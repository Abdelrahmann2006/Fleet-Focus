import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';

/// ProfileRepository — إدارة الملفات الشخصية عبر Firestore
///
/// البيانات:
///  • اسم المشارك + كود التسجيل
///  • التصنيف (مقيم/وافد)
///  • حالة الطلب (pending/approved/rejected)
///  • بيانات الجهاز والإعداد
///
/// سياسة الكاش:
///  Firestore persistenceEnabled → يعمل offline بعد أول قراءة
class ProfileRepository {
  static final ProfileRepository _instance = ProfileRepository._();
  factory ProfileRepository() => _instance;
  ProfileRepository._();

  final _fs = FirestoreService();

  // ── Participant: Self Profile ─────────────────────────────────

  Future<Map<String, dynamic>?> getMyProfile(String uid) =>
      _fs.getProfile(uid);

  Future<void> updateMyProfile(String uid, Map<String, dynamic> data) =>
      _fs.updateProfile(uid, data);

  /// إعداد الملف الشخصي الأولي للمشارك بعد التسجيل
  Future<void> initializeParticipant({
    required String uid,
    required String name,
    required String email,
    required String code,
    String? deviceModel,
    String? androidVersion,
  }) async {
    await _fs.updateProfile(uid, {
      'name': name,
      'email': email,
      'role': 'participant',
      'code': code,
      'applicationStatus': 'pending',
      'deviceSetupComplete': false,
      if (deviceModel != null) 'deviceModel': deviceModel,
      if (androidVersion != null) 'androidVersion': androidVersion,
    });
    debugPrint('[ProfileRepo] Participant initialized: $uid');
  }

  /// تحديث بيانات الجهاز بعد اكتمال الإعداد
  Future<void> markDeviceSetupComplete(String uid, {
    required bool adminShield,
    required bool accessibilityEnabled,
    required bool overlayPermission,
    required bool batteryOptimizationIgnored,
  }) async {
    await _fs.updateProfile(uid, {
      'deviceSetupComplete': true,
      'setupCompletedAt': DateTime.now().millisecondsSinceEpoch,
      'permissions': {
        'deviceAdmin': adminShield,
        'accessibility': accessibilityEnabled,
        'overlay': overlayPermission,
        'batteryOptimization': batteryOptimizationIgnored,
      },
    });
  }

  // ── Leader: All Participants ──────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllParticipants() =>
      _fs.getAllParticipants();

  Stream<List<Map<String, dynamic>>> watchPendingRequests() =>
      _fs.watchPendingRequests();

  Stream<Map<String, dynamic>?> watchParticipant(String uid) =>
      _fs.watchProfile(uid);

  Future<void> acceptParticipant(String uid) =>
      _fs.setApplicationStatus(uid, 'approved');

  Future<void> rejectParticipant(String uid) =>
      _fs.setApplicationStatus(uid, 'rejected');

  // ── Code Management ───────────────────────────────────────────

  Future<void> saveGeneratedCode(String leaderUid, String participantName, String code) =>
      _fs.saveParticipantCode(leaderUid, participantName, code);

  Future<Map<String, dynamic>?> validateCode(String code) =>
      _fs.validateCode(code);

  Future<void> markCodeUsed(String code) =>
      _fs.markCodeUsed(code);

  // ── Classification ────────────────────────────────────────────

  Future<void> setClassification(String uid, String classification) async {
    await _fs.updateProfile(uid, {'classification': classification});
  }

  // ── Bulk Operations (Leader) ──────────────────────────────────

  /// تحديث درجة الطاعة للمشارك (مثال: بعد تقييم)
  Future<void> updateObedienceGrade(String uid, int grade) async {
    assert(grade >= 0 && grade <= 100);
    await _fs.updateProfile(uid, {'obedienceGrade': grade});
  }

  Future<void> addCredits(String uid, int amount) async {
    // لا نستخدم FieldValue.increment مباشرةً هنا لأنه في FirestoreService
    final profile = await _fs.getProfile(uid);
    final current = (profile?['credits'] as num?)?.toInt() ?? 0;
    await _fs.updateProfile(uid, {'credits': current + amount});
  }

  Future<void> updateCurrentJob(String uid, String? job) async {
    await _fs.updateProfile(uid, {'currentJob': job});
  }

  Future<void> updateTaskProgress(String uid, double progress) async {
    assert(progress >= 0.0 && progress <= 1.0);
    await _fs.updateProfile(uid, {'taskProgress': progress});
  }

  Future<void> updateRank(String uid, int rank) async {
    await _fs.updateProfile(uid, {'rankPosition': rank});
  }
}
