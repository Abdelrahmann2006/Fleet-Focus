import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/colors.dart';

/// OffboardingScreen — شاشة إدارة دورة حياة الجهاز (الإيقاف عن الخدمة)
///
/// دورة الحياة:
///   ACTIVE (نشط) → GHOST (شبحي) → RELEASED (محرَّر)
///
/// Ghost State: يُحافظ على كل قيود الأمان، يُعطّل الخدمات غير الضرورية
/// Full Release: يُزيل كل القيود ويُفصل Device Admin نهائياً
class OffboardingScreen extends StatefulWidget {
  final String uid;
  const OffboardingScreen({super.key, required this.uid});

  @override
  State<OffboardingScreen> createState() => _OffboardingScreenState();
}

class _OffboardingScreenState extends State<OffboardingScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundCard,
        title: const Text('إيقاف الجهاز عن الخدمة',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.accent),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('device_states')
            .doc(widget.uid)
            .snapshots(),
        builder: (ctx, snap) {
          final data = snap.data?.data();
          final assetState = data?['assetState'] as String? ?? 'active';
          final ghostAt    = data?['ghostActivatedAt'] as Timestamp?;
          final releasedAt = data?['releasedAt'] as Timestamp?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── بطاقة الحالة الحالية ──────────────────────────
                _buildStateCard(assetState, ghostAt, releasedAt),
                const SizedBox(height: 20),

                // ── دليل مرحلي ───────────────────────────────────
                _buildLifecycleTimeline(assetState),
                const SizedBox(height: 20),

                // ── إجراءات Ghost State ───────────────────────────
                if (assetState == 'active')
                  _buildGhostSection(),
                if (assetState == 'ghost')
                  _buildReleaseSection(),
                if (assetState == 'released')
                  _buildReleasedSection(releasedAt),

                // ── سجل أحداث دورة الحياة ────────────────────────
                const SizedBox(height: 20),
                _buildLifecycleLog(),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── بطاقة الحالة ──────────────────────────────────────────────

  Widget _buildStateCard(String state, Timestamp? ghostAt, Timestamp? releasedAt) {
    final config = _stateConfig(state);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: config.$3, width: 2),
      ),
      child: Column(children: [
        Icon(config.$1, color: config.$3, size: 52),
        const SizedBox(height: 10),
        Text(config.$2,
            style: TextStyle(
                color: config.$3, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          state == 'active'  ? 'الجهاز يعمل بكامل وظائفه تحت الإدارة الكاملة' :
          state == 'ghost'   ? 'قيود الأمان مفعّلة — الخدمات غير الضرورية موقوفة' :
          'تم فصل الجهاز من المنظومة نهائياً',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        if (ghostAt != null && state == 'ghost')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'أُرشف: ${DateFormat('dd/MM/yyyy — HH:mm').format(ghostAt.toDate())}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ),
        if (releasedAt != null && state == 'released')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'أُطلق: ${DateFormat('dd/MM/yyyy — HH:mm').format(releasedAt.toDate())}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ),
      ]),
    );
  }

  (IconData, String, Color) _stateConfig(String state) => switch (state) {
    'ghost'    => (Icons.visibility_off, 'الحالة الشبحية', AppColors.warning),
    'released' => (Icons.lock_open, 'مُطلَق — خارج المنظومة', AppColors.success),
    _          => (Icons.verified_user, 'نشط — قيد الإدارة', AppColors.accent),
  };

  // ── مخطط دورة الحياة ──────────────────────────────────────────

  Widget _buildLifecycleTimeline(String currentState) {
    final steps = [
      ('active',   'نشط',      Icons.shield, AppColors.accent),
      ('ghost',    'شبحي',     Icons.visibility_off, AppColors.warning),
      ('released', 'محرَّر',   Icons.lock_open, AppColors.success),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final i     = entry.key;
          final step  = entry.value;
          final isDone = _stateOrder(currentState) >= _stateOrder(step.$1);
          final isCurrent = currentState == step.$1;

          return Expanded(
            child: Row(children: [
              Expanded(
                child: Column(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCurrent
                          ? step.$4
                          : isDone ? step.$4.withValues(alpha: 0.4) : AppColors.background,
                      border: Border.all(
                          color: isDone ? step.$4 : AppColors.textMuted, width: 2),
                    ),
                    child: Icon(step.$3,
                        color: isDone ? Colors.white : AppColors.textMuted, size: 20),
                  ),
                  const SizedBox(height: 4),
                  Text(step.$2,
                      style: TextStyle(
                          color: isCurrent ? step.$4 : AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                ]),
              ),
              if (i < steps.length - 1)
                Container(width: 20, height: 2,
                    color: _stateOrder(currentState) > i ? AppColors.accent : AppColors.textMuted),
            ]),
          );
        }).toList(),
      ),
    );
  }

  int _stateOrder(String s) => switch (s) {
    'active' => 0, 'ghost' => 1, 'released' => 2, _ => 0
  };

  // ── قسم تفعيل Ghost State ─────────────────────────────────────

  Widget _buildGhostSection() {
    return _ActionCard(
      title: 'الحالة الشبحية (Ghost State)',
      icon: Icons.visibility_off,
      iconColor: AppColors.warning,
      description: 'ينتقل الجهاز إلى وضع الأرشفة. تُحافظ جميع قيود الأمان ويُوقف الوصول للخدمات غير الضرورية. يبقى Device Admin مفعّلاً.',
      warningPoints: const [
        'يُوقف Snap Check-in وDLP Monitor',
        'يُوقف تسجيل الشاشة والرادار الحي',
        'يبقي قفل الشاشة والقيود المؤسسية',
        'يبقى CommandListenerService للطوارئ',
      ],
      buttonLabel: 'تفعيل الحالة الشبحية',
      buttonColor: AppColors.warning,
      isLoading: _isLoading,
      onPressed: _initiateGhostState,
    );
  }

  // ── قسم Full Release ──────────────────────────────────────────

  Widget _buildReleaseSection() {
    return _ActionCard(
      title: 'الإفراج الكامل (Full Release)',
      icon: Icons.lock_open,
      iconColor: AppColors.error,
      description: 'إجراء نهائي لا يمكن التراجع عنه. يُزيل جميع القيود ويُفصل Device Admin ويُوقف جميع الخدمات. الجهاز يخرج من المنظومة.',
      warningPoints: const [
        'يُزيل جميع القيود المؤسسية',
        'يُفصل صلاحيات Device Admin',
        'يُوقف جميع الخدمات الخلفية',
        'لا يمكن التراجع — إجراء دائم',
      ],
      buttonLabel: 'تنفيذ الإفراج الكامل',
      buttonColor: AppColors.error,
      isLoading: _isLoading,
      onPressed: _executeFullRelease,
      requiresDoubleConfirm: true,
    );
  }

  // ── حالة بعد الإفراج ─────────────────────────────────────────

  Widget _buildReleasedSection(Timestamp? releasedAt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Column(children: [
        const Icon(Icons.check_circle_outline, color: AppColors.success, size: 40),
        const SizedBox(height: 8),
        const Text('الجهاز مُطلَق من المنظومة',
            style: TextStyle(color: AppColors.success, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('جميع الصلاحيات مُزالة والخدمات موقوفة.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center),
        if (releasedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              DateFormat('EEEE, dd MMMM yyyy — HH:mm', 'ar').format(releasedAt.toDate()),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ),
      ]),
    );
  }

  // ── سجل أحداث دورة الحياة ────────────────────────────────────

  Widget _buildLifecycleLog() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.history, color: AppColors.accent, size: 16),
          SizedBox(width: 6),
          Text('سجل أحداث دورة الحياة',
              style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
        const Divider(color: AppColors.textMuted, height: 14),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('compliance_assets')
              .doc(widget.uid)
              .collection('lifecycle_events')
              .orderBy('timestamp', descending: true)
              .limit(10)
              .snapshots(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.accent)),
                  ));
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: Text('لا توجد أحداث مسجَّلة',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              );
            }
            return Column(
              children: docs.map((doc) {
                final d  = doc.data();
                final ts = d['timestamp'] as Timestamp?;
                final ev = d['event'] as String? ?? 'unknown';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Icon(_eventIcon(ev), color: _eventColor(ev), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_eventLabel(ev),
                          style: TextStyle(color: _eventColor(ev), fontSize: 12)),
                    ),
                    if (ts != null)
                      Text(
                        DateFormat('HH:mm dd/MM').format(ts.toDate()),
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                      ),
                  ]),
                );
              }).toList(),
            );
          },
        ),
      ]),
    );
  }

  IconData _eventIcon(String ev) => switch (ev) {
    'ghost_state_activated' => Icons.visibility_off,
    'full_release_executed' => Icons.lock_open,
    _ => Icons.circle,
  };

  Color _eventColor(String ev) => switch (ev) {
    'ghost_state_activated' => AppColors.warning,
    'full_release_executed' => AppColors.success,
    _ => AppColors.textMuted,
  };

  String _eventLabel(String ev) => switch (ev) {
    'ghost_state_activated' => 'تم تفعيل الحالة الشبحية',
    'full_release_executed' => 'تم تنفيذ الإفراج الكامل',
    _ => ev,
  };

  // ── الإجراءات ─────────────────────────────────────────────────

  Future<void> _initiateGhostState() async {
    final confirmed = await _showConfirmDialog(
      title: 'تأكيد الحالة الشبحية',
      message: 'هل أنت متأكد من أرشفة هذا الجهاز؟ ستُوقف الخدمات غير الضرورية مع الحفاظ على الأمان.',
      confirmLabel: 'نعم، أرشِف الجهاز',
      confirmColor: AppColors.warning,
    );
    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('device_commands')
          .doc(widget.uid)
          .set({
        'command': 'initiate_ghost_state',
        'payload': {},
        'acknowledged': false,
        'issuedAt': FieldValue.serverTimestamp(),
      });
      _showSnack('✓ أمر الحالة الشبحية أُرسل');
    } catch (e) {
      _showSnack('خطأ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _executeFullRelease() async {
    // تأكيد مزدوج لعملية خطيرة
    final step1 = await _showConfirmDialog(
      title: 'تحذير — إجراء لا يُعاد',
      message: 'الإفراج الكامل يُزيل كل الصلاحيات ويُخرج الجهاز من المنظومة نهائياً. هل تريد المتابعة؟',
      confirmLabel: 'نعم، أفهم المخاطر',
      confirmColor: AppColors.error,
    );
    if (!step1) return;

    final step2 = await _showConfirmDialog(
      title: 'تأكيد أخير',
      message: 'هل أنت متأكد تماماً؟ لا يمكن التراجع عن هذا الإجراء.',
      confirmLabel: 'نفّذ الإفراج الكامل',
      confirmColor: AppColors.error,
    );
    if (!step2) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('device_commands')
          .doc(widget.uid)
          .set({
        'command': 'full_release',
        'payload': {},
        'acknowledged': false,
        'issuedAt': FieldValue.serverTimestamp(),
      });
      _showSnack('✓ أمر الإفراج الكامل أُرسل — جارٍ تنفيذه على الجهاز');
    } catch (e) {
      _showSnack('خطأ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: Text(title,
            style: TextStyle(color: confirmColor, fontWeight: FontWeight.bold)),
        content: Text(message,
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            child: Text(confirmLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }
}

// ── بطاقة الإجراء ────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String description;
  final List<String> warningPoints;
  final String buttonLabel;
  final Color buttonColor;
  final bool isLoading;
  final VoidCallback onPressed;
  final bool requiresDoubleConfirm;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.description,
    required this.warningPoints,
    required this.buttonLabel,
    required this.buttonColor,
    required this.isLoading,
    required this.onPressed,
    this.requiresDoubleConfirm = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(color: iconColor, fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        Text(description,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: warningPoints.map((p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Icon(Icons.arrow_left, color: iconColor, size: 14),
                const SizedBox(width: 4),
                Expanded(child: Text(p,
                    style: TextStyle(color: iconColor, fontSize: 11))),
              ]),
            )).toList(),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: isLoading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(icon),
            label: Text(isLoading ? 'جارٍ التنفيذ...' : buttonLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
      ]),
    );
  }
}
