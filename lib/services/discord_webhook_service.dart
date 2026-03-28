import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

/// DiscordWebhookService — طبقة تنبيهات Discord
///
/// يُرسل تنبيهات المستوى الأول (Mutiny / Escape / Critical) إلى Discord.
/// رابط الـ Webhook مُخزَّن في Firestore: config/discord_settings → webhookUrl
class DiscordWebhookService {
  DiscordWebhookService._();
  static final instance = DiscordWebhookService._();

  String? _webhookUrl;

  Future<String?> _getUrl() async {
    if (_webhookUrl != null) return _webhookUrl;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('discord_settings')
          .get();
      _webhookUrl = doc.data()?['webhookUrl'] as String?;
    } catch (_) {}
    return _webhookUrl;
  }

  void clearCache() => _webhookUrl = null;

  // ── إرسال تنبيه ──────────────────────────────────────────────────────────

  Future<bool> sendAlert({
    required String level,        // L1 / L2 / L3
    required String eventType,    // MUTINY / ESCAPE / REBELLION / CRITICAL
    required String assetUid,
    required String assetName,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    final url = await _getUrl();
    if (url == null || url.isEmpty) return false;

    final color = switch (level) {
      'L1' => 0xE53E3E,  // Red
      'L2' => 0xDD6B20,  // Orange
      _    => 0x3182CE,  // Blue
    };

    final fields = <Map<String, dynamic>>[
      {'name': 'العنصر', 'value': assetName, 'inline': true},
      {'name': 'UID', 'value': '`$assetUid`', 'inline': true},
      {'name': 'نوع الحدث', 'value': eventType, 'inline': true},
    ];

    if (metadata != null) {
      fields.addAll(metadata.entries.map((e) => {
        'name': e.key,
        'value': '${e.value}',
        'inline': false,
      }));
    }

    final body = jsonEncode({
      'embeds': [
        {
          'title':       '🚨 تنبيه المستوى $level: $eventType',
          'description': description ?? 'حدث نظام طارئ يستوجب تدخل السيدة فوراً.',
          'color':       color,
          'fields':      fields,
          'footer':      {'text': 'Panopticon — نظام المراقبة'},
          'timestamp':   DateTime.now().toUtc().toIso8601String(),
        }
      ]
    });

    try {
      final resp = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 8));
      return resp.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  // ── تنبيهات مُختصَرة ─────────────────────────────────────────────────────

  Future<void> alertMutiny(String uid, String name) =>
      sendAlert(level: 'L1', eventType: 'MUTINY', assetUid: uid, assetName: name,
                description: 'اكتشاف محاولة تمرد — تدخل فوري مطلوب.');

  Future<void> alertEscape(String uid, String name, Map<String, double> gps) =>
      sendAlert(level: 'L1', eventType: 'ESCAPE', assetUid: uid, assetName: name,
                description: 'خروج عن النطاق الجغرافي المسموح.',
                metadata: {'lat': gps['lat'], 'lng': gps['lng']});

  Future<void> alertRebellion(String uid, String name, String detail) =>
      sendAlert(level: 'L2', eventType: 'REBELLION', assetUid: uid, assetName: name,
                description: detail);

  Future<void> alertPoT(String uid, String name, int windowSec) =>
      sendAlert(level: 'L2', eventType: 'TASK_FALSIFICATION', assetUid: uid, assetName: name,
                description: 'مشتبه بتزوير مهام: ${windowSec}ث لـ 3 مهام متتالية');
}
