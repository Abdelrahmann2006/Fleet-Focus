import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/colors.dart';

/// Tab 1 — Device Compliance & Security Integrity
/// يعرض: UsageStats · Device Uptime · حالة الامتثال الأمني
class DpcComplianceTab extends StatefulWidget {
  final String participantUid;
  final Map<String, dynamic> deviceState;

  const DpcComplianceTab({
    super.key,
    required this.participantUid,
    required this.deviceState,
  });

  @override
  State<DpcComplianceTab> createState() => _DpcComplianceTabState();
}

class _DpcComplianceTabState extends State<DpcComplianceTab> {
  bool _loading = false;
  String _complianceScore = '--';
  String _uptime = '--';
  List<_AppUsageStat> _topApps = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _computeMetrics();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _computeMetrics(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _computeMetrics() {
    final state = widget.deviceState;
    final perms = state['permissions'] as Map<String, dynamic>? ?? {};

    // حساب نقاط الامتثال
    int score = 0;
    if (perms['deviceAdmin'] == true) score += 30;
    if (perms['accessibility'] == true) score += 25;
    if (perms['overlay'] == true) score += 20;
    if (perms['batteryOptimization'] == true) score += 15;
    if (state['isOnline'] == true) score += 10;

    // وقت التشغيل من lastSeen + bootTime
    final bootTime = state['bootTimeMs'] as int?;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (bootTime != null && bootTime > 0) {
      final diff = Duration(milliseconds: now - bootTime);
      final h = diff.inHours;
      final m = diff.inMinutes % 60;
      _uptime = '$h س $m د';
    } else {
      _uptime = 'غير متوفر';
    }

    // إحصاءات استخدام التطبيقات من Firestore
    final usageRaw = state['topApps'] as List<dynamic>? ?? [];
    _topApps = usageRaw
        .map((e) => _AppUsageStat(
              packageName: e['package'] as String? ?? '',
              appLabel: e['label'] as String? ?? e['package'] as String? ?? '',
              usageMinutes: (e['minutes'] as num?)?.toInt() ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.usageMinutes.compareTo(a.usageMinutes));

    if (mounted) {
      setState(() {
        _complianceScore = '$score%';
        _loading = false;
      });
    }
  }

  Color _scoreColor(String score) {
    final v = int.tryParse(score.replaceAll('%', '')) ?? 0;
    if (v >= 80) return AppColors.success;
    if (v >= 50) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.deviceState;
    final perms = state['permissions'] as Map<String, dynamic>? ?? {};

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('device_states')
          .doc(widget.participantUid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasData && snap.data!.exists) {
          final fresh = snap.data!.data() as Map<String, dynamic>;
          // تحديث صامت بالبيانات الجديدة
          Future.microtask(() {
            if (mounted) {
              final mergedState = {...widget.deviceState, ...fresh};
              _computeMetricsFrom(mergedState);
            }
          });
        }

        return RefreshIndicator(
          onRefresh: () async => _computeMetrics(),
          color: AppColors.accent,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── نقاط الامتثال الكبرى ──
              _ComplianceScoreCard(
                score: _complianceScore,
                color: _scoreColor(_complianceScore),
              ),

              const SizedBox(height: 16),

              // ── وقت التشغيل ──
              _UptimeCard(uptime: _uptime),

              const SizedBox(height: 16),

              // ── حالة الصلاحيات المفصّلة ──
              _SectionHeader(label: 'حالة الصلاحيات المؤسسية'),
              const SizedBox(height: 8),
              _PermissionRow(
                label: 'مشرف الجهاز (Device Admin)',
                icon: Icons.admin_panel_settings,
                active: perms['deviceAdmin'] == true,
                weight: 30,
              ),
              _PermissionRow(
                label: 'خدمة إمكانية الوصول',
                icon: Icons.accessibility_new,
                active: perms['accessibility'] == true,
                weight: 25,
              ),
              _PermissionRow(
                label: 'الرسم فوق التطبيقات (Overlay)',
                icon: Icons.layers,
                active: perms['overlay'] == true,
                weight: 20,
              ),
              _PermissionRow(
                label: 'استثناء تحسين البطارية',
                icon: Icons.battery_charging_full,
                active: perms['batteryOptimization'] == true,
                weight: 15,
              ),
              _PermissionRow(
                label: 'متصل بالشبكة',
                icon: Icons.wifi,
                active: state['isOnline'] == true,
                weight: 10,
              ),

              const SizedBox(height: 16),

              // ── القيود المفعّلة ──
              _SectionHeader(label: 'القيود المؤسسية النشطة'),
              const SizedBox(height: 8),
              _RestrictionRow(
                label: 'Factory Reset محجوب',
                icon: Icons.no_sim,
                active: state['factoryResetBlocked'] ?? false,
              ),
              _RestrictionRow(
                label: 'وضع الطيران محجوب',
                icon: Icons.airplanemode_off,
                active: state['airplaneModeBlocked'] ?? false,
              ),
              _RestrictionRow(
                label: 'إلغاء تثبيت التطبيق محجوب',
                icon: Icons.delete_forever,
                active: state['uninstallBlocked'] ?? false,
              ),
              _RestrictionRow(
                label: 'Lost Mode نشط',
                icon: Icons.location_off,
                active: state['lostModeActive'] ?? false,
                dangerActive: true,
              ),

              const SizedBox(height: 16),

              // ── أعلى التطبيقات استخداماً ──
              _SectionHeader(label: 'أعلى التطبيقات استخداماً (آخر 24 ساعة)'),
              const SizedBox(height: 8),
              if (_topApps.isEmpty)
                _EmptyUsage()
              else
                ..._topApps.take(7).map((app) => _AppUsageRow(stat: app)),

              const SizedBox(height: 16),

              // ── بيانات أجهزة إضافية ──
              _SectionHeader(label: 'بيانات الجهاز'),
              const SizedBox(height: 8),
              _DataRow(label: 'البطارية', value: '${state['battery'] ?? '--'}%'),
              _DataRow(label: 'التخزين المتاح', value: '${state['freeStorageMb'] ?? '--'} MB'),
              _DataRow(label: 'حالة الشاشة', value: state['screenOn'] == true ? 'نشطة' : 'خاملة'),
              _DataRow(label: 'آخر ظهور', value: _formatTimestamp(state['lastSeen'])),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  void _computeMetricsFrom(Map<String, dynamic> state) {
    final perms = state['permissions'] as Map<String, dynamic>? ?? {};
    int score = 0;
    if (perms['deviceAdmin'] == true) score += 30;
    if (perms['accessibility'] == true) score += 25;
    if (perms['overlay'] == true) score += 20;
    if (perms['batteryOptimization'] == true) score += 15;
    if (state['isOnline'] == true) score += 10;

    if (mounted) setState(() => _complianceScore = '$score%');
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '--';
    if (ts is Timestamp) {
      final dt = ts.toDate().toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return ts.toString();
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────

class _ComplianceScoreCard extends StatelessWidget {
  final String score;
  final Color color;
  const _ComplianceScoreCard({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user, color: color, size: 48),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('نقاط الامتثال الأمني',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontFamily: 'Tajawal')),
              Text(score,
                  style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: color,
                      fontFamily: 'Tajawal')),
              Text(
                score == '100%'
                    ? 'ممتثل بالكامل'
                    : score == '--'
                        ? 'جارٍ الحساب...'
                        : 'يحتاج مراجعة',
                style: TextStyle(fontSize: 12, color: color, fontFamily: 'Tajawal'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UptimeCard extends StatelessWidget {
  final String uptime;
  const _UptimeCard({required this.uptime});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: AppColors.accent, size: 22),
          const SizedBox(width: 12),
          const Text('وقت تشغيل الجهاز',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
          const Spacer(),
          Text(uptime,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                  fontFamily: 'Tajawal')),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              fontFamily: 'Tajawal',
              letterSpacing: 0.5)),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final int weight;
  const _PermissionRow(
      {required this.label,
      required this.icon,
      required this.active,
      required this.weight});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(active ? Icons.check : Icons.close, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.text, fontFamily: 'Tajawal'))),
          Text('+$weight نقطة',
              style: TextStyle(
                  fontSize: 11,
                  color: active ? AppColors.success : AppColors.textMuted,
                  fontFamily: 'Tajawal')),
          const SizedBox(width: 8),
          Icon(icon, color: active ? color : AppColors.textMuted, size: 18),
        ],
      ),
    );
  }
}

