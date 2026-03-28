package com.abdelrahman.panopticon

import android.content.Context
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

/**
 * DlpScanEngine — محرك منع تسرب البيانات (Data Loss Prevention)
 *
 * يعمل بشكل خامد حتى يُنشَّط من MyAccessibilityService
 * عند رصد تطبيق عالي الخطورة.
 *
 * طبقات الفحص:
 *  Layer 1: Accessibility Node Tree — استخراج النصوص الظاهرة
 *  Layer 2: ML Kit TextRecognizer — تحليل لغوي للنص
 *  Layer 3: Keyword Engine — مطابقة الكلمات المفتاحية المحظورة
 *
 * عند اكتشاف تسرب:
 *  - يُرسل تحذيراً فورياً لـ Firestore
 *  - يُخطر Flutter عبر FocusChannelHolder
 */
object DlpScanEngine {

    private const val TAG = "DlpScanEngine"

    // ── قائمة التطبيقات عالية الخطورة ────────────────────────
    val HIGH_RISK_APPS: Set<String> = setOf(
        // متصفحات غير موثوقة
        "com.android.browser",
        "org.mozilla.firefox",
        "com.brave.browser",
        "com.duckduckgo.mobile.android",
        "com.opera.browser",
        "com.UCMobile.intl",

        // تطبيقات المراسلة
        "com.whatsapp",
        "org.telegram.messenger",
        "com.telegram.messenger",
        "com.discord",
        "com.skype.raider",
        "com.viber.voip",

        // تطبيقات البريد الإلكتروني غير الرسمية
        "com.google.android.gm",
        "com.microsoft.office.outlook",

        // تطبيقات مشاركة الملفات
        "com.shareit.activity",
        "com.xender",
    )

    // ── الكلمات المفتاحية المحظورة (عربي + إنجليزي) ─────────
    private val FORBIDDEN_KEYWORDS = listOf(
        // بيانات هوية
        "رقم الهوية", "رقم الجواز", "id number", "passport",
        "كلمة المرور", "password", "pin code", "رمز سري",

        // معلومات مالية
        "رقم البطاقة", "card number", "cvv", "حساب بنكي", "bank account",
        "iban", "swift code",

        // بيانات طبية
        "تشخيص", "diagnosis", "دواء", "medication", "سجل طبي",

        // اتصالات خارجية مشبوهة
        "إرسال وثيقة", "send document", "transfer file", "شارك ملف",

        // كلمات تسرب محتوى
        "سري", "confidential", "classified", "top secret", "سري للغاية",
    )

    // ── محرك ML Kit ──────────────────────────────────────────

    private val textRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    // ── الدالة الرئيسية — تُستدعى من MyAccessibilityService ──

    /**
     * يفحص محتوى الشاشة الحالية بحثاً عن بيانات حساسة.
     * @param rootNode جذر شجرة الـ AccessibilityNodeInfo
     * @param packageName اسم التطبيق الحالي
     * @param uid معرف المستخدم لإرسال التحذيرات
     * @param context السياق
     */
    fun scan(
        rootNode: AccessibilityNodeInfo?,
        packageName: String,
        uid: String,
        context: Context
    ) {
        if (rootNode == null || uid.isEmpty()) return

        // Layer 1: استخراج النصوص من شجرة الـ Accessibility
        val extractedText = extractTextFromNodeTree(rootNode)
        if (extractedText.isEmpty()) return

        Log.d(TAG, "نص مستخرج من $packageName: ${extractedText.take(200)}")

        // Layer 2: فحص الكلمات المفتاحية
        val foundKeywords = checkKeywords(extractedText)
        if (foundKeywords.isNotEmpty()) {
            Log.w(TAG, "⚠ DLP تحذير: كلمات محظورة في $packageName: $foundKeywords")
            reportDlpAlert(uid, packageName, foundKeywords, extractedText.take(500), context)
        }

        // Layer 3: ML Kit تحليل إضافي للنص (غير متزامن)
        analyzeWithMlKit(extractedText, packageName, uid, context)
    }

    // ── Layer 1: Accessibility Node Tree Traversal ────────────

    private fun extractTextFromNodeTree(node: AccessibilityNodeInfo): String {
        val builder = StringBuilder()
        traverseNode(node, builder, depth = 0)
        return builder.toString()
    }

