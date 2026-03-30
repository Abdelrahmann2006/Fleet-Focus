import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leader_ui_provider.dart';
import '../../widgets/participant_card_widget.dart';
import '../../models/participant_card_model.dart';

class LeaderHomeTab extends StatefulWidget {
  final bool isActive;
  const LeaderHomeTab({super.key, required this.isActive});

  @override
  State<LeaderHomeTab> createState() => _LeaderHomeTabState();
}

class _LeaderHomeTabState extends State<LeaderHomeTab> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Center(child: CircularProgressIndicator());

    // ── 1. الاستماع لبيانات السيدة الحالية لجلب كودها ──
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnap) {
        final leaderData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final leaderCode = leaderData['leaderCode'] ?? '';

        // ── 2. الاستماع الحي للعناصر الحقيقيين فقط ──
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('linkedLeaderCode', isEqualTo: leaderCode)
              .where('role', isEqualTo: 'participant')
              .snapshots(),
          builder: (context, partSnap) {
            final docs = partSnap.data?.docs ?? [];
            
            // ── تحويل البيانات باستخدام الموديل الجديد (fromFirestore) ──
            final List<ParticipantCardModel> allParticipants = docs.map((doc) {
              return ParticipantCardModel.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
            }).toList();

            // تطبيق فلتر البحث
            final filteredList = allParticipants.where((p) {
              final query = _searchCtrl.text.toLowerCase();
              return p.name.toLowerCase().contains(query) || p.uid.contains(query);
            }).toList();

            return Scaffold(
              backgroundColor: AppColors.background,
              body: SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(context, leaderData),
                    _buildSearchBar(context),
                    _buildStatsRow(allParticipants),
                    Expanded(child: _buildListOrGrid(context, filteredList)), // تم تعديل اسم الدالة
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context, Map<String, dynamic> leaderData) {
    final name = leaderData['fullName']?.split(' ').first ?? 'السيدة';
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
          const Icon(Icons.notifications_outlined, color: AppColors.textSecondary, size: 20),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.accent, fontFamily: 'Tajawal')),
                  const SizedBox(width: 6),
                  const Text('أهلاً،', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
                ],
              ),
              Text(dateStr, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontFamily: 'Tajawal')),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFFC9A84C), Color(0xFF8B6914)]),
              boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 8)],
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
          GestureDetector(
            onTap: () => context.read<LeaderUIProvider>().toggleViewMode(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
              child: Icon(provider.gridView ? Icons.view_list_outlined : Icons.grid_view_outlined, color: AppColors.accent, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
              child: TextField(
                controller: _searchCtrl,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13, color: AppColors.text, fontFamily: 'Tajawal'),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  hintText: 'بحث باسم العنصر…',
                  hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted, fontFamily: 'Tajawal'),
                  suffixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 18),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats Row ─────────────────────────────────────────────────
  Widget _buildStatsRow(List<ParticipantCardModel> participants) {
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
          const Icon(Icons.pan_tool_alt_outlined, size: 14, color: AppColors.accent),
          const SizedBox(width: 4),
          const Text('Panopticon', style: TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')),
        ],
      ),
    );
  }

  // ── Grid / List (التعديل الجذري هنا لحل مشكلة الأزرار) ─────────
  Widget _buildListOrGrid(BuildContext context, List<ParticipantCardModel> list) {
    final provider = context.watch<LeaderUIProvider>();

    if (list.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_off_outlined, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text('لا يوجد عناصر مسجلة بعد', style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 15)),
            Text('شارك الكود الخاص بك للبدء', style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
          ],
        ),
      );
    }

    // إذا كان العرض شبكي (Grid)
    if (provider.gridView) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          // قد تحتاج لتقليل هذا الرقم إذا كانت الأزرار مقصوصة في وضع الشبكة أيضاً
          childAspectRatio: 0.55, 
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: list.length,
        itemBuilder: (_, i) => ParticipantCardWidget(p: list[i]),
      );
    } 
    
    // إذا كان العرض قائمة (List) - وهو الوضع الافتراضي في صورك
    // استخدام ListView.builder يسمح للبطاقة بأخذ الارتفاع الذي تحتاجه (Wrap Content)
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80), // مسافة من الأسفل لعدم تغطية الفلوتنج باتون
      itemCount: list.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: ParticipantCardWidget(p: list[i]),
      ),
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
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.25))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color, fontFamily: 'Tajawal')),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
        ],
      ),
    );
  }
}
