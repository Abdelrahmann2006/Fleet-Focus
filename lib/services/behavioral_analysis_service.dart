import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

/// BehavioralAnalysisService — محرك التحليل السلوكي (v2 + Keyboard Dynamics)
///
/// يحسب مؤشرات الذكاء الاصطناعي في الوقت الحقيقي:
///
///  1. مؤشر الضغط النفسي (Stress Index 0-100)
///  2. احتمالية الخداع (Deception Probability 0-100)
///  3. النبرة العاطفية (CALM / NEUTRAL / STRESSED / AGITATED)
///  4. ديناميكيات لوحة المفاتيح (ghost % / velocity WPM / pattern)
///  5. درع الحواس (Sensory Shield: محتوى مُصفَّى)
///
/// النتائج مُكتَبة في:
///  RTDB: device_states/{uid}/behavioralAnalysis
///  RTDB: device_states/{uid}/keyboardDynamics
class BehavioralAnalysisService {
  BehavioralAnalysisService._();
  static final instance = BehavioralAnalysisService._();

  static const _rtdb = 'device_states';

  StreamSubscription? _backspaceSub;
  StreamSubscription? _audioSub;
  StreamSubscription? _dlpSub;
  StreamSubscription? _kbSub;
  Timer?              _ticker;

  // ── الحالة المحسوبة ──────────────────────────────────────────────────────

  int    _backspaceCount  = 0;
  String _audioClass      = 'QUIET';
  double _audioDb         = 0;
  int    _dlpAlerts       = 0;
  int    _smsFlagged      = 0;

  // ديناميكيات لوحة المفاتيح
  int    _ghostInputCount  = 0;
  int    _totalKeystrokes  = 0;
  int    _keystrokeWindow  = 0;   // keystrokes in last window
  final  List<int> _kbTimestamps = []; // timestamps in ms

  // ── تشغيل المحرك لجهاز محدد ──────────────────────────────────────────────

