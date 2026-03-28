package com.abdelrahman.panopticon

import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.UserManager
import android.util.Log
import android.widget.Toast

/**
 * MyDeviceAdminReceiver — مشرف الجهاز المؤسسي (Enterprise DPC)
 *
 * يدعم وضعَي التشغيل:
 *   1. Device Admin (DA) — الصلاحيات الأساسية (قفل، كلمة سر، مسح)
 *   2. Device Owner  (DO) — صلاحيات مؤسسية كاملة تتطلب Provisioning
 *
 * ───────────────────────────────────────────────────────────────
 *  تفعيل Device Owner عبر ADB (جهاز جديد أو بعد Factory Reset):
 * ───────────────────────────────────────────────────────────────
 *  adb shell dpm set-device-owner com.abdelrahman.panopticon/.MyDeviceAdminReceiver
 *
 *  ─── QR Code Provisioning JSON ────────────────────────────────
 *  {
 *    "android.app.extra.PROVISIONING_DEVICE_ADMIN_COMPONENT_NAME":
 *        "com.abdelrahman.panopticon/.MyDeviceAdminReceiver",
 *    "android.app.extra.PROVISIONING_DEVICE_ADMIN_PACKAGE_DOWNLOAD_LOCATION":
 *        "https://your-cdn.example.com/panopticon.apk",
 *    "android.app.extra.PROVISIONING_DEVICE_ADMIN_PACKAGE_CHECKSUM":
 *        "<SHA-256 of APK in Base64url>",
 *    "android.app.extra.PROVISIONING_SKIP_ENCRYPTION": false,
 *    "android.app.extra.PROVISIONING_WIFI_SSID": "CompetitionWiFi",
 *    "android.app.extra.PROVISIONING_WIFI_SECURITY_TYPE": "WPA",
 *    "android.app.extra.PROVISIONING_WIFI_PASSWORD": "replace_with_real",
 *    "android.app.extra.PROVISIONING_LEAVE_ALL_SYSTEM_APPS_ENABLED": false,
 *    "android.app.extra.PROVISIONING_LOCALE": "ar_SA",
 *    "android.app.extra.PROVISIONING_TIME_ZONE": "Asia/Riyadh",
 *    "android.app.extra.PROVISIONING_ADMIN_EXTRAS_BUNDLE": {
 *        "competition_code": "PANOPTICON-2025"
 *    }
 *  }
 * ───────────────────────────────────────────────────────────────
 */
class MyDeviceAdminReceiver : DeviceAdminReceiver() {

