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
  List<Map<String, dynamic>> _participants = [];
  String _leaderCode = '';
  bool _loading = true;
  bool _codeCopied = false;
  bool _refreshing = false;

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

  // عناصر الشريط الجانبي (ويب + تابلت)
  static const List<SidebarItem> _navItems = [
    SidebarItem(icon: Icons.dashboard_outlined,     label: 'لوحة التحكم',  route: '/leader/dashboard'),
    SidebarItem(icon: Icons.group_outlined,         label: 'العناصر',      route: '/leader/participants'),
    SidebarItem(icon: Icons.phone_android_outlined, label: 'إدارة الأجهزة', route: '/leader/devices'),
    SidebarItem(icon: Icons.notifications_outlined, label: 'الإشعارات'),
    SidebarItem(icon: Icons.settings_outlined,      label: 'الإعدادات'),
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final code = userDoc.data()?['leaderCode'] ?? '';
      setState(() => _leaderCode = code);
      if (code.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where('linkedLeaderCode', isEqualTo: code)
            .where('role', isEqualTo: 'participant')
            .get();
        setState(() => _participants =
            snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList());
      }
    } catch (e) {
      debugPrint('LeaderDashboard Error: $e');
    } finally {
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _leaderCode));
    setState(() => _codeCopied = true);
    Future.delayed(
        const Duration(seconds: 2), () => setState(() => _codeCopied = false));
  }

  int get _total     => _participants.length;
  int get _submitted => _participants.where((p) => p['applicationStatus'] == 'submitted').length;
  int get _approved  => _participants.where((p) => p['applicationStatus'] == 'approved').length;
  int get _pending   => _participants.where((p) => p['applicationStatus'] == 'pending').length;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final firstName = user?.fullName?.split(' ').first ?? 'السيدة';

    // ── ويب / تابلت / ديسكتوب → ResponsiveScaffold ─────────
    if (kIsWeb || context.isTablet || context.isDesktop) {
      return ResponsiveScaffold(
        title: 'لوحة تحكم السيدة',
        currentIndex: 0,
        navItems: _navItems,
        actions: [
          _BuzzerActionButton(),
          const SizedBox(width: 12),
          _LogoutButton(),
          const SizedBox(width: 16),
        ],
        body: _buildWebContent(firstName),
      );
    }

    // ── موبايل → تخطيط Stack مع خلفية Spotlight ────────────
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const StageLightBackground(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() => _refreshing = true);
                await _fetchData();
              },
              color: AppColors.accent,
              backgroundColor: AppColors.backgroundCard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildMobileContent(firstName),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  محتوى الويب — تخطيط Grid متجاوب
  // ─────────────────────────────────────────────────────────────
  Widget _buildWebContent(String firstName) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── ترحيب ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent.withOpacity(0.08),
                      Colors.transparent,
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: Row(
                  children: [
                    // كود القائد (ويب)
                    Expanded(child: _LeaderCodeCard(
                      leaderCode: _leaderCode,
                      codeCopied: _codeCopied,
                      onCopy: _copyCode,
                    )),
                    const SizedBox(width: 24),
                    // ترحيب
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('أهلاً، $firstName',
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text,
                                fontFamily: 'Tajawal')),
                        const SizedBox(height: 4),
                        Text(
                          'لديك $_total متسابق مسجّل',
                          style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                              fontFamily: 'Tajawal'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── بطاقات الإحصائيات ────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _WebStatCard(label: 'إجمالي العناصر', value: _total,     icon: Icons.group, color: AppColors.accent),
                    const SizedBox(width: 16),
                    _WebStatCard(label: 'بانتظار المراجعة',  value: _submitted, icon: Icons.hourglass_top, color: const Color(0xFFC9A84C)),
                    const SizedBox(width: 16),
                    _WebStatCard(label: 'تمت الموافقة',      value: _approved,  icon: Icons.check_circle_outline, color: AppColors.success),
                    const SizedBox(width: 16),
                    _WebStatCard(label: 'معلّق',             value: _pending,   icon: Icons.pending_outlined, color: AppColors.warning),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── جدول المتسابقين ──────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => context.push('/leader/participants'),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 14, color: AppColors.accent),
                      label: const Text('عرض الكل',
                          style: TextStyle(fontSize: 14, color: AppColors.accent, fontFamily: 'Tajawal')),
                    ),
                    const Text('العناصر المسجّلة',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text, fontFamily: 'Tajawal')),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(60),
                  child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                )
              else if (_participants.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(60),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.group_outlined, size: 64, color: AppColors.textMuted),
                      SizedBox(height: 16),
                      Text('لا يوجد متسابقون بعد',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
                      SizedBox(height: 8),
                      Text('شارك الكود لبدء الاستقبال',
                          style: TextStyle(fontSize: 14, color: AppColors.textMuted, fontFamily: 'Tajawal')),
                    ]),
                  ),
                )
              else
                // جدول الويب
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: isWide
                      ? _WebParticipantsTable(
                          participants: _participants,
                          statusColors: _statusColors,
                          statusLabels: _statusLabels,
                          onTap: (uid) => context.push('/leader/participant/$uid'),
                        )
                      : Column(
                          children: _participants
                              .take(10)
                              .map((p) => _ParticipantCard(
                                    participant: p,
                                    statusColors: _statusColors,
                                    statusLabels: _statusLabels,
                                    onTap: () => context.push('/leader/participant/${p['uid']}'),
                                  ))
                              .toList(),
                        ),
                ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  محتوى الموبايل (تخطيط قائمة عمودي)
  // ─────────────────────────────────────────────────────────────
  Widget _buildMobileContent(String firstName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _LogoutButton(),
            Text('أهلاً، $firstName',
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    fontFamily: 'Tajawal')),
          ],
        ),
        const SizedBox(height: 20),

        // كود القائد
        _LeaderCodeCard(
          leaderCode: _leaderCode,
          codeCopied: _codeCopied,
          onCopy: _copyCode,
        ),

        const SizedBox(height: 20),

        // إحصائيات
        Row(children: [
          _StatCard(label: 'إجمالي',  value: _total,     color: AppColors.accent),
          const SizedBox(width: 10),
          _StatCard(label: 'مكتمل',   value: _submitted,  color: const Color(0xFFC9A84C)),
          const SizedBox(width: 10),
          _StatCard(label: 'موافق',   value: _approved,   color: AppColors.success),
          const SizedBox(width: 10),
          _StatCard(label: 'معلق',    value: _pending,    color: AppColors.warning),
        ]),

        const SizedBox(height: 20),

        // ── بطاقة إدارة الأجهزة (موبايل) ─────────────
        GestureDetector(
          onTap: () => context.push('/leader/devices'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.info.withOpacity(0.12),
                AppColors.info.withOpacity(0.04),
              ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.info.withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.chevron_left, color: AppColors.info, size: 18),
              Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('إدارة الأجهزة',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        fontFamily: 'Tajawal')),
                Text('Kiosk Mode · قفل الشاشة · التطبيقات المحجوبة',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.info,
                        fontFamily: 'Tajawal')),
              ]),
              SizedBox(width: 12),
              Icon(Icons.phone_android_outlined, color: AppColors.info, size: 26),
            ]),
          ),
        ),

        const SizedBox(height: 28),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          TextButton(
            onPressed: () => context.push('/leader/participants'),
            child: const Text('عرض الكل',
                style: TextStyle(fontSize: 14, color: AppColors.accent, fontFamily: 'Tajawal')),
          ),
          const Text('العناصر',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text, fontFamily: 'Tajawal')),
        ]),
        const SizedBox(height: 8),

        if (_loading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AppColors.accent)))
        else if (_participants.isEmpty)
          _EmptyState()
        else
          ..._participants.take(5).map((p) => _ParticipantCard(
                participant: p,
                statusColors: _statusColors,
                statusLabels: _statusLabels,
                onTap: () => context.push('/leader/participant/${p['uid']}'),
              )),

        const SizedBox(height: 40),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  مكوّن كود القائد — مشترك بين الموبايل والويب
