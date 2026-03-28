import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/device_command_listener.dart';
import '../../services/background_service_channel.dart';
import '../../services/sync_service.dart';
import 'participant_sovereign_portal_screen.dart';

class ParticipantHomeScreen extends StatefulWidget {
  const ParticipantHomeScreen({super.key});

  @override
  State<ParticipantHomeScreen> createState() => _ParticipantHomeScreenState();
}

class _ParticipantHomeScreenState extends State<ParticipantHomeScreen> {
  // ── Petition System ─────────────────────────────────────────
  Timer? _petitionTimer;
  double _petitionProgress = 0.0;
  bool _isPetitioning      = false;
  bool _petitionSent       = false;
  static const _petitionDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _startCommandServices();
  }

  /// يُشغّل طبقتَي الاستماع:
  ///  1. Flutter DeviceCommandListener  — يعمل عندما يكون التطبيق في المقدمة
  ///  2. Native CommandListenerService  — يعمل في الخلفية حتى بعد إغلاق التطبيق
  Future<void> _startCommandServices() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;

    // طبقة Flutter (حالة المقدمة)
    DeviceCommandListener.start(uid);

    // طبقة Kotlin Foreground Service (حالة الخلفية والإغلاق)
    await BackgroundServiceChannel.start(uid: uid);

    // طبقة المزامنة عند استعادة الاتصال (Blackbox Sync-on-Reconnect)
    SyncService.instance.start(uid: uid);
  }

  @override
  void dispose() {
    _petitionTimer?.cancel();
    DeviceCommandListener.stop();
    super.dispose();
  }

  // ── Petition — High-Friction 5-Second Long-Press ─────────────

  void _onPetitionPressStart() {
    if (_isPetitioning || _petitionSent) return;
    setState(() {
      _isPetitioning      = true;
      _petitionProgress   = 0.0;
    });

    const tickInterval = Duration(milliseconds: 50);
    final totalTicks   = _petitionDuration.inMilliseconds / tickInterval.inMilliseconds;
    int tick = 0;

    _petitionTimer = Timer.periodic(tickInterval, (t) {
      tick++;
      if (!mounted) { t.cancel(); return; }
      setState(() => _petitionProgress = tick / totalTicks);

      if (tick >= totalTicks) {
        t.cancel();
        _submitPetition();
      }
    });
  }

  void _onPetitionPressEnd() {
    if (!_isPetitioning) return;
    _petitionTimer?.cancel();
    if (!_petitionSent) {
      setState(() {
        _isPetitioning    = false;
        _petitionProgress = 0.0;
      });
    }
  }

  Future<void> _submitPetition() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('petitions')
          .doc(uid)
          .set({
        'uid':       uid,
        'type':      'emergency_assistance',
        'status':    'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'message':   'طلب مساعدة طارئ من المشارك',
      }, SetOptions(merge: false));

      if (mounted) {
        setState(() {
          _petitionSent   = true;
          _isPetitioning  = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال طلب المساعدة للقائد',
                style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
        // إعادة التهيئة بعد 10 ثوانٍ
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) {
            setState(() {
              _petitionSent     = false;
              _petitionProgress = 0.0;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPetitioning    = false;
          _petitionProgress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final status = user?.applicationStatus ?? 'pending';
    final statusColors = {
      'pending':   AppColors.warning,
      'submitted': AppColors.accent,
      'approved':  AppColors.success,
    };
    final statusLabels = {
      'pending':   'لم تكمل الاستمارة بعد',
      'submitted': 'تمت الإرسال - بانتظار المراجعة',
      'approved':  'تمت الموافقة على طلبك!',
    };
    final statusIcons = {
      'pending':   Icons.warning_amber_outlined,
      'submitted': Icons.schedule_outlined,
      'approved':  Icons.check_circle_outlined,
    };
    final color = statusColors[status] ?? AppColors.warning;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.logout, color: AppColors.textSecondary),
                    onPressed: () async {
                      DeviceCommandListener.stop();
                      await context.read<AuthProvider>().signOut();
                      if (context.mounted) context.go('/');
                    },
                  ),
                  Text(
                    'أهلاً، ${user?.displayName?.split(' ').first ?? 'المتسابق'}',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        fontFamily: 'Tajawal'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Status card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [color.withOpacity(0.13), Colors.transparent]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  const Spacer(),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('حالة طلبك',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            fontFamily: 'Tajawal')),
                    const SizedBox(height: 4),
                    Text(
                      statusLabels[status] ?? '',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: color,
                          fontFamily: 'Tajawal'),
                    ),
                  ]),
                  const SizedBox(width: 14),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(16)),
                    child: Icon(
                        statusIcons[status] ?? Icons.help_outline,
                        size: 28,
                        color: color),
                  ),
                ]),
              ),

              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(
                  'مرتبط بكود: ${user?.linkedLeaderCode ?? "—"}',
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      fontFamily: 'Tajawal'),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.link_outlined,
                    size: 14, color: AppColors.textMuted),
              ]),

              const SizedBox(height: 24),

              // CTA
              if (status == 'pending')
                GestureDetector(
                  onTap: () => context.push('/participant/application'),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppGradients.goldGradient,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.accent.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6))
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: const Row(children: [
                      Icon(Icons.chevron_left,
                          color: AppColors.background, size: 20),
                      Spacer(),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('ابدأ ملء الاستمارة',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.background,
                                    fontFamily: 'Tajawal')),
                            Text('استمارة تسجيل المتسابق الشاملة',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0x88000000),
                                    fontFamily: 'Tajawal')),
                          ]),
                      SizedBox(width: 14),
                      Icon(Icons.article_outlined,
                          size: 26, color: AppColors.background),
                    ]),
                  ),
                ),

              if (status == 'submitted')
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Column(children: [
                    Icon(Icons.send_outlined,
                        size: 40, color: AppColors.accent),
                    SizedBox(height: 12),
                    Text('تم إرسال استمارتك',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                            fontFamily: 'Tajawal')),
                    SizedBox(height: 8),
                    Text(
                        'سيتم مراجعتها من قِبل القائد وستصلك النتيجة قريباً',
                        style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontFamily: 'Tajawal'),
                        textAlign: TextAlign.center),
                  ]),
                ),

              if (status == 'approved')
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                  ),
                  child: Column(children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.emoji_events_outlined,
                          size: 40, color: AppColors.accent),
                    ),
                    const SizedBox(height: 12),
                    const Text('مبروك! تمت الموافقة',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                            fontFamily: 'Tajawal')),
                    const SizedBox(height: 8),
                    const Text(
                        'تم قبولك في البرنامج. انتظر التعليمات من قائدك.',
                        style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontFamily: 'Tajawal'),
                        textAlign: TextAlign.center),
                  ]),
                ),

              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                    child: _InfoCard(
                        icon: Icons.schedule_outlined,
                        title: 'أكمل في وقتك',
                        desc: 'يمكنك الإكمال لاحقاً')),
                const SizedBox(width: 12),
                Expanded(
                    child: _InfoCard(
                        icon: Icons.shield_outlined,
                        title: 'بياناتك محمية',
                        desc: 'معلوماتك مشفرة وآمنة')),
              ]),
              const SizedBox(height: 24),

              // ── البوابة السيادية — رابط للمشارك ─────────────────
              GestureDetector(
                onTap: () => context.push('/participant/portal'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.chevron_left,
                        color: AppColors.accent, size: 20),
                    const Spacer(),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('البوابة السيادية',
                              style: TextStyle(
                                  color: AppColors.accent,
                                  fontFamily: 'Tajawal',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16)),
                          const Text('سجل الأوامر · الحسابات · الدستور الرقمي',
                              style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontFamily: 'Tajawal',
                                  fontSize: 11)),
                        ]),
                    const SizedBox(width: 12),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.account_balance_outlined,
                          size: 22, color: AppColors.accent),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 12),

              // ── Petition System — طلب المساعدة الطارئة ───────────
              _PetitionButton(
                progress:    _petitionProgress,
                isPressing:  _isPetitioning,
                isSent:      _petitionSent,
                onPressStart: _onPetitionPressStart,
                onPressEnd:   _onPetitionPressEnd,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Petition Widget ──────────────────────────────────────────────────────────

class _PetitionButton extends StatelessWidget {
  final double progress;
  final bool isPressing;
  final bool isSent;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;

  const _PetitionButton({
    required this.progress,
    required this.isPressing,
    required this.isSent,
    required this.onPressStart,
    required this.onPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSent
              ? AppColors.success.withValues(alpha: 0.5)
              : isPressing
                  ? AppColors.error.withValues(alpha: 0.5)
                  : AppColors.border,
          width: isPressing ? 2 : 1,
        ),
      ),
      child: Column(children: [
        Row(children: [
          Icon(
            isSent
                ? Icons.check_circle_outline
                : Icons.sos_outlined,
            color: isSent ? AppColors.success : AppColors.error,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSent ? 'تم إرسال الطلب' : 'طلب مساعدة طارئة',
                  style: TextStyle(
                    color: isSent ? AppColors.success : AppColors.text,
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  isSent
                      ? 'سيتواصل معك القائد قريباً'
                      : 'اضغط باستمرار لمدة 5 ثوانٍ لإرسال طلب طارئ للقائد',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ]),
        if (!isSent) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onLongPressStart: (_) => onPressStart(),
            onLongPressEnd:   (_) => onPressEnd(),
            onLongPressCancel: onPressEnd,
            child: Stack(alignment: Alignment.center, children: [
              // حلقة التقدم
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: isPressing ? progress : 0,
                  strokeWidth: 4,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation(AppColors.error),
                ),
              ),
              // الزر المركزي
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isPressing
                      ? AppColors.error.withValues(alpha: 0.15)
                      : AppColors.backgroundCard,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isPressing ? AppColors.error : AppColors.border,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.sos_outlined,
                  color: isPressing ? AppColors.error : AppColors.textMuted,
                  size: 28,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Text(
            isPressing
                ? '${((1 - progress) * 5).ceil()} ثوانٍ متبقية...'
                : 'اضغط باستمرار للإرسال',
            style: TextStyle(
              color: isPressing ? AppColors.error : AppColors.textMuted,
              fontFamily: 'Tajawal',
              fontSize: 12,
              fontWeight: isPressing ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title, desc;
  const _InfoCard(
      {required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        Icon(icon, size: 22, color: AppColors.accent),
        const SizedBox(height: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
                fontFamily: 'Tajawal'),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(desc,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textMuted, fontFamily: 'Tajawal'),
            textAlign: TextAlign.center),
      ]),
    );
  }
}