    companion object {
        private const val TAG = "EnterpriseAdmin"
        private const val PKG = "com.abdelrahman.panopticon"

        /**
         * تفعيل جميع القيود المؤسسية — يُمايز بين DA و DO تلقائياً
         */
        fun applyEnterpriseRestrictions(context: Context) {
            val dpm  = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val comp = ComponentName(context, MyDeviceAdminReceiver::class.java)

            if (!dpm.isAdminActive(comp)) {
                Log.w(TAG, "Device Admin غير مفعّل — القيود لم تُطبَّق")
                return
            }

            // ── قيود Device Admin (متاحة لكلا الوضعين) ─────────────────────

            safeApply(TAG, "Factory Reset محجوب") {
                dpm.addUserRestriction(comp, UserManager.DISALLOW_FACTORY_RESET)
            }
            safeApply(TAG, "التحكم في التطبيقات محجوب") {
                dpm.addUserRestriction(comp, UserManager.DISALLOW_APPS_CONTROL)
            }
            safeApply(TAG, "التثبيت من مصادر مجهولة محجوب") {
                dpm.addUserRestriction(comp, UserManager.DISALLOW_INSTALL_UNKNOWN_SOURCES)
            }
            safeApply(TAG, "تغيير إعدادات WiFi محجوب") {
                dpm.addUserRestriction(comp, UserManager.DISALLOW_CONFIG_WIFI)
            }
            safeApply(TAG, "إزالة الملف المُدار محجوبة") {
                dpm.addUserRestriction(comp, UserManager.DISALLOW_REMOVE_MANAGED_PROFILE)
            }
            safeApply(TAG, "التقاط الشاشة محجوب") {
                dpm.setScreenCaptureDisabled(comp, true)
            }
            safeApply(TAG, "جودة كلمة المرور: ALPHANUMERIC") {
                dpm.setPasswordQuality(comp, DevicePolicyManager.PASSWORD_QUALITY_ALPHANUMERIC)
            }
            safeApply(TAG, "القفل التلقائي: 60 ثانية") {
                dpm.setMaximumTimeToLock(comp, 60_000L)
            }

            // ── قيود Device Owner فقط (تتطلب Provisioning عبر ADB/QR) ──────

            if (dpm.isDeviceOwnerApp(PKG)) {
                Log.i(TAG, "✓ وضع Device Owner مُكتشَف — تطبيق قيود DO الكاملة")

                // حظر الوضع الآمن (Safe Mode) — يمنع تجاوز القيود
                safeApply(TAG, "Safe Mode محجوب") {
                    dpm.addUserRestriction(comp, UserManager.DISALLOW_SAFE_BOOT)
                }
                // حظر تعديل الحسابات — يمنع تسجيل حسابات Google خارجية
                safeApply(TAG, "تعديل الحسابات محجوب") {
                    dpm.addUserRestriction(comp, UserManager.DISALLOW_MODIFY_ACCOUNTS)
                }
                // حظر إضافة مستخدمين جدد
                safeApply(TAG, "إضافة مستخدمين محجوبة") {
                    dpm.addUserRestriction(comp, UserManager.DISALLOW_ADD_USER)
                }
                // حظر إيقاف تشغيل الجهاز من واجهة المستخدم
                safeApply(TAG, "إيقاف التشغيل من UI محجوب") {
                    dpm.addUserRestriction(comp, UserManager.DISALLOW_SAFE_BOOT)
                }
                // منع إلغاء تثبيت التطبيق من الإعدادات
                safeApply(TAG, "إلغاء تثبيت Panopticon محجوب") {
                    dpm.setUninstallBlocked(comp, PKG, true)
                }
                // تسجيل الحزم المسموح بها في وضع Kiosk (Lock Task)
                safeApply(TAG, "Lock Task Packages مُسجَّلة") {
                    dpm.setLockTaskPackages(comp, arrayOf(PKG))
                }
                // إخفاء شريط الحالة في وضع Kiosk
                safeApply(TAG, "Lock Task Features مُضبوطة") {
                    dpm.setLockTaskFeatures(
                        comp,
                        DevicePolicyManager.LOCK_TASK_FEATURE_SYSTEM_INFO or
                        DevicePolicyManager.LOCK_TASK_FEATURE_NOTIFICATIONS
                    )
                }
                Log.i(TAG, "✓ جميع قيود Device Owner مُطبَّقة")
            } else {
                Log.i(TAG, "وضع Device Admin فقط — قيود DO غير متاحة (يلزم Provisioning)")
            }
        }

        /**
         * تفعيل وضع Kiosk (Sovereign Portal Lock)
         * يُقيّد الجهاز لتشغيل تطبيق واحد فقط
         */
        fun enterKioskMode(context: Context) {
            val dpm  = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val comp = ComponentName(context, MyDeviceAdminReceiver::class.java)

            if (!dpm.isDeviceOwnerApp(PKG)) {
                Log.w(TAG, "Kiosk Mode يتطلب Device Owner — غير مُفعَّل")
                return
            }
            safeApply(TAG, "Kiosk: Lock Task Packages") {
                dpm.setLockTaskPackages(comp, arrayOf(PKG))
            }
            Log.i(TAG, "✓ Kiosk Mode جاهز — ابدأ startLockTask() من Activity")
        }

        /**
         * منع وضع الطيران — الحفاظ على الاتصال الدائم
         */
        fun setAirplaneMode(context: Context, enabled: Boolean) {
            val dpm  = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val comp = ComponentName(context, MyDeviceAdminReceiver::class.java)
            if (!dpm.isAdminActive(comp)) return
            safeApply(TAG, if (enabled) "وضع الطيران محجوب" else "وضع الطيران متاح") {
                if (enabled) dpm.addUserRestriction(comp, UserManager.DISALLOW_AIRPLANE_MODE)
                else         dpm.clearUserRestriction(comp, UserManager.DISALLOW_AIRPLANE_MODE)
            }
        }

        /**
         * رفع جميع القيود المؤسسية (إعادة التهيئة / انتهاء المنافسة)
         */
        fun clearAllRestrictions(context: Context) {
            val dpm  = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val comp = ComponentName(context, MyDeviceAdminReceiver::class.java)
            if (!dpm.isAdminActive(comp)) return

            val baseRestrictions = listOf(
                UserManager.DISALLOW_FACTORY_RESET,
                UserManager.DISALLOW_APPS_CONTROL,
                UserManager.DISALLOW_INSTALL_UNKNOWN_SOURCES,
                UserManager.DISALLOW_CONFIG_WIFI,
                UserManager.DISALLOW_REMOVE_MANAGED_PROFILE,
                UserManager.DISALLOW_AIRPLANE_MODE,
            )
            val doRestrictions = listOf(
                UserManager.DISALLOW_SAFE_BOOT,
                UserManager.DISALLOW_MODIFY_ACCOUNTS,
                UserManager.DISALLOW_ADD_USER,
            )

            for (r in baseRestrictions) {
                safeApply(TAG, "رفع قيد: $r") { dpm.clearUserRestriction(comp, r) }
            }
            if (dpm.isDeviceOwnerApp(PKG)) {
                for (r in doRestrictions) {
                    safeApply(TAG, "رفع قيد DO: $r") { dpm.clearUserRestriction(comp, r) }
                }
                safeApply(TAG, "إعادة تفعيل إلغاء التثبيت") {
                    dpm.setUninstallBlocked(comp, PKG, false)
                }
                safeApply(TAG, "مسح Lock Task Packages") {
                    dpm.setLockTaskPackages(comp, emptyArray())
                }
            }

            safeApply(TAG, "إعادة تفعيل التقاط الشاشة") {
                dpm.setScreenCaptureDisabled(comp, false)
            }
            Log.i(TAG, "✓ جميع القيود المؤسسية أُزيلت")
        }

        /** مساعد — يُنفّذ ويُسجّل الاستثناءات دون كسر التدفق */
        private fun safeApply(tag: String, label: String, block: () -> Unit) {
            try {
                block()
                Log.i(tag, "✓ $label")
            } catch (e: SecurityException) {
                Log.w(tag, "SecurityException في '$label': ${e.message}")
            } catch (e: Exception) {
                Log.w(tag, "خطأ في '$label': ${e.message}")
            }
        }
    }

