package com.abdelrahman.panopticon

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private lateinit var permissionChannel: PermissionMethodChannel
    private lateinit var systemControlChannel: SystemControlChannel
    private lateinit var backgroundServiceChannel: BackgroundServiceChannel
    private lateinit var securityKeyStoreService: SecurityKeyStoreService

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── قناة الصلاحيات ─────────────────────────────────────
        permissionChannel = PermissionMethodChannel(this, flutterEngine)

        // ── قناة التحكم في النظام (lock screen, onboarding) ────
        systemControlChannel = SystemControlChannel(this, flutterEngine)

        // ── قناة الخدمة في الخلفية (Foreground Service) ────────
        backgroundServiceChannel = BackgroundServiceChannel(this, flutterEngine)

        // ── مخزن المفاتيح الأمني — AES-256 Android Keystore ────
        securityKeyStoreService = SecurityKeyStoreService(flutterEngine)

        // ── تسجيل BinaryMessenger لـ MyAccessibilityService ────
        FocusChannelHolder.messenger = flutterEngine.dartExecutor.binaryMessenger

        // ── قناة الطبقة الحمراء العقابية — Red Overlay ─────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "panopticon/red_overlay"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "showRedOverlay" -> {
                    val message = call.argument<String>("message")
                        ?: "انتهاك مرصود — خرق قواعد النظام"
                    RedOverlayService.show(applicationContext, message)
                    result.success(true)
                }
                "hideRedOverlay" -> {
                    RedOverlayService.hide(applicationContext)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ── مستمع تحديث التطبيقات المحجوبة من Dart ─────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MyAccessibilityService.FOCUS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateBlockedApps" -> {
                    @Suppress("UNCHECKED_CAST")
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    saveBlockedAppsToPrefs(packages)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun saveBlockedAppsToPrefs(packages: List<String>) {
        getSharedPreferences(CommandListenerService.PREF_FILE, MODE_PRIVATE)
            .edit()
            .putStringSet("blocked_apps", packages.toSet())
            .apply()
        android.util.Log.i("MainActivity", "قائمة الحجب محفوظة: ${packages.size} تطبيق")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun onDestroy() {
        FocusChannelHolder.messenger = null
        super.onDestroy()
    }
}
