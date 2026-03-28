import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';

/// ParticipantSovereignPortal — البوابة السيادية للمشارك
///
/// 13 تبويباً لغرفة التحكم الكاملة للعنصر:
///   1.  سجل الأوامر   — كل أمر أرسله القائد مع التوقيت والحالة
///   2.  الحسابات      — الرصيد / الديون / سلسلة الولاء
///   3.  الدستور       — نص الاتفاقية + بيانات التوقيع البيولوجي
///   4.  المهام         — قائمة المهام المسندة وحالتها
///   5.  الموقع         — سجل النطاق الجغرافي والمخالفات
///   6.  الحضور         — سجل تسجيل الحضور اليومي
///   7.  الإنجازات      — النقاط والجوائز والعقوبات
///   8.  الصور الإلزامية — سجل صور Snap Check-in
///   9.  التقارير       — التقارير الذاتية المقدّمة
///   10. المهارات       — ملف المهارات والتقييم
///   11. حالة الجهاز   — بيانات MDM والنشاط
///   12. التنبيهات      — إشعارات النظام والتحذيرات
///   13. طلباتي         — بوابة الطلبات والعرائض
class ParticipantSovereignPortal extends StatelessWidget {
  const ParticipantSovereignPortal({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid ?? '';
    return DefaultTabController(
      length: 13,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundCard,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'البوابة السيادية',
            style: TextStyle(
                color: AppColors.accent,
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w800,
                fontSize: 18),
          ),
          iconTheme: const IconThemeData(color: AppColors.textSecondary),
          bottom: const TabBar(
            indicatorColor: AppColors.accent,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 11),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.receipt_long_outlined, size: 16), text: 'الأوامر'),
              Tab(icon: Icon(Icons.account_balance_wallet_outlined, size: 16), text: 'الحسابات'),
              Tab(icon: Icon(Icons.gavel_outlined, size: 16), text: 'الدستور'),
              Tab(icon: Icon(Icons.task_alt_outlined, size: 16), text: 'المهام'),
              Tab(icon: Icon(Icons.fence_outlined, size: 16), text: 'الموقع'),
              Tab(icon: Icon(Icons.how_to_reg_outlined, size: 16), text: 'الحضور'),
              Tab(icon: Icon(Icons.emoji_events_outlined, size: 16), text: 'الإنجازات'),
              Tab(icon: Icon(Icons.camera_alt_outlined, size: 16), text: 'الصور'),
              Tab(icon: Icon(Icons.summarize_outlined, size: 16), text: 'تقاريري'),
              Tab(icon: Icon(Icons.radar_outlined, size: 16), text: 'مهاراتي'),
              Tab(icon: Icon(Icons.phone_android_outlined, size: 16), text: 'الجهاز'),
              Tab(icon: Icon(Icons.notifications_outlined, size: 16), text: 'التنبيهات'),
              Tab(icon: Icon(Icons.sos_outlined, size: 16), text: 'طلباتي'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AuditLogTab(uid: uid),
            _LedgerTab(uid: uid),
            _ConstitutionTab(uid: uid),
            _TasksTab(uid: uid),
            _GeofenceTab(uid: uid),
            _AttendanceTab(uid: uid),
            _AchievementsTab(uid: uid),
            _SnapCheckinTab(uid: uid),
            _SelfReportsTab(uid: uid),
            _SkillsTab(uid: uid),
            _DeviceStatusTab(uid: uid),
            _AlertsTab(uid: uid),
            _PetitionsTab(uid: uid),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1: سجل الأوامر السيادي ───────────────────────────────────────────────

class _AuditLogTab extends StatelessWidget {
  final String uid;
  const _AuditLogTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('compliance_assets')
          .doc(uid)
          .collection('command_log')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.accent));
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'لا توجد أوامر مُسجَّلة',
            subtitle: 'كل أمر يُرسله القائد سيظهر هنا',
          );
        }

        final docs = snap.data!.docs;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _SectionHeader(
                label: '${docs.length} أمر مُسجَّل',
                icon: Icons.history_outlined),
            const SizedBox(height: 12),
            ...docs.map((doc) {
              final d         = doc.data() as Map<String, dynamic>;
              final cmd       = d['command'] as String? ?? 'unknown';
              final ts        = (d['timestamp'] as Timestamp?)?.toDate();
              final status    = d['status'] as String? ?? 'executed';
              final params    = d['params'] as Map? ?? {};
              final timeStr   = ts != null
                  ? '${ts.day}/${ts.month} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}'
                  : '—';
              return _AuditCard(
                  command: cmd,
                  timeStr: timeStr,
                  status: status,
                  params: params);
            }),
          ],
        );
      },
    );
  }
}

