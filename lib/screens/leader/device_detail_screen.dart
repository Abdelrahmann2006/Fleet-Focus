import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../layout/responsive_scaffold.dart';
import '../../services/device_state_service.dart';
import '../../services/focus_service.dart';

/// شاشة تفاصيل الجهاز — التحكم الفردي الكامل
class DeviceDetailScreen extends StatefulWidget {
  final String uid;
  const DeviceDetailScreen({super.key, required this.uid});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  String _participantName = 'المشارك';
  bool _loadingName = true;

  // قائمة التطبيقات المعروضة للتحكم
  final Map<String, bool> _appSelections = {
    for (final entry in FocusService.packageDisplayNames.entries)
      entry.key: FocusService.defaultBlockedApps.contains(entry.key),
  };

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(widget.uid).get();
      setState(() {
        _participantName = doc.data()?['displayName'] ?? 'المشارك';
        _loadingName = false;
      });
      // تحميل قائمة الحجب الحالية من Firestore
      final state = await DeviceStateService.getDeviceState(widget.uid);
      if (state != null) {
        final blocked = List<String>.from(state['blockedApps'] ?? []);
        setState(() {
          for (final key in _appSelections.keys) {
            _appSelections[key] = blocked.contains(key);
          }
        });
      }
    } catch (_) {
      setState(() => _loadingName = false);
    }
  }

  Future<void> _applyBlockedApps() async {
    final selected = _appSelections.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    await DeviceStateService.updateBlockedApps(widget.uid, selected);
    _showSnack('تم تحديث قائمة التطبيقات المحجوبة (${selected.length} تطبيق)');
  }

  Future<void> _sendLockScreen() async {
    await DeviceStateService.lockScreen(widget.uid);
    _showSnack('تم إرسال أمر قفل الشاشة');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(color: Colors.black, fontFamily: 'Tajawal')),
      backgroundColor: AppColors.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: 'جهاز: $_participantName',
      currentIndex: 2,
      navItems: const [],
      body: _loadingName
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : StreamBuilder<DocumentSnapshot>(
              stream: DeviceStateService.watchDeviceState(widget.uid),
              builder: (context, snap) {
                final state =
                    snap.data?.data() as Map<String, dynamic>? ?? {};
                return _buildBody(state);
              },
            ),
    );
  }

  Widget _buildBody(Map<String, dynamic> state) {
    final kioskOn = state['kioskMode'] as bool? ?? false;
    final perms   = state['permissions'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── بطاقة حالة الجهاز ─────────────────────────
          _DeviceStatusCard(
            name: _participantName,
            kioskOn: kioskOn,
            permissions: perms,
            onEnableKiosk: () async {
              await DeviceStateService.enableKiosk(widget.uid);
              _showSnack('تم تفعيل Kiosk');
            },
            onDisableKiosk: () async {
              await DeviceStateService.disableKiosk(widget.uid);
              _showSnack('تم إلغاء Kiosk');
            },
            onLockScreen: _sendLockScreen,
          ),

          const SizedBox(height: 24),

          // ── إدارة التطبيقات المحجوبة ──────────────────
          _BlockedAppsCard(
            selections: _appSelections,
            onChanged: (pkg, val) => setState(() => _appSelections[pkg] = val),
            onApply: _applyBlockedApps,
          ),

          const SizedBox(height: 24),

          // ── بطاقة الصلاحيات ───────────────────────────
          _PermissionsCard(permissions: perms),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  بطاقة حالة الجهاز + أزرار التحكم
// ─────────────────────────────────────────────────────────────
class _DeviceStatusCard extends StatelessWidget {
  final String name;
  final bool kioskOn;
  final Map<String, dynamic> permissions;
  final VoidCallback onEnableKiosk;
  final VoidCallback onDisableKiosk;
  final VoidCallback onLockScreen;

  const _DeviceStatusCard({
    required this.name,
    required this.kioskOn,
    required this.permissions,
    required this.onEnableKiosk,
    required this.onDisableKiosk,
    required this.onLockScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: kioskOn
              ? AppColors.warning.withOpacity(0.4)
              : AppColors.border,
          width: kioskOn ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(children: [
            // حالة Kiosk
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (kioskOn ? AppColors.warning : AppColors.success)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: (kioskOn ? AppColors.warning : AppColors.success)
                        .withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  kioskOn ? Icons.lock : Icons.lock_open,
                  size: 14,
                  color:
                      kioskOn ? AppColors.warning : AppColors.success,
                ),
                const SizedBox(width: 6),
                Text(
                  kioskOn ? 'Kiosk مُفعَّل' : 'Kiosk معطّل',
                  style: TextStyle(
                    color: kioskOn ? AppColors.warning : AppColors.success,
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ]),
            ),
            const Spacer(),
            const Icon(Icons.phone_android, color: AppColors.accent, size: 26),
            const SizedBox(width: 10),
            Text(name,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                    fontFamily: 'Tajawal')),
          ]),

          const SizedBox(height: 20),
          const Divider(color: AppColors.border),
          const SizedBox(height: 16),

          // أزرار التحكم
          Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.end, children: [
            _ActionButton(
              label: kioskOn ? 'إلغاء Kiosk' : 'تفعيل Kiosk',
              icon: kioskOn ? Icons.lock_open_outlined : Icons.lock_outline,
              color: kioskOn ? AppColors.success : AppColors.warning,
              onTap: kioskOn ? onDisableKiosk : onEnableKiosk,
            ),
            _ActionButton(
              label: 'قفل الشاشة الآن',
              icon: Icons.screen_lock_portrait_outlined,
              color: AppColors.error,
              onTap: onLockScreen,
            ),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  بطاقة التطبيقات المحجوبة
// ─────────────────────────────────────────────────────────────
class _BlockedAppsCard extends StatelessWidget {
  final Map<String, bool> selections;
  final void Function(String pkg, bool val) onChanged;
  final VoidCallback onApply;

  const _BlockedAppsCard({
    required this.selections,
    required this.onChanged,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final blockedCount = selections.values.where((v) => v).length;

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
          Row(children: [
            Text('$blockedCount محجوب',
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontFamily: 'Tajawal',
                    fontSize: 13)),
            const Spacer(),
            const Text('التطبيقات المحجوبة',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                    fontFamily: 'Tajawal')),
          ]),
          const SizedBox(height: 16),

          // قائمة التطبيقات
          ...selections.entries.map((entry) {
            final display =
                FocusService.displayName(entry.key);
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: entry.value
                    ? AppColors.error.withOpacity(0.05)
                    : AppColors.backgroundElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: entry.value
                        ? AppColors.error.withOpacity(0.2)
                        : AppColors.border),
              ),
              child: CheckboxListTile(
                value: entry.value,
                onChanged: (v) => onChanged(entry.key, v ?? false),
                title: Text(display,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: entry.value
                            ? AppColors.error
                            : AppColors.text,
                        fontSize: 14)),
                subtitle: Text(entry.key,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontFamily: 'Courier',
                        color: AppColors.textMuted,
                        fontSize: 10)),
                activeColor: AppColors.error,
                checkColor: Colors.white,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12),
                dense: true,
              ),
            );
          }),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.send_outlined, size: 16),
              label: const Text('تطبيق القائمة على الجهاز',
                  style: TextStyle(fontFamily: 'Tajawal')),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  بطاقة الصلاحيات (للقراءة فقط من جانب القائد)