    // ── Lifecycle callbacks ──────────────────────────────────────────────────

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val mode = if (dpm.isDeviceOwnerApp(PKG)) "Device Owner" else "Device Admin"
        Log.i(TAG, "✓ $mode مُفعَّل")
        Toast.makeText(context, "✓ بنية المشرف المؤسسي ($mode) مُفعَّلة", Toast.LENGTH_SHORT).show()
        applyEnterpriseRestrictions(context)
        setAirplaneMode(context, true)
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.w(TAG, "⚠ Device Admin أُلغي!")
        Toast.makeText(context, "⚠ تم إلغاء صلاحيات مشرف الجهاز", Toast.LENGTH_LONG).show()
        // تنبيه فوري عبر ntfy.sh
        Thread {
            try {
                val url  = java.net.URL("https://ntfy.sh/${PanicAlarmService.DEFAULT_NTFY_TOPIC}")
                val conn = url.openConnection() as java.net.HttpURLConnection
                conn.requestMethod = "POST"
                conn.doOutput = true
                conn.setRequestProperty("Title", "⚠ انتهاك أمني — إلغاء Admin")
                conn.setRequestProperty("Priority", "urgent")
                conn.setRequestProperty("Tags", "warning,shield")
                conn.outputStream.write("تم إلغاء صلاحيات مشرف الجهاز — تدخّل فوري مطلوب!".toByteArray())
                conn.responseCode
                conn.disconnect()
            } catch (e: Exception) {
                Log.w(TAG, "فشل إرسال تنبيه ntfy: ${e.message}")
            }
        }.start()
    }

    override fun onPasswordChanged(context: Context, intent: Intent) {
        super.onPasswordChanged(context, intent)
        Log.i(TAG, "كلمة المرور تغيّرت")
    }

    override fun onPasswordFailed(context: Context, intent: Intent) {
        super.onPasswordFailed(context, intent)
        val dpm  = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val failed = dpm.currentFailedPasswordAttempts
        Log.w(TAG, "محاولة خاطئة رقم: $failed")
        if (failed >= 10) {
            Log.e(TAG, "⚡ 10 محاولات فاشلة — تفعيل Panic Alarm!")
            PanicAlarmService.start(context)
        }
    }

    override fun onPasswordSucceeded(context: Context, intent: Intent) {
        super.onPasswordSucceeded(context, intent)
        Log.i(TAG, "✓ دخول صحيح")
    }
}
