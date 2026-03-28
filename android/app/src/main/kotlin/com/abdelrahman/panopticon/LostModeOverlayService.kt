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
import android.os.CountDownTimer
import android.os.IBinder
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

/**
 * LostModeOverlayService — نافذة قفل الفقدان (System Alert Window / High Priority Layer)
 *
 * عند تفعيل Lost Mode تُعرض شاشة "المصادقة مطلوبة" فوق كل شيء
 * مع عداد تنازلي وحقل إدخال كلمة المرور.
 * لا يمكن إغلاقها إلا بإدخال الـ PIN الصحيح أو بأمر من المشرف.
 */
class LostModeOverlayService : Service() {

    companion object {
        const val TAG = "LostModeOverlay"
        const val NOTIFICATION_ID = 3001
        const val CHANNEL_ID = "lost_mode_channel"
        const val EXTRA_TRIGGER = "trigger_source"
        const val EXTRA_UNLOCK_PIN = "unlock_pin"
        const val PREF_FILE = "focus_prefs"
        const val PREF_LOST_ACTIVE = "lost_mode_active"
        const val PREF_LOST_PIN = "lost_mode_pin"
        const val DEFAULT_COUNTDOWN_MS = 300_000L // 5 دقائق

        fun activate(context: Context, pin: String = "0000") {
            context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(PREF_LOST_ACTIVE, true)
                .putString(PREF_LOST_PIN, pin)
                .apply()

            val intent = Intent(context, LostModeOverlayService::class.java)
                .putExtra(EXTRA_UNLOCK_PIN, pin)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun deactivate(context: Context) {
            context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(PREF_LOST_ACTIVE, false)
                .apply()
            context.stopService(Intent(context, LostModeOverlayService::class.java))
        }

        fun isActive(context: Context): Boolean =
            context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                .getBoolean(PREF_LOST_ACTIVE, false)
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var countdownTimer: CountDownTimer? = null
    private var unlockPin: String = "0000"

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startForeground(NOTIFICATION_ID, buildNotification())
        Log.i(TAG, "✓ Lost Mode Overlay Service بدأ")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        unlockPin = intent?.getStringExtra(EXTRA_UNLOCK_PIN)
            ?: getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                .getString(PREF_LOST_PIN, "0000") ?: "0000"

        if (Settings.canDrawOverlays(this)) {
            showOverlay()
        } else {
            Log.e(TAG, "لا توجد صلاحية SYSTEM_ALERT_WINDOW — Overlay لن تُعرض")
        }

        return START_STICKY
    }

    override fun onDestroy() {
        countdownTimer?.cancel()
        removeOverlay()
        Log.i(TAG, "Lost Mode Overlay أُوقف")
        super.onDestroy()
    }

    private fun showOverlay() {
        removeOverlay()

        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        windowManager = wm

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_SYSTEM_ALERT

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                    or WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                    or WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                    or WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
        }

        val view = buildOverlayView()
        overlayView = view

        try {
            wm.addView(view, params)
            Log.i(TAG, "✓ نافذة Lost Mode عُرضت")
            startCountdown(view)
        } catch (e: Exception) {
            Log.e(TAG, "فشل عرض Overlay: ${e.message}")
        }
    }

    private fun buildOverlayView(): View {
        val ctx = this

        val root = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#E8000000"))
            setPadding(60, 80, 60, 80)
        }

        // أيقونة القفل
        val lockIcon = TextView(ctx).apply {
            text = "🔒"
            textSize = 72f
            gravity = Gravity.CENTER
        }
        root.addView(lockIcon)

        val sp4 = View(ctx).apply { minimumHeight = 24 }
        root.addView(sp4)

        // عنوان رئيسي
        val title = TextView(ctx).apply {
            text = "الجهاز محجوب"
            textSize = 28f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        }
        root.addView(title)

        val sp1 = View(ctx).apply { minimumHeight = 12 }
        root.addView(sp1)

        // عنوان فرعي
        val subtitle = TextView(ctx).apply {
            text = "المصادقة مطلوبة"
            textSize = 16f
            setTextColor(Color.parseColor("#AAAAAA"))
            gravity = Gravity.CENTER
        }
        root.addView(subtitle)

        val sp2 = View(ctx).apply { minimumHeight = 32 }
        root.addView(sp2)

