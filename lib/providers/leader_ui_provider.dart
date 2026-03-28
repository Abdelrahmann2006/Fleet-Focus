import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/participant_card_model.dart';

/// نموذج طلب الانضمام (mock)
class JoinRequest {
  final String uid;
  final String name;
  final String deviceModel;
  final DateTime requestedAt;
  JoinRequestStatus status;

  JoinRequest({
    required this.uid,
    required this.name,
    required this.deviceModel,
    required this.requestedAt,
    this.status = JoinRequestStatus.pending,
  });
}

enum JoinRequestStatus { pending, accepted, rejected }

/// LeaderUIProvider — يدير حالة واجهة القائد بالكامل
///
/// يشمل:
///  • قائمة المشاركين (mock)
///  • حقول البطاقة المرئية (قابلة للتخصيص)
///  • طلبات الانضمام
///  • كود القائد المولَّد
///  • نمط العرض (Grid / List)
class LeaderUIProvider extends ChangeNotifier {
  // ── Mock Participants ────────────────────────────────────────
  late List<ParticipantCardModel> _participants;
  String _searchQuery = '';
  bool _gridView = true;

  // ── Card Field Visibility ────────────────────────────────────
  Set<String> _visibleFields = Set.from(CardField.defaultVisible);

  // ── Join Requests ────────────────────────────────────────────
  late List<JoinRequest> _joinRequests;

  // ── Generated Code ───────────────────────────────────────────
  String? _generatedCode;
  String? _generatedName;

  LeaderUIProvider() {
    _participants = ParticipantCardModel.mockList(12);
    _joinRequests = _mockRequests();
  }

  // ── Getters ──────────────────────────────────────────────────

  List<ParticipantCardModel> get participants {
    if (_searchQuery.isEmpty) return _participants;
    final q = _searchQuery.toLowerCase();
    return _participants.where((p) =>
      p.name.toLowerCase().contains(q) ||
      p.code.toLowerCase().contains(q) ||
      (p.currentJob?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  bool get gridView => _gridView;
  Set<String> get visibleFields => _visibleFields;
  List<JoinRequest> get joinRequests => _joinRequests;
  int get pendingCount => _joinRequests.where((r) => r.status == JoinRequestStatus.pending).length;
  String? get generatedCode => _generatedCode;
  String? get generatedName => _generatedName;

  // ── Search ───────────────────────────────────────────────────

  void search(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  // ── View Toggle ──────────────────────────────────────────────

  void toggleViewMode() {
    _gridView = !_gridView;
    notifyListeners();
  }

  // ── Field Visibility ─────────────────────────────────────────

  bool isFieldVisible(String key) => _visibleFields.contains(key);

  void toggleField(String key) {
    if (_visibleFields.contains(key)) {
      _visibleFields = Set.from(_visibleFields)..remove(key);
    } else {
      _visibleFields = Set.from(_visibleFields)..add(key);
    }
    notifyListeners();
  }

  void resetFieldsToDefault() {
    _visibleFields = Set.from(CardField.defaultVisible);
    notifyListeners();
  }

  void showAllFields() {
    _visibleFields = CardField.all.map((f) => f.key).toSet();
    notifyListeners();
  }

  void hideAllFields() {
    _visibleFields = {};
    notifyListeners();
  }

  // ── Code Generation ──────────────────────────────────────────

  String generateCode(String participantName) {
    final chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    final code = List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
    _generatedCode = code;
    _generatedName = participantName;
    notifyListeners();
    return code;
  }

  void clearGeneratedCode() {
    _generatedCode = null;
    _generatedName = null;
    notifyListeners();
  }

  // ── Join Requests ────────────────────────────────────────────

  void acceptRequest(String uid) {
    final idx = _joinRequests.indexWhere((r) => r.uid == uid);
    if (idx >= 0) {
      _joinRequests[idx].status = JoinRequestStatus.accepted;
      notifyListeners();
    }
  }

  void rejectRequest(String uid) {
    final idx = _joinRequests.indexWhere((r) => r.uid == uid);
    if (idx >= 0) {
      _joinRequests[idx].status = JoinRequestStatus.rejected;
      notifyListeners();
    }
  }

  // ── Refresh Mock Data ────────────────────────────────────────

  void refreshMockData() {
    _participants = ParticipantCardModel.mockList(12);
    notifyListeners();
  }

  // ── Private Helpers ──────────────────────────────────────────

  static List<JoinRequest> _mockRequests() {
    final names = ['عمر الفيصل', 'ليلى الخالدي', 'ياسر الرويلي', 'رنا المنصور'];
    final models = ['Samsung S23', 'Xiaomi 13', 'Pixel 7', 'OnePlus 11'];
    return List.generate(4, (i) => JoinRequest(
      uid: 'req_$i',
      name: names[i],
      deviceModel: models[i],
      requestedAt: DateTime.now().subtract(Duration(minutes: (i + 1) * 25)),
      status: i < 2 ? JoinRequestStatus.pending : JoinRequestStatus.values[i % 3],
    ));
  }
}
