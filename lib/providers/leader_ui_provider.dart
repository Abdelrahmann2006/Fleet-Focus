import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/participant_card_model.dart';

/// LeaderUIProvider — يدير حالة واجهة القائد والعمليات السيادية:
///  • وضع الهدوء الانفعالي (Zen Mode)
///  • تخصيص حقول عرض بطاقة المشارك
///  • توليد وحفظ معرفات الانضمام الرسمية (PAN-ID) في Firestore
///  • إدارة البحث ونمط العرض (Grid / List)
class LeaderUIProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _searchQuery = '';
  bool _gridView = true;
  bool _zenMode = false;

  // ── تخصيص الحقول المرئية ─────────────────────────────────────
  Set<String> _visibleFields = Set.from(CardField.defaultVisible);

  // ── بيانات المعرف المولَّد ──────────────────────────────────────
  String? _generatedCode;
  String? _generatedName;

  // ── Getters ──────────────────────────────────────────────────
  bool get gridView => _gridView;
  bool get zenMode => _zenMode;
  Set<String> get visibleFields => _visibleFields;
  String? get generatedCode => _generatedCode;
  String? get generatedName => _generatedName;
  String get searchQuery => _searchQuery;

  // ── منطق الهدوء الانفعالي (Zen Mode) ──────────────────────────
  void toggleZenMode() {
    _zenMode = !_zenMode;
    notifyListeners();
  }

  // ── البحث وطريقة العرض ───────────────────────────────────────
  void search(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void toggleViewMode() {
    _gridView = !_gridView;
    notifyListeners();
  }

  // ── التحكم في الحقول ─────────────────────────────────────────
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

  // ── توليد المعرف الرسمي (ID System) وحفظه في Firestore ─────────
  /// يقوم بتوليد كود بصيغة PAN-XXXXXX وحفظه فوراً في مستند القائد
  /// لضمان قبول التابع عند استخدامه.
  Future<String> generateCode(String participantName, String leaderUid) async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    
    // توليد 6 رموز عشوائية
    final randomPart = List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
    
    // تنسيق المعرف النهائي للنظام
    final code = 'PAN-$randomPart'; 
    
    try {
      // تحديث قاعدة البيانات فوراً لربط الكود بـ "السيدة"
      await _db.collection('users').doc(leaderUid).update({
        'leaderCode': code,
        'lastGeneratedFor': participantName,
        'codeGeneratedAt': FieldValue.serverTimestamp(),
      });

      _generatedCode = code;
      _generatedName = participantName;
      
      notifyListeners();
      return code;
    } catch (e) {
      debugPrint('Error generating/saving code: $e');
      rethrow;
    }
  }

  void clearGeneratedCode() {
    _generatedCode = null;
    _generatedName = null;
    notifyListeners();
  }
}
