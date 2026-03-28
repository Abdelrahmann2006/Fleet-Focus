package com.abdelrahman.panopticon

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore

/**
 * BriefingEnforcerService — بروتوكول الإحاطة الإجبارية
 *
 * يُطلقه المشرف عبر أمر "start_mandatory_briefing" في CommandListenerService.
 * يقوم بـ:
 *  1. فتح رابط عميق (Zoom / Google Meet / Teams) فوراً عبر Intent
 *  2. قفل المستخدم داخل التطبيق المفتوح:
 *     - يستخدم AccessibilityService (MyAccessibilityService.setBriefingLock)
 *       لإعادة الإطلاق فور كشف محاولة الخروج
 *  3. يُسجّل بداية الجلسة في Firestore
 *  4. يُوقف الإجبار عند وصول أمر "end_mandatory_briefing"
 *
 * متطلبات الأمر:
 *   { "type": "start_mandatory_briefing",
 *     "deepLink": "zoomus://zoom.us/join?confno=1234567890",
 *     "sessionName": "إحاطة يومية" }
 */
class BriefingEnforcerService : Service() {

    companion object {
        private const val TAG             = "BriefingEnforcer"
        const val NOTIFICATION_ID         = 8001
        const val CHANNEL_ID              = "briefing_enforcer_channel"
        const val EXTRA_UID               = "uid"
        const val EXTRA_DEEP_LINK         = "deepLink"
        const val EXTRA_SESSION_NAME      = "sessionName"
        const val PREF_FILE               = "focus_prefs"
        const val PREF_UID                = "saved_uid"
        const val PREF_BRIEFING_ACTIVE    = "briefing_active"
        const val PREF_BRIEFING_DEEP_LINK = "briefing_deepLink"

        // فترة إعادة الإطلاق عند كشف الخروج (بالمللي ثانية)
        private const val RE_LAUNCH_DELAY_MS = 1_500L

        fun start(
            context: Context,
            uid: String,
            deepLink: String,
            sessionName: String = "إحاطة إجبارية"
        ) {
            context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE).edit()
                .putBoolean(PREF_BRIEFING_ACTIVE, true)
                .putString(PREF_BRIEFING_DEEP_LINK, deepLink)
                .apply()

            val intent = Intent(context, BriefingEnforcerService::class.java).apply {
                putExtra(EXTRA_UID, uid)
                putExtra(EXTRA_DEEP_LINK, deepLink)
                putExtra(EXTRA_SESSION_NAME, sessionName)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context, uid: String) {
            context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE).edit()
                .putBoolean(PREF_BRIEFING_ACTIVE, false)
                .remove(PREF_BRIEFING_DEEP_LINK)
                .apply()
            context.stopService(Intent(context, BriefingEnforcerService::class.java))
            Log.i(TAG, "✓ الإحاطة الإجبارية انتهت للجهاز $uid")
        }

        fun isBriefingActive(context: Context): Boolean =
            context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                .getBoolean(PREF_BRIEFING_ACTIVE, false)

        fun getBriefingDeepLink(context: Context): String? =
            context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                .getString(PREF_BRIEFING_DEEP_LINK, null)
    }

    private val handler = Handler(Looper.getMainLooper())
    private var uid: String = ""
    private var deepLink: String = ""
    private var sessionName: String = ""
    private var sessionStartTime: Long = 0L

    // مراقب دوري يعيد الإطلاق كل 5 ثوان لتعزيز الإجبار
    private val reEnforceRunnable = object : Runnable {
        override fun run() {
            if (isBriefingActive(this@BriefingEnforcerService)) {
                launchDeepLink()
                handler.postDelayed(this, 5_000L)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startForeground(NOTIFICATION_ID, buildNotification())
        Log.i(TAG, "✓ BriefingEnforcerService بدأ")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        uid = intent?.getStringExtra(EXTRA_UID)
            ?: getSharedPreferences(PREF_FILE, MODE_PRIVATE)
                .getString(PREF_UID, "") ?: ""
        deepLink    = intent?.getStringExtra(EXTRA_DEEP_LINK)    ?: ""
        sessionName = intent?.getStringExtra(EXTRA_SESSION_NAME) ?: "إحاطة إجبارية"

        if (deepLink.isEmpty()) {
            Log.e(TAG, "لا يوجد رابط عميق — إيقاف")
            stopSelf(); return START_NOT_STICKY
        }

        sessionStartTime = System.currentTimeMillis()
        reportSessionStarted()

        // الإطلاق الفوري
        handler.postDelayed({ launchDeepLink() }, 500L)

        // إعادة التأكيد الدوري كل 5 ثوان لمنع الهروب
        handler.postDelayed(reEnforceRunnable, 5_000L)

        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(reEnforceRunnable)
        reportSessionEnded()
        Log.i(TAG, "✓ BriefingEnforcerService أُوقف")
        super.onDestroy()
    }

    // ── إطلاق الرابط العميق ──────────────────────────────────

    private fun launchDeepLink() {
        try {
            val launchIntent = Intent(Intent.ACTION_VIEW, Uri.parse(deepLink)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            }
            startActivity(launchIntent)
            Log.i(TAG, "✓ رابط الإحاطة أُطلق: $deepLink")
        } catch (e: Exception) {
            Log.e(TAG, "فشل إطلاق الرابط العميق: ${e.message}")
            // احتياطي: فتح متصفح الويب
            try {
                val webIntent = Intent(Intent.ACTION_VIEW, Uri.parse(deepLink)).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(webIntent)
            } catch (ex: Exception) {
                Log.e(TAG, "فشل الاحتياطي أيضاً: ${ex.message}")
            }
        }
    }

    // ── تسجيل الجلسة في Firestore ────────────────────────────

    private fun reportSessionStarted() {
        if (uid.isEmpty()) return
        FirebaseFirestore.getInstance()
            .collection("compliance_assets").document(uid)
            .collection("briefing_sessions")
            .add(mapOf(
                "sessionName"  to sessionName,
                "deepLink"     to deepLink,
                "startedAt"    to FieldValue.serverTimestamp(),
                "status"       to "active"
            ))
            .addOnSuccessListener { ref ->
                Log.i(TAG, "✓ جلسة الإحاطة مُسجَّلة: ${ref.id}")
            }

        FirebaseFirestore.getInstance()
            .collection("device_states").document(uid)
            .update(mapOf(
                "briefingActive"  to true,
                "briefingSession" to sessionName,
                "briefingStartAt" to FieldValue.serverTimestamp()
            ))
    }

    private fun reportSessionEnded() {
        if (uid.isEmpty()) return
        val durationMs = System.currentTimeMillis() - sessionStartTime

        FirebaseFirestore.getInstance()
            .collection("device_states").document(uid)
            .update(mapOf(
                "briefingActive"     to false,
                "briefingEndAt"      to FieldValue.serverTimestamp(),
                "briefingDurationMs" to durationMs
            ))
    }

    // ── الإشعار الدائم ────────────────────────────────────────

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID, "الإحاطة الإجبارية",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                setShowBadge(true)
            }
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("📋 إحاطة إجبارية جارية")
            .setContentText("حضور الجلسة إلزامي — لا يمكنك إغلاق التطبيق")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setColor(0xFFC9A84C.toInt())
            .build()
    }
}
