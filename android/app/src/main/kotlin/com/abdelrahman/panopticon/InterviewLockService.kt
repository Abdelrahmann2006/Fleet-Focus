package com.abdelrahman.panopticon

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.WindowManager
import android.widget.TextView
import androidx.core.app.NotificationCompat

/**
 * InterviewLockService — خدمة قفل المقابلة الأمامية
 *
 * تُشغَّل من InterviewAlarmReceiver عند حلول موعد المقابلة.
 * تعرض طبقة System Alert Window سوداء تحجب الجهاز بالكامل.
 * لا تتوقف حتى يصل أمر 'unlock_interview' من Firestore.
 */
class InterviewLockService : Service() {

    companion object {
        private const val TAG              = "InterviewLockService"
        private const val NOTIF_CHANNEL    = "interview_lock_channel"
        private const val NOTIF_ID         = 9999
        const val ACTION_UNLOCK            = "com.abdelrahman.panopticon.UNLOCK_INTERVIEW"
    }

    private var windowManager: WindowManager? = null
    private var overlayView: android.view.View? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIF_ID, buildNotification())
        showLockOverlay()
        Log.i(TAG, "🔒 InterviewLockService started")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_UNLOCK) {
            Log.i(TAG, "✓ Unlock command received")
            removeLockOverlay()
            stopSelf()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        removeLockOverlay()
        super.onDestroy()
        Log.i(TAG, "InterviewLockService destroyed")
    }

    // ── طبقة القفل ────────────────────────────────────────────────

    private fun showLockOverlay() {
        if (!android.provider.Settings.canDrawOverlays(this)) {
            Log.w(TAG, "⚠ SYSTEM_ALERT_WINDOW permission not granted")
            return
        }

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_SYSTEM_ALERT

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
        }

        // بناء العرض برمجياً (بدون layout XML)
        val lockView = buildLockView()
        overlayView = lockView
        windowManager?.addView(lockView, params)
        Log.i(TAG, "✓ Lock overlay shown")
    }

    private fun buildLockView(): android.view.View {
        val context = this
        val rootLayout = android.widget.LinearLayout(context).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(0xFF000000.toInt())
            layoutParams = android.view.ViewGroup.LayoutParams(
                android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                android.view.ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        val lockIcon = android.widget.ImageView(context).apply {
            setImageResource(android.R.drawable.ic_lock_lock)
            layoutParams = android.widget.LinearLayout.LayoutParams(120, 120).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = 32
            }
            setColorFilter(0xFFCC0000.toInt())
        }

        val titleText = android.widget.TextView(context).apply {
            text = "الجهاز مقفول"
            textSize = 28f
            setTextColor(0xFFFFFFFF.toInt())
            gravity = Gravity.CENTER
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 16
            }
        }

        val bodyText = android.widget.TextView(context).apply {
            text = "جارٍ المقابلة مع السيدة\nلن يُفتح الجهاز حتى تحديد المصير النهائي"
            textSize = 14f
            setTextColor(0xFFCC3333.toInt())
            gravity = Gravity.CENTER
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                leftMargin = 40
                rightMargin = 40
            }
        }

        rootLayout.addView(lockIcon)
        rootLayout.addView(titleText)
        rootLayout.addView(bodyText)
        return rootLayout
    }

    private fun removeLockOverlay() {
        try {
            overlayView?.let { windowManager?.removeView(it) }
            overlayView = null
        } catch (e: Exception) {
            Log.w(TAG, "Remove overlay error: $e")
        }
    }

    // ── الإشعار الأمامي ───────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIF_CHANNEL,
                "قفل المقابلة",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "إشعار نظام قفل المقابلة"
                setShowBadge(false)
            }
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, NOTIF_CHANNEL)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("الجهاز مقفول — وقت المقابلة")
            .setContentText("جارٍ المقابلة مع السيدة")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .build()
    }
}