class _AuditCard extends StatelessWidget {
  final String command, timeStr, status;
  final Map params;
  const _AuditCard(
      {required this.command,
      required this.timeStr,
      required this.status,
      required this.params});

  @override
  Widget build(BuildContext context) {
    final cmdAr = _commandArabic(command);
    final statusColor = status == 'executed'
        ? AppColors.success
        : status == 'failed'
            ? AppColors.error
            : AppColors.warning;
    final statusAr = status == 'executed'
        ? 'مُنفَّذ'
        : status == 'failed'
            ? 'فاشل'
            : 'مُعلَّق';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.terminal_outlined,
                color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cmdAr,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text('`$command`',
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontFamily: 'monospace',
                        fontSize: 10)),
                if (params.isNotEmpty)
                  Text(
                    params.entries
                        .take(2)
                        .map((e) => '${e.key}: ${e.value}')
                        .join(' · '),
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Tajawal',
                        fontSize: 11),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(statusAr,
                    style: TextStyle(
                        color: statusColor,
                        fontFamily: 'Tajawal',
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 4),
              Text(timeStr,
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontFamily: 'Tajawal')),
            ],
          ),
        ],
      ),
    );
  }

  String _commandArabic(String cmd) {
    const map = {
      'lock_screen':                  'قفل الشاشة',
      'enable_kiosk':                 'تفعيل وضع Kiosk',
      'disable_kiosk':                'إلغاء وضع Kiosk',
      'update_blocked_apps':          'تحديث التطبيقات المحجوبة',
      'activate_lost_mode':           'تفعيل وضع الضياع',
      'deactivate_lost_mode':         'إلغاء وضع الضياع',
      'trigger_panic_alarm':          'تشغيل إنذار الذعر',
      'stop_panic_alarm':             'إيقاف إنذار الذعر',
      'apply_enterprise_restrictions':'تطبيق قيود المؤسسة',
      'clear_enterprise_restrictions':'رفع قيود المؤسسة',
      'set_airplane_mode_blocked':    'حظر وضع الطيران',
      'set_admin_phone':              'تعيين هاتف المشرف',
      'set_oob_enabled':              'تفعيل بروتوكول OOB',
      'snap_checkin_selfie':          'التقاط صورة سيلفي',
      'snap_checkin_surroundings':    'التقاط صور المحيط',
      'stop_screen_recording':        'إيقاف تسجيل الشاشة',
      'set_geofence':                 'تعيين منطقة جغرافية',
      'disable_geofence':             'إلغاء المنطقة الجغرافية',
      'grant_travel_pass':            'منح تصريح سفر',
      'revoke_travel_pass':           'سحب تصريح السفر',
      'enable_radar_mode':            'تفعيل وضع الرادار',
      'disable_radar_mode':           'إيقاف وضع الرادار',
      'launch_mandatory_app':         'تشغيل التطبيق الإلزامي',
      'stop_mandatory_app':           'إيقاف التطبيق الإلزامي',
      'initiate_ghost_state':         'تفعيل الحالة الشبحية',
      'full_release':                 'إطلاق كامل للجهاز',
      'report_device_state':          'طلب تقرير الجهاز',
      'push_rtdb_command':            'أمر RTDB مباشر',
      'start_ambient_audio':          'بدء تحليل الصوت المحيطي',
      'stop_ambient_audio':           'إيقاف تحليل الصوت',
      'enable_notification_scan':     'تفعيل مسح الإشعارات',
      'disable_notification_scan':    'إيقاف مسح الإشعارات',
    };
    return map[cmd] ?? cmd;
  }
}

// ── Tab 2: دفتر الحسابات والولاء ────────────────────────────────────────────

