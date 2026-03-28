package com.abdelrahman.panopticon

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import java.net.HttpURLConnection
import java.net.URL

/**
 * GeofenceMonitorService — خدمة المحيط الجغرافي الآمن
 *
 * تُراقب موقع الجهاز محلياً وتُطبّق حدود النطاق الجغرافي (Work Zone).
 *
 * المنطق:
 *  1. تقرأ مركز النطاق + نصف القطر من Firestore: geofence_config/{uid}
 *  2. تُحدّث الموقع عبر LocationManager كل 30 ثانية
 *  3. إذا خرج الجهاز عن النطاق بدون Travel Pass مفعّل:
 *     → تُسجل الخرق في compliance_assets/{uid}/breach_log
 *     → تُشغّل PanicAlarmService (إنذار صوتي)
 *     → تُشغّل LostModeOverlayService (قفل بصري)
 *     → تُرسل إشعار NTFY.sh للمشرف
 *  4. إذا كان Travel Pass مفعّلاً → تسجيل تحذير فقط (بدون إجراء)
 *
 * Firestore Schema:
 *   geofence_config/{uid}: { centerLat, centerLon, radiusMeters, enabled }
 *   geofence_status/{uid}: { insideZone, lastLat, lastLon, lastChecked }
 *   compliance_assets/{uid}/breach_log: { lat, lon, distanceMeters, timestamp, travelPassActive }
 */
class GeofenceMonitorService : Service() {

