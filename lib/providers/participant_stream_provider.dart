import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/participant_card_model.dart';
import '../models/live_telemetry_model.dart';
import '../repositories/participant_card_repository.dart';
import '../services/firestore_service.dart';

/// ParticipantStreamProvider — يُغذّي واجهة القائد ببيانات حقيقية
///
/// يستمع لـ ParticipantCardRepository ويُكشَف عبر context.watch<>
/// ليحلّ محلّ LeaderUIProvider.participants (mock) في الأجزاء الحية.
///
/// الاستخدام:
///   context.watch<ParticipantStreamProvider>().participants
///   context.watch<ParticipantStreamProvider>().pendingRequests
///   context.watch<ParticipantStreamProvider>().activeCount
///
/// البيانات المصدر:
///   Firestore → profiles, join requests
///   RTDB      → device states (pulse, battery, adminShield…)
///   MQTT      → GPS, battery (via updateMqtt() from TelemetryProvider)
class ParticipantStreamProvider extends ChangeNotifier {
  final _repo = ParticipantCardRepository();
  final _fs   = FirestoreService();

  List<ParticipantCardModel> _participants    = [];
  List<JoinRequestLive>      _pendingRequests = [];
  bool _initialized = false;

  StreamSubscription? _participantsSub;
  StreamSubscription? _pendingSub;

  // ── Getters ───────────────────────────────────────────────────

  List<ParticipantCardModel> get participants    => _participants;
  List<JoinRequestLive>      get pendingRequests => _pendingRequests;
  bool get isInitialized => _initialized;
  bool get hasRealData   => _participants.isNotEmpty;

  int get activeCount => _participants
      .where((p) => p.livePulse == LivePulse.active)
      .length;

  int get pendingCount => _pendingRequests
      .where((r) => r.status == 'pending')
      .length;

  /// بحث في المشاركين
  List<ParticipantCardModel> search(String query) {
    if (query.isEmpty) return _participants;
    final q = query.toLowerCase();
    return _participants.where((p) =>
        p.name.toLowerCase().contains(q) ||
        p.code.toLowerCase().contains(q) ||
        (p.currentJob?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  // ── Initialization ────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _repo.start();

    _participantsSub = _repo.participantsStream.listen((list) {
      _participants = list;
      notifyListeners();
    });

    _pendingSub = _repo.pendingRequestsStream.listen((list) {
      _pendingRequests = list;
      notifyListeners();
    });

    debugPrint('[ParticipantStreamProvider] initialized');
  }

  // ── MQTT Bridge ───────────────────────────────────────────────

  /// يُستدعى من TelemetryProvider عند وصول بيانات MQTT جديدة
  void onMqttUpdate(String uid, LiveTelemetryModel telemetry) {
    _repo.updateMqtt(uid, telemetry);
  }

  // ── Join Request Actions ──────────────────────────────────────

  /// قبول طلب انضمام (الطريقة القديمة — بدون بيانات الموافقة)
  Future<void> acceptRequest(String uid) async {
    try {
      await _fs.updateProfile(uid, {
        'applicationStatus': 'approved',
        'approvedAt':        DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('[ParticipantStreamProvider] ✓ Accepted: $uid');
    } catch (e) {
      debugPrint('[ParticipantStreamProvider] Accept error: $e');
      rethrow;
    }
  }

  /// ✦ قبول طلب انضمام مع بيانات الموافقة الكاملة (Step 2)
  ///
  /// [meta] تحتوي على: توقيت الجرد، وقت ومكان المقابلة، الزي الرسمي
  Future<void> approveWithMeta({
    required String uid,
    required Map<String, dynamic> meta,
    required String assetCode,
  }) async {
    try {
      await _fs.updateProfile(uid, {
        'applicationStatus': 'approved',
        'approvedAt':        DateTime.now().millisecondsSinceEpoch,
        'approvalMeta':      meta,
        'assetCode':         assetCode,
        'deviceSetupComplete': false,
      });
      debugPrint('[ParticipantStreamProvider] ✓ ApprovedWithMeta: $uid | assetCode=$assetCode');
    } catch (e) {
      debugPrint('[ParticipantStreamProvider] ApproveWithMeta error: $e');
      rethrow;
    }
  }

  /// ✦ تفعيل وضع الجرد (Step 3) — تُطلقها السيدة من لوحة التحكم
  Future<void> triggerAuditMode(String uid) async {
    try {
      await _fs.updateProfile(uid, {
        'applicationStatus': 'audit_active',
        'auditStartedAt':    DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('[ParticipantStreamProvider] ✓ AuditMode activated: $uid');
    } catch (e) {
      debugPrint('[ParticipantStreamProvider] TriggerAudit error: $e');
      rethrow;
    }
  }

  /// ✦ تفعيل قفل المقابلة (Step 4a) — يُطلَق من AlarmManager أو يدوياً
  Future<void> triggerInterviewLock(String uid) async {
    try {
      await _fs.updateProfile(uid, {
        'applicationStatus':    'interview_locked',
        'interviewLockedAt':    DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('[ParticipantStreamProvider] 🔒 InterviewLock: $uid');
    } catch (e) {
      debugPrint('[ParticipantStreamProvider] TriggerLock error: $e');
      rethrow;
    }
  }

  /// ✦ إرسال الدستور النهائي (Step 4b) — تُطلقها السيدة بعد المقابلة
  Future<void> pushFinalConstitution({
    required String uid,
    required String leaderDecision,
    required List<String> terms,
    required String signingDeadlineIso,
  }) async {
    try {
      await FirestoreService().updateProfile(uid, {
        'applicationStatus': 'final_constitution_active',
        'constitutionPushedAt': DateTime.now().millisecondsSinceEpoch,
      });
      await FirebaseFirestore.instance.collection('final_constitution').doc(uid).set({
        'leaderDecision':    leaderDecision,
        'terms':             terms,
        'signingDeadlineIso': signingDeadlineIso,
        'pushedAt':          FieldValue.serverTimestamp(),
      });
      debugPrint('[ParticipantStreamProvider] ✓ FinalConstitution pushed: $uid');
    } catch (e) {
      debugPrint('[ParticipantStreamProvider] PushConstitution error: $e');
      rethrow;
    }
  }

  /// رفض طلب انضمام (مع مسح البيانات المحلية من جانب السيدة)
  Future<void> rejectRequest(String uid) async {
    try {
      await _fs.updateProfile(uid, {
        'applicationStatus': 'rejected',
        'rejectedAt':        DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('[ParticipantStreamProvider] ✗ Rejected: $uid');
    } catch (e) {
      debugPrint('[ParticipantStreamProvider] Reject error: $e');
      rethrow;
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────

  @override
  void dispose() {
    _participantsSub?.cancel();
    _pendingSub?.cancel();
    _repo.dispose();
    super.dispose();
  }
}
