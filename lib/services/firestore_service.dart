import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/inventory_item_model.dart';

/// FirestoreService — Firestore للبيانات الثابتة / منخفضة التردد
///
/// المجموعات:
///  • users/{uid}                          — الملف الشخصي الكامل
///  • inventory_logs/{uid}/items/{id}      — سجلات المخزون
///  • legal_assets/{uid}/signatures/{id}   — الأصول القانونية (التواقيع/الدستور)
///  • device_states/{uid}                  — snapshot دوري (ليس real-time)
///  • device_commands/{uid}                — أوامر Firestore (موجودة مسبقاً)
///
/// سياسة الكاش:
///  يُفعَّل persistentCacheSettings لتقليل القراءات المدفوعة
class FirestoreService {
  // ── Singleton ─────────────────────────────────────────────────
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  FirebaseFirestore get _fs {
    final fs = FirebaseFirestore.instance;
    fs.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    return fs;
  }

  // ─────────────────────────────────────────────────────────────
  // PROFILES — users/{uid}
  // ─────────────────────────────────────────────────────────────

  /// قراءة الملف الشخصي (مع كاش)
  Future<Map<String, dynamic>?> getProfile(String uid) async {
    try {
      final snap = await _fs.collection('users').doc(uid).get(
        const GetOptions(source: Source.serverAndCache),
      );
      return snap.data();
    } catch (e) {
      debugPrint('[FS] getProfile error: $e');
      return null;
    }
  }

