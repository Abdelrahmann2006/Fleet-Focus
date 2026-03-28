package com.abdelrahman.panopticon

import android.content.Context
import android.util.Log
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore

/**
 * TravelPassManager — مدير تصاريح التنقل
 *
 * يُدير حالة Travel Pass الممنوحة للمشارك للخروج المؤقت من النطاق الجغرافي.
 *
 * يُخزَّن التصريح في SharedPreferences للاستخدام الفوري بدون إنترنت،
 * ويُرفع لـ Firestore للمزامنة مع لوحة المشرف.
 *
 * الوقت الافتراضي للتصريح: ساعتان (7200 ثانية)
 */
object TravelPassManager {

    private const val TAG = "TravelPassManager"
    private const val PREF_FILE = "focus_prefs"
    private const val PREF_PASS_ACTIVE = "travel_pass_active"
    private const val PREF_PASS_EXPIRY = "travel_pass_expiry"
    private const val PREF_PASS_REASON = "travel_pass_reason"

    /**
     * يُفعّل تصريح التنقل لمدة [durationHours] ساعة
     */
    fun activate(context: Context, uid: String, durationHours: Int = 2, reason: String = "مجاز") {
        val expiry = System.currentTimeMillis() + (durationHours * 3600 * 1000L)

        context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE).edit().apply {
            putBoolean(PREF_PASS_ACTIVE, true)
            putLong(PREF_PASS_EXPIRY, expiry)
            putString(PREF_PASS_REASON, reason)
            apply()
        }

        // رفع الحالة لـ Firestore
        FirebaseFirestore.getInstance()
            .collection("geofence_config")
            .document(uid)
            .update(mapOf(
                "travelPassActive" to true,
                "travelPassExpiry" to expiry,
                "travelPassReason" to reason,
                "travelPassGrantedAt" to FieldValue.serverTimestamp()
            ))
            .addOnSuccessListener { Log.i(TAG, "✓ Travel Pass مُفعَّل ($durationHours ساعة)") }

        Log.i(TAG, "✓ Travel Pass محلي مُفعَّل حتى: ${java.util.Date(expiry)}")
    }

    /**
     * يُلغي تصريح التنقل فوراً
     */
    fun revoke(context: Context, uid: String) {
        context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE).edit().apply {
            putBoolean(PREF_PASS_ACTIVE, false)
            putLong(PREF_PASS_EXPIRY, 0L)
            remove(PREF_PASS_REASON)
            apply()
        }

        FirebaseFirestore.getInstance()
            .collection("geofence_config")
            .document(uid)
            .update(mapOf(
                "travelPassActive" to false,
                "travelPassExpiry" to 0,
                "travelPassRevokedAt" to FieldValue.serverTimestamp()
            ))
            .addOnSuccessListener { Log.i(TAG, "✓ Travel Pass مُلغى") }

        Log.i(TAG, "Travel Pass مُلغى")
    }

    /**
     * يُعيد ما إذا كان تصريح التنقل مفعّلاً وصالحاً
     */
    fun isActive(context: Context, uid: String): Boolean {
        val prefs = context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
        val isActive = prefs.getBoolean(PREF_PASS_ACTIVE, false)
        val expiry = prefs.getLong(PREF_PASS_EXPIRY, 0L)

        if (!isActive) return false

        val now = System.currentTimeMillis()
        if (now > expiry) {
            // انتهى التصريح — تنظيف تلقائي
            revoke(context, uid)
            Log.i(TAG, "Travel Pass انتهت مدته — مُلغى تلقائياً")
            return false
        }

        return true
    }

    /**
     * يُعيد وقت انتهاء التصريح بتنسيق مقروء
     */
    fun getExpiryFormatted(context: Context): String {
        val expiry = context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
            .getLong(PREF_PASS_EXPIRY, 0L)
        return if (expiry > 0) {
            java.text.SimpleDateFormat("HH:mm - dd/MM", java.util.Locale.US)
                .format(java.util.Date(expiry))
        } else {
            "غير مفعّل"
        }
    }

    /**
     * يُعيد سبب التصريح
     */
    fun getReason(context: Context): String {
        return context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
            .getString(PREF_PASS_REASON, "غير محدد") ?: "غير محدد"
    }
}
