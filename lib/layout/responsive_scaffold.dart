import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/colors.dart';
import 'breakpoints.dart';

/// ResponsiveScaffold — هيكل التخطيط المتجاوب
///
/// موبايل:  Scaffold عادي + AppBar + Drawer
/// تابلت:   Sidebar مُطوي (عرض 72px) + محتوى
/// ديسكتوب: Sidebar كامل (عرض 260px) + محتوى + شريط علوي

class ResponsiveScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<SidebarItem> navItems;
  final int currentIndex;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  const ResponsiveScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.navItems,
    required this.currentIndex,
    this.floatingActionButton,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final type = context.deviceType;
    switch (type) {
      case DeviceType.mobile:
        return _MobileLayout(
            title: title,
            body: body,
            navItems: navItems,
            currentIndex: currentIndex,
            actions: actions,
            floatingActionButton: floatingActionButton);
      case DeviceType.tablet:
        return _TabletLayout(
            title: title,
            body: body,
            navItems: navItems,
            currentIndex: currentIndex,
            actions: actions,
            floatingActionButton: floatingActionButton);
      case DeviceType.desktop:
        return _DesktopLayout(
            title: title,
            body: body,
            navItems: navItems,
            currentIndex: currentIndex,
            actions: actions,
            floatingActionButton: floatingActionButton);
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  موبايل — AppBar + Drawer
// ─────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final String title;
  final Widget body;
  final List<SidebarItem> navItems;
  final int currentIndex;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  const _MobileLayout({
    required this.title,
    required this.body,
    required this.navItems,
    required this.currentIndex,
    this.floatingActionButton,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundCard,
        elevation: 0,
        title: Text(title,
            style: const TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontSize: 18)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.accent),
        actions: actions,
      ),
      drawer: _SidebarDrawer(navItems: navItems, currentIndex: currentIndex),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  تابلت — Sidebar مُطوي + محتوى
// ─────────────────────────────────────────────────────────────

class _TabletLayout extends StatelessWidget {
  final String title;
  final Widget body;
  final List<SidebarItem> navItems;
  final int currentIndex;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  const _TabletLayout({
    required this.title,
    required this.body,
    required this.navItems,
    required this.currentIndex,
    this.floatingActionButton,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // شريط جانبي مضغوط
          _CollapsedSidebar(navItems: navItems, currentIndex: currentIndex),
          // المحتوى الرئيسي
          Expanded(
            child: Column(
              children: [
                _TopBar(title: title, actions: actions),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ديسكتوب — Sidebar كامل + محتوى
// ─────────────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  final String title;
  final Widget body;
  final List<SidebarItem> navItems;
  final int currentIndex;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  const _DesktopLayout({
    required this.title,
    required this.body,
    required this.navItems,
    required this.currentIndex,
    this.floatingActionButton,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // شريط جانبي كامل
          _FullSidebar(navItems: navItems, currentIndex: currentIndex),
          // المحتوى الرئيسي
          Expanded(
            child: Column(
              children: [
                _TopBar(title: title, actions: actions),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  مكونات مشتركة
// ─────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;

  const _TopBar({required this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontSize: 20)),
          const Spacer(),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

class _FullSidebar extends StatelessWidget {
  final List<SidebarItem> navItems;
  final int currentIndex;

  const _FullSidebar({required this.navItems, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: double.infinity,
      color: AppColors.backgroundCard,
      child: Column(
        children: [
          // شعار + اسم القائد
          _SidebarHeader(showLabel: true),
          const SizedBox(height: 16),
          // عناصر القائمة
          Expanded(
            child: ListView.builder(
              itemCount: navItems.length,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (_, i) => _NavTile(
                item: navItems[i],
                selected: i == currentIndex,
                showLabel: true,
              ),
            ),
          ),
          // تذييل
          _SidebarFooter(showLabel: true),
        ],
      ),
    );
  }
}

class _CollapsedSidebar extends StatelessWidget {
  final List<SidebarItem> navItems;
  final int currentIndex;

  const _CollapsedSidebar({required this.navItems, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: double.infinity,
      color: AppColors.backgroundCard,
      child: Column(
        children: [
          _SidebarHeader(showLabel: false),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: navItems.length,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemBuilder: (_, i) => _NavTile(
                item: navItems[i],
                selected: i == currentIndex,
                showLabel: false,
              ),
            ),
          ),
          _SidebarFooter(showLabel: false),
        ],
      ),
    );
  }
}

class _SidebarDrawer extends StatelessWidget {
  final List<SidebarItem> navItems;
  final int currentIndex;

  const _SidebarDrawer({required this.navItems, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.backgroundCard,
      child: Column(
        children: [
          _SidebarHeader(showLabel: true),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: navItems.length,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (_, i) => _NavTile(
                item: navItems[i],
                selected: i == currentIndex,
                showLabel: true,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          _SidebarFooter(showLabel: true),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  final bool showLabel;
  const _SidebarHeader({required this.showLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
      child: Row(
        mainAxisAlignment:
            showLabel ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.accent, AppColors.accentDark],
              ),
            ),
            child: const Icon(Icons.military_tech,
                color: Colors.black, size: 22),
          ),
          if (showLabel) ...[
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('نظام المسابقة',
                    style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontSize: 15)),
                Text('لوحة القائد',
                    style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: AppColors.textMuted,
                        fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  final bool showLabel;
  const _SidebarFooter({required this.showLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.go('/'),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment:
                showLabel ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout_outlined,
                  color: AppColors.error, size: 20),
              if (showLabel) ...[
                const SizedBox(width: 12),
                const Text('تسجيل الخروج',
                    style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: AppColors.error,
                        fontSize: 14)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final SidebarItem item;
  final bool selected;
  final bool showLabel;
  final VoidCallback? onTap;

  const _NavTile({
    required this.item,
    required this.selected,
    required this.showLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: selected ? AppColors.accent.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: selected
            ? Border.all(color: AppColors.accent.withOpacity(0.3))
            : null,
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          item.icon,
          color: selected ? AppColors.accent : AppColors.textMuted,
          size: 22,
        ),
        title: showLabel
            ? Text(item.label,
                style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: selected ? AppColors.accent : AppColors.textSecondary,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 14))
            : null,
        onTap: () {
          onTap?.call();
          if (item.route != null) context.go(item.route!);
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Model
// ─────────────────────────────────────────────────────────────

class SidebarItem {
  final IconData icon;
  final String label;
  final String? route;

  const SidebarItem({
    required this.icon,
    required this.label,
    this.route,
  });
}
