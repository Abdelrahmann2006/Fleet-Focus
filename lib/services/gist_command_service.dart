import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// GistCommandService — بروتوكول النبضة الميتة (Dead Pulse Protocol)
///
/// عندما ينقطع اتصال Firebase بالكامل، يُحقق التطبيق من GitHub Gist عام
/// كل 15 دقيقة للبحث عن أوامر طوارئ من القائد.
///
/// التدفق:
///   Firebase متاح  → يُكمل التطبيق عمله الاعتيادي
///   Firebase غير متاح → GistCommandService يتولى القيادة
///     1. جلب Gist JSON: { "cmd": "lockScreen", "ts": 1234567890, "target": "all" }
///     2. التحقق من الطابع الزمني (لا تنفيذ أوامر أقدم من 24 ساعة)
///     3. تنفيذ الأمر محلياً عبر Callback
///
/// الإعداد:
///   • أنشئ GitHub Gist خاصاً (Secret)
///   • ضع رابط raw في configure(rawGistUrl: '...')
///   • القائد يُحدّث الـ Gist يدوياً أو عبر GitHub API
///
/// مثال محتوى Gist:
/// ```json
/// {
///   "cmd": "lockScreen",
///   "target": "all",
///   "ts": 1703123456789,
///   "payload": { "message": "انتظر التعليمات" }
/// }
/// ```
class GistCommandService {
  static final GistCommandService _i = GistCommandService._();
  factory GistCommandService() => _i;
  GistCommandService._();

  static const String _prefKey         = 'gist_last_cmd_ts';
  static const Duration _checkInterval = Duration(minutes: 15);
  static const Duration _httpTimeout   = Duration(seconds: 10);
  static const Duration _maxCmdAge     = Duration(hours: 24);

  String _rawGistUrl = '';
  bool   _running    = false;
  Timer? _timer;

  // Callback يُستدعى عند العثور على أمر جديد
  void Function(GistCommand)? onCommand;

  void configure({
    required String rawGistUrl,
    void Function(GistCommand)? onCommand,
  }) {
    _rawGistUrl = rawGistUrl;
    this.onCommand = onCommand;
  }

  // ── Start / Stop ──────────────────────────────────────────────

  void start() {
    if (_rawGistUrl.isEmpty || _running) return;
    _running = true;
    _checkNow(); // فحص فوري عند الإقلاع
    _timer = Timer.periodic(_checkInterval, (_) => _checkNow());
    debugPrint('[GistCmd] Dead Pulse Protocol active — checking every 15m');
  }

  void stop() {
    _running = false;
    _timer?.cancel();
  }

  /// فحص يدوي فوري (يُستدعى عند اكتشاف انقطاع Firebase)
  Future<void> checkNow() => _checkNow();

  // ── Internal ──────────────────────────────────────────────────

  Future<void> _checkNow() async {
    if (_rawGistUrl.isEmpty) return;
    try {
      final resp = await http
          .get(
            Uri.parse(_rawGistUrl),
            headers: {
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
            },
          )
          .timeout(_httpTimeout);

      if (resp.statusCode != 200) {
        debugPrint('[GistCmd] HTTP ${resp.statusCode}');
        return;
      }

      final body = jsonDecode(resp.body);
      if (body is! Map<String, dynamic>) return;

      final cmd = GistCommand.fromJson(body);
      if (!_isValid(cmd)) {
        debugPrint('[GistCmd] Command invalid or already executed: ${cmd.cmd}');
        return;
      }

      await _markExecuted(cmd.ts);
      debugPrint('[GistCmd] ✓ Executing: ${cmd.cmd}');
      onCommand?.call(cmd);
    } on TimeoutException {
      debugPrint('[GistCmd] Timeout — Gist unreachable');
    } on SocketException catch (e) {
      debugPrint('[GistCmd] Network error: ${e.message}');
    } catch (e) {
      debugPrint('[GistCmd] Error: $e');
    }
  }

  bool _isValid(GistCommand cmd) {
    // تحقق: الأمر ليس قديماً أكثر من 24 ساعة
    final age = DateTime.now().millisecondsSinceEpoch - cmd.ts;
    if (age > _maxCmdAge.inMilliseconds) return false;

    // تحقق: لم يُنفَّذ سابقاً (نفس الطابع الزمني)
    // يُراجَع في _markExecuted
    return true;
  }

  Future<bool> _hasBeenExecuted(int ts) async {
    final prefs   = await SharedPreferences.getInstance();
    final lastTs  = prefs.getInt(_prefKey) ?? 0;
    return ts <= lastTs;
  }

  Future<void> _markExecuted(int ts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, ts);
  }
}

// ── Data Model ────────────────────────────────────────────────

class GistCommand {
  final String cmd;
  final String target;    // 'all' | uid
  final int    ts;
  final Map<String, dynamic>? payload;

  const GistCommand({
    required this.cmd,
    required this.target,
    required this.ts,
    this.payload,
  });

  factory GistCommand.fromJson(Map<String, dynamic> j) => GistCommand(
    cmd:     j['cmd']    as String? ?? '',
    target:  j['target'] as String? ?? 'all',
    ts:      j['ts']     is int ? j['ts'] as int : 0,
    payload: j['payload'] as Map<String, dynamic>?,
  );

  @override
  String toString() => 'GistCommand($cmd → $target @ ${DateTime.fromMillisecondsSinceEpoch(ts)})';
}
