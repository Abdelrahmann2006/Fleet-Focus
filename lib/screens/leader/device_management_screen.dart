import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/colors.dart';
import '../../layout/responsive_scaffold.dart';
import '../../providers/auth_provider.dart';
import '../../services/device_state_service.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  List<Map<String, dynamic>> _participants = [];
  bool _loading = true;
  String _leaderCode = '';

  static const List<SidebarItem> _navItems = [
    SidebarItem(icon: Icons.dashboard_outlined,    label: 'لوحة التحكم',  route: '/leader/dashboard'),
    SidebarItem(icon: Icons.group_outlined,        label: 'العناصر',      route: '/leader/participants'),
    SidebarItem(icon: Icons.phone_android_outlined, label: 'إدارة الأجهزة', route: '/leader/devices'),
    SidebarItem(icon: Icons.notifications_outlined, label: 'الإشعارات'),
  ];

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
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
      debugPrint('DeviceManagement: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── أوامر جماعية ──────────────────────────────────────────

  Future<void> _enableKioskAll() async {
    final confirmed = await _confirm('تفعيل Kiosk لجميع الأجهزة؟',
        'سيتم تقييد جميع الأجهزة الآن');
    if (!confirmed) return;
    for (final p in _participants) {
      await DeviceStateService.enableKiosk(p['uid'] as String);
    }
    _showSnack('تم إرسال أمر Kiosk لـ ${_participants.length} جهاز');
  }

  Future<void> _disableKioskAll() async {
    final confirmed = await _confirm('إلغاء Kiosk لجميع الأجهزة؟',
        'سيتم رفع القيود عن جميع الأجهزة');
    if (!confirmed) return;
    for (final p in _participants) {
      await DeviceStateService.disableKiosk(p['uid'] as String);
    }
    _showSnack('تم إلغاء Kiosk لجميع الأجهزة');
  }

  Future<void> _lockAllScreens() async {
    final confirmed =
        await _confirm('قفل شاشات جميع الأجهزة؟', 'لا يمكن التراجع فوراً');
    if (!confirmed) return;
    for (final p in _participants) {
      await DeviceStateService.lockScreen(p['uid'] as String);
    }
    _showSnack('تم إرسال أمر القفل لـ ${_participants.length} جهاز');
  }

  Future<bool> _confirm(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.backgroundCard,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title,
                style: const TextStyle(
                    color: AppColors.text,
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w700)),
            content: Text(body,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontFamily: 'Tajawal')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء',
                      style: TextStyle(
                          color: AppColors.textMuted, fontFamily: 'Tajawal'))),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('تأكيد', style: TextStyle(fontFamily: 'Tajawal'))),
            ],
          ),
        ) ??
        false;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontFamily: 'Tajawal', color: Colors.black)),
      backgroundColor: AppColors.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: 'إدارة الأجهزة',
      currentIndex: 2,
      navItems: _navItems,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── DPC Command Center — الدخول السريع ─────────────
          GestureDetector(
            onTap: () => context.push('/leader/dpc'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.accent.withOpacity(0.15),
                  AppColors.accent.withOpacity(0.04),
                ]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accent.withOpacity(0.35)),
              ),
              child: const Row(children: [
                Icon(Icons.chevron_left, color: AppColors.accent, size: 18),
                Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('DPC Command Center',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                          fontFamily: 'Tajawal')),
                  Text(
                    'Lost Mode · Panic Alarm · OOB Protocol · القيود المؤسسية',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.accent,
                        fontFamily: 'Tajawal'),
                  ),
                ]),
                SizedBox(width: 12),
                Icon(Icons.admin_panel_settings,
                    color: AppColors.accent, size: 28),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // ── شريط الأوامر الجماعية ─────────────────────────
          _BulkActionBar(
            total: _participants.length,
            onEnableKiosk: _enableKioskAll,
            onDisableKiosk: _disableKioskAll,
            onLockAll: _lockAllScreens,
          ),
          const SizedBox(height: 24),

          // ── رأس الجدول ────────────────────────────────────
          const Text('قائمة الأجهزة',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                  fontFamily: 'Tajawal')),
          const SizedBox(height: 12),

          if (_participants.isEmpty)
            const _EmptyDevices()
          else
            Column(
              children: _participants
                  .map((p) => _DeviceRow(
                        participant: p,
                        onTap: () =>
                            context.push('/leader/device/${p['uid']}'),
                        onEnableKiosk: () async {
                          await DeviceStateService.enableKiosk(p['uid'] as String);
                          _showSnack('تم تفعيل Kiosk لـ ${p['displayName'] ?? 'العنصر'}');
                        },
                        onDisableKiosk: () async {
                          await DeviceStateService.disableKiosk(p['uid'] as String);
                          _showSnack('تم إلغاء Kiosk لـ ${p['displayName'] ?? 'العنصر'}');
                        },
                        onLock: () async {
                          await DeviceStateService.lockScreen(p['uid'] as String);
                          _showSnack('تم قفل جهاز ${p['displayName'] ?? 'العنصر'}');
                        },
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  شريط الأوامر الجماعية
// ─────────────────────────────────────────────────────────────
class _BulkActionBar extends StatelessWidget {
  final int total;
  final VoidCallback onEnableKiosk;
  final VoidCallback onDisableKiosk;
  final VoidCallback onLockAll;

  const _BulkActionBar({
    required this.total,
    required this.onEnableKiosk,
    required this.onDisableKiosk,
    required this.onLockAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$total جهاز مسجّل',
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w600)),
              ),
              const Text('أوامر جماعية',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                      fontFamily: 'Tajawal')),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              _BulkButton(
                label: 'تفعيل Kiosk للكل',
                icon: Icons.lock_outline,
                color: AppColors.warning,
                onTap: onEnableKiosk,
              ),
              _BulkButton(
                label: 'إلغاء Kiosk للكل',
                icon: Icons.lock_open_outlined,
                color: AppColors.success,
                onTap: onDisableKiosk,
              ),
              _BulkButton(
                label: 'قفل جميع الشاشات',
                icon: Icons.screen_lock_portrait_outlined,
                color: AppColors.error,
                onTap: onLockAll,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BulkButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _BulkButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: color,
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            const SizedBox(width: 8),
            Icon(icon, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  صف الجهاز مع حالة real-time من Firestore
// ─────────────────────────────────────────────────────────────
class _DeviceRow extends StatelessWidget {
  final Map<String, dynamic> participant;
  final VoidCallback onTap;
  final VoidCallback onEnableKiosk;
  final VoidCallback onDisableKiosk;
  final VoidCallback onLock;

  const _DeviceRow({
    required this.participant,
    required this.onTap,
    required this.onEnableKiosk,
    required this.onDisableKiosk,
    required this.onLock,
  });

  @override
  Widget build(BuildContext context) {
    final uid = participant['uid'] as String;
    final name = participant['displayName'] ?? 'مشارك';

    return StreamBuilder<DocumentSnapshot>(
      stream: DeviceStateService.watchDeviceState(uid),
      builder: (context, snap) {
        final state = snap.data?.data() as Map<String, dynamic>? ?? {};
        final kioskOn     = state['kioskMode'] as bool? ?? false;
        final permissions = state['permissions'] as Map<String, dynamic>? ?? {};
        final adminOk     = permissions['deviceAdmin'] as bool? ?? false;
        final a11yOk      = permissions['accessibility'] as bool? ?? false;
        final overlayOk   = permissions['overlay'] as bool? ?? false;
        final lastSeenTs  = state['lastSeen'] as Timestamp?;
        final lastSeen    = _formatLastSeen(lastSeenTs);
        final online      = lastSeenTs != null &&
            DateTime.now()
                    .difference(lastSeenTs.toDate())
                    .inMinutes < 5;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: kioskOn
                    ? AppColors.warning.withOpacity(0.35)
                    : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // ── صف المعلومات الأساسية ─────────────────
                Row(
                  children: [
                    // أزرار التحكم
                    Row(
                      children: [
                        _SmallIconBtn(
                          icon: Icons.screen_lock_portrait_outlined,
                          color: AppColors.error,
                          tooltip: 'قفل الشاشة',
                          onTap: onLock,
                        ),
                        const SizedBox(width: 6),
                        _SmallIconBtn(
                          icon: kioskOn
                              ? Icons.lock_open_outlined
                              : Icons.lock_outline,
                          color: kioskOn ? AppColors.success : AppColors.warning,
                          tooltip: kioskOn ? 'إلغاء Kiosk' : 'تفعيل Kiosk',
                          onTap: kioskOn ? onDisableKiosk : onEnableKiosk,
                        ),
                      ],
                    ),
                    const Spacer(),
                    // اسم + حالة الاتصال
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                color: AppColors.text,
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                        Row(children: [
                          Text(lastSeen,
                              style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  fontFamily: 'Tajawal')),
                          const SizedBox(width: 5),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: online
                                  ? AppColors.success
                                  : AppColors.textMuted,
                            ),
                          ),
                        ]),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // أيقونة الجهاز
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.phone_android,
                          color: online
                              ? AppColors.accent
                              : AppColors.textMuted,
                          size: 22),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 10),

                // ── صف مؤشرات الصلاحيات ──────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (kioskOn)
                      _StatusChip(
                          label: 'Kiosk نشط',
                          ok: true,
                          color: AppColors.warning),
                    const SizedBox(width: 6),
                    _PermBadge(label: 'Overlay',     ok: overlayOk),
                    const SizedBox(width: 6),
                    _PermBadge(label: 'Accessibility', ok: a11yOk),
                    const SizedBox(width: 6),
                    _PermBadge(label: 'Device Admin',  ok: adminOk),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatLastSeen(Timestamp? ts) {
    if (ts == null) return 'لم يُتصل بعد';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inSeconds < 60) return 'منذ ${diff.inSeconds} ث';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    return 'منذ ${diff.inDays} يوم';
  }
}

// ─────────────────────────────────────────────────────────────
//  مكوّنات مساعدة
// ─────────────────────────────────────────────────────────────
class _SmallIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _SmallIconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }
}

class _PermBadge extends StatelessWidget {
  final String label;
  final bool ok;
  const _PermBadge({required this.label, required this.ok});

  @override
  Widget build(BuildContext context) => _StatusChip(
        label: label,
        ok: ok,
        color: ok ? AppColors.success : AppColors.error,
      );
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool ok;
  final Color color;
  const _StatusChip(
      {required this.label, required this.ok, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          ok ? Icons.check_circle_outline : Icons.cancel_outlined,
          color: color,
          size: 11,
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _EmptyDevices extends StatelessWidget {
  const _EmptyDevices();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(60),
        child: Column(children: [
          Icon(Icons.phone_android_outlined, size: 64, color: AppColors.textMuted),
          SizedBox(height: 16),
          Text('لا توجد أجهزة مسجّلة',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  fontFamily: 'Tajawal')),
          SizedBox(height: 8),
          Text('ستظهر الأجهزة هنا عند اتصال العناصر',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textMuted, fontFamily: 'Tajawal')),
        ]),
      ),
    );
  }
}