// ─────────────────────────────────────────────────────────────
class _LeaderCodeCard extends StatelessWidget {
  final String leaderCode;
  final bool codeCopied;
  final VoidCallback onCopy;

  const _LeaderCodeCard({
    required this.leaderCode,
    required this.codeCopied,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.accent.withOpacity(0.15),
          AppColors.accent.withOpacity(0.05),
        ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onCopy,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withOpacity(0.2)),
              ),
              child: Column(children: [
                Icon(codeCopied ? Icons.check : Icons.copy_outlined,
                    size: 18,
                    color: codeCopied ? AppColors.success : AppColors.accent),
                const SizedBox(height: 4),
                Text(codeCopied ? 'تم' : 'نسخ',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: codeCopied ? AppColors.success : AppColors.accent,
                        fontFamily: 'Tajawal')),
              ]),
            ),
          ),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('رمز السيدة',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontFamily: 'Tajawal')),
            Text(
              leaderCode.isEmpty ? '---' : leaderCode,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                  letterSpacing: 3,
                  fontFamily: 'Courier'),
            ),
            const Text('شارك هذا الرمز مع العناصر',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontFamily: 'Tajawal')),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  بطاقة إحصائية للويب (أكبر + أيقونة)
// ─────────────────────────────────────────────────────────────
class _WebStatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _WebStatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Text('$value',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: color,
                        fontFamily: 'Tajawal')),
              ],
            ),
            const SizedBox(height: 12),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontFamily: 'Tajawal')),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  جدول المتسابقين للويب
