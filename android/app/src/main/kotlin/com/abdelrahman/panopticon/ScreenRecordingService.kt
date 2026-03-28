package com.abdelrahman.panopticon

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * ScreenRecordingService — خدمة التسجيل المرئي للجلسات المدققة
 *
 * سياسة الشفافية (Android Transparency):
 *  - إشعار إلزامي "التسجيل نشط" — مطلوب بموجب Android Policy
 *  - foregroundServiceType = "mediaProjection"
 *  - تُوقف الخدمة إذا أُلغي إذن MediaProjection
 *
 * التدفق:
 *  Admin → Firestore command "start_audit_recording" →
 *  CommandListenerService → يُطلق هذه الخدمة →
 *  MediaProjection + VirtualDisplay + MediaRecorder →
 *  تُحفظ في ملف MP4 محلي →
 *  تُرفع لـ IPFS/Telegram عبر TelemetryPublisherService
 */
class ScreenRecordingService : Service() {

    companion object {
        private const val TAG = "ScreenRecordingSvc"
        const val NOTIFICATION_ID = 5001
        const val CHANNEL_ID = "screen_recording_channel"

        const val EXTRA_RESULT_CODE = "result_code"
        const val EXTRA_RESULT_DATA = "result_data"
        const val EXTRA_UID = "uid"

        const val PREF_FILE = "focus_prefs"
        const val PREF_UID = "saved_uid"

        private var isRecording = false
        private var currentOutputPath: String? = null

        fun isCurrentlyRecording() = isRecording

        fun start(context: Context, resultCode: Int, resultData: Intent, uid: String) {
            val intent = Intent(context, ScreenRecordingService::class.java).apply {
                putExtra(EXTRA_RESULT_CODE, resultCode)
                putExtra(EXTRA_RESULT_DATA, resultData)
                putExtra(EXTRA_UID, uid)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, ScreenRecordingService::class.java))
        }
    }

    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var mediaRecorder: MediaRecorder? = null
    private var outputFile: File? = null
    private var uid: String = ""

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startForeground(NOTIFICATION_ID, buildRecordingNotification())
        Log.i(TAG, "✓ Screen Recording Service بدأ")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val resultCode = intent?.getIntExtra(EXTRA_RESULT_CODE, Activity.RESULT_CANCELED)
            ?: Activity.RESULT_CANCELED
        val resultData = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent?.getParcelableExtra(EXTRA_RESULT_DATA, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent?.getParcelableExtra(EXTRA_RESULT_DATA)
        }
        uid = intent?.getStringExtra(EXTRA_UID)
            ?: getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                .getString(PREF_UID, "") ?: ""

        if (resultCode != Activity.RESULT_OK || resultData == null) {
            Log.e(TAG, "MediaProjection permission denied — إيقاف الخدمة")
            reportRecordingState(uid, "permission_denied")
            stopSelf()
            return START_NOT_STICKY
        }

        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                as MediaProjectionManager
        mediaProjection = projectionManager.getMediaProjection(resultCode, resultData)

        val started = startRecording()
        if (!started) {
            stopSelf()
            return START_NOT_STICKY
        }

        isRecording = true
        reportRecordingState(uid, "recording_started")
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopRecording()
        Log.i(TAG, "Screen Recording أُوقف")
        super.onDestroy()
    }

    // ── تسجيل الشاشة ─────────────────────────────────────────

    private fun startRecording(): Boolean {
        return try {
            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val metrics = DisplayMetrics()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                wm.currentWindowMetrics.bounds.let {
                    metrics.widthPixels = it.width()
                    metrics.heightPixels = it.height()
                    metrics.densityDpi = resources.displayMetrics.densityDpi
                }
            } else {
                @Suppress("DEPRECATION")
                wm.defaultDisplay.getMetrics(metrics)
            }

            val width = (metrics.widthPixels / 2) * 2   // يجب أن يكون زوجياً
            val height = (metrics.heightPixels / 2) * 2
            val dpi = metrics.densityDpi

            // إعداد ملف الإخراج
            val dir = File(getExternalFilesDir(null), "audit_recordings").also { it.mkdirs() }
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
            outputFile = File(dir, "audit_$timestamp.mp4")
            currentOutputPath = outputFile!!.absolutePath

            // MediaRecorder
            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }

            mediaRecorder!!.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setVideoSource(MediaRecorder.VideoSource.SURFACE)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setOutputFile(outputFile!!.absolutePath)
                setVideoSize(width, height)
                setVideoEncoder(MediaRecorder.VideoEncoder.H264)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setVideoEncodingBitRate(1_500_000)
                setVideoFrameRate(30)
                prepare()
            }

            virtualDisplay = mediaProjection?.createVirtualDisplay(
                "PanopticonAudit",
                width, height, dpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                mediaRecorder!!.surface, null, null
            )

            mediaRecorder!!.start()
            Log.i(TAG, "✓ التسجيل بدأ: ${outputFile!!.name}")
            true
        } catch (e: Exception) {
            Log.e(TAG, "فشل التسجيل: ${e.message}")
            reportRecordingState(uid, "recording_failed")
            false
        }
    }

    private fun stopRecording() {
        isRecording = false
        try {
            mediaRecorder?.apply {
                stop()
                release()
            }
            mediaRecorder = null
        } catch (e: Exception) {
            Log.w(TAG, "خطأ في إيقاف MediaRecorder: ${e.message}")
        }
        virtualDisplay?.release()
        virtualDisplay = null
        mediaProjection?.stop()
        mediaProjection = null

        val path = currentOutputPath
        if (path != null && uid.isNotEmpty()) {
            Log.i(TAG, "✓ التسجيل حُفظ: $path")
            reportRecordingState(uid, "recording_saved", path)
        }
        currentOutputPath = null
    }

    // ── Firestore — رفع حالة التسجيل ───────────────────────

    private fun reportRecordingState(uid: String, state: String, filePath: String? = null) {
        if (uid.isEmpty()) return
        val data = mutableMapOf<String, Any>(
            "screenRecordingState" to state,
            "lastUpdated" to FieldValue.serverTimestamp()
        )
        if (filePath != null) {
            data["lastRecordingPath"] = filePath
            data["pendingUpload"] = true
        }
        FirebaseFirestore.getInstance()
            .collection("device_states")
            .document(uid)
            .update(data)
            .addOnFailureListener { Log.w(TAG, "فشل رفع حالة التسجيل: ${it.message}") }
    }

    // ── الإشعار الإلزامي (سياسة Android) ─────────────────────

    private fun buildRecordingNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID,
                "التسجيل نشط",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "جلسة التدقيق قيد التسجيل — إشعار إلزامي بموجب سياسة Android"
                setShowBadge(true)
                enableLights(true)
                lightColor = android.graphics.Color.RED
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🔴 التسجيل نشط — Audit Session")
            .setContentText("يتم تسجيل شاشة الجهاز لأغراض التدقيق والمراجعة")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setColor(0xFFFF0000.toInt())
            .build()
    }
}
