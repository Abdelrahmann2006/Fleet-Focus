import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pointycastle/digests/sha256.dart';
import '../models/approval_meta_model.dart';
import '../services/sync_service.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;
  final String? role;
  final String? fullName;
  final String? linkedLeaderCode;
  final String? linkedLeaderUid;
  final String? applicationStatus;
  final bool biometricEnabled;
  final bool deviceSetupComplete;

  /// بيانات موافقة السيدة (مدرجة عند القبول — Step 2)
  final ApprovalMeta? approvalMeta;

  /// رمز العنصر المُوحَّد
  final String? assetCode;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    this.role,
    this.fullName,
    this.linkedLeaderCode,
    this.linkedLeaderUid,
    this.applicationStatus,
    this.biometricEnabled = false,
    this.deviceSetupComplete = false,
    this.approvalMeta,
    this.assetCode,
  });

  AppUser copyWith({
    String? role,
    String? fullName,
    String? linkedLeaderCode,
    String? linkedLeaderUid,
    String? applicationStatus,
    bool? biometricEnabled,
    bool? deviceSetupComplete,
    ApprovalMeta? approvalMeta,
    String? assetCode,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName,
      photoURL: photoURL,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      linkedLeaderCode: linkedLeaderCode ?? this.linkedLeaderCode,
      linkedLeaderUid: linkedLeaderUid ?? this.linkedLeaderUid,
      applicationStatus: applicationStatus ?? this.applicationStatus,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      deviceSetupComplete: deviceSetupComplete ?? this.deviceSetupComplete,
      approvalMeta: approvalMeta ?? this.approvalMeta,
      assetCode: assetCode ?? this.assetCode,
    );
  }

  factory AppUser.fromFirestore(User firebaseUser, Map<String, dynamic> data) {
    ApprovalMeta? meta;
    final metaRaw = data['approvalMeta'];
    if (metaRaw is Map<String, dynamic>) {
      meta = ApprovalMeta.fromMap(metaRaw);
    }
    return AppUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName ?? '',
      photoURL: firebaseUser.photoURL,
      role: data['role'],
      fullName: data['fullName'],
      linkedLeaderCode: data['linkedLeaderCode'],
      linkedLeaderUid: data['linkedLeaderUid'],
      applicationStatus: data['applicationStatus'],
      biometricEnabled: data['biometricEnabled'] ?? false,
      deviceSetupComplete: data['deviceSetupComplete'] ?? false,
      approvalMeta: meta,
      assetCode: data['assetCode'],
    );
  }
}

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AppUser? _user;
  User? _firebaseUser;
  bool _isLoading = true;

  // ── بوابة المصادقة البيومترية (في الذاكرة فقط — تُعاد عند كل تشغيل) ──
  bool _biometricVerified = false;

  AppUser? get user => _user;
  User? get firebaseUser => _firebaseUser;
  bool get isLoading => _isLoading;
  bool get biometricVerified => _biometricVerified;

  static const String _dpcPasswordKey = 'pnx_dpc_password_hash';

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? fbUser) async {
    if (fbUser == null) {
      _firebaseUser = null;
      _user = null;
      _isLoading = false;
      _biometricVerified = false;
      notifyListeners();
      return;
    }
    _firebaseUser = fbUser;
    try {
      final doc = await _db.collection('users').doc(fbUser.uid).get();
      if (doc.exists) {
        _user = AppUser.fromFirestore(fbUser, doc.data()!);
      } else {
        _user = AppUser(
          uid: fbUser.uid,
          email: fbUser.email ?? '',
          displayName: fbUser.displayName ?? '',
          photoURL: fbUser.photoURL,
        );
      }
    } catch (e) {
      _user = AppUser(
        uid: fbUser.uid,
        email: fbUser.email ?? '',
        displayName: fbUser.displayName ?? '',
        photoURL: fbUser.photoURL,
      );
    }
    _isLoading = false;
    notifyListeners();

    // ── Module 2: Burst Sync — يبدأ فور تسجيل الدخول ──────────
    if (fbUser != null) {
      SyncService.instance.start(uid: fbUser.uid);
    }
  }

  Future<void> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await _auth.signInWithCredential(credential);
  }

  // ── بوابة المصادقة البيومترية ─────────────────────────────────

  /// تُعلم النظام بنجاح المصادقة البيومترية — تُستدعى من BiometricGateScreen
  void markBiometricVerified() {
    _biometricVerified = true;
    notifyListeners();
  }

  // ── تشفير كلمة المرور ─────────────────────────────────────────

  /// SHA-256 hash of password with app-specific salt
  static String _hashPassword(String uid, String password) {
    final input = 'pnx_dpc_${uid}_${password}_2026';
    final bytes = Uint8List.fromList(utf8.encode(input));
    final digest = SHA256Digest();
    final hash = digest.process(bytes);
    return base64Encode(hash);
  }

  /// تخزين hash كلمة مرور DPC في SharedPreferences
  Future<void> storeAppPassword(String uid, String rawPassword) async {
    if (rawPassword.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '${_dpcPasswordKey}_$uid', _hashPassword(uid, rawPassword));
  }

  /// التحقق من كلمة مرور DPC — إذا لم تُحفظ بعد تُعيد true تلقائياً
  Future<bool> verifyAppPassword(String uid, String rawPassword) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('${_dpcPasswordKey}_$uid');
    if (stored == null || stored.isEmpty) return true; // لم تُضبط بعد
    return stored == _hashPassword(uid, rawPassword);
  }

  /// هل توجد كلمة مرور DPC محفوظة لهذا القائد؟
  Future<bool> hasDpcPassword(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('${_dpcPasswordKey}_$uid');
    return stored != null && stored.isNotEmpty;
  }

  // ── إعداد الحسابات ────────────────────────────────────────────

  Future<void> setupLeaderAccount({
    required String fullName,
    required String appPassword,
    required bool biometricEnabled,
  }) async {
    if (_firebaseUser == null) return;
    final leaderCode = 'L-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase().substring(7)}';
    final data = {
      'uid': _firebaseUser!.uid,
      'email': _firebaseUser!.email,
      'displayName': _firebaseUser!.displayName,
      'photoURL': _firebaseUser!.photoURL,
      'role': 'leader',
      'fullName': fullName,
      'leaderCode': leaderCode,
      'biometricEnabled': biometricEnabled,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _db.collection('users').doc(_firebaseUser!.uid).set(data, SetOptions(merge: true));
    await _db.collection('leader_codes').doc(leaderCode).set({
      'leaderUid': _firebaseUser!.uid,
      'leaderName': fullName,
      'createdAt': FieldValue.serverTimestamp(),
      'active': true,
    });
    // حفظ كلمة مرور DPC محلياً (SHA-256)
    await storeAppPassword(_firebaseUser!.uid, appPassword);
    _user = _user?.copyWith(role: 'leader', fullName: fullName, biometricEnabled: biometricEnabled);
    notifyListeners();
  }

  Future<Map<String, dynamic>?> validateLeaderCode(String code) async {
    final doc = await _db.collection('leader_codes').doc(code.toUpperCase()).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    if (data['active'] != true) return null;
    return data;
  }

  Future<void> setupParticipantAccount({
    required String leaderCode,
    required String leaderUid,
    required bool biometricEnabled,
  }) async {
    if (_firebaseUser == null) return;
    final data = {
      'uid': _firebaseUser!.uid,
      'email': _firebaseUser!.email,
      'displayName': _firebaseUser!.displayName,
      'photoURL': _firebaseUser!.photoURL,
      'role': 'participant',
      'linkedLeaderCode': leaderCode.toUpperCase(),
      'linkedLeaderUid': leaderUid,
      'biometricEnabled': biometricEnabled,
      'applicationStatus': 'pending',
      'deviceSetupComplete': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _db.collection('users').doc(_firebaseUser!.uid).set(data, SetOptions(merge: true));
    _user = _user?.copyWith(
      role: 'participant',
      linkedLeaderCode: leaderCode.toUpperCase(),
      linkedLeaderUid: leaderUid,
      biometricEnabled: biometricEnabled,
    );
    notifyListeners();
  }

  Future<void> markDeviceSetupComplete() async {
    if (_firebaseUser == null) return;
    await _db.collection('users').doc(_firebaseUser!.uid).update({
      'deviceSetupComplete': true,
      'deviceSetupAt': FieldValue.serverTimestamp(),
    });
    _user = _user?.copyWith(deviceSetupComplete: true);
    notifyListeners();
  }

  Future<void> updateApplicationStatus(String status) async {
    if (_firebaseUser == null) return;
    await _db.collection('users').doc(_firebaseUser!.uid).update({
      'applicationStatus': status,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
    });
    _user = _user?.copyWith(applicationStatus: status);
    notifyListeners();
  }

  /// تُعلِم الجهاز بأن شاشة الانتقال (Dying Screen) قد عُرضت
  /// وتُغيَّر الحالة إلى `approved_active`
  Future<void> markDyingScreenComplete() async {
    if (_firebaseUser == null) return;
    await _db.collection('users').doc(_firebaseUser!.uid).update({
      'applicationStatus': 'approved_active',
      'dyingScreenShownAt': FieldValue.serverTimestamp(),
    });
    _user = _user?.copyWith(applicationStatus: 'approved_active');
    notifyListeners();
  }

  /// تُعلِم بانتهاء جلسة الجرد
  Future<void> markAuditSubmitted() async {
    if (_firebaseUser == null) return;
    await _db.collection('users').doc(_firebaseUser!.uid).update({
      'applicationStatus': 'audit_submitted',
      'auditSubmittedAt': FieldValue.serverTimestamp(),
    });
    _user = _user?.copyWith(applicationStatus: 'audit_submitted');
    notifyListeners();
  }

  /// تحميل بيانات المستخدم من Firestore وتحديث الحالة المحلية
  Future<void> refreshUserData() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) return;
    try {
      final doc = await _db.collection('users').doc(fbUser.uid).get();
      if (doc.exists) {
        _user = AppUser.fromFirestore(fbUser, doc.data()!);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AuthProvider] refreshUserData خطأ: $e');
    }
  }

  Future<void> signOut() async {
    _biometricVerified = false;
    await _googleSignIn.signOut();
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  void updateLocalUser(Map<String, dynamic> updates) {
    if (_user == null) return;
    _user = _user!.copyWith(
      applicationStatus: updates['applicationStatus'] ?? _user!.applicationStatus,
    );
    notifyListeners();
  }
}
