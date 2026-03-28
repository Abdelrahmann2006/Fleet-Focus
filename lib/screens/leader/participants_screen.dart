import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/colors.dart';

class ParticipantsScreen extends StatefulWidget {
  const ParticipantsScreen({super.key});

  @override
  State<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends State<ParticipantsScreen> {
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _statusFilter = 'all';
  String _searchQuery = '';

  final _statusColors = {
    'pending': AppColors.warning,
    'submitted': AppColors.accent,
    'approved': AppColors.success,
  };
  final _statusLabels = {
    'pending': 'لم يكمل',
    'submitted': 'بانتظار المراجعة',
    'approved': 'موافق عليه',
  };

  @override
  void initState() {
    super.initState();
    _fetchParticipants();
  }

  Future<void> _fetchParticipants() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final code = userDoc.data()?['leaderCode'] ?? '';
    if (code.isEmpty) { setState(() => _loading = false); return; }
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('linkedLeaderCode', isEqualTo: code)
        .where('role', isEqualTo: 'participant')
        .get();
    final list = snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
    setState(() { _all = list; _loading = false; });
    _applyFilter();
  }

  void _applyFilter() {
    setState(() {
      _filtered = _all.where((p) {
        final matchStatus = _statusFilter == 'all' || p['applicationStatus'] == _statusFilter;
        final matchSearch = _searchQuery.isEmpty ||
            (p['displayName'] ?? '').toString().contains(_searchQuery) ||
            (p['email'] ?? '').toString().contains(_searchQuery);
        return matchStatus && matchSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(icon: const Icon(Icons.arrow_forward, color: AppColors.textSecondary), onPressed: () => context.pop()),
        title: Column(children: [
          const Text('المتسابقون', style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
          Text('${_filtered.length} من ${_all.length}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontFamily: 'Tajawal')),
        ]),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              onChanged: (v) { _searchQuery = v; _applyFilter(); },
              style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal'),
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو البريد...',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal'),
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                filled: true, fillColor: AppColors.backgroundCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['all', 'pending', 'submitted', 'approved'].map((f) {
                final active = _statusFilter == f;
                final label = f == 'all' ? 'الكل' : _statusLabels[f] ?? f;
                final color = f == 'all' ? AppColors.accent : _statusColors[f] ?? AppColors.accent;
                return GestureDetector(
                  onTap: () { _statusFilter = f; _applyFilter(); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? color.withOpacity(0.15) : AppColors.backgroundCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? color.withOpacity(0.5) : AppColors.border),
                    ),
                    child: Text(label,
                        style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                            color: active ? color : AppColors.textMuted, fontFamily: 'Tajawal')),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : _filtered.isEmpty
                    ? const Center(child: Text('لا يوجد نتائج', style: TextStyle(fontSize: 16, color: AppColors.textMuted, fontFamily: 'Tajawal')))
                    : RefreshIndicator(
                        onRefresh: _fetchParticipants,
                        color: AppColors.accent,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final p = _filtered[i];
                            final status = p['applicationStatus'] ?? 'pending';
                            final color = _statusColors[status] ?? AppColors.warning;
                            return GestureDetector(
                              onTap: () => context.push('/leader/participant/${p['uid']}'),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundCard,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.chevron_left, color: AppColors.textMuted),
                                    const Spacer(),
                                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                      Text(p['displayName'] ?? 'مجهول',
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text, fontFamily: 'Tajawal')),
                                      const SizedBox(height: 3),
                                      Row(children: [
                                        Text(_statusLabels[status] ?? '', style: TextStyle(fontSize: 12, color: color, fontFamily: 'Tajawal')),
                                        const SizedBox(width: 5),
                                        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                      ]),
                                    ]),
                                    const SizedBox(width: 12),
                                    Container(width: 44, height: 44,
                                        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), shape: BoxShape.circle),
                                        child: Center(child: Text((p['displayName'] ?? 'م').substring(0, 1).toUpperCase(),
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.accent, fontFamily: 'Tajawal')))),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
