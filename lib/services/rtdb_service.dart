import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/device_state_model.dart';

/// RtdbService — Firebase Realtime Database
///
/// المسؤوليات:
///  • المشارك: يرفع حالة جهازه كل ~30ث + عند كل تغيير مهم
///  • القائد: يستمع لجميع المشاركين بـ Stream واحد
///
/// هيكل RTDB:
/// /device_states/
///   {uid}/
///     pulse, batteryPct, batteryCharging, screenActive,
///     currentJob, taskProgress, connectionQuality,
///     activityState, focusApp, adminShield,
///     accessibilityEnabled, overlayPermission,
///     batteryOptimizationIgnored, lastSeen, storageFreePct
class RtdbService {
  // ── Singleton ─────────────────────────────────────────────────
  static final RtdbService _instance = RtdbService._internal();
  factory RtdbService() => _instance;
  RtdbService._internal();

  FirebaseDatabase get _db => FirebaseDatabase.instance;

  static const String _root = 'device_states';

  // ── Participant: Push State ───────────────────────────────────

  /// يُحدّث حالة المشارك في RTDB
  Future<void> updateParticipantState({
    required String uid,
    required DeviceStateModel state,
  }) async {
    try {
      await _db.ref('$_root/$uid').update(state.toRtdb());
      debugPrint('[RTDB] State updated for $uid');
    } catch (e) {
      debugPrint('[RTDB] Update error: $e');
      rethrow;
    }
  }

  /// تحديث سريع لحقل واحد فقط (مثل batteryPct)
  Future<void> updateField(String uid, String field, dynamic value) async {
    try {
      await _db.ref('$_root/$uid/$field').set(value);
    } catch (e) {
      debugPrint('[RTDB] Field update error ($field): $e');
    }
  }

  /// تحديث أحدث ظهور + حالة النبض (كل 15 ثانية)
  Future<void> heartbeat(String uid, String pulse) async {
    try {
      await _db.ref('$_root/$uid').update({
        'pulse': pulse,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('[RTDB] Heartbeat error: $e');
    }
  }

  /// تسجيل انقطاع عند الإغلاق (يُنفَّذ تلقائياً من الخادم)
  void setOnDisconnect(String uid) {
    _db.ref('$_root/$uid').onDisconnect().update({
      'pulse': 'offline',
      'lastSeen': ServerValue.timestamp,
    });
  }

  /// إزالة Disconnect hook
  void cancelOnDisconnect(String uid) {
    _db.ref('$_root/$uid').onDisconnect().cancel();
  }

  // ── Leader: Watch Single Participant ─────────────────────────

  /// Stream لحالة مشارك واحد — يتحدث فور تغيير أي حقل
  Stream<DeviceStateModel> watchParticipant(String uid) {
    return _db
        .ref('$_root/$uid')
        .onValue
        .map((event) {
          final data = event.snapshot.value;
          if (data == null || data is! Map) {
            return DeviceStateModel.offline.copyWith();
          }
          try {
            return DeviceStateModel.fromRtdb(
              uid,
              data as Map<dynamic, dynamic>,
            );
          } catch (e) {
            debugPrint('[RTDB] Parse error for $uid: $e');
            return DeviceStateModel(uid: uid, pulse: 'offline');
          }
        })
        .handleError((e) => debugPrint('[RTDB] Stream error: $e'));
  }

  // ── Leader: Watch All Participants ────────────────────────────

  /// Stream لجميع المشاركين دفعةً واحدة
  /// يُعيد Map<uid, DeviceStateModel>
  Stream<Map<String, DeviceStateModel>> watchAll() {
    return _db
        .ref(_root)
        .onValue
        .map((event) {
          final data = event.snapshot.value;
          if (data == null || data is! Map) return <String, DeviceStateModel>{};

          final result = <String, DeviceStateModel>{};
          for (final entry in (data as Map).entries) {
            final uid = entry.key as String;
            final val = entry.value;
            if (val is! Map) continue;
            try {
              result[uid] = DeviceStateModel.fromRtdb(uid, val as Map<dynamic, dynamic>);
            } catch (e) {
              debugPrint('[RTDB] Parse error for $uid: $e');
            }
          }
          return result;
        })
        .handleError((e) => debugPrint('[RTDB] WatchAll error: $e'));
  }

  // ── Leader: Watch Specific Fields ────────────────────────────

  /// Stream لتغييرات حقل واحد فقط لمشارك معيّن
  Stream<T?> watchField<T>(String uid, String field) {
    return _db
        .ref('$_root/$uid/$field')
        .onValue
        .map((event) => event.snapshot.value as T?)
        .handleError((e) => debugPrint('[RTDB] Field watch error: $e'));
  }

  // ── One-time Read ─────────────────────────────────────────────

  Future<DeviceStateModel?> getOnce(String uid) async {
    try {
      final snap = await _db.ref('$_root/$uid').get();
      if (!snap.exists || snap.value == null) return null;
      return DeviceStateModel.fromRtdb(uid, snap.value as Map<dynamic, dynamic>);
    } catch (e) {
      debugPrint('[RTDB] GetOnce error: $e');
      return null;
    }
  }

  // ── Admin Commands ─────────────────────────────────────────────

  /// القائد يرسل أمر RTDB للمشارك (مكمّل لـ Firestore commands)
  Future<void> pushCommand(String uid, {
    required String command,
    Map<String, dynamic>? payload,
  }) async {
    await _db.ref('device_commands_rt/$uid').set({
      'command': command,
      'payload': payload ?? {},
      'issuedAt': DateTime.now().millisecondsSinceEpoch,
      'acknowledged': false,
    });
  }

  /// الاشتراك في الأوامر الواردة للمشارك (بديل خفيف عن Firestore)
  Stream<Map<String, dynamic>?> watchCommands(String uid) {
    return _db
        .ref('device_commands_rt/$uid')
        .onValue
        .map((event) {
          final data = event.snapshot.value;
          if (data == null || data is! Map) return null;
          final map = Map<String, dynamic>.from(data as Map);
          if (map['acknowledged'] == true) return null;
          return map;
        })
        .where((cmd) => cmd != null)
        .handleError((e) => debugPrint('[RTDB] Commands watch error: $e'));
  }

  /// إقرار استلام أمر RTDB
  Future<void> acknowledgeCommand(String uid) async {
    await _db.ref('device_commands_rt/$uid/acknowledged').set(true);
  }
}
