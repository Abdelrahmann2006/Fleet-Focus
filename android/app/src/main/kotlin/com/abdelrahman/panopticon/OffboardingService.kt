package com.abdelrahman.panopticon

import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore

/**
 * OffboardingService — خدمة إنهاء تعيين الجهاز (Ghost State & Full Release)
 *
 * دورة حياة الجهاز:
 *   ACTIVE → GHOST → RELEASED
 *
 * Ghost State (الحالة الشبحية):
 *   - يُحافظ على جميع قيود الأمان
 *   - يُعطّل الخدمات غير الضرورية (Snap Check-in, WebRTC, DLP)
 *   - يُعطّل تحديثات اللوحة
 *   - يُبقي CommandListenerService نشطاً للأوامر الطارئة فقط
 *   - يُسجّل الجهاز كـ "archived" في Firestore
 *
 * Full Release (الإفراج الكامل):
 *   - يُزيل جميع قيود Device Admin
 *   - يُفصل Device Admin نهائياً
 *   - يُوقف جميع الخدمات الخلفية
 *   - يُسجّل الجهاز كـ "released" في Firestore
 *
 * يتطلب موافقة صريحة من المشرف في كلتا الحالتين
 */
object OffboardingService {

    private const val TAG = "OffboardingService"

    // حالات الجهاز
    const val STATE_ACTIVE = "active"
    const val STATE_GHOST = "ghost"
    const val STATE_RELEASED = "released"

    private const val PREF_FILE = "focus_prefs"
    private const val PREF_ASSET_STATE = "asset_state"

    // ── Ghost State ───────────────────────────────────────────

    /**
     * يُحوّل الجهاز إلى الحالة الشبحية (Ghost State)
     * - يُحافظ على الأمان
     * - يُعطّل الخدمات غير الضرورية
     */
    fun initiateGhostState(context: Context, uid: String) {
        Log.i(TAG, "⚪ تفعيل Ghost State للجهاز $uid")

        // حفظ الحالة محلياً
        context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE).edit()
            .putString(PREF_ASSET_STATE, STATE_GHOST)
            .apply()

        // إيقاف الخدمات غير الضرورية
        stopNonEssentialServices(context)

        // تحديث Firestore
        val ghostData = mapOf(
            "assetState" to STATE_GHOST,
            "ghostActivatedAt" to FieldValue.serverTimestamp(),
            "ghostUid" to uid,
            "securityBlocksActive" to true,
            "commandListenerActive" to true,
            "snapCheckinEnabled" to false,
            "dlpMonitorEnabled" to false,
            "telemetryEnabled" to false,
        )

        FirebaseFirestore.getInstance()
            .collection("device_states")
            .document(uid)
            .update(ghostData)
            .addOnSuccessListener {
                Log.i(TAG, "✓ Ghost State مُسجَّل في Firestore")
            }

        // تسجيل في compliance_assets للتدقيق
        FirebaseFirestore.getInstance()
            .collection("compliance_assets")
            .document(uid)
            .collection("lifecycle_events")
            .add(mapOf(
                "event" to "ghost_state_activated",
                "timestamp" to FieldValue.serverTimestamp(),
                "initiatedBy" to "remote_admin"
            ))

        Log.i(TAG, "✓ Ghost State مُفعَّل — الجهاز في وضع الأرشفة")
    }

    /**
     * يُنفّذ الإفراج الكامل عن الجهاز (Full Release)
     * لا يمكن التراجع عن هذا الإجراء
     */
    fun executeFullRelease(context: Context, uid: String) {
        Log.i(TAG, "🔓 تنفيذ Full Release للجهاز $uid")

        // 1. رفع إلى Firestore قبل أي شيء (إذا فشلت بقية الخطوات)
        val releaseData = mapOf(
            "assetState" to STATE_RELEASED,
            "releasedAt" to FieldValue.serverTimestamp(),
            "securityBlocksActive" to false,
            "commandListenerActive" to false,
        )

        FirebaseFirestore.getInstance()
            .collection("device_states")
            .document(uid)
            .update(releaseData)

        // تسجيل في compliance_assets
        FirebaseFirestore.getInstance()
            .collection("compliance_assets")
            .document(uid)
            .collection("lifecycle_events")
            .add(mapOf(
                "event" to "full_release_executed",
                "timestamp" to FieldValue.serverTimestamp(),
                "uid" to uid
            ))

        // 2. رفع جميع قيود Device Admin
        MyDeviceAdminReceiver.clearAllRestrictions(context)
        Log.i(TAG, "✓ القيود المؤسسية مُزالة")

        // 3. إيقاف جميع الخدمات الخلفية
        stopAllServices(context)
        Log.i(TAG, "✓ جميع الخدمات أُوقفت")

        // 4. إلغاء ربط Device Admin — يتطلب نشاطاً في المقدمة
        // لا يمكن استدعاء removeActiveAdmin من خدمة خلفية
        // — يُرسل Intent لـ MainActivity لإتمام الفصل
        val releaseIntent = Intent("com.abdelrahman.panopticon.FULL_RELEASE")
        releaseIntent.setPackage(context.packageName)
        context.sendBroadcast(releaseIntent)
        Log.i(TAG, "✓ Full Release Broadcast أُرسل لـ MainActivity")

        // 5. تحديث الحالة المحلية
        context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE).edit()
            .putString(PREF_ASSET_STATE, STATE_RELEASED)
            .apply()

        Log.i(TAG, "✓ Full Release مكتمل")
    }

    // ── مساعدات ────────────────────────────────────────────────

    private fun stopNonEssentialServices(context: Context) {
        // إيقاف تسجيل الشاشة إذا كان نشطاً
        if (ScreenRecordingService.isCurrentlyRecording()) {
            ScreenRecordingService.stop(context)
        }
        // إيقاف GeofenceMonitor (في Ghost State — الجهاز مؤرشف)
        GeofenceMonitorService.stop(context)
        Log.i(TAG, "✓ الخدمات غير الضرورية أُوقفت")
    }

    private fun stopAllServices(context: Context) {
        stopNonEssentialServices(context)
        GeofenceMonitorService.stop(context)
        TelemetryPublisherService.stop(context)
        context.stopService(Intent(context, CommandListenerService::class.java))
        Log.i(TAG, "✓ جميع الخدمات أُوقفت")
    }

    /**
     * يُعيد الحالة الحالية للجهاز
     */
    fun getCurrentState(context: Context): String {
        return context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
            .getString(PREF_ASSET_STATE, STATE_ACTIVE) ?: STATE_ACTIVE
    }

    fun isGhostState(context: Context): Boolean =
        getCurrentState(context) == STATE_GHOST

    fun isReleased(context: Context): Boolean =
        getCurrentState(context) == STATE_RELEASED
}
