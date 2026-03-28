import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../constants/colors.dart';

class ParticipantDetailScreen extends StatefulWidget {
  final String uid;
  const ParticipantDetailScreen({super.key, required this.uid});

  @override
  State<ParticipantDetailScreen> createState() => _ParticipantDetailScreenState();
}

class _ParticipantDetailScreenState extends State<ParticipantDetailScreen> {
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _appData;
  bool _loading = true;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
    setState(() => _userData = userDoc.data());
    try {
      final appDoc = await FirebaseFirestore.instance.collection('participants').doc(widget.uid).get();
      if (appDoc.exists) setState(() => _appData = appDoc.data());
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _updateStatus(String status) async {
    final label = status == 'approved' ? 'الموافقة' : 'الرفض';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: Text('تأكيد $label', style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal')),
        content: Text('هل تريد $label على هذا المتسابق؟', style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal'), textAlign: TextAlign.right),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(label, style: TextStyle(color: status == 'approved' ? AppColors.success : AppColors.error, fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _updating = true);
    await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'applicationStatus': status});
    setState(() { _userData?['applicationStatus'] = status; _updating = false; });
  }

  @override
  Widget build(BuildContext context) {
    final status = _userData?['applicationStatus'] ?? 'pending';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(icon: const Icon(Icons.arrow_forward, color: AppColors.textSecondary), onPressed: () => context.pop()),
        title: const Text('تفاصيل المتسابق', style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal')),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), shape: BoxShape.circle),
                    child: Center(child: Text(
                      (_userData?['displayName'] ?? 'م').substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.accent, fontFamily: 'Tajawal'),
                    )),
                  ),
                  const SizedBox(height: 12),
                  Text(_userData?['displayName'] ?? 'مجهول',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text, fontFamily: 'Tajawal')),
                  Text(_userData?['email'] ?? '',
                      style: const TextStyle(fontSize: 14, color: AppColors.textMuted, fontFamily: 'Tajawal')),
                  const SizedBox(height: 24),

                  // Status
                  _InfoCard(title: 'الحالة', items: {
                    'حالة الطلب': _statusLabel(status),
                    'البيومترية': (_userData?['biometricEnabled'] == true) ? 'مفعّل' : 'غير مفعّل',
                    'إعداد الجهاز': (_userData?['deviceSetupComplete'] == true) ? 'مكتمل ✓' : 'غير مكتمل',
                    'كود القائد': _userData?['linkedLeaderCode'] ?? '—',
                  }),
                  const SizedBox(height: 16),

                  // Form data if submitted
                  if (_appData != null) ...[
                    _InfoCard(title: 'البيانات الأساسية', items: {
                      'الاسم الكامل': _appData?['basic_info']?['full_name'] ?? '—',
                      'تاريخ الميلاد': _appData?['basic_info']?['date_of_birth'] ?? '—',
                      'الجنسية': _appData?['basic_info']?['nationality'] ?? '—',
                    }),
                    const SizedBox(height: 16),
                  ],

                  // Action buttons
                  if (status != 'approved')
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _updating ? null : () => _updateStatus('approved'),
                        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                        label: const Text('الموافقة على المتسابق',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Tajawal')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  if (status == 'approved') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _updating ? null : () => _updateStatus('pending'),
                        icon: const Icon(Icons.undo, color: AppColors.warning),
                        label: const Text('إلغاء الموافقة',
                            style: TextStyle(fontSize: 16, color: AppColors.warning, fontFamily: 'Tajawal')),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.warning),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  String _statusLabel(String s) =>
      s == 'approved' ? 'موافق عليه ✓' : s == 'submitted' ? 'بانتظار المراجعة' : 'لم يكمل الاستمارة';
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Map<String, String> items;
  const _InfoCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.accent, fontFamily: 'Tajawal')),
          const Divider(color: AppColors.border, height: 20),
          ...items.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(e.value, style: const TextStyle(fontSize: 14, color: AppColors.text, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
                Text(e.key, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