class _LedgerTab extends StatelessWidget {
  final String uid;
  const _LedgerTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.accent));
        }

        final d       = (snap.data?.data() as Map<String, dynamic>?) ?? {};
        final credits = (d['credits'] as num?)?.toInt() ?? 0;
        final debt    = (d['debt'] as num?)?.toInt() ?? 0;
        final loyalty = (d['loyaltyStreak'] as num?)?.toInt() ?? 0;
        final balance = credits - debt;
        final isPositive = balance >= 0;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── بطاقة الرصيد الرئيسية ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPositive
                      ? [AppColors.accent.withOpacity(0.15), AppColors.backgroundCard]
                      : [AppColors.error.withOpacity(0.1), AppColors.backgroundCard],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isPositive
                        ? AppColors.accent.withOpacity(0.3)
                        : AppColors.error.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(
                    isPositive
                        ? Icons.trending_up_outlined
                        : Icons.trending_down_outlined,
                    color: isPositive ? AppColors.accent : AppColors.error,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  const Text('الرصيد الصافي',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontFamily: 'Tajawal',
                          fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    '${isPositive ? '+' : ''}${_formatNum(balance)} نقطة',
                    style: TextStyle(
                        color: isPositive ? AppColors.accent : AppColors.error,
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w800,
                        fontSize: 32),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── بطاقات المكونات ───────────────────────────────────────────
            Row(children: [
              Expanded(
                  child: _LedgerCard(
                      label: 'رصيد مكتسب',
                      value: '${_formatNum(credits)} نقطة',
                      icon: Icons.add_circle_outline,
                      color: AppColors.success)),
              const SizedBox(width: 12),
              Expanded(
                  child: _LedgerCard(
                      label: 'ديون مُتراكمة',
                      value: '${_formatNum(debt)} نقطة',
                      icon: Icons.remove_circle_outline,
                      color: AppColors.error)),
            ]),

            const SizedBox(height: 12),

            // ── سلسلة الولاء ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('سلسلة الولاء',
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontFamily: 'Tajawal',
                              fontSize: 12)),
                      Text('$loyalty يوم متواصل',
                          style: const TextStyle(
                              color: AppColors.text,
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                    ],
                  ),
                  const Spacer(),
                  // Visual streak flames
                  Row(children: List.generate(
                    loyalty.clamp(0, 7),
                    (_) => const Padding(
                      padding: EdgeInsets.only(left: 2),
                      child: Icon(Icons.local_fire_department_outlined,
                          color: AppColors.warning, size: 22),
                    ),
                  )),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── شريط التقدم نحو المكافأة ──────────────────────────────────
            _SectionHeader(label: 'التقدم نحو المكافأة', icon: Icons.emoji_events_outlined),
            const SizedBox(height: 10),
            _RewardProgressBar(credits: credits),

            const SizedBox(height: 20),
            const _SectionHeader(label: 'ملاحظة', icon: Icons.info_outline),
            const SizedBox(height: 8),
            const Text(
              'النقاط تُحسب بناءً على الالتزام اليومي، وتحقيق المهام، والإنجازات. الديون تنتج من مخالفات السياسات أو الغياب.',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Tajawal',
                  fontSize: 13,
                  height: 1.6),
              textDirection: TextDirection.rtl,
            ),
          ],
        );
      },
    );
  }

  String _formatNum(int n) {
    if (n.abs() >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return n.toString();
  }
}

class _LedgerCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _LedgerCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontFamily: 'Tajawal',
                  fontSize: 11)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
        ],
      ),
    );
  }
}

class _RewardProgressBar extends StatelessWidget {
  final int credits;
  const _RewardProgressBar({required this.credits});

  @override
  Widget build(BuildContext context) {
    final tiers = [
      (500, 'فضي', AppColors.textSecondary),
      (1500, 'ذهبي', AppColors.accent),
      (3000, 'بلاتيني', AppColors.info),
      (5000, 'ماسي', AppColors.success),
    ];

    int nextTierCredits = tiers
        .firstWhere((t) => credits < t.$1,
            orElse: () => tiers.last)
        .$1;
    final prevTier = credits >= tiers.last.$1 ? tiers.last.$1 : tiers
        .lastWhere((t) => credits >= t.$1, orElse: () => (0, '', Colors.transparent))
        .$1;
    final progress = nextTierCredits == prevTier
        ? 1.0
        : ((credits - prevTier) / (nextTierCredits - prevTier)).clamp(0.0, 1.0);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: tiers.map((t) => Column(children: [
            Icon(Icons.circle, size: 8,
                color: credits >= t.$1 ? t.$3 : AppColors.border),
            const SizedBox(height: 2),
            Text(t.$2,
                style: TextStyle(
                    color: credits >= t.$1 ? t.$3 : AppColors.textMuted,
                    fontFamily: 'Tajawal',
                    fontSize: 10)),
          ])).toList(),
        ),
      ],
    );
  }
}

// ── Tab 3: الدستور الرقمي ─────────────────────────────────────────────────────

