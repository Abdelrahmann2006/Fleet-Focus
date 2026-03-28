import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../models/asset_audit_model.dart';

/// Tab 25 — الجرد المتقدم
///
/// يشمل:
///  • Zero-Hour Lockdown (شاشة سوداء خلال الجرد الفعلي)
///  • محرك مقارنة الجرد (Audit Diff Engine)
///  • مصير الأصول (حجز / إعادة / إعادة بقيود)
class DpcAdvancedAuditTab extends StatelessWidget {
  final String uid;
  final Future<void> Function(String cmd, {Map<String, dynamic> payload}) sendCommand;

  const DpcAdvancedAuditTab({
    super.key,
    required this.uid,
    required this.sendCommand,
  });

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return const Center(
        child: Text('اختر عنصراً من القائمة',
            style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal')),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [

        // ── Zero-Hour Lockdown ──────────────────────────────────────────────
        _AuditSectionHeader(label: 'قفل ساعة الصفر', icon: Icons.brightness_1),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text(
              'يُفعِّل شاشة سوداء دائمة على الجهاز أثناء الجرد المادي. الجهاز غير قابل للاستخدام حتى صدور أمر "إنهاء الجرد".',
              textAlign: TextAlign.right,
              style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 12),
            Row(children: [
              _AuditBtn(
                label: 'إنهاء الجرد',
                icon: Icons.lock_open_outlined,
                color: AppColors.success,
                onTap: () => sendCommand('conclude_zero_hour_lockdown'),
              ),
              const SizedBox(width: 10),
              _AuditBtn(
                label: 'تفعيل قفل ساعة الصفر',
                icon: Icons.do_not_disturb_on_outlined,
                color: AppColors.error,
                onTap: () => sendCommand('zero_hour_lockdown',
                    payload: {'reason': 'جرد مادي جارٍ'}),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 20),

        // ── محرك مقارنة الجرد ──────────────────────────────────────────────
        _AuditSectionHeader(label: 'محرك مقارنة الجرد', icon: Icons.compare_arrows_outlined),
        const SizedBox(height: 8),
        _AuditDiffEngine(uid: uid),
        const SizedBox(height: 20),

        // ── مصير الأصول ────────────────────────────────────────────────────
        _AuditSectionHeader(label: 'مصير الأصول', icon: Icons.gavel_outlined),
        const SizedBox(height: 8),
        _AssetFatePanel(uid: uid, sendCommand: sendCommand),
      ]),
    );
  }
}

// ── محرك المقارنة ─────────────────────────────────────────────────────────────

class _AuditDiffEngine extends StatelessWidget {
  final String uid;
  const _AuditDiffEngine({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('asset_audits')
          .doc(uid)
          .collection('history')
          .orderBy('submittedAt', descending: true)
          .limit(2)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _EmptyDiff();
        }
        if (snap.data!.docs.length < 2) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text('جرد واحد فقط — لا توجد مقارنة بعد.',
                textAlign: TextAlign.right,
                style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
          );
        }

        final current  = snap.data!.docs[0].data() as Map<String, dynamic>;
        final previous = snap.data!.docs[1].data() as Map<String, dynamic>;
        final currAns  = (current['answers']  as Map<String, dynamic>?) ?? {};
        final prevAns  = (previous['answers'] as Map<String, dynamic>?) ?? {};

        final diffs = <_DiffEntry>[];
        for (final cat in kAuditCategories) {
          final cur = currAns[cat.id]  as Map<String, dynamic>? ?? {};
          final prv = prevAns[cat.id]  as Map<String, dynamic>? ?? {};
          final curOwned = cur['owned']  as bool? ?? false;
          final prvOwned = prv['owned']  as bool? ?? false;
          final curQty   = (cur['qty']   as num?)?.toInt() ?? 0;
          final prvQty   = (prv['qty']   as num?)?.toInt() ?? 0;

          if (curOwned != prvOwned || curQty != prvQty) {
            diffs.add(_DiffEntry(
              category: cat.titleAr,
              prevOwned: prvOwned,
              currOwned: curOwned,
              prevQty: prvQty,
              currQty: curQty,
            ));
          }
        }

        if (diffs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              const Text('لا تغييرات مكتشفة بين الجردَين',
                  style: TextStyle(color: AppColors.success, fontFamily: 'Tajawal', fontSize: 12)),
              const SizedBox(width: 8),
              const Icon(Icons.check_circle_outline, color: AppColors.success, size: 16),
            ]),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${diffs.length} تغيير مكتشَف',
                style: const TextStyle(color: AppColors.warning, fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            ...diffs.map((d) => _DiffRow(entry: d)),
          ],
        );
      },
    );
  }
}

