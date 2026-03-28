/// عنصر في سجل المخزون — يُخزَّن في Firestore
/// inventory_logs/{uid}/items/{id}
class InventoryItem {
  final String id;
  final String uid;
  final InventoryType type;
  final String description;
  final int quantity;
  final String unit;
  final DateTime timestamp;
  final DateTime? expiryDate;
  final String? authorizedBy; // uid القائد الذي أذن
  final Map<String, dynamic>? metadata;

  const InventoryItem({
    required this.id,
    required this.uid,
    required this.type,
    required this.description,
    required this.quantity,
    required this.unit,
    required this.timestamp,
    this.expiryDate,
    this.authorizedBy,
    this.metadata,
  });

  // ── Firestore Path ────────────────────────────────────────────
  static String collectionPath(String uid) =>
      'inventory_logs/$uid/items';

  // ── Serialization ─────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
    'uid': uid,
    'type': type.name,
    'description': description,
    'quantity': quantity,
    'unit': unit,
    'timestamp': timestamp.millisecondsSinceEpoch,
    if (expiryDate != null) 'expiryDate': expiryDate!.millisecondsSinceEpoch,
    if (authorizedBy != null) 'authorizedBy': authorizedBy,
    if (metadata != null) 'metadata': metadata,
  };

  factory InventoryItem.fromFirestore(String id, Map<String, dynamic> data) {
    return InventoryItem(
      id: id,
      uid: data['uid'] as String? ?? '',
      type: InventoryType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => InventoryType.general,
      ),
      description: data['description'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      unit: data['unit'] as String? ?? 'وحدة',
      timestamp: data['timestamp'] is int
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
          : DateTime.now(),
      expiryDate: data['expiryDate'] is int
          ? DateTime.fromMillisecondsSinceEpoch(data['expiryDate'] as int)
          : null,
      authorizedBy: data['authorizedBy'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }
}

enum InventoryType {
  checkIn,    // تسجيل حضور
  equipment,  // معدات
  ration,     // حصص
  credential, // وثائق
  general,    // عام
}

extension InventoryTypeLabel on InventoryType {
  String get label {
    switch (this) {
      case InventoryType.checkIn:    return 'حضور';
      case InventoryType.equipment:  return 'معدات';
      case InventoryType.ration:     return 'حصص';
      case InventoryType.credential: return 'وثائق';
      case InventoryType.general:    return 'عام';
    }
  }
}

/// أصل قانوني — يُخزَّن في Firestore
/// legal_assets/{uid}/signatures/{id}
class LegalAsset {
  final String id;
  final String uid;
  final LegalAssetType type;
  final String documentVersion;
  final DateTime signedAt;
  final String checksum;          // SHA-256 of signed content
  final String? storageRef;       // Firebase Storage path for signature image
  final String? ipAddress;        // optional: device IP at signing time
  final String? deviceModel;

  const LegalAsset({
    required this.id,
    required this.uid,
    required this.type,
    required this.documentVersion,
    required this.signedAt,
    required this.checksum,
    this.storageRef,
    this.ipAddress,
    this.deviceModel,
  });

  // ── Firestore Path ────────────────────────────────────────────
  static String collectionPath(String uid) =>
      'legal_assets/$uid/signatures';

  // ── Serialization ─────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
    'uid': uid,
    'type': type.name,
    'documentVersion': documentVersion,
    'signedAt': signedAt.millisecondsSinceEpoch,
    'checksum': checksum,
    if (storageRef != null) 'storageRef': storageRef,
    if (ipAddress != null) 'ipAddress': ipAddress,
    if (deviceModel != null) 'deviceModel': deviceModel,
  };

  factory LegalAsset.fromFirestore(String id, Map<String, dynamic> data) {
    return LegalAsset(
      id: id,
      uid: data['uid'] as String? ?? '',
      type: LegalAssetType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => LegalAssetType.constitution,
      ),
      documentVersion: data['documentVersion'] as String? ?? '1.0',
      signedAt: data['signedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(data['signedAt'] as int)
          : DateTime.now(),
      checksum: data['checksum'] as String? ?? '',
      storageRef: data['storageRef'] as String?,
      ipAddress: data['ipAddress'] as String?,
      deviceModel: data['deviceModel'] as String?,
    );
  }
}

enum LegalAssetType {
  constitution,   // الدستور
  nda,            // اتفاقية عدم إفصاح
  consent,        // موافقة على المراقبة
  disciplinary,   // قرار تأديبي
}