    private fun traverseNode(node: AccessibilityNodeInfo, sb: StringBuilder, depth: Int) {
        if (depth > 15) return // منع التعمق الزائد

        // استخرج النص من هذه العقدة
        node.text?.toString()?.let { text ->
            if (text.isNotBlank() && text.length > 2) {
                sb.append(text).append(" ")
            }
        }
        node.contentDescription?.toString()?.let { desc ->
            if (desc.isNotBlank()) sb.append(desc).append(" ")
        }

        // تكرر على الأبناء
        for (i in 0 until node.childCount) {
            try {
                val child = node.getChild(i) ?: continue
                traverseNode(child, sb, depth + 1)
                child.recycle()
            } catch (e: Exception) { /* تجاهل */ }
        }
    }

    // ── Layer 2: Keyword Matching ─────────────────────────────

    private fun checkKeywords(text: String): List<String> {
        val lowerText = text.lowercase()
        return FORBIDDEN_KEYWORDS.filter { keyword ->
            lowerText.contains(keyword.lowercase())
        }
    }

    // ── Layer 3: ML Kit Text Analysis ────────────────────────

    private fun analyzeWithMlKit(
        text: String,
        packageName: String,
        uid: String,
        context: Context
    ) {
        // للنص الممسوح من AccessibilityNodeInfo — نُمرره مباشرة للمحلل
        // ML Kit يمكن استخدامه لتعرف الكيانات المسماة (Named Entity Recognition)
        // هنا نُطبق pattern matching متقدم على النص المستخرج

        val sensitivePatterns = listOf(
            Regex("\\b\\d{10}\\b"),          // رقم هوية
            Regex("\\b\\d{4}[- ]?\\d{4}[- ]?\\d{4}[- ]?\\d{4}\\b"), // رقم بطاقة
            Regex("\\b[A-Z]{2}\\d{2}[A-Z0-9]{4}\\d{7}([A-Z0-9]?){0,16}\\b"), // IBAN
            Regex("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"), // Email
            Regex("\\b\\d{3,4}\\b"),          // CVV محتمل
        )

        val matchedPatterns = mutableListOf<String>()
        for (pattern in sensitivePatterns) {
            if (pattern.containsMatchIn(text)) {
                matchedPatterns.add(pattern.pattern)
            }
        }

        if (matchedPatterns.isNotEmpty()) {
            Log.w(TAG, "⚠ ML Kit: أنماط حساسة في $packageName: $matchedPatterns")
            reportDlpAlert(uid, packageName, matchedPatterns, "pattern_match", context)
        }
    }

    // ── Firestore: رفع تحذير DLP ────────────────────────────

    private fun reportDlpAlert(
        uid: String,
        packageName: String,
        keywords: List<String>,
        snippet: String,
        context: Context
    ) {
        val alertData = mapOf(
            "type" to "dlp_alert",
            "packageName" to packageName,
            "foundKeywords" to keywords,
            "textSnippet" to snippet.take(300),
            "timestamp" to FieldValue.serverTimestamp(),
            "severity" to if (keywords.size > 2) "HIGH" else "MEDIUM"
        )

        // رفع التحذير لـ Firestore
        FirebaseFirestore.getInstance()
            .collection("compliance_assets")
            .document(uid)
            .collection("dlp_alerts")
            .add(alertData)
            .addOnSuccessListener {
                Log.i(TAG, "✓ DLP Alert رُفع لـ Firestore")
            }

        // تحديث حالة الجهاز
        FirebaseFirestore.getInstance()
            .collection("device_states")
            .document(uid)
            .update(mapOf(
                "lastDlpAlert" to FieldValue.serverTimestamp(),
                "dlpAlertCount" to com.google.firebase.firestore.FieldValue.increment(1)
            ))

        // إخطار Flutter
        notifyFlutter(context, packageName, keywords)
    }

    private fun notifyFlutter(
        context: Context,
        packageName: String,
        keywords: List<String>
    ) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            try {
                val messenger = FocusChannelHolder.messenger
                if (messenger != null) {
                    val channel = io.flutter.plugin.common.MethodChannel(
                        messenger, MyAccessibilityService.FOCUS_CHANNEL
                    )
                    channel.invokeMethod("dlp_alert", mapOf(
                        "packageName" to packageName,
                        "keywords" to keywords,
                        "timestamp" to System.currentTimeMillis()
                    ))
                }
            } catch (e: Exception) {
                Log.w(TAG, "فشل إخطار Flutter بـ DLP: ${e.message}")
            }
        }
    }
}
