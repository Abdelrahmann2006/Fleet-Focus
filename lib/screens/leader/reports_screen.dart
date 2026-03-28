import 'package:flutter/material.dart';
import '../../constants/colors.dart';

/// شاشة التقارير — واجهة احتياطية لبيانات Google Sheets المستقبلية
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('التقارير الشاملة',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                          fontFamily: 'Tajawal')),
                ],
              ),
            ),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // أيقونة كبيرة
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.success.withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                      border: Border.all(
                        color: AppColors.success.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.table_chart_outlined,
                      size: 44,
                      color: AppColors.success,
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'تقارير Google Sheets',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                      fontFamily: 'Tajawal',
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'سيتم هنا عرض التقارير الشاملة المتزامنة مع Google Sheets — بيانات الأداء، والطاعة، والمهام.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontFamily: 'Tajawal',
                        height: 1.6,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // مؤشرات التقارير القادمة
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _ComingSoonTile(
                          icon: Icons.trending_up,
                          title: 'تقرير الأداء الأسبوعي',
                          color: AppColors.info,
                        ),
                        const SizedBox(height: 8),
                        _ComingSoonTile(
                          icon: Icons.military_tech_outlined,
                          title: 'تصنيف الطاعة والولاء',
                          color: AppColors.accent,
                        ),
                        const SizedBox(height: 8),
                        _ComingSoonTile(
                          icon: Icons.task_alt_outlined,
                          title: 'تتبع المهام والإنجازات',
                          color: AppColors.success,
                        ),
                        const SizedBox(height: 8),
                        _ComingSoonTile(
                          icon: Icons.psychology_outlined,
                          title: 'التحليل النفسي الجماعي',
                          color: const Color(0xFF9F7AEA),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('قريباً في المرحلة 2',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                fontFamily: 'Tajawal')),
                        SizedBox(width: 6),
                        Icon(Icons.schedule_outlined,
                            size: 14, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _ComingSoonTile({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppColors.textMuted.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.lock_outline, size: 10, color: AppColors.textMuted),
          ),
          const Spacer(),
          Text(title,
              style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Tajawal')),
          const SizedBox(width: 10),
          Icon(icon, size: 18, color: color),
        ],
      ),
    );
  }
}
