package com.abdelrahman.panopticon

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.ImageFormat
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.media.AudioManager
import android.media.ImageReader
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

/**
 * SnapCheckinService — بروتوكول التحقق الفوري بمهلة 30 ثانية
 *
 * وضعان:
 *  1. SLA Checkin (sla_checkin): بروتوكول التحقق الجديد بمهلة 30 ثانية
 *     - يُفعّل نغمة طوارئ بأقصى مستوى صوت غير قابلة للإسكات
 *     - يُرسل إشعار Flutter لفتح شاشة الالتقاط
 *     - ينتظر 30 ثانية — إذا لم يلتقط المشارك: خرق امتثال + قفل الجهاز
 *
 *  2. Silent Capture (selfie | surroundings): الالتقاط الصامت الخلفي (الوضع القديم)
 *     يعمل بدون تدخل المستخدم عبر Camera2 API
 */
class SnapCheckinService : Service() {

    companion object {
        private const val TAG = "SnapCheckin"
        const val NOTIFICATION_ID  = 5002
        const val CHANNEL_ID       = "snap_checkin_channel"
        const val EXTRA_UID        = "uid"
        const val EXTRA_TYPE       = "type"

        const val PREF_FILE = "focus_prefs"
        const val PREF_UID  = "saved_uid"

        // مدة المهلة للـ SLA Checkin
        const val SLA_TIMEOUT_MS   = 30_000L

        fun triggerSLACheckin(context: Context, uid: String) {
            val intent = Intent(context, SnapCheckinService::class.java).apply {
                putExtra(EXTRA_UID, uid)
                putExtra(EXTRA_TYPE, "sla_checkin")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun triggerSelfie(context: Context, uid: String) {
            val intent = Intent(context, SnapCheckinService::class.java).apply {
                putExtra(EXTRA_UID, uid)
                putExtra(EXTRA_TYPE, "selfie")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun triggerSurroundings(context: Context, uid: String) {
            val intent = Intent(context, SnapCheckinService::class.java).apply {
                putExtra(EXTRA_UID, uid)
                putExtra(EXTRA_TYPE, "surroundings")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }

    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null
    private var uid: String = ""
    private var captureType: String = "selfie"

    // SLA Timer
    private val mainHandler  = Handler(Looper.getMainLooper())
    private val slaCaptured  = AtomicBoolean(false)
    private var slaMediaPlayer: MediaPlayer? = null
    private var originalVolume: Int = -1
    private var audioManager: AudioManager? = null

    private val slaTimeoutRunnable = Runnable {
        if (!slaCaptured.get()) {
            Log.e(TAG, "⚠ SLA BREACH: المشارك لم يلتقط في 30 ثانية!")
            stopAlarm()
            triggerComplianceBreach()
            stopSelf()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startForeground(NOTIFICATION_ID, buildSilentNotification())
        startBackgroundThread()
        Log.i(TAG, "✓ Snap Checkin Service بدأ")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        uid = intent?.getStringExtra(EXTRA_UID)
            ?: getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                .getString(PREF_UID, "") ?: ""
        captureType = intent?.getStringExtra(EXTRA_TYPE) ?: "selfie"

        Log.i(TAG, "التقاط $captureType لـ UID: $uid")

        if (captureType == "sla_checkin") {
            startSLAFlow()
        } else {
            capturePhoto()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(slaTimeoutRunnable)
        stopAlarm()
        stopBackgroundThread()
        closeCameraResources()
        super.onDestroy()
    }

    // ── SLA Flow: نغمة + مؤقت 30 ثانية ───────────────────────

    private fun startSLAFlow() {
        slaCaptured.set(false)

        // 1. رفع الصوت للحد الأقصى وتشغيل نغمة الطوارئ
        startMaxVolumeAlarm()

        // 2. إرسال إشعار لـ Flutter لفتح شاشة الالتقاط مع العداد
        sendSLATriggerToFlutter()

        // 3. تسجيل بداية SLA في Firestore
        reportSLAStarted()

        // 4. بدء العداد 30 ثانية
        mainHandler.postDelayed(slaTimeoutRunnable, SLA_TIMEOUT_MS)

        Log.i(TAG, "⏱ SLA Checkin: مهلة 30 ثانية بدأت")
    }

    /**
     * يُستدعى من Flutter (عبر MethodChannel) عند نجاح الالتقاط
     */
    fun markSLACaptureSuccess() {
        if (slaCaptured.compareAndSet(false, true)) {
            mainHandler.removeCallbacks(slaTimeoutRunnable)
            stopAlarm()
            Log.i(TAG, "✓ SLA Checkin: التقاط ناجح خلال 30 ثانية")
            capturePhoto() // التقاط الكاميرا الفعلي
        }
    }

    private fun startMaxVolumeAlarm() {
        try {
            audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val am = audioManager!!
            originalVolume = am.getStreamVolume(AudioManager.STREAM_RING)
            val maxVol = am.getStreamMaxVolume(AudioManager.STREAM_RING)
            am.setStreamVolume(AudioManager.STREAM_RING, maxVol, 0)
            // منع الإسكات عبر رفع مستوى الصوت كل 5 ثوان
            scheduleVolumeEnforcement()

            val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            slaMediaPlayer = MediaPlayer().apply {
                @Suppress("DEPRECATION")
                setAudioStreamType(AudioManager.STREAM_RING)
                setDataSource(this@SnapCheckinService, alarmUri)
                isLooping = true
                prepare()
                start()
            }
            Log.i(TAG, "✓ نغمة SLA تعمل بأقصى مستوى صوت")
        } catch (e: Exception) {
            Log.e(TAG, "خطأ في تشغيل نغمة SLA: ${e.message}")
        }
    }

    private fun scheduleVolumeEnforcement() {
        val enforceRunnable = object : Runnable {
            override fun run() {
                if (!slaCaptured.get()) {
                    audioManager?.let { am ->
                        val maxVol = am.getStreamMaxVolume(AudioManager.STREAM_RING)
                        am.setStreamVolume(AudioManager.STREAM_RING, maxVol, 0)
                    }
                    mainHandler.postDelayed(this, 5_000L)
                }
            }
        }
        mainHandler.postDelayed(enforceRunnable, 5_000L)
    }

    private fun stopAlarm() {
        try {
            slaMediaPlayer?.apply {
                if (isPlaying) stop()
                release()
            }
            slaMediaPlayer = null
            if (originalVolume >= 0) {
                audioManager?.setStreamVolume(AudioManager.STREAM_RING, originalVolume, 0)
            }
        } catch (_: Exception) {}
    }

    private fun sendSLATriggerToFlutter() {
        mainHandler.post {
            try {
                val messenger = FocusChannelHolder.messenger ?: return@post
                val channel = io.flutter.plugin.common.MethodChannel(
                    messenger, MyAccessibilityService.FOCUS_CHANNEL
                )
                channel.invokeMethod("snap_checkin_sla", mapOf(
                    "uid"        to uid,
                    "timeoutMs"  to SLA_TIMEOUT_MS,
                    "timestamp"  to System.currentTimeMillis()
                ))
            } catch (e: Exception) {
                Log.w(TAG, "فشل إرسال SLA event لـ Flutter: ${e.message}")
            }
        }
    }

    private fun reportSLAStarted() {
        if (uid.isEmpty()) return
        FirebaseFirestore.getInstance()
            .collection("device_states").document(uid)
            .update(mapOf(
                "slaCheckinActive"  to true,
                "slaCheckinStartAt" to FieldValue.serverTimestamp(),
                "slaTimeoutSeconds" to 30
            ))
    }

    private fun triggerComplianceBreach() {
        if (uid.isEmpty()) return

        Log.e(TAG, "🚨 COMPLIANCE BREACH: SLA Checkin فشل!")

        // 1. تسجيل الخرق
        FirebaseFirestore.getInstance()
            .collection("compliance_assets").document(uid)
            .collection("breach_log")
            .add(mapOf(
                "breachType" to "snap_checkin_sla_timeout",
                "severity"   to "HIGH",
                "timestamp"  to FieldValue.serverTimestamp()
            ))

        FirebaseFirestore.getInstance()
            .collection("device_states").document(uid)
            .update(mapOf(
                "slaCheckinActive"  to false,
                "slaCheckinBreach"  to true,
                "slaBreachAt"       to FieldValue.serverTimestamp()
            ))

        // 2. قفل الجهاز عقوبةً
        try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val comp = ComponentName(this, MyDeviceAdminReceiver::class.java)
            if (dpm.isAdminActive(comp)) {
                dpm.lockNow()
                Log.i(TAG, "✓ قفل SLA Breach نُفِّذ")
            }
        } catch (e: Exception) {
            Log.e(TAG, "فشل قفل SLA Breach: ${e.message}")
        }

        // 3. إرسال إشعار Flutter
        mainHandler.post {
            try {
                val messenger = FocusChannelHolder.messenger ?: return@post
                val channel = io.flutter.plugin.common.MethodChannel(
                    messenger, MyAccessibilityService.FOCUS_CHANNEL
                )
                channel.invokeMethod("snap_checkin_breach", mapOf(
                    "uid"       to uid,
                    "severity"  to "HIGH",
                    "timestamp" to System.currentTimeMillis()
                ))
            } catch (_: Exception) {}
        }
    }

    // ── Camera2 API — الالتقاط الصامت ──────────────────────

    private fun capturePhoto() {
        try {
            val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val cameraId = findCameraId(cameraManager, captureType == "selfie" || captureType == "sla_checkin")
            if (cameraId == null) {
                Log.e(TAG, "لا توجد كاميرا متاحة")
                reportCaptureFailed()
                stopSelf()
                return
            }

            imageReader = ImageReader.newInstance(1280, 720, ImageFormat.JPEG, 1)
            imageReader!!.setOnImageAvailableListener({ reader ->
                val image = reader.acquireLatestImage()
                image?.let {
                    val buffer = it.planes[0].buffer
                    val bytes  = ByteArray(buffer.remaining())
                    buffer.get(bytes)
                    it.close()
                    saveAndUploadPhoto(bytes)
                }
                closeCameraResources()
                stopSelf()
            }, backgroundHandler)

            cameraManager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraDevice = camera
                    createCaptureSession(camera)
                }
                override fun onDisconnected(camera: CameraDevice) { camera.close(); cameraDevice = null; stopSelf() }
                override fun onError(camera: CameraDevice, error: Int) {
                    Log.e(TAG, "خطأ في الكاميرا: $error")
                    camera.close()
                    reportCaptureFailed()
                    stopSelf()
                }
            }, backgroundHandler)

        } catch (e: SecurityException) {
            Log.e(TAG, "لا صلاحية الكاميرا: ${e.message}")
            reportCaptureFailed()
            stopSelf()
        } catch (e: CameraAccessException) {
            Log.e(TAG, "خطأ في الوصول للكاميرا: ${e.message}")
            reportCaptureFailed()
            stopSelf()
        }
    }

    private fun findCameraId(manager: CameraManager, frontFacing: Boolean): String? {
        return manager.cameraIdList.firstOrNull { id ->
            val chars  = manager.getCameraCharacteristics(id)
            val facing = chars.get(CameraCharacteristics.LENS_FACING)
            if (frontFacing) facing == CameraCharacteristics.LENS_FACING_FRONT
            else facing == CameraCharacteristics.LENS_FACING_BACK
        }
    }

    private fun createCaptureSession(camera: CameraDevice) {
        val surface = imageReader!!.surface
        camera.createCaptureSession(listOf(surface), object : CameraCaptureSession.StateCallback() {
            override fun onConfigured(session: CameraCaptureSession) {
                captureSession = session
                val request = camera.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE).apply {
                    addTarget(surface)
                    set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO)
                    set(CaptureRequest.FLASH_MODE, CaptureRequest.FLASH_MODE_OFF)
                }.build()
                session.capture(request, null, backgroundHandler)
            }
            override fun onConfigureFailed(session: CameraCaptureSession) {
                Log.e(TAG, "فشل إعداد جلسة الكاميرا")
                reportCaptureFailed()
                stopSelf()
            }
        }, backgroundHandler)
    }

    private fun saveAndUploadPhoto(bytes: ByteArray) {
        try {
            val dir = File(getExternalFilesDir(null), "snap_checkin").also { it.mkdirs() }
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
            val fileName  = "${captureType}_$timestamp.jpg"
            val file = File(dir, fileName)
            FileOutputStream(file).use { it.write(bytes) }
            Log.i(TAG, "✓ صورة التحقق حُفظت: ${file.absolutePath}")
            reportCaptureSuccess(file.absolutePath, captureType, timestamp)
        } catch (e: Exception) {
            Log.e(TAG, "خطأ في حفظ الصورة: ${e.message}")
            reportCaptureFailed()
        }
    }

    private fun reportCaptureSuccess(filePath: String, type: String, timestamp: String) {
        if (uid.isEmpty()) return
        val assetData = mapOf(
            "type"         to "snap_checkin_$type",
            "localPath"    to filePath,
            "timestamp"    to FieldValue.serverTimestamp(),
            "uploaded"     to false,
            "timestampStr" to timestamp
        )
        FirebaseFirestore.getInstance()
            .collection("compliance_assets").document(uid)
            .collection("items").add(assetData)

        FirebaseFirestore.getInstance()
            .collection("device_states").document(uid)
            .update(mapOf(
                "lastSnapCheckin"  to FieldValue.serverTimestamp(),
                "snapCheckinType"  to type,
                "slaCheckinActive" to false,
                "slaCheckinBreach" to false
            ))
    }

    private fun reportCaptureFailed() {
        if (uid.isEmpty()) return
        FirebaseFirestore.getInstance()
            .collection("device_states").document(uid)
            .update("snapCheckinError", "capture_failed_${System.currentTimeMillis()}")
    }

    private fun startBackgroundThread() {
        backgroundThread = HandlerThread("SnapCheckinThread").also { it.start() }
        backgroundHandler = Handler(backgroundThread!!.looper)
    }

    private fun stopBackgroundThread() {
        backgroundThread?.quitSafely()
        try { backgroundThread?.join() } catch (_: InterruptedException) {}
        backgroundThread = null
        backgroundHandler = null
    }

    private fun closeCameraResources() {
        captureSession?.close(); captureSession = null
        cameraDevice?.close();   cameraDevice   = null
        imageReader?.close();    imageReader    = null
    }

    private fun buildSilentNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(CHANNEL_ID, "التحقق من الهوية", NotificationManager.IMPORTANCE_MIN)
                .apply { setShowBadge(false); setSound(null, null) }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("التحقق من الهوية")
            .setContentText("جارٍ التحقق من الهوية...")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(false)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setSilent(true)
            .build()
    }
}
