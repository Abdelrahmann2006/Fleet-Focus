import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/colors.dart';
import '../../services/dead_mans_switch_service.dart';
import '../../services/discord_webhook_service.dart';

/// Tab 33 — البنية التحتية الصامدة
///
/// • المفتاح الميت (Dead Man's Switch)
/// • Discord Webhook (تنبيهات المستوى الأول)
/// • إعداد Persona Engine
/// • سجل الأحداث البنيوية
class DpcInfrastructureTab extends StatefulWidget {
  final String leaderUid;
  const DpcInfrastructureTab({super.key, required this.leaderUid});

  @override
  State<DpcInfrastructureTab> createState() => _DpcInfrastructureTabState();
}

class _DpcInfrastructureTabState extends State<DpcInfrastructureTab> {
  final _webhookCtrl  = TextEditingController();
  final _msgCtrl      = TextEditingController();
  DeadManStatus?      _deadStatus;
  bool _loadingDead   = false;
  bool _savingWebhook = false;
  bool _savingPersona = false;
  String _defaultAction = 'lock_screen';

  @override
  void initState() {
    super.initState();
    DeadMansSwitchService.instance.start(widget.leaderUid);
    _loadDeadStatus();
    _loadSettings();
  }

  @override
  void dispose() {
    _webhookCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDeadStatus() async {
    setState(() => _loadingDead = true);
    final status = await DeadMansSwitchService.instance.getStatus();
    if (mounted) setState(() { _deadStatus = status; _loadingDead = false; });
  }

  Future<void> _loadSettings() async {
    try {
      final docs = await Future.wait([
        FirebaseFirestore.instance.collection('config').doc('discord_settings').get(),
        FirebaseFirestore.instance.collection('config').doc('persona_engine').get(),
      ]);
      final discord = docs[0].data() ?? {};
      final persona = docs[1].data() ?? {};
      if (mounted) {
        setState(() {
          _webhookCtrl.text = discord['webhookUrl'] as String? ?? '';
          _msgCtrl.text = persona['inactivityMessage'] as String? ?? '';
          _defaultAction = persona['defaultAction'] as String? ?? 'lock_screen';
        });
      }
    } catch (_) {}
  }

  Future<void> _saveWebhook() async {
    setState(() => _savingWebhook = true);
    await FirebaseFirestore.instance.collection('config').doc('discord_settings').set({
      'webhookUrl': _webhookCtrl.text.trim(),
      'updatedAt':  FieldValue.serverTimestamp(),
    });
    DiscordWebhookService.instance.clearCache();
    if (mounted) {
      setState(() => _savingWebhook = false);
      _snack('✓ Webhook محفوظ');
    }
  }

  Future<void> _testWebhook() async {
    final ok = await DiscordWebhookService.instance.sendAlert(
      level: 'L3', eventType: 'TEST',
      assetUid: 'test', assetName: 'اختبار',
      description: 'رسالة اختبار من Panopticon.',
    );
    if (mounted) _snack(ok ? '✓ رسالة اختبار أُرسلت' : '✗ فشل الإرسال');
  }

  Future<void> _savePersona() async {
    setState(() => _savingPersona = true);
    await DeadMansSwitchService.instance.savePersona(
      defaultAction:     _defaultAction,
      inactivityMessage: _msgCtrl.text.trim(),
    );
    if (mounted) { setState(() => _savingPersona = false); _snack('✓ Persona محفوظ'); }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Tajawal')),
        backgroundColor: AppColors.success),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [

        // ── المفتاح الميت ───────────────────────────────────────────────
        _InfraHdr(label: 'المفتاح الميت (Dead Man\'s Switch)', icon: Icons.timer_off_outlined),
        const SizedBox(height: 8),
        _DeadManCard(
          loading: _loadingDead,
          status: _deadStatus,
          onRefresh: _loadDeadStatus,
          onHeartbeat: () { DeadMansSwitchService.instance.heartbeat(); _snack('✓ نشاط مُسجَّل'); },
        ),
        const SizedBox(height: 20),

        // ── Persona Engine ──────────────────────────────────────────────
        _InfraHdr(label: 'محرك الشخصية (Persona Engine)', icon: Icons.smart_toy_outlined),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            DropdownButtonFormField<String>(
              value: _defaultAction,
              decoration: const InputDecoration(
                labelText: 'الإجراء الافتراضي',
                labelStyle: TextStyle(fontFamily: 'Tajawal', color: AppColors.textMuted),
                isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              dropdownColor: AppColors.backgroundCard,
              style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text, fontSize: 12),
              items: const [
                DropdownMenuItem(value: 'lock_screen',    child: Text('قفل الشاشة')),
                DropdownMenuItem(value: 'play_alarm',     child: Text('تشغيل منبه')),
                DropdownMenuItem(value: 'zero_hour_lockdown', child: Text('قفل ساعة الصفر')),
                DropdownMenuItem(value: 'digital_void',   child: Text('الفراغ الرقمي')),
              ],
              onChanged: (v) { if (v != null) setState(() => _defaultAction = v); },
            ),
            const SizedBox(height: 8),
            TextField(controller: _msgCtrl, textAlign: TextAlign.right, textDirection: ui.TextDirection.rtl,
              maxLines: 2,
              style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 12),
              decoration: const InputDecoration(hintText: 'رسالة عدم النشاط',
                hintStyle: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11),
                isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8))),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: _savingPersona ? null : _savePersona,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent, foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 10), elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('حفظ Persona', style: TextStyle(fontFamily: 'Tajawal')),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // ── Discord Webhook ─────────────────────────────────────────────
        _InfraHdr(label: 'Discord Webhook (تنبيهات L1)', icon: Icons.webhook_outlined),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF5865F2).withValues(alpha: 0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            TextField(controller: _webhookCtrl,
              style: const TextStyle(color: AppColors.text, fontFamily: 'Courier', fontSize: 11),
              decoration: InputDecoration(
                hintText: 'https://discord.com/api/webhooks/…',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontFamily: 'Courier', fontSize: 10),
                filled: true, fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              )),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _testWebhook,
                icon: const Icon(Icons.send_outlined, size: 14),
                label: const Text('اختبار', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5865F2),
                  side: const BorderSide(color: Color(0xFF5865F2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton.icon(
                onPressed: _savingWebhook ? null : _saveWebhook,
                icon: const Icon(Icons.save_outlined, size: 14),
                label: const Text('حفظ', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5865F2), foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )),
            ]),
          ]),
        ),
        const SizedBox(height: 20),

        // ── سجل أحداث البنية ────────────────────────────────────────────
        _InfraHdr(label: 'سجل الأحداث البنيوية', icon: Icons.history_outlined),
        const SizedBox(height: 8),
        _InfraEventsLog(leaderUid: widget.leaderUid),
      ]),
    );
  }
}

