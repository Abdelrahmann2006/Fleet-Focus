import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../constants/colors.dart';

/// Tab 27 — مهارات العناصر (Radar Chart)
///
/// يعرض مخطط Radar متحركاً يُصوِّر مستويات المهارات الحالية.
/// البيانات مُخزَّنة في Firestore: skill_profiles/{uid}
class DpcSkillsRadarTab extends StatelessWidget {
  final String uid;
  const DpcSkillsRadarTab({super.key, required this.uid});

  static const _skills = [
    'الالتزام', 'الدقة', 'السرعة',
    'التواصل', 'الطاعة', 'الابتكار',
  ];

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return const Center(child: Text('اختر عنصراً', style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal')));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('skill_profiles')
          .doc(uid)
          .snapshots(),
      builder: (_, snap) {
        final data   = snap.data?.data() as Map<String, dynamic>? ?? {};
        final scores = _skills.map((s) => ((data[s] as num?)?.toDouble() ?? 50.0).clamp(0.0, 100.0)).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [

            // ── Radar Chart ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(children: [
                const Text('خريطة المهارات',
                    style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 280,
                  child: CustomPaint(
                    painter: _RadarPainter(scores: scores, labels: _skills),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // ── إدخال الدرجات يدوياً ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('تعديل الدرجات',
                      style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal',
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 12),
                  ..._skills.asMap().map((i, s) => MapEntry(i,
                    _SkillSlider(
                      label: s,
                      value: scores[i],
                      onChanged: (v) => _updateSkill(uid, s, v),
                    ),
                  )).values.toList(),
                ],
              ),
            ),
          ]),
        );
      },
    );
  }

  static Future<void> _updateSkill(String uid, String skill, double value) async {
    await FirebaseFirestore.instance
        .collection('skill_profiles')
        .doc(uid)
        .set({skill: value, 'updatedAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
  }
}

class _SkillSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _SkillSlider({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Text('${value.round()}', style: const TextStyle(
          color: AppColors.accent, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 12),
        textDirection: TextDirection.ltr),
      Expanded(
        child: Slider(
          value: value,
          min: 0, max: 100,
          activeColor: AppColors.accent,
          inactiveColor: AppColors.border,
          onChanged: onChanged,
        ),
      ),
      SizedBox(width: 80, child: Text(label,
          textAlign: TextAlign.right,
          style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 12))),
    ]),
  );
}

// ── Radar Chart Painter ──────────────────────────────────────────────────────

class _RadarPainter extends CustomPainter {
  final List<double> scores;
  final List<String> labels;
  const _RadarPainter({required this.scores, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width  / 2;
    final cy     = size.height / 2;
    final radius = min(cx, cy) - 40;
    final n      = scores.length;
    final step   = (2 * pi) / n;
    final startAngle = -pi / 2;

    // ── Grid circles ────────────────────────────────────────────────────
    for (int r = 1; r <= 4; r++) {
      final paint = Paint()
        ..color = AppColors.border.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawCircle(Offset(cx, cy), radius * r / 4, paint);
    }

    // ── Grid axes ────────────────────────────────────────────────────────
    for (int i = 0; i < n; i++) {
      final angle = startAngle + i * step;
      final x     = cx + radius * cos(angle);
      final y     = cy + radius * sin(angle);
      final paint = Paint()..color = AppColors.border.withValues(alpha: 0.5)..strokeWidth = 0.8;
      canvas.drawLine(Offset(cx, cy), Offset(x, y), paint);
    }

    // ── Data polygon ─────────────────────────────────────────────────────
    final path  = Path();
    final fill  = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = AppColors.accent
      ..style  = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < n; i++) {
      final angle = startAngle + i * step;
      final r     = radius * scores[i] / 100.0;
      final x     = cx + r * cos(angle);
      final y     = cy + r * sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);

    // ── Data points ──────────────────────────────────────────────────────
    final dotPaint = Paint()..color = AppColors.accent..style = PaintingStyle.fill;
    for (int i = 0; i < n; i++) {
      final angle = startAngle + i * step;
      final r     = radius * scores[i] / 100.0;
      canvas.drawCircle(Offset(cx + r * cos(angle), cy + r * sin(angle)), 4, dotPaint);
    }

    // ── Labels ───────────────────────────────────────────────────────────
    final tp = TextPainter(textDirection: TextDirection.rtl);
    for (int i = 0; i < n; i++) {
      final angle = startAngle + i * step;
      final lx    = cx + (radius + 28) * cos(angle);
      final ly    = cy + (radius + 28) * sin(angle);
      tp.text = TextSpan(
        text: labels[i],
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontFamily: 'Tajawal'),
      );
      tp.layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.scores != scores;
}
