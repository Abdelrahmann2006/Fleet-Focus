package com.abdelrahman.panopticon

import android.accounts.AccountManager
import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.app.role.RoleManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.provider.Telephony
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class PermissionMethodChannel(
    private val activity: FlutterActivity,
    flutterEngine: FlutterEngine
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.abdelrahman.panopticon/permissions"
    }

    private val channel: MethodChannel =
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isDeviceAdminActive"              -> result.success(isDeviceAdminActive())
            "isAccessibilityServiceEnabled"    -> result.success(isAccessibilityServiceEnabled())
            "canDrawOverApps"                  -> result.success(canDrawOverApps())
            "isBatteryOptimizationIgnored"     -> result.success(isBatteryOptimizationIgnored())
            "isDefaultSmsApp"                  -> result.success(isDefaultSmsApp())
            "isDefaultPhoneApp"                -> result.success(isDefaultPhoneApp())
            "openDeviceAdminSettings"          -> { openDeviceAdminSettings(); result.success(null) }
            "openAccessibilitySettings"        -> { openAccessibilitySettings(); result.success(null) }
            "openOverlaySettings"              -> { openOverlaySettings(); result.success(null) }
            "openBatteryOptimizationSettings"  -> { openBatteryOptimizationSettings(); result.success(null) }
            "openDeveloperOptions"             -> { openDeveloperOptions(); result.success(null) }
            "openAppSettings"                  -> { openAppSettings(); result.success(null) }
            "requestDefaultSmsApp"             -> { requestDefaultSmsApp(); result.success(null) }
            "requestDefaultPhoneApp"           -> { requestDefaultPhoneApp(); result.success(null) }
            "getAllPermissionsStatus"           -> result.success(getAllPermissionsStatus())
            "isDeviceOwnerApp"                 -> result.success(isDeviceOwnerApp())
            "getGoogleAccounts"                -> result.success(getGoogleAccounts())
            "openSyncSettings"                 -> { openSyncSettings(); result.success(null) }
            else -> result.notImplemented()
        }
    }

    // ─────────────────────────────────────────────────────────────
    //  التحقق من الصلاحيات
    // ─────────────────────────────────────────────────────────────

    /** هل التطبيق مشرف جهاز نشط؟ */
    private fun isDeviceAdminActive(): Boolean {
        val dpm = activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(activity, MyDeviceAdminReceiver::class.java)
        return dpm.isAdminActive(adminComponent)
    }

    /** هل خدمة إمكانية الوصول مفعّلة؟ */
    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedService = "${activity.packageName}/${MyAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            activity.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)
        while (colonSplitter.hasNext()) {
            if (colonSplitter.next().equals(expectedService, ignoreCase = true)) return true
        }
        return false
    }

    /** هل لدى التطبيق إذن الرسم فوق التطبيقات؟ */
    private fun canDrawOverApps(): Boolean {
        return Settings.canDrawOverlays(activity)
    }

    /** هل التطبيق معفى من تحسين البطارية؟ */
    private fun isBatteryOptimizationIgnored(): Boolean {
        val pm = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(activity.packageName)
    }

    /** هل التطبيق التطبيق الافتراضي للـ SMS؟ */
    private fun isDefaultSmsApp(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = activity.getSystemService(RoleManager::class.java)
            roleManager?.isRoleHeld(RoleManager.ROLE_SMS) == true
        } else {
            Telephony.Sms.getDefaultSmsPackage(activity) == activity.packageName
        }
    }

    /** هل التطبيق التطبيق الافتراضي للهاتف (Dialer)؟ */
    private fun isDefaultPhoneApp(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = activity.getSystemService(RoleManager::class.java)
            roleManager?.isRoleHeld(RoleManager.ROLE_DIALER) == true
        } else {
            // Android < 10: لا توجد طريقة مباشرة — نقبل دائماً
            true
        }
    }

    /** طلب التعيين كتطبيق SMS الافتراضي */
    private fun requestDefaultSmsApp() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = activity.getSystemService(RoleManager::class.java)
            if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_SMS)
                && !roleManager.isRoleHeld(RoleManager.ROLE_SMS)) {
                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_SMS)
                activity.startActivityForResult(intent, 101)
            }
        } else {
            val intent = Intent("android.provider.Telephony.ACTION_CHANGE_DEFAULT").apply {
                putExtra("package", activity.packageName)
            }
            activity.startActivity(intent)
        }
    }

    /** طلب التعيين كتطبيق هاتف افتراضي (Dialer) */
    private fun requestDefaultPhoneApp() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = activity.getSystemService(RoleManager::class.java)
            if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_DIALER)
                && !roleManager.isRoleHeld(RoleManager.ROLE_DIALER)) {
                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_DIALER)
                activity.startActivityForResult(intent, 102)
            }
        } else {
            val intent = Intent(Intent.ACTION_DIAL)
            activity.startActivity(intent)
        }
    }

    /** جميع حالات الصلاحيات دفعة واحدة */
    private fun getAllPermissionsStatus(): HashMap<String, Boolean> {
        return hashMapOf(
            "deviceAdmin"          to isDeviceAdminActive(),
            "accessibility"        to isAccessibilityServiceEnabled(),
            "overlay"              to canDrawOverApps(),
            "batteryOptimization"  to isBatteryOptimizationIgnored(),
            "defaultSmsApp"        to isDefaultSmsApp(),
            "defaultPhoneApp"      to isDefaultPhoneApp()
        )
    }

    // ─────────────────────────────────────────────────────────────
    //  فتح الإعدادات
    // ─────────────────────────────────────────────────────────────

    /** فتح شاشة تفعيل مشرف الجهاز */
    private fun openDeviceAdminSettings() {
        val adminComponent = ComponentName(activity, MyDeviceAdminReceiver::class.java)
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
            putExtra(
                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                "هذه الصلاحية ضرورية لعمل التطبيق بشكل صحيح."
            )
        }
        activity.startActivity(intent)
    }

    /** فتح إعدادات إمكانية الوصول */
    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        activity.startActivity(intent)
    }

    /** فتح إعدادات الرسم فوق التطبيقات */
    private fun openOverlaySettings() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${activity.packageName}")
        )
        activity.startActivity(intent)
    }

    /** فتح إعدادات استثناء تحسين البطارية */
    private fun openBatteryOptimizationSettings() {
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:${activity.packageName}")
        }
        activity.startActivity(intent)
    }

    /** فتح خيارات المطور */
    private fun openDeveloperOptions() {
        val intent = Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        activity.startActivity(intent)
    }

    /** فتح تفاصيل التطبيق */
    private fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:${activity.packageName}")
        }
        activity.startActivity(intent)
    }

    // ─────────────────────────────────────────────────────────────
    //  Device Owner & Google Accounts
    // ─────────────────────────────────────────────────────────────

    /** هل التطبيق Device Owner حالياً؟ */
    private fun isDeviceOwnerApp(): Boolean {
        val dpm = activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return dpm.isDeviceOwnerApp(activity.packageName)
    }

    /** قائمة حسابات Google المسجَّلة على الجهاز */
    private fun getGoogleAccounts(): List<String> {
        return try {
            val am = AccountManager.get(activity)
            am.getAccountsByType("com.google").map { it.name }
        } catch (_: Exception) {
            emptyList()
        }
    }

    /** فتح إعدادات الحسابات والمزامنة لحذف حسابات Google */
    private fun openSyncSettings() {
        val intent = Intent(Settings.ACTION_SYNC_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        try {
            activity.startActivity(intent)
        } catch (_: Exception) {
            val fallback = Intent(Settings.ACTION_SETTINGS)
            fallback.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            activity.startActivity(fallback)
        }
    }
}
