import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leader_ui_provider.dart';
import '../../providers/participant_stream_provider.dart';
import 'leader_home_tab.dart';
import 'join_requests_screen.dart'; // ستعمل كمركز للإشعارات
import 'leader_settings_screen.dart';

class LeaderShell extends StatefulWidget {
  const LeaderShell({super.key});

  @override
  State<LeaderShell> createState() => _LeaderShellState();
}

class _LeaderShellState extends State<LeaderShell> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // جلب عدد الطلبات/الإشعارات المعلقة
    final pendingCount = context.watch<ParticipantStreamProvider>().pendingCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          LeaderHomeTab(isActive: _currentIndex == 0),
          const JoinRequestsScreen(), // شاشة الإشعارات (الاستمارات والطلبات)
          const Center(
            child: Text(
              'شاشة الدردشات قيد التطوير',
              style: TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 16),
            ),
          ),
          const LeaderSettingsScreen(),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showGenerateCodeDialog(context),
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('إضافة عنصر',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, fontFamily: 'Tajawal')),
              elevation: 4,
            )
          : null,
      // endFloat في التطبيقات العربية (RTL) يضع الزر على اليسار
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildBottomNav(pendingCount),
    );
  }

  // ── نافذة توليد المعرف المتصلة بقاعدة البيانات ──────────────────────────

  void _showGenerateCodeDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    String? generatedCode;
    String? participantName;
    bool copied = false;
    bool loading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.backgroundCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('توليد معرف انضمام رسمي',
                  style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Icon(Icons.badge_outlined, color: AppColors.accent, size: 20),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (generatedCode == null) ...[
                // إدخال الاسم
                _buildInput(nameCtrl),
                const SizedBox(height: 12),
                _buildActionBtn(
                  label: loading ? 'جاري التفعيل...' : 'توليد المعرف وتفعيله',
                  icon: Icons.auto_awesome,
                  color: AppColors.accent,
                  textColor: Colors.black,
                  onTap: loading ? null : () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final leaderUid = context.read<AuthProvider>().user?.uid;
                    if (leaderUid == null) return;

                    setS(() => loading = true);
                    try {
                      // الاتصال بالخادم لتوليد كود حقيقي
                      final code = await context.read<LeaderUIProvider>().generateCode(name, leaderUid);
                      setS(() {
                        generatedCode = code;
                        participantName = name;
                        loading = false;
                      });
                    } catch (e) {
                      setS(() => loading = false);
                    }
                  },
                ),
              ] else ...[
                // عرض الكود
                _buildCodeDisplay(generatedCode!),
                const SizedBox(height: 20),
                
                // الأزرار
                _buildActionBtn(
                  label: copied ? 'تم النسخ بنجاح' : 'نسخ المعرف الرسمي',
                  icon: copied ? Icons.check_circle : Icons.copy_all_outlined,
                  color: AppColors.backgroundElevated,
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: generatedCode!));
                    setS(() => copied = true);
                  },
                ),
                const SizedBox(height: 10),
                _buildActionBtn(
                  label: 'إرسال عبر واتساب',
                  icon: Icons.chat_bubble_outline,
                  color: const Color(0xFF25D366),
                  onTap: () async {
                    final msg = "أهلاً $participantName، هذا هو معرف الانضمام الرسمي الخاص بك:\n\n$generatedCode\n\nيرجى استخدامه للتسجيل فوراً.";
                    final url = "https://wa.me/?text=${Uri.encodeComponent(msg)}";
                    if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
                  },
                ),
                const SizedBox(height: 10),
                _buildActionBtn(
                  label: 'توليد معرف جديد',
                  icon: Icons.refresh_rounded,
                  color: AppColors.error,
                  onTap: () {
                    nameCtrl.clear();
                    setS(() {
                      generatedCode = null;
                      copied = false;
                    });
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء الإجراء', style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── مكونات مساعدة للنافذة ──────────────────────────────────

  Widget _buildInput(TextEditingController ctrl) {
    return Container(
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: TextField(
        controller: ctrl,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal'),
        decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12), hintText: 'اسم العنصر المستهدف', hintStyle: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal')),
      ),
    );
  }

  Widget _buildCodeDisplay(String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Text(
        code,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.accent, fontFamily: 'Courier', letterSpacing: 4),
      ),
    );
  }

  Widget _buildActionBtn({required String label, required IconData icon, required Color color, Color textColor = Colors.white, VoidCallback? onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: textColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Tajawal', fontSize: 13)),
      ),
    );
  }

  Widget _buildBottomNav(int pending) {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: AppColors.backgroundCard,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'الرئيسية', index: 0, currentIndex: _currentIndex, onTap: (i) => setState(() => _currentIndex = i)),
            _NavItem(icon: Icons.notifications_none_outlined, activeIcon: Icons.notifications, label: 'الإشعارات', index: 1, currentIndex: _currentIndex, onTap: (i) => setState(() => _currentIndex = i), badge: pending > 0 ? pending : null),
            _NavItem(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'الدردشات', index: 2, currentIndex: _currentIndex, onTap: (i) => setState(() => _currentIndex = i)),
            _NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'الإعدادات', index: 3, currentIndex: _currentIndex, onTap: (i) => setState(() => _currentIndex = i)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, currentIndex;
  final ValueChanged<int> onTap;
  final int? badge;

  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.index, required this.currentIndex, required this.onTap, this.badge});

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
            Stack(clipBehavior: Clip.none, children: [
              Icon(active ? activeIcon : icon, color: color, size: 24),
              if (badge != null) 
                Positioned(
                  top: -5, 
                  right: -8, 
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: AppColors.error, shape: BoxShape.circle, border: Border.all(color: AppColors.backgroundCard, width: 2)), 
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Center(child: Text('$badge', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'Tajawal')))
                  )
                ),
            ]),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: active ? FontWeight.w800 : FontWeight.w500, fontFamily: 'Tajawal')),
          ],
        ),
      ),
    );
  }
}
