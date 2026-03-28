package com.abdelrahman.panopticon

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * SystemControlChannel
 *
 * قناة التحكم في النظام — تُستدعى من Dart عبر:
 *   MethodChannel('com.abdelrahman.panopticon/system_control')
 *
 * الأوامر المدعومة:
 *  ┌─────────────────────────────────────────────────────┐
 *  │  onboardingComplete  → يُسجّل اكتمال الإعداد        │
 *  │  lockScreen          → قفل الشاشة (Device Admin)    │
 *  │  isAdminActive       → هل Device Admin مُفعَّل؟     │
 *  └─────────────────────────────────────────────────────┘
 *
 * ملاحظة: lockScreen يستلزم تفعيل Device Admin أولاً
 * عبر قناة PermissionMethodChannel → openDeviceAdminSettings()
 */
class SystemControlChannel(
    private val activity: FlutterActivity,
    flutterEngine: FlutterEngine
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.abdelrahman.panopticon/system_control"
    }

    private val channel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger, CHANNEL
    )

    // مكوّنات Device Policy
    private val dpm: DevicePolicyManager by lazy {
        activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    }

    private val adminComponent: ComponentName by lazy {
        ComponentName(activity, MyDeviceAdminReceiver::class.java)
    }

    init {
        channel.setMethodCallHandler(this)
    }

    // ──────────────────────────────────────────────────────────
    //  نقطة استقبال الأوامر
    // ──────────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {

            // ── إكمال الإعداد ──────────────────────────────────
            "onboardingComplete" -> {
                handleOnboardingComplete(result)
            }

            // ── قفل الشاشة (ضبط النفس / الحماية من السرقة) ───
            "lockScreen" -> {
                lockScreen(result)
            }

            // ── التحقق من نشاط Device Admin ───────────────────
            "isAdminActive" -> {
                result.success(isAdminActive())
            }

            else -> result.notImplemented()
        }
    }

    // ──────────────────────────────────────────────────────────
    //  onboardingComplete — يُسجّل اكتمال الإعداد
    // ──────────────────────────────────────────────────────────

    private fun handleOnboardingComplete(result: MethodChannel.Result) {
        // سجّل الحدث — يمكن توسيعه لاحقاً (Firestore timestamp, etc.)
        android.util.Log.i("SystemControl", "onboardingComplete: الإعداد اكتمل بنجاح")

        // أرسل للـ Dart: هل Device Admin نشط؟
        result.success(
            mapOf(
                "success"      to true,
                "adminActive"  to isAdminActive(),
                "timestamp"    to System.currentTimeMillis()
            )
        )
    }

    // ──────────────────────────────────────────────────────────
    //  lockScreen — قفل الشاشة عبر DevicePolicyManager
    //
    //  الاستخدام الشرعي:
    //   • ضبط النفس: قفل الجهاز بإرادة المستخدم نفسه
    //   • الحماية من السرقة: قفل فوري عند الكشف عن خطر
    // ──────────────────────────────────────────────────────────

    private fun lockScreen(result: MethodChannel.Result) {
        if (!isAdminActive()) {
            result.error(
                "ADMIN_NOT_ACTIVE",
                "صلاحيات مشرف الجهاز غير مفعّلة. فعّلها أولاً عبر إعدادات التطبيق.",
                null
            )
            return
        }

        try {
            dpm.lockNow()
            result.success(true)
        } catch (e: SecurityException) {
            result.error("LOCK_FAILED", "فشل قفل الشاشة: ${e.message}", null)
        }
    }

    // ──────────────────────────────────────────────────────────
    //  مساعدات
    // ──────────────────────────────────────────────────────────

    private fun isAdminActive(): Boolean =
        dpm.isAdminActive(adminComponent)
}
