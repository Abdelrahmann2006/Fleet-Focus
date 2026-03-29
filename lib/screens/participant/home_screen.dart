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
import '../../services/firestore_service.dart';

class ParticipantHomeScreen extends StatefulWidget {
  const ParticipantHomeScreen({super.key});

  @override
  State<ParticipantHomeScreen> createState() => _ParticipantHomeScreenState();
}

class _ParticipantHomeScreenState extends State<ParticipantHomeScreen> with SingleTickerProviderStateMixin {
  // ── Petition System (نظام الالتماس الطارئ) ───────────────────
  Timer? _petitionTimer;
  double _petitionProgress = 0.0;
  bool _isPetitioning      = false;
  bool _petitionSent       = false;
  static const _petitionDuration = Duration(seconds: 5);

  // ── Animation (عين المراقبة) ───────────────────────────────
  late AnimationController _eyeController;
  late Animation<double> _eyeAnimation;

  @override
  void initState() {
    super.initState();
    _startCommandServices();
    
    // إعداد أنيميشن حركة "النور" (Scanning Effect)
    _eyeController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _eyeAnimation = Tween<double>(begin: -25.0, end: 25.0).animate(
      CurvedAnimation(parent: _eyeController, curve: Curves.easeInOut),
    );
  }

  /// تشغيل المحركات والخدمات الخلفية فور فتح التطبيق
  Future<void> _startCommandServices() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;

    DeviceCommandListener.start(uid);
    await BackgroundServiceChannel.start(uid: uid);
    SyncService.instance.start(uid: uid);
  }

  @override
  void dispose() {
    _petitionTimer?.cancel();
    _eyeController.dispose();
    DeviceCommandListener.stop();
    super.dispose();
  }

  // ── Petition Logic (منطق الالتماس بضغط مطول 5 ثوانٍ) ──────────

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
      await FirebaseFirestore.instance.collection('petitions').doc(uid).set({
        'uid':       uid,
        'type':      'emergency_assistance',
        'status':    'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'message':   'طلب مساعدة طارئ من المشارك عبر نظام Panopticon',
      }, SetOptions(merge: false));

      if (mounted) {
        setState(() { _petitionSent = true; _isPetitioning = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال طلب المساعدة للقائد', style: TextStyle(fontFamily: 'Tajawal')),
          backgroundColor: AppColors.success, duration: Duration(seconds: 3)));
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) setState(() { _petitionSent = false; _petitionProgress = 0.0; });
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isPetitioning = false; _petitionProgress = 0.0; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final uid = auth.user?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: FirestoreService().watchProfile(uid!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }

          final data = snapshot.data ?? {};
          final status = data['applicationStatus'] ?? 'pending';
          
          final color = {
            'pending': AppColors.warning,
            'submitted': AppColors.accent,
            'approved': AppColors.success,
          }[status] ?? AppColors.warning;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(height: 20),
                  _buildHeader(auth),
                  const SizedBox(height: 20),
                  
                  // 1. شاشة المراقبة (العين والنور المتحرك)
                  _buildWatchingEyeSection(),
                  const SizedBox(height: 20),

                  // 2. بطاقة الحالة (Status Card)
                  _buildStatusCard(status, color),
                  const SizedBox(height: 12),
                  _buildLinkedCodeRow(data),
                  const SizedBox(height: 24),

                  // 3. المحتوى المتغير حسب الحالة (Status-Specific Content)
                  if (status == 'pending') _buildPendingCTA(),
                  if (status == 'submitted') _buildSubmittedCard(),
                  if (status == 'approved') _buildApprovedCard(),

                  const SizedBox(height: 20),
                  _buildInfoGrid(),
                  const SizedBox(height: 24),

                  // 4. البوابة السيادية (Sovereign Portal)
                  _buildSovereignPortalBtn(),
                  const SizedBox(height: 12),

                  // 5. نظام الاستغاثة (Petition System)
                  _PetitionButton(
                    progress: _petitionProgress, isPressing: _isPetitioning,
                    isSent: _petitionSent, onPressStart: _onPetitionPressStart,
                    onPressEnd: _onPetitionPressEnd,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── المكونات الرسومية الفرعية (UI Sub-widgets) ───────────────────

  Widget _buildHeader(AuthProvider auth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.logout, color: AppColors.textSecondary),
          onPressed: () async {
            DeviceCommandListener.stop();
            await auth.signOut();
            if (mounted) context.go('/');
          },
        ),
        Text('أهلاً، ${auth.user?.displayName?.split(' ').first ?? 'المتسابق'}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text, fontFamily: 'Tajawal')),
      ],
    );
  }

  Widget _buildWatchingEyeSection() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _eyeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_eyeAnimation.value, 0),
                child: Opacity(
                  opacity: 0.5,
                  child: Container(
                    width: 200, height: 100,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(colors: [AppColors.accent.withOpacity(0.5), Colors.transparent]),
                    ),
                  ),
                ),
              );
            },
          ),
          const Icon(Icons.remove_red_eye, size: 50, color: AppColors.accent),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String status, Color color) {
    final labels = {'pending': 'لم تكمل الاستمارة بعد', 'submitted': 'تمت الإرسال - بانتظار المراجعة', 'approved': 'تمت الموافقة على طلبك!'};
    final icons = {'pending': Icons.warning_amber_outlined, 'submitted': Icons.schedule_outlined, 'approved': Icons.check_circle_outlined};
    
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.13), Colors.transparent]),
        borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('حالة طلبك', style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontFamily: 'Tajawal')),
          Text(labels[status] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color, fontFamily: 'Tajawal')),
        ]),
        const SizedBox(width: 14),
        Container(width: 56, height: 56, decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(16)),
          child: Icon(icons[status] ?? Icons.help_outline, size: 28, color: color)),
      ]),
    );
  }

  Widget _buildLinkedCodeRow(Map<String, dynamic> data) {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Text('مرتبط بكود: ${data['linkedLeaderCode'] ?? "—"}', style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontFamily: 'Tajawal')),
      const SizedBox(width: 6),
      const Icon(Icons.link_outlined, size: 14, color: AppColors.textMuted),
    ]);
  }

  Widget _buildPendingCTA() {
    return GestureDetector(
      onTap: () => context.push('/participant/application'),
      child: Container(
        decoration: BoxDecoration(gradient: AppGradients.goldGradient, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))]),
        padding: const EdgeInsets.all(20),
        child: const Row(children: [
          Icon(Icons.chevron_left, color: AppColors.background, size: 20),
          Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('ابدأ ملء الاستمارة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.background, fontFamily: 'Tajawal')),
            Text('استمارة تسجيل المتسابق الشاملة', style: TextStyle(fontSize: 13, color: Color(0x88000000), fontFamily: 'Tajawal')),
          ]),
          SizedBox(width: 14),
          Icon(Icons.article_outlined, size: 26, color: AppColors.background),
        ]),
      ),
    );
  }

  Widget _buildSubmittedCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: const Column(children: [
        Icon(Icons.send_outlined, size: 40, color: AppColors.accent),
        SizedBox(height: 12),
        Text('تم إرسال استمارتك', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text, fontFamily: 'Tajawal')),
        SizedBox(height: 8),
        Text('سيتم مراجعتها من قِبل السيدة وستصلك النتيجة قريباً', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'Tajawal'), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildApprovedCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.08), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.accent.withOpacity(0.2))),
      child: Column(children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.emoji_events_outlined, size: 40, color: AppColors.accent)),
        const SizedBox(height: 12),
        const Text('مبروك! تمت الموافقة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.accent, fontFamily: 'Tajawal')),
        const SizedBox(height: 8),
        const Text('تم قبولك. انتظر التعليمات من سيدتك.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'Tajawal'), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildInfoGrid() {
    return const Row(children: [
      Expanded(child: _InfoCard(icon: Icons.schedule_outlined, title: 'أكمل في وقتك', desc: 'يمكنك الإكمال لاحقاً')),
      SizedBox(width: 12),
      Expanded(child: _InfoCard(icon: Icons.shield_outlined, title: 'بياناتك محمية', desc: 'معلوماتك مشفرة وآمنة')),
    ]);
  }

  Widget _buildSovereignPortalBtn() {
    return GestureDetector(
      onTap: () => context.push('/participant/portal'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.accent.withOpacity(0.3))),
        child: Row(children: [
          const Icon(Icons.chevron_left, color: AppColors.accent, size: 20),
          const Spacer(),
          const Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('البوابة السيادية', style: TextStyle(color: AppColors.accent, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 16)),
            Text('سجل الأوامر · الحسابات · الدستور الرقمي', style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11)),
          ]),
          const SizedBox(width: 12),
          Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.account_balance_outlined, size: 22, color: AppColors.accent)),
        ]),
      ),
    );
  }
}