class _DeadManCard extends StatelessWidget {
  final bool loading;
  final DeadManStatus? status;
  final VoidCallback onRefresh, onHeartbeat;
  const _DeadManCard({required this.loading, required this.status,
      required this.onRefresh, required this.onHeartbeat});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2));
    }
    final s = status;
    final triggered = s?.isTriggered ?? false;
    final hours     = s?.inactiveHours ?? 0;
    final lastSeen  = s?.lastSeen;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: triggered ? AppColors.error.withValues(alpha: 0.08) : AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: triggered
            ? AppColors.error.withValues(alpha: 0.4) : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(children: [
          GestureDetector(
            onTap: onRefresh,
            child: const Icon(Icons.refresh, color: AppColors.textMuted, size: 18)),
          const Spacer(),
          Text(triggered ? '⚠ مُفعَّل' : 'خامل', style: TextStyle(
              color: triggered ? AppColors.error : AppColors.success,
              fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(width: 8),
          const Text('حالة المفتاح الميت', style: TextStyle(
              color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        Text('$hours ساعة من آخر نشاط مُسجَّل',
            textAlign: TextAlign.right,
            style: TextStyle(
                color: hours >= 20 ? AppColors.warning : AppColors.textSecondary,
                fontFamily: 'Tajawal', fontSize: 12)),
        if (lastSeen != null)
          Text('آخر نشاط: ${DateFormat('dd/MM/yyyy HH:mm').format(lastSeen)}',
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 10)),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onHeartbeat,
            icon: const Icon(Icons.favorite_outline, size: 14),
            label: const Text('تسجيل نشاط الآن', style: TextStyle(fontFamily: 'Tajawal')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10), elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _InfraEventsLog extends StatelessWidget {
  final String leaderUid;
  const _InfraEventsLog({required this.leaderUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('dead_mans_switch_log')
          .where('leaderUid', isEqualTo: leaderUid)
          .orderBy('triggeredAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: const Text('لا أحداث بنيوية مُسجَّلة.',
                textAlign: TextAlign.right,
                style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
          );
        }
        return Column(
          children: snap.data!.docs.map((d) {
            final data   = d.data() as Map<String, dynamic>;
            final action = data['action'] as String? ?? '';
            final count  = data['assetsAffected'] as int? ?? 0;
            final at     = (data['triggeredAt'] as Timestamp?)?.toDate();
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                if (at != null) Text(DateFormat('dd/MM HH:mm').format(at),
                    style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 9)),
                const Spacer(),
                Text('$action — $count عناصر',
                    style: const TextStyle(color: AppColors.error, fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w600, fontSize: 11)),
              ]),
            );
          }).toList(),
        );
      },
    );
  }
}

class _InfraHdr extends StatelessWidget {
  final String label;
  final IconData icon;
  const _InfraHdr({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(children: [
    const Spacer(),
    Text(label, style: const TextStyle(color: AppColors.textSecondary,
        fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 13)),
    const SizedBox(width: 6),
    Icon(icon, color: AppColors.accent, size: 16),
  ]);
}
