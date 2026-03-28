package com.abdelrahman.panopticon

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * BackgroundServiceChannel — يُتيح لـ Flutter التحكم في خدمتَي الخلفية:
 *   • CommandListenerService   (يستمع للأوامر من Firestore)
 *   • TelemetryPublisherService (يرفع بيانات الجهاز إلى RTDB)
 *
 * القنوات:
 *   الكلاسيكية: com.abdelrahman.panopticon/background_service (متوافقة مع الكود القديم)
 *   الموسّعة:   com.abdelrahman.panopticon/services          (NativeServiceChannel.dart)
 */
class BackgroundServiceChannel(
    private val activity: FlutterActivity,
    flutterEngine: FlutterEngine,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL          = "com.abdelrahman.panopticon/background_service"
        const val EXTENDED_CHANNEL = "com.abdelrahman.panopticon/services"
    }

    // القناة الكلاسيكية (للتوافق مع الكود القديم)
    private val channel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger, CHANNEL
    )

    // القناة الموسّعة (NativeServiceChannel.dart)
    private val extChannel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger, EXTENDED_CHANNEL
    )

    init {
        channel.setMethodCallHandler(this)
        extChannel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {

            // ── القناة الكلاسيكية ─────────────────────────────

            "startListenerService" -> {
                val uid = call.argument<String>("uid")
                if (uid.isNullOrEmpty()) {
                    result.error("MISSING_UID", "uid مطلوب", null)
                    return
                }
                startCmd(uid)
                result.success(true)
            }

            "stopListenerService" -> {
                stopCmd()
                result.success(true)
            }

            // ── القناة الموسّعة ───────────────────────────────

            "startCommandListener" -> {
                val uid = call.argument<String>("uid")
                if (uid.isNullOrEmpty()) {
                    result.error("MISSING_UID", "uid مطلوب", null); return
                }
                startCmd(uid)
                result.success(true)
            }

            "stopCommandListener" -> {
                stopCmd()
                result.success(true)
            }

            "startTelemetryPublisher" -> {
                val uid = call.argument<String>("uid")
                if (uid.isNullOrEmpty()) {
                    result.error("MISSING_UID", "uid مطلوب", null); return
                }
                startTelemetry(uid)
                result.success(true)
            }

            "stopTelemetryPublisher" -> {
                activity.stopService(
                    Intent(activity, TelemetryPublisherService::class.java)
                )
                result.success(true)
            }

            "queryPermissions" -> {
                result.success(queryPermissionsMap())
            }

            else -> result.notImplemented()
        }
    }

    // ── Helpers: CommandListenerService ───────────────────────

    private fun startCmd(uid: String) {
        val intent = Intent(activity, CommandListenerService::class.java)
            .putExtra(CommandListenerService.EXTRA_UID, uid)
        launch(intent)
        android.util.Log.i("BackgroundServiceChannel", "✓ CommandListenerService → UID: $uid")
    }

    private fun stopCmd() {
        activity.stopService(Intent(activity, CommandListenerService::class.java))
        activity.getSharedPreferences(CommandListenerService.PREF_FILE, Context.MODE_PRIVATE)
            .edit().remove(CommandListenerService.PREF_UID).apply()
        android.util.Log.i("BackgroundServiceChannel", "✓ CommandListenerService stopped")
    }

    // ── Helpers: TelemetryPublisherService ────────────────────

    private fun startTelemetry(uid: String) {
        val intent = Intent(activity, TelemetryPublisherService::class.java)
            .putExtra(TelemetryPublisherService.EXTRA_UID, uid)
        launch(intent)
        android.util.Log.i("BackgroundServiceChannel", "✓ TelemetryPublisherService → UID: $uid")
    }

    // ── Helpers: General ──────────────────────────────────────

    private fun launch(intent: Intent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            activity.startForegroundService(intent)
        } else {
            activity.startService(intent)
        }
    }

    private fun queryPermissionsMap(): Map<String, Boolean> {
        val dpm  = activity.getSystemService(Context.DEVICE_POLICY_SERVICE)
                as android.app.admin.DevicePolicyManager
        val pm   = activity.getSystemService(Context.POWER_SERVICE)
                as android.os.PowerManager
        val comp = ComponentName(activity, MyDeviceAdminReceiver::class.java)
        return mapOf(
            "deviceAdmin"         to dpm.isAdminActive(comp),
            "accessibility"       to isAccessibilityEnabled(),
            "overlay"             to Settings.canDrawOverlays(activity),
            "batteryOptimization" to pm.isIgnoringBatteryOptimizations(activity.packageName),
        )
    }

    private fun isAccessibilityEnabled(): Boolean {
        val pkg  = activity.packageName
        val svc  = MyAccessibilityService::class.java.canonicalName ?: return false
        val expected = "$pkg/$svc"
        val enabled  = Settings.Secure.getString(
            activity.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabled)
        while (splitter.hasNext()) {
            if (splitter.next().equals(expected, ignoreCase = true)) return true
        }
        return false
    }
}
