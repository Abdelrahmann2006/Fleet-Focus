import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// GeofenceService — خدمة النطاق الجغرافي (Flutter Side)
///
/// تدير إعدادات النطاق الجغرافي من لوحة المشرف.
/// الرصد الفعلي يتم على الجانب الأصلي (GeofenceMonitorService.kt).
///
/// مسؤولياتها:
/// - قراءة إعدادات النطاق من Firestore
/// - تحديث إعدادات النطاق (مركز + نصف قطر + تفعيل/تعطيل)
/// - قراءة حالة الجهاز الحالية (داخل/خارج النطاق)
/// - قراءة سجل الخروقات (breach_log)
/// - منح/سحب تصاريح التنقل (travel pass)
class GeofenceService {
  GeofenceService._();
  static final GeofenceService instance = GeofenceService._();

  final _db = FirebaseFirestore.instance;

  // ── إعدادات النطاق ────────────────────────────────────────────

  Stream<DocumentSnapshot<Map<String, dynamic>>> configStream(String uid) =>
      _db.collection('geofence_config').doc(uid).snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> statusStream(String uid) =>
      _db.collection('geofence_status').doc(uid).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> breachLogStream(String uid) =>
      _db
          .collection('compliance_assets')
          .doc(uid)
          .collection('breach_log')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots();

  /// تُعيّن النطاق الجغرافي الجديد
  Future<void> setGeofence({
    required String uid,
    required double centerLat,
    required double centerLon,
    required double radiusMeters,
    bool enabled = true,
  }) async {
    await _db.collection('geofence_config').doc(uid).set({
      'centerLat': centerLat,
      'centerLon': centerLon,
      'radiusMeters': radiusMeters,
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // إرسال أمر للجهاز لتحديث إعداداته
    await _db.collection('device_commands').doc(uid).set({
      'command': 'set_geofence',
      'payload': {
        'centerLat': centerLat,
        'centerLon': centerLon,
        'radiusMeters': radiusMeters,
        'enabled': enabled,
      },
      'acknowledged': false,
      'issuedAt': FieldValue.serverTimestamp(),
    });
  }

  /// تُعطّل النطاق الجغرافي
  Future<void> disableGeofence(String uid) async {
    await _db.collection('geofence_config').doc(uid).update({'enabled': false});
    await _db.collection('device_commands').doc(uid).set({
      'command': 'disable_geofence',
      'payload': {},
      'acknowledged': false,
      'issuedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── تصاريح التنقل (Travel Pass) ──────────────────────────────

  /// تمنح تصريح التنقل لمدة [durationHours] ساعة
  Future<void> grantTravelPass(
    String uid, {
    int durationHours = 2,
    String reason = 'مجاز',
  }) async {
    final expiry = DateTime.now().add(Duration(hours: durationHours));
    await _db.collection('geofence_config').doc(uid).update({
      'travelPassActive': true,
      'travelPassExpiry': Timestamp.fromDate(expiry),
      'travelPassReason': reason,
      'travelPassGrantedAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('device_commands').doc(uid).set({
      'command': 'grant_travel_pass',
      'payload': {'durationHours': durationHours, 'reason': reason},
      'acknowledged': false,
      'issuedAt': FieldValue.serverTimestamp(),
    });
  }

  /// تسحب تصريح التنقل فوراً
  Future<void> revokeTravelPass(String uid) async {
    await _db.collection('geofence_config').doc(uid).update({
      'travelPassActive': false,
      'travelPassExpiry': 0,
      'travelPassRevokedAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('device_commands').doc(uid).set({
      'command': 'revoke_travel_pass',
      'payload': {},
      'acknowledged': false,
      'issuedAt': FieldValue.serverTimestamp(),
    });
  }
}

/// بيانات إعدادات النطاق
class GeofenceConfig {
  final double centerLat;
  final double centerLon;
  final double radiusMeters;
  final bool enabled;
  final bool travelPassActive;
  final DateTime? travelPassExpiry;
  final String travelPassReason;

  GeofenceConfig({
    required this.centerLat,
    required this.centerLon,
    required this.radiusMeters,
    required this.enabled,
    this.travelPassActive = false,
    this.travelPassExpiry,
    this.travelPassReason = 'غير محدد',
  });

  factory GeofenceConfig.fromMap(Map<String, dynamic> data) {
    final expTs = data['travelPassExpiry'];
    DateTime? expiry;
    if (expTs is Timestamp) expiry = expTs.toDate();

    return GeofenceConfig(
      centerLat: (data['centerLat'] as num?)?.toDouble() ?? 0.0,
      centerLon: (data['centerLon'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (data['radiusMeters'] as num?)?.toDouble() ?? 500.0,
      enabled: data['enabled'] as bool? ?? false,
      travelPassActive: data['travelPassActive'] as bool? ?? false,
      travelPassExpiry: expiry,
      travelPassReason: data['travelPassReason'] as String? ?? 'غير محدد',
    );
  }

  String get centerFormatted =>
      '${centerLat.toStringAsFixed(5)}, ${centerLon.toStringAsFixed(5)}';

  String get radiusFormatted => '${radiusMeters.toStringAsFixed(0)} متر';

  String get travelPassExpiryFormatted {
    if (travelPassExpiry == null) return 'غير محدد';
    final diff = travelPassExpiry!.difference(DateTime.now());
    if (diff.isNegative) return 'انتهى';
    return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
  }
}

/// لون حالة النطاق
Color geofenceStatusColor(bool? insideZone) {
  if (insideZone == null) return const Color(0xFF6B6580);
  return insideZone ? const Color(0xFF38A169) : const Color(0xFFE53E3E);
}
