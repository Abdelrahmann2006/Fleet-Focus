import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';

/// E2eVaultService — التشفير الكامل من طرف إلى طرف لبيانات الحسابات الرقمية
///
/// البنية الأمنية:
///  - السيدة تمتلك مفتاح AES-256 (Vault Key) مُخزَّن في Firestore تحت `vault_keys/{leaderUid}`
///  - جهاز العنصر يجلب المفتاح العام لتشفير كلمات المرور قبل الرفع
///  - فقط السيدة (بمعرفة leaderUid) يمكنها جلب المفتاح وفك التشفير
///
/// ملاحظة: هذا تشفير AES متماثل لا RSA غير متماثل — للحصول على E2E حقيقي
/// يُوصى بترقية المفتاح إلى RSA-2048 مع Android Keystore.
class E2eVaultService {
  E2eVaultService._();
  static final instance = E2eVaultService._();

  static const _collection = 'vault_keys';

  // ── توليد مفتاح Vault جديد (للسيدة عند الإعداد الأول) ──────

  Future<void> generateAndStoreVaultKey(String leaderUid) async {
    final key = enc.Key.fromSecureRandom(32);
    await FirebaseFirestore.instance.collection(_collection).doc(leaderUid).set({
      'keyBase64': key.base64,
      'createdAt': FieldValue.serverTimestamp(),
      'algorithm': 'AES-256-CBC',
    }, SetOptions(merge: true));
    debugPrint('[E2eVault] ✓ مفتاح Vault جُنِّد للسيدة: $leaderUid');
  }

  // ── تشفير كلمة مرور (على جهاز العنصر) ──────────────────────

  /// يُشفَّر plaintext بمفتاح السيدة المخزَّن في Firestore
  /// المُخرج: سلسلة "iv_base64:cipher_base64"
  Future<String> encryptPassword({
    required String leaderUid,
    required String plaintext,
  }) async {
    final keyBase64 = await _fetchVaultKey(leaderUid);
    if (keyBase64 == null) {
      debugPrint('[E2eVault] ⚠ لا يوجد مفتاح Vault — التخزين بدون تشفير');
      return '⚠️UNENCRYPTED:$plaintext';
    }
    try {
      final key = enc.Key.fromBase64(keyBase64);
      final iv  = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(plaintext, iv: iv);
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      debugPrint('[E2eVault] خطأ في التشفير: $e');
      return '⚠️ERROR';
    }
  }

  // ── فك تشفير كلمة مرور (على جهاز السيدة) ─────────────────

  Future<String> decryptPassword({
    required String leaderUid,
    required String ciphertext,
  }) async {
    if (ciphertext.startsWith('⚠️')) return ciphertext;
    final keyBase64 = await _fetchVaultKey(leaderUid);
    if (keyBase64 == null) return '⚠️ لا يوجد مفتاح';
    try {
      final parts = ciphertext.split(':');
      if (parts.length != 2) return '⚠️ صيغة غير صالحة';
      final key  = enc.Key.fromBase64(keyBase64);
      final iv   = enc.IV.fromBase64(parts[0]);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      return encrypter.decrypt(enc.Encrypted.fromBase64(parts[1]), iv: iv);
    } catch (e) {
      debugPrint('[E2eVault] خطأ في فك التشفير: $e');
      return '⚠️ فشل فك التشفير';
    }
  }

  // ── جلب المفتاح من Firestore ─────────────────────────────────

  Future<String?> _fetchVaultKey(String leaderUid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(leaderUid)
          .get();
      return doc.data()?['keyBase64'] as String?;
    } catch (e) {
      debugPrint('[E2eVault] فشل جلب المفتاح: $e');
      return null;
    }
  }

  /// هل يوجد مفتاح Vault للسيدة؟
  Future<bool> hasVaultKey(String leaderUid) async {
    return await _fetchVaultKey(leaderUid) != null;
  }
}
