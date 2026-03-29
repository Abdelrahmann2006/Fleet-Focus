import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/participant_card_model.dart';

/// LeaderUIProvider — يدير حالة واجهة القائد بالكامل:
///  • وضع الهدوء الانفعالي (Zen Mode)
///  • حقول البطاقة المرئية (قابلة للتخصيص)
///  • توليد معرفات الانضمام الرسمية (PAN-ID)
///  • نمط العرض (Grid / List) والبحث
class LeaderUIProvider extends ChangeNotifier {
  String _searchQuery = '';
  bool _gridView = true;
  bool _zenMode = false;

  // ── Card Field Visibility ────────────────────────────────────
  // افتراضياً تظهر كافة الحقول الأساسية
  Set<String> _visibleFields = Set.from(CardField.defaultVisible);

  // ── Generated ID System ──────────────────────────────────────
  String? _generatedCode;
  String? _generatedName;

  // ── Getters ──────────────────────────────────────────────────
  bool get gridView => _gridView;
  bool get zenMode => _zenMode;
  Set<String> get visibleFields => _visibleFields;
  String? get generatedCode => _generatedCode;
  String? get generatedName => _generatedName;
  String get searchQuery => _searchQuery;

  // ── Zen Mode Logic ───────────────────────────────────────────
  void toggleZenMode() {
    _zenMode = !_zenMode;
    notifyListeners();
  }

  // ── Search & View ────────────────────────────────────────────
  void search(String q) {
    _searchQuery = q;
    notifyListeners();
  }

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

  // ── Official ID Generation (PAN-XXXXXX) ──────────────────────
  /// يولد معرفاً فريداً يبدأ ببادئة النظام PAN- متبوعة بـ 6 رموز alphanumeric
  String generateCode(String participantName) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    
    // توليد الجزء العشوائي
    final randomPart = List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
    
    // تنسيق المعرف الرسمي للنظام
    final code = 'PAN-$randomPart'; 
    
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
