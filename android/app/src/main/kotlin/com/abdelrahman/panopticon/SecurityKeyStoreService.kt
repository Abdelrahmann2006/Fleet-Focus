package com.abdelrahman.panopticon

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * SecurityKeyStoreService — مخزن المفاتيح الأمني للطبقة الحرجة
 *
 * يُخزّن مفتاح AES-256 لتشفير MQTT داخل Android Keystore System.
 * المفتاح محمي في Secure Enclave ولا يمكن استخراجه حتى مع root.
 *
 * MethodChannel: panopticon/keystore
 *   encrypt(plaintext: String)  → String (Base64 IV||Ciphertext)
 *   decrypt(encoded: String)    → String (plaintext)
 *   isKeyReady()                → Boolean
 *
 * البنية الأمنية:
 *   • AES-256-GCM  — مصادقة + تشفير في آنٍ واحد
 *   • IV عشوائي لكل عملية تشفير (مضمون في GCM mode)
 *   • setRandomizedEncryptionRequired(true)  — Android يُدير IV
 *   • المفتاح لا يُصدَّر أبداً من الـ Keystore
 */
class SecurityKeyStoreService(flutterEngine: FlutterEngine) {

    companion object {
        private const val TAG          = "KeyStoreService"
        const val CHANNEL_NAME         = "panopticon/keystore"
        private const val KEY_ALIAS    = "PanopticonMqttKey_v1"
        private const val KEYSTORE     = "AndroidKeyStore"
        private const val ALGORITHM    = KeyProperties.KEY_ALGORITHM_AES
        private const val BLOCK_MODE   = KeyProperties.BLOCK_MODE_GCM
        private const val PADDING      = KeyProperties.ENCRYPTION_PADDING_NONE
        private const val TRANSFORM    = "AES/GCM/NoPadding"
        private const val GCM_IV_LEN   = 12   // 96-bit IV standard for GCM
        private const val GCM_TAG_BITS = 128  // 128-bit authentication tag
    }

    init {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "encrypt" -> {
                    val plain = call.argument<String>("plaintext") ?: ""
                    val enc   = encrypt(plain)
                    if (enc != null) result.success(enc)
                    else result.error("ENCRYPT_FAILED", "فشل التشفير في Keystore", null)
                }
                "decrypt" -> {
                    val encoded = call.argument<String>("encoded") ?: ""
                    val dec     = decrypt(encoded)
                    if (dec != null) result.success(dec)
                    else result.error("DECRYPT_FAILED", "فشل فك التشفير في Keystore", null)
                }
                "isKeyReady" -> result.success(isKeyReady())
                "deleteKey"  -> {
                    deleteKey()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // تأكد من وجود المفتاح عند بدء التشغيل
        try {
            getOrCreateKey()
            Log.i(TAG, "✓ SecurityKeyStoreService جاهز — المفتاح في Secure Enclave")
        } catch (e: Exception) {
            Log.e(TAG, "فشل تهيئة KeyStore: ${e.message}")
        }
    }

    // ── إنشاء أو استرداد مفتاح AES-256 من Keystore ─────────────────────────

    private fun getOrCreateKey(): SecretKey {
        val ks = KeyStore.getInstance(KEYSTORE).apply { load(null) }

        if (ks.containsAlias(KEY_ALIAS)) {
            return (ks.getEntry(KEY_ALIAS, null) as KeyStore.SecretKeyEntry).secretKey
        }

        Log.i(TAG, "إنشاء مفتاح AES-256 جديد في Android Keystore…")
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(BLOCK_MODE)
            .setEncryptionPaddings(PADDING)
            .setKeySize(256)
            .setUserAuthenticationRequired(false)
            .setRandomizedEncryptionRequired(true)
            .build()

        return KeyGenerator.getInstance(ALGORITHM, KEYSTORE).run {
            init(spec)
            generateKey()
        }.also { Log.i(TAG, "✓ مفتاح AES-256-GCM أُنشئ وحُفظ بأمان") }
    }

    // ── تشفير — يُعيد Base64(IV || CipherText) ──────────────────────────────

    fun encrypt(plaintext: String): String? = runCatching {
        val key    = getOrCreateKey()
        val cipher = Cipher.getInstance(TRANSFORM)
        cipher.init(Cipher.ENCRYPT_MODE, key)

        val iv         = cipher.iv                                     // 12 bytes
        val ciphertext = cipher.doFinal(plaintext.toByteArray(Charsets.UTF_8))
        val combined   = iv + ciphertext                               // IV || CT
        Base64.encodeToString(combined, Base64.NO_WRAP)
    }.onFailure { Log.e(TAG, "خطأ في التشفير: ${it.message}") }.getOrNull()

    // ── فك التشفير — يُفكّك Base64(IV || CipherText) ────────────────────────

    fun decrypt(encoded: String): String? = runCatching {
        val combined   = Base64.decode(encoded, Base64.NO_WRAP)
        require(combined.size > GCM_IV_LEN) { "بيانات مشفرة قصيرة جداً" }

        val iv         = combined.copyOfRange(0, GCM_IV_LEN)
        val ciphertext = combined.copyOfRange(GCM_IV_LEN, combined.size)

        val key    = getOrCreateKey()
        val cipher = Cipher.getInstance(TRANSFORM)
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(GCM_TAG_BITS, iv))

        String(cipher.doFinal(ciphertext), Charsets.UTF_8)
    }.onFailure { Log.e(TAG, "خطأ في فك التشفير: ${it.message}") }.getOrNull()

    // ── فحص جاهزية المفتاح ──────────────────────────────────────────────────

    fun isKeyReady(): Boolean = runCatching {
        KeyStore.getInstance(KEYSTORE).apply { load(null) }.containsAlias(KEY_ALIAS)
    }.getOrDefault(false)

    // ── حذف المفتاح (للاختبار / إعادة التهيئة) ──────────────────────────────

    private fun deleteKey() {
        runCatching {
            KeyStore.getInstance(KEYSTORE).apply { load(null) }.deleteEntry(KEY_ALIAS)
            Log.w(TAG, "⚠ مفتاح MQTT حُذف من Keystore")
        }
    }
}
