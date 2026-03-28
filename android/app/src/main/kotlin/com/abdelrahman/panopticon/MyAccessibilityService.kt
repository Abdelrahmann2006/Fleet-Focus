package com.abdelrahman.panopticon

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Toast
import androidx.core.app.NotificationCompat

/**
 * MyAccessibilityService — محرك إنفاذ التركيز الكامل
 *
 * الميزات المُنفَّذة:
 *  1. App Blocking — يُعيد للشاشة الرئيسية عند فتح تطبيق مقيَّد
 *  2. Anti Split-Screen / PiP — يُغلق وضع النافذة المتعددة فور اكتشافه
 *  3. DLP Trigger — تفعيل مسح محتوى التطبيقات عالية الخطورة
 *  4. Input Integrity / Backspace Tracker — تتبع حذف المدخلات
 *  5. Web URL Filtering — مراقبة روابط المتصفحات وحجب المواقع المقيَّدة
 *  6. Mutiny Lockout — كشف فتح صفحة إعدادات إمكانية الوصول وتطبيق العقوبة
 *  7. Briefing Enforcer — إعادة الإطلاق الفوري إذا حاول المستخدم الخروج من جلسة الإحاطة
 */
class MyAccessibilityService : AccessibilityService() {

    companion object {
        const val NOTIFICATION_CHANNEL_ID = "competition_foreground_channel"
        const val NOTIFICATION_ID          = 1001

        const val FOCUS_CHANNEL = "com.abdelrahman.panopticon/focus_events"

        val DEFAULT_BLOCKED_APPS: Set<String> = setOf(
            "com.instagram.android",
            "com.twitter.android",
            "com.facebook.katana",
            "com.snapchat.android",
            "com.zhiliaoapp.musically",
            "com.tiktok.android",
        )

        // ── متصفحات مراقبة الروابط ────────────────────────────
        private val BROWSER_PACKAGES = setOf(
            "com.android.chrome",
            "org.mozilla.firefox",
            "com.opera.browser",
            "com.microsoft.emmx",         // Edge
            "com.sec.android.app.sbrowser", // Samsung Internet
            "com.brave.browser",
            "com.duckduckgo.mobile.android",
            "com.kiwibrowser.browser",
            "com.vivaldi.browser",
        )

        // ── نماذج أسماء حقول عنوان URL في المتصفحات ───────────
        private val URL_BAR_RESOURCE_IDS = setOf(
            "com.android.chrome:id/url_bar",
            "com.android.chrome:id/search_box_text",
            "org.mozilla.firefox:id/url_bar_text",
            "org.mozilla.firefox:id/mozac_browser_toolbar_url_view",
            "com.sec.android.app.sbrowser:id/location_bar_edit_text",
            "com.microsoft.emmx:id/url_bar",
            "com.brave.browser:id/url_bar",
        )

        // ── مسار صفحة إعدادات إمكانية الوصول ─────────────────
        private const val SETTINGS_PACKAGE   = "com.android.settings"
        private const val ACCESSIBILITY_HINT = "accessibility"
    }

    private var blockedApps: MutableSet<String> = DEFAULT_BLOCKED_APPS.toMutableSet()
    private var blockedDomains: MutableSet<String> = mutableSetOf()
    private var lastForegroundPackage: String = ""
    private var currentBrowserPackage: String = ""

    // DLP
    private var dlpScanActive: Boolean = false
    private var dlpCurrentPackage: String = ""
    private var lastDlpScanMs: Long = 0L
    private val DLP_SCAN_INTERVAL_MS = 3_000L

    // Backspace Tracker
    private var sessionBackspaceCount: Int = 0
    private var lastBackspacePublishMs: Long = 0L
    private val BACKSPACE_PUBLISH_INTERVAL = 10_000L
    private var lastTextLengths: MutableMap<Int, Int> = mutableMapOf()

    // Input Log
    private var lastTypedLogMs: Long = 0L
    private val TYPED_LOG_INTERVAL_MS = 30_000L