class _ConstitutionTab extends StatelessWidget {
  final String uid;
  const _ConstitutionTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.accent));
        }

        final d        = (snap.data?.data() as Map<String, dynamic>?) ?? {};
        final sigMeta  = (d['signatureMetadata'] as Map<String, dynamic>?) ?? {};
        final sigTs    = (d['signedAt'] as Timestamp?)?.toDate();
        final sigTsStr = sigTs != null
            ? '${sigTs.day}/${sigTs.month}/${sigTs.year} — ${sigTs.hour.toString().padLeft(2, '0')}:${sigTs.minute.toString().padLeft(2, '0')}'
            : '—';
        final isSigned = sigMeta.isNotEmpty || sigTs != null;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── بطاقة حالة التوقيع ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSigned
                    ? AppColors.success.withOpacity(0.08)
                    : AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: isSigned
                        ? AppColors.success.withOpacity(0.3)
                        : AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(children: [
                Icon(
                  isSigned
                      ? Icons.verified_outlined
                      : Icons.pending_outlined,
                  color: isSigned ? AppColors.success : AppColors.warning,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSigned ? 'الوثيقة موقَّعة ونافذة' : 'لم يُوقَّع بعد',
                        style: TextStyle(
                            color: isSigned
                                ? AppColors.success
                                : AppColors.warning,
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                      if (isSigned)
                        Text('تاريخ التوقيع: $sigTsStr',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontFamily: 'Tajawal',
                                fontSize: 11)),
                    ],
                  ),
                ),
              ]),
            ),

            if (isSigned && sigMeta.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionHeader(
                  label: 'بيانات التوقيع البيولوجي', icon: Icons.fingerprint),
              const SizedBox(height: 10),
              ..._biometricRows(sigMeta),
            ],

            const SizedBox(height: 20),
            _SectionHeader(
                label: 'ملخص بنود الاتفاقية', icon: Icons.gavel_outlined),
            const SizedBox(height: 12),
            ..._constitutionArticles.map((a) => _ArticleCard(
                number: a.$1, title: a.$2, summary: a.$3)),
          ],
        );
      },
    );
  }

  List<Widget> _biometricRows(Map<String, dynamic> meta) {
    final rows = <(String, String, IconData)>[
      ('متوسط السرعة',    '${(meta['averageSpeed'] as num?)?.toStringAsFixed(2) ?? '—'} px/ms',  Icons.speed_outlined),
      ('الضغط المتوسط',   '${(meta['avgPressure'] as num?)?.toStringAsFixed(2) ?? '—'}',          Icons.touch_app_outlined),
      ('إجمالي النقاط',   '${(meta['totalPoints'] as num?)?.toInt() ?? '—'} نقطة حركة',          Icons.gesture_outlined),
      ('حالة التحقق',     meta['isValid'] == true ? 'صالحة ✓' : 'غير صالحة',                     Icons.verified_user_outlined),
    ];
    return rows.map((r) => _BiometricRow(label: r.$1, value: r.$2, icon: r.$3)).toList();
  }

  static const _constitutionArticles = [
    ('1', 'الأطراف والتعريفات',
        'يُبرم هذا الاتفاق بين القائد (الطرف الأول) والمشارك (الطرف الثاني) طوعاً وبدون إكراه.'),
    ('2', 'نطاق الصلاحيات',
        'يُخوَّل القائد بمراقبة الأداء الرقمي وتفعيل آليات الامتثال المُحددة في هذه الوثيقة.'),
    ('3', 'حقوق المشارك',
        'يحتفظ المشارك بحق الاطلاع على سجل الأوامر وحقه في تقديم طلب مساعدة طارئة في أي وقت.'),
    ('4', 'التزامات المشارك',
        'يلتزم المشارك بالتواجد اليومي والإفصاح الصادق وعدم محاولة تجاوز منظومة الرقابة.'),
    ('5', 'إنهاء الاتفاق',
        'يُنهى الاتفاق عند انتهاء المنافسة أو بإشعار صريح من كلا الطرفين.'),
  ];
}

class _ArticleCard extends StatelessWidget {
  final String number, title, summary;
  const _ArticleCard(
      {required this.number, required this.title, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(number,
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(height: 4),
                Text(summary,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BiometricRow extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _BiometricRow(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Icon(icon, color: AppColors.info, size: 16),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Tajawal',
                  fontSize: 12)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: AppColors.text,
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
        ]),
      ),
    );
  }
}

// ── مكونات مشتركة ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Spacer(),
      Text(label,
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w600,
              fontSize: 13)),
      const SizedBox(width: 6),
      Icon(icon, color: AppColors.accent, size: 16),
    ]);
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.border),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w600,
                  fontSize: 16)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontFamily: 'Tajawal',
                  fontSize: 13),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 4: المهام المسندة
