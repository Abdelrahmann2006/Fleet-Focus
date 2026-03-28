package com.abdelrahman.panopticon

import android.Manifest
import android.app.*
import android.app.admin.DevicePolicyManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.StatFs
import android.provider.Settings
import android.text.TextUtils
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ServerValue

/**
 * TelemetryPublisherService — خدمة الاستشعار الخلفية
 *
 * تجمع وترفع بيانات الجهاز إلى Firebase Realtime Database كل 30 ثانية:
 *  • البطارية (% + حالة الشحن + الصحة)
 *  • الشاشة (نشطة / خاملة)
 *  • التخزين (% المساحة الحرة)
 *  • الصلاحيات (Admin Shield, Accessibility, Overlay, Battery Optimization)
 *  • نبضة حياة (pulse)
 *
 * تعمل مستقلةً عن CommandListenerService — مسؤولياتها مختلفة:
 *   CommandListenerService  = يستمع للأوامر الواردة ويُنفّذها
 *   TelemetryPublisherService = يرفع بيانات الجهاز للخادم
 *
 * محسَّنة لاستهلاك بطارية منخفض:
 *   • PARTIAL_WAKE_LOCK فقط عند كل دورة نشر
 *   • لا GPS — GPS تُدار من طبقة Flutter (geolocator)
 *   • الـ Handler loop فعّال أكثر من WorkManager للـ real-time
 */
class TelemetryPublisherService : Service() {

