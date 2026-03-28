package com.abdelrahman.panopticon

import android.content.ComponentName
import android.content.SharedPreferences
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FieldValue

/**
 * NotificationScannerService — خدمة اعتراض الإشعارات
 *
 * تستمع لكل إشعار يصل إلى الجهاز وتُحلِّل محتواه:
 *  1. فحص DLP — تطابق الكلمات المفتاحية في عنوان/نص الإشعار
 *  2. كشف التطبيقات المشبوهة — إشعارات من تطبيقات غير مصرَّح بها
 *  3. رفع التنبيهات لـ Firestore تحت `compliance_assets/{uid}/notification_alerts`
 *
 * مُفعَّلة فقط بعد منح إذن BIND_NOTIFICATION_LISTENER_SERVICE من إعدادات النظام.
 */
class NotificationScannerService : NotificationListenerService() {

    companion object {
        private const val TAG            = "NotificationScanner"
        private const val PREF_FILE      = CommandListenerService.PREF_FILE
        private const val PREF_UID       = CommandListenerService.PREF_UID
        private const val PREF_ENABLED   = "notification_scanner_enabled"

        /** الكلمات المفتاحية الحساسة — تُطابَق بغض النظر عن الحالة */
        private val DLP_KEYWORDS = listOf(
            "password", "كلمة مرور", "secret", "سري",
            "token", "api key", "otp", "رمز", "pin",
            "credential", "بيانات دخول", "login", "تسجيل دخول",
            "bank", "بنك", "iban", "swift", "حساب",
            "location", "موقع", "coordinates", "إحداثيات",
            "telegram", "whatsapp", "واتساب", "signal",
        )

        /** التطبيقات المشبوهة التي يُبلَّغ عنها فوراً */
        private val SUSPICIOUS_PACKAGES = setOf(
            "org.telegram.messenger",
            "com.whatsapp",
            "org.thoughtcrime.securesms",   // Signal
            "com.viber.voip",
            "com.discord",
            "com.skype.raider",
        )

        fun isEnabled(prefs: SharedPreferences): Boolean =
            prefs.getBoolean(PREF_ENABLED, true)

        fun setEnabled(prefs: SharedPreferences, enabled: Boolean) =
            prefs.edit().putBoolean(PREF_ENABLED, enabled).apply()
    }

    private val db by lazy { FirebaseFirestore.getInstance() }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.i(TAG, "✓ مستمع الإشعارات متصل")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.w(TAG, "مستمع الإشعارات انقطع")
        // إعادة الاتصال تلقائياً
        try {
            requestRebind(ComponentName(this, NotificationScannerService::class.java))
        } catch (e: Exception) {
            Log.w(TAG, "فشلت إعادة الربط: ${e.message}")
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return

        val prefs = getSharedPreferences(PREF_FILE, MODE_PRIVATE)
        if (!isEnabled(prefs)) return

        val uid = prefs.getString(PREF_UID, null) ?: return
        val pkg = sbn.packageName ?: return

        // تجاهل إشعارات تطبيقنا نفسنا
        if (pkg == applicationContext.packageName) return

        val extras      = sbn.notification?.extras ?: return
        val title       = extras.getString("android.title") ?: ""
        val text        = extras.getCharSequence("android.text")?.toString() ?: ""
        val bigText     = extras.getCharSequence("android.bigText")?.toString() ?: text
        val fullContent = "$title $bigText".lowercase()

        val matchedKeywords = DLP_KEYWORDS.filter { fullContent.contains(it.lowercase()) }
        val isSuspiciousApp = pkg in SUSPICIOUS_PACKAGES

        if (matchedKeywords.isEmpty() && !isSuspiciousApp) return

        Log.w(TAG, "⚠ إشعار مُعلَّم — التطبيق: $pkg | الكلمات: $matchedKeywords")

        val alert = hashMapOf(
            "type"             to "notification_scan",
            "packageName"      to pkg,
            "appLabel"         to getAppLabel(pkg),
            "title"            to title,
            "preview"          to bigText.take(200),
            "matchedKeywords"  to matchedKeywords,
            "isSuspiciousApp"  to isSuspiciousApp,
            "severity"         to if (isSuspiciousApp) "high" else "medium",
            "timestamp"        to FieldValue.serverTimestamp(),
            "postedAt"         to sbn.postTime,
        )

        db.collection("compliance_assets")
            .document(uid)
            .collection("notification_alerts")
            .add(alert)
            .addOnFailureListener { e ->
                Log.w(TAG, "فشل رفع تنبيه الإشعار: ${e.message}")
            }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // لا نحتاج لمعالجة الإشعارات المُزالة حالياً
    }

    private fun getAppLabel(packageName: String): String {
        return try {
            val info = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (_: Exception) {
            packageName
        }
    }
}
