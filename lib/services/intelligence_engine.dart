import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'behavioral_analysis_service.dart';
import 'gemini_service.dart';
import 'noise_gate_service.dart';

/// IntelligenceEngine — المحرك المركزي للذكاء الاصطناعي
///
/// يجمع جميع مصادر التلمترة في تدفق واحد موحَّد:
///  • محرك التحليل السلوكي (keyboard + audio + DLP)
///  • بوابة Gemini (vision + sentiment + pattern)
///  • بوابة الضجيج (noise gate + diarization)
///
/// يُكتب الحالة الموحَّدة في RTDB: device_states/{uid}/intelligenceReport
/// ويُعيد حذف الصور المُعتمَدة تلقائياً (Auto-Purge).
class IntelligenceEngine {
  IntelligenceEngine._();
  static final instance = IntelligenceEngine._();

  String? _activeUid;
  StreamSubscription? _snapSub;
  StreamSubscription? _audioSub;
  final Map<String, KeyboardPattern> _kbPatternCache = {};
  bool _sensoryShieldEnabled = false;

  // ── تشغيل ────────────────────────────────────────────────────────────────

  void start(String uid) {
    if (_activeUid == uid) return;
    stop();
    _activeUid = uid;

    BehavioralAnalysisService.instance.start(uid);
    NoiseGateService.instance.start(uid);

    // راقب الصور الجديدة في Firestore (snap check-ins)
    _snapSub = FirebaseFirestore.instance
        .collection('compliance_assets')
        .doc(uid)
        .collection('snap_checkins')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) async {
      if (snap.docs.isEmpty) return;
      final doc  = snap.docs.first;
      final data = doc.data();
      final url  = data['imageUrl'] as String?;
      final analysed = data['geminiAnalysed'] as bool? ?? false;
      if (url == null || analysed) return;
      await _analyseSnapCheckIn(uid, doc.id, url);
    });

    // راقب تغيّرات ديناميكيات لوحة المفاتيح في RTDB
    _audioSub = FirebaseDatabase.instance
        .ref('device_states/$uid/keyboardDynamics')
        .onValue
        .listen((evt) async {
      final d = (evt.snapshot.value as Map?)?.cast<String, dynamic>() ?? {};
      final ghost   = (d['ghostPercent']  as num?)?.toInt() ?? 0;
      final wpm     = (d['velocityWpm']   as num?)?.toInt() ?? 0;
      final backsp  = (d['backspaceCount']as num?)?.toInt() ?? 0;
      final dlp     = (d['dlpAlerts']     as num?)?.toInt() ?? 0;

      final pattern = await GeminiService.instance.analyzeKeyboard(
        ghostPercent:   ghost,
        velocityWpm:    wpm,
        backspaceCount: backsp,
        dlpAlerts:      dlp,
      );
      _kbPatternCache[uid] = pattern;
      FirebaseDatabase.instance.ref('device_states/$uid/keyboardPattern').set({
        'pattern':        pattern.pattern,
        'confidence':     pattern.confidence,
        'interpretation': pattern.interpretation,
        'updatedAt':      ServerValue.timestamp,
      });
    });
  }

  // ── إيقاف ────────────────────────────────────────────────────────────────

  void stop() {
    _snapSub?.cancel();
    _audioSub?.cancel();
    BehavioralAnalysisService.instance.stop();
    NoiseGateService.instance.stop();
    _activeUid = null;
  }

  // ── درع الحواس ───────────────────────────────────────────────────────────

  bool get sensoryShieldEnabled => _sensoryShieldEnabled;

  void toggleSensoryShield(bool enabled) {
    _sensoryShieldEnabled = enabled;
    if (_activeUid == null) return;
    FirebaseDatabase.instance
        .ref('device_states/$_activeUid/sensoryShield')
        .set({'enabled': enabled, 'setAt': ServerValue.timestamp});
  }

  // ── تحليل Snap Check-in ───────────────────────────────────────────────────

  Future<void> _analyseSnapCheckIn(
      String uid, String docId, String url) async {
    try {
      final bytes = await _downloadBytes(url);
      if (bytes == null) return;

      final analysis = await GeminiService.instance.analyzeScene(bytes);

      // اكتب النتيجة في Firestore
      await FirebaseFirestore.instance
          .collection('compliance_assets')
          .doc(uid)
          .collection('snap_checkins')
          .doc(docId)
          .update({
        'geminiAnalysed':    true,
        'sceneDescription':  analysis.description,
        'isViolation':       analysis.isViolation,
        'analysedAt':        FieldValue.serverTimestamp(),
      });

      // اكتب آخر تحليل بصري في RTDB للعرض الفوري
      FirebaseDatabase.instance
          .ref('device_states/$uid/lastSceneAnalysis')
          .set({
        'description': analysis.description,
        'isViolation': analysis.isViolation,
        'docId':       docId,
        'timestamp':   ServerValue.timestamp,
      });

      // Auto-Purge: احذف الصورة الأصلية من Storage بعد التحليل الناجح
      if (!analysis.isViolation) {
        _autoPurge(url);
      }
    } catch (_) {}
  }

  Future<void> _autoPurge(String url) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();
    } catch (_) {}
  }

  Future<Uint8List?> _downloadBytes(String url) async {
    try {
      final ref  = FirebaseStorage.instance.refFromURL(url);
      return await ref.getData(2 * 1024 * 1024); // 2 MB max
    } catch (_) {
      return null;
    }
  }

  // ── الاستعلام باللغة الطبيعية ─────────────────────────────────────────────

  Future<NlQueryResult> query(String uid, String question) async {
    // اجمع السياق المتاح من RTDB
    final snap = await FirebaseDatabase.instance
        .ref('device_states/$uid')
        .get();
    final ctx = (snap.value as Map?)?.cast<String, dynamic>() ?? {};

    // أضف معلومات ملخّصة
    final summary = <String, dynamic>{
      'uid':             uid,
      'behavioralState': ctx['behavioralAnalysis'] ?? {},
      'keyboardPattern': ctx['keyboardPattern']    ?? {},
      'noiseGate':       ctx['noiseGateAnalysis']  ?? {},
      'lastScene':       ctx['lastSceneAnalysis']  ?? {},
      'sensoryShield':   ctx['sensoryShield']      ?? {},
    };

    return GeminiService.instance.naturalQuery(question, summary);
  }
}