  void start(String uid) {
    stop();
    final db = FirebaseDatabase.instance;
    final fs = FirebaseFirestore.instance;

    // 1. استمع لعدد الحذف (Backspace) من RTDB
    _backspaceSub = db
        .ref('$_rtdb/$uid/backspaceCount')
        .onValue
        .listen((evt) {
      _backspaceCount = (evt.snapshot.value as int?) ?? 0;
    });

    // 2. استمع لتصنيف الصوت المحيطي من RTDB
    _audioSub = db
        .ref('$_rtdb/$uid/ambientAudio')
        .onValue
        .listen((evt) {
      final d = (evt.snapshot.value as Map?)?.cast<String, dynamic>() ?? {};
      _audioClass = d['classification'] as String? ?? 'QUIET';
      _audioDb    = (d['dbLevel'] as num?)?.toDouble() ?? 0.0;
    });

    // 3. استمع لتنبيهات DLP من Firestore
    _dlpSub = fs
        .collection('compliance_assets')
        .doc(uid)
        .collection('notification_alerts')
        .where('severity', whereIn: ['critical', 'high'])
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen((snap) => _dlpAlerts = snap.docs.length);

    // 4. استمع لأحداث لوحة المفاتيح الخام من RTDB (keylog)
    _kbSub = db
        .ref('$_rtdb/$uid/keylogRaw')
        .onValue
        .listen((evt) {
      final d = (evt.snapshot.value as Map?)?.cast<String, dynamic>() ?? {};
      _ghostInputCount = (d['ghostCount']    as num?)?.toInt() ?? 0;
      _totalKeystrokes = (d['totalCount']    as num?)?.toInt() ?? 0;
      _keystrokeWindow = (d['windowCount']   as num?)?.toInt() ?? 0;

      final rawTs = d['recentTimestamps'];
      if (rawTs is List) {
        _kbTimestamps
          ..clear()
          ..addAll(rawTs.cast<int>());
      }
    });

    // نافذة تحليل كل 30 ثانية
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      _computeAndPublish(uid);
    });

    // حساب أولي فوري
    Future.delayed(const Duration(seconds: 3), () => _computeAndPublish(uid));
  }

  // ── إيقاف ────────────────────────────────────────────────────────────────

  void stop() {
    _backspaceSub?.cancel();
    _audioSub?.cancel();
    _dlpSub?.cancel();
    _kbSub?.cancel();
    _ticker?.cancel();
  }

  // ── الخوارزمية المحلية ────────────────────────────────────────────────────

  void _computeAndPublish(String uid) {
    final result = _computeLocally();

    FirebaseDatabase.instance
        .ref('$_rtdb/$uid/behavioralAnalysis')
        .set({
      'stressIndex':          result.stressIndex,
      'deceptionProbability': result.deceptionProbability,
      'emotionalTone':        result.emotionalTone,
      'stressLevel':          result.stressLevel,
      'alertFlags':           result.alertFlags,
      'computedAt':           ServerValue.timestamp,
      'engineVersion':        '2.0-kb-dynamics',
    });

    // كتابة ديناميكيات لوحة المفاتيح مستقلة
    FirebaseDatabase.instance
        .ref('$_rtdb/$uid/keyboardDynamics')
        .set({
      'ghostPercent':   result.ghostPercent,
      'velocityWpm':    result.velocityWpm,
      'backspaceCount': _backspaceCount,
      'dlpAlerts':      _dlpAlerts,
      'pattern':        result.keyboardPattern,
      'updatedAt':      ServerValue.timestamp,
    });
  }

  BehavioralResult _computeLocally() {
    // ── Stress Index ─────────────────────────────────────────────────────────
    final backspaceScore = (_backspaceCount.clamp(0, 200) / 200 * 50).round();
    final audioScore     = _audioClassToScore(_audioClass);
    final stressIndex    = (backspaceScore + audioScore).clamp(0, 100);

    // ── Deception Probability ────────────────────────────────────────────────
    final deceptionProb  = (_dlpAlerts * 8 + _smsFlagged * 12).clamp(0, 100);

    // ── Emotional Tone ────────────────────────────────────────────────────────
    final emotionalTone  = _deriveEmotionalTone(stressIndex, _audioClass, _audioDb);

    // ── Stress Level Label ───────────────────────────────────────────────────
    final stressLevel    = stressIndex < 25 ? 'LOW'
        : stressIndex < 50 ? 'MODERATE'
        : stressIndex < 75 ? 'HIGH'
        : 'CRITICAL';

    // ── Alert Flags ─────────────────────────────────────────────────────────
    final flags = <String>[];
    if (stressIndex >= 75)       flags.add('HIGH_STRESS');
    if (deceptionProb >= 50)     flags.add('DECEPTION_RISK');
    if (_dlpAlerts >= 3)         flags.add('DLP_FLOOD');
    if (_audioClass == 'VERY_LOUD') flags.add('AUDIO_ALERT');

    // ── Keyboard Dynamics ────────────────────────────────────────────────────
    final ghostPercent = _totalKeystrokes == 0
        ? 0
        : ((_ghostInputCount / _totalKeystrokes) * 100).round().clamp(0, 100);

    final velocityWpm = _computeVelocityWpm();

    final keyboardPattern = _deriveKeyboardPattern(
        ghostPercent, velocityWpm, _backspaceCount);

    if (ghostPercent > 40) flags.add('HIGH_GHOST_INPUT');
    if (velocityWpm > 80)  flags.add('RAPID_TYPING');

    return BehavioralResult(
      stressIndex:          stressIndex,
      deceptionProbability: deceptionProb,
      emotionalTone:        emotionalTone,
      stressLevel:          stressLevel,
      alertFlags:           flags,
      ghostPercent:         ghostPercent,
      velocityWpm:          velocityWpm,
      keyboardPattern:      keyboardPattern,
    );
  }

  int _computeVelocityWpm() {
    if (_kbTimestamps.length < 2) {
      // احتياطي: استخدم keystrokeWindow / نافذة 30 ثانية
      return (_keystrokeWindow / 5).round(); // تقدير تقريبي: 5 ضربات/كلمة
    }
    final sorted = List<int>.from(_kbTimestamps)..sort();
    final spanMs = sorted.last - sorted.first;
    if (spanMs <= 0) return 0;
    final spanMin = spanMs / 60000.0;
    final wordsEst = sorted.length / 5.0; // كل 5 ضربات = كلمة واحدة تقريباً
    return (wordsEst / spanMin).round().clamp(0, 200);
  }

  String _deriveKeyboardPattern(int ghost, int wpm, int backspace) {
    if (ghost > 40 || backspace > 30 || wpm > 90) return 'AGITATED';
    if (ghost > 20 || backspace > 15 || wpm < 15)  return 'HESITANT';
    return 'CALM';
  }

  int _audioClassToScore(String cls) {
    switch (cls) {
      case 'VERY_LOUD': return 50;
      case 'LOUD':      return 35;
      case 'MODERATE':  return 15;
      case 'QUIET':
      default:          return 0;
    }
  }

  String _deriveEmotionalTone(int stress, String audioClass, double db) {
    if (stress >= 75 || audioClass == 'VERY_LOUD') return 'AGITATED';
    if (stress >= 50 || audioClass == 'LOUD')       return 'STRESSED';
    if (stress >= 25 || db > 55)                    return 'NEUTRAL';
    return 'CALM';
  }
}

// ── نموذج النتيجة ────────────────────────────────────────────────────────────

class BehavioralResult {
  final int    stressIndex;
  final int    deceptionProbability;
  final String emotionalTone;
  final String stressLevel;
  final List<String> alertFlags;
  // Keyboard dynamics
  final int    ghostPercent;
  final int    velocityWpm;
  final String keyboardPattern;

  const BehavioralResult({
    required this.stressIndex,
    required this.deceptionProbability,
    required this.emotionalTone,
    required this.stressLevel,
    required this.alertFlags,
    this.ghostPercent    = 0,
    this.velocityWpm     = 0,
    this.keyboardPattern = 'CALM',
  });
}