  /// حفظ / تحديث جزئي للملف الشخصي
  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    await _fs.collection('users').doc(uid).set(
      {'updatedAt': FieldValue.serverTimestamp(), ...data},
      SetOptions(merge: true),
    );
  }

  /// Stream للملف الشخصي (للقائد لمراقبة تغييرات المشارك)
  Stream<Map<String, dynamic>?> watchProfile(String uid) {
    return _fs.collection('users').doc(uid).snapshots().map((s) => s.data());
  }

  /// قراءة جميع المشاركين (role == 'participant') — مع كاش
  Future<List<Map<String, dynamic>>> getAllParticipants() async {
    try {
      final snap = await _fs
          .collection('users')
          .where('role', isEqualTo: 'participant')
          .where('applicationStatus', isEqualTo: 'approved')
          .get(const GetOptions(source: Source.serverAndCache));
      return snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
    } catch (e) {
      debugPrint('[FS] getAllParticipants error: $e');
      return [];
    }
  }

  /// Stream لطلبات الانضمام المعلقة
  Stream<List<Map<String, dynamic>>> watchPendingRequests() {
    return _fs
        .collection('users')
        .where('role', isEqualTo: 'participant')
        .where('applicationStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList());
  }

  /// تحديث حالة الطلب (قبول / رفض)
  Future<void> setApplicationStatus(String uid, String status) async {
    await _fs.collection('users').doc(uid).update({
      'applicationStatus': status,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  /// حفظ كود المشارك المولَّد
  Future<void> saveParticipantCode(String uid, String name, String code) async {
    await _fs.collection('participant_codes').doc(code).set({
      'uid': uid,
      'name': name,
      'code': code,
      'used': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// التحقق من كود المشارك عند التسجيل
  Future<Map<String, dynamic>?> validateCode(String code) async {
    try {
      final snap = await _fs.collection('participant_codes').doc(code).get();
      if (!snap.exists) return null;
      final data = snap.data()!;
      if (data['used'] == true) return null;
      return data;
    } catch (e) {
      debugPrint('[FS] validateCode error: $e');
      return null;
    }
  }

  /// تعليم الكود كمستخدم
  Future<void> markCodeUsed(String code) async {
    await _fs.collection('participant_codes').doc(code).update({'used': true});
  }

  // ─────────────────────────────────────────────────────────────
  // INVENTORY LOGS — inventory_logs/{uid}/items/{id}
  // ─────────────────────────────────────────────────────────────

  /// إضافة عنصر مخزون
  Future<String> addInventoryItem(String uid, InventoryItem item) async {
    final ref = await _fs
        .collection(InventoryItem.collectionPath(uid))
        .add(item.toFirestore());
    return ref.id;
  }

  /// Stream لعناصر مخزون المشارك
  Stream<List<InventoryItem>> watchInventory(String uid, {InventoryType? type}) {
    Query<Map<String, dynamic>> q =
        _fs.collection(InventoryItem.collectionPath(uid)).orderBy('timestamp', descending: true);
    if (type != null) {
      q = q.where('type', isEqualTo: type.name);
    }
    return q.snapshots().map((snap) =>
        snap.docs.map((d) => InventoryItem.fromFirestore(d.id, d.data())).toList());
  }

  /// جلب عناصر المخزون مرة واحدة (مع كاش)
  Future<List<InventoryItem>> getInventory(String uid) async {
    try {
      final snap = await _fs
          .collection(InventoryItem.collectionPath(uid))
          .orderBy('timestamp', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));
      return snap.docs
          .map((d) => InventoryItem.fromFirestore(d.id, d.data()))
          .toList();
    } catch (e) {
      debugPrint('[FS] getInventory error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LEGAL ASSETS — legal_assets/{uid}/signatures/{id}
  // ─────────────────────────────────────────────────────────────

  /// حفظ أصل قانوني (توقيع / دستور)
  Future<String> saveLegalAsset(String uid, LegalAsset asset) async {
    final ref = await _fs
        .collection(LegalAsset.collectionPath(uid))
        .add(asset.toFirestore());
    return ref.id;
  }

  /// جلب آخر توقيع للمشارك
  Future<LegalAsset?> getLatestSignature(String uid, LegalAssetType type) async {
    try {
      final snap = await _fs
          .collection(LegalAsset.collectionPath(uid))
          .where('type', isEqualTo: type.name)
          .orderBy('signedAt', descending: true)
          .limit(1)
          .get(const GetOptions(source: Source.serverAndCache));
      if (snap.docs.isEmpty) return null;
      return LegalAsset.fromFirestore(snap.docs.first.id, snap.docs.first.data());
    } catch (e) {
      debugPrint('[FS] getLatestSignature error: $e');
      return null;
    }
  }

  /// Stream للأصول القانونية للقائد
  Stream<List<LegalAsset>> watchLegalAssets(String uid) {
    return _fs
        .collection(LegalAsset.collectionPath(uid))
        .orderBy('signedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LegalAsset.fromFirestore(d.id, d.data()))
            .toList());
  }

  // ─────────────────────────────────────────────────────────────
  // DEVICE STATE SNAPSHOT (Firestore — low freq backup)
  // ─────────────────────────────────────────────────────────────

  /// حفظ snapshot دوري لـ device_states (مكمّل للـ RTDB)
  Future<void> snapshotDeviceState(
      String uid, Map<String, dynamic> state) async {
    await _fs.collection('device_states').doc(uid).set(
      {'...state': state, 'snapshotAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DEVICE COMMANDS (موجودة مسبقاً — نُوثّق الواجهة فقط)
  // ─────────────────────────────────────────────────────────────

  /// إرسال أمر للمشارك
  Future<void> sendCommand(String uid, {
    required String command,
    Map<String, dynamic>? payload,
  }) async {
    await _fs.collection('device_commands').doc(uid).set({
      'command': command,
      'payload': payload ?? {},
      'issuedAt': FieldValue.serverTimestamp(),
      'acknowledged': false,
    });
  }

  /// Stream لأوامر المشارك الواردة
  Stream<Map<String, dynamic>?> watchCommands(String uid) {
    return _fs
        .collection('device_commands')
        .doc(uid)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return null;
          final data = snap.data()!;
          if (data['acknowledged'] == true) return null;
          return data;
        })
        .where((cmd) => cmd != null);
  }
}
