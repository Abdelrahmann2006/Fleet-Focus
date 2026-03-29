import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/stage_light_background.dart';
import '../../widgets/cdn_audio_player.dart';
import '../../constants/colors.dart';
import '../../layout/breakpoints.dart';
import '../../layout/responsive_scaffold.dart';

class LeaderDashboardScreen extends StatefulWidget {
  const LeaderDashboardScreen({super.key});

  @override
  State<LeaderDashboardScreen> createState() => _LeaderDashboardScreenState();
}

class _LeaderDashboardScreenState extends State<LeaderDashboardScreen> {
  bool _codeCopied = false;

  static const _statusColors = {
    'pending':   Color(0xFFDD6B20),
    'submitted': Color(0xFFC9A84C),
    'approved':  Color(0xFF38A169),
    'rejected':  Color(0xFFE53E3E),
  };
  static const _statusLabels = {
    'pending':   'لم يكمل',
    'submitted': 'بانتظار المراجعة',
    'approved':  'موافق عليه',
    'rejected':  'مرفوض',
  };

  static const List<SidebarItem> _navItems = [
    SidebarItem(icon: Icons.dashboard_outlined,     label: 'لوحة التحكم',  route: '/leader/dashboard'),
    SidebarItem(icon: Icons.group_outlined,         label: 'العناصر',      route: '/leader/participants'),
    SidebarItem(icon: Icons.phone_android_outlined, label: 'إدارة الأجهزة', route: '/leader/devices'),
    SidebarItem(icon: Icons.notifications_outlined, label: 'الإشعارات'),
    SidebarItem(icon: Icons.settings_outlined,      label: 'الإعدادات'),
  ];

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    setState(() => _codeCopied = true);
    Future.delayed(const Duration(seconds: 2), () => setState(() => _codeCopied = false));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.accent)));

    // ── 1. الاستماع لبيانات السيدة لجلب كود الربط الحالي ──
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnap) {
        final leaderData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final leaderCode = leaderData['leaderCode'] ?? '';
        final firstName = leaderData['fullName']?.split(' ').first ?? 'السيدة';

        // ── 2. الاستماع الحي للعناصر المربوطين بهذا الكود فقط ──
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('linkedLeaderCode', isEqualTo: leaderCode)
              .where('role', isEqualTo: 'participant')
              .snapshots(),
          builder: (context, partSnap) {
            final participants = partSnap.data?.docs
                .map((d) => {'uid': d.id, ...d.data() as Map<String, dynamic>})
                .toList() ?? [];

            final total     = participants.length;
            final submitted = participants.where((p) => p['applicationStatus'] == 'submitted').length;
            final approved  = participants.where((p) => p['applicationStatus'] == 'approved').length;
            final pending   = participants.where((p) => p['applicationStatus'] == 'pending').length;

            if (kIsWeb || context.isTablet || context.isDesktop) {
              return ResponsiveScaffold(
                title: 'Panopticon — لوحة السيدة',
                currentIndex: 0,
                navItems: _navItems,
                actions: [
                  _BuzzerActionButton(),
                  const SizedBox(width: 12),
                  _LogoutButton(),
                  const SizedBox(width: 16),
                ],
                body: _buildWebContent(firstName, leaderCode, participants, total, submitted, approved, pending),
              );
            }

            return Scaffold(
              backgroundColor: AppColors.background,
              body: Stack(
                children: [
                  const StageLightBackground(),
                  SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildMobileContent(firstName, leaderCode, participants, total, submitted, approved, pending),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWebContent(String name, String code, List<Map<String, dynamic>> parts, int tot, int sub, int app, int pen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(child: _LeaderCodeCard(leaderCode: code, codeCopied: _codeCopied, onCopy: () => _copyCode(code))),
              const SizedBox(width: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('أهلاً، $name', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text, fontFamily: 'Tajawal')),
                  Text('لديك $tot عنصر مسجل في النظام', style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _WebStatCard(label: 'إجمالي العناصر', value: tot, icon: Icons.group, color: AppColors.accent),
              const SizedBox(width: 16),
              _WebStatCard(label: 'بانتظار المراجعة', value: sub, icon: Icons.hourglass_top, color: const Color(0xFFC9A84C)),
              const SizedBox(width: 16),
              _WebStatCard(label: 'تمت الموافقة', value: app, icon: Icons.check_circle_outline, color: AppColors.success),
              const SizedBox(width: 16),
              _WebStatCard(label: 'معلّق', value: pen, icon: Icons.pending_outlined, color: AppColors.warning),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildParticipantsHeader(),
        if (parts.isEmpty) _EmptyState() else _WebParticipantsTable(participants: parts, statusColors: _statusColors, statusLabels: _statusLabels, onTap: (uid) => context.push('/leader/participant/$uid')),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildMobileContent(String name, String code, List<Map<String, dynamic>> parts, int tot, int sub, int app, int pen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _LogoutButton(),
            Text('أهلاً، $name', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text, fontFamily: 'Tajawal')),
          ],
        ),
        const SizedBox(height: 20),
        _LeaderCodeCard(leaderCode: code, codeCopied: _codeCopied, onCopy: () => _copyCode(code)),
        const SizedBox(height: 20),
        Row(children: [
          _StatCard(label: 'إجمالي', value: tot, color: AppColors.accent),
          const SizedBox(width: 10),
          _StatCard(label: 'مراجعة', value: sub, color: const Color(0xFFC9A84C)),
          const SizedBox(width: 10),
          _StatCard(label: 'موافق', value: app, color: AppColors.success),
          const SizedBox(width: 10),
          _StatCard(label: 'معلق', value: pen, color: AppColors.warning),
        ]),
        const SizedBox(height: 28),
        _buildParticipantsHeader(),
        const SizedBox(height: 8),
        if (parts.isEmpty) _EmptyState() else ...parts.take(10).map((p) => _ParticipantCard(participant: p, statusColors: _statusColors, statusLabels: _statusLabels, onTap: () => context.push('/leader/participant/${p['uid']}'))),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildParticipantsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(onPressed: () => context.push('/leader/participants'), child: const Text('عرض الكل', style: TextStyle(fontSize: 14, color: AppColors.accent, fontFamily: 'Tajawal'))),
          const Text('العناصر الحالية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text, fontFamily: 'Tajawal')),
        ],
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────
//  مكوّنات الواجهة التكميلية (Widgets)
// ─────────────────────────────────────────────────────────────

  // جدول العناصر للويب
  Widget _WebParticipantsTable({
    required List<Map<String, dynamic>> participants,
    required Map<String, Color> statusColors,
    required Map<String, String> statusLabels,
    required void Function(String uid) onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(0.5),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(1.5),
            4: FlexColumnWidth(1),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: AppColors.backgroundElevated),
              children: const [
                _TableHeader('#'),
                _TableHeader('الاسم'),
                _TableHeader('البريد الإلكتروني'),
                _TableHeader('الحالة'),
                _TableHeader('إجراء'),
              ],
            ),
            ...participants.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              final status = p['applicationStatus'] ?? 'pending';
              final color = statusColors[status] ?? AppColors.warning;
              return TableRow(
                decoration: BoxDecoration(
                  color: i.isEven ? AppColors.backgroundCard : AppColors.backgroundCard.withOpacity(0.7),
                ),
                children: [
                  _TablePadding(Text('${i + 1}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontFamily: 'Tajawal'), textAlign: TextAlign.center)),
                  _TablePadding(Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(p['fullName'] ?? p['displayName'] ?? 'عنصر مجهول', style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
                      const SizedBox(width: 10),
                      CircleAvatar(radius: 16, backgroundColor: AppColors.accent.withOpacity(0.15), child: Text((p['displayName'] ?? 'ع').substring(0, 1), style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w700))),
                    ],
                  )),
                  _TablePadding(Text(p['email'] ?? '—', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontFamily: 'Tajawal'), textAlign: TextAlign.end)),
                  _TablePadding(Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(statusLabels[status] ?? '', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
                        const SizedBox(width: 5),
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      ]),
                    ),
                  )),
                  _TablePadding(TextButton(onPressed: () => onTap(p['uid']), child: const Text('تفاصيل', style: TextStyle(fontSize: 13, fontFamily: 'Tajawal')))),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _TablePadding(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: child);
}

// ── كود السيدة ─────────────────────────────────────────────────
class _LeaderCodeCard extends StatelessWidget {
  final String leaderCode;
  final bool codeCopied;
  final VoidCallback onCopy;
  const _LeaderCodeCard({required this.leaderCode, required this.codeCopied, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.accent.withOpacity(0.15), AppColors.accent.withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: onCopy,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Icon(codeCopied ? Icons.check : Icons.copy_outlined, size: 18, color: codeCopied ? AppColors.success : AppColors.accent),
              const SizedBox(height: 4),
              Text(codeCopied ? 'تم' : 'نسخ', style: TextStyle(fontSize: 12, color: codeCopied ? AppColors.success : AppColors.accent, fontFamily: 'Tajawal')),
            ]),
          ),
        ),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('رمز السيدة الخاص', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
          Text(leaderCode.isEmpty ? '------' : leaderCode, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.accent, letterSpacing: 4, fontFamily: 'monospace')),
          const Text('امنح هذا الرمز للعناصر للارتباط', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontFamily: 'Tajawal')),
        ]),
      ]),
    );
  }
}