    companion object {
        const val NOTIFICATION_ID       = 2002
        const val CHANNEL_ID            = "telemetry_channel"
        const val EXTRA_UID             = "uid"
        const val EXTRA_RADAR_MODE      = "radar_mode"
        const val PREF_FILE             = "focus_prefs"
        const val PREF_UID              = "saved_uid"
        const val PREF_RADAR_ACTIVE     = "radar_mode_active"
        const val PUBLISH_INTERVAL      = 30_000L   // 30 ثانية — وضع عادي
        const val RADAR_INTERVAL_MS     = 1_000L    // 1 ثانية — وضع الرادار
        const val RADAR_MIN_DIST_M      = 0f        // بدون حد أدنى للمسافة في Radar
        const val RTDB_ROOT             = "device_states"

        fun start(context: Context, uid: String) {
            val intent = Intent(context, TelemetryPublisherService::class.java)
                .putExtra(EXTRA_UID, uid)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, TelemetryPublisherService::class.java))
        }

        /**
         * تُفعّل وضع الرادار عالي التردد (1 ثانية GPS + MQTT)
         */
        fun enableRadarMode(context: Context, uid: String) {
            context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                .edit().putBoolean(PREF_RADAR_ACTIVE, true).apply()
            // إعادة تشغيل الخدمة بعلامة الرادار
            val intent = Intent(context, TelemetryPublisherService::class.java)
                .putExtra(EXTRA_UID, uid)
                .putExtra(EXTRA_RADAR_MODE, true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            android.util.Log.i("TelemetryService", "🔴 Radar Mode مُفعَّل — GPS 1 ثانية")
        }

        /**
         * تُعطّل وضع الرادار وتعود للـ 30 ثانية
         */
        fun disableRadarMode(context: Context, uid: String) {
            context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                .edit().putBoolean(PREF_RADAR_ACTIVE, false).apply()
            val intent = Intent(context, TelemetryPublisherService::class.java)
                .putExtra(EXTRA_UID, uid)
                .putExtra(EXTRA_RADAR_MODE, false)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            android.util.Log.i("TelemetryService", "⚪ Radar Mode مُعطَّل — GPS 30 ثانية")
        }
    }

    private var uid: String? = null
    private val handler = Handler(Looper.getMainLooper())
    private var batteryReceiver: BroadcastReceiver? = null
    private var lastBatteryLevel = -1
    private var lastIsCharging   = false

    // Radar Mode
    private var isRadarMode = false
    private var locationManager: LocationManager? = null
    private var lastRadarLat = 0.0
    private var lastRadarLon = 0.0
    private var lastRadarAccuracy = 0f

    // ── Lifecycle ──────────────────────────────────────────────

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startForeground(NOTIFICATION_ID, buildNotification())
        registerBatteryReceiver()
        // ── AlarmManager Doze Bypass ──────────────────────────────
        // Handler.postDelayed يتوقف في Doze Mode — AlarmManager مضمون
        AlarmWakeUpReceiver.scheduleTelemetryWake(this)
        android.util.Log.i("TelemetryService", "✓ TelemetryPublisherService created + AlarmManager مُجدوَل")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        uid = intent?.getStringExtra(EXTRA_UID)
            ?: getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                .getString(PREF_UID, null)

        if (uid.isNullOrEmpty()) {
            android.util.Log.w("TelemetryService", "UID مجهول — إيقاف الخدمة")
            stopSelf()
            return START_NOT_STICKY
        }

        getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
            .edit().putString(PREF_UID, uid).apply()

        // قراءة حالة Radar Mode
        val radarFromIntent = intent?.getBooleanExtra(EXTRA_RADAR_MODE, false) ?: false
        val radarFromPrefs  = getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
            .getBoolean(PREF_RADAR_ACTIVE, false)
        val newRadarMode = radarFromIntent || radarFromPrefs

        if (newRadarMode != isRadarMode) {
            isRadarMode = newRadarMode
            stopRadarGps()
            if (isRadarMode) startRadarGps()
        }

        // تسجيل حالة Disconnect في RTDB
        setOfflinePresence(uid!!)

        // بدء دورة النشر (إذا لم تكن نشطة)
        handler.removeCallbacks(publishRunnable)
        scheduleNextPublish()

        android.util.Log.i("TelemetryService",
            "✓ Telemetry UID: $uid | Radar: $isRadarMode")
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        unregisterBatteryReceiver()
        stopRadarGps()
        uid?.let { markOffline(it) }
        // إلغاء إنذارات AlarmManager عند الإيقاف المقصود
        // (BootReceiver يُعيد الجدولة عند إعادة الإقلاع)
        android.util.Log.i("TelemetryService", "TelemetryService destroyed")
        super.onDestroy()
    }

    // ── Radar GPS ──────────────────────────────────────────────

    private fun startRadarGps() {
        if (ContextCompat.checkSelfPermission(
                this, Manifest.permission.ACCESS_FINE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            android.util.Log.e("TelemetryService", "لا يوجد إذن GPS للرادار")
            return
        }
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        try {
            locationManager?.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                RADAR_INTERVAL_MS,
                RADAR_MIN_DIST_M,
                radarLocationListener
            )
            // إعلام Firestore بتفعيل الرادار
            uid?.let { u ->
                com.google.firebase.firestore.FirebaseFirestore.getInstance()
                    .collection(RTDB_ROOT)
                    .document(u)
                    .update("radarMode", true)
                    .addOnFailureListener { /* تجاهل */ }
            }
            android.util.Log.i("TelemetryService", "🔴 Radar GPS بدأ — 1 ثانية")
        } catch (e: Exception) {
            android.util.Log.e("TelemetryService", "خطأ في بدء Radar GPS: ${e.message}")
        }
    }

    private fun stopRadarGps() {
        locationManager?.removeUpdates(radarLocationListener)
        locationManager = null
        // إعلام Firestore بإيقاف الرادار
        uid?.let { u ->
            com.google.firebase.firestore.FirebaseFirestore.getInstance()
                .collection(RTDB_ROOT)
                .document(u)
                .update("radarMode", false)
                .addOnFailureListener { /* تجاهل */ }
        }
        android.util.Log.i("TelemetryService", "Radar GPS أُوقف")
    }

    private val radarLocationListener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            lastRadarLat      = location.latitude
            lastRadarLon      = location.longitude
            lastRadarAccuracy = location.accuracy

            val currentUid = uid ?: return

            // نشر فوري عبر RTDB (MQTT-like via Firebase)
            val radarData = mapOf(
                "radarLat"      to location.latitude,
                "radarLon"      to location.longitude,
                "radarAccuracy" to location.accuracy.toDouble(),
                "radarSpeed"    to (if (location.hasSpeed()) location.speed.toDouble() else 0.0),
                "radarTs"       to ServerValue.TIMESTAMP,
                "radarMode"     to true
            )
            FirebaseDatabase.getInstance()
                .getReference("$RTDB_ROOT/$currentUid/radar")
                .setValue(radarData)
        }

        @Deprecated("Deprecated in Java")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
    }

    // ── Publish Loop ───────────────────────────────────────────

    private fun scheduleNextPublish() {
        handler.postDelayed(publishRunnable, PUBLISH_INTERVAL)
    }

    private val publishRunnable = object : Runnable {
        override fun run() {
            uid?.let { publishTelemetry(it) }
            scheduleNextPublish()
        }
    }

    private fun publishTelemetry(uid: String) {
        val pm   = getSystemService(Context.POWER_SERVICE) as PowerManager
        val dpm  = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val comp = ComponentName(this, MyDeviceAdminReceiver::class.java)

        val data = buildMap {
            // البطارية
            put("batteryPct",      lastBatteryLevel)
            put("batteryCharging", lastIsCharging)

            // الشاشة
            put("screenActive", pm.isInteractive)

            // نبضة
            put("pulse", if (pm.isInteractive) "active" else "idle")

            // التخزين
            put("storageFreePct", getStorageFreePct())

            // الصلاحيات
            put("adminShield",               dpm.isAdminActive(comp))
            put("accessibilityEnabled",      isAccessibilityEnabled())
            put("overlayPermission",         Settings.canDrawOverlays(this@TelemetryPublisherService))
            put("batteryOptimizationIgnored",
                pm.isIgnoringBatteryOptimizations(packageName))

            // الطابع الزمني
            put("lastSeen", ServerValue.TIMESTAMP)
        }

        FirebaseDatabase.getInstance()
            .getReference("$RTDB_ROOT/$uid")
            .updateChildren(data)
            .addOnSuccessListener {
                android.util.Log.d("TelemetryService", "✓ RTDB updated for $uid")
            }
            .addOnFailureListener { e ->
                android.util.Log.e("TelemetryService", "RTDB error: ${e.message}")
            }
    }

    // ── Presence (onDisconnect) ────────────────────────────────

    private fun setOfflinePresence(uid: String) {
        FirebaseDatabase.getInstance()
            .getReference("$RTDB_ROOT/$uid")
            .onDisconnect()
            .updateChildren(
                mapOf(
                    "pulse"    to "offline",
                    "lastSeen" to ServerValue.TIMESTAMP,
                )
            )
    }

    private fun markOffline(uid: String) {
        FirebaseDatabase.getInstance()
            .getReference("$RTDB_ROOT/$uid")
            .updateChildren(
                mapOf(
                    "pulse"    to "offline",
                    "lastSeen" to ServerValue.TIMESTAMP,
                )
            )
    }

    // ── Battery Receiver ───────────────────────────────────────

    private fun registerBatteryReceiver() {
        batteryReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent == null) return

                lastBatteryLevel = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                val scale  = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                if (scale > 0) lastBatteryLevel = (lastBatteryLevel * 100 / scale)

                val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                lastIsCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                        status == BatteryManager.BATTERY_STATUS_FULL

                // نشر فوري عند تغيير حالة الشحن
                uid?.let { currentUid ->
                    FirebaseDatabase.getInstance()
                        .getReference("$RTDB_ROOT/$currentUid")
                        .updateChildren(
                            mapOf(
                                "batteryPct"      to lastBatteryLevel,
                                "batteryCharging" to lastIsCharging,
                                "lastSeen"        to ServerValue.TIMESTAMP,
                            )
                        )
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_BATTERY_CHANGED)
            addAction(Intent.ACTION_POWER_CONNECTED)
            addAction(Intent.ACTION_POWER_DISCONNECTED)
        }
        registerReceiver(batteryReceiver, filter)
    }

    private fun unregisterBatteryReceiver() {
        batteryReceiver?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
        }
        batteryReceiver = null
    }

    // ── Helpers ────────────────────────────────────────────────

    private fun getStorageFreePct(): Double {
        return try {
            val stat = StatFs(dataDir.absolutePath)
            val free  = stat.availableBlocksLong * stat.blockSizeLong
            val total = stat.blockCountLong * stat.blockSizeLong
            if (total == 0L) 0.0 else (free.toDouble() / total) * 100.0
        } catch (_: Exception) { 0.0 }
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

    // ── Notification ───────────────────────────────────────────

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "خدمة بيانات الجهاز",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "ترفع بيانات الجهاز بشكل دوري"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("مزامنة البيانات")
            .setContentText("يرفع بيانات الجهاز بشكل دوري")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setColor(0xFFC9A84C.toInt())
            .build()
    }
}
