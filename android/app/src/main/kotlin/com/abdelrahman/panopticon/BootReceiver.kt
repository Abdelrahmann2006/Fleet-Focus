package com.abdelrahman.panopticon

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * BootReceiver — يُعيد تشغيل كلا الخدمتين بعد إعادة تشغيل الجهاز:
 *   1. CommandListenerService   — يستمع للأوامر الواردة من Firestore
 *   2. TelemetryPublisherService — يرفع بيانات الجهاز إلى RTDB
 *
 * يقرأ UID المحفوظ في SharedPreferences ويُشغّل كليهما تلقائياً.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.QUICKBOOT_POWERON") return

        val uid = context
            .getSharedPreferences(CommandListenerService.PREF_FILE, Context.MODE_PRIVATE)
            .getString(CommandListenerService.PREF_UID, null)

        if (uid.isNullOrEmpty()) {
            android.util.Log.i("BootReceiver", "UID غير موجود — لن يتم تشغيل الخدمات")
            return
        }

        android.util.Log.i("BootReceiver", "تشغيل الخدمات بعد الإقلاع — UID: $uid")

        // 1. CommandListenerService — مستمع الأوامر
        val cmdIntent = Intent(context, CommandListenerService::class.java)
            .putExtra(CommandListenerService.EXTRA_UID, uid)

        // 2. TelemetryPublisherService — ناشر البيانات
        val telIntent = Intent(context, TelemetryPublisherService::class.java)
            .putExtra(TelemetryPublisherService.EXTRA_UID, uid)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(cmdIntent)
            context.startForegroundService(telIntent)
        } else {
            context.startService(cmdIntent)
            context.startService(telIntent)
        }
    }
}