// ─────────────────────────────────────────────────────────────────────────────
class _TasksTab extends StatelessWidget {
  final String uid;
  const _TasksTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('compliance_assets')
          .doc(uid)
          .collection('tasks')
          .orderBy('assigned_at', descending: true)
          .limit(30)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const _EmptyState(icon: Icons.task_alt_outlined, title: 'لا توجد مهام مسندة حالياً', subtitle: '');
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final status = d['status'] as String? ?? 'pending';
            final statusColor = status == 'done' ? AppColors.success : status == 'overdue' ? AppColors.error : AppColors.warning;
            final statusLabel = status == 'done' ? 'مكتملة' : status == 'overdue' ? 'متأخرة' : 'قيد التنفيذ';
            final ts = (d['assigned_at'] as Timestamp?)?.toDate();
            final due = (d['due_at'] as Timestamp?)?.toDate();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(statusLabel, style: TextStyle(color: statusColor, fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  Text(d['title'] as String? ?? 'مهمة', style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 14), textDirection: TextDirection.rtl),
                ]),
                if ((d['description'] as String?)?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 6),
                  Text(d['description'] as String, style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 12), textDirection: TextDirection.rtl, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  if (due != null) Text('الموعد: ${due.day}/${due.month}/${due.year}', style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11)),
                  if (ts != null) Text('أُسندت: ${ts.day}/${ts.month}', style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11)),
                ]),
              ]),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 5: الموقع الجغرافي (سجل النطاق)
// ─────────────────────────────────────────────────────────────────────────────
class _GeofenceTab extends StatelessWidget {
  final String uid;
  const _GeofenceTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('compliance_assets')
          .doc(uid)
          .collection('breach_log')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }
        final docs = snap.data?.docs ?? [];
        return Column(children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _StatPill(label: 'مخالفات النطاق', value: docs.where((d) => (d.data() as Map)['type'] == 'breach').length.toString(), color: AppColors.error),
              _StatPill(label: 'إجمالي الأحداث', value: docs.length.toString(), color: AppColors.accent),
            ]),
          ),
          Expanded(
            child: docs.isEmpty
                ? const _EmptyState(icon: Icons.fence_outlined, title: 'لا توجد أحداث جغرافية مسجّلة', subtitle: '')
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: docs.length,
                    itemBuilder: (ctx, i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      final type = d['type'] as String? ?? 'event';
                      final isBreach = type == 'breach';
                      final ts = (d['timestamp'] as Timestamp?)?.toDate();
                      return _SimpleRow(
                        icon: isBreach ? Icons.location_off_outlined : Icons.location_on_outlined,
                        color: isBreach ? AppColors.error : AppColors.success,
                        title: isBreach ? 'مخالفة نطاق جغرافي' : 'دخول النطاق',
                        subtitle: ts != null ? '${ts.day}/${ts.month}/${ts.year}  ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}' : '',
                      );
                    },
                  ),
          ),
        ]);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 6: سجل الحضور
