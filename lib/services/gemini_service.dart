import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

/// GeminiService — بوابة الذكاء الاصطناعي (Gemini 1.5 Flash)
///
/// المفتاح مُخزَّن في Firestore: config/ai_settings → geminiApiKey
/// يُحمَّل مرة واحدة ويُخزَّن في الذاكرة المؤقتة.
///
/// 4 عمليات رئيسية:
///  • analyzeScene()      — وصف المشهد البصري (Gemini Vision)
///  • analyzeSentiment()  — تحليل المشاعر من نص
///  • analyzeKeyboard()   — تفسير ديناميكيات لوحة المفاتيح
///  • naturalQuery()      — الاستعلام باللغة الطبيعية
class GeminiService {
  GeminiService._();
  static final instance = GeminiService._();

  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent';

  static const _fallbackKey = 'AIzaSyDm3hOSyBdKb7tZqE0_q66S9Bk-BHn1XsM';

  String? _apiKey;
  bool _loading = false;

  // ── تحميل المفتاح ──────────────────────────────────────────────────────────

  Future<String?> _key() async {
    if (_apiKey != null) return _apiKey;
    if (_loading) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _apiKey ?? _fallbackKey;
    }
    _loading = true;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('ai_settings')
          .get();
      _apiKey = doc.data()?['geminiApiKey'] as String?;
    } catch (_) {
      _apiKey = null;
    }
    _loading = false;
    return _apiKey ?? _fallbackKey;
  }

  void clearKey() => _apiKey = null;

  // ── استدعاء Gemini الأساسي ─────────────────────────────────────────────────

  Future<String?> _call(List<Map<String, dynamic>> parts) async {
    final key = await _key();
    if (key == null || key.isEmpty) return null;
    try {
      final resp = await http
          .post(
            Uri.parse('$_baseUrl?key=$key'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {'parts': parts}
              ],
              'generationConfig': {
                'maxOutputTokens': 512,
                'temperature': 0.4,
              },
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return (json['candidates'] as List?)
          ?.firstOrNull
          ?['content']?['parts']
          ?.firstOrNull?['text'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── M1: تحليل المشهد البصري ────────────────────────────────────────────────

  /// يُحلِّل صورة Base64 ويعيد وصفاً موجزاً للمشهد بالعربية
  Future<SceneAnalysis> analyzeScene(Uint8List imageBytes) async {
    final b64 = base64Encode(imageBytes);
    final text = await _call([
      {
        'inline_data': {'mime_type': 'image/jpeg', 'data': b64}
      },
      {
        'text':
            'أنت نظام مراقبة. حلِّل هذه الصورة وأجب بالعربية في سطرين فقط: '
            '1) وصف موجز للمكان والأشخاص '
            '2) تقييم الامتثال: COMPLIANT أو VIOLATION مع السبب. '
            'مثال: "الهدف في غرفة مضاءة أمام كمبيوتر محمول. COMPLIANT: لا مخالفات."'
      },
    ]);
    if (text == null) return SceneAnalysis.empty();
    final isViolation = text.toUpperCase().contains('VIOLATION');
    return SceneAnalysis(
      description: text.trim(),
      isViolation: isViolation,
      timestamp: DateTime.now(),
    );
  }

  // ── M3: تحليل المشاعر من نص ────────────────────────────────────────────────

  /// يُحلِّل نصاً (كلام منقول) ويعيد تقرير المشاعر والكلمات الممنوعة
  Future<SentimentReport> analyzeSentiment(String transcript) async {
    if (transcript.trim().isEmpty) return SentimentReport.empty();
    final text = await _call([
      {
        'text':
            'أنت محلل مراقبة. حلِّل النص التالي وأجب بصيغة JSON فقط بدون أي نص إضافي:\n'
            '{"emotion":"CALM|STRESSED|AGITATED|FEARFUL","stress_level":0-100,'
            '"forbidden_keywords":["..."],"multi_speaker":true|false,'
            '"summary":"وصف موجز بالعربية"}\n\nالنص:\n$transcript'
      },
    ]);
    if (text == null) return SentimentReport.empty();
    try {
      final jsonStr =
          RegExp(r'\{.*\}', dotAll: true).firstMatch(text)?.group(0) ?? text;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return SentimentReport(
        emotion: map['emotion'] as String? ?? 'UNKNOWN',
        stressLevel: (map['stress_level'] as num?)?.toInt() ?? 0,
        forbiddenKeywords:
            (map['forbidden_keywords'] as List?)?.cast<String>() ?? [],
        multiSpeaker: map['multi_speaker'] as bool? ?? false,
        summary: map['summary'] as String? ?? text.trim(),
      );
    } catch (_) {
      return SentimentReport(
        emotion: 'UNKNOWN',
        stressLevel: 0,
        forbiddenKeywords: const [],
        multiSpeaker: false,
        summary: text.trim(),
      );
    }
  }

  // ── M1: تحليل ديناميكيات لوحة المفاتيح ────────────────────────────────────

  /// يفسِّر مؤشرات لوحة المفاتيح ويعيد نمطاً سلوكياً
  Future<KeyboardPattern> analyzeKeyboard({
    required int ghostPercent,
    required int velocityWpm,
    required int backspaceCount,
    required int dlpAlerts,
  }) async {
    final text = await _call([
      {
        'text':
            'حلِّل ديناميكيات كتابة المستخدم وأجب بـ JSON فقط:\n'
            '{"pattern":"CALM|HESITANT|AGITATED","confidence":0-100,'
            '"interpretation":"تفسير قصير بالعربية"}\n\n'
            'البيانات: ghost=$ghostPercent% velocity=$velocityWpm WPM '
            'backspace=$backspaceCount dlp_alerts=$dlpAlerts'
      },
    ]);
    if (text == null) {
      return KeyboardPattern(
        pattern: _localKeyboardPattern(ghostPercent, velocityWpm, backspaceCount),
        confidence: 60,
        interpretation: _localPatternLabel(ghostPercent, velocityWpm),
      );
    }
    try {
      final jsonStr =
          RegExp(r'\{.*\}', dotAll: true).firstMatch(text)?.group(0) ?? text;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return KeyboardPattern(
        pattern: map['pattern'] as String? ?? 'CALM',
        confidence: (map['confidence'] as num?)?.toInt() ?? 70,
        interpretation:
            map['interpretation'] as String? ?? text.trim(),
      );
    } catch (_) {
      return KeyboardPattern(
        pattern: _localKeyboardPattern(ghostPercent, velocityWpm, backspaceCount),
        confidence: 60,
        interpretation: _localPatternLabel(ghostPercent, velocityWpm),
      );
    }
  }

  static String _localKeyboardPattern(int ghost, int wpm, int backspace) {
    if (ghost > 40 || backspace > 30) return 'AGITATED';
    if (ghost > 20 || wpm < 20)       return 'HESITANT';
    return 'CALM';
  }

  static String _localPatternLabel(int ghost, int wpm) {
    if (ghost > 40) return 'حذف مفرط يُشير إلى توتر حاد';
    if (ghost > 20) return 'تردد ملحوظ في الكتابة';
    if (wpm < 20)   return 'سرعة منخفضة — إحجام أو تردد';
    return 'إيقاع طبيعي';
  }

  // ── M4: الاستعلام باللغة الطبيعية ─────────────────────────────────────────

  /// يُجيب على استفسار السيدة ويعيد نتيجة منظَّمة مع file_id إن وُجد
  Future<NlQueryResult> naturalQuery(
    String question,
    Map<String, dynamic> context,
  ) async {
    final ctxStr = context.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');
    final text = await _call([
      {
        'text':
            'أنت مساعد مراقبة ذكي. أجب على سؤال السيدة بـ JSON فقط:\n'
            '{"answer":"إجابة موجزة بالعربية","file_id":null|"id",'
            '"action":"none|play_audio|show_image|show_log",'
            '"confidence":0-100}\n\n'
            'السياق المتاح:\n$ctxStr\n\n'
            'السؤال: $question'
      },
    ]);
    if (text == null) {
      return NlQueryResult(
        answer: 'لا يمكن الاتصال بمحرك الذكاء حالياً',
        fileId: null,
        action: 'none',
        confidence: 0,
      );
    }
    try {
      final jsonStr =
          RegExp(r'\{.*\}', dotAll: true).firstMatch(text)?.group(0) ?? text;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return NlQueryResult(
        answer: map['answer'] as String? ?? text.trim(),
        fileId: map['file_id'] as String?,
        action: map['action'] as String? ?? 'none',
        confidence: (map['confidence'] as num?)?.toInt() ?? 70,
      );
    } catch (_) {
      return NlQueryResult(
        answer: text.trim(),
        fileId: null,
        action: 'none',
        confidence: 60,
      );
    }
  }
}

// ── نماذج البيانات ────────────────────────────────────────────────────────────

class SceneAnalysis {
  final String description;
  final bool isViolation;
  final DateTime timestamp;
  SceneAnalysis({
    required this.description,
    required this.isViolation,
    required this.timestamp,
  });
  factory SceneAnalysis.empty() => SceneAnalysis(
    description: '— لا توجد صورة للتحليل بعد —',
    isViolation: false,
    timestamp: DateTime.now(),
  );
}

class SentimentReport {
  final String emotion;
  final int stressLevel;
  final List<String> forbiddenKeywords;
  final bool multiSpeaker;
  final String summary;
  SentimentReport({
    required this.emotion,
    required this.stressLevel,
    required this.forbiddenKeywords,
    required this.multiSpeaker,
    required this.summary,
  });
  factory SentimentReport.empty() => SentimentReport(
    emotion: '—',
    stressLevel: 0,
    forbiddenKeywords: const [],
    multiSpeaker: false,
    summary: '— لا يوجد تسجيل لتحليله بعد —',
  );
}

class KeyboardPattern {
  final String pattern;
  final int confidence;
  final String interpretation;
  KeyboardPattern({
    required this.pattern,
    required this.confidence,
    required this.interpretation,
  });
}

class NlQueryResult {
  final String answer;
  final String? fileId;
  final String action;
  final int confidence;
  NlQueryResult({
    required this.answer,
    required this.fileId,
    required this.action,
    required this.confidence,
  });
}
