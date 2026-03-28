package com.abdelrahman.panopticon

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ServerValue
import kotlin.math.abs
import kotlin.math.log10
import kotlin.math.sqrt

/**
 * AmbientAudioService — خدمة تحليل الصوت المحيط
 *
 * تُشغَّل بأمر من CommandListenerService عبر `start_ambient_audio`.
 * تستخدم AudioRecord للاستماع الدوري (3 ثوانٍ كل 30 ثانية):
 *  1. قياس مستوى الصوت بالـ dB (Decibel)
 *  2. حساب RMS (Root Mean Square) للسعة
 *  3. تصنيف بيئة الصوت: QUIET / MODERATE / LOUD / VERY_LOUD
 *  4. رفع البيانات لـ RTDB: `device_states/{uid}/ambientAudio`
 *
 * تتوقف تلقائياً بأمر `stop_ambient_audio`.
 */
class AmbientAudioService : Service() {

    companion object {
        private const val TAG             = "AmbientAudio"
        const val NOTIFICATION_ID         = 3003
        const val CHANNEL_ID              = "ambient_audio_channel"
        const val EXTRA_UID               = "uid"

        // إعدادات الصوت
        private const val SAMPLE_RATE     = 44100  // Hz
        private const val CHANNEL_CONFIG  = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT    = AudioFormat.ENCODING_PCM_16BIT
        private const val SAMPLE_DURATION = 3_000L  // 3 ثوان لكل عيّنة
        private const val PUBLISH_INTERVAL = 30_000L // 30 ثانية بين العيّنات

        // عتبات تصنيف الصوت بالـ dB
        private const val QUIET_THRESHOLD    = 40.0  // < 40 dB → QUIET
        private const val MODERATE_THRESHOLD = 60.0  // 40-60 dB → MODERATE
        private const val LOUD_THRESHOLD     = 80.0  // 60-80 dB → LOUD
                                                      // > 80 dB → VERY_LOUD

        fun start(context: Context, uid: String) {
            val intent = Intent(context, AmbientAudioService::class.java)
                .putExtra(EXTRA_UID, uid)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, AmbientAudioService::class.java))
        }
    }

    private val rtdb by lazy { FirebaseDatabase.getInstance().reference }
    private val handler = Handler(Looper.getMainLooper())
    private var uid: String = ""
    private var isRecording = false

    private val sampleRunnable = object : Runnable {
        override fun run() {
            if (isRecording) {
                performAudioSample()
                handler.postDelayed(this, PUBLISH_INTERVAL)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startForeground(NOTIFICATION_ID, buildNotification())
        Log.i(TAG, "✓ خدمة تحليل الصوت المحيط بدأت")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        uid = intent?.getStringExtra(EXTRA_UID)
            ?: getSharedPreferences(CommandListenerService.PREF_FILE, MODE_PRIVATE)
                .getString(CommandListenerService.PREF_UID, "") ?: ""

        if (uid.isEmpty()) {
            Log.w(TAG, "UID غير موجود — إيقاف الخدمة")
            stopSelf()
            return START_NOT_STICKY
        }

        isRecording = true
        handler.post(sampleRunnable)

        return START_STICKY
    }

    override fun onDestroy() {
        isRecording = false
        handler.removeCallbacks(sampleRunnable)
        // رفع حالة نهاية التشغيل
        if (uid.isNotEmpty()) {
            rtdb.child("device_states").child(uid).child("ambientAudio")
                .updateChildren(mapOf("active" to false, "stoppedAt" to ServerValue.TIMESTAMP))
        }
        super.onDestroy()
        Log.i(TAG, "خدمة تحليل الصوت توقفت")
    }

    // ── تسجيل عيّنة صوتية ──────────────────────────────────────

    private fun performAudioSample() {
        Thread {
            try {
                val bufferSize = AudioRecord.getMinBufferSize(
                    SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT
                ).coerceAtLeast(4096)

                val recorder = AudioRecord(
                    MediaRecorder.AudioSource.MIC,
                    SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT, bufferSize
                )

                if (recorder.state != AudioRecord.STATE_INITIALIZED) {
                    Log.w(TAG, "فشل تهيئة AudioRecord — تحقق من إذن RECORD_AUDIO")
                    recorder.release()
                    return@Thread
                }

                recorder.startRecording()

                // جمع العيّنات لمدة SAMPLE_DURATION
                val samplesNeeded = (SAMPLE_RATE * (SAMPLE_DURATION / 1000)).toInt()
                val buffer        = ShortArray(bufferSize)
                val allSamples    = mutableListOf<Short>()
                val startTime     = System.currentTimeMillis()

                while (System.currentTimeMillis() - startTime < SAMPLE_DURATION &&
                       isRecording) {
                    val read = recorder.read(buffer, 0, bufferSize)
                    if (read > 0) {
                        allSamples.addAll(buffer.take(read))
                    }
                }

                recorder.stop()
                recorder.release()

                if (allSamples.isEmpty()) return@Thread

                // حساب RMS
                val rms = sqrt(
                    allSamples.map { it.toDouble() * it.toDouble() }
                        .average()
                )

                // تحويل لـ dB
                val dbLevel = if (rms > 0) {
                    20.0 * log10(rms / 32768.0) + 90.0 // تعديل الأساس ليكون 0-120 dB
                } else 0.0

                val classification = classifyNoise(dbLevel)
                val peakAmplitude  = allSamples.maxOfOrNull { abs(it.toInt()) } ?: 0

                Log.i(TAG, "🎙 مستوى الصوت: ${String.format("%.1f", dbLevel)} dB — $classification")

                // رفع للـ RTDB
                val payload = mapOf(
                    "dbLevel"        to dbLevel,
                    "rms"            to rms,
                    "peakAmplitude"  to peakAmplitude,
                    "classification" to classification,
                    "sampleDuration" to SAMPLE_DURATION,
                    "active"         to true,
                    "timestamp"      to ServerValue.TIMESTAMP,
                )

                rtdb.child("device_states").child(uid).child("ambientAudio")
                    .setValue(payload)
                    .addOnFailureListener { e ->
                        Log.w(TAG, "فشل رفع بيانات الصوت: ${e.message}")
                    }

            } catch (e: SecurityException) {
                Log.e(TAG, "خطأ أمني — يحتاج إذن RECORD_AUDIO: ${e.message}")
                stopSelf()
            } catch (e: Exception) {
                Log.e(TAG, "خطأ في تسجيل الصوت: ${e.message}")
            }
        }.start()
    }

    private fun classifyNoise(db: Double): String = when {
        db < QUIET_THRESHOLD    -> "QUIET"
        db < MODERATE_THRESHOLD -> "MODERATE"
        db < LOUD_THRESHOLD     -> "LOUD"
        else                    -> "VERY_LOUD"
    }

    // ── الإشعار الدائم ─────────────────────────────────────────

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "تحليل البيئة الصوتية",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("مراقبة البيئة الصوتية")
            .setContentText("تحليل دوري لمستوى الضوضاء المحيطة")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setColor(0xFFC9A84C.toInt())
            .build()
    }
}
