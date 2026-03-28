import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/colors.dart';

/// Tab 32 — وضع الزن + خريطة الجلسة
///
/// • وضع الزن: يخفي جميع البيانات إلا الانتهاكات
/// • خريطة استخدام التطبيق الحبيبي
/// • تقرير المراقبة السيادية
class DpcZenModeTab extends StatefulWidget {
  final String uid;
  const DpcZenModeTab({super.key, required this.uid});

  @override
  State<DpcZenModeTab> createState() => _DpcZenModeTabState();
}

class _DpcZenModeTabState extends State<DpcZenModeTab> {
  bool _zenMode = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [

        // ── مفتاح وضع الزن ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _zenMode
                ? AppColors.success.withValues(alpha: 0.07)
                : AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _zenMode
                ? AppColors.success.withValues(alpha: 0.4)
                : AppColors.border),
          ),
          child: Row(children: [
            Switch(
              value: _zenMode,
              onChanged: (v) => setState(() => _zenMode = v),
              activeColor: AppColors.success,
              activeTrackColor: AppColors.success.withValues(alpha: 0.3),
            ),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_zenMode ? 'وضع الزن مُفعَّل' : 'وضع الزن معطَّل',
                  style: TextStyle(
                      color: _zenMode ? AppColors.success : AppColors.text,
                      fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 14)),
              Text(_zenMode
                  ? 'يُعرض فقط: الانتهاكات والاستثناءات'
                  : 'جميع البيانات مرئية',
                  style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 10)),
            ]),
            const SizedBox(width: 8),
            Icon(_zenMode ? Icons.spa_outlined : Icons.spa,
                color: _zenMode ? AppColors.success : AppColors.textMuted, size: 24),
          ]),
        ),
        const SizedBox(height: 16),

        if (_zenMode) ...[
          _ZenViolationsOnly(uid: widget.uid),
        ] else ...[
          _ZenHdr(label: 'خريطة استخدام التطبيق', icon: Icons.map_outlined),
          const SizedBox(height: 8),
          _AppUsageMap(uid: widget.uid),
          const SizedBox(height: 20),
          _ZenHdr(label: 'الدرجة التراكمية للامتثال', icon: Icons.leaderboard_outlined),
          const SizedBox(height: 8),
          _ComplianceScore(uid: widget.uid),
          const SizedBox(height: 20),
          _ZenHdr(label: 'تقرير التدقيق التاريخي', icon: Icons.analytics_outlined),
          const SizedBox(height: 8),
          _AuditMapReport(uid: widget.uid),
        ],
      ]),
    );
  }
}

// ── وضع الزن: الانتهاكات فقط ────────────────────────────────────────────────

class _ZenViolationsOnly extends StatelessWidget {
  final String uid;
  const _ZenViolationsOnly({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('device_states/$uid/behavioralAnalysis').onValue,
      builder: (_, snap) {
        final data  = (snap.data?.snapshot.value as Map?)?.cast<String, dynamic>() ?? {};
        final flags = (data['alertFlags'] as List?)?.cast<String>() ?? [];

        if (flags.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
            ),
            child: Column(children: [
              const Icon(Icons.check_circle_outline, color: AppColors.success, size: 48),
              const SizedBox(height: 12),
              const Text('لا انتهاكات مكتشَفة',
                  style: TextStyle(color: AppColors.success, fontFamily: 'Tajawal',
                      fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('اللوحة هادئة — كل شيء تحت السيطرة',
                  style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
            ]),
          );
        }

        return Column(
          children: flags.map((f) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_outlined, color: AppColors.error, size: 18),
              const Spacer(),
              Text(f, style: const TextStyle(color: AppColors.error,
                  fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          )).toList(),
        );
      },
    );
  }
}

// ── خريطة استخدام التطبيق ────────────────────────────────────────────────────

class _AppUsageMap extends StatelessWidget {
  final String uid;
  const _AppUsageMap({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('app_usage_log')
          .doc(uid)
          .collection('sessions')
          .orderBy('openedAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: const Text('لا توجد بيانات استخدام بعد.',
                textAlign: TextAlign.right,
                style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
          );
        }

        // تجميع حسب التطبيق
        final counts = <String, int>{};
        for (final d in snap.data!.docs) {
          final app = (d.data() as Map<String, dynamic>)['app'] as String? ?? 'unknown';
          counts[app] = (counts[app] ?? 0) + 1;
        }
        final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
          child: Column(
            children: sorted.map((e) {
              final max = sorted.first.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Text('${e.value}x', style: const TextStyle(
                      color: AppColors.accent, fontFamily: 'Tajawal',
                      fontWeight: FontWeight.w700, fontSize: 11)),
                  const SizedBox(width: 8),
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: e.value / max,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation(AppColors.info.withValues(alpha: 0.7)),
                      minHeight: 6,
                    ),
                  )),
                  const SizedBox(width: 8),
                  Text(e.key, textAlign: TextAlign.right,
                      style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 11)),
                ]),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ── درجة الامتثال التراكمية ──────────────────────────────────────────────────

class _ComplianceScore extends StatelessWidget {
  final String uid;
  const _ComplianceScore({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('compliance_score').doc(uid).snapshots(),
      builder: (_, snap) {
        final d     = snap.data?.data() as Map<String, dynamic>? ?? {};
        final score = (d['masterScore'] as num?)?.toInt() ?? 0;
        final rank  = d['rank'] as String? ?? '—';
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.accent.withValues(alpha: 0.1), AppColors.backgroundCard]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(rank, style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11)),
              const Text('الرتبة', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 9)),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$score', style: const TextStyle(color: AppColors.accent, fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w800, fontSize: 36)),
              const Text('درجة الامتثال الكاملة',
                  style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 10)),
            ]),
          ]),
        );
      },
    );
  }
}

// ── تقرير التدقيق التاريخي ────────────────────────────────────────────────────

class _AuditMapReport extends StatelessWidget {
  final String uid;
  const _AuditMapReport({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('audit_usage_map').doc(uid).snapshots(),
      builder: (_, snap) {
        final d = snap.data?.data() as Map<String, dynamic>? ?? {};
        if (d.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: const Text('لا توجد بيانات تدقيق بعد.',
                textAlign: TextAlign.right,
                style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
          );
        }
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: d.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Text('${e.value}x',
                    style: const TextStyle(color: AppColors.accent, fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w700, fontSize: 12)),
                const Spacer(),
                Text('${e.key}',
                    style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 12)),
              ]),
            )).toList(),
          ),
        );
      },
    );
  }
}

class _ZenHdr extends StatelessWidget {
  final String label;
  final IconData icon;
  const _ZenHdr({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(children: [
    const Spacer(),
    Text(label, style: const TextStyle(color: AppColors.textSecondary,
        fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 13)),
    const SizedBox(width: 6),
    Icon(icon, color: AppColors.accent, size: 16),
  ]);
}