// ── بطاقات الإحصائيات ──────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color, fontFamily: 'Tajawal')),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontFamily: 'Tajawal')),
      ]),
    ),
  );
}

class _WebStatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _WebStatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
          Text('$value', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: color, fontFamily: 'Tajawal')),
        ]),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
      ]),
    ),
  );
}

// ── بطاقة العنصر ───────────────────────────────────────────────
class _ParticipantCard extends StatelessWidget {
  final Map<String, dynamic> participant;
  final Map<String, Color> statusColors;
  final Map<String, String> statusLabels;
  final VoidCallback onTap;
  const _ParticipantCard({required this.participant, required this.statusColors, required this.statusLabels, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = participant['applicationStatus'] ?? 'pending';
    final color = statusColors[status] ?? AppColors.warning;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          const Icon(Icons.chevron_left, color: AppColors.textMuted),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(participant['fullName'] ?? participant['displayName'] ?? 'عنصر مجهول', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text, fontFamily: 'Tajawal')),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(statusLabels[status] ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color, fontFamily: 'Tajawal')),
                const SizedBox(width: 4),
                Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              ]),
            ),
          ]),
          const SizedBox(width: 12),
          CircleAvatar(radius: 22, backgroundColor: AppColors.accent.withOpacity(0.15), child: Text((participant['displayName'] ?? 'ع').substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.accent, fontFamily: 'Tajawal'))),
        ]),
      ),
    );
  }
}

// ── حالات فارغة وترويسات ────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(60),
      child: Column(children: [
        Icon(Icons.group_off_outlined, size: 48, color: AppColors.textMuted),
        SizedBox(height: 12),
        Text('لا يوجد عناصر مسجلة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
        SizedBox(height: 6),
        Text('بمجرد أن يستخدم العنصر الكود الخاص بك سيظهر هنا فوراً', style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontFamily: 'Tajawal'), textAlign: TextAlign.center),
      ]),
    ),
  );
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontFamily: 'Tajawal'), textAlign: TextAlign.end));
}

class _BuzzerActionButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'إطلاق تنبيه للعناصر',
    child: CdnAudioButton(
      sound: AppSound.buzzer,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: AppColors.error.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.error.withOpacity(0.3))),
        child: const Row(children: [
          Icon(Icons.notifications_active, color: AppColors.error, size: 18),
          SizedBox(width: 6),
          Text('تنبيه', style: TextStyle(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
        ]),
      ),
    ),
  );
}

class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'تسجيل الخروج',
    icon: const Icon(Icons.logout, color: AppColors.textSecondary),
    onPressed: () async {
      await context.read<AuthProvider>().signOut();
      if (context.mounted) context.go('/');
    },
  );
}
