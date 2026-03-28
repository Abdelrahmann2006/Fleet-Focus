import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// TaskGovernanceService — محرك إدارة المهام والدور اليومي
///
/// الوظائف:
///  1. التدوير الخوارزمي للأدوار (بدون تكرار يومَين متتاليَين)
///  2. الإشعار عبر FCM (عبر Firestore trigger / Cloud Function)
///  3. كاشف تزوير المهام (Proof of Task)
///  4. تسجيل الفوز الصوتي / الخسارة الصوتية (طلب على الجهاز)
class TaskGovernanceService {
  TaskGovernanceService._();
  static final instance = TaskGovernanceService._();

  static const _roles  = ['housekeeper', 'companion', 'secretary'];
  static const _rolesAr= ['عاملة المنزل', 'المرافقة', 'السكرتيرة'];

  // ── تدوير الأدوار ─────────────────────────────────────────────────────────

  /// يُعيَّن دور جديد للعنصر بشرط عدم تكراره يومين متتاليين
  Future<RoleAssignment> rotateRole(String uid) async {
    final fs = FirebaseFirestore.instance;

    // اقرأ آخر دور مُعيَّن
    final doc = await fs
        .collection('task_assignments')
        .doc(uid)
        .collection('daily_roles')
        .orderBy('assignedAt', descending: true)
        .limit(1)
        .get();

    final lastRole = doc.docs.isNotEmpty
        ? doc.docs.first.data()['role'] as String? ?? ''
        : '';

    // اختر دوراً مختلفاً بشكل عشوائي
    final available = _roles.where((r) => r != lastRole).toList();
    final newRole   = available[Random().nextInt(available.length)];
    final newRoleAr = _rolesAr[_roles.indexOf(newRole)];

    // اكتب في Firestore
    final ref = await fs
        .collection('task_assignments')
        .doc(uid)
        .collection('daily_roles')
        .add({
      'role':       newRole,
      'roleAr':     newRoleAr,
      'assignedAt': FieldValue.serverTimestamp(),
      'status':     'active',
    });

    // أرسل أمر FCM للجهاز عبر device_commands
    await _sendFcmViaCommand(uid, newRoleAr, ref.id);

    return RoleAssignment(
      roleId:   newRole,
      roleAr:   newRoleAr,
      docId:    ref.id,
      assignedAt: DateTime.now(),
    );
  }

  /// يُرسل إشعار FCM عبر آلية device_commands الموجودة
  Future<void> _sendFcmViaCommand(
    String uid, String roleAr, String roleDocId) async {
    await FirebaseFirestore.instance
        .collection('device_commands')
        .doc(uid)
        .set({
      'command': 'fcm_role_assigned',
      'payload': {
        'title':      'تعيين دور جديد',
        'body':       'تم تعيينك في دور: $roleAr',
        'role_doc':   roleDocId,
        'priority':   'high',
        'vibration':  true,
      },
      'timestamp': FieldValue.serverTimestamp(),
      'status':    'pending',
    }, SetOptions(merge: false));
  }

  // ── إضافة مهمة ────────────────────────────────────────────────────────────

  Future<void> addTask({
    required String uid,
    required String title,
    required String category,
    required DateTime deadline,
    int points = 10,
  }) async {
    await FirebaseFirestore.instance
        .collection('task_assignments')
        .doc(uid)
        .collection('tasks')
        .add({
      'title':       title,
      'category':    category,
      'deadline':    Timestamp.fromDate(deadline),
      'points':      points,
      'status':      'pending',
      'createdAt':   FieldValue.serverTimestamp(),
      'completedAt': null,
    });
  }

  // ── كاشف التزوير (Proof of Task) ─────────────────────────────────────────

  /// يتحقق من النمط الزمني للمهام المكتملة —
  /// إذا أُكملت ≥ 3 مهام في < 60 ثانية → مشبوه
  Future<FalsificationReport> checkFalsification(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('task_assignments')
        .doc(uid)
        .collection('tasks')
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true)
        .limit(10)
        .get();

    final timestamps = snap.docs
        .map((d) => (d.data()['completedAt'] as Timestamp?)?.toDate())
        .whereType<DateTime>()
        .toList();

