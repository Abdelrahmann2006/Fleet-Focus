import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// هيكل Firestore المستخدم:
///
/// device_states/{uid}
///   kioskMode      : bool
///   blockedApps    : List<String>
///   lastSeen       : Timestamp
///   permissions    : Map<String, bool>   ← يُحدَّث من الجهاز نفسه
///
/// device_commands/{uid}
///   command        : String   ('enable_kiosk' | 'disable_kiosk' |
///                              'update_blocked_apps' | 'lock_screen')
///   payload        : Map<String, dynamic>
///   timestamp      : Timestamp
///   acknowledged   : bool

class DeviceCommand {
  static const enableKiosk       = 'enable_kiosk';
  static const disableKiosk      = 'disable_kiosk';
  static const updateBlockedApps = 'update_blocked_apps';
  static const lockScreen        = 'lock_screen';
}

class DeviceStateService {
  static final _db = FirebaseFirestore.instance;

  // ── مجموعات Firestore ─────────────────────────────────────
  static CollectionReference get _states   => _db.collection('device_states');
  static CollectionReference get _commands => _db.collection('device_commands');

  // ────────────────────────────────────────────────────────────
  //  قراءة حالة جهاز واحد
  // ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getDeviceState(String uid) async {
    try {
      final doc = await _states.doc(uid).get();
      if (!doc.exists) return null;
      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      debugPrint('DeviceStateService.getDeviceState: $e');
      return null;
    }
  }

  /// Stream لحالة جهاز واحد (real-time)
  static Stream<DocumentSnapshot> watchDeviceState(String uid) {
    return _states.doc(uid).snapshots();
  }

  // ────────────────────────────────────────────────────────────
  //  أوامر القائد → الجهاز
  // ────────────────────────────────────────────────────────────

  /// تفعيل وضع Kiosk على جهاز المشارك
  static Future<void> enableKiosk(String uid) async {
    await _commands.doc(uid).set({
      'command':      DeviceCommand.enableKiosk,
      'payload':      {},
      'timestamp':    FieldValue.serverTimestamp(),
      'acknowledged': false,
    });
    await _states.doc(uid).set({
      'kioskMode': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// تعطيل وضع Kiosk على جهاز المشارك
  static Future<void> disableKiosk(String uid) async {
    await _commands.doc(uid).set({
      'command':      DeviceCommand.disableKiosk,
      'payload':      {},
      'timestamp':    FieldValue.serverTimestamp(),
      'acknowledged': false,
    });
    await _states.doc(uid).set({
      'kioskMode': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// تحديث قائمة التطبيقات المحجوبة عن بُعد
  static Future<void> updateBlockedApps(
    String uid,
    List<String> packages,
  ) async {
    await _commands.doc(uid).set({
      'command':      DeviceCommand.updateBlockedApps,
      'payload':      {'packages': packages},
      'timestamp':    FieldValue.serverTimestamp(),
      'acknowledged': false,
    });
    await _states.doc(uid).set({
      'blockedApps': packages,
      'updatedAt':   FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// قفل شاشة الجهاز فوراً
  static Future<void> lockScreen(String uid) async {
    await _commands.doc(uid).set({
      'command':      DeviceCommand.lockScreen,
      'payload':      {},
      'timestamp':    FieldValue.serverTimestamp(),
      'acknowledged': false,
    });
  }

  // ────────────────────────────────────────────────────────────
  //  من جانب الجهاز: تحديث الحالة + الاستماع للأوامر
  // ────────────────────────────────────────────────────────────

  /// يُحدّث حالة الجهاز (صلاحيات، lastSeen) — يُستدعى من الجهاز
  static Future<void> reportDeviceState(
    String uid, {
    required Map<String, bool> permissions,
    bool? kioskMode,
  }) async {
    final data = <String, dynamic>{
      'permissions': permissions,
      'lastSeen':    FieldValue.serverTimestamp(),
    };
    if (kioskMode != null) data['kioskMode'] = kioskMode;
    await _states.doc(uid).set(data, SetOptions(merge: true));
  }

  /// Stream للأوامر الواردة — الجهاز يستمع لهذا
  static Stream<DocumentSnapshot> watchCommands(String uid) {
    return _commands.doc(uid).snapshots();
  }

  /// يُعلم السيرفر باستلام الأمر وتنفيذه
  static Future<void> acknowledgeCommand(String uid) async {
    await _commands.doc(uid).update({'acknowledged': true});
  }
}