class _DiffEntry {
  final String category;
  final bool prevOwned, currOwned;
  final int prevQty, currQty;
  const _DiffEntry({
    required this.category,
    required this.prevOwned, required this.currOwned,
    required this.prevQty,   required this.currQty,
  });
}

class _DiffRow extends StatelessWidget {
  final _DiffEntry entry;
  const _DiffRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFD4AC0D).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD4AC0D).withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(entry.category,
            style: const TextStyle(color: AppColors.text,
                fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (entry.prevQty != entry.currQty) ...[
            Text('الجديد: ${entry.currQty}',
                style: const TextStyle(color: Color(0xFFD4AC0D),
                    fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 11)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('←', style: TextStyle(color: AppColors.textMuted)),
            ),
            Text('القديم: ${entry.prevQty}',
                style: const TextStyle(color: AppColors.textMuted,
                    fontFamily: 'Tajawal', fontSize: 11)),
          ],
          if (entry.prevOwned != entry.currOwned) ...[
            if (entry.prevQty != entry.currQty) const SizedBox(width: 12),
            Text(entry.currOwned ? '✓ أُضيف' : '✗ أُزيل',
                style: TextStyle(
                    color: entry.currOwned ? AppColors.success : AppColors.error,
                    fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 11)),
          ],
        ]),
      ]),
    );
  }
}

class _EmptyDiff extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.backgroundCard,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
    ),
    child: const Text('لا يوجد تاريخ جرد بعد.',
        textAlign: TextAlign.right,
        style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
  );
}

// ── مصير الأصول ─────────────────────────────────────────────────────────────

class _AssetFatePanel extends StatelessWidget {
  final String uid;
  final Future<void> Function(String, {Map<String, dynamic> payload}) sendCommand;
  const _AssetFatePanel({required this.uid, required this.sendCommand});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('asset_audits')
          .doc(uid)
          .snapshots(),
      builder: (_, snap) {
        final data    = snap.data?.data() as Map<String, dynamic>? ?? {};
        final answers = data['answers'] as Map<String, dynamic>? ?? {};

        if (answers.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text('لا يوجد جرد مُرسَل بعد.',
                textAlign: TextAlign.right,
                style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
          );
        }

        final owned = answers.entries
            .where((e) => (e.value as Map<String, dynamic>? ?? {})['owned'] == true)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: owned.map((e) {
            final label = _labelFor(e.key);
            final fateKey = 'fate_${e.key}';
            final fate = data[fateKey] as String? ?? 'pending';
            return _FateRow(
              categoryId: e.key,
              label: label,
              fate: fate,
              onFate: (f) => _setFate(uid, e.key, f),
            );
          }).toList(),
        );
      },
    );
  }

  static String _labelFor(String id) {
    try { return kAuditCategories.firstWhere((c) => c.id == id).titleAr; }
    catch (_) { return id; }
  }

  Future<void> _setFate(String uid, String categoryId, String fate) async {
    await FirebaseFirestore.instance
        .collection('asset_audits')
        .doc(uid)
        .set({'fate_$categoryId': fate}, SetOptions(merge: true));
    await sendCommand('asset_fate_update',
        payload: {'categoryId': categoryId, 'fate': fate});
  }
}

class _FateRow extends StatelessWidget {
  final String categoryId, label, fate;
  final void Function(String) onFate;
  const _FateRow({
    required this.categoryId, required this.label,
    required this.fate, required this.onFate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Row(children: [
          _FateBtn(label: 'إعادة بقيود', color: AppColors.warning,
              selected: fate == 'restricted', onTap: () => onFate('restricted')),
          const SizedBox(width: 6),
          _FateBtn(label: 'إعادة', color: AppColors.success,
              selected: fate == 'returned', onTap: () => onFate('returned')),
          const SizedBox(width: 6),
          _FateBtn(label: 'حجز', color: AppColors.error,
              selected: fate == 'confiscated', onTap: () => onFate('confiscated')),
        ]),
        const Spacer(),
        Text(label, style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 12)),
      ]),
    );
  }
}

class _FateBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _FateBtn({required this.label, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: selected ? color : AppColors.border),
      ),
      child: Text(label, style: TextStyle(
          color: selected ? color : AppColors.textMuted,
          fontFamily: 'Tajawal', fontSize: 10,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
    ),
  );
}

// ── مساعد ───────────────────────────────────────────────────────────────────

class _AuditSectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _AuditSectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(children: [
    const Spacer(),
    Text(label, style: const TextStyle(
        color: AppColors.textSecondary, fontFamily: 'Tajawal',
        fontWeight: FontWeight.w600, fontSize: 13)),
    const SizedBox(width: 6),
    Icon(icon, color: AppColors.accent, size: 16),
  ]);
}

class _AuditBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _AuditBtn({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 10),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withValues(alpha: 0.4)),
        ),
      ),
    ),
  );
}