    if (timestamps.length < 3) {
      return FalsificationReport(isSuspicious: false, count: timestamps.length, windowSec: 0);
    }

    // احسب أسرع نافذة لـ 3 مهام متتالية
    int minWindow = 999999;
    for (int i = 0; i < timestamps.length - 2; i++) {
      final window = timestamps[i]
          .difference(timestamps[i + 2])
          .inSeconds
          .abs();
      if (window < minWindow) minWindow = window;
    }

    final suspicious = minWindow < 60;
    if (suspicious) {
      // اكتب تحذيراً في RTDB للعرض الفوري
      FirebaseDatabase.instance
          .ref('device_states/$uid/potAlert')
          .set({
        'suspicious':  true,
        'windowSec':   minWindow,
        'detectedAt':  ServerValue.timestamp,
      });
    }

    return FalsificationReport(
      isSuspicious: suspicious,
      count:        timestamps.length,
      windowSec:    minWindow,
    );
  }

  // ── طلب صوت المكافأة/العقاب ────────────────────────────────────────────

  Future<void> playAudio(String uid, {required bool success}) async {
    await FirebaseFirestore.instance
        .collection('device_commands')
        .doc(uid)
        .set({
      'command': success ? 'play_success_audio' : 'play_aversive_buzzer',
      'payload': {},
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    }, SetOptions(merge: false));
  }

  // ── تكامل Google Calendar (وكيل HTTP) ─────────────────────────────────────

  /// يسحب أحداث Lockout من Google Calendar ويُرسل أمر قفل للجهاز
  Future<List<CalendarEvent>> fetchLockoutEvents(
    String calendarId,
    String apiKey,
    String uid,
  ) async {
    try {
      final now   = DateTime.now().toUtc();
      final end   = now.add(const Duration(days: 7));
      final url   = Uri.parse(
        'https://www.googleapis.com/calendar/v3/calendars/'
        '${Uri.encodeComponent(calendarId)}/events'
        '?key=$apiKey'
        '&timeMin=${now.toIso8601String()}'
        '&timeMax=${end.toIso8601String()}'
        '&q=Lockout'
        '&singleEvents=true'
        '&orderBy=startTime',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return [];
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final items = (json['items'] as List?) ?? [];

      return items.map((e) {
        final start = DateTime.parse(
            e['start']?['dateTime'] ?? e['start']?['date'] ?? '');
        final end_ = DateTime.parse(
            e['end']?['dateTime'] ?? e['end']?['date'] ?? '');
        return CalendarEvent(
          title:    e['summary'] as String? ?? '',
          start:    start,
          end:      end_,
          isoStart: e['start']?['dateTime'] ?? e['start']?['date'] ?? '',
        );
      }).where((e) => e.title.toLowerCase().contains('lockout')).toList();
    } catch (_) {
      return [];
    }
  }

  /// يُرسل أمر Time Dungeon Lock للجهاز
  Future<void> triggerTimeDungeon(
    String uid, DateTime start, DateTime end) async {
    await FirebaseFirestore.instance
        .collection('device_commands')
        .doc(uid)
        .set({
      'command':   'time_dungeon_lock',
      'payload': {
        'start': start.millisecondsSinceEpoch,
        'end':   end.millisecondsSinceEpoch,
        'reason': 'Calendar: Lockout',
      },
      'timestamp': FieldValue.serverTimestamp(),
      'status':    'pending',
    }, SetOptions(merge: false));
  }
}

// ── النماذج ────────────────────────────────────────────────────────────────

class RoleAssignment {
  final String roleId;
  final String roleAr;
  final String docId;
  final DateTime assignedAt;
  const RoleAssignment({
    required this.roleId,
    required this.roleAr,
    required this.docId,
    required this.assignedAt,
  });
}

class FalsificationReport {
  final bool isSuspicious;
  final int count;
  final int windowSec;
  const FalsificationReport({
    required this.isSuspicious,
    required this.count,
    required this.windowSec,
  });
}

class CalendarEvent {
  final String title;
  final DateTime start;
  final DateTime end;
  final String isoStart;
  const CalendarEvent({
    required this.title,
    required this.start,
    required this.end,
    required this.isoStart,
  });
}