// ── المكونات المستقلة (Internal Widgets) ───────────────────────────

class _PetitionButton extends StatelessWidget {
  final double progress; final bool isPressing; final bool isSent;
  final VoidCallback onPressStart; final VoidCallback onPressEnd;
  const _PetitionButton({required this.progress, required this.isPressing, required this.isSent, required this.onPressStart, required this.onPressEnd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: isSent ? AppColors.success.withOpacity(0.5) : isPressing ? AppColors.error.withOpacity(0.5) : AppColors.border, width: isPressing ? 2 : 1)),
      child: Column(children: [
        Row(children: [
          Icon(isSent ? Icons.check_circle_outline : Icons.sos_outlined, color: isSent ? AppColors.success : AppColors.error, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isSent ? 'تم إرسال الطلب' : 'طلب مساعدة طارئة', style: TextStyle(color: isSent ? AppColors.success : AppColors.text, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 15)),
            const Text('اضغط باستمرار لمدة 5 ثوانٍ لإرسال طلب طارئ للقائد', style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
          ])),
        ]),
        if (!isSent) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onLongPressStart: (_) => onPressStart(), onLongPressEnd: (_) => onPressEnd(), onLongPressCancel: onPressEnd,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(width: 72, height: 72, child: CircularProgressIndicator(value: isPressing ? progress : 0, strokeWidth: 4, backgroundColor: AppColors.border, valueColor: const AlwaysStoppedAnimation(AppColors.error))),
              Container(width: 60, height: 60, decoration: BoxDecoration(color: isPressing ? AppColors.error.withOpacity(0.15) : AppColors.backgroundCard, shape: BoxShape.circle, border: Border.all(color: isPressing ? AppColors.error : AppColors.border, width: 2)),
                child: Icon(Icons.sos_outlined, color: isPressing ? AppColors.error : AppColors.textMuted, size: 28)),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon; final String title, desc;
  const _InfoCard({required this.icon, required this.title, required this.desc});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Icon(icon, size: 22, color: AppColors.accent),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text, fontFamily: 'Tajawal'), textAlign: TextAlign.center),
        Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontFamily: 'Tajawal'), textAlign: TextAlign.center),
      ]),
    );
  }
}
