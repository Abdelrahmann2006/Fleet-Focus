import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/inventory_item_model.dart';
import '../services/firestore_service.dart';

/// InventoryRepository — إدارة المخزون والأصول القانونية عبر Firestore
///
/// المخزون:
///  • تسجيل حضور (check-in)
///  • معدات وأجهزة
///  • حصص (food/supplies)
///  • وثائق رسمية
///
/// الأصول القانونية:
///  • توقيع الدستور
///  • اتفاقية عدم الإفصاح
///  • موافقة على المراقبة
class InventoryRepository {
  static final InventoryRepository _instance = InventoryRepository._();
  factory InventoryRepository() => _instance;
  InventoryRepository._();

  final _fs = FirestoreService();

  // ─────────────────────────────────────────────────────────────
  // INVENTORY ITEMS
  // ─────────────────────────────────────────────────────────────

  /// إضافة تسجيل حضور
  Future<String> recordCheckIn(String uid, {
    String? location,
    String? authorizedBy,
  }) async {
    final item = InventoryItem(
      id: '',
      uid: uid,
      type: InventoryType.checkIn,
      description: 'تسجيل حضور${location != null ? ' — $location' : ''}',
      quantity: 1,
      unit: 'تسجيل',
      timestamp: DateTime.now(),
      authorizedBy: authorizedBy,
    );
    final id = await _fs.addInventoryItem(uid, item);
    debugPrint('[InventoryRepo] Check-in recorded: $id');
    return id;
  }

  /// إضافة معدات
  Future<String> addEquipment(String uid, {
    required String description,
    required int quantity,
    String unit = 'وحدة',
    DateTime? expiryDate,
    String? authorizedBy,
  }) async {
    final item = InventoryItem(
      id: '',
      uid: uid,
      type: InventoryType.equipment,
      description: description,
      quantity: quantity,
      unit: unit,
      timestamp: DateTime.now(),
      expiryDate: expiryDate,
      authorizedBy: authorizedBy,
    );
    return await _fs.addInventoryItem(uid, item);
  }

  /// إضافة حصة
  Future<String> addRation(String uid, {
    required String description,
    required int quantity,
    String unit = 'وحدة',
    DateTime? expiryDate,
  }) async {
    final item = InventoryItem(
      id: '',
      uid: uid,
      type: InventoryType.ration,
      description: description,
      quantity: quantity,
      unit: unit,
      timestamp: DateTime.now(),
      expiryDate: expiryDate,
    );
    return await _fs.addInventoryItem(uid, item);
  }

  /// Stream للمخزون الكامل
  Stream<List<InventoryItem>> watchInventory(String uid) =>
      _fs.watchInventory(uid);

  /// Stream حسب النوع
  Stream<List<InventoryItem>> watchByType(String uid, InventoryType type) =>
      _fs.watchInventory(uid, type: type);

  /// جلب المخزون مرة واحدة
  Future<List<InventoryItem>> getInventory(String uid) =>
      _fs.getInventory(uid);

  /// حساب العناصر المنتهية أو القريبة من الانتهاء (< 7 أيام)
  Future<List<InventoryItem>> getExpiringItems(String uid) async {
    final items = await _fs.getInventory(uid);
    final threshold = DateTime.now().add(const Duration(days: 7));
    return items.where((i) =>
        i.expiryDate != null && i.expiryDate!.isBefore(threshold)).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // LEGAL ASSETS
  // ─────────────────────────────────────────────────────────────

  /// تسجيل توقيع المشارك على الدستور
  Future<String> recordConstitutionSignature(String uid, {
    required String checksum,
    String documentVersion = '1.0',
    String? storageRef,
    String? deviceModel,
  }) async {
    final asset = LegalAsset(
      id: '',
      uid: uid,
      type: LegalAssetType.constitution,
      documentVersion: documentVersion,
      signedAt: DateTime.now(),
      checksum: checksum,
      storageRef: storageRef,
      deviceModel: deviceModel,
    );
    final id = await _fs.saveLegalAsset(uid, asset);
    debugPrint('[InventoryRepo] Constitution signature recorded: $id');
    return id;
  }

  /// تسجيل موافقة على المراقبة
  Future<String> recordConsentSignature(String uid, {
    required String checksum,
    String? deviceModel,
    String? storageRef,
  }) async {
    final asset = LegalAsset(
      id: '',
      uid: uid,
      type: LegalAssetType.consent,
      documentVersion: '1.0',
      signedAt: DateTime.now(),
      checksum: checksum,
      storageRef: storageRef,
      deviceModel: deviceModel,
    );
    return await _fs.saveLegalAsset(uid, asset);
  }

  /// التحقق من توقيع الدستور
  Future<bool> hasSignedConstitution(String uid) async {
    final asset = await _fs.getLatestSignature(uid, LegalAssetType.constitution);
    return asset != null;
  }

  /// جلب آخر توقيع
  Future<LegalAsset?> getLatestSignature(String uid, LegalAssetType type) =>
      _fs.getLatestSignature(uid, type);

  /// Stream لجميع الأصول القانونية (للقائد)
  Stream<List<LegalAsset>> watchLegalAssets(String uid) =>
      _fs.watchLegalAssets(uid);

  // ─────────────────────────────────────────────────────────────
  // CREDENTIAL STORAGE
  // ─────────────────────────────────────────────────────────────

  /// تسجيل وثيقة رسمية
  Future<String> addCredential(String uid, {
    required String description,
    String? externalRef,
    String? authorizedBy,
  }) async {
    final item = InventoryItem(
      id: '',
      uid: uid,
      type: InventoryType.credential,
      description: description,
      quantity: 1,
      unit: 'وثيقة',
      timestamp: DateTime.now(),
      authorizedBy: authorizedBy,
      metadata: externalRef != null ? {'ref': externalRef} : null,
    );
    return await _fs.addInventoryItem(uid, item);
  }
}