// ─────────────────────────────────────────────────────────────────────────────
class _AttendanceTab extends StatelessWidget {
  final String uid;
  const _AttendanceTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('compliance_assets')
          .doc(uid)
          .collection('attendance_log')
          .orderBy('timestamp', descending: true)
          .limit(60)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const _EmptyState(icon: Icons.how_to_reg_outlined, title: 'لا توجد سجلات حضور بعد', subtitle: '');
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final type = d['type'] as String? ?? 'check_in';
            final ts = (d['timestamp'] as Timestamp?)?.toDate();
            final isIn = type.contains('in');
            return _SimpleRow(
              icon: isIn ? Icons.login_outlined : Icons.logout_outlined,
              color: isIn ? AppColors.success : AppColors.info,
              title: isIn ? 'تسجيل دخول' : 'تسجيل خروج',
              subtitle: ts != null ? '${ts.day}/${ts.month}/${ts.year}  ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}' : '',
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 7: الإنجازات والعقوبات
// ─────────────────────────────────────────────────────────────────────────────
class _AchievementsTab extends StatelessWidget {
  final String uid;
  const _AchievementsTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('compliance_assets').doc(uid).snapshots(),
      builder: (ctx, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final points = data['points'] as int? ?? 0;
        final strikes = data['strikes'] as int? ?? 0;
        final level = data['loyalty_level'] as int? ?? 1;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            // Stats row
            Row(children: [
              Expanded(child: _AchCard(label: 'نقاط الولاء', value: points.toString(), icon: Icons.star_outline, color: AppColors.accent)),
              const SizedBox(width: 10),
              Expanded(child: _AchCard(label: 'المخالفات', value: strikes.toString(), icon: Icons.warning_amber_outlined, color: AppColors.error)),
              const SizedBox(width: 10),
              Expanded(child: _AchCard(label: 'مستوى الولاء', value: 'L$level', icon: Icons.military_tech_outlined, color: AppColors.info)),
            ]),
            const SizedBox(height: 16),
            // Rewards history
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('compliance_assets').doc(uid).collection('rewards').orderBy('timestamp', descending: true).limit(20).snapshots(),
              builder: (ctx2, snap2) {
                final rewards = snap2.data?.docs ?? [];
                if (rewards.isEmpty) return const _EmptyState(icon: Icons.emoji_events_outlined, title: 'لا توجد إنجازات أو عقوبات بعد', subtitle: '');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('سجل الإنجازات والعقوبات', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13), textDirection: TextDirection.rtl),
                    const SizedBox(height: 8),
                    ...rewards.map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      final pts = d['points'] as int? ?? 0;
                      final ts = (d['timestamp'] as Timestamp?)?.toDate();
                      final isReward = pts >= 0;
                      return _SimpleRow(
                        icon: isReward ? Icons.add_circle_outline : Icons.remove_circle_outline,
                        color: isReward ? AppColors.success : AppColors.error,
                        title: d['reason'] as String? ?? (isReward ? 'مكافأة' : 'خصم'),
                        subtitle: '${isReward ? "+" : ""}$pts نقطة${ts != null ? "  •  ${ts.day}/${ts.month}" : ""}',
                      );
                    }),
                  ],
                );
              },
            ),
          ]),
        );
      },
    );
  }
}

class _AchCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _AchCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
    child: Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(color: color, fontFamily: 'Tajawal', fontWeight: FontWeight.w800, fontSize: 20)),
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 10), textAlign: TextAlign.center),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 8: صور Snap Check-in الإلزامية
// ─────────────────────────────────────────────────────────────────────────────
class _SnapCheckinTab extends StatelessWidget {
  final String uid;
  const _SnapCheckinTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('compliance_assets')
          .doc(uid)
          .collection('snap_checkins')
          .orderBy('timestamp', descending: true)
          .limit(30)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const _EmptyState(icon: Icons.camera_alt_outlined, title: 'لا توجد صور تسجيل حضور بعد', subtitle: '');
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.85),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final ts = (d['timestamp'] as Timestamp?)?.toDate();
            final url = d['telegram_file_id'] as String? ?? d['url'] as String?;
            final type = d['type'] as String? ?? 'selfie';
            return Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withOpacity(0.2)),
              ),
              child: Column(children: [
                Expanded(
                  child: url != null && url.startsWith('http')
                      ? ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(11)), child: Image.network(url, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: AppColors.textMuted, size: 40)))
                      : const Center(child: Icon(Icons.image_outlined, color: AppColors.textMuted, size: 40)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Column(children: [
                    Text(type == 'selfie' ? 'Selfie' : 'محيط', style: const TextStyle(color: AppColors.accent, fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.w700)),
                    if (ts != null) Text('${ts.day}/${ts.month}  ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 10)),
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

// ─────────────────────────────────────────────────────────────────────────────
// Tab 9: التقارير الذاتية
// ─────────────────────────────────────────────────────────────────────────────
class _SelfReportsTab extends StatelessWidget {
  final String uid;
  const _SelfReportsTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('self_reports')
          .where('uid', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const _EmptyState(icon: Icons.summarize_outlined, title: 'لا توجد تقارير ذاتية مقدَّمة بعد', subtitle: '');
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final ts = (d['timestamp'] as Timestamp?)?.toDate();
            final status = d['status'] as String? ?? 'pending';
            final statusColor = status == 'reviewed' ? AppColors.success : AppColors.warning;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(status == 'reviewed' ? 'مُراجَع' : 'بانتظار المراجعة', style: TextStyle(color: statusColor, fontFamily: 'Tajawal', fontSize: 11)),
                  ),
                  Text(d['type'] as String? ?? 'تقرير', style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13), textDirection: TextDirection.rtl),
                ]),
                const SizedBox(height: 8),
                Text(d['content'] as String? ?? '', style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 12), textDirection: TextDirection.rtl, maxLines: 3, overflow: TextOverflow.ellipsis),
                if (ts != null) ...[const SizedBox(height: 6), Text('${ts.day}/${ts.month}/${ts.year}', style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 10))],
              ]),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 10: ملف المهارات