// ─────────────────────────────────────────────────────────────
class _WebParticipantsTable extends StatelessWidget {
  final List<Map<String, dynamic>> participants;
  final Map<String, Color> statusColors;
  final Map<String, String> statusLabels;
  final void Function(String uid) onTap;

  const _WebParticipantsTable({
    required this.participants,
    required this.statusColors,
    required this.statusLabels,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            // رأس الجدول
            TableRow(
              decoration: const BoxDecoration(
                color: AppColors.backgroundElevated,
              ),
              children: const [
                _TableHeader('#'),
                _TableHeader('الاسم'),
                _TableHeader('البريد الإلكتروني'),
                _TableHeader('الحالة'),
                _TableHeader('إجراء'),
              ],
            ),
            // صفوف البيانات
            ...participants.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              final status = p['applicationStatus'] ?? 'pending';
              final color = statusColors[status] ?? AppColors.warning;
              final isEven = i.isEven;
              return TableRow(
                decoration: BoxDecoration(
                  color: isEven
                      ? AppColors.backgroundCard
                      : AppColors.backgroundCard.withOpacity(0.7),
                ),
                children: [
                  // رقم
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Text('${i + 1}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontFamily: 'Tajawal'),
                        textAlign: TextAlign.center),
                  ),
                  // الاسم
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(p['displayName'] ?? 'مجهول',
                            style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
                        const SizedBox(width: 10),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.accent.withOpacity(0.15),
                          child: Text(
                            (p['displayName'] ?? 'م').substring(0, 1),
                            style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // البريد
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Text(p['email'] ?? '—',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontFamily: 'Tajawal'),
                        textAlign: TextAlign.end),
                  ),
                  // الحالة
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.13),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(statusLabels[status] ?? '',
                                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
                            const SizedBox(width: 5),
                            Container(width: 6, height: 6,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // زر التفاصيل
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: TextButton(
                      onPressed: () => onTap(p['uid']),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: const Text('تفاصيل',
                          style: TextStyle(fontSize: 13, fontFamily: 'Tajawal')),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              fontFamily: 'Tajawal'),
          textAlign: TextAlign.end),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  بطاقة موبايل
// ─────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          Text('$value',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color, fontFamily: 'Tajawal')),
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontFamily: 'Tajawal')),
        ]),
      ),
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  final Map<String, dynamic> participant;
  final Map<String, Color> statusColors;
  final Map<String, String> statusLabels;
  final VoidCallback onTap;
  const _ParticipantCard({
    required this.participant,
    required this.statusColors,
    required this.statusLabels,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = participant['applicationStatus'] ?? 'pending';
    final color = statusColors[status] ?? AppColors.warning;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.chevron_left, color: AppColors.textMuted),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(participant['displayName'] ?? 'مجهول',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                    fontFamily: 'Tajawal')),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(statusLabels[status] ?? '',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: color,
                          fontFamily: 'Tajawal')),
                  const SizedBox(width: 4),
                  Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                ],
              ),
            ),
          ]),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                shape: BoxShape.circle),
            child: Center(
              child: Text(
                (participant['displayName'] ?? 'م').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                    fontFamily: 'Tajawal'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(60),
        child: Column(children: [
          Icon(Icons.group_outlined, size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text('لا يوجد متسابقون بعد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
          SizedBox(height: 6),
          Text('شارك الكود أعلاه لبدء الاستقبال',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted, fontFamily: 'Tajawal'),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  أزرار شريط الأدوات
// ─────────────────────────────────────────────────────────────
class _BuzzerActionButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'إطلاق بزّر للمتسابقين',
      child: CdnAudioButton(
        sound: AppSound.buzzer,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.error.withOpacity(0.3)),
          ),
          child: const Row(children: [
            Icon(Icons.notifications_active, color: AppColors.error, size: 18),
            SizedBox(width: 6),
            Text('بزّر', style: TextStyle(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
          ]),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'تسجيل الخروج',
      icon: const Icon(Icons.logout, color: AppColors.textSecondary),
      onPressed: () async {
        await context.read<AuthProvider>().signOut();
        if (context.mounted) context.go('/');
      },
    );
  }
}
