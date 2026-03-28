package com.abdelrahman.panopticon

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

/**
 * RedOverlayService — خدمة الطبقة الحمراء العقابية
 *
 * تستخدم WindowManager + SYSTEM_ALERT_WINDOW لعرض طبقة
 * حمراء شبه شفافة فوق جميع التطبيقات كإجراء عقابي.
 *
 * تُحكَم من Dart عبر MethodChannel 'panopticon/red_overlay'.
 * المتطلب: إذن SYSTEM_ALERT_WINDOW (Draw over other apps).
 */
class RedOverlayService : Service() {

    companion object {
        const val ACTION_SHOW = "com.abdelrahman.panopticon.SHOW_RED_OVERLAY"
        const val ACTION_HIDE = "com.abdelrahman.panopticon.HIDE_RED_OVERLAY"
        const val EXTRA_MESSAGE = "overlay_message"
        private const val CHANNEL_ID = "panopticon_red_overlay"
        private const val NOTIF_ID = 9001

        fun show(context: Context, message: String = "انتهاك مرصود") {
            val intent = Intent(context, RedOverlayService::class.java).apply {
                action = ACTION_SHOW
                putExtra(EXTRA_MESSAGE, message)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun hide(context: Context) {
            context.startService(
                Intent(context, RedOverlayService::class.java).apply {
                    action = ACTION_HIDE
                }
            )
        }
    }

    private var windowManager: WindowManager? = null
    private var overlayView: FrameLayout? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        startForeground(NOTIF_ID, buildNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW -> {
                val message = intent.getStringExtra(EXTRA_MESSAGE)
                    ?: "انتهاك مرصود — خرق قواعد النظام"
                showOverlay(message)
            }
            ACTION_HIDE -> hideOverlayAndStop()
        }
        return START_STICKY
    }

    // ── عرض الطبقة ───────────────────────────────────────────────

    private fun showOverlay(message: String) {
        if (overlayView != null) return          // لا تُضيف طبقة مكررة
        val wm = windowManager ?: return

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }

        overlayView = FrameLayout(this).apply {
            // خلفية حمراء شبه شفافة (70% opacity)
            setBackgroundColor(Color.argb(178, 180, 0, 0))

            // رسالة عقابية في المنتصف
            addView(
                TextView(this@RedOverlayService).apply {
                    text = message
                    textSize = 20f
                    setTextColor(Color.WHITE)
                    gravity = Gravity.CENTER
                    setPadding(48, 48, 48, 48)
                    setTypeface(typeface, android.graphics.Typeface.BOLD)
                },
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    Gravity.CENTER
                )
            )
        }

        try {
            wm.addView(overlayView, params)
            android.util.Log.i("RedOverlayService", "الطبقة الحمراء نشطة: $message")
        } catch (e: Exception) {
            android.util.Log.e("RedOverlayService", "فشل عرض الطبقة: ${e.message}")
            overlayView = null
        }
    }

    // ── إخفاء الطبقة ─────────────────────────────────────────────

    private fun hideOverlayAndStop() {
        overlayView?.let { view ->
            try {
                windowManager?.removeView(view)
            } catch (_: Exception) {}
            overlayView = null
        }
        stopSelf()
    }

    override fun onDestroy() {
        overlayView?.let { view ->
            try {
                windowManager?.removeView(view)
            } catch (_: Exception) {}
            overlayView = null
        }
        super.onDestroy()
    }

    // ── إشعار Foreground إلزامي ────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Panopticon Overlay",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                setSound(null, null)
                enableVibration(false)
            }
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Panopticon")
            .setContentText("طبقة المراقبة نشطة")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }
}
