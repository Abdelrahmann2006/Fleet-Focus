import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/leader_ui_provider.dart';
import '../../providers/participant_stream_provider.dart'; // ⚡ التعديل: استدعاء مزود البيانات الحقيقية
import 'leader_home_tab.dart';
import 'join_requests_screen.dart';
import 'reports_screen.dart';
import 'leader_settings_screen.dart';

/// LeaderShell — غلاف واجهة القائد مع Bottom Nav + FAB
///
/// يُدير 4 تبويبات:
///  0 → الرئيسية (شبكة المشاركين)
///  1 → طلبات الانضمام (مع شارة عداد)
///  2 → التقارير
///  3 → الإعدادات
///
/// FAB → "توليد كود جديد" — يظهر فقط في التبويب الرئيسي
class LeaderShell extends StatefulWidget {
  const LeaderShell({super.key});

  @override
  State<LeaderShell> createState() => _LeaderShellState();
}

class _LeaderShellState extends State<LeaderShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  late final List<Widget> _tabs = [
    LeaderHomeTab(isActive: _currentIndex == 0),
    const JoinRequestsScreen(),
    const ReportsScreen(),
    const LeaderSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // ⚡ التعديل: قراءة عدد الطلبات المعلقة من الـ StreamProvider الحقيقي
    final pending = context.watch<ParticipantStreamProvider>().pendingCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      // ── الصفحات ─────────────────────────────────────────────
      body: IndexedStack(
        index: _currentIndex,
        children: [
          LeaderHomeTab(isActive: _currentIndex == 0),
          const JoinRequestsScreen(),
          const ReportsScreen(),
          const LeaderSettingsScreen(),
        ],
      ),

      // ── FAB — توليد كود جديد ─────────────────────────────────
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showGenerateCodeDialog(context),
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'كود جديد',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    fontFamily: 'Tajawal'),
              ),
              elevation: 4,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,

      // ── Bottom Navigation ────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
          color: AppColors.backgroundCard,
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                  label: 'الرئيسية',
                  index: 0,
                  currentIndex: _currentIndex,
                  onTap: _onTabTap,
                ),
                _NavItem(
                  icon: Icons.person_add_outlined,
                  activeIcon: Icons.person_add_rounded,
                  label: 'الطلبات',
                  index: 1,
                  currentIndex: _currentIndex,
                  onTap: _onTabTap,
                  badge: pending > 0 ? pending : null, // ⚡ استخدام العداد الحقيقي هنا
                ),
                _NavItem(
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart_rounded,
                  label: 'التقارير',
                  index: 2,
                  currentIndex: _currentIndex,
                  onTap: _onTabTap,
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'الإعدادات',
                  index: 3,
                  currentIndex: _currentIndex,
                  onTap: _onTabTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onTabTap(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }
    // ── Generate Code Dialog ──────────────────────────────────────

  void _showGenerateCodeDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    String? generatedCode;
    bool copied = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.backgroundCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('توليد كود مشارك',
                  style: TextStyle(
                      color: AppColors.text,
                      fontFamily: 'Tajawal',
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              SizedBox(width: 8),
              Icon(Icons.qr_code_outlined, color: AppColors.accent, size: 20),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (generatedCode == null) ...[
                // ─ حقل الاسم ─
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: nameCtrl,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                        color: AppColors.text, fontFamily: 'Tajawal'),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      hintText: 'اسم العنصر',
                      hintStyle: TextStyle(
                          color: AppColors.textMuted, fontFamily: 'Tajawal'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'يُولَّد كود مؤقت لتسجيل العنصر',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontFamily: 'Tajawal'),
                ),
              ] else ...[
                // ─ الكود المولَّد ─
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent.withOpacity(0.15),
                        AppColors.accent.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                  ),
                  child: Column(
                    children: [
                      const Text('الكود',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontFamily: 'Tajawal')),
                      const SizedBox(height: 8),
                      Text(
                        generatedCode!,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.accent,
                          fontFamily: 'Tajawal',
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () async {
                          await Clipboard.setData(
                              ClipboardData(text: generatedCode!));
                          setS(() => copied = true);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: copied
                                ? AppColors.success.withOpacity(0.15)
                                : AppColors.backgroundElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: copied
                                    ? AppColors.success.withOpacity(0.4)
                                    : AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                copied ? 'تم النسخ!' : 'نسخ الكود',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: copied
                                        ? AppColors.success
                                        : AppColors.textSecondary,
                                    fontFamily: 'Tajawal'),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                copied
                                    ? Icons.check_circle_outline
                                    : Icons.copy_outlined,
                                size: 14,
                                color: copied
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.info.withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(child: SizedBox()),
                      Flexible(
                        child: Text(
                          'أعطِ هذا الكود للمشارك ليُدخله عند التسجيل.',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.info,
                              fontFamily: 'Tajawal'),
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.info_outline, size: 13, color: AppColors.info),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontFamily: 'Tajawal')),
            ),
            if (generatedCode == null)
              ElevatedButton.icon(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final code = context.read<LeaderUIProvider>().generateCode(name);
                  setS(() => generatedCode = code);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('توليد',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontFamily: 'Tajawal')),
              )
            else
              ElevatedButton.icon(
                onPressed: () {
                  nameCtrl.clear();
                  setS(() {
                    generatedCode = null;
                    copied = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.info,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                label: const Text('كود جديد',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Tajawal')),
              ),
          ],
        ),
      ),
    );
  }
}

// ── NavItem ───────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int? badge;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == currentIndex;
    final color = active ? AppColors.accent : AppColors.textMuted;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    active ? activeIcon : icon,
                    key: ValueKey(active),
                    color: color,
                    size: 22,
                  ),
                ),
                if (badge != null && badge! > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.backgroundCard, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          '$badge',
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.w400,
                  fontFamily: 'Tajawal'),
            ),
          ],
        ),
      ),
    );
  }
}