// ─────────────────────────────────────────────────────────────────────────────
class _SkillsTab extends StatelessWidget {
  final String uid;
  const _SkillsTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('form_submissions').doc(uid).snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final s4 = data['section4'] as Map<String, dynamic>? ?? {};
        final skills = s4['skill_ratings'] as Map<String, dynamic>? ?? {};
        final langs = (s4['languages'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final edu = s4['education'] as Map<String, dynamic>? ?? {};
        if (skills.isEmpty && langs.isEmpty) {
          return const _EmptyState(icon: Icons.radar_outlined, title: 'لم يتم تقديم ملف المهارات بعد\nيرجى إكمال استمارة القسم الرابع', subtitle: '');
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (edu.isNotEmpty) ...[
              _SectionHdr(title: 'التعليم', icon: Icons.school_outlined),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (edu['degree'] != null) _InfoRow(label: 'الدرجة العلمية', value: edu['degree'].toString()),
                  if (edu['major'] != null) _InfoRow(label: 'التخصص', value: edu['major'].toString()),
                  if (edu['gpa'] != null) _InfoRow(label: 'المعدل التراكمي', value: edu['gpa'].toString()),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            if (langs.isNotEmpty) ...[
              _SectionHdr(title: 'اللغات', icon: Icons.language_outlined),
              ...langs.map((l) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(l['proficiency']?.toString() ?? '', style: const TextStyle(color: AppColors.accent, fontFamily: 'Tajawal', fontSize: 11)),
                  ),
                  Text(l['language']?.toString() ?? '', style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              )),
              const SizedBox(height: 12),
            ],
            if (skills.isNotEmpty) ...[
              _SectionHdr(title: 'تقييم المهارات', icon: Icons.bar_chart_outlined),
              ...skills.entries.take(20).map((e) {
                final val = (e.value as num?)?.toDouble() ?? 0.0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(10)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('${val.toInt()}/10', style: TextStyle(color: _skillColor(val), fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 12)),
                      Text(e.key, style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 12), textDirection: TextDirection.rtl),
                    ]),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: val / 10, backgroundColor: AppColors.backgroundElevated, color: _skillColor(val), borderRadius: BorderRadius.circular(4), minHeight: 5),
                  ]),
                );
              }),
            ],
          ]),
        );
      },
    );
  }

  Color _skillColor(double v) {
    if (v >= 8) return AppColors.success;
    if (v >= 5) return AppColors.accent;
    return AppColors.error;
  }
}

class _SectionHdr extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHdr({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Text(title, style: const TextStyle(color: AppColors.accent, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 14), textDirection: TextDirection.rtl),
      const SizedBox(width: 8),
      Icon(icon, color: AppColors.accent, size: 18),
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(value, style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 13)),
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 11: حالة الجهاز
// ─────────────────────────────────────────────────────────────────────────────
class _DeviceStatusTab extends StatelessWidget {
  final String uid;
  const _DeviceStatusTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('compliance_assets').doc(uid).snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final device = data['device'] as Map<String, dynamic>? ?? {};
        final sensors = data['last_sensors'] as Map<String, dynamic>? ?? {};
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _SectionHdr(title: 'معلومات الجهاز', icon: Icons.phone_android_outlined),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                _InfoRow(label: 'الطراز', value: device['model']?.toString() ?? '—'),
                _InfoRow(label: 'Android', value: device['android_version']?.toString() ?? '—'),
                _InfoRow(label: 'حالة MDM', value: data['mdm_status']?.toString() ?? 'غير مفعّل'),
                _InfoRow(label: 'آخر تسجيل', value: () {
                  final ts = (data['last_seen'] as Timestamp?)?.toDate();
                  return ts != null ? '${ts.day}/${ts.month}/${ts.year}  ${ts.hour}:${ts.minute.toString().padLeft(2, "0")}' : '—';
                }()),
              ]),
            ),
            if (sensors.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionHdr(title: 'قراءات الاستشعار', icon: Icons.sensors_outlined),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  if (sensors['battery'] != null) _InfoRow(label: 'البطارية', value: '${sensors["battery"]}%'),
                  if (sensors['screen_on'] != null) _InfoRow(label: 'الشاشة', value: sensors['screen_on'] == true ? 'مفتوحة' : 'مغلقة'),
                  if (sensors['wifi_ssid'] != null) _InfoRow(label: 'Wi-Fi', value: sensors['wifi_ssid'].toString()),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            _SectionHdr(title: 'آخر الأوامر المنفّذة', icon: Icons.history_outlined),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('compliance_assets').doc(uid).collection('command_log').orderBy('timestamp', descending: true).limit(5).snapshots(),
              builder: (ctx2, snap2) {
                final cmds = snap2.data?.docs ?? [];
                if (cmds.isEmpty) return const _EmptyState(icon: Icons.history_outlined, title: 'لا توجد أوامر منفّذة', subtitle: '');
                return Column(
                  children: cmds.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final ts = (d['timestamp'] as Timestamp?)?.toDate();
                    return _SimpleRow(
                      icon: Icons.terminal_outlined,
                      color: AppColors.accent,
                      title: d['command'] as String? ?? 'أمر',
                      subtitle: ts != null ? '${ts.day}/${ts.month}  ${ts.hour}:${ts.minute.toString().padLeft(2, "0")}' : '',
                    );
                  }).toList(),
                );
              },
            ),
          ]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 12: التنبيهات والإشعارات
