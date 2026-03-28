import 'package:flutter/services.dart';

/// SecurityKeyStoreService — واجهة Flutter لمخزن المفاتيح الأمني
///
/// يتواصل مع Android Keystore عبر MethodChannel.
/// المفتاح AES-256-GCM محمي في Secure Enclave — لا يمكن استخراجه.
///
/// الاستخدام:
///   final enc = await SecurityKeyStoreService.encrypt('سر_حساس');
///   final dec = await SecurityKeyStoreService.decrypt(enc!);
class SecurityKeyStoreService {
  SecurityKeyStoreService._();
  static final instance = SecurityKeyStoreService._();

  static const _channel = MethodChannel('panopticon/keystore');

  /// تشفير نص — يُعيد Base64(IV||CipherText) أو null عند الفشل
  Future<String?> encrypt(String plaintext) async {
    try {
      final result = await _channel.invokeMethod<String>(
          'encrypt', {'plaintext': plaintext});
      return result;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[KeyStore] فشل التشفير: ${e.message}');
      return null;
    }
  }

  /// فك تشفير — يُعيد النص الأصلي أو null عند الفشل
  Future<String?> decrypt(String encoded) async {
    try {
      final result = await _channel.invokeMethod<String>(
          'decrypt', {'encoded': encoded});
      return result;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[KeyStore] فشل فك التشفير: ${e.message}');
      return null;
    }
  }

  /// فحص جاهزية المفتاح في Keystore
  Future<bool> isKeyReady() async {
    try {
      return await _channel.invokeMethod<bool>('isKeyReady') ?? false;
    } on PlatformException {
      return false;
    }
  }
}
