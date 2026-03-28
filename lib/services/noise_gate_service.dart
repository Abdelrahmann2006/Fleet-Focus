import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

import 'gemini_service.dart';

/// NoiseGateService — بوابة الضجيج وتحليل الكلام المحيطي
///
/// يراقب مستوى الديسيبل من RTDB:  device_states/{uid}/ambientAudio/dbLevel
/// إذا تجاوز العتبة (≥ _thresholdDb) → يقرأ النص المُنقَّل من STT
/// ويُرسله إلى Gemini للتحليل العاطفي وكشف الكلمات الممنوعة.
///
/// النتائج مُكتَبة في: device_states/{uid}/noiseGateAnalysis
class NoiseGateService {
  NoiseGateService._();
  static final instance = NoiseGateService._();

  static const _thresholdDb   = 65.0;   // dB — عتبة الصوت المحادثاتي
  static const _cooldownSec   = 45;     // ثانية — فترة هدوء بين التحليلَين

  StreamSubscription? _audioSub;
  StreamSubscription? _sttSub;
  DateTime?           _lastAnalysis;
  bool                _analysing = false;
  String              _lastTranscript = '';

  // ── تشغيل ────────────────────────────────────────────────────────────────

  void start(String uid) {
    stop();
    final db = FirebaseDatabase.instance;

    // استمع لمستوى الصوت
    _audioSub = db
        .ref('device_states/$uid/ambientAudio')
        .onValue
        .listen((evt) async {
      final d = (evt.snapshot.value as Map?)?.cast<String, dynamic>() ?? {};
      final db_ = (d['dbLevel'] as num?)?.toDouble() ?? 0.0;
      _onDbLevel(uid, db_);
    });

    // استمع للنص المُنقَّل (STT) من الجهاز
    _sttSub = db
        .ref('device_states/$uid/sttTranscript')
        .onValue
        .listen((evt) {
      _lastTranscript = evt.snapshot.value as String? ?? '';
    });
  }

  // ── إيقاف ────────────────────────────────────────────────────────────────

  void stop() {
    _audioSub?.cancel();
    _sttSub?.cancel();
    _lastAnalysis = null;
    _analysing    = false;
  }

  // ── منطق العتبة ──────────────────────────────────────────────────────────

  void _onDbLevel(String uid, double db) async {
    if (db < _thresholdDb) return;
    if (_analysing) return;
    final now = DateTime.now();
    if (_lastAnalysis != null &&
        now.difference(_lastAnalysis!).inSeconds < _cooldownSec) return;
    _analysing    = true;
    _lastAnalysis = now;

    await _triggerAnalysis(uid);
    _analysing = false;
  }

  Future<void> _triggerAnalysis(String uid) async {
    if (_lastTranscript.isEmpty) {
      _writeStatus(uid, 'GATE_OPEN', _lastTranscript, null, false);
      return;
    }

    final report = await GeminiService.instance.analyzeSentiment(_lastTranscript);

    _writeStatus(
      uid,
      _emotionToGateStatus(report.emotion, report.stressLevel),
      _lastTranscript,
      report,
      true,
    );
  }

  String _emotionToGateStatus(String emotion, int stress) {
    if (emotion == 'AGITATED' || stress > 75) return 'ALERT';
    if (emotion == 'STRESSED' || stress > 50) return 'ELEVATED';
    if (emotion == 'FEARFUL')                 return 'ALERT';
    return 'NORMAL';
  }

  void _writeStatus(
    String uid,
    String gateStatus,
    String transcript,
    SentimentReport? report,
    bool analysed,
  ) {
    FirebaseDatabase.instance
        .ref('device_states/$uid/noiseGateAnalysis')
        .set({
      'gateStatus':        gateStatus,
      'transcript':        transcript,
      'analysed':          analysed,
      'emotion':           report?.emotion ?? '—',
      'stressLevel':       report?.stressLevel ?? 0,
      'multiSpeaker':      report?.multiSpeaker ?? false,
      'forbiddenKeywords': report?.forbiddenKeywords ?? [],
      'summary':           report?.summary ?? '',
      'updatedAt':         ServerValue.timestamp,
    });
  }
}