class _RestrictionRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool dangerActive;
  const _RestrictionRow(
      {required this.label,
      required this.icon,
      required this.active,
      this.dangerActive = false});

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (dangerActive) {
      color = active ? AppColors.error : AppColors.textMuted;
    } else {
      color = active ? AppColors.success : AppColors.textMuted;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.text, fontFamily: 'Tajawal'))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              active ? 'مُفعَّل' : 'غير نشط',
              style: TextStyle(fontSize: 11, color: color, fontFamily: 'Tajawal'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppUsageRow extends StatelessWidget {
  final _AppUsageStat stat;
  const _AppUsageRow({required this.stat});

  @override
  Widget build(BuildContext context) {
    final pct = (stat.usageMinutes / 1440).clamp(0.0, 1.0); // من أصل 24 ساعة
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.apps, color: AppColors.accent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(stat.appLabel,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.text, fontFamily: 'Tajawal'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
              Text('${stat.usageMinutes} د',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontFamily: 'Tajawal')),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: pct,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }
}

class _EmptyUsage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Text(
          'لا توجد بيانات استخدام متوفرة\nيتطلب إذن PACKAGE_USAGE_STATS',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13, color: AppColors.textMuted, fontFamily: 'Tajawal'),
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  const _DataRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                  fontFamily: 'Tajawal')),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
        ],
      ),
    );
  }
}

class _AppUsageStat {
  final String packageName;
  final String appLabel;
  final int usageMinutes;
  const _AppUsageStat(
      {required this.packageName,
      required this.appLabel,
      required this.usageMinutes});
}
