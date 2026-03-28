package com.abdelrahman.panopticon

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log

/**
 * AlarmWakeUpReceiver — مُوقِظ دورة حياة الخدمات (Doze Mode Bypass)
 *
 * يُحلّ المشكلة الحرجة: Handler.postDelayed() يتوقف عندما يدخل
 * Android في وضع Doze Mode (الإسبات العميق). AlarmManager.setExactAndAllowWhileIdle()
 * هو الوحيد المضمون للتشغيل حتى في Doze.
 *
 * الآلية:
 *  1. TelemetryPublisherService يُجدوِل AlarmWakeUpReceiver كل 30 ثانية
 *  2. عند الإطلاق، يُعيد تشغيل TelemetryPublisherService + يُجدوِل الإنذار التالي
 *  3. CommandListenerService يستخدم نفس الآلية للحفاظ على مستمع Firestore حياً
 *
 * النتيجة: دورة نشر مضمونة كل 30 ثانية حتى في Doze Mode الكامل.
 */
class AlarmWakeUpReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG                = "AlarmWakeUp"
        const val ACTION_WAKE_TELEMETRY      = "com.abdelrahman.panopticon.WAKE_TELEMETRY"
        const val ACTION_WAKE_COMMAND        = "com.abdelrahman.panopticon.WAKE_COMMAND"

        private const val TELEMETRY_INTERVAL = 30_000L   // 30 ثانية — وضع عادي
        private const val COMMAND_INTERVAL   = 60_000L   // 60 ثانية — فحص الأوامر
        private const val RADAR_INTERVAL     = 5_000L    // 5 ثوان — وضع الرادار

        private const val REQ_TELEMETRY = 1001
        private const val REQ_COMMAND   = 1002

        /**
         * يُجدوِل إنذار الـ Telemetry القادم.
         * يُستدعى من TelemetryPublisherService.onCreate() وبعد كل إطلاق.
         */
        fun scheduleTelemetryWake(context: Context, intervalMs: Long = TELEMETRY_INTERVAL) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, AlarmWakeUpReceiver::class.java)
                .setAction(ACTION_WAKE_TELEMETRY)
            val pending = PendingIntent.getBroadcast(
                context, REQ_TELEMETRY, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val triggerAt = SystemClock.elapsedRealtime() + intervalMs

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pending
                    )
                } else {
                    alarmManager.setExact(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pending
                    )
                }
                Log.d(TAG, "✓ إنذار Telemetry مُجدوَل بعد ${intervalMs / 1000}s")
            } catch (e: SecurityException) {
                Log.w(TAG, "يحتاج إذن SCHEDULE_EXACT_ALARM: ${e.message}")
                // fallback للـ inexact alarm
                alarmManager.set(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pending
                )
            }
        }

        /**
         * يُجدوِل إنذار فحص الأوامر القادم.
         * يُستدعى من CommandListenerService.
         */
        fun scheduleCommandWake(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, AlarmWakeUpReceiver::class.java)
                .setAction(ACTION_WAKE_COMMAND)
            val pending = PendingIntent.getBroadcast(
                context, REQ_COMMAND, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val triggerAt = SystemClock.elapsedRealtime() + COMMAND_INTERVAL

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pending
                    )
                } else {
                    alarmManager.setExact(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pending
                    )
                }
            } catch (e: SecurityException) {
                alarmManager.set(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pending
                )
            }
        }

        /** يُلغي جميع الإنذارات المُجدوَلة */
        fun cancelAll(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            listOf(
                Pair(REQ_TELEMETRY, ACTION_WAKE_TELEMETRY),
                Pair(REQ_COMMAND,   ACTION_WAKE_COMMAND),
            ).forEach { (reqCode, action) ->
                val pending = PendingIntent.getBroadcast(
                    context, reqCode,
                    Intent(context, AlarmWakeUpReceiver::class.java).setAction(action),
                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                )
                pending?.let { alarmManager.cancel(it) }
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val uid = context
            .getSharedPreferences(CommandListenerService.PREF_FILE, Context.MODE_PRIVATE)
            .getString(CommandListenerService.PREF_UID, null) ?: return

        when (intent.action) {

            ACTION_WAKE_TELEMETRY -> {
                Log.d(TAG, "🔔 إيقاظ Telemetry — UID: $uid")
                // إعادة تشغيل TelemetryPublisherService إذا كان متوقفاً
                val svcIntent = Intent(context, TelemetryPublisherService::class.java)
                    .putExtra(TelemetryPublisherService.EXTRA_UID, uid)
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(svcIntent)
                    } else {
                        context.startService(svcIntent)
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "فشل إعادة تشغيل Telemetry: ${e.message}")
                }
                // جدوِل الإطلاق التالي
                scheduleTelemetryWake(context)
            }

            ACTION_WAKE_COMMAND -> {
                Log.d(TAG, "🔔 إيقاظ CommandListener — UID: $uid")
                // إعادة تشغيل CommandListenerService إذا كان متوقفاً
                val cmdIntent = Intent(context, CommandListenerService::class.java)
                    .putExtra(CommandListenerService.EXTRA_UID, uid)
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(cmdIntent)
                    } else {
                        context.startService(cmdIntent)
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "فشل إعادة تشغيل CommandListener: ${e.message}")
                }
                // جدوِل الإطلاق التالي
                scheduleCommandWake(context)
            }
        }
    }
}
