import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../constants/colors.dart';

/// Tab 29 — الترسانة التأديبية
///
/// • مصفوفة عتبة الكرامة (50 بند مُلوَّن)
/// • بروتوكول الرهاب (قفل + صوت + تحقق)
class DpcDisciplinaryTab extends StatefulWidget {
  final String uid;
  final String assetName;
  final Future<void> Function(String cmd, {Map<String, dynamic> payload}) sendCommand;
  const DpcDisciplinaryTab({super.key, required this.uid, required this.assetName, required this.sendCommand});

  @override
  State<DpcDisciplinaryTab> createState() => _DpcDisciplinaryTabState();
}

class _DpcDisciplinaryTabState extends State<DpcDisciplinaryTab> {

  static const _defaultLimits = [
    'وقت النوم',      'استخدام الهاتف',  'التواصل الاجتماعي',
    'الخروج',         'الطعام',           'الملابس',
    'الترفيه',        'التواصل مع الأهل', 'الخصوصية',
    'الوقت الحر',     'الإنفاق',          'الزيارات',
    'الموسيقى',       'القراءة',          'الرياضة',
    'ساعات العمل',    'التنقل',           'التعليم',
    'وسائل التواصل',  'الراحة',           'الزيارات الطبية',
    'الهواتف الأخرى', 'البريد',           'الطبخ',
    'الديكور',        'الأصدقاء',         'التسوق',
    'الصلاة',         'النوم النهاري',    'مشاهدة التلفاز',
    'الغذاء اليومي',  'القهوة',           'المياومة',
    'الحضور',         'الاستئذان',        'رنين الهاتف',
    'الشبكة',         'الكاميرا',         'البلوتوث',
    'الموقع',         'المكالمات',        'الرسائل',
    'البريد الإلكتروني', 'التطبيقات',     'الفيديو',
    'الصور',           'الصوت',           'الإشعارات',
    'اللغة',           'الاتجاه',
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.uid.isEmpty) {
      return const Center(child: Text('اختر عنصراً', style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal')));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('disciplinary_matrix')
          .doc(widget.uid)
          .snapshots(),
      builder: (_, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [

            // ── مصفوفة عتبة الكرامة ─────────────────────────────────────
            _DiscHdr(label: 'مصفوفة عتبة الكرامة (50 بنداً)', icon: Icons.table_chart_outlined),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: _defaultLimits.asMap().map((i, label) {
                  final statusKey  = 'limit_${i}_status';
                  final status     = data[statusKey] as String? ?? 'green';
                  return MapEntry(i, _LimitRow(
                    index:    i,
                    label:    label,
                    status:   status,
                    onStatus: (s) => _setLimitStatus(widget.uid, i, s),
                  ));
                }).values.toList(),
              ),
            ),
            const SizedBox(height: 20),

            // ── بروتوكول التحكم الأقصى ──────────────────────────────────
            _DiscHdr(label: 'بروتوكول التحكم الأقصى', icon: Icons.warning_amber_outlined),
            const SizedBox(height: 8),
            _ExtremeProtocolPanel(
              uid: widget.uid,
              sendCommand: widget.sendCommand,
            ),
          ]),
        );
      },
    );
  }

  Future<void> _setLimitStatus(String uid, int index, String status) async {
    await FirebaseFirestore.instance
        .collection('disciplinary_matrix')
        .doc(uid)
        .set({'limit_${index}_status': status}, SetOptions(merge: true));
  }
}

class _LimitRow extends StatelessWidget {
  final int index;
  final String label, status;
  final void Function(String) onStatus;
  const _LimitRow({required this.index, required this.label, required this.status, required this.onStatus});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'red'    => AppColors.error,
      'yellow' => const Color(0xFFD4AC0D),
      _        => AppColors.success,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        // Status selector
        Row(mainAxisSize: MainAxisSize.min, children: [
          _StatusDot(color: AppColors.error,           selected: status == 'red',    onTap: () => onStatus('red')),
          const SizedBox(width: 4),
          _StatusDot(color: const Color(0xFFD4AC0D),   selected: status == 'yellow', onTap: () => onStatus('yellow')),
          const SizedBox(width: 4),
          _StatusDot(color: AppColors.success,         selected: status == 'green',  onTap: () => onStatus('green')),
        ]),
        const SizedBox(width: 10),
        Expanded(
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Flexible(child: Text(label,
                textAlign: TextAlign.right,
                style: TextStyle(color: color, fontFamily: 'Tajawal', fontSize: 11))),
            const SizedBox(width: 4),
            Text('${index + 1}.',
                style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 9)),
          ]),
        ),
      ]),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _StatusDot({required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 14, height: 14,
      decoration: BoxDecoration(
        color: selected ? color : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
    ),
  );
}

// ── بروتوكول التحكم الأقصى ────────────────────────────────────────────────────

class _ExtremeProtocolPanel extends StatelessWidget {
  final String uid;
  final Future<void> Function(String, {Map<String, dynamic> payload}) sendCommand;
  const _ExtremeProtocolPanel({required this.uid, required this.sendCommand});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _ProtBtn(
        label:  'قفل + صوت تردد عالٍ',
        desc:   'يقفل الشاشة ويُشغِّل صوتاً عالي التردد.',
        color:  AppColors.error,
        icon:   Icons.vibration,
        onTap:  () => sendCommand('phobia_lockout', payload: {'highFreqAudio': true}),
      ),
      const SizedBox(height: 8),
      _ProtBtn(
        label:  'عزل رقمي كامل',
        desc:   'يُقطع الإنترنت + يُقفل التطبيقات + يُعرض شاشة بيضاء ناصعة.',
        color:  AppColors.warning,
        icon:   Icons.block_outlined,
        onTap:  () => sendCommand('digital_void', payload: {'whiteScreen': true, 'blockApps': true}),
      ),
      const SizedBox(height: 8),
      _ProtBtn(
        label:  'Court-Martial — إعادة الضبط الكاملة',
        desc:   'خسارة كاملة للنقاط + إعادة جرد + 3 أدوار متزامنة.',
        color:  AppColors.error,
        icon:   Icons.gavel_outlined,
        onTap:  () async {
          // Write court-martial to Firestore
          await FirebaseFirestore.instance
              .collection('disciplinary_events')
              .doc(uid)
              .collection('log')
              .add({
            'type': 'court_martial',
            'at':   FieldValue.serverTimestamp(),
          });
          await sendCommand('court_martial_reset');
        },
      ),
    ]);
  }
}

class _ProtBtn extends StatelessWidget {
  final String label, desc;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _ProtBtn({required this.label, required this.desc, required this.color, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, textAlign: TextAlign.right,
          style: TextStyle(color: color, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 12)),
      subtitle: Text(desc, textAlign: TextAlign.right,
          style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 10)),
      trailing: Icon(Icons.arrow_forward_ios, color: color, size: 12),
    ),
  );
}

class _DiscHdr extends StatelessWidget {
  final String label;
  final IconData icon;
  const _DiscHdr({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(children: [
    const Spacer(),
    Text(label, style: const TextStyle(color: AppColors.textSecondary,
        fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 13)),
    const SizedBox(width: 6),
    Icon(icon, color: AppColors.accent, size: 16),
  ]);
}
