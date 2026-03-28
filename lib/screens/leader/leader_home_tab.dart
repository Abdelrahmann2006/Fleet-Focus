import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/participant_card_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leader_ui_provider.dart';
import '../../providers/participant_stream_provider.dart';
import '../../widgets/participant_card_widget.dart';

/// تبويب الرئيسية — شبكة بطاقات المشاركين
///
/// [isActive] — يُعطَّل تحديث البيانات عندما لا يكون التبويب نشطاً
class LeaderHomeTab extends StatefulWidget {
  final bool isActive;
  const LeaderHomeTab({super.key, required this.isActive});

  @override
  State<LeaderHomeTab> createState() => _LeaderHomeTabState();
}

class _LeaderHomeTabState extends State<LeaderHomeTab> {
  final _searchCtrl = TextEditingController();

  @override
  void didUpdateWidget(LeaderHomeTab old) {
    super.didUpdateWidget(old);
    // عند activation: refresh mock فقط إن لم تتوفر بيانات حقيقية
    if (widget.isActive && !old.isActive) {
      final stream = context.read<ParticipantStreamProvider>();
      if (!stream.hasRealData) {
        context.read<LeaderUIProvider>().refreshMockData();
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            _buildSearchBar(context),
            _buildStatsRow(context),
            Expanded(child: _buildGrid(context)),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final name = user?.fullName?.split(' ').first ?? 'السيدة';
    final now = DateTime.now();
    final days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    final months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    final dateStr = '${days[now.weekday % 7]}، ${now.day} ${months[now.month - 1]}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D0D1A), Color(0xFF12122A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          // أيقونة الإشعارات
          _NotificationButton(),
          const Spacer(),
          // تحية + تاريخ
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                          fontFamily: 'Tajawal')),
                  const SizedBox(width: 6),
                  const Text('أهلاً،',
                      style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontFamily: 'Tajawal')),
                ],
              ),
              Text(dateStr,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontFamily: 'Tajawal')),
            ],
          ),
          const SizedBox(width: 12),
          // شعار القائد
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFC9A84C), Color(0xFF8B6914)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.black, size: 20),
          ),
        ],
      ),
    );
  }

  // ── Search Bar ────────────────────────────────────────────────

  Widget _buildSearchBar(BuildContext context) {
    final provider = context.watch<LeaderUIProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          // زر Grid/List
          GestureDetector(
            onTap: () => context.read<LeaderUIProvider>().toggleViewMode(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                provider.gridView ? Icons.view_list_outlined : Icons.grid_view_outlined,
                color: AppColors.accent,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // حقل البحث
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _searchCtrl,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.text, fontFamily: 'Tajawal'),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  hintText: 'بحث بالاسم أو الكود…',
                  hintStyle: const TextStyle(
                      fontSize: 13, color: AppColors.textMuted, fontFamily: 'Tajawal'),
                  suffixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 18),
                ),
                onChanged: (q) => context.read<LeaderUIProvider>().search(q),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats Row ─────────────────────────────────────────────────

  Widget _buildStatsRow(BuildContext context) {
    final streamProvider = context.watch<ParticipantStreamProvider>();
    final uiProvider     = context.watch<LeaderUIProvider>();
    // تفضيل البيانات الحقيقية — الرجوع للـ mock عند الغياب
    final participants = streamProvider.hasRealData
        ? streamProvider.participants
        : uiProvider.participants;
    final active  = participants.where((p) => p.livePulse == LivePulse.active).length;
    final idle    = participants.where((p) => p.livePulse == LivePulse.idle).length;
    final offline = participants.where((p) => p.livePulse == LivePulse.offline).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          _StatBadge(label: 'الكل', value: participants.length, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          _StatBadge(label: 'نشط', value: active, color: AppColors.success),
          const SizedBox(width: 8),
          _StatBadge(label: 'خامل', value: idle, color: AppColors.warning),
          const SizedBox(width: 8),
          _StatBadge(label: 'غائب', value: offline, color: AppColors.error),
          const Spacer(),
          // زر إعدادات البطاقة
          GestureDetector(
            onTap: () => _showFieldSettingsSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_outlined, size: 14, color: AppColors.accent),
                  SizedBox(width: 4),
                  Text('البطاقة',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Tajawal')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Grid / List ───────────────────────────────────────────────

  Widget _buildGrid(BuildContext context) {
    final provider       = context.watch<LeaderUIProvider>();
    final streamProvider = context.watch<ParticipantStreamProvider>();

    // ⚡ الجسر الحيوي: استخدام البيانات الحقيقية عند توفّرها
    final List<ParticipantCardModel> list = streamProvider.hasRealData
        ? streamProvider.search(_searchCtrl.text)
        : provider.participants;

    if (list.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_outlined, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text('لا توجد نتائج',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontFamily: 'Tajawal',
                    fontSize: 15)),
          ],
        ),
      );
    }

    if (provider.gridView) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.78,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: list.length,
        itemBuilder: (_, i) => ParticipantCardWidget(p: list[i]),
      );
    } else {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => ParticipantCardWidget(p: list[i]),
      );
    }
  }

  // ── Field Settings Bottom Sheet ───────────────────────────────

  void _showFieldSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<LeaderUIProvider>(),
        child: const _FieldSettingsSheet(),
      ),
    );
  }
}

// ── Field Settings Sheet ──────────────────────────────────────

class _FieldSettingsSheet extends StatelessWidget {
  const _FieldSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LeaderUIProvider>();
    final categories = CardField.categoryLabels.keys.toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, sc) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Row(
                  children: [
                    TextButton(
                      onPressed: provider.hideAllFields,
                      child: const Text('إخفاء الكل',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.error,
                              fontFamily: 'Tajawal')),
                    ),
                    TextButton(
                      onPressed: provider.resetFieldsToDefault,
                      child: const Text('افتراضي',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.info,
                              fontFamily: 'Tajawal')),
                    ),
                    TextButton(
                      onPressed: provider.showAllFields,
                      child: const Text('عرض الكل',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.success,
                              fontFamily: 'Tajawal')),
                    ),
                  ],
                ),
                const Spacer(),
                const Text('تخصيص البطاقة',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        fontFamily: 'Tajawal')),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          // List
          Expanded(
            child: ListView.builder(
              controller: sc,
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: categories.length,
              itemBuilder: (_, ci) {
                final cat = categories[ci];
                final fields = CardField.all.where((f) => f.category == cat).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                      child: Text(
                        CardField.categoryLabels[cat]!,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                            fontFamily: 'Tajawal',
                            letterSpacing: 0.5),
                      ),
                    ),
                    ...fields.map((f) => SwitchListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 0),
                          title: Text(f.label,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.text,
                                  fontFamily: 'Tajawal')),
                          value: provider.isFieldVisible(f.key),
                          onChanged: (_) => provider.toggleField(f.key),
                          activeColor: AppColors.accent,
                          inactiveTrackColor: AppColors.border,
                        )),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Notification Button ───────────────────────────────────────

class _NotificationButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(
            Icons.notifications_outlined,
            color: AppColors.textSecondary,
            size: 20,
          ),
        ),
        Positioned(
          top: 2,
          left: 2,
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Stat Badge ────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontFamily: 'Tajawal')),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontFamily: 'Tajawal')),
        ],
      ),
    );
  }
}
