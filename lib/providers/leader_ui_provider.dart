import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/participant_card_model.dart';

/// LeaderUIProvider — يدير حالة واجهة القائد:
///  • حقول البطاقة المرئية (قابلة للتخصيص)
///  • كود القائد المولَّد
///  • نمط العرض (Grid / List)
///  • البحث
class LeaderUIProvider extends ChangeNotifier {
  String _searchQuery = '';
  bool _gridView = true;

  // ── Card Field Visibility ────────────────────────────────────
  Set<String> _visibleFields = Set.from(CardField.defaultVisible);

  // ── Generated Code ───────────────────────────────────────────
  String? _generatedCode;
  String? _generatedName;

  // ── Getters ──────────────────────────────────────────────────
  bool get gridView => _gridView;
  Set<String> get visibleFields => _visibleFields;
  String? get generatedCode => _generatedCode;
  String? get generatedName => _generatedName;
  String get searchQuery => _searchQuery;

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
}
