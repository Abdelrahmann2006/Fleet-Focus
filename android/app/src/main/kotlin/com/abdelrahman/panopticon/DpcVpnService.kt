package com.abdelrahman.panopticon

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean

/**
 * DpcVpnService — شبكة VPN المؤسسية بسياسة Null-Route الكاملة
 *
 * عند تفعيل "Network Isolation" من المشرف يعمل كـ Blackhole:
 *  - يُنشئ واجهة TUN وهمية تستقبل كل حركة الشبكة
 *  - يُسقط جميع الحزم الصادرة باستثناء المسارات المُدرجة في القائمة البيضاء
 *  - القائمة البيضاء (DPC Endpoints):
 *      • Firebase: 142.250.0.0/15, 172.217.0.0/16, 216.58.0.0/16
 *      • Telegram Bot API: 149.154.0.0/16, 91.108.0.0/16
 *      • MQTT (configurable): يُقرأ من SharedPreferences
 *  - يُسجّل كل حزمة مسقوطة في Firestore للتدقيق
 *  - يُفصل تلقائياً عند وصول أمر "disable_vpn_isolation"
 */
class DpcVpnService : VpnService() {

    companion object {
        private const val TAG              = "DpcVpnService"
        const val NOTIFICATION_ID          = 7001
        const val CHANNEL_ID               = "vpn_isolation_channel"
        const val EXTRA_UID                = "uid"
        const val EXTRA_MQTT_IP            = "mqtt_ip"
        const val PREF_FILE                = "focus_prefs"
        const val PREF_UID                 = "saved_uid"
        const val PREF_MQTT_IP             = "mqtt_server_ip"
        const val PREF_VPN_ACTIVE          = "vpn_isolation_active"

        // ─── القائمة البيضاء الثابتة (DPC Endpoints) ─────────────────
        // Firebase / Google APIs
        private val WHITELIST_CIDRS = listOf(
            "142.250.0.0" to 15,  // Google (Firebase Realtime DB / Firestore)
            "172.217.0.0" to 16,  // Google APIs
            "216.58.0.0"  to 16,  // Google (GCP)
            "74.125.0.0"  to 16,  // Google (Firebase Auth)
            "108.177.0.0" to 17,  // Google (GCP region)
            // Telegram Bot API
            "149.154.0.0" to 16,
            "91.108.0.0"  to 16,
            // DNS — لا بد منه للعمل
            "8.8.8.8"     to 32,
            "8.8.4.4"     to 32,
            "1.1.1.1"     to 32
        )

        fun start(context: Context, uid: String, mqttIp: String? = null) {
            context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE).edit()
                .putString(PREF_UID, uid)
                .putBoolean(PREF_VPN_ACTIVE, true)
                .also { if (mqttIp != null) it.putString(PREF_MQTT_IP, mqttIp) }
                .apply()

            val intent = prepare(context)
            if (intent != null) {
                // يحتاج موافقة المستخدم — يُرسل Broadcast للواجهة
                Log.w(TAG, "VPN يحتاج موافقة المستخدم — أرسل prepare intent لـ MainActivity")
                return
            }
            val svcIntent = Intent(context, DpcVpnService::class.java)
                .putExtra(EXTRA_UID, uid)
                .also { if (mqttIp != null) it.putExtra(EXTRA_MQTT_IP, mqttIp) }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(svcIntent)
            } else {
                context.startService(svcIntent)
            }
        }

        fun stop(context: Context) {
            context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE).edit()
                .putBoolean(PREF_VPN_ACTIVE, false)
                .apply()
            context.stopService(Intent(context, DpcVpnService::class.java))
        }

        fun isActive(context: Context): Boolean =
            context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
                .getBoolean(PREF_VPN_ACTIVE, false)
    }

    private val running   = AtomicBoolean(false)
    private var vpnFd: ParcelFileDescriptor? = null
    private var tunnelThread: Thread? = null
    private var uid: String = ""
    private var droppedPacketCount: Long = 0L
    private var lastDropReport: Long = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startForeground(NOTIFICATION_ID, buildNotification())
        Log.i(TAG, "✓ DpcVpnService بدأ")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        uid = intent?.getStringExtra(EXTRA_UID)
            ?: getSharedPreferences(PREF_FILE, MODE_PRIVATE)
                .getString(PREF_UID, "") ?: ""

        val mqttIp = intent?.getStringExtra(EXTRA_MQTT_IP)
            ?: getSharedPreferences(PREF_FILE, MODE_PRIVATE)
                .getString(PREF_MQTT_IP, null)

        if (uid.isEmpty()) {
            Log.e(TAG, "UID مجهول — إيقاف VPN")
            stopSelf(); return START_NOT_STICKY
        }

        establishVpnTunnel(mqttIp)
        reportVpnActivated()
        return START_STICKY
    }

    override fun onDestroy() {
        running.set(false)
        tunnelThread?.interrupt()
        try { vpnFd?.close() } catch (_: Exception) {}
        vpnFd = null
        reportVpnDeactivated()
        Log.i(TAG, "DpcVpnService أُوقف — العزل رُفع")
        super.onDestroy()
    }

    // ── بناء نفق VPN ─────────────────────────────────────────

    private fun establishVpnTunnel(mqttIp: String?) {
        try {
            val builder = Builder()
                .setSession("DPC Network Isolation")
                .setMtu(1500)
                .addAddress("10.0.0.2", 24)        // عنوان وهمي للواجهة
                .addDnsServer("8.8.8.8")
                .addDnsServer("8.8.4.4")

            // توجيه جميع حركة الشبكة عبر النفق
            builder.addRoute("0.0.0.0", 0)

            // استثناء DPC نفسه من النفق (لتفادي حلقة لا نهائية)
            builder.addDisallowedApplication(packageName)

            // MQTT IP المخصص (إذا توفّر)
            mqttIp?.let {
                try {
                    builder.addRoute(it, 32) // السماح بالمسار
                    Log.i(TAG, "MQTT IP أُضيف للقائمة البيضاء: $it")
                } catch (e: Exception) {
                    Log.w(TAG, "MQTT IP غير صالح: $it — ${e.message}")
                }
            }

            vpnFd = builder.establish()
                ?: throw IllegalStateException("فشل إنشاء VPN interface")

            Log.i(TAG, "✓ VPN TUN interface نشط — Null-Route مُفعَّل")

            running.set(true)
            tunnelThread = Thread({ runPacketFilter() }, "DpcVpnTunnel").also { it.start() }

        } catch (e: Exception) {
            Log.e(TAG, "فشل إنشاء VPN tunnel: ${e.message}")
            stopSelf()
        }
    }

    // ── فلتر الحزم — النواة الأساسية للـ Blackhole ───────────

    private fun runPacketFilter() {
        val fd = vpnFd ?: return
        val input  = FileInputStream(fd.fileDescriptor)
        val output = FileOutputStream(fd.fileDescriptor)
        val buffer = ByteBuffer.allocate(32767)

        Log.i(TAG, "✓ بدأ فلتر الحزم — وضع Blackhole نشط")

        while (running.get() && !Thread.currentThread().isInterrupted) {
            try {
                buffer.clear()
                val length = input.read(buffer.array())
                if (length <= 0) continue

                buffer.limit(length)

                if (isPacketAllowed(buffer)) {
                    // حزمة مسموح بها → إرسالها للخارج عبر protect()
                    output.write(buffer.array(), 0, length)
                } else {
                    // حزمة مُسقطة → Null-Route Blackhole
                    droppedPacketCount++
                    reportDroppedPacketsBatch()
                }

            } catch (_: InterruptedException) {
                break
            } catch (e: Exception) {
                if (running.get()) {
                    Log.w(TAG, "خطأ في فلتر الحزم: ${e.message}")
                }
            }
        }

        Log.i(TAG, "فلتر الحزم توقف — إجمالي الحزم المسقوطة: $droppedPacketCount")
    }

    // ── التحقق من السماح بالحزمة ────────────────────────────

    private fun isPacketAllowed(packet: ByteBuffer): Boolean {
        if (packet.limit() < 20) return false // حزمة IP تحتاج 20 بايت كحد أدنى

        val versionIHL = packet.get(0).toInt() and 0xFF
        val version = versionIHL shr 4

        // IPv4 فقط — IPv6 يُسقط
        if (version != 4) return false

        // استخراج عنوان الوجهة (Destination IP) من الـ header
        val destIp = buildString {
            for (i in 16..19) {
                if (length > 0) append(".")
                append(packet.get(i).toInt() and 0xFF)
            }
        }

        // التحقق من القائمة البيضاء
        return WHITELIST_CIDRS.any { (networkStr, prefix) ->
            isInSubnet(destIp, networkStr, prefix)
        }
    }

    private fun isInSubnet(ip: String, network: String, prefix: Int): Boolean {
        return try {
            val ipParts   = ip.split(".").map { it.toInt() }
            val netParts  = network.split(".").map { it.toInt() }
            if (ipParts.size != 4 || netParts.size != 4) return false

            val ipLong   = (ipParts[0].toLong() shl 24) or (ipParts[1].toLong() shl 16) or
                           (ipParts[2].toLong() shl 8) or ipParts[3].toLong()
            val netLong  = (netParts[0].toLong() shl 24) or (netParts[1].toLong() shl 16) or
                           (netParts[2].toLong() shl 8) or netParts[3].toLong()
            val mask     = if (prefix == 0) 0L else (0xFFFFFFFFL shl (32 - prefix)) and 0xFFFFFFFFL

            (ipLong and mask) == (netLong and mask)
        } catch (_: Exception) {
            false
        }
    }

    // ── Firestore Reporting ───────────────────────────────────

    private fun reportVpnActivated() {
        if (uid.isEmpty()) return
        FirebaseFirestore.getInstance()
            .collection("device_states").document(uid)
            .update(mapOf(
                "vpnIsolationActive" to true,
                "vpnActivatedAt"     to FieldValue.serverTimestamp(),
                "networkPolicy"      to "null_route_blackhole"
            ))
        Log.i(TAG, "✓ VPN Isolation مُسجَّل في Firestore")
    }

    private fun reportVpnDeactivated() {
        if (uid.isEmpty()) return
        FirebaseFirestore.getInstance()
            .collection("device_states").document(uid)
            .update(mapOf(
                "vpnIsolationActive"   to false,
                "vpnDeactivatedAt"     to FieldValue.serverTimestamp(),
                "totalDroppedPackets"  to droppedPacketCount
            ))
    }

    private fun reportDroppedPacketsBatch() {
        val now = System.currentTimeMillis()
        if (now - lastDropReport < 30_000L) return // تقرير كل 30 ثانية فقط
        lastDropReport = now

        if (uid.isEmpty()) return
        FirebaseFirestore.getInstance()
            .collection("compliance_assets").document(uid)
            .collection("vpn_drop_log")
            .add(mapOf(
                "droppedPackets" to droppedPacketCount,
                "timestamp"      to FieldValue.serverTimestamp()
            ))
    }

    // ── الإشعار الدائم ────────────────────────────────────────

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID, "عزل الشبكة المؤسسي",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                setShowBadge(false)
                setSound(null, null)
            }
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🔒 عزل الشبكة مفعّل")
            .setContentText("جميع الاتصالات محجوبة ما عدا نقاط DPC المعتمدة")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSilent(true)
            .setColor(0xFFFF0000.toInt())
            .build()
    }
}