// ─────────────────────────────────────────────────────────────────────────────
class _AlertsTab extends StatelessWidget {
  final String uid;
  const _AlertsTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('compliance_assets')
          .doc(uid)
          .collection('notification_alerts')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const _EmptyState(icon: Icons.notifications_outlined, title: 'لا توجد تنبيهات', subtitle: '');
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final severity = d['severity'] as String? ?? 'info';
            final color = severity == 'high' ? AppColors.error : severity == 'medium' ? AppColors.warning : AppColors.info;
            final ts = (d['timestamp'] as Timestamp?)?.toDate();
            return _SimpleRow(
              icon: severity == 'high' ? Icons.error_outline : severity == 'medium' ? Icons.warning_amber_outlined : Icons.info_outline,
              color: color,
              title: d['message'] as String? ?? 'تنبيه',
              subtitle: ts != null ? '${ts.day}/${ts.month}/${ts.year}  ${ts.hour}:${ts.minute.toString().padLeft(2, "0")}' : '',
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 13: بوابة الطلبات والعرائض
// ─────────────────────────────────────────────────────────────────────────────
class _PetitionsTab extends StatelessWidget {
  final String uid;
  const _PetitionsTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('petitions')
          .where('uid', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }
        final docs = snap.data?.docs ?? [];
        return Column(children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('بوابة الطلبات', style: TextStyle(color: AppColors.accent, fontFamily: 'Tajawal', fontWeight: FontWeight.w800, fontSize: 15), textDirection: TextDirection.rtl),
              const SizedBox(height: 4),
              const Text('لتقديم طلب أو عريضة استخدم زر المساعدة الطارئة في الشاشة الرئيسية (الضغط الطويل 5 ثوانٍ)', style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12), textDirection: TextDirection.rtl),
            ]),
          ),
          if (docs.isEmpty)
            const Expanded(child: _EmptyState(icon: Icons.sos_outlined, title: 'لم تقدّم أي طلبات بعد', subtitle: ''))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final status = d['status'] as String? ?? 'pending';
                  final statusColor = status == 'approved' ? AppColors.success : status == 'rejected' ? AppColors.error : AppColors.warning;
                  final ts = (d['timestamp'] as Timestamp?)?.toDate();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor.withOpacity(0.3))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                          child: Text(status == 'approved' ? 'موافق عليه' : status == 'rejected' ? 'مرفوض' : 'قيد المراجعة', style: TextStyle(color: statusColor, fontFamily: 'Tajawal', fontSize: 11)),
                        ),
                        Text(d['type'] as String? ?? 'طلب مساعدة', style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13), textDirection: TextDirection.rtl),
                      ]),
                      if ((d['message'] as String?)?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 6),
                        Text(d['message'] as String, style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 12), textDirection: TextDirection.rtl, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                      if (ts != null) ...[
                        const SizedBox(height: 6),
                        Text('${ts.day}/${ts.month}/${ts.year}', style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 10)),
                      ],
                    ]),
                  );
                },
              ),
            ),
        ]);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// مساعدات مشتركة
// ─────────────────────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(color: color, fontFamily: 'Tajawal', fontWeight: FontWeight.w800, fontSize: 24)),
    Text(label, style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11), textAlign: TextAlign.center),
  ]);
}

class _SimpleRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  const _SimpleRow({required this.icon, required this.color, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(title, style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w600), textDirection: TextDirection.rtl, overflow: TextOverflow.ellipsis),
        if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11)),
      ])),
    ]),
  );
}
