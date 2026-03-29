import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // تأكد من إضافة هذه المكتبة في pubspec.yaml

import '../../constants/colors.dart';
import '../../providers/leader_ui_provider.dart';
import '../../providers/participant_stream_provider.dart';
import 'leader_home_tab.dart';
import 'join_requests_screen.dart';
import 'reports_screen.dart';
import 'leader_settings_screen.dart';

/// LeaderShell — الغلاف الرئيسي لواجهة القائد
/// يدير التنقل السفلي والوظائف السيادية مثل توليد كود الانضمام
class LeaderShell extends StatefulWidget {
  const LeaderShell({super.key});

  @override
  State<LeaderShell> createState() => _LeaderShellState();
}

class _LeaderShellState extends State<LeaderShell> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  // قائمة التبويبات الرئيسية
  late final List<Widget> _tabs = [
    LeaderHomeTab(isActive: _currentIndex == 0),
    const JoinRequestsScreen(),
    const ReportsScreen(),
    const LeaderSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // جلب عدد الطلبات المعلقة من البيانات الحقيقية لإظهارها على الأيقونة
    final pendingCount = context.watch<ParticipantStreamProvider>().pendingCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),

      // ── زر توليد كود جديد ─────────────────────────────────
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showGenerateCodeDialog(context),
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add_moderator_outlined, size: 20),
              label: const Text(
                'معرف جديد',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, fontFamily: 'Tajawal'),
              ),
              elevation: 4,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,

      // ── شريط التنقل السفلي ────────────────────────────────────
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
                  badge: pendingCount > 0 ? pendingCount : null,
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

  // ── نافذة توليد معرف الانضمام الرسمي ──────────────────────────

  void _showGenerateCodeDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    String? generatedCode;
    String? participantName;
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
              Text('توليد معرف انضمام رسمي',
                  style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.w700)),
              SizedBox(width: 8),
              Icon(Icons.badge_outlined, color: AppColors.accent, size: 20),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (generatedCode == null) ...[
                // إدخال اسم العنصر قبل التوليد
                Container(
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                  child: TextField(
                    controller: nameCtrl,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal'),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      hintText: 'اسم العنصر المستهدف',
                      hintStyle: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('سيتم إنشاء معرف فريد (ID) لا يمكن الدخول بدونه.', 
                    textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontFamily: 'Tajawal')),
              ] else ...[
                // عرض المعرف المولَّد بخط عريض وواضح
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.accent.withOpacity(0.15), AppColors.accent.withOpacity(0.05)]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                  ),
                  child: Column(
                    children: [
                      const Text('معرف الانضمام الصادر', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontFamily: 'Tajawal')),
                      const SizedBox(height: 8),
                      SelectableText(
                        generatedCode!,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.accent, fontFamily: 'Tajawal', letterSpacing: 2),
                      ),
                      const SizedBox(height: 16),
                      // صف الأزرار: واتساب + نسخ
                      Row(
                        children: [
                          // زر المشاركة عبر واتساب
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final msg = "أهلاً $participantName، هذا هو معرف الانضمام الرسمي الخاص بك في نظام Panopticon:\n\n$generatedCode\n\nيرجى استخدامه لإتمام عملية التسجيل والولاء.";
                                final url = "https://wa.me/?text=${Uri.encodeComponent(msg)}";
                                if (await canLaunchUrl(Uri.parse(url))) {
                                  await launchUrl(Uri.parse(url));
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.chat_bubble_outline, size: 14),
                              label: const Text('واتساب', style: TextStyle(fontSize: 11, fontFamily: 'Tajawal')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // زر النسخ للحافظة
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: generatedCode!));
                                setS(() => copied = true);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.backgroundElevated,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: Icon(copied ? Icons.check : Icons.copy_all_outlined, size: 14, color: AppColors.accent),
                              label: Text(copied ? 'تم!' : 'نسخ', 
                                  style: const TextStyle(fontSize: 11, fontFamily: 'Tajawal', color: AppColors.textSecondary)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal'))),
            if (generatedCode == null)
              ElevatedButton.icon(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final code = context.read<LeaderUIProvider>().generateCode(name);
                  setS(() { generatedCode = code; participantName = name; });
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('توليد المعرف', style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Tajawal')),
              )
            else
              ElevatedButton(
                onPressed: () { nameCtrl.clear(); setS(() { generatedCode = null; copied = false; }); },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.info),
                child: const Text('توليد معرف جديد', style: TextStyle(color: Colors.white, fontFamily: 'Tajawal')),
              ),
          ],
        ),
      ),
    );
  }
}

// ── NavItem Widget ─────────────────────────────────────────────

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
                  child: Icon(active ? activeIcon : icon, key: ValueKey(active), color: color, size: 22),
                ),
                if (badge != null && badge! > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.backgroundCard, width: 1.5),
                      ),
                      child: Center(
                        child: Text('$badge', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: active ? FontWeight.w700 : FontWeight.w400, fontFamily: 'Tajawal')),
          ],
        ),
      ),
    );
  }
}
