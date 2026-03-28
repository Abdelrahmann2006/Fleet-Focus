import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leader_ui_provider.dart';
import '../../models/participant_card_model.dart';

/// شاشة إعدادات القائد
class LeaderSettingsScreen extends StatelessWidget {
  const LeaderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                children: [
                  _buildProfileSection(context),
                  const SizedBox(height: 20),
                  _buildDisplaySection(context),
                  const SizedBox(height: 20),
                  _buildCardFieldsSection(context),
                  const SizedBox(height: 20),
                  _buildDangerSection(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('الإعدادات',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  fontFamily: 'Tajawal')),
        ],
      ),
    );
  }

  // ── Profile Section ───────────────────────────────────────────

  Widget _buildProfileSection(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final name = user?.fullName ?? 'السيدة';
    final email = user?.email ?? '';

    return _SectionCard(
      title: 'الملف الشخصي',
      icon: Icons.person_outline,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        fontFamily: 'Tajawal')),
                if (email.isNotEmpty)
                  Text(email,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontFamily: 'Tajawal')),
              ],
            ),
            const SizedBox(width: 14),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFC9A84C), Color(0xFF8B6914)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  name.split(' ').take(2).map((w) => w[0]).join(),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      fontFamily: 'Tajawal'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Display Settings ──────────────────────────────────────────

  Widget _buildDisplaySection(BuildContext context) {
    final provider = context.watch<LeaderUIProvider>();

    return _SectionCard(
      title: 'إعدادات العرض',
      icon: Icons.display_settings_outlined,
      children: [
        _SettingRow(
          label: 'عرض شبكي',
          subtitle: provider.gridView ? 'عمودان' : 'قائمة',
          icon: provider.gridView ? Icons.grid_view_outlined : Icons.view_list_outlined,
          trailing: Switch(
            value: provider.gridView,
            onChanged: (_) => provider.toggleViewMode(),
            activeColor: AppColors.accent,
            inactiveTrackColor: AppColors.border,
          ),
        ),
      ],
    );
  }

  // ── Card Fields Section ───────────────────────────────────────

  Widget _buildCardFieldsSection(BuildContext context) {
    final provider = context.watch<LeaderUIProvider>();
    final visibleCount = provider.visibleFields.length;
    final totalCount = CardField.all.length;
    final categories = CardField.categoryLabels.keys.toList();

    return _SectionCard(
      title: 'حقول بطاقة المشارك',
      icon: Icons.tune_outlined,
      children: [
        // ملخص + أزرار سريعة
        Row(
          children: [
            Row(
              children: [
                _QuickBtn(
                  label: 'إخفاء الكل',
                  color: AppColors.error,
                  onTap: provider.hideAllFields,
                ),
                const SizedBox(width: 6),
                _QuickBtn(
                  label: 'افتراضي',
                  color: AppColors.info,
                  onTap: provider.resetFieldsToDefault,
                ),
                const SizedBox(width: 6),
                _QuickBtn(
                  label: 'عرض الكل',
                  color: AppColors.success,
                  onTap: provider.showAllFields,
                ),
              ],
            ),
            const Spacer(),
            Text('$visibleCount/$totalCount ظاهر',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontFamily: 'Tajawal')),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(color: AppColors.border, height: 1),

        // الحقول مجمّعة بالفئة
        ...categories.map((cat) {
          final fields = CardField.all.where((f) => f.category == cat).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 4),
                child: Text(
                  CardField.categoryLabels[cat]!,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                      letterSpacing: 0.5,
                      fontFamily: 'Tajawal'),
                ),
              ),
              ...fields.map((f) => _FieldToggleRow(field: f)),
            ],
          );
        }),
      ],
    );
  }

  // ── Danger Zone ───────────────────────────────────────────────

  Widget _buildDangerSection(BuildContext context) {
    return _SectionCard(
      title: 'منطقة الخطر',
      icon: Icons.warning_amber_outlined,
      iconColor: AppColors.error,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.read<AuthProvider>().signOut(),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.logout, color: AppColors.error, size: 16),
            label: const Text('تسجيل الخروج',
                style: TextStyle(
                    color: AppColors.error,
                    fontFamily: 'Tajawal',
                    fontSize: 14)),
          ),
        ),
      ],
    );
  }
}

// ── Sub-Widgets ───────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.iconColor = AppColors.accent,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              const Spacer(),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                      fontFamily: 'Tajawal')),
              const SizedBox(width: 8),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Widget trailing;

  const _SettingRow({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        trailing,
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.text,
                    fontFamily: 'Tajawal')),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontFamily: 'Tajawal')),
          ],
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 18, color: AppColors.textSecondary),
      ],
    );
  }
}

class _FieldToggleRow extends StatelessWidget {
  final CardField field;
  const _FieldToggleRow({required this.field});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LeaderUIProvider>();
    final visible = provider.isFieldVisible(field.key);
    return InkWell(
      onTap: () => provider.toggleField(field.key),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Switch(
              value: visible,
              onChanged: (_) => provider.toggleField(field.key),
              activeColor: AppColors.accent,
              inactiveTrackColor: AppColors.border,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const Spacer(),
            Text(field.label,
                style: TextStyle(
                    fontSize: 13,
                    color: visible ? AppColors.text : AppColors.textMuted,
                    fontFamily: 'Tajawal')),
          ],
        ),
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w700,
                fontFamily: 'Tajawal')),
      ),
    );
  }
}
