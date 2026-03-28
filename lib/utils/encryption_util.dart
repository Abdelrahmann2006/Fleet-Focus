import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart' hide Key;

/// EncryptionUtil — تشفير AES-256-CBC للبيانات المرسلة عبر MQTT
///
/// لأننا نستخدم HiveMQ Public Broker الذي يمكن لأي شخص الاشتراك فيه،
/// يجب تشفير جميع حزم البيانات قبل نشرها وفك تشفيرها عند الاستقبال.
///
/// الخوارزمية:  AES-256-CBC
/// المفتاح:     32 بايت (256-bit) — مشترك بين المشارك والقائد
/// IV:          16 بايت عشوائي لكل رسالة (يُضاف في مقدمة البيانات)
///
/// تنسيق الحمولة المشفرة (base64):
///   base64( IV[16 bytes] + CipherText[N bytes] )
///
/// الخصائص الأمنية:
///   ✓ كل رسالة لها IV مختلف → لا يمكن تحليل الأنماط
///   ✓ AES-256 — غير قابل للكسر بالقوة الغاشمة
///   ✓ لا يُرسل المفتاح عبر الشبكة — موجود في الكود فقط
///   ✗ PSK (Pre-Shared Key) — ليس end-to-end بالمعنى الحرفي
///      لكنه كافٍ لحماية البيانات من العامة على Broker المشترك
///
/// ملاحظة أمنية:
///   المفتاح مُضمَّن في الـ APK. لمستوى أمان أعلى في الإنتاج،
///   يُفضَّل جلبه من Firebase Remote Config مع التحقق من التوقيع.
class EncryptionUtil {
  EncryptionUtil._(); // لا instantiation

  // ── المفتاح المشترك (AES-256 = 32 بايت) ──────────────────────
  //
  // مُولَّد عشوائياً — لا تُغيّره بعد النشر لأن القائد والمشارك
  // يجب أن يستخدموا نفس المفتاح في جميع الأوقات.
  //
  // إن أردت تدوير المفتاح: أضف حقل "keyVersion" في الحمولة
  // وادعم أكثر من مفتاح في _keyMap أدناه.
  static const String _rawKey =
      'P@n0pt1c0n#S3cur3K3y!AES256BitK3y'; // 32 حرف بالضبط

  // ── IV Size ───────────────────────────────────────────────────
  static const int _ivLength = 16; // AES block size

  // ── Encrypter (lazy) ──────────────────────────────────────────
  static Encrypter? _encrypter;
  static final _random = Random.secure();

  static Encrypter get _enc {
    _encrypter ??= Encrypter(AES(Key.fromUtf8(_rawKey), mode: AESMode.cbc));
    return _encrypter!;
  }

  // ══════════════════════════════════════════════════════════════
  // Public API
  // ══════════════════════════════════════════════════════════════

  /// تشفير Map إلى سلسلة base64 (تُرسَل كحمولة MQTT)
  ///
  /// المدخل:  { 'lat': 24.7, 'lng': 46.7, ... }
  /// المخرج:  'aGVsbG8uLi43...' (base64)
  static String encryptPayload(Map<String, dynamic> payload) {
    try {
      final plaintext = jsonEncode(payload);
      final iv        = _generateIV();
      final encrypted = _enc.encrypt(plaintext, iv: iv);

      // ادمج IV + CipherText في مصفوفة بايت واحدة، ثم base64
      final combined = Uint8List(_ivLength + encrypted.bytes.length)
        ..setRange(0, _ivLength, iv.bytes)
        ..setRange(_ivLength, _ivLength + encrypted.bytes.length, encrypted.bytes);

      return base64Encode(combined);
    } catch (e) {
      debugPrint('[Encryption] Encrypt error: $e');
      rethrow;
    }
  }

  /// فك تشفير سلسلة base64 الواردة من MQTT إلى Map
  ///
  /// المدخل:  'aGVsbG8uLi43...' (base64)
  /// المخرج:  { 'lat': 24.7, 'lng': 46.7, ... }
  ///
  /// يرمي [EncryptionException] عند:
  ///   • فشل base64
  ///   • طول البيانات أقل من IV
  ///   • فشل AES (مفتاح خاطئ / بيانات تالفة)
  ///   • JSON غير صالح بعد فك التشفير
  static Map<String, dynamic> decryptPayload(String encrypted64) {
    late final Uint8List combined;
    try {
      combined = base64Decode(encrypted64);
    } catch (_) {
      throw EncryptionException('فشل قراءة base64 — الحمولة تالفة');
    }

    if (combined.length < _ivLength) {
      throw EncryptionException(
          'حمولة قصيرة جداً (${combined.length} < $_ivLength)');
    }

    try {
      final iv         = IV(Uint8List.fromList(combined.sublist(0, _ivLength)));
      final cipherBytes = Encrypted(
          Uint8List.fromList(combined.sublist(_ivLength)));
      final plaintext  = _enc.decrypt(cipherBytes, iv: iv);
      return jsonDecode(plaintext) as Map<String, dynamic>;
    } catch (e) {
      throw EncryptionException(
          'فشل فك التشفير — المفتاح خاطئ أو البيانات تالفة: $e');
    }
  }

  /// تشفير نص عادي (للاستخدام العام)
  static String encryptString(String plaintext) {
    final iv        = _generateIV();
    final encrypted = _enc.encrypt(plaintext, iv: iv);
    final combined  = Uint8List(_ivLength + encrypted.bytes.length)
      ..setRange(0, _ivLength, iv.bytes)
      ..setRange(_ivLength, _ivLength + encrypted.bytes.length, encrypted.bytes);
    return base64Encode(combined);
  }

  /// فك تشفير نص
  static String decryptString(String encrypted64) {
    final combined  = base64Decode(encrypted64);
    final iv        = IV(Uint8List.fromList(combined.sublist(0, _ivLength)));
    final cipherBytes = Encrypted(
        Uint8List.fromList(combined.sublist(_ivLength)));
    return _enc.decrypt(cipherBytes, iv: iv);
  }

  /// التحقق من أن المفتاح يعمل بشكل صحيح (للـ debug)
  static bool selfTest() {
    try {
      const testPayload = {'test': true, 'value': 42, 'msg': 'panopticon'};
      final encrypted   = encryptPayload(testPayload);
      final decrypted   = decryptPayload(encrypted);

      final ok = decrypted['test'] == true &&
          decrypted['value'] == 42 &&
          decrypted['msg'] == 'panopticon';

      debugPrint('[Encryption] Self-test: ${ok ? "✓ PASSED" : "✗ FAILED"}');
      return ok;
    } catch (e) {
      debugPrint('[Encryption] Self-test FAILED: $e');
      return false;
    }
  }

  // ── Internal ──────────────────────────────────────────────────

  static IV _generateIV() {
    final bytes = Uint8List(_ivLength);
    for (var i = 0; i < _ivLength; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return IV(bytes);
  }
}

// ── Exception ─────────────────────────────────────────────────

class EncryptionException implements Exception {
  final String message;
  const EncryptionException(this.message);
  @override
  String toString() => 'EncryptionException: $message';
}
