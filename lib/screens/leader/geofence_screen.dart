import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/colors.dart';
import '../../services/geofence_service.dart';

/// GeofenceScreen — شاشة إدارة النطاق الجغرافي الآمن
///
/// تتيح للمشرف:
/// - تعيين مركز النطاق (خط العرض/الطول) ونصف قطره
/// - تفعيل/تعطيل المراقبة
/// - منح/سحب تصاريح التنقل
/// - مشاهدة سجل الخروقات بث مباشر
/// - مشاهدة موقع الجهاز الحالي وهل هو داخل النطاق
class GeofenceScreen extends StatefulWidget {
  final String uid;
  const GeofenceScreen({super.key, required this.uid});

  @override
  State<GeofenceScreen> createState() => _GeofenceScreenState();
}

class _GeofenceScreenState extends State<GeofenceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // حقول إعداد النطاق
  final _latCtrl     = TextEditingController();
  final _lonCtrl     = TextEditingController();
  final _radiusCtrl  = TextEditingController(text: '500');
  final _reasonCtrl  = TextEditingController(text: 'مهمة رسمية');
  int _travelHours   = 2;
  bool _isSaving     = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadCurrentConfig();
  }

  void _loadCurrentConfig() {
    GeofenceService.instance.configStream(widget.uid).first.then((snap) {
      if (!snap.exists || snap.data() == null) return;
      final cfg = GeofenceConfig.fromMap(snap.data()!);
      if (!mounted) return;
      _latCtrl.text    = cfg.centerLat != 0.0 ? cfg.centerLat.toStringAsFixed(6) : '';
      _lonCtrl.text    = cfg.centerLon != 0.0 ? cfg.centerLon.toStringAsFixed(6) : '';
      _radiusCtrl.text = cfg.radiusMeters.toStringAsFixed(0);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    _radiusCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundCard,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('النطاق الجغرافي الآمن',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('UID: ${widget.uid.substring(0, 8)}...',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
        iconTheme: const IconThemeData(color: AppColors.accent),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(text: 'الإعداد'),
            Tab(text: 'الحالة'),
            Tab(text: 'السجل'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ConfigTab(
            uid: widget.uid,
            latCtrl: _latCtrl,
            lonCtrl: _lonCtrl,
            radiusCtrl: _radiusCtrl,
            reasonCtrl: _reasonCtrl,
            travelHours: _travelHours,
            isSaving: _isSaving,
            onTravelHoursChanged: (v) => setState(() => _travelHours = v),
            onSave: _saveGeofence,
            onGrantPass: _grantTravelPass,
            onRevokePass: _revokeTravelPass,
            onDisable: _disableGeofence,
          ),
          _StatusTab(uid: widget.uid),
          _BreachLogTab(uid: widget.uid),
        ],
      ),
    );
  }

  Future<void> _saveGeofence() async {
    final lat    = double.tryParse(_latCtrl.text.trim());
    final lon    = double.tryParse(_lonCtrl.text.trim());
    final radius = double.tryParse(_radiusCtrl.text.trim());

    if (lat == null || lon == null || radius == null || radius <= 0) {
      _showSnack('يرجى إدخال إحداثيات ونصف قطر صحيح', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await GeofenceService.instance.setGeofence(
        uid: widget.uid,
        centerLat: lat,
        centerLon: lon,
        radiusMeters: radius,
      );
      _showSnack('✓ النطاق مُعيَّن وسيُطبَّق على الجهاز');
    } catch (e) {
      _showSnack('خطأ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _grantTravelPass() async {
    try {
      await GeofenceService.instance.grantTravelPass(
        widget.uid,
        durationHours: _travelHours,
        reason: _reasonCtrl.text.trim().isNotEmpty
            ? _reasonCtrl.text.trim()
            : 'مجاز',
      );
      _showSnack('✓ تصريح تنقل مُمنوح لـ $_travelHours ساعة');
    } catch (e) {
      _showSnack('خطأ: $e', isError: true);
    }
  }

  Future<void> _revokeTravelPass() async {
    try {
      await GeofenceService.instance.revokeTravelPass(widget.uid);
      _showSnack('✓ تصريح التنقل مُسحوب');
    } catch (e) {
      _showSnack('خطأ: $e', isError: true);
    }
  }

  Future<void> _disableGeofence() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: const Text('تعطيل النطاق', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('هل تريد تعطيل مراقبة النطاق الجغرافي؟',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('تعطيل', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await GeofenceService.instance.disableGeofence(widget.uid);
      _showSnack('✓ النطاق الجغرافي مُعطَّل');
    } catch (e) {
      _showSnack('خطأ: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }
}

// ── تبويب الإعداد ────────────────────────────────────────────────

class _ConfigTab extends StatelessWidget {
  final String uid;
  final TextEditingController latCtrl, lonCtrl, radiusCtrl, reasonCtrl;
  final int travelHours;
  final bool isSaving;
  final ValueChanged<int> onTravelHoursChanged;
  final VoidCallback onSave, onGrantPass, onRevokePass, onDisable;

  const _ConfigTab({
    required this.uid,
    required this.latCtrl,
    required this.lonCtrl,
    required this.radiusCtrl,
    required this.reasonCtrl,
    required this.travelHours,
    required this.isSaving,
    required this.onTravelHoursChanged,
    required this.onSave,
    required this.onGrantPass,
    required this.onRevokePass,
    required this.onDisable,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionCard(
            title: 'تعيين منطقة العمل',
            icon: Icons.location_on,
            iconColor: AppColors.accent,
            children: [
              _InputRow(label: 'خط العرض (Lat)', controller: latCtrl,
                  hint: 'مثال: 24.688'),
              const SizedBox(height: 10),
              _InputRow(label: 'خط الطول (Lon)', controller: lonCtrl,
                  hint: 'مثال: 46.721'),
              const SizedBox(height: 10),
              _InputRow(label: 'نصف القطر (متر)', controller: radiusCtrl,
                  hint: '500', keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isSaving ? null : onSave,
                    icon: isSaving
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.check_circle_outline),
                    label: Text(isSaving ? 'جارٍ الحفظ...' : 'تطبيق النطاق'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onDisable,
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16)),
                  child: const Text('تعطيل'),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'تصريح التنقل (Travel Pass)',
            icon: Icons.card_travel,
            iconColor: AppColors.info,
            children: [
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: GeofenceService.instance.configStream(uid),
                builder: (ctx, snap) {
                  if (!snap.hasData || !snap.data!.exists) {
                    return const _StatusBadge(label: 'لا توجد بيانات', color: AppColors.textMuted);
                  }
                  final cfg = GeofenceConfig.fromMap(snap.data!.data()!);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        _StatusBadge(
                          label: cfg.travelPassActive
                              ? 'مفعّل — ينتهي: ${cfg.travelPassExpiryFormatted}'
                              : 'غير مفعّل',
                          color: cfg.travelPassActive ? AppColors.success : AppColors.textMuted,
                        ),
                      ]),
                      if (cfg.travelPassActive)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('السبب: ${cfg.travelPassReason}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              _InputRow(label: 'سبب التصريح', controller: reasonCtrl,
                  hint: 'مهمة رسمية'),
              const SizedBox(height: 10),
              Row(children: [
                const Text('المدة: ', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                ...([1, 2, 4, 8].map((h) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => onTravelHoursChanged(h),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: travelHours == h ? AppColors.accent : AppColors.backgroundCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: travelHours == h ? AppColors.accent : AppColors.textMuted,
                            width: 1),
                      ),
                      child: Text('${h}h',
                          style: TextStyle(
                              color: travelHours == h ? Colors.black : AppColors.textSecondary,
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onGrantPass,
                    icon: const Icon(Icons.check),
                    label: Text('منح تصريح ${travelHours}h'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onRevokePass,
                  icon: const Icon(Icons.block),
                  label: const Text('سحب'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: const BorderSide(color: AppColors.warning),
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12)),
                ),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}

// ── تبويب الحالة ─────────────────────────────────────────────────

class _StatusTab extends StatelessWidget {
  final String uid;
  const _StatusTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: GeofenceService.instance.statusStream(uid),
      builder: (ctx, statusSnap) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: GeofenceService.instance.configStream(uid),
          builder: (ctx, cfgSnap) {
            final statusData = statusSnap.data?.data();
            final cfgData    = cfgSnap.data?.data();
            final cfg = cfgData != null ? GeofenceConfig.fromMap(cfgData) : null;
            final insideZone = statusData?['insideZone'] as bool?;
            final lastLat    = (statusData?['lastLat'] as num?)?.toDouble();
            final lastLon    = (statusData?['lastLon'] as num?)?.toDouble();
            final lastTs     = statusData?['lastChecked'];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // بطاقة الحالة الرئيسية
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: geofenceStatusColor(insideZone),
                        width: 2,
                      ),
                    ),
                    child: Column(children: [
                      Icon(
                        insideZone == true ? Icons.verified_user : Icons.gpp_bad,
                        color: geofenceStatusColor(insideZone),
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        insideZone == true ? 'داخل النطاق الآمن' :
                        insideZone == false ? 'خارج النطاق!' : 'حالة غير معروفة',
                        style: TextStyle(
                          color: geofenceStatusColor(insideZone),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (cfg != null && cfg.enabled == false)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text('المراقبة مُعطَّلة',
                              style: TextStyle(color: AppColors.warning, fontSize: 12)),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  // تفاصيل الموقع
                  _SectionCard(
                    title: 'الموقع الأخير',
                    icon: Icons.my_location,
                    iconColor: AppColors.info,
                    children: [
                      _InfoRow('خط العرض',
                          lastLat?.toStringAsFixed(6) ?? '—'),
                      _InfoRow('خط الطول',
                          lastLon?.toStringAsFixed(6) ?? '—'),
                      _InfoRow('التحديث الأخير',
                          lastTs is Timestamp
                              ? DateFormat('HH:mm:ss - dd/MM', 'ar').format(lastTs.toDate())
                              : '—'),
                      _InfoRow('الدقة',
                          '${((statusData?['accuracy'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)} م'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // إعدادات النطاق
                  if (cfg != null)
                    _SectionCard(
                      title: 'إعدادات النطاق',
                      icon: Icons.adjust,
                      iconColor: AppColors.accent,
                      children: [
                        _InfoRow('المركز', cfg.centerFormatted),
                        _InfoRow('نصف القطر', cfg.radiusFormatted),
                        _InfoRow('الحالة', cfg.enabled ? 'مُفعَّل' : 'مُعطَّل'),
                        _InfoRow('Travel Pass',
                            cfg.travelPassActive
                                ? 'مفعّل — ${cfg.travelPassExpiryFormatted}'
                                : 'غير مفعّل'),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── تبويب سجل الخروقات ───────────────────────────────────────────

class _BreachLogTab extends StatelessWidget {
  final String uid;
  const _BreachLogTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: GeofenceService.instance.breachLogStream(uid),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.accent)));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('لا توجد خروقات مسجَّلة',
              style: TextStyle(color: AppColors.textMuted)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data();
            final ts = d['timestamp'] as Timestamp?;
            final distance = (d['distanceMeters'] as num?)?.toInt() ?? 0;
            final hasPass = d['travelPassActive'] as bool? ?? false;
            final severity = d['severity'] as String? ?? 'INFO';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: severity == 'CRITICAL' ? AppColors.error : AppColors.warning,
                  width: 1,
                ),
              ),
              child: Row(children: [
                Icon(
                  severity == 'CRITICAL' ? Icons.gpp_bad : Icons.warning_amber,
                  color: severity == 'CRITICAL' ? AppColors.error : AppColors.warning,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(
                        severity == 'CRITICAL' ? 'خرق أمني' : 'خروج مُصرَّح',
                        style: TextStyle(
                          color: severity == 'CRITICAL' ? AppColors.error : AppColors.warning,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (hasPass)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: _StatusBadge(label: 'Travel Pass', color: AppColors.success),
                        ),
                    ]),
                    Text('المسافة: $distance م',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    if (ts != null)
                      Text(
                        DateFormat('HH:mm:ss - dd/MM/yyyy', 'ar').format(ts.toDate()),
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                  ]),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

// ── Widgets مشتركة ────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 6),
          Text(title,
              style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ]),
        const Divider(color: AppColors.textMuted, height: 14),
        ...children,
      ]),
    );
  }
}

class _InputRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;

  const _InputRow({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
        ),
      ),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text('$label: ', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        Expanded(
          child: Text(value,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              textAlign: TextAlign.left),
        ),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
