package com.abdelrahman.panopticon

import android.app.admin.DevicePolicyManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.CallLog
import android.telecom.TelecomManager
import android.telephony.TelephonyManager
import android.util.Log

/**
 * IncomingCallLockdownReceiver — بروتوكول الانتعاش خارج النطاق (OOB)
 *
 * عند استقبال مكالمة واردة من رقم المشرف المعتمد:
 *  1. يُطلق قفل الجهاز الكامل فوراً عبر DevicePolicyManager.lockNow()
 *  2. يُنهي المكالمة فوراً عبر TelecomManager (لأسباب أمنية)
 *  3. يُفعّل Lost Mode إذا كان الجهاز في حالة سرقة
 *
 * يعمل حتى بدون اتصال بالإنترنت (OOB = Out-Of-Band)
 * سجَّل في AndroidManifest تحت:
 *   <receiver android:name=".IncomingCallLockdownReceiver">
 *     <intent-filter>
 *       <action android:name="android.intent.action.PHONE_STATE"/>
 *     </intent-filter>
 *   </receiver>
 */
class IncomingCallLockdownReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "OOB_LockdownReceiver"
        private const val PREF_FILE = "focus_prefs"
        private const val PREF_ADMIN_PHONE = "admin_phone_number"
        private const val PREF_OOB_ENABLED = "oob_lockdown_enabled"

        fun saveAdminPhone(context: Context, phone: String) {
            context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                .edit()
                .putString(PREF_ADMIN_PHONE, phone)
                .putBoolean(PREF_OOB_ENABLED, true)
                .apply()
            Log.i(TAG, "رقم المشرف المحفوظ: $phone")
        }

        fun getAdminPhone(context: Context): String? =
            context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                .getString(PREF_ADMIN_PHONE, null)

        fun isOobEnabled(context: Context): Boolean =
            context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                .getBoolean(PREF_OOB_ENABLED, false)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return
        if (!isOobEnabled(context)) return

        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        if (state != TelephonyManager.EXTRA_STATE_RINGING) return

        val incomingNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
            ?: return

        val adminPhone = getAdminPhone(context) ?: return

        if (!phoneNumbersMatch(incomingNumber, adminPhone)) {
            Log.d(TAG, "مكالمة من رقم غير معتمد: $incomingNumber")
            return
        }

        Log.w(TAG, "⚡ OOB: مكالمة من المشرف المعتمد — بدء قفل الطوارئ!")

        // 1. قفل الجهاز فوراً
        triggerEmergencyLockdown(context)

        // 2. إنهاء المكالمة فوراً (لأسباب أمنية)
        terminateIncomingCall(context)

        // 3. مسح سجل المكالمة (بعد 2 ثانية لمنح النظام وقت تسجيلها)
        Handler(Looper.getMainLooper()).postDelayed({
            deleteCallLogEntry(context, incomingNumber)
        }, 2_000L)

        // 4. تفعيل نافذة Lost Mode التراكبية
        triggerLostModeOverlay(context)
    }

    private fun phoneNumbersMatch(incoming: String, admin: String): Boolean {
        val normalize = { n: String -> n.replace(Regex("[^0-9+]"), "") }
        val inNorm = normalize(incoming)
        val adNorm = normalize(admin)
        return inNorm == adNorm ||
                inNorm.endsWith(adNorm.takeLast(9)) ||
                adNorm.endsWith(inNorm.takeLast(9))
    }

    private fun triggerEmergencyLockdown(context: Context) {
        try {
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE)
                    as DevicePolicyManager
            val comp = ComponentName(context, MyDeviceAdminReceiver::class.java)
            if (dpm.isAdminActive(comp)) {
                dpm.lockNow()
                Log.i(TAG, "✓ قفل الطوارئ نُفِّذ بنجاح")
            } else {
                Log.e(TAG, "Device Admin غير مفعّل — القفل فشل")
            }
        } catch (e: Exception) {
            Log.e(TAG, "خطأ في تنفيذ القفل: ${e.message}")
        }
    }

    private fun terminateIncomingCall(context: Context) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val telecom = context.getSystemService(Context.TELECOM_SERVICE)
                        as TelecomManager
                telecom.endCall()
                Log.i(TAG, "✓ المكالمة أُنهيت فوراً عبر TelecomManager")
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "لا صلاحية إنهاء المكالمة: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "خطأ في إنهاء المكالمة: ${e.message}")
        }
    }

    private fun deleteCallLogEntry(context: Context, phoneNumber: String) {
        try {
            val normalized = phoneNumber.replace(Regex("[^0-9+]"), "")
            val deleted = context.contentResolver.delete(
                CallLog.Calls.CONTENT_URI,
                "${CallLog.Calls.NUMBER} LIKE ? OR ${CallLog.Calls.NUMBER} LIKE ?",
                arrayOf("%${normalized.takeLast(9)}", "%${normalized.takeLast(7)}")
            )
            Log.i(TAG, "✓ سجل المكالمة مُحذوف — السجلات المحذوفة: $deleted")
        } catch (e: SecurityException) {
            Log.w(TAG, "لا صلاحية حذف سجل المكالمة: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "خطأ في حذف سجل المكالمة: ${e.message}")
        }
    }

    private fun triggerLostModeOverlay(context: Context) {
        val overlayIntent = Intent(context, LostModeOverlayService::class.java).apply {
            putExtra(LostModeOverlayService.EXTRA_TRIGGER, "oob_call")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(overlayIntent)
        } else {
            context.startService(overlayIntent)
        }
        Log.i(TAG, "✓ تم تشغيل Lost Mode Overlay")
    }
}
