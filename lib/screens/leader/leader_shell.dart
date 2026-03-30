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
import 'join_requests_screen.dart'; // ستعمل كمركز للإشعارات بناءً على طلبك
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
    // جلب عدد الطلبات المعلقة من الـ Provider لإظهاره كإشعار (Badge)
    final pendingCount = context.watch<ParticipantStreamProvider>().pendingCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // الخانة 0: الرئيسية
          LeaderHomeTab(isActive: _currentIndex == 0),
          
          // الخانة 1: الإشعارات (كانت "الطلبات" سابقاً)
          const JoinRequestsScreen(),
          
          // الخانة 2: الدردشات (كانت "التقارير" سابقاً)
          const Center(
            child: Text(
              'شاشة الدردشات قيد التطوير',
              style: TextStyle(
                color: Colors.white, 
                fontFamily: 'Tajawal', 
                fontSize: 16
              ),
            ),
          ),
          
          // الخانة 3: الإعدادات
          const LeaderSettingsScreen(),
        ],
      ),
      
      // زر إضافة عنصر (يظهر فقط في التبويب الرئيسي)
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showGenerateCodeDialog(context),
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text(
                'إضافة عنصر', 
                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')
              ),
            )
          : null,

      bottomNavigationBar: Container(
        height: 70,
        decoration: const BoxDecoration(
          color: AppColors.backgroundCard,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: Row(
          children: [
            // تبويب الرئيسية
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'الرئيسية',
              index: 0,
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
            ),
            
            // تبويب الإشعارات (مع عداد الطلبات)
            _NavItem(
              icon: Icons.notifications_none_outlined,
              activeIcon: Icons.notifications,
              label: 'الإشعارات',
              index: 1,
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              badge: pendingCount > 0 ? pendingCount : null,
            ),
            
            // تبويب الدردشات (بديل التقارير)
            _NavItem(
              icon: Icons.chat_bubble_outline,
              activeIcon: Icons.chat_bubble,
              label: 'الدردشات',
              index: 2,
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
            ),
            
            // تبويب الإعدادات
            _NavItem(
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings,
              label: 'الإعدادات',
              index: 3,
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
            ),
          ],
        ),
      ),
    );
  }

  // دالة توليد كود انضمام جديد (بروتوكول السيدة)
  void _showGenerateCodeDialog(BuildContext context) {
    final code = Random().nextInt(899999) + 100000;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'كود انضمام جديد', 
          textAlign: TextAlign.right, 
          style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'شارك هذا الكود مع العنصر المراد ضمه للنظام. هذا الكود صالح للاستخدام مرة واحدة فقط.', 
              textAlign: TextAlign.right,
              style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 13)
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.background, 
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withOpacity(0.3))
              ),
              child: SelectableText(
                '$code', 
                style: const TextStyle(
                  fontSize: 36, 
                  fontWeight: FontWeight.w900, 
                  color: AppColors.accent, 
                  letterSpacing: 6,
                  fontFamily: 'Courier'
                )
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('إغلاق', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textMuted))
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '$code'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم نسخ الكود إلى الحافظة', style: TextStyle(fontFamily: 'Tajawal')),
                  backgroundColor: AppColors.success,
                ),
              );
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
            ),
            icon: const Icon(Icons.copy_all, size: 18),
            label: const Text('نسخ الكود', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
  }
}

// ويدجت أيقونة التنقل السفلي
class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, currentIndex;
  final ValueChanged<int> onTap;
  final int? badge;

  const _NavItem({
    required this.icon, 
    required this.activeIcon, 
    required this.label, 
    required this.index, 
    required this.currentIndex, 
    required this.onTap, 
    this.badge
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
                Icon(active ? activeIcon : icon, color: color, size: 24),
                if (badge != null) 
                  Positioned(
                    top: -5, 
                    right: -8, 
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.error, 
                        shape: BoxShape.circle, 
                        border: Border.all(color: AppColors.backgroundCard, width: 2)
                      ), 
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Center(
                        child: Text(
                          '$badge', 
                          style: const TextStyle(
                            fontSize: 10, 
                            fontWeight: FontWeight.w900, 
                            color: Colors.white,
                            fontFamily: 'Tajawal'
                          )
                        )
                      )
                    )
                  ),
              ]
            ),
            const SizedBox(height: 4),
            Text(
              label, 
              style: TextStyle(
                fontSize: 10, 
                color: color, 
                fontWeight: active ? FontWeight.w800 : FontWeight.w500, 
                fontFamily: 'Tajawal'
              )
            ),
          ],
        ),
      ),
    );
  }
}
