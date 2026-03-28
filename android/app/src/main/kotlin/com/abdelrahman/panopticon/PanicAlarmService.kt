package com.abdelrahman.panopticon

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/**
 * PanicAlarmService — صافرة الذعر لتحديد موقع الأصول المفقودة
 *
 * عند تفعيله:
 *  1. يرفع مستوى الصوت للحد الأقصى تلقائياً
 *  2. يُشغّل نغمة الطوارئ القصوى
 *  3. يُفعّل الاهتزاز المستمر
 *  4. يُرسل إشعار NTFY.sh لضمان تجاوز Doze Mode
 *  5. يحافظ على WakeLock لمنع الإيقاف بواسطة النظام
 */
class PanicAlarmService : Service() {

    companion object {
        const val TAG = "PanicAlarmService"
        const val NOTIFICATION_ID = 4001
        const val CHANNEL_ID = "panic_alarm_channel"
        const val ACTION_STOP = "com.abdelrahman.panopticon.STOP_PANIC_ALARM"
        const val NTFY_TOPIC_KEY = "ntfy_topic"
        const val DEFAULT_NTFY_TOPIC = "panopticon-alerts"

        fun start(context: Context, ntfyTopic: String = DEFAULT_NTFY_TOPIC) {
            val intent = Intent(context, PanicAlarmService::class.java)
                .putExtra(NTFY_TOPIC_KEY, ntfyTopic)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, PanicAlarmService::class.java))
        }
    }

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var originalVolume: Int = -1
    private var audioManager: AudioManager? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        acquireWakeLock()
        startForeground(NOTIFICATION_ID, buildNotification())
        Log.i(TAG, "✓ Panic Alarm Service بدأ")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }

        val ntfyTopic = intent?.getStringExtra(NTFY_TOPIC_KEY) ?: DEFAULT_NTFY_TOPIC

        overrideVolumeToMax()
        startAlarmSound()
        startVibration()

        // إرسال إشعار NTFY.sh في خيط منفصل (لتجاوز Doze Mode عبر الشبكة)
        Thread {
            sendNtfyAlert(ntfyTopic)
        }.start()

        return START_STICKY
    }

    override fun onDestroy() {
        restoreVolume()
        stopAlarmSound()
        stopVibration()
        wakeLock?.release()
        Log.i(TAG, "Panic Alarm أُوقف")
        super.onDestroy()
    }

    // ── رفع الصوت للحد الأقصى ────────────────────────────────

    private fun overrideVolumeToMax() {
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val am = audioManager ?: return

        originalVolume = am.getStreamVolume(AudioManager.STREAM_ALARM)
        val maxVolume = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)

        am.setStreamVolume(
            AudioManager.STREAM_ALARM,
            maxVolume,
            0
        )
        Log.i(TAG, "✓ الصوت رُفع للحد الأقصى: $maxVolume")
    }

    private fun restoreVolume() {
        if (originalVolume >= 0) {
            audioManager?.setStreamVolume(AudioManager.STREAM_ALARM, originalVolume, 0)
            Log.i(TAG, "الصوت أُعيد لمستواه الأصلي: $originalVolume")
        }
    }

    // ── تشغيل صوت الطوارئ ────────────────────────────────────

    private fun startAlarmSound() {
        try {
            stopAlarmSound()

            val alarmUri: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(this@PanicAlarmService, alarmUri)
                isLooping = true
                prepare()
                start()
            }
            Log.i(TAG, "✓ صوت الإنذار يعمل")
        } catch (e: IOException) {
            Log.e(TAG, "خطأ في تشغيل الصوت: ${e.message}")
        }
    }

    private fun stopAlarmSound() {
        try {
            mediaPlayer?.apply {
                if (isPlaying) stop()
                release()
            }
            mediaPlayer = null
        } catch (e: Exception) { /* تجاهل */ }
    }

    // ── الاهتزاز المستمر ──────────────────────────────────────

    private fun startVibration() {
        try {
            vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vm.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }

            val pattern = longArrayOf(0, 500, 200, 500, 200, 1000, 300)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(
                    VibrationEffect.createWaveform(pattern, 0)
                )
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
            Log.i(TAG, "✓ الاهتزاز يعمل")
        } catch (e: Exception) {
            Log.e(TAG, "خطأ في الاهتزاز: ${e.message}")
        }
    }

    private fun stopVibration() {
        try { vibrator?.cancel() } catch (e: Exception) { /* تجاهل */ }
        vibrator = null
    }

    // ── إشعار NTFY.sh (يتجاوز Doze Mode) ────────────────────

    private fun sendNtfyAlert(topic: String) {
        try {
            val url = URL("https://ntfy.sh/$topic")
            val conn = url.openConnection() as HttpURLConnection
            conn.apply {
                requestMethod = "POST"
                doOutput = true
                connectTimeout = 10_000
                readTimeout = 10_000
                setRequestProperty("Title", "🚨 تنبيه طوارئ — Panic Alarm")
                setRequestProperty("Priority", "urgent")
                setRequestProperty("Tags", "rotating_light,sos")
                setRequestProperty("Content-Type", "text/plain; charset=utf-8")
            }

            val body = "⚠️ تم تفعيل Panic Alarm على الجهاز!\n" +
                    "الوقت: ${java.util.Date()}\n" +
                    "الجهاز: ${android.os.Build.MODEL}\n" +
                    "يرجى التحقق من موقع الجهاز فوراً."
            conn.outputStream.write(body.toByteArray(Charsets.UTF_8))

            val responseCode = conn.responseCode
            Log.i(TAG, "✓ NTFY.sh استجاب: $responseCode")
            conn.disconnect()
        } catch (e: Exception) {
            Log.w(TAG, "NTFY.sh فشل (قد يكون الجهاز بدون إنترنت): ${e.message}")
        }
    }

    // ── WakeLock ──────────────────────────────────────────────

    private fun acquireWakeLock() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ON_AFTER_RELEASE,
            "PanicAlarmService::WakeLock"
        ).also { it.acquire(30 * 60 * 1000L) } // 30 دقيقة كحد أقصى
    }

    // ── الإشعار الدائم ────────────────────────────────────────

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID,
                "إنذار الطوارئ",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "إنذار تحديد موقع الأصل المفقود"
                setShowBadge(true)
                enableLights(true)
                lightColor = android.graphics.Color.RED
                enableVibration(true)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🚨 Panic Alarm — تنبيه طوارئ")
            .setContentText("جهاز مفقود — الإنذار يعمل")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setColor(0xFFFF0000.toInt())
            .build()
    }
}
