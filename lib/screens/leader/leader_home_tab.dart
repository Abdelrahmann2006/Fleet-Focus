import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leader_ui_provider.dart';
import '../../services/gemini_service.dart';
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
                    Expanded(child: _buildListOrGrid(context, filteredList)),
                  ],
                ),
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _openGeminiPanel(context, allParticipants),
                backgroundColor: const Color(0xFF1A1040),
                elevation: 4,
                icon: ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Color(0xFF9B59B6), Color(0xFFC39BD3)],
                  ).createShader(r),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                ),
                label: const Text('Gemini AI', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, color: Color(0xFFC39BD3), fontSize: 13)),
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
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: list.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: ParticipantCardWidget(p: list[i]),
      ),
    );
  }

  // ── لوحة Gemini AI للأوامر الطبيعية ──────────────────────────
  void _openGeminiPanel(BuildContext context, List<ParticipantCardModel> participants) {
    final cmdCtrl = TextEditingController();
    String? lastAnswer;
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F0B1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSB) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20)),
                    const Spacer(),
                    ShaderMask(
                      shaderCallback: (r) => const LinearGradient(colors: [Color(0xFF9B59B6), Color(0xFFE8DAFF)]).createShader(r),
                      child: const Text('مساعد Gemini AI', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.auto_awesome_rounded, color: Color(0xFF9B59B6), size: 22),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('اسألني عن أي عنصر، أو أعطني أمراً بلغتك الطبيعية', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
                const SizedBox(height: 16),
                if (lastAnswer != null)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A0F2E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF9B59B6).withOpacity(0.4)),
                    ),
                    child: Text(lastAnswer!, textAlign: TextAlign.right, textDirection: TextDirection.rtl,
                        style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 14, height: 1.5)),
                  ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: loading ? null : () async {
                        final q = cmdCtrl.text.trim();
                        if (q.isEmpty) return;
                        setSB(() => loading = true);
                        final ctx2 = {
                          'عدد_العناصر': participants.length,
                          'العناصر_النشطون': participants.where((p) => p.applicationStatus == 'approved_active').length,
                          'العناصر': participants.map((p) => '${p.name} (${p.applicationStatus})').join(', '),
                        };
                        final result = await GeminiService.instance.naturalQuery(q, ctx2);
                        setSB(() { lastAnswer = result.answer; loading = false; });
                        cmdCtrl.clear();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF7D3C98), Color(0xFF9B59B6)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1040),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF9B59B6).withOpacity(0.3)),
                        ),
                        child: TextField(
                          controller: cmdCtrl,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 14),
                          maxLines: 2,
                          minLines: 1,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            hintText: 'مثال: كم عنصر الآن؟',
                            hintStyle: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6, runSpacing: 6, alignment: WrapAlignment.end,
                  children: ['كم عناصري الآن؟', 'من لم يمتثل؟', 'من الأكثر نشاطاً؟'].map((s) =>
                    GestureDetector(
                      onTap: () { cmdCtrl.text = s; },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF9B59B6).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF9B59B6).withOpacity(0.3))),
                        child: Text(s, style: const TextStyle(color: Color(0xFFC39BD3), fontFamily: 'Tajawal', fontSize: 11)),
                      ),
                    )
                  ).toList(),
                ),
              ],
            ),
          ),
        ),
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