        // العداد التنازلي
        val countdown = TextView(ctx).apply {
            tag = "countdown"
            text = "05:00"
            textSize = 48f
            setTextColor(Color.parseColor("#FF4444"))
            gravity = Gravity.CENTER
            typeface = android.graphics.Typeface.MONOSPACE
        }
        root.addView(countdown)

        val sp3 = View(ctx).apply { minimumHeight = 8 }
        root.addView(sp3)

        val countdownLabel = TextView(ctx).apply {
            text = "الوقت المتبقي للتأمين التلقائي"
            textSize = 12f
            setTextColor(Color.parseColor("#888888"))
            gravity = Gravity.CENTER
        }
        root.addView(countdownLabel)

        val sp5 = View(ctx).apply { minimumHeight = 40 }
        root.addView(sp5)

        // حقل PIN
        val pinField = EditText(ctx).apply {
            hint = "أدخل رمز التحقق"
            setHintTextColor(Color.parseColor("#666666"))
            setTextColor(Color.WHITE)
            textSize = 20f
            gravity = Gravity.CENTER
            inputType = android.text.InputType.TYPE_CLASS_NUMBER or
                    android.text.InputType.TYPE_NUMBER_VARIATION_PASSWORD
            setBackgroundColor(Color.parseColor("#333333"))
            setPadding(32, 24, 32, 24)
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.parseColor("#222222"))
                setStroke(2, Color.parseColor("#C9A84C"))
                cornerRadius = 12f
            }
        }
        root.addView(pinField, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ))

        val sp6 = View(ctx).apply { minimumHeight = 20 }
        root.addView(sp6)

        // زر التحقق
        val verifyBtn = Button(ctx).apply {
            text = "تحقق وفتح"
            textSize = 16f
            setTextColor(Color.parseColor("#0D0D0D"))
            setBackgroundColor(Color.parseColor("#C9A84C"))
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.parseColor("#C9A84C"))
                cornerRadius = 12f
            }
        }
        verifyBtn.setOnClickListener {
            val entered = pinField.text.toString().trim()
            if (entered == unlockPin) {
                Log.i(TAG, "✓ PIN صحيح — إلغاء Lost Mode")
                deactivate(ctx)
            } else {
                pinField.error = "رمز خاطئ"
                pinField.setText("")
                Log.w(TAG, "محاولة PIN فاشلة")
            }
        }
        root.addView(verifyBtn, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ))

        val sp7 = View(ctx).apply { minimumHeight = 32 }
        root.addView(sp7)

        // معلومات تواصل
        val contact = TextView(ctx).apply {
            text = "للمساعدة: تواصل مع مشرف النظام"
            textSize = 12f
            setTextColor(Color.parseColor("#555555"))
            gravity = Gravity.CENTER
        }
        root.addView(contact)

        // السماح بالتركيز لحقل الإدخال
        params@ root.isFocusableInTouchMode = true
        pinField.isFocusableInTouchMode = true

        return root
    }

    private fun startCountdown(view: View) {
        countdownTimer?.cancel()
        countdownTimer = object : CountDownTimer(DEFAULT_COUNTDOWN_MS, 1000) {
            override fun onTick(millisUntilFinished: Long) {
                val minutes = millisUntilFinished / 60000
                val seconds = (millisUntilFinished % 60000) / 1000
                val text = String.format("%02d:%02d", minutes, seconds)
                try {
                    val tv = view.findViewWithTag<TextView>("countdown")
                    tv?.post { tv.text = text }
                } catch (e: Exception) { /* النافذة أُغلقت */ }
            }

            override fun onFinish() {
                Log.w(TAG, "انتهى العداد — الجهاز لا يزال محجوباً حتى يُطلقه المشرف")
                try {
                    val tv = view.findViewWithTag<TextView>("countdown")
                    tv?.post { tv.text = "00:00" }
                } catch (e: Exception) { /* تجاهل */ }
            }
        }.start()
    }

    private fun removeOverlay() {
        try {
            overlayView?.let { windowManager?.removeView(it) }
        } catch (e: Exception) { /* تجاهل إذا لم تُضَف */ }
        overlayView = null
    }

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID,
                "وضع الفقدان",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "الجهاز في وضع الفقدان — تواصل مع المشرف"
                setShowBadge(true)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🔒 الجهاز محجوب — Lost Mode")
            .setContentText("تواصل مع مشرف النظام لإلغاء التأمين")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setColor(0xFFFF4444.toInt())
            .build()
    }
}