    // Mutiny Lockout — حماية من إيقاف الخدمة
    private var mutinyLockoutEnabled: Boolean = true
    private var lastMutinyTriggerMs: Long = 0L
    private val MUTINY_LOCKOUT_COOLDOWN_MS = 10_000L

    // URL Filter cooldown
    private var lastUrlBlockMs: Long = 0L
    private val URL_BLOCK_COOLDOWN_MS = 3_000L

    override fun onServiceConnected() {
        super.onServiceConnected()

        serviceInfo = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                         AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                         AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED
            feedbackType     = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags            = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                               AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 100
        }

        startForegroundWithStickyNotification()
        android.util.Log.i("FocusEngine", "✓ خدمة إنفاذ التركيز الكاملة نشطة")
    }

    override fun onInterrupt() {
        android.util.Log.w("FocusEngine", "الخدمة انقطعت مؤقتاً")
    }

    override fun onDestroy() {
        super.onDestroy()
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                val pkg = event.packageName?.toString() ?: return
                handleWindowStateChanged(pkg, event)
            }
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                handleContentChanged(event)
            }
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> {
                handleTextChanged(event)
            }
        }
    }

    // ── 1. تغيير التطبيق النشط ────────────────────────────────

    private fun handleWindowStateChanged(packageName: String, event: AccessibilityEvent) {
        if (packageName == "com.abdelrahman.panopticon") return

        // ── Mutiny Lockout: فتح صفحة إعدادات إمكانية الوصول ──
        if (mutinyLockoutEnabled && packageName == SETTINGS_PACKAGE) {
            val className = event.className?.toString()?.lowercase() ?: ""
            val eventText = event.text?.joinToString(" ")?.lowercase() ?: ""
            if (className.contains(ACCESSIBILITY_HINT) || eventText.contains(ACCESSIBILITY_HINT)) {
                handleMutinyAttempt()
                return
            }
        }

        if (packageName == lastForegroundPackage) return
        lastForegroundPackage = packageName

        // ── حجب التطبيقات ──
        if (packageName in blockedApps) {
            android.util.Log.i("FocusEngine", "⛔ محجوب: $packageName → GLOBAL_ACTION_HOME")
            performGlobalAction(GLOBAL_ACTION_HOME)
            sendFocusEventToFlutter(
                type = "app_blocked",
                data = mapOf("blockedPackage" to packageName, "timestamp" to System.currentTimeMillis())
            )
        }

        // ── Briefing Enforcer: إذا تركت التطبيق المُجبَر ──
        if (BriefingEnforcerService.isBriefingActive(this)) {
            val deepLink = BriefingEnforcerService.getBriefingDeepLink(this)
            if (deepLink != null && packageName !in setOf("com.abdelrahman.panopticon")) {
                android.util.Log.w("FocusEngine", "⚠ Briefing: محاولة مغادرة الجلسة → إعادة الإطلاق")
                Handler(Looper.getMainLooper()).postDelayed({
                    try {
                        val intent = android.content.Intent(
                            android.content.Intent.ACTION_VIEW,
                            android.net.Uri.parse(deepLink)
                        ).apply { addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK) }
                        startActivity(intent)
                    } catch (_: Exception) {}
                }, 800L)
            }
        }

        // ── Browser: تتبع المتصفح النشط ──
        currentBrowserPackage = if (packageName in BROWSER_PACKAGES) packageName else ""

        // ── DLP Trigger ──
        if (packageName in DlpScanEngine.HIGH_RISK_APPS) {
            dlpScanActive = true
            dlpCurrentPackage = packageName
        } else {
            dlpScanActive = false
            dlpCurrentPackage = ""
        }
    }

    // ── 2. تغيير محتوى النافذة ────────────────────────────────

    private fun handleContentChanged(event: AccessibilityEvent) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return

        // ── Anti Split-Screen / PiP ──
        val inMultiWindow = windows?.any { w ->
            w.isInPictureInPictureMode ||
            (w.type == android.view.accessibility.AccessibilityWindowInfo.TYPE_SPLIT_SCREEN_DIVIDER)
        } ?: false

        if (inMultiWindow) {
            android.util.Log.i("FocusEngine", "⛔ Split-Screen/PiP مكتشف → إغلاق")
            performGlobalAction(GLOBAL_ACTION_HOME)
            performGlobalAction(GLOBAL_ACTION_HOME) // ضربة مزدوجة لكسر الـ UI
            sendFocusEventToFlutter(
                type = "split_screen_blocked",
                data = mapOf("timestamp" to System.currentTimeMillis())
            )
        }

        // ── Web URL Filtering ──
        if (currentBrowserPackage.isNotEmpty() && blockedDomains.isNotEmpty()) {
            scanBrowserUrl(event)
        }

        // ── Mutiny: مراقبة محتوى صفحة الإعدادات ──
        if (mutinyLockoutEnabled && lastForegroundPackage == SETTINGS_PACKAGE) {
            val root = rootInActiveWindow
            if (root != null && isAccessibilitySettingsVisible(root)) {
                handleMutinyAttempt()
                root.recycle()
                return
            }
            root?.recycle()
        }

        // ── DLP Content Scan ──
        if (dlpScanActive && dlpCurrentPackage.isNotEmpty()) {
            val now = System.currentTimeMillis()
            if (now - lastDlpScanMs > DLP_SCAN_INTERVAL_MS) {
                lastDlpScanMs = now
                val uid = getSharedPreferences("focus_prefs", Context.MODE_PRIVATE)
                    .getString("saved_uid", "") ?: ""
                if (uid.isNotEmpty()) {
                    Handler(Looper.getMainLooper()).post {
                        DlpScanEngine.scan(rootInActiveWindow, dlpCurrentPackage, uid, this)
                    }
                }
            }
        }
    }

    // ── 5. فلترة روابط المتصفح ───────────────────────────────

    private fun scanBrowserUrl(event: AccessibilityEvent) {
        val now = System.currentTimeMillis()
        if (now - lastUrlBlockMs < URL_BLOCK_COOLDOWN_MS) return

        val root = rootInActiveWindow ?: return
        try {
            val urlText = extractBrowserUrl(root) ?: return
            val normalizedUrl = urlText.lowercase().trim()
                .removePrefix("https://").removePrefix("http://").removePrefix("www.")

            val matched = blockedDomains.any { domain ->
                normalizedUrl.startsWith(domain.lowercase()) ||
                normalizedUrl.contains("/$domain") ||
                normalizedUrl == domain.lowercase()
            }

            if (matched) {
                lastUrlBlockMs = now
                android.util.Log.w("FocusEngine", "⛔ رابط محجوب: $urlText")

                performGlobalAction(GLOBAL_ACTION_BACK)
                Handler(Looper.getMainLooper()).postDelayed({
                    performGlobalAction(GLOBAL_ACTION_BACK)
                }, 150L)

                Handler(Looper.getMainLooper()).post {
                    Toast.makeText(
                        this,
                        "Content restricted by Administrator policy",
                        Toast.LENGTH_LONG
                    ).show()
                }

                sendFocusEventToFlutter(
                    type = "url_blocked",
                    data = mapOf("url" to urlText, "timestamp" to now)
                )
                logUrlBlock(urlText)
            }
        } catch (e: Exception) {
            android.util.Log.w("FocusEngine", "خطأ في فحص URL: ${e.message}")
        } finally {
            root.recycle()
        }
    }

    private fun extractBrowserUrl(root: AccessibilityNodeInfo): String? {
        // محاولة 1: بحث بـ Resource ID المعروفة
        for (resId in URL_BAR_RESOURCE_IDS) {
            val nodes = root.findAccessibilityNodeInfosByViewId(resId)
            if (nodes.isNotEmpty()) {
                val text = nodes[0].text?.toString()
                nodes.forEach { it.recycle() }
                if (!text.isNullOrBlank()) return text
            }
        }
        // محاولة 2: بحث بالـ Class Name لأي EditText في المتصفح
        return findUrlBarByClass(root)
    }

    private fun findUrlBarByClass(node: AccessibilityNodeInfo): String? {
        if (node.className?.contains("EditText") == true) {
            val text = node.text?.toString()
            if (!text.isNullOrBlank() &&
                (text.startsWith("http") || text.startsWith("www.") ||
                 text.contains(".com") || text.contains(".net") || text.contains(".org"))) {
                return text
            }
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val result = findUrlBarByClass(child)
            child.recycle()
            if (result != null) return result
        }
        return null
    }

    private fun logUrlBlock(url: String) {
        val uid = getSharedPreferences(CommandListenerService.PREF_FILE, MODE_PRIVATE)
            .getString(CommandListenerService.PREF_UID, null) ?: return
        try {
            com.google.firebase.firestore.FirebaseFirestore.getInstance()
                .collection("compliance_assets").document(uid)
                .collection("url_block_log")
                .add(mapOf(
                    "url"       to url,
                    "browser"   to currentBrowserPackage,
                    "timestamp" to com.google.firebase.firestore.FieldValue.serverTimestamp()
                ))
        } catch (e: Exception) {
            android.util.Log.w("FocusEngine", "فشل تسجيل URL block: ${e.message}")
        }
    }

    // ── 6. Mutiny Lockout — حماية خدمة إمكانية الوصول ────────

    private fun isAccessibilitySettingsVisible(root: AccessibilityNodeInfo): Boolean {
        val packageName = root.packageName?.toString() ?: return false
        if (packageName != SETTINGS_PACKAGE) return false

        // بحث عن نصوص تدل على صفحة إمكانية الوصول
        val nodes = root.findAccessibilityNodeInfosByText("نظام المنافسة")
            .plus(root.findAccessibilityNodeInfosByText("Panopticon"))
            .plus(root.findAccessibilityNodeInfosByText("مراقبة المنافسة"))
        val found = nodes.isNotEmpty()
        nodes.forEach { it.recycle() }
        return found
    }

    private fun handleMutinyAttempt() {
        val now = System.currentTimeMillis()
        if (now - lastMutinyTriggerMs < MUTINY_LOCKOUT_COOLDOWN_MS) return
        lastMutinyTriggerMs = now

        android.util.Log.e("FocusEngine", "⛔ MUTINY DETECTED: محاولة تعطيل الخدمة → عقوبة فورية")

        // 1. تفعيل Red Overlay العقابية
        val overlayIntent = Intent(this, RedOverlayService::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(overlayIntent)
        } else {
            startService(overlayIntent)
        }

        // 2. قفل الجهاز فوراً
        try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val comp = ComponentName(this, MyDeviceAdminReceiver::class.java)
            if (dpm.isAdminActive(comp)) {
                dpm.lockNow()
                android.util.Log.i("FocusEngine", "✓ قفل Mutiny نُفِّذ")
            }
        } catch (e: Exception) {
            android.util.Log.e("FocusEngine", "فشل قفل Mutiny: ${e.message}")
        }

        // 3. إخفاء صفحة الإعدادات بضغط Home
        performGlobalAction(GLOBAL_ACTION_HOME)

        // 4. تسجيل الخيانة في Firestore
        val uid = getSharedPreferences(CommandListenerService.PREF_FILE, MODE_PRIVATE)
            .getString(CommandListenerService.PREF_UID, null) ?: return
        try {
            com.google.firebase.firestore.FirebaseFirestore.getInstance()
                .collection("compliance_assets").document(uid)
                .collection("mutiny_log")
                .add(mapOf(
                    "event"     to "accessibility_disable_attempt",
                    "severity"  to "CRITICAL",
                    "timestamp" to com.google.firebase.firestore.FieldValue.serverTimestamp()
                ))
        } catch (e: Exception) {
            android.util.Log.w("FocusEngine", "فشل تسجيل Mutiny: ${e.message}")
        }

        sendFocusEventToFlutter(
            type = "mutiny_lockout",
            data = mapOf("timestamp" to now, "severity" to "CRITICAL")
        )
    }

    // ── 3. Backspace Tracker + Input Integrity ─────────────────

    private fun handleTextChanged(event: AccessibilityEvent) {
        val viewId      = event.windowId * 1000 + (event.eventTime and 0xFFFF).toInt()
        val currentLen  = event.text?.firstOrNull()?.length ?: 0
        val previousLen = lastTextLengths[viewId]

        if (previousLen != null && currentLen < previousLen) {
            val deletedChars = previousLen - currentLen
            sessionBackspaceCount += deletedChars
        }
        lastTextLengths[viewId] = currentLen

        val typedText = event.text?.firstOrNull()?.toString()
        if (!typedText.isNullOrBlank() && currentLen > 2) {
            logTypedInput(typedText, event.packageName?.toString() ?: "unknown")
        }

        val now = System.currentTimeMillis()
        if (now - lastBackspacePublishMs >= BACKSPACE_PUBLISH_INTERVAL && sessionBackspaceCount > 0) {
            lastBackspacePublishMs = now
            publishBackspaceCount()
        }
    }

    private fun logTypedInput(text: String, packageName: String) {
        val now = System.currentTimeMillis()
        if (now - lastTypedLogMs < TYPED_LOG_INTERVAL_MS) return
        lastTypedLogMs = now

        val uid = getSharedPreferences(CommandListenerService.PREF_FILE, MODE_PRIVATE)
            .getString(CommandListenerService.PREF_UID, null) ?: return

        try {
            com.google.firebase.firestore.FirebaseFirestore.getInstance()
                .collection("compliance_assets").document(uid)
                .collection("input_logs")
                .add(mapOf(
                    "snippet"        to text.takeLast(120),
                    "packageName"    to packageName,
                    "backspaceCount" to sessionBackspaceCount,
                    "timestamp"      to com.google.firebase.firestore.FieldValue.serverTimestamp()
                ))
        } catch (e: Exception) {
            android.util.Log.w("FocusEngine", "فشل تسجيل Input Log: ${e.message}")
        }
    }

    private fun publishBackspaceCount() {
        val uid = getSharedPreferences(CommandListenerService.PREF_FILE, MODE_PRIVATE)
            .getString(CommandListenerService.PREF_UID, null) ?: return

        try {
            com.google.firebase.database.FirebaseDatabase.getInstance()
                .getReference("device_states").child(uid).child("backspaceCount")
                .setValue(sessionBackspaceCount)
        } catch (e: Exception) {
            android.util.Log.w("FocusEngine", "خطأ backspaceCount: ${e.message}")
        }
    }

    // ── 4. MethodChannel لـ Flutter ──────────────────────────

    private fun sendFocusEventToFlutter(type: String, data: Map<String, Any>) {
        Handler(Looper.getMainLooper()).post {
            try {
                val messenger = FocusChannelHolder.messenger
                if (messenger != null) {
                    val channel = io.flutter.plugin.common.MethodChannel(messenger, FOCUS_CHANNEL)
                    channel.invokeMethod(type, data)
                }
            } catch (e: Exception) {
                android.util.Log.w("FocusEngine", "تعذّر الإرسال لـ Flutter: ${e.message}")
            }
        }
    }

    // ── API العامة (يُستدعى من CommandListenerService) ────────

    fun updateBlockedApps(packages: List<String>) {
        blockedApps = packages.toMutableSet()
        android.util.Log.i("FocusEngine", "قائمة حجب التطبيقات محدَّثة: $blockedApps")
    }

    fun updateBlockedDomains(domains: List<String>) {
        blockedDomains = domains.toMutableSet()
        android.util.Log.i("FocusEngine", "قائمة حجب الروابط محدَّثة: $blockedDomains")
    }

    fun setMutinyLockoutEnabled(enabled: Boolean) {
        mutinyLockoutEnabled = enabled
        android.util.Log.i("FocusEngine", "Mutiny Lockout: $enabled")
    }

    // ── Foreground Sticky Notification ───────────────────────

    private fun startForegroundWithStickyNotification() {
        createNotificationChannel()

        val notification: Notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("نظام التركيز نشط")
            .setContentText("يعمل في الخلفية للحفاظ على بيئة التركيز")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setColor(0xFFC9A84C.toInt())
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID, "خدمة التركيز",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description          = "إشعار دائم لضمان استمرارية خدمة التركيز"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }
}

object FocusChannelHolder {
    var messenger: io.flutter.plugin.common.BinaryMessenger? = null
}