// ─────────────────────────────────────────────────────────────
class _PermissionsCard extends StatelessWidget {
  final Map<String, dynamic> permissions;
  const _PermissionsCard({required this.permissions});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Device Admin',   permissions['deviceAdmin']         as bool? ?? false),
      ('Accessibility',  permissions['accessibility']       as bool? ?? false),
      ('Draw Overlay',   permissions['overlay']             as bool? ?? false),
      ('Battery Exempt', permissions['batteryOptimization'] as bool? ?? false),
    ];

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
          const Text('حالة الصلاحيات',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                  fontFamily: 'Tajawal')),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (item.$2 ? AppColors.success : AppColors.error)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: (item.$2
                                  ? AppColors.success
                                  : AppColors.error)
                              .withOpacity(0.3)),
                    ),
                    child: Text(
                      item.$2 ? 'مُفعَّل ✓' : 'معطّل ✗',
                      style: TextStyle(
                          color: item.$2
                              ? AppColors.success
                              : AppColors.error,
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  Text(item.$1,
                      style: const TextStyle(
                          color: AppColors.text,
                          fontFamily: 'Tajawal',
                          fontSize: 14)),
                ]),
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  زر إجراء عام
// ─────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                  color: color,
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          const SizedBox(width: 8),
          Icon(icon, color: color, size: 18),
        ]),
      ),
    );
  }
}