    companion object {
        private const val TAG = "GeofenceMonitor"
        const val NOTIFICATION_ID = 6001
        const val CHANNEL_ID = "geofence_channel"
        const val EXTRA_UID = "uid"
        const val PREF_FILE = "focus_prefs"
        const val PREF_UID = "saved_uid"

        // Firestore collections
        const val COL_CONFIG = "geofence_config"
        const val COL_STATUS = "geofence_status"
        const val COL_BREACH = "breach_log"

        // شعار التطبيق على NTFY
        const val NTFY_TOPIC = "panopticon-alerts"

        // فترة تحديث الموقع (30 ثانية بالمللي ثانية)
        const val LOCATION_INTERVAL_MS = 30_000L
        const val LOCATION_MIN_DISTANCE_M = 10f

        fun start(context: Context, uid: String) {
            val intent = Intent(context, GeofenceMonitorService::class.java)
                .putExtra(EXTRA_UID, uid)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, GeofenceMonitorService::class.java))
        }
    }

    private var uid: String = ""
    private var locationManager: LocationManager? = null
    private var geofenceConfigListener: ListenerRegistration? = null

    // إعدادات النطاق الحالية
    private var centerLat: Double = 0.0
    private var centerLon: Double = 0.0
    private var radiusMeters: Double = 500.0
    private var geofenceEnabled: Boolean = false

    // حالة الموقع الأخير
    private var lastLat: Double = 0.0
    private var lastLon: Double = 0.0
    private var isInsideZone: Boolean = true
    private var breachNotified: Boolean = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startForeground(NOTIFICATION_ID, buildNotification())
        Log.i(TAG, "✓ GeofenceMonitorService بدأ")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        uid = intent?.getStringExtra(EXTRA_UID)
            ?: getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                .getString(PREF_UID, "") ?: ""

        if (uid.isEmpty()) {
            Log.e(TAG, "UID مجهول — إيقاف الخدمة")
            stopSelf()
            return START_NOT_STICKY
        }

        startLocationUpdates()
        listenGeofenceConfig()

        return START_STICKY
    }

    override fun onDestroy() {
        locationManager?.removeUpdates(locationListener)
        geofenceConfigListener?.remove()
        Log.i(TAG, "GeofenceMonitorService أُوقف")
        super.onDestroy()
    }

    // ── قراءة إعدادات النطاق من Firestore ────────────────────

    private fun listenGeofenceConfig() {
        geofenceConfigListener?.remove()
        geofenceConfigListener = FirebaseFirestore.getInstance()
            .collection(COL_CONFIG)
            .document(uid)
            .addSnapshotListener { snap, error ->
                if (error != null || snap == null) return@addSnapshotListener
                val data = snap.data ?: return@addSnapshotListener

                centerLat = (data["centerLat"] as? Number)?.toDouble() ?: 0.0
                centerLon = (data["centerLon"] as? Number)?.toDouble() ?: 0.0
                radiusMeters = (data["radiusMeters"] as? Number)?.toDouble() ?: 500.0
                geofenceEnabled = data["enabled"] as? Boolean ?: false
                breachNotified = false // إعادة تعيين عند تغيير الإعدادات

                Log.i(TAG, "✓ إعدادات النطاق: ($centerLat, $centerLon) r=${radiusMeters}m enabled=$geofenceEnabled")
            }
    }

    // ── تحديثات الموقع ────────────────────────────────────────

    private fun startLocationUpdates() {
        if (ContextCompat.checkSelfPermission(
                this, Manifest.permission.ACCESS_FINE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            Log.e(TAG, "لا يوجد إذن الموقع")
            return
        }

        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        try {
            locationManager?.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                LOCATION_INTERVAL_MS,
                LOCATION_MIN_DISTANCE_M,
                locationListener
            )
            // احتياطي: شبكة الجوال
            locationManager?.requestLocationUpdates(
                LocationManager.NETWORK_PROVIDER,
                LOCATION_INTERVAL_MS,
                LOCATION_MIN_DISTANCE_M,
                locationListener
            )
            Log.i(TAG, "✓ تحديثات GPS بدأت (30s)")
        } catch (e: Exception) {
            Log.e(TAG, "خطأ في بدء GPS: ${e.message}")
        }
    }

    private val locationListener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            lastLat = location.latitude
            lastLon = location.longitude
            onNewLocation(location)
        }

        @Deprecated("Deprecated in Java")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
    }

    // ── منطق التحقق من النطاق ────────────────────────────────

    private fun onNewLocation(location: Location) {
        // تحديث Firestore بالموقع الحالي
        updateGeofenceStatus(location)

        if (!geofenceEnabled) return
        if (centerLat == 0.0 && centerLon == 0.0) return // لم يُعيَّن النطاق بعد

        val center = Location("").apply {
            latitude = centerLat
            longitude = centerLon
        }

        val distance = location.distanceTo(center)
        val wasInside = isInsideZone
        isInsideZone = distance <= radiusMeters

        Log.d(TAG, "الموقع: (${lastLat}, ${lastLon}) → مسافة: ${distance.toInt()}m / ${radiusMeters.toInt()}m")

        when {
            // ── خرج للتو ─────────────────────────────────────
            wasInside && !isInsideZone -> {
                Log.w(TAG, "⚠ خروج عن النطاق! المسافة: ${distance.toInt()}m")
                onPerimeterBreach(distance)
            }

            // ── عاد للنطاق ────────────────────────────────────
            !wasInside && isInsideZone -> {
                Log.i(TAG, "✓ عاد للنطاق")
                breachNotified = false
                reportReturnToZone()
            }

            // ── خارج النطاق باستمرار ──────────────────────────
            !isInsideZone -> {
                Log.d(TAG, "لا يزال خارج النطاق: ${distance.toInt()}m")
            }
        }
    }

    // ── بروتوكول خرق المحيط ──────────────────────────────────

    private fun onPerimeterBreach(distanceMeters: Float) {
        val travelPassActive = TravelPassManager.isActive(this, uid)

        // تسجيل الخرق دائماً
        logBreachEvent(distanceMeters, travelPassActive)

        if (travelPassActive) {
            Log.i(TAG, "Travel Pass مفعّل — الخروج مسموح")
            return
        }

        if (breachNotified) return // لا تُكرر الإجراءات
        breachNotified = true

        Log.e(TAG, "⛔ خرق أمني! لا يوجد Travel Pass — تفعيل بروتوكول الاسترداد")

        // 1. إنذار صوتي + إشعار NTFY
        PanicAlarmService.start(this)

        // 2. قفل بصري (Lost Mode)
        LostModeOverlayService.activate(this)

        // 3. إشعار NTFY للمشرف
        sendBreachNotification(distanceMeters)
    }

    private fun logBreachEvent(distance: Float, travelPassActive: Boolean) {
        val breachData = mapOf(
            "lat" to lastLat,
            "lon" to lastLon,
            "distanceMeters" to distance.toInt(),
            "radiusMeters" to radiusMeters.toInt(),
            "travelPassActive" to travelPassActive,
            "timestamp" to FieldValue.serverTimestamp(),
            "severity" to if (travelPassActive) "INFO" else "CRITICAL"
        )

        FirebaseFirestore.getInstance()
            .collection("compliance_assets")
            .document(uid)
            .collection(COL_BREACH)
            .add(breachData)
            .addOnSuccessListener { Log.i(TAG, "✓ خرق مسجَّل في Firestore") }

        FirebaseFirestore.getInstance()
            .collection(COL_STATUS)
            .document(uid)
            .update(mapOf(
                "lastBreach" to FieldValue.serverTimestamp(),
                "lastBreachDistance" to distance.toInt(),
                "travelPassActive" to travelPassActive
            ))
    }

    private fun reportReturnToZone() {
        FirebaseFirestore.getInstance()
            .collection(COL_STATUS)
            .document(uid)
            .update(mapOf(
                "insideZone" to true,
                "lastReturnToZone" to FieldValue.serverTimestamp()
            ))
    }

    private fun updateGeofenceStatus(location: Location) {
        FirebaseFirestore.getInstance()
            .collection(COL_STATUS)
            .document(uid)
            .set(mapOf(
                "lastLat" to location.latitude,
                "lastLon" to location.longitude,
                "insideZone" to isInsideZone,
                "accuracy" to location.accuracy,
                "lastChecked" to FieldValue.serverTimestamp()
            ), com.google.firebase.firestore.SetOptions.merge())
    }

    // ── NTFY.sh — إشعار الاسترداد ─────────────────────────────

    private fun sendBreachNotification(distance: Float) {
        Thread {
            try {
                val url = URL("https://ntfy.sh/$NTFY_TOPIC")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.doOutput = true
                conn.setRequestProperty("Title", "🚨 خرق أمني — خروج عن النطاق")
                conn.setRequestProperty("Priority", "urgent")
                conn.setRequestProperty("Tags", "warning,location")
                val msg = "الجهاز خرج عن النطاق الآمن بمسافة ${distance.toInt()} متر! تم تفعيل بروتوكول الاسترداد."
                conn.outputStream.write(msg.toByteArray())
                conn.responseCode
                conn.disconnect()
                Log.i(TAG, "✓ NTFY إشعار الخرق أُرسل")
            } catch (e: Exception) {
                Log.w(TAG, "فشل إرسال NTFY: ${e.message}")
            }
        }.start()
    }

    // ── الإشعار الدائم ────────────────────────────────────────

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID, "مراقبة النطاق الجغرافي",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                setShowBadge(false)
                setSound(null, null)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("مراقبة النطاق الآمن")
            .setContentText("يراقب موقع الجهاز ضمن النطاق المصرح به")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSilent(true)
            .setColor(0xFFC9A84C.toInt())
            .build()
    }
}
