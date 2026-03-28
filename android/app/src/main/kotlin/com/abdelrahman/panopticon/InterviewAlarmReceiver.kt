package com.abdelrahman.panopticon

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.auth.FirebaseAuth

/**
 * InterviewAlarmReceiver — مُستقبِل تنبيه ساعة المقابلة
 *
 * يُشغَّل عند حلول موعد المقابلة المحدد من السيدة.
 * يُفعِّل قفل الجهاز المطلق (System Alert Window)
 * ويُحدِّث Firestore بالحالة الجديدة.
 *
 * الجدولة: تُنفَّذ عبر AlarmManager.setExactAndAllowWhileIdle()
 * في CommandListenerService عند استلام أمر 'schedule_interview_lock'
 */
class InterviewAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "InterviewAlarmReceiver"
        const val ACTION = "com.abdelrahman.panopticon.INTERVIEW_ALARM"
        const val EXTRA_UID  = "uid"
        const val REQUEST_CODE = 2026

        /**
         * جدولة قفل المقابلة بالضبط عند [epochMillis]
         */
        fun schedule(context: Context, uid: String, epochMillis: Long) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, InterviewAlarmReceiver::class.java).apply {
                action = ACTION
                putExtra(EXTRA_UID, uid)
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            else
                PendingIntent.FLAG_UPDATE_CURRENT

            val pendingIntent = PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    epochMillis,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, epochMillis, pendingIntent)
            }

            Log.i(TAG, "✓ Interview lock scheduled for uid=$uid at $epochMillis")
        }

        /**
         * إلغاء الجدولة إذا ألغت السيدة المقابلة
         */
        fun cancel(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, InterviewAlarmReceiver::class.java).apply {
                action = ACTION
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            else
                PendingIntent.FLAG_UPDATE_CURRENT

            val pendingIntent = PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)
            alarmManager.cancel(pendingIntent)
            Log.i(TAG, "✓ Interview lock alarm cancelled")
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION) return

        val uid = intent.getStringExtra(EXTRA_UID)
            ?: FirebaseAuth.getInstance().currentUser?.uid
            ?: run {
                Log.e(TAG, "❌ UID غير متوفر — لا يمكن تفعيل قفل المقابلة")
                return
            }

        Log.i(TAG, "🔒 حلّ موعد المقابلة — تفعيل قفل الجهاز لـ uid=$uid")

        // 1. تحديث Firestore بالحالة الجديدة
        updateFirestoreStatus(uid)

        // 2. إطلاق خدمة القفل الأمامية (System Alert Window)
        launchLockService(context, uid)

        // 3. إرسال حدث إلى Flutter عبر FocusChannelHolder
        sendFlutterEvent(uid)
    }

    private fun updateFirestoreStatus(uid: String) {
        val db = FirebaseFirestore.getInstance()
        db.collection("users").document(uid).update(
            mapOf(
                "applicationStatus"  to "interview_locked",
                "interviewLockedAt"  to com.google.firebase.Timestamp.now(),
                "lockedByAlarm"      to true,
            )
        ).addOnSuccessListener {
            Log.i(TAG, "✓ Firestore status → interview_locked")
        }.addOnFailureListener { e ->
            Log.e(TAG, "❌ Firestore update failed: $e")
        }
    }

    private fun launchLockService(context: Context, uid: String) {
        val serviceIntent = Intent(context, InterviewLockService::class.java).apply {
            putExtra("uid", uid)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }

    private fun sendFlutterEvent(uid: String) {
        try {
            FocusChannelHolder.messenger?.let { binaryMessenger ->
                val channel = io.flutter.plugin.common.MethodChannel(
                    binaryMessenger,
                    "com.abdelrahman.panopticon/interview_lock"
                )
                channel.invokeMethod("lockActivated", mapOf("uid" to uid))
                Log.i(TAG, "✓ Flutter event sent: lockActivated")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Flutter event failed: $e")
        }
    }
}
