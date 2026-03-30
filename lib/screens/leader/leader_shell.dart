import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
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
    // جلب عدد الطلبات المعلقة لإظهاره كإشعار (Badge) على الأيقونة
    final pendingCount = context.watch<ParticipantStreamProvider>().pendingCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // الخانة 0: الشاشة الرئيسية
          LeaderHomeTab(isActive: _currentIndex == 0),
          
          // الخانة 1: مركز الإشعارات (كانت شاشة الطلبات سابقاً)
          const JoinRequestsScreen(),
          
          // الخانة 2: الدردشات (بديلة لشاشة التقارير)
          const Center(
            child: Text(
              'شاشة الدردشات قيد التطوير',
              style: TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 16),
            ),
          ),
          
          // الخانة 3: الإعدادات
          const LeaderSettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        height: 70,
        decoration: const BoxDecoration(
          color: AppColors.backgroundCard,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: Row(
          children: [
            // الرئيسية
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'الرئيسية',
              index: 0,
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
            ),
            
            // الإشعارات (مع الـ Badge للطلبات المعلقة)
            _NavItem(
              icon: Icons.notifications_none_outlined,
              activeIcon: Icons.notifications,
              label: 'الإشعارات',
              index: 1,
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              badge: pendingCount > 0 ? pendingCount : null,
            ),
            
            // الدردشات (بديلة للتقارير)
            _NavItem(
              icon: Icons.chat_bubble_outline,
              activeIcon: Icons.chat_bubble,
              label: 'الدردشات',
              index: 2,
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
            ),
            
            // الإعدادات
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
}

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
                Icon(active ? activeIcon : icon, color: color, size: 22),
                if (badge != null)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.backgroundCard, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          '$badge',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
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
                fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
