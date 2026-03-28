import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

/// DeadMansSwitchService — المفتاح الميت
///
/// إذا كانت السيدة غير نشطة لـ 24 ساعة متواصلة →
/// يُنفِّذ انضباطاً تلقائياً على جميع العناصر المرتبطة
/// بناءً على إعدادات Persona Engine في Firestore.
///
/// يُحدَّث timestamp النشاط عند كل تفاعل في التطبيق.
class DeadMansSwitchService {
  DeadMansSwitchService._();
  static final instance = DeadMansSwitchService._();

  static const _thresholdHours = 24;
  Timer? _ticker;
  String _leaderUid = '';

  // ── تشغيل ─────────────────────────────────────────────────────────────────

  void start(String leaderUid) {
    _leaderUid = leaderUid;
    _ticker?.cancel();
    // تحقق كل 30 دقيقة
    _ticker = Timer.periodic(const Duration(minutes: 30), (_) => _check());
  }

  void stop() {
    _ticker?.cancel();
    _leaderUid = '';
  }

  // ── تحديث وقت آخر نشاط ───────────────────────────────────────────────────

  void heartbeat() {
    if (_leaderUid.isEmpty) return;
    FirebaseDatabase.instance
        .ref('leader_activity/$_leaderUid/lastSeen')
        .set(ServerValue.timestamp);
  }

  // ── التحقق من الحالة ──────────────────────────────────────────────────────

  Future<DeadManStatus> getStatus() async {
    if (_leaderUid.isEmpty) {
      return DeadManStatus(isTriggered: false, inactiveHours: 0);
    }
    return _computeStatus();
  }

  Future<void> _check() async {
    final status = await _computeStatus();
    if (!status.isTriggered) return;

    // اقرأ Persona Engine
    final personaDoc = await FirebaseFirestore.instance
        .collection('config')
        .doc('persona_engine')
        .get();
    final persona = personaDoc.data() ?? {};

    // احصل على جميع العناصر المرتبطة
    final leaderDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_leaderUid)
        .get();
    final code = leaderDoc.data()?['leaderCode'] as String?;
    if (code == null) return;

    final assets = await FirebaseFirestore.instance
        .collection('users')
        .where('linkedLeaderCode', isEqualTo: code)
        .where('role', isEqualTo: 'participant')
        .get();

    final action = persona['defaultAction'] as String? ?? 'lock_screen';
    final msg    = persona['inactivityMessage'] as String?
        ?? 'السيدة في وضع عدم الاتصال — تطبيق الانضباط التلقائي.';

    for (final asset in assets.docs) {
      await FirebaseFirestore.instance
          .collection('device_commands')
          .doc(asset.id)
          .set({
        'command': action,
        'payload': {'reason': msg, 'auto': true},
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'source': 'dead_mans_switch',
      }, SetOptions(merge: false));
    }

    // سجَّل في Firestore
    await FirebaseFirestore.instance
        .collection('dead_mans_switch_log')
        .add({
      'leaderUid':      _leaderUid,
      'triggeredAt':    FieldValue.serverTimestamp(),
      'inactiveHours':  status.inactiveHours,
      'assetsAffected': assets.size,
      'action':         action,
    });
  }

  Future<DeadManStatus> _computeStatus() async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref('leader_activity/$_leaderUid/lastSeen')
          .get();
      final ms  = snap.value as int? ?? 0;
      if (ms == 0) return DeadManStatus(isTriggered: false, inactiveHours: 0);
      final lastSeen = DateTime.fromMillisecondsSinceEpoch(ms);
      final hours    = DateTime.now().difference(lastSeen).inHours;
      return DeadManStatus(
        isTriggered:    hours >= _thresholdHours,
        inactiveHours:  hours,
        lastSeen:       lastSeen,
      );
    } catch (_) {
      return DeadManStatus(isTriggered: false, inactiveHours: 0);
    }
  }

  // ── إعداد Persona Engine ──────────────────────────────────────────────────

  Future<void> savePersona({
    required String defaultAction,
    required String inactivityMessage,
    int thresholdHours = 24,
  }) async {
    await FirebaseFirestore.instance
        .collection('config')
        .doc('persona_engine')
        .set({
      'defaultAction':       defaultAction,
      'inactivityMessage':   inactivityMessage,
      'thresholdHours':      thresholdHours,
      'updatedAt':           FieldValue.serverTimestamp(),
    });
  }
}

class DeadManStatus {
  final bool isTriggered;
  final int inactiveHours;
  final DateTime? lastSeen;
  const DeadManStatus({
    required this.isTriggered,
    required this.inactiveHours,
    this.lastSeen,
  });
}
