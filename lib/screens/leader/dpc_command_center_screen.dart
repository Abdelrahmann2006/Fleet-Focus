import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart' hide Query;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../models/asset_audit_model.dart';
import '../../providers/participant_stream_provider.dart';
import '../../services/gemini_service.dart';
import '../../services/hive_blackbox_service.dart';
import '../../services/intelligence_engine.dart';
import '../../services/mqtt_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/stage_light_background.dart';
import 'dpc_compliance_tab.dart';
import 'dpc_advanced_audit_tab.dart';
import 'dpc_behavioral_blackbox_tab.dart';
import 'dpc_disciplinary_tab.dart';
import 'dpc_economy_tab.dart';
import 'dpc_infrastructure_tab.dart';
import 'dpc_peer_surveillance_tab.dart';
import 'dpc_skills_radar_tab.dart';
import 'dpc_task_governance_tab.dart';
import 'dpc_zen_mode_tab.dart';
import 'geofence_screen.dart';
import 'media_vault_screen.dart';
import 'offboarding_screen.dart';
import 'remote_support_screen.dart';

/// DPC Command Center — مركز التحكم المؤسسي في الأسطول
/// DefaultTabController مع 20 تبويباً لإدارة الأجهزة الميدانية
class DpcCommandCenterScreen extends StatefulWidget {
  final String? targetUid;
  const DpcCommandCenterScreen({super.key, this.targetUid});

  @override
  State<DpcCommandCenterScreen> createState() => _DpcCommandCenterScreenState();
}

class _DpcCommandCenterScreenState extends State<DpcCommandCenterScreen>
    with TickerProviderStateMixin {
  // ── بيانات الجهاز المحدد ──────────────────────────────────────
  String _selectedUid = '';
  Map<String, dynamic> _deviceState = {};
  List<Map<String, dynamic>> _fleet = [];
  bool _loadingFleet = true;
  StreamSubscription? _deviceSub;

  // ── بوابة كلمة المرور ────────────────────────────────────────
  bool _passwordVerified = false;
  final _dpcPwCtrl = TextEditingController();
  bool _dpcPwError = false;
  bool _dpcPwChecking = false;

  // ── حالة الأوامر ─────────────────────────────────────────────
  bool _sendingCommand = false;
  String _commandFeedback = '';

  // ── حقول OOB ────────────────────────────────────────────────
  final _adminPhoneCtrl = TextEditingController();
  final _lostPinCtrl = TextEditingController();
  final _ntfyTopicCtrl = TextEditingController(text: 'panopticon-alerts');

  // ── تعريفات التبويبات الـ 37 ──────────────────────────────────
  static const _tabs = [
    _TabDef(icon: Icons.verified_user,       label: 'الامتثال'),
    _TabDef(icon: Icons.location_off,         label: 'Lost Mode'),
    _TabDef(icon: Icons.campaign,             label: 'Panic Alarm'),
    _TabDef(icon: Icons.phone_locked,         label: 'OOB Protocol'),
    _TabDef(icon: Icons.lock,                 label: 'قفل الشاشة'),
    _TabDef(icon: Icons.apps_outlined,        label: 'التطبيقات'),
    _TabDef(icon: Icons.security,             label: 'القيود'),
    // ── Phase 5 Tabs ───────────────────────────────────────────
    _TabDef(icon: Icons.face_retouching_natural, label: 'التحقق'),
    _TabDef(icon: Icons.videocam_outlined,    label: 'التسجيل'),
    _TabDef(icon: Icons.shield_outlined,      label: 'DLP'),
    _TabDef(icon: Icons.video_call_outlined,  label: 'الدعم'),
    _TabDef(icon: Icons.photo_library_outlined, label: 'الخزنة'),
    _TabDef(icon: Icons.cloud_sync_outlined,  label: 'المزامنة'),
    // ── Phase 7 Tabs ───────────────────────────────────────────
    _TabDef(icon: Icons.radar,                label: 'الرادار'),
    _TabDef(icon: Icons.open_in_new,          label: 'إلزامي'),
    _TabDef(icon: Icons.manage_history,       label: 'دورة الحياة'),
    // ── Phase 8 Tabs ───────────────────────────────────────────
    _TabDef(icon: Icons.wifi_tethering,       label: 'MQTT'),
    _TabDef(icon: Icons.build_circle_outlined, label: 'الاسترداد'),
    // ── Phase 9 Tabs ───────────────────────────────────────────
    _TabDef(icon: Icons.sensors,              label: 'الحواس'),
    _TabDef(icon: Icons.psychology_outlined,  label: 'الذكاء'),
    // ── Phase 11 Tabs ───────────────────────────────────────────
    _TabDef(icon: Icons.gavel_rounded,        label: 'البروتوكول'),
    _TabDef(icon: Icons.vpn_lock_outlined,    label: 'تحصين الشبكة'),
    _TabDef(icon: Icons.keyboard_outlined,    label: 'Keylog'),
    _TabDef(icon: Icons.fingerprint,          label: 'الخزنة والقنبلة'),
    // ── Phase 6 Tabs (Modules A, B, C) ────────────────────────────────
    _TabDef(icon: Icons.inventory_2_outlined, label: 'الجرد المتقدم'),
    _TabDef(icon: Icons.task_alt_outlined,    label: 'إدارة المهام'),
    _TabDef(icon: Icons.radar_outlined,       label: 'مهارات العناصر'),
    _TabDef(icon: Icons.policy_outlined,      label: 'سجل السلوك'),
    _TabDef(icon: Icons.gavel_outlined,       label: 'الترسانة التأديبية'),
    _TabDef(icon: Icons.account_balance_wallet_outlined, label: 'اقتصاد النقاط'),
    _TabDef(icon: Icons.groups_outlined,      label: 'مراقبة الأقران'),
    _TabDef(icon: Icons.spa_outlined,         label: 'وضع الزن'),
    _TabDef(icon: Icons.cable_outlined,       label: 'البنية الصامدة'),
    // ── Archive Tabs (Phase Final) ─────────────────────────────────
    _TabDef(icon: Icons.sms_outlined,         label: 'أرشيف الرسائل'),
    _TabDef(icon: Icons.archive_outlined,     label: 'أرشيف الجلسات'),
    _TabDef(icon: Icons.all_inbox_outlined,   label: 'الأرشيف الشامل'),
    // ── Tab 37: Gemini AI Integration ─────────────────────────────
    _TabDef(icon: Icons.auto_awesome_outlined, label: 'Gemini AI'),
  ];

  String get _selectedName {
    if (_selectedUid.isEmpty) return '';
    final dev = _fleet.firstWhere(
        (f) => f['uid'] == _selectedUid, orElse: () => {});
    return dev['fullName'] as String? ??
        (_selectedUid.length >= 6 ? _selectedUid.substring(0, 6) : _selectedUid);
  }

  // مُبسَّط للتبويبات الجديدة: يُرسل أمراً دون حاجة لرسالة تأكيد أو نجاح
  Future<void> _sendSimpleCommand(String cmd,
      {Map<String, dynamic> payload = const {}}) =>
      _sendCommand(cmd, payload: payload);

  @override
  void initState() {
    super.initState();
    _loadFleet();
    // بوابة كلمة المرور — تُفحص بعد اكتمال البناء
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPasswordGate());
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    _adminPhoneCtrl.dispose();
    _lostPinCtrl.dispose();
    _ntfyTopicCtrl.dispose();
    _dpcPwCtrl.dispose();
    super.dispose();
  }

  // ── بوابة كلمة المرور DPC ──────────────────────────────────────

  Future<void> _checkPasswordGate() async {
    if (!mounted) return;
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) { setState(() => _passwordVerified = true); return; }
    final hasPassword =
        await context.read<AuthProvider>().hasDpcPassword(uid);
    if (!hasPassword) {
      setState(() => _passwordVerified = true);
    }
    // إذا كانت هناك كلمة مرور، تبقى _passwordVerified = false
    // وستُعرض بوابة الإدخال في build()
  }

  Future<void> _verifyDpcPassword() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;
    setState(() { _dpcPwChecking = true; _dpcPwError = false; });
    final ok = await context
        .read<AuthProvider>()
        .verifyAppPassword(uid, _dpcPwCtrl.text.trim());
    if (mounted) {
      setState(() {
        _dpcPwChecking = false;
        if (ok) {
          _passwordVerified = true;
          _dpcPwCtrl.clear();
        } else {
          _dpcPwError = true;
        }
      });
    }
  }

  Widget _buildPasswordGate() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const StageLightBackground(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent.withValues(alpha: 0.08),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        size: 48,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'DPC Command Center',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'أدخل كلمة مرور غرفة التحكم',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _dpcPwCtrl,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Tajawal',
                        fontSize: 18,
                        letterSpacing: 4,
                      ),
                      decoration: InputDecoration(
                        hintText: '••••••',
                        hintStyle: TextStyle(
                          color: AppColors.textMuted,
                          letterSpacing: 4,
                        ),
                        filled: true,
                        fillColor: AppColors.backgroundCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: _dpcPwError
                                ? AppColors.error
                                : AppColors.border,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: _dpcPwError
                                ? AppColors.error
                                : AppColors.border,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: _dpcPwError
                                ? AppColors.error
                                : AppColors.accent,
                            width: 1.5,
                          ),
                        ),
                        errorText: _dpcPwError ? 'كلمة المرور غير صحيحة' : null,
                        errorStyle: const TextStyle(
                          fontFamily: 'Tajawal',
                          color: AppColors.error,
                        ),
                      ),
                      onSubmitted: (_) => _verifyDpcPassword(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _dpcPwChecking ? null : _verifyDpcPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _dpcPwChecking
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'فتح غرفة التحكم',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text(
                        'رجوع',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── تحميل الأسطول ───────────────────────────────────────────

  Future<void> _loadFleet() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final code = userDoc.data()?['leaderCode'] ?? '';
      if (code.isEmpty) return;

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('linkedLeaderCode', isEqualTo: code)
          .where('role', isEqualTo: 'participant')
          .get();

      final fleet =
          snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList();

      setState(() {
        _fleet = fleet;
        _loadingFleet = false;
        if (widget.targetUid != null &&
            fleet.any((f) => f['uid'] == widget.targetUid)) {
          _selectedUid = widget.targetUid!;
        } else if (fleet.isNotEmpty) {
          _selectedUid = fleet.first['uid'] as String;
        }
      });

      if (_selectedUid.isNotEmpty) {
        _subscribeToDevice(_selectedUid);
        IntelligenceEngine.instance.start(_selectedUid);
      }
    } catch (e) {
      debugPrint('DPC loadFleet: $e');
      setState(() => _loadingFleet = false);
    }
  }

  void _subscribeToDevice(String uid) {
    _deviceSub?.cancel();
    _deviceSub = FirebaseFirestore.instance
        .collection('device_states')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      if (snap.exists && mounted) {
        setState(() => _deviceState = snap.data() ?? {});
      }
    });
  }

  void _onDeviceSelected(String uid) {
    setState(() {
      _selectedUid = uid;
      _deviceState = {};
    });
    _subscribeToDevice(uid);
    // بدء محرك الذكاء للعنصر المحدَّد
    IntelligenceEngine.instance.start(uid);
  }

  // ── إرسال أمر ───────────────────────────────────────────────

  Future<void> _sendCommand(
    String command, {
    Map<String, dynamic> payload = const {},
    String? successMsg,
    String? confirmMsg,
  }) async {
    if (_selectedUid.isEmpty) {
      _showFeedback('اختر جهازاً أولاً');
      return;
    }

    if (confirmMsg != null) {
      final ok = await _confirm('تأكيد التنفيذ', confirmMsg);
      if (!ok) return;
    }

    setState(() {
      _sendingCommand = true;
      _commandFeedback = '';
    });

    try {
      await FirebaseFirestore.instance
          .collection('device_commands')
          .doc(_selectedUid)
          .set({
        'command': command,
        'payload': payload,
        'acknowledged': false,
        'sentAt': FieldValue.serverTimestamp(),
      });
      _showFeedback(successMsg ?? '✓ الأمر أُرسل بنجاح');
    } catch (e) {
      _showFeedback('خطأ في الإرسال: $e');
    } finally {
      setState(() => _sendingCommand = false);
    }
  }

  void _showFeedback(String msg) {
    setState(() => _commandFeedback = msg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Tajawal')),
        backgroundColor: AppColors.backgroundCard,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _confirm(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.backgroundCard,
            title: Text(title,
                style: const TextStyle(
                    color: AppColors.text, fontFamily: 'Tajawal')),
            content: Text(body,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontFamily: 'Tajawal')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء',
                      style: TextStyle(color: AppColors.textMuted))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تأكيد',
                    style: TextStyle(color: Colors.black, fontFamily: 'Tajawal')),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── Phase 11: مساعدات بروتوكول التهيئة ──────────────────────

  /// Step 3: إطلاق جرد الأصول
  Future<void> _triggerAuditMode() async {
    if (_selectedUid.isEmpty) { _showFeedback('اختر عنصراً أولاً'); return; }
    final ok = await _confirm(
      'تفعيل جرد الأصول',
      'سيُرسَل أمر تفعيل بروتوكول الجرد الشامل (13 فئة) للعنصر. يجب إكماله خلال 60 دقيقة.',
    );
    if (!ok) return;
    setState(() => _sendingCommand = true);
    try {
      await context.read<ParticipantStreamProvider>().triggerAuditMode(_selectedUid);
      _showFeedback('✓ تم إطلاق بروتوكول الجرد — العداد يعمل');
    } catch (e) {
      _showFeedback('خطأ: $e');
    } finally {
      setState(() => _sendingCommand = false);
    }
  }

  /// Step 4a: قفل المقابلة يدوياً
  Future<void> _triggerInterviewLock() async {
    if (_selectedUid.isEmpty) { _showFeedback('اختر عنصراً أولاً'); return; }
    final ok = await _confirm(
      'قفل المقابلة',
      'سيُقفَل جهاز العنصر فوراً بطبقة System Alert Window. لا يمكنه الخروج منها.',
    );
    if (!ok) return;
    setState(() => _sendingCommand = true);
    try {
      await context.read<ParticipantStreamProvider>().triggerInterviewLock(_selectedUid);
      _showFeedback('🔒 جهاز العنصر مقفول — وقت المقابلة');
    } catch (e) {
      _showFeedback('خطأ: $e');
    } finally {
      setState(() => _sendingCommand = false);
    }
  }

  /// Step 4a: رفع قفل المقابلة بعد الانتهاء
  Future<void> _unlockInterview() async {
    if (_selectedUid.isEmpty) { _showFeedback('اختر عنصراً أولاً'); return; }
    final ok = await _confirm('رفع قفل المقابلة', 'هل انتهت المقابلة؟ سيُرسَل أمر فتح الجهاز.');
    if (!ok) return;
    await _sendCommand('unlock_interview', successMsg: '✓ تم رفع قفل المقابلة');
  }

  /// Step 4b: إرسال الدستور النهائي
  Future<void> _showPushConstitutionDialog() async {
    if (_selectedUid.isEmpty) { _showFeedback('اختر عنصراً أولاً'); return; }

    String decision = 'مقبول';
    final termsCtrl    = TextEditingController();
    final deadlineCtrl = TextEditingController(
      text: DateTime.now().add(const Duration(days: 3)).toIso8601String().substring(0, 10),
    );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          backgroundColor: AppColors.backgroundCard,
          title: const Text('الدستور النهائي',
              textAlign: TextAlign.right,
              style: TextStyle(color: AppColors.gold, fontFamily: 'Tajawal', fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // القرار
                const Text('القرار النهائي:', textAlign: TextAlign.right,
                    style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 12)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: decision,
                  dropdownColor: AppColors.backgroundElevated,
                  style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal'),
                  decoration: _inputDec('القرار'),
                  items: ['مقبول', 'على قيد الاختبار', 'مرفوض']
                      .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontFamily: 'Tajawal'))))
                      .toList(),
                  onChanged: (v) => ss(() => decision = v ?? decision),
                ),
                const SizedBox(height: 10),
                // البنود
                const Text('البنود والاشتراطات (كل سطر = بند):', textAlign: TextAlign.right,
                    style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 12)),
                const SizedBox(height: 4),
                TextField(
                  controller: termsCtrl,
                  maxLines: 4,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 13),
                  decoration: _inputDec('أدخل البنود — سطر واحد لكل بند'),
                ),
                const SizedBox(height: 10),
                // الموعد النهائي للتوقيع
                const Text('الموعد النهائي للتوقيع (YYYY-MM-DD):', textAlign: TextAlign.right,
                    style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 12)),
                const SizedBox(height: 4),
                TextField(
                  controller: deadlineCtrl,
                  style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 13),
                  decoration: _inputDec('مثال: 2026-04-01'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              onPressed: () async {
                final terms = termsCtrl.text.split('\n').where((t) => t.trim().isNotEmpty).toList();
                if (terms.isEmpty) { return; }
                Navigator.pop(ctx);
                setState(() => _sendingCommand = true);
                try {
                  await context.read<ParticipantStreamProvider>().pushFinalConstitution(
                    uid:                _selectedUid,
                    leaderDecision:     decision,
                    terms:              terms,
                    signingDeadlineIso: '${deadlineCtrl.text.trim()}T23:59:59.000',
                  );
                  _showFeedback('✓ الدستور النهائي أُرسل للعنصر');
                } catch (e) {
                  _showFeedback('خطأ: $e');
                } finally {
                  setState(() => _sendingCommand = false);
                }
              },
              child: const Text('إرسال الدستور',
                  style: TextStyle(color: Colors.black, fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  static InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    hintTextDirection: TextDirection.rtl,
    hintStyle: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12),
    filled: true,
    fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.6))),
  );

  // ── البناء ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ── بوابة كلمة المرور — تُعرض حتى اكتمال التحقق ──────────
    if (!_passwordVerified) return _buildPasswordGate();

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            const StageLightBackground(),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildDeviceSelector(),
                  if (_sendingCommand)
                    const LinearProgressIndicator(
                      color: AppColors.accent,
                      backgroundColor: Colors.transparent,
                    ),
                  _buildTabBar(),
                  Expanded(child: _buildTabViews()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.text, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DPC Command Center',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        fontFamily: 'Tajawal')),
                Text('${_fleet.length} جهاز في الأسطول',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontFamily: 'Tajawal')),
              ],
            ),
          ),
          // مؤشر حالة الاتصال
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _deviceState.isNotEmpty ? AppColors.success : AppColors.textMuted,
              boxShadow: _deviceState.isNotEmpty
                  ? [BoxShadow(color: AppColors.success.withOpacity(0.5), blurRadius: 6)]
                  : null,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildDeviceSelector() {
    if (_loadingFleet) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: LinearProgressIndicator(color: AppColors.accent),
      );
    }
    if (_fleet.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('لا توجد أجهزة مسجّلة',
            style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal')),
      );
    }

    return Container(
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _fleet.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final dev = _fleet[i];
          final uid = dev['uid'] as String;
          final name = dev['fullName'] as String? ?? uid.substring(0, 6);
          final selected = uid == _selectedUid;
          return GestureDetector(
            onTap: () => _onDeviceSelected(uid),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.accent
                    : AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: selected ? AppColors.accent : AppColors.border),
              ),
              child: Text(name,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.black : AppColors.textSecondary,
                      fontFamily: 'Tajawal')),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.backgroundCard.withOpacity(0.6),
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: AppColors.accent,
        labelColor: AppColors.accent,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: const TextStyle(fontSize: 11, fontFamily: 'Tajawal'),
        tabs: _tabs
            .map((t) => Tab(
                  icon: Icon(t.icon, size: 16),
                  text: t.label,
                  iconMargin: const EdgeInsets.only(bottom: 2),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildTabViews() {
    return TabBarView(
      children: [
        // ── Tab 1: Compliance & Security ──────────────────────
        DpcComplianceTab(
          participantUid: _selectedUid,
          deviceState: _deviceState,
        ),

        // ── Tab 2: Lost Mode ──────────────────────────────────
        _LostModeTab(
          isActive: _deviceState['lostModeActive'] == true,
          pinController: _lostPinCtrl,
          onActivate: (pin) => _sendCommand(
            'activate_lost_mode',
            payload: {'pin': pin},
            successMsg: '✓ Lost Mode مُفعَّل',
            confirmMsg: 'سيتم عرض شاشة القفل الآمنة على الجهاز فوراً.',
          ),
          onDeactivate: () => _sendCommand(
            'deactivate_lost_mode',
            successMsg: '✓ Lost Mode مُلغى',
            confirmMsg: 'هل تريد رفع التأمين عن الجهاز؟',
          ),
        ),

        // ── Tab 3: Panic Alarm ────────────────────────────────
        _PanicAlarmTab(
          ntfyController: _ntfyTopicCtrl,
          onTrigger: () => _sendCommand(
            'trigger_panic_alarm',
            payload: {'ntfy_topic': _ntfyTopicCtrl.text.trim()},
            successMsg: '🚨 Panic Alarm مُشغَّل!',
            confirmMsg:
                'سيُشغَّل إنذار صوتي بأعلى مستوى على الجهاز. هل تريد المتابعة؟',
          ),
          onStop: () => _sendCommand(
            'stop_panic_alarm',
            successMsg: '✓ Panic Alarm مُوقَف',
          ),
        ),

        // ── Tab 4: OOB Protocol ───────────────────────────────
        _OobProtocolTab(
          phoneController: _adminPhoneCtrl,
          onSavePhone: () => _sendCommand(
            'set_admin_phone',
            payload: {'phone': _adminPhoneCtrl.text.trim()},
            successMsg: '✓ رقم المشرف حُفظ على الجهاز',
          ),
          deviceState: _deviceState,
        ),

        // ── Tab 5: قفل الشاشة ─────────────────────────────────
        _LockScreenTab(
          onLock: () => _sendCommand(
            'lock_screen',
            successMsg: '✓ الشاشة مُقفلة',
            confirmMsg: 'سيتم قفل الشاشة فوراً.',
          ),
          onEnableKiosk: () => _sendCommand(
            'enable_kiosk',
            successMsg: '✓ Kiosk Mode مُفعَّل',
            confirmMsg: 'سيتم تفعيل وضع Kiosk على الجهاز.',
          ),
          onDisableKiosk: () => _sendCommand(
            'disable_kiosk',
            successMsg: '✓ Kiosk Mode مُلغى',
            confirmMsg: 'سيتم إلغاء وضع Kiosk.',
          ),
        ),

        // ── Tab 6: إدارة التطبيقات ────────────────────────────
        _AppsManagementTab(
          onSendAppList: (packages) => _sendCommand(
            'update_blocked_apps',
            payload: {'packages': packages},
            successMsg: '✓ قائمة الحجب محدَّثة',
          ),
        ),

        // ── Tab 7: القيود المؤسسية ────────────────────────────
        _RestrictionsTab(
          deviceState: _deviceState,
          onApplyAll: () => _sendCommand(
            'apply_enterprise_restrictions',
            successMsg: '✓ جميع القيود مُطبَّقة',
            confirmMsg: 'سيتم تطبيق جميع قيود Device Admin المؤسسية.',
          ),
          onClearAll: () => _sendCommand(
            'clear_enterprise_restrictions',
            successMsg: '✓ جميع القيود مُزالة',
            confirmMsg: 'سيتم رفع جميع القيود عن الجهاز.',
          ),
          onBlockAirplane: (block) => _sendCommand(
            'set_airplane_mode_blocked',
            payload: {'blocked': block},
            successMsg: block
                ? '✓ وضع الطيران محجوب'
                : '✓ وضع الطيران متاح',
          ),
        ),

        // ── Tab 8: التحقق الميداني (Snap Check-in) ──────────────
        _SnapCheckinTab(
          uid: _selectedUid,
          onSelfie: () => _sendCommand(
            'snap_checkin_selfie',
            successMsg: '✓ أمر التقاط Selfie أُرسل',
          ),
          onSurroundings: () => _sendCommand(
            'snap_checkin_surroundings',
            successMsg: '✓ أمر التقاط المحيط أُرسل',
          ),
          onSla: () => _sendCommand(
            'snap_checkin_sla',
            successMsg: '⏱ SLA Check-in مُفعَّل — مهلة 30 ثانية',
            confirmMsg: 'سيُطلب من العنصر إرسال تأكيد حضور خلال 30 ثانية أو يُسجَّل غياب.',
          ),
        ),

        // ── Tab 9: تسجيل الجلسات (Audit Recording) ───────────
        _AuditRecordingTab(
          deviceState: _deviceState,
          onStop: () => _sendCommand(
            'stop_screen_recording',
            successMsg: '✓ أمر إيقاف التسجيل أُرسل',
            confirmMsg: 'سيتم إيقاف التسجيل وحفظ الملف.',
          ),
        ),

        // ── Tab 10: مراقبة DLP ────────────────────────────────
        _DlpMonitorTab(
          uid: _selectedUid,
          onEnableScan:  () => _sendCommand('enable_notification_scan',
              successMsg: '✓ مسح DLP مُفعَّل'),
          onDisableScan: () => _sendCommand('disable_notification_scan',
              successMsg: '✓ مسح DLP مُعطَّل'),
          onClearAlerts: () async {
            if (_selectedUid.isEmpty) return;
            await FirebaseFirestore.instance
                .collection('dlp_alerts')
                .where('uid', isEqualTo: _selectedUid)
                .get()
                .then((s) => Future.wait(s.docs.map((d) => d.reference.delete())));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✓ تنبيهات DLP مُسحت')));
            }
          },
        ),

        // ── Tab 11: الدعم الفني عن بُعد ──────────────────────
        _RemoteSupportLaunchTab(
          uid: _selectedUid,
          onLaunch: () {
            if (_selectedUid.isEmpty) return;
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => RemoteSupportScreen(uid: _selectedUid),
            ));
          },
        ),

        // ── Tab 12: خزنة الوسائط ──────────────────────────────
        _MediaVaultLaunchTab(
          uid: _selectedUid,
          onLaunch: () {
            if (_selectedUid.isEmpty) return;
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MediaVaultScreen(uid: _selectedUid),
            ));
          },
        ),

        // ── Tab 13: الصندوق الأسود والمزامنة ─────────────────
        _BlackboxSyncTab(uid: _selectedUid),

        // ── Tab 14: الرادار الحي ──────────────────────────────
        _LiveRadarTab(
          uid: _selectedUid,
          onEnable: () => _sendCommand('enable_radar_mode',
              successMsg: '✓ الرادار الحي مُفعَّل — GPS 1 ثانية',
              confirmMsg: 'سيُفعَّل تحديث GPS كل ثانية عبر RTDB. يستهلك بطارية أعلى.'),
          onDisable: () => _sendCommand('disable_radar_mode',
              successMsg: '✓ الرادار الحي مُعطَّل',
              confirmMsg: 'هل تريد إيقاف الرادار والعودة للفترة الاعتيادية (30 ثانية)؟'),
        ),

        // ── Tab 15: التطبيق الإلزامي ──────────────────────────
        _MandatoryAppTab(
          uid: _selectedUid,
          onLaunch: (pkg, kiosk) => _sendCommand(
            'launch_mandatory_app',
            payload: {'packageName': pkg, 'kioskMode': kiosk},
            successMsg: '✓ تم إطلاق التطبيق الإلزامي',
            confirmMsg: 'سيتم فتح "$pkg" على جهاز المشارك مع قفل جزئي للمشتتات.',
          ),
          onStop: () => _sendCommand('stop_mandatory_app',
              successMsg: '✓ وضع التطبيق الإلزامي أُنهي',
              confirmMsg: 'هل تريد إنهاء جلسة التطبيق الإلزامي؟'),
        ),

        // ── Tab 16: دورة حياة الجهاز ─────────────────────────
        _DeviceLifecycleTab(
          uid: _selectedUid,
          onOpenGeofence: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GeofenceScreen(uid: _selectedUid),
            ),
          ),
          onOpenOffboarding: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OffboardingScreen(uid: _selectedUid),
            ),
          ),
        ),

        // ── Tab 17: MQTT Live Telemetry Monitor ───────────────
        _MqttMonitorTab(uid: _selectedUid),

        // ── Tab 18: Recovery & Advanced Tools ────────────────
        _RecoveryToolsTab(
          uid: _selectedUid,
          onForceReport: () => _sendCommand('report_device_state'),
          onSetOob: (enabled) => _sendCommand(
            'set_oob_enabled',
            payload: {'enabled': enabled},
          ),
        ),

        // ── Tab 19: Phase 9 Sensors (Ambient Audio + Notifications + SMS) ──
        _Phase9SensorsTab(
          uid: _selectedUid,
          onStartAudio:  () => _sendCommand('start_ambient_audio'),
          onStopAudio:   () => _sendCommand('stop_ambient_audio'),
          onEnableNotifScan: () => _sendCommand('enable_notification_scan'),
          onDisableNotifScan: () => _sendCommand('disable_notification_scan'),
        ),

        // ── Tab 20: AI Behavioral Brain ──────────────────────────────────────
        _Phase10AIBrainTab(uid: _selectedUid),

        // ── Tab 21: Phase 11 Protocol (4-Step Onboarding Pipeline) ──────────
        _Phase11ProtocolTab(
          uid:            _selectedUid,
          deviceState:    _deviceState,
          onTriggerAudit: _triggerAuditMode,
          onLockInterview: _triggerInterviewLock,
          onUnlockInterview: _unlockInterview,
          onPushConstitution: _showPushConstitutionDialog,
          onRejectAsset: () => _sendCommand(
            'force_reject_asset',
            successMsg: '✓ العنصر مرفوض — تم إشعاره',
            confirmMsg: 'هل تريد رفض العنصر نهائياً وإشعاره؟',
          ),
        ),

        // ── Tab 22: Network Enforcement (VPN + URL + Mutiny + Red Overlay) ──
        _NetworkEnforcementTab(
          deviceState: _deviceState,
          onActivateVpn: () => _sendCommand(
            'start_network_isolation',
            successMsg: '✓ VPN Blackhole مُفعَّل — الشبكة معزولة',
            confirmMsg: 'سيتم عزل جميع اتصالات الجهاز عبر نفق VPN يحجب كل حركة مرور.',
          ),
          onDeactivateVpn: () => _sendCommand(
            'stop_network_isolation',
            successMsg: '✓ VPN Blackhole مُلغى',
            confirmMsg: 'هل تريد إعادة الوصول الكامل للإنترنت؟',
          ),
          onEnableUrlFilter: (urls) => _sendCommand(
            'update_blocked_domains',
            payload: {'domains': urls},
            successMsg: '✓ فلتر النطاقات مُفعَّل — ${urls.length} نطاق محجوب',
          ),
          onDisableUrlFilter: () => _sendCommand(
            'update_blocked_domains',
            payload: const {'domains': <String>[]},
            successMsg: '✓ فلتر النطاقات مُلغى',
          ),
          onMutinyLockout: () => _sendCommand(
            'set_mutiny_lockout',
            payload: const {'enabled': true},
            successMsg: '⚠ قفل التمرد مُفعَّل — الجهاز محجوب',
            confirmMsg: 'سيُقفَل الجهاز فوراً بسبب محاولة التمرد على النظام.',
          ),
          onForceBriefing: () => _sendCommand(
            'start_mandatory_briefing',
            payload: const {
              'deepLink': 'panopticon://participant/briefing',
              'sessionName': 'إحاطة إلزامية — مطلوب التأكيد',
            },
            successMsg: '✓ إحاطة إلزامية مُرسَلة',
            confirmMsg: 'سيظهر للعنصر إشعار إحاطة لا يمكن رفضه حتى يؤكد استلامه.',
          ),
          onActivateRedOverlay: () => _sendCommand(
            'show_red_overlay',
            payload: const {'message': '🔴 مراقبة نشطة — السيدة ترى كل شيء'},
            successMsg: '🔴 الطبقة الحمراء العقابية مُفعَّلة',
            confirmMsg: 'سيظهر تظليل أحمر عقابي فوق جميع واجهات الجهاز.',
          ),
          onDeactivateRedOverlay: () => _sendCommand(
            'hide_red_overlay',
            successMsg: '✓ الطبقة الحمراء مُلغاة',
          ),
        ),

        // ── Tab 23: Live Keylog Feed ──────────────────────────────────────────
        _KeylogFeedTab(uid: _selectedUid),

        // ── Tab 24: Vault & Detonator (Biometric + Audit Review) ─────────────
        _VaultDetonatorTab(
          uid:         _selectedUid,
          deviceState: _deviceState,
          onVerifyBiometric: () => _sendCommand(
            'request_biometric_verification',
            successMsg: '✓ طلب التحقق البيومتري أُرسل',
            confirmMsg: 'سيُطلب من العنصر إجراء بصمة لتأكيد هويته الآن.',
          ),
          onClearAuditData: () => _sendCommand(
            'clear_audit_submission',
            successMsg: '✓ بيانات الجرد مُسحت من جانبنا',
            confirmMsg: 'هل تريد مسح سجل الجرد المُرسَل من العنصر؟',
          ),
        ),

        // ── Tab 25: الجرد المتقدم (Phase 6 Module A) ─────────────────────────
        DpcAdvancedAuditTab(
          uid: _selectedUid,
          sendCommand: _sendSimpleCommand,
        ),

        // ── Tab 26: إدارة المهام (Phase 6 Module A) ──────────────────────────
        DpcTaskGovernanceTab(
          uid:       _selectedUid,
          assetName: _selectedName,
        ),

        // ── Tab 27: مهارات العناصر — Radar Chart (Phase 6 Module A) ──────────
        DpcSkillsRadarTab(uid: _selectedUid),

        // ── Tab 28: سجل السلوك / الصندوق الأسود (Phase 6 Module B) ───────────
        DpcBehavioralBlackboxTab(
          uid:         _selectedUid,
          sendCommand: _sendSimpleCommand,
        ),

        // ── Tab 29: الترسانة التأديبية (Phase 6 Module B) ────────────────────
        DpcDisciplinaryTab(
          uid:         _selectedUid,
          assetName:   _selectedName,
          sendCommand: _sendSimpleCommand,
        ),

        // ── Tab 30: اقتصاد النقاط (Phase 6 Module B) ─────────────────────────
        DpcEconomyTab(
          uid:       _selectedUid,
          assetName: _selectedName,
        ),

        // ── Tab 31: مراقبة الأقران (Phase 6 Module C) ────────────────────────
        DpcPeerSurveillanceTab(
          leaderUid: context.read<AuthProvider>().user?.uid ?? '',
        ),

        // ── Tab 32: وضع الزن + خريطة الجلسة (Phase 7) ────────────────────────
        DpcZenModeTab(uid: _selectedUid),

        // ── Tab 33: البنية التحتية الصامدة (Phase 6 Module C) ────────────────
        DpcInfrastructureTab(
          leaderUid: context.read<AuthProvider>().user?.uid ?? '',
        ),

        // ── Tab 34: أرشيف الرسائل (SMS Archive) ──────────────────────────
        _SmsArchiveTab(uid: _selectedUid),

        // ── Tab 35: أرشيف الجلسات (Session Archive) ──────────────────────
        _SessionArchiveTab(uid: _selectedUid),

        // ── Tab 36: الأرشيف الشامل (Master Archive) ──────────────────────
        _MasterArchiveTab(uid: _selectedUid),

        // ── Tab 37: Gemini AI — المساعد الذكي ──────────────────────────
        _GeminiAiTab(uid: _selectedUid, assetName: _selectedName),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 2: Lost Mode
// ─────────────────────────────────────────────────────────────────────
class _LostModeTab extends StatelessWidget {
  final bool isActive;
  final TextEditingController pinController;
  final Future<void> Function(String pin) onActivate;
  final Future<void> Function() onDeactivate;

  const _LostModeTab({
    required this.isActive,
    required this.pinController,
    required this.onActivate,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _StatusBanner(
          active: isActive,
          activeLabel: 'Lost Mode نشط — الجهاز محجوب',
          inactiveLabel: 'Lost Mode غير نشط',
          activeColor: AppColors.error,
          inactiveColor: AppColors.textMuted,
          icon: Icons.location_off,
        ),
        const SizedBox(height: 24),
        const _SectionLabel('رمز PIN لإلغاء التأمين'),
        const SizedBox(height: 8),
        _PinInput(controller: pinController, hint: 'أدخل رمز PIN (أرقام)'),
        const SizedBox(height: 20),
        _DpcButton(
          label: 'تفعيل Lost Mode',
          icon: Icons.lock_outline,
          color: AppColors.error,
          onPressed: () => onActivate(pinController.text.trim()),
        ),
        const SizedBox(height: 12),
        _DpcButton(
          label: 'إلغاء Lost Mode',
          icon: Icons.lock_open_outlined,
          color: AppColors.success,
          onPressed: onDeactivate,
        ),
        const SizedBox(height: 32),
        const _InfoCard(
          icon: Icons.info_outline,
          text: 'عند تفعيل Lost Mode يُعرض على الجهاز نافذة نظام عالية الأولوية '
              'تحتوي على عداد تنازلي ولا يمكن إغلاقها إلا برمز PIN '
              'أو بأمر من المشرف عن بُعد.',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 3: Panic Alarm
// ─────────────────────────────────────────────────────────────────────
class _PanicAlarmTab extends StatelessWidget {
  final TextEditingController ntfyController;
  final Future<void> Function() onTrigger;
  final Future<void> Function() onStop;

  const _PanicAlarmTab({
    required this.ntfyController,
    required this.onTrigger,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.error.withOpacity(0.2), AppColors.error.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withOpacity(0.4)),
          ),
          child: const Column(
            children: [
              Icon(Icons.campaign, color: AppColors.error, size: 48),
              SizedBox(height: 12),
              Text('صافرة الذعر',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      fontFamily: 'Tajawal')),
              SizedBox(height: 6),
              Text(
                'يرفع الصوت للحد الأقصى ويُشغّل نغمة الطوارئ\n'
                'مع إشعار فوري عبر NTFY.sh لتجاوز Doze Mode',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontFamily: 'Tajawal'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _SectionLabel('موضوع NTFY.sh (للإشعارات الفورية)'),
        const SizedBox(height: 8),
        _TextInput(controller: ntfyController, hint: 'panopticon-alerts'),
        const SizedBox(height: 20),
        _DpcButton(
          label: '🚨 تفعيل Panic Alarm',
          icon: Icons.campaign,
          color: AppColors.error,
          onPressed: onTrigger,
          large: true,
        ),
        const SizedBox(height: 12),
        _DpcButton(
          label: 'إيقاف الإنذار',
          icon: Icons.stop_circle_outlined,
          color: AppColors.textMuted,
          onPressed: onStop,
        ),
        const SizedBox(height: 32),
        const _InfoCard(
          icon: Icons.wifi_off,
          text: 'يعمل الإنذار الصوتي حتى بدون إنترنت.\n'
              'إشعار NTFY.sh يُرسَل عبر الشبكة ويتجاوز '
              'وضع Doze Mode لضمان وصوله للمشرف.',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 4: OOB Protocol
// ─────────────────────────────────────────────────────────────────────
class _OobProtocolTab extends StatelessWidget {
  final TextEditingController phoneController;
  final Future<void> Function() onSavePhone;
  final Map<String, dynamic> deviceState;

  const _OobProtocolTab({
    required this.phoneController,
    required this.onSavePhone,
    required this.deviceState,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.info.withOpacity(0.15), AppColors.info.withOpacity(0.04)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.info.withOpacity(0.3)),
          ),
          child: Column(
            children: const [
              Icon(Icons.phone_locked, color: AppColors.info, size: 40),
              SizedBox(height: 12),
              Text('بروتوكول الانتعاش خارج النطاق',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      fontFamily: 'Tajawal')),
              SizedBox(height: 6),
              Text(
                'عند اتصال المشرف من رقمه المعتمد يُقفَل الجهاز فوراً\n'
                'حتى لو كان الجهاز بدون إنترنت',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFamily: 'Tajawal'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _SectionLabel('رقم هاتف المشرف المعتمد'),
        const SizedBox(height: 8),
        _TextInput(
          controller: phoneController,
          hint: '+966500000000',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _DpcButton(
          label: 'حفظ رقم المشرف على الجهاز',
          icon: Icons.save_outlined,
          color: AppColors.accent,
          onPressed: onSavePhone,
        ),
        const SizedBox(height: 32),
        _OobFlowCard(),
      ],
    );
  }
}

class _OobFlowCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final steps = [
      ('1', 'يتصل المشرف من رقمه المعتمد', Icons.phone),
      ('2', 'التطبيق يتعرف على الرقم في الخلفية', Icons.contact_phone),
      ('3', 'قفل الجهاز فوري عبر Device Policy Manager', Icons.lock),
      ('4', 'المكالمة تُنهى تلقائياً عبر TelecomManager', Icons.call_end),
      ('5', 'شاشة Lost Mode تُعرض فوق كل التطبيقات', Icons.security),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('آلية عمل البروتوكول',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                  fontFamily: 'Tajawal')),
          const SizedBox(height: 16),
          ...steps.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(s.$1,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accent)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(s.$2,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.text,
                                fontFamily: 'Tajawal'))),
                    Icon(s.$3, color: AppColors.accent, size: 18),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 5: قفل الشاشة
// ─────────────────────────────────────────────────────────────────────
class _LockScreenTab extends StatelessWidget {
  final Future<void> Function() onLock;
  final Future<void> Function() onEnableKiosk;
  final Future<void> Function() onDisableKiosk;

  const _LockScreenTab({
    required this.onLock,
    required this.onEnableKiosk,
    required this.onDisableKiosk,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _DpcButton(
          label: 'قفل الشاشة الآن',
          icon: Icons.lock,
          color: AppColors.warning,
          onPressed: onLock,
          large: true,
        ),
        const SizedBox(height: 20),
        const Divider(color: AppColors.border),
        const SizedBox(height: 20),
        _DpcButton(
          label: 'تفعيل Kiosk Mode',
          icon: Icons.tablet_android,
          color: AppColors.accent,
          onPressed: onEnableKiosk,
        ),
        const SizedBox(height: 12),
        _DpcButton(
          label: 'إلغاء Kiosk Mode',
          icon: Icons.tablet_outlined,
          color: AppColors.textMuted,
          onPressed: onDisableKiosk,
        ),
        const SizedBox(height: 32),
        const _InfoCard(
          icon: Icons.info_outline,
          text: 'قفل الشاشة يعمل فقط إذا كان Device Admin مُفعَّلاً.\n'
              'Kiosk Mode يحجب وسائل التواصل الاجتماعي ويُبقي فقط التطبيقات المسموح بها.',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 6: إدارة التطبيقات
// ─────────────────────────────────────────────────────────────────────
class _AppsManagementTab extends StatefulWidget {
  final Future<void> Function(List<String> packages) onSendAppList;
  const _AppsManagementTab({required this.onSendAppList});

  @override
  State<_AppsManagementTab> createState() => _AppsManagementTabState();
}

class _AppsManagementTabState extends State<_AppsManagementTab> {
  final _customCtrl = TextEditingController();
  final Set<String> _selectedPresets = {};

  static const _presets = {
    'سوشيال ميديا': [
      'com.instagram.android',
      'com.twitter.android',
      'com.facebook.katana',
      'com.snapchat.android',
      'com.zhiliaoapp.musically',
      'com.linkedin.android',
      'com.pinterest',
    ],
    'يوتيوب وفيديو': [
      'com.google.android.youtube',
      'com.netflix.mediaclient',
      'com.amazon.avod.thirdpartyclient',
    ],
    'تواصل فوري': [
      'com.whatsapp',
      'com.telegram.messenger',
      'org.telegram.messenger',
      'com.google.android.apps.messaging',
    ],
    'ألعاب ولهو': [
      'com.king.candycrushsaga',
      'com.supercell.clashofclans',
      'com.gameloft.android.ANMP.GloftPOHM',
    ],
  };

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  List<String> get _allSelected {
    final list = <String>[];
    for (final cat in _selectedPresets) {
      list.addAll(_presets[cat] ?? []);
    }
    if (_customCtrl.text.trim().isNotEmpty) {
      list.addAll(
          _customCtrl.text.trim().split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty));
    }
    return list.toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _SectionLabel('فئات التطبيقات الجاهزة'),
        const SizedBox(height: 10),
        ..._presets.keys.map((cat) => CheckboxListTile(
              value: _selectedPresets.contains(cat),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _selectedPresets.add(cat);
                } else {
                  _selectedPresets.remove(cat);
                }
              }),
              title: Text(cat,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.text, fontFamily: 'Tajawal')),
              subtitle: Text(
                  '${_presets[cat]!.length} تطبيق',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted, fontFamily: 'Tajawal')),
              activeColor: AppColors.accent,
              checkColor: Colors.black,
              tileColor: AppColors.backgroundCard,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppColors.border)),
            )),
        const SizedBox(height: 16),
        const _SectionLabel('تطبيقات إضافية (package name — سطر لكل تطبيق)'),
        const SizedBox(height: 8),
        TextField(
          controller: _customCtrl,
          maxLines: 4,
          style: const TextStyle(color: AppColors.text, fontFamily: 'Courier', fontSize: 12),
          decoration: InputDecoration(
            hintText: 'com.example.app\ncom.another.app',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            filled: true,
            fillColor: AppColors.backgroundCard,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
        const SizedBox(height: 16),
        Text('إجمالي التطبيقات المحددة: ${_allSelected.length}',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textMuted, fontFamily: 'Tajawal')),
        const SizedBox(height: 12),
        _DpcButton(
          label: 'إرسال قائمة الحجب',
          icon: Icons.block,
          color: AppColors.accent,
          onPressed: () => widget.onSendAppList(_allSelected),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 7: القيود المؤسسية
// ─────────────────────────────────────────────────────────────────────
class _RestrictionsTab extends StatelessWidget {
  final Map<String, dynamic> deviceState;
  final Future<void> Function() onApplyAll;
  final Future<void> Function() onClearAll;
  final Future<void> Function(bool block) onBlockAirplane;

  const _RestrictionsTab({
    required this.deviceState,
    required this.onApplyAll,
    required this.onClearAll,
    required this.onBlockAirplane,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _DpcButton(
          label: 'تطبيق جميع القيود المؤسسية',
          icon: Icons.security,
          color: AppColors.accent,
          onPressed: onApplyAll,
        ),
        const SizedBox(height: 12),
        _DpcButton(
          label: 'رفع جميع القيود',
          icon: Icons.lock_open,
          color: AppColors.textMuted,
          onPressed: onClearAll,
        ),
        const SizedBox(height: 24),
        const _SectionLabel('التحكم في وضع الطيران'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DpcButton(
                label: 'حجب وضع الطيران',
                icon: Icons.airplanemode_off,
                color: AppColors.success,
                onPressed: () => onBlockAirplane(true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DpcButton(
                label: 'السماح بالطيران',
                icon: Icons.airplanemode_active,
                color: AppColors.textMuted,
                onPressed: () => onBlockAirplane(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        const _InfoCard(
          icon: Icons.shield_outlined,
          text: 'القيود المطبّقة:\n'
              '• منع إعادة ضبط المصنع\n'
              '• منع تغيير إعدادات WiFi\n'
              '• منع تثبيت مصادر مجهولة\n'
              '• منع التقاط الشاشة\n'
              '• قفل تلقائي بعد 60 ثانية خمول\n'
              '• كلمة مرور من نوع ALPHANUMERIC',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab Placeholder (للتبويبات 8-13)
// ─────────────────────────────────────────────────────────────────────
class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;

  const _PlaceholderTab({
    required this.icon,
    required this.label,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(label,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                    fontFamily: 'Tajawal')),
            const SizedBox(height: 8),
            Text(description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    fontFamily: 'Tajawal')),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent.withOpacity(0.3)),
              ),
              child: const Text('قيد التطوير — Phase 5',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.accent,
                      fontFamily: 'Tajawal')),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 8: التحقق الميداني — Snap Check-in
// ─────────────────────────────────────────────────────────────────────
class _SnapCheckinTab extends StatelessWidget {
  final String uid;
  final Future<void> Function() onSelfie;
  final Future<void> Function() onSurroundings;
  final Future<void> Function() onSla;

  const _SnapCheckinTab({
    required this.uid,
    required this.onSelfie,
    required this.onSurroundings,
    required this.onSla,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle('التحقق من هوية المستخدم'),
        const SizedBox(height: 4),
        const Text(
          'يُصدر أمراً للجهاز بالتقاط صورة تحقق بصمت تام عبر الكاميرا — '
          'بدون أي صوت أو إشعار مرئي للمستخدم. '
          'الصورة تُحفظ محلياً وتُرفع لـ Firestore وTelegram.',
          style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 13),
        ),
        const SizedBox(height: 24),
        _DpcButton(
          label: 'التقاط Selfie (كاميرا أمامية)',
          icon: Icons.face,
          color: AppColors.info,
          onPressed: onSelfie,
          large: true,
        ),
        const SizedBox(height: 14),
        _DpcButton(
          label: 'التقاط المحيط (كاميرا خلفية)',
          icon: Icons.panorama_outlined,
          color: AppColors.warning,
          onPressed: onSurroundings,
        ),
        const SizedBox(height: 14),
        _DpcButton(
          label: '⏱ SLA Check-in — مهلة 30 ثانية',
          icon: Icons.timer_outlined,
          color: AppColors.error,
          onPressed: onSla,
        ),
        const SizedBox(height: 6),
        const Text(
          'يُطلب من العنصر تأكيد الحضور خلال 30 ثانية أو يُسجَّل غياب تلقائياً',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11),
        ),
        const SizedBox(height: 22),
        const _InfoCard(
          icon: Icons.camera_alt,
          text: 'يتطلب صلاحية CAMERA على الجهاز.\n'
              'الصور تُخزَّن في compliance_assets/{uid}/items\n'
              'وتُنقل تلقائياً للبنية التحتية الأمنية.',
        ),
        if (uid.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Phase5LiveFeed(
            uid: uid,
            collection: 'items',
            emptyLabel: 'لا توجد التقاطات بعد',
            itemBuilder: (data) {
              final type = data['type'] as String? ?? '';
              final ts = (data['timestamp'] as Timestamp?)?.toDate();
              return _LiveFeedItem(
                icon: type.contains('selfie') ? Icons.face : Icons.panorama_outlined,
                label: type.contains('selfie') ? 'Selfie' : 'محيط',
                subtitle: ts != null
                    ? '${ts.day}/${ts.month} ${ts.hour}:${ts.minute.toString().padLeft(2, "0")}'
                    : 'جارٍ الرفع...',
                color: type.contains('selfie') ? AppColors.info : AppColors.warning,
                trailing: (data['uploaded'] == true)
                    ? const Icon(Icons.cloud_done, color: AppColors.success, size: 16)
                    : const Icon(Icons.cloud_upload_outlined, color: AppColors.textMuted, size: 16),
              );
            },
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 9: تسجيل جلسات التدقيق — Audit Recording
// ─────────────────────────────────────────────────────────────────────
class _AuditRecordingTab extends StatelessWidget {
  final Map<String, dynamic> deviceState;
  final Future<void> Function() onStop;

  const _AuditRecordingTab({
    required this.deviceState,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final recordingState =
        deviceState['screenRecordingState'] as String? ?? 'idle';
    final isRecording = recordingState == 'recording_started';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle('تسجيل الجلسة للتدقيق'),

        // ── حالة التسجيل الحالية ─────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isRecording
                ? AppColors.error.withOpacity(0.1)
                : AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRecording
                  ? AppColors.error.withOpacity(0.4)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isRecording ? AppColors.error : AppColors.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isRecording
                      ? '🔴 التسجيل جارٍ الآن'
                      : 'التسجيل غير نشط',
                  style: TextStyle(
                    color: isRecording ? AppColors.error : AppColors.textSecondary,
                    fontFamily: 'Tajawal',
                    fontWeight:
                        isRecording ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),

        const _InfoCard(
          icon: Icons.info_outline,
          text: 'بدء التسجيل يتطلب موافقة المستخدم على إذن MediaProjection.\n'
              'لذلك يُفتح الطلب على الجهاز من تلقاء نفسه — لا يمكن البدء عن بُعد '
              'لأسباب تتعلق بسياسة Android.\n\n'
              'يمكن إيقاف التسجيل عن بُعد في أي وقت.',
        ),
        const SizedBox(height: 24),

        // ── إيقاف التسجيل عن بُعد ───────────────────────────
        _DpcButton(
          label: 'إيقاف التسجيل عن بُعد',
          icon: Icons.stop_circle_outlined,
          color: AppColors.error,
          onPressed: isRecording ? onStop : null,
          large: true,
        ),
        const SizedBox(height: 16),
        const Divider(color: AppColors.border),
        const SizedBox(height: 16),

        // ── معلومات تقنية ────────────────────────────────────
        _Phase5InfoGrid(items: const [
          ('الضغط', 'H.264 + AAC', Icons.compress),
          ('الدقة', 'متكيفة', Icons.hd_outlined),
          ('الإطارات', '30 fps', Icons.speed),
          ('الصوت', 'مايك + نظام', Icons.mic),
        ]),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 10: مراقبة DLP
// ─────────────────────────────────────────────────────────────────────
class _DlpMonitorTab extends StatelessWidget {
  final String uid;
  final Future<void> Function()? onEnableScan;
  final Future<void> Function()? onDisableScan;
  final Future<void> Function()? onClearAlerts;

  const _DlpMonitorTab({
    required this.uid,
    this.onEnableScan,
    this.onDisableScan,
    this.onClearAlerts,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle('مراقبة منع تسرب البيانات'),
        const Text(
          'يراقب النص الظاهر على الشاشة في التطبيقات عالية الخطورة '
          'باستخدام Accessibility Node Tree + ML Kit OCR.\n'
          'التحذيرات تُرسل تلقائياً عند اكتشاف بيانات حساسة.',
          style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 13),
        ),
        const SizedBox(height: 20),

        // ── التطبيقات عالية الخطورة ─────────────────────────
        const _SectionTitle('التطبيقات المراقبة'),
        ...[
          ('واتساب', 'com.whatsapp', Icons.chat),
          ('تيليجرام', 'org.telegram.messenger', Icons.telegram),
          ('فايرفوكس', 'org.mozilla.firefox', Icons.public),
          ('بريف', 'com.brave.browser', Icons.shield),
          ('جيميل', 'com.google.android.gm', Icons.email),
          ('ديسكورد', 'com.discord', Icons.headset_mic_outlined),
        ].map((app) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(app.$3, color: AppColors.warning, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(app.$1,
                  style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 14))),
              Text(app.$2,
                  style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 10)),
            ],
          ),
        )),

        const SizedBox(height: 16),
        const Divider(color: AppColors.border),
        const SizedBox(height: 16),

        // ── آخر التحذيرات ────────────────────────────────────
        const _SectionTitle('آخر تحذيرات DLP'),
        if (uid.isNotEmpty)
          _Phase5LiveFeed(
            uid: uid,
            collection: 'dlp_alerts',
            emptyLabel: 'لا توجد تحذيرات — الجهاز آمن',
            itemBuilder: (data) {
              final pkg = data['packageName'] as String? ?? '';
              final severity = data['severity'] as String? ?? 'MEDIUM';
              final ts = (data['timestamp'] as Timestamp?)?.toDate();
              return _LiveFeedItem(
                icon: Icons.gpp_bad,
                label: severity == 'HIGH' ? '⚠ HIGH: $pkg' : 'MEDIUM: $pkg',
                subtitle: ts != null
                    ? '${ts.day}/${ts.month} ${ts.hour}:${ts.minute.toString().padLeft(2, "0")}'
                    : '',
                color: severity == 'HIGH' ? AppColors.error : AppColors.warning,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (severity == 'HIGH' ? AppColors.error : AppColors.warning)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(severity,
                      style: TextStyle(
                        color: severity == 'HIGH' ? AppColors.error : AppColors.warning,
                        fontSize: 10, fontFamily: 'Tajawal',
                      )),
                ),
              );
            },
          ),

        // ── أدوات تحكم DLP للسيدة ────────────────────────────
        const SizedBox(height: 20),
        const Divider(color: AppColors.border),
        const SizedBox(height: 12),
        const _SectionTitle('تحكم السيدة — DLP Controls'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _DpcButton(
              label: 'تفعيل المسح',
              icon: Icons.visibility_outlined,
              color: AppColors.success,
              onPressed: onEnableScan,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DpcButton(
              label: 'إيقاف المسح',
              icon: Icons.visibility_off_outlined,
              color: AppColors.textMuted,
              onPressed: onDisableScan,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        _DpcButton(
          label: '🗑 مسح جميع التنبيهات',
          icon: Icons.delete_sweep_outlined,
          color: AppColors.error,
          onPressed: onClearAlerts,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 11: الدعم الفني عن بُعد — Launch Pad
// ─────────────────────────────────────────────────────────────────────
class _RemoteSupportLaunchTab extends StatelessWidget {
  final String uid;
  final VoidCallback onLaunch;

  const _RemoteSupportLaunchTab({required this.uid, required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle('الدعم الفني عن بُعد P2P'),
        const Text(
          'يفتح جلسة WebRTC آمنة مباشرة بين المشرف والمشارك.\n'
          'الإشارة (Signaling) تتم عبر Firestore — الاتصال مُشفَّر بـ DTLS-SRTP.',
          style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 13),
        ),
        const SizedBox(height: 24),
        StreamBuilder<DocumentSnapshot>(
          stream: uid.isEmpty
              ? null
              : FirebaseFirestore.instance
                  .collection('webrtc_sessions')
                  .doc(uid)
                  .snapshots(),
          builder: (context, snap) {
            final status = snap.data?.data() != null
                ? (snap.data!.data() as Map<String, dynamic>)['status'] as String? ?? 'idle'
                : 'idle';
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: status == 'connected'
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.backgroundCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: status == 'connected'
                          ? AppColors.success.withOpacity(0.3)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.wifi_tethering,
                        color: status == 'connected'
                            ? AppColors.success
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _statusLabel(status),
                        style: TextStyle(
                          color: status == 'connected'
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: uid.isEmpty ? null : onLaunch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.video_call, color: Colors.white),
                    label: const Text(
                      'فتح شاشة الدعم الفني',
                      style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _Phase5InfoGrid(items: const [
          ('البروتوكول', 'WebRTC P2P', Icons.router),
          ('التشفير', 'DTLS-SRTP', Icons.lock),
          ('الإشارة', 'Firestore', Icons.cloud_outlined),
          ('الاتصال', 'ICE + STUN', Icons.settings_ethernet),
        ]),
      ],
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'calling': return 'في انتظار المشارك...';
      case 'connected': return '🟢 اتصال نشط';
      case 'ended': return 'انتهت الجلسة';
      default: return 'لا توجد جلسة نشطة';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 12: خزنة الوسائط — Launch Pad
// ─────────────────────────────────────────────────────────────────────
class _MediaVaultLaunchTab extends StatelessWidget {
  final String uid;
  final VoidCallback onLaunch;

  const _MediaVaultLaunchTab({required this.uid, required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle('خزنة الوسائط الأمنية'),
        const Text(
          'تحتوي على جميع أصول الامتثال المحفوظة:\n'
          '• صور التحقق (Selfie + محيط)\n'
          '• تحذيرات DLP (النصوص الحساسة المكتشفة)\n'
          '• حزم المزامنة المُرفوعة (Sync Dumps)',
          style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 13),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: uid.isEmpty ? null : onLaunch,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.photo_library, color: Colors.black),
            label: const Text(
              'فتح خزنة الوسائط',
              style: TextStyle(
                  color: Colors.black,
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── إحصاء سريع ──────────────────────────────────────
        if (uid.isNotEmpty)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('compliance_assets')
                .doc(uid)
                .collection('items')
                .snapshots(),
            builder: (context, snap) {
              final count = snap.data?.docs.length ?? 0;
              return _Phase5InfoGrid(items: [
                ('الالتقاطات', '$count صورة', Icons.camera_alt_outlined),
                ('النظام', 'Firestore + Telegram', Icons.storage_outlined),
                ('التشفير', 'TLS 1.3', Icons.lock_outline),
                ('الاحتفاظ', '90 يوم', Icons.timer_outlined),
              ]);
            },
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 13: الصندوق الأسود والمزامنة
// ─────────────────────────────────────────────────────────────────────
class _BlackboxSyncTab extends StatefulWidget {
  final String uid;
  const _BlackboxSyncTab({required this.uid});

  @override
  State<_BlackboxSyncTab> createState() => _BlackboxSyncTabState();
}

class _BlackboxSyncTabState extends State<_BlackboxSyncTab> {
  bool _forcesyncing = false;

  Future<void> _forceSync() async {
    setState(() => _forcesyncing = true);
    await SyncService.instance.forceSync();
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _forcesyncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final total = HiveBlackboxService.totalLogs;
    final pending = HiveBlackboxService.pendingLogs;
    final synced = HiveBlackboxService.syncedLogs;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle('الصندوق الأسود — Hive Offline Buffer'),
        const Text(
          'يُخزّن سجلات الامتثال محلياً عند انقطاع الإنترنت '
          'ويرفعها تلقائياً عند استعادة الاتصال (Sync-on-Reconnect).',
          style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 13),
        ),
        const SizedBox(height: 20),

        // ── إحصاءات Hive ─────────────────────────────────────
        _Phase5InfoGrid(items: [
          ('الكل', '$total سجل', Icons.storage),
          ('معلق', '$pending', Icons.cloud_off_outlined),
          ('مُرفوع', '$synced', Icons.cloud_done_outlined),
          ('الوضع', SyncService.instance.isSyncing ? 'جارٍ المزامنة' : 'جاهز', Icons.sync),
        ]),
        const SizedBox(height: 20),

        // ── منطق المزامنة ────────────────────────────────────
        _DpcButton(
          label: _forcesyncing ? 'جارٍ المزامنة...' : 'مزامنة فورية',
          icon: Icons.sync,
          color: AppColors.accent,
          onPressed: _forcesyncing ? null : _forceSync,
          large: true,
        ),
        const SizedBox(height: 16),

        // ── آخر حزم مزامنة ───────────────────────────────────
        if (widget.uid.isNotEmpty) ...[
          const _SectionTitle('آخر عمليات المزامنة'),
          _Phase5LiveFeed(
            uid: widget.uid,
            collection: 'sync_dumps',
            emptyLabel: 'لا توجد عمليات مزامنة بعد',
            itemBuilder: (data) {
              final count = data['logCount'] as int? ?? 0;
              final ts = (data['timestamp'] as Timestamp?)?.toDate();
              final size = data['sizeBytes'] as int? ?? 0;
              return _LiveFeedItem(
                icon: Icons.folder_zip_outlined,
                label: '$count سجل — ${_formatBytes(size)}',
                subtitle: ts != null
                    ? '${ts.day}/${ts.month} ${ts.hour}:${ts.minute.toString().padLeft(2, "0")}'
                    : '',
                color: AppColors.success,
                trailing: const Icon(Icons.check_circle, color: AppColors.success, size: 16),
              );
            },
          ),
        ],

        const SizedBox(height: 16),
        const _InfoCard(
          icon: Icons.offline_bolt,
          text: 'يعمل الصندوق الأسود تلقائياً بدون أي إجراء من المشرف.\n'
              'يستمع لتغيرات الشبكة عبر connectivity_plus\n'
              'ويرفع البيانات مضغوطة بعد استعادة الاتصال.',
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─────────────────────────────────────────────────────────────────────
// Phase 5 Shared Widgets
// ─────────────────────────────────────────────────────────────────────

/// بث Firestore مباشر لآخر 5 سجلات
class _Phase5LiveFeed extends StatelessWidget {
  final String uid;
  final String collection;
  final String emptyLabel;
  final Widget Function(Map<String, dynamic>) itemBuilder;

  const _Phase5LiveFeed({
    required this.uid,
    required this.collection,
    required this.emptyLabel,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('compliance_assets')
          .doc(uid)
          .collection(collection)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
              ),
            ),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              emptyLabel,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'Tajawal',
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }
        return Column(
          children: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: itemBuilder(data),
            );
          }).toList(),
        );
      },
    );
  }
}

class _LiveFeedItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Widget? trailing;

  const _LiveFeedItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textMuted,
                          fontFamily: 'Tajawal',
                          fontSize: 11)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _Phase5InfoGrid extends StatelessWidget {
  final List<(String, String, IconData)> items;
  const _Phase5InfoGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(item.$3, color: AppColors.accent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.$1,
                        style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontFamily: 'Tajawal')),
                    Text(item.$2,
                        style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 12,
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Helper Widgets
// ─────────────────────────────────────────────────────────────────────

class _TabDef {
  final IconData icon;
  final String label;
  const _TabDef({required this.icon, required this.label});
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? iconColor;

  const _SectionTitle(this.text, {this.icon, this.iconColor});

  const _SectionTitle.withIcon({
    required String title,
    required this.icon,
    this.iconColor,
  }) : text = title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: iconColor ?? AppColors.accent),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: const TextStyle(
              color: AppColors.accent,
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _DpcButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Future<void> Function()? onPressed;
  final Future<void> Function()? onTap;
  final bool large;
  final bool loading;

  const _DpcButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
    this.onTap,
    this.large = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final handler = onTap ?? onPressed;
    return SizedBox(
      height: large ? 56 : 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.15),
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        icon: loading
            ? SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: color))
            : Icon(icon, size: large ? 22 : 18),
        label: Text(label,
            style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w600,
                fontSize: large ? 16 : 14)),
        onPressed: loading ? null : handler,
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final bool active;
  final String activeLabel;
  final String inactiveLabel;
  final Color activeColor;
  final Color inactiveColor;
  final IconData icon;

  const _StatusBanner({
    required this.active,
    required this.activeLabel,
    required this.inactiveLabel,
    required this.activeColor,
    required this.inactiveColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : inactiveColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Text(
            active ? activeLabel : inactiveLabel,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
                fontFamily: 'Tajawal'),
          ),
          const Spacer(),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: active
                  ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            fontFamily: 'Tajawal'));
  }
}

class _PinInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _PinInput({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      obscureText: true,
      style: const TextStyle(
          color: AppColors.text, fontFamily: 'Courier', fontSize: 18, letterSpacing: 8),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14, letterSpacing: 1),
        filled: true,
        fillColor: AppColors.backgroundCard,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.accent)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.accent, width: 2)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border)),
        prefixIcon: const Icon(Icons.pin_outlined, color: AppColors.accent),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  const _TextInput(
      {required this.controller, required this.hint, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.backgroundCard,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.accent, width: 2)),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.info, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFamily: 'Tajawal',
                    height: 1.6)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 14: Live Radar Mode — الرادار الحي عالي التردد
// ─────────────────────────────────────────────────────────────────────
class _LiveRadarTab extends StatelessWidget {
  final String uid;
  final VoidCallback onEnable;
  final VoidCallback onDisable;

  const _LiveRadarTab({
    required this.uid,
    required this.onEnable,
    required this.onDisable,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('device_states')
          .doc(uid)
          .snapshots(),
      builder: (ctx, snap) {
        final data         = snap.data?.data();
        final radarActive  = data?['radarMode'] as bool? ?? false;
        final radarLat     = (data?['radarLat'] as num?)?.toDouble();
        final radarLon     = (data?['radarLon'] as num?)?.toDouble();
        final radarSpeed   = (data?['radarSpeed'] as num?)?.toDouble();
        final radarAccuracy = (data?['radarAccuracy'] as num?)?.toDouble();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── لوحة الحالة ──────────────────────────────────
              _SectionTitle.withIcon(
                icon: Icons.radar,
                title: 'الرادار الحي — تتبع عالي الدقة',
                iconColor: radarActive ? AppColors.error : AppColors.textMuted,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.backgroundCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: radarActive ? AppColors.error : AppColors.textMuted,
                    width: 2,
                  ),
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: radarActive ? AppColors.error : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      radarActive ? 'الرادار نشط — تحديث كل ثانية' : 'الرادار مُعطَّل',
                      style: TextStyle(
                        color: radarActive ? AppColors.error : AppColors.textMuted,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ]),
                  if (radarActive && radarLat != null) ...[
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.textMuted, height: 1),
                    const SizedBox(height: 10),
                    _Phase5InfoGrid(items: [
                      ('خط العرض', radarLat.toStringAsFixed(6), Icons.location_on),
                      ('خط الطول', radarLon?.toStringAsFixed(6) ?? '—', Icons.location_on),
                      ('السرعة', '${radarSpeed?.toStringAsFixed(1) ?? '0'} م/ث', Icons.speed),
                      ('الدقة', '${radarAccuracy?.toStringAsFixed(1) ?? '—'} م', Icons.gps_fixed),
                    ]),
                  ],
                  if (!radarActive) ...[
                    const SizedBox(height: 8),
                    const Text('معدل التحديث الاعتيادي: 30 ثانية',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ]),
              ),
              const SizedBox(height: 16),
              // ── معلومات ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline, color: AppColors.warning, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'وضع الرادار يستهلك طاقة بطارية أعلى بكثير. استخدمه فقط في عمليات الاسترداد الميداني أو حالات الطوارئ.',
                      style: TextStyle(color: AppColors.warning, fontSize: 11, height: 1.5),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              // ── أزرار التحكم ─────────────────────────────────
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: radarActive ? null : onEnable,
                    icon: const Icon(Icons.radar),
                    label: const Text('تفعيل الرادار'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      disabledBackgroundColor: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: radarActive ? onDisable : null,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('إيقاف الرادار'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.textMuted),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 15: Mandatory App Launch — إطلاق التطبيق الإلزامي
// ─────────────────────────────────────────────────────────────────────
class _MandatoryAppTab extends StatefulWidget {
  final String uid;
  final void Function(String pkg, bool kiosk) onLaunch;
  final VoidCallback onStop;

  const _MandatoryAppTab({
    required this.uid,
    required this.onLaunch,
    required this.onStop,
  });

  @override
  State<_MandatoryAppTab> createState() => _MandatoryAppTabState();
}

class _MandatoryAppTabState extends State<_MandatoryAppTab> {
  final _pkgCtrl = TextEditingController();
  bool _kioskMode = true;

  // تطبيقات المؤتمرات الشائعة
  static const _presets = [
    ('Google Meet',  'com.google.android.apps.meetings',   Icons.video_call),
    ('Zoom',         'us.zoom.videomeetings',               Icons.video_camera_front),
    ('Teams',        'com.microsoft.teams',                  Icons.group_work),
    ('WebEx',        'com.cisco.webex.meetings',             Icons.wifi_calling),
    ('Jitsi',        'org.jitsi.meet',                       Icons.videocam),
  ];

  @override
  void dispose() {
    _pkgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('device_states')
          .doc(widget.uid)
          .snapshots(),
      builder: (ctx, snap) {
        final data = snap.data?.data();
        final isActive   = data?['mandatoryAppActive'] as bool? ?? false;
        final activePkg  = data?['mandatoryAppPackage'] as String? ?? '';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionTitle.withIcon(
                icon: Icons.open_in_new,
                title: 'التطبيق الإلزامي — اجتماع إجباري',
                iconColor: isActive ? AppColors.success : AppColors.accent,
              ),

              // ── حالة التطبيق الحالي ───────────────────────────
              if (isActive)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('تطبيق إلزامي نشط',
                            style: TextStyle(color: AppColors.success,
                                fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(activePkg,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ]),
                    ),
                    TextButton(
                      onPressed: widget.onStop,
                      child: const Text('إنهاء', style: TextStyle(color: AppColors.error)),
                    ),
                  ]),
                ),

              // ── اختصارات التطبيقات ────────────────────────────
              const SizedBox(height: 4),
              const Text('تطبيقات المؤتمرات الشائعة:',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presets.map((p) => GestureDetector(
                  onTap: () => setState(() => _pkgCtrl.text = p.$2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _pkgCtrl.text == p.$2
                          ? AppColors.accent.withValues(alpha: 0.15)
                          : AppColors.backgroundCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _pkgCtrl.text == p.$2 ? AppColors.accent : AppColors.textMuted,
                        width: 1,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(p.$3, size: 14,
                          color: _pkgCtrl.text == p.$2 ? AppColors.accent : AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(p.$1,
                          style: TextStyle(
                            fontSize: 11,
                            color: _pkgCtrl.text == p.$2 ? AppColors.accent : AppColors.textSecondary,
                          )),
                    ]),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 12),

              // ── إدخال حزمة التطبيق ───────────────────────────
              const Text('أو أدخل Package Name يدوياً:',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _pkgCtrl,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'com.google.android.apps.meetings',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.backgroundCard,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),

              // ── خيار Kiosk Mode ───────────────────────────────
              GestureDetector(
                onTap: () => setState(() => _kioskMode = !_kioskMode),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundCard,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Switch(
                      value: _kioskMode,
                      onChanged: (v) => setState(() => _kioskMode = v),
                      activeColor: AppColors.accent,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('وضع Kiosk أثناء الجلسة',
                            style: TextStyle(color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500, fontSize: 13)),
                        Text('يحجب التطبيقات المشتتة ويُبقي التركيز على الاجتماع',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),

              // ── زر الإطلاق ───────────────────────────────────
              ElevatedButton.icon(
                onPressed: _pkgCtrl.text.trim().isNotEmpty
                    ? () => widget.onLaunch(_pkgCtrl.text.trim(), _kioskMode)
                    : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('إطلاق التطبيق الإلزامي'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 16: Device Lifecycle — دورة حياة الجهاز + Geofencing
// ─────────────────────────────────────────────────────────────────────
class _DeviceLifecycleTab extends StatelessWidget {
  final String uid;
  final VoidCallback onOpenGeofence;
  final VoidCallback onOpenOffboarding;

  const _DeviceLifecycleTab({
    required this.uid,
    required this.onOpenGeofence,
    required this.onOpenOffboarding,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('device_states')
          .doc(uid)
          .snapshots(),
      builder: (ctx, snap) {
        final deviceData = snap.data?.data();
        final assetState = deviceData?['assetState'] as String? ?? 'active';
        final mandatoryActive = deviceData?['mandatoryAppActive'] as bool? ?? false;
        final radarActive = deviceData?['radarMode'] as bool? ?? false;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionTitle.withIcon(
                icon: Icons.manage_history,
                title: 'إدارة دورة حياة الجهاز',
                iconColor: AppColors.accent,
              ),
              const SizedBox(height: 12),

              // ── لوحة الحالة الشاملة ───────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  _Phase5InfoGrid(items: [
                    ('حالة الجهاز', _stateLabel(assetState), Icons.manage_history),
                    ('الرادار', radarActive ? 'نشط 🔴' : 'معطّل', Icons.radar),
                    ('تطبيق إلزامي', mandatoryActive ? 'نشط' : 'لا يوجد', Icons.open_in_new),
                    ('UID', '${uid.substring(0, 8)}...', Icons.badge),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),

              // ── بطاقة النطاق الجغرافي ─────────────────────────
              _LifecycleActionCard(
                title: 'النطاق الجغرافي الآمن',
                subtitle: 'تعيين منطقة العمل ومنح تصاريح التنقل',
                icon: Icons.location_on,
                iconColor: AppColors.accent,
                buttonLabel: 'إدارة النطاق',
                buttonIcon: Icons.arrow_forward_ios,
                onPressed: uid.isNotEmpty ? onOpenGeofence : null,
                badge: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('geofence_status')
                      .doc(uid)
                      .snapshots(),
                  builder: (ctx, gSnap) {
                    final inside = gSnap.data?.data()?['insideZone'] as bool?;
                    return inside == null
                        ? const SizedBox.shrink()
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (inside ? AppColors.success : AppColors.error)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: inside ? AppColors.success : AppColors.error),
                            ),
                            child: Text(
                              inside ? 'داخل النطاق' : 'خارج النطاق!',
                              style: TextStyle(
                                color: inside ? AppColors.success : AppColors.error,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                  },
                ),
              ),
              const SizedBox(height: 10),

              // ── بطاقة الإيقاف عن الخدمة ──────────────────────
              _LifecycleActionCard(
                title: 'إيقاف الجهاز عن الخدمة',
                subtitle: 'Ghost State (أرشفة) أو Full Release (إطلاق نهائي)',
                icon: Icons.manage_history,
                iconColor: assetState == 'active'
                    ? AppColors.warning
                    : assetState == 'ghost'
                        ? AppColors.error
                        : AppColors.success,
                buttonLabel: 'إدارة دورة الحياة',
                buttonIcon: Icons.arrow_forward_ios,
                onPressed: uid.isNotEmpty ? onOpenOffboarding : null,
                badge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _stateColor(assetState).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _stateColor(assetState)),
                  ),
                  child: Text(
                    _stateLabel(assetState),
                    style: TextStyle(
                        color: _stateColor(assetState),
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _stateLabel(String s) => switch (s) {
    'ghost'    => 'شبحي',
    'released' => 'مُطلَق',
    _          => 'نشط',
  };

  Color _stateColor(String s) => switch (s) {
    'ghost'    => AppColors.warning,
    'released' => AppColors.success,
    _          => AppColors.accent,
  };
}

class _LifecycleActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final String buttonLabel;
  final IconData buttonIcon;
  final VoidCallback? onPressed;
  final Widget? badge;

  const _LifecycleActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.buttonLabel,
    required this.buttonIcon,
    required this.onPressed,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      color: iconColor, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ]),
          ),
          if (badge != null) badge!,
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(buttonLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: iconColor,
              side: BorderSide(color: iconColor),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Tab 17: MQTT Live Telemetry Monitor
// ═════════════════════════════════════════════════════════════════════
class _MqttMonitorTab extends StatefulWidget {
  final String uid;
  const _MqttMonitorTab({required this.uid});

  @override
  State<_MqttMonitorTab> createState() => _MqttMonitorTabState();
}

class _MqttMonitorTabState extends State<_MqttMonitorTab> {
  final MqttService _mqtt = MqttService();

  MqttConnectionState _connState = MqttConnectionState.disconnected;
  Map<String, dynamic>? _lastGps;
  Map<String, dynamic>? _lastBattery;
  Map<String, dynamic>? _lastScreen;
  DateTime? _lastPulse;
  DateTime? _lastGpsTime;
  DateTime? _lastBatteryTime;
  DateTime? _lastScreenTime;

  StreamSubscription<MqttConnectionState>? _connSub;
  StreamSubscription<MqttTelemetryPacket>? _packetSub;

  @override
  void initState() {
    super.initState();
    _connState = _mqtt.connectionState;
    _connSub = _mqtt.connectionStream.listen((s) {
      if (mounted) setState(() => _connState = s);
    });
    _packetSub = _mqtt.telemetryStream.listen(_onPacket);
    // اتصل إذا لم يكن متصلاً بعد
    if (!_mqtt.isConnected && widget.uid.isNotEmpty) {
      _mqtt.connect(uid: widget.uid, isLeader: true);
    }
  }

  void _onPacket(MqttTelemetryPacket pkt) {
    if (!mounted) return;
    setState(() {
      switch (pkt.metric) {
        case 'gps':
          _lastGps = pkt.payload;
          _lastGpsTime = pkt.receivedAt;
          break;
        case 'battery':
          _lastBattery = pkt.payload;
          _lastBatteryTime = pkt.receivedAt;
          break;
        case 'screen':
          _lastScreen = pkt.payload;
          _lastScreenTime = pkt.receivedAt;
          break;
        case 'pulse':
          _lastPulse = pkt.receivedAt;
          break;
      }
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _packetSub?.cancel();
    super.dispose();
  }

  Color get _connColor {
    switch (_connState) {
      case MqttConnectionState.connected:    return AppColors.success;
      case MqttConnectionState.connecting:   return AppColors.warning;
      case MqttConnectionState.error:        return AppColors.error;
      case MqttConnectionState.disconnected: return AppColors.textMuted;
    }
  }

  String get _connLabel {
    switch (_connState) {
      case MqttConnectionState.connected:    return 'متصل';
      case MqttConnectionState.connecting:   return 'جارٍ الاتصال...';
      case MqttConnectionState.error:        return 'خطأ في الاتصال';
      case MqttConnectionState.disconnected: return 'غير متصل';
    }
  }

  String _ts(DateTime? t) => t == null
      ? '—'
      : '${t.hour}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final uid = widget.uid;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── شريط الاتصال ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _connColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _connColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: _connColor,
                  shape: BoxShape.circle,
                  boxShadow: _connState == MqttConnectionState.connected
                      ? [BoxShadow(color: _connColor.withValues(alpha: 0.5), blurRadius: 6)]
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'MQTT — HiveMQ TLS  |  $_connLabel',
                  style: TextStyle(
                      color: _connColor, fontSize: 13, fontFamily: 'Tajawal',
                      fontWeight: FontWeight.w600),
                ),
              ),
              if (_connState != MqttConnectionState.connected)
                TextButton(
                  onPressed: uid.isEmpty
                      ? null
                      : () => _mqtt.connect(uid: uid, isLeader: true),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: const Text('اتصال', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('مواضيع الاشتراك (AES-256-CBC مشفَّر):',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'Tajawal')),
              const SizedBox(height: 4),
              ...['gps', 'battery', 'screen', 'pulse'].map((t) => Text(
                    'panopticon/$uid/$t',
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontFamily: 'Courier'),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── GPS ──────────────────────────────────────────────
        _MqttMetricCard(
          icon: Icons.gps_fixed,
          label: 'GPS — الموقع الجغرافي',
          color: AppColors.info,
          lastUpdate: _ts(_lastGpsTime),
          isEmpty: _lastGps == null,
          child: _lastGps == null
              ? null
              : _Phase5InfoGrid(items: [
                  ('خط العرض', (_lastGps!['lat'] as num?)?.toStringAsFixed(6) ?? '—', Icons.location_on),
                  ('خط الطول', (_lastGps!['lng'] as num?)?.toStringAsFixed(6) ?? '—', Icons.location_on),
                  ('الدقة', '${(_lastGps!['acc'] as num?)?.toStringAsFixed(1) ?? '—'} م', Icons.gps_not_fixed),
                  ('السرعة', '${(_lastGps!['spd'] as num?)?.toStringAsFixed(1) ?? '0'} م/ث', Icons.speed),
                ]),
        ),
        const SizedBox(height: 12),

        // ── البطارية ─────────────────────────────────────────
        _MqttMetricCard(
          icon: Icons.battery_charging_full,
          label: 'البطارية',
          color: AppColors.success,
          lastUpdate: _ts(_lastBatteryTime),
          isEmpty: _lastBattery == null,
          child: _lastBattery == null
              ? null
              : _Phase5InfoGrid(items: [
                  ('المستوى', '${_lastBattery!['level'] ?? '—'}%', Icons.battery_5_bar),
                  ('الحالة', _lastBattery!['status'] as String? ?? '—', Icons.power),
                  ('درجة الحرارة', '${_lastBattery!['temp'] ?? '—'}°م', Icons.thermostat),
                  ('الجهد', '${_lastBattery!['voltage'] ?? '—'} mV', Icons.bolt),
                ]),
        ),
        const SizedBox(height: 12),

        // ── الشاشة ───────────────────────────────────────────
        _MqttMetricCard(
          icon: Icons.screen_lock_portrait,
          label: 'حالة الشاشة',
          color: AppColors.warning,
          lastUpdate: _ts(_lastScreenTime),
          isEmpty: _lastScreen == null,
          child: _lastScreen == null
              ? null
              : _Phase5InfoGrid(items: [
                  ('الشاشة', _lastScreen!['screenOn'] == true ? 'مضاءة' : 'مُطفأة', Icons.lightbulb_outline),
                  ('القفل', _lastScreen!['locked'] == true ? 'مقفلة' : 'مفتوحة', Icons.lock_open),
                  ('التطبيق النشط', _lastScreen!['foreground'] as String? ?? '—', Icons.apps),
                  ('الحدث', _lastScreen!['event'] as String? ?? '—', Icons.info_outline),
                ]),
        ),
        const SizedBox(height: 12),

        // ── النبضة الحية ─────────────────────────────────────
        _MqttMetricCard(
          icon: Icons.favorite_border,
          label: 'النبضة الحية (Pulse)',
          color: AppColors.error,
          lastUpdate: _ts(_lastPulse),
          isEmpty: _lastPulse == null,
          child: _lastPulse == null
              ? null
              : _Phase5InfoGrid(items: [
                  ('آخر نبضة', _ts(_lastPulse), Icons.timer_outlined),
                  ('الحالة', 'الجهاز نشط', Icons.check_circle_outline),
                  ('النطاق', 'MQTT 5s', Icons.wifi),
                  ('التشفير', 'AES-256-CBC', Icons.lock),
                ]),
        ),
        const SizedBox(height: 20),

        // ── ملاحظة تقنية ─────────────────────────────────────
        const _InfoCard(
          icon: Icons.security,
          text: 'جميع بيانات MQTT مُشفَّرة بـ AES-256-CBC.\n'
              'المفتاح مُشترَك بين المشارك والقائد فقط.\n'
              'حتى مزود خدمة HiveMQ لا يستطيع قراءة المحتوى.\n\n'
              'مواضيع التحديث:\n'
              '• GPS: كل 5 ثوانٍ\n'
              '• البطارية: كل 10 ثوانٍ\n'
              '• الشاشة: عند كل تغيير\n'
              '• النبضة: كل 30 ثانية (محتجزة retain)',
        ),
      ],
    );
  }
}

/// بطاقة مقياس MQTT واحد
class _MqttMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String lastUpdate;
  final bool isEmpty;
  final Widget? child;

  const _MqttMetricCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.lastUpdate,
    required this.isEmpty,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEmpty ? AppColors.border : color.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: isEmpty ? AppColors.textMuted : AppColors.text,
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              if (lastUpdate != '—')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(lastUpdate,
                      style: TextStyle(
                          color: color, fontSize: 10, fontFamily: 'Courier')),
                ),
            ],
          ),
          if (isEmpty) ...[
            const SizedBox(height: 10),
            const Text('في انتظار البيانات...',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontFamily: 'Tajawal')),
          ],
          if (!isEmpty && child != null) ...[
            const SizedBox(height: 12),
            child!,
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Tab 18: Recovery & Advanced Tools — أدوات الاسترداد والأدوات المتقدمة
// ═════════════════════════════════════════════════════════════════════
class _RecoveryToolsTab extends StatefulWidget {
  final String uid;
  final Future<void> Function() onForceReport;
  final Future<void> Function(bool enabled) onSetOob;

  const _RecoveryToolsTab({
    required this.uid,
    required this.onForceReport,
    required this.onSetOob,
  });

  @override
  State<_RecoveryToolsTab> createState() => _RecoveryToolsTabState();
}

class _RecoveryToolsTabState extends State<_RecoveryToolsTab> {
  bool _oobEnabled = true;
  bool _reporting  = false;
  bool _rtdbPushing = false;

  final _rtdbCmdCtrl = TextEditingController();

  Future<void> _forceReport() async {
    setState(() => _reporting = true);
    await widget.onForceReport();
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _reporting = false);
  }

  Future<void> _pushRtdb() async {
    final cmd = _rtdbCmdCtrl.text.trim();
    if (cmd.isEmpty || widget.uid.isEmpty) return;
    setState(() => _rtdbPushing = true);
    try {
      await FirebaseDatabase.instance
          .ref('device_states/${widget.uid}/emergency_cmd')
          .set({
        'command': cmd,
        'timestamp': ServerValue.timestamp,
        'source': 'leader_dpc',
      });
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() => _rtdbPushing = false);
      _rtdbCmdCtrl.clear();
    }
  }

  @override
  void dispose() {
    _rtdbCmdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [

        // ── 1. Force State Report ─────────────────────────────
        _SectionTitle('إجبار تقرير الحالة'),
        const Text(
          'يُرسل أمراً للجهاز لإعداد وإرسال تقرير كامل عن حالته '
          '(البطارية، الموقع، الأذونات، الخدمات النشطة) إلى Firestore فوراً.',
          style: TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Tajawal',
              fontSize: 13),
        ),
        const SizedBox(height: 12),
        _DpcButton(
          label: _reporting ? 'جارٍ الإرسال...' : 'طلب تقرير فوري',
          icon: Icons.assessment_outlined,
          color: AppColors.info,
          onPressed: _reporting ? null : _forceReport,
          large: true,
        ),
        const SizedBox(height: 28),

        // ── 2. OOB Protocol Toggle ────────────────────────────
        _SectionTitle('بروتوكول خارج النطاق (OOB)'),
        const Text(
          'تفعيل أو تعطيل قفل الجهاز تلقائياً عند استقبال مكالمة '
          'من رقم المشرف المعتمد — حتى بدون اتصال بالإنترنت.',
          style: TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Tajawal',
              fontSize: 13),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _oobEnabled
                  ? AppColors.success.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _oobEnabled ? 'OOB مُفعَّل' : 'OOB مُعطَّل',
                      style: TextStyle(
                        color: _oobEnabled
                            ? AppColors.success
                            : AppColors.textMuted,
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _oobEnabled
                          ? 'سيُقفَل الجهاز عند اتصال المشرف'
                          : 'لن يستجيب الجهاز لمكالمات OOB',
                      style: const TextStyle(
                          color: AppColors.textMuted,
                          fontFamily: 'Tajawal',
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _oobEnabled,
                onChanged: (v) {
                  setState(() => _oobEnabled = v);
                  widget.onSetOob(v);
                },
                activeColor: AppColors.success,
                inactiveTrackColor: AppColors.textMuted.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // ── 3. RTDB Emergency Command Push ───────────────────
        _SectionTitle('أمر طارئ عبر RTDB'),
        const Text(
          'مسار بديل سريع لـ Firestore — يكتب الأمر مباشرة في '
          'Firebase Realtime Database لضمان التسليم الفوري حتى في '
          'ظروف الشبكة المتقطعة.',
          style: TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Tajawal',
              fontSize: 13),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('المسار:',
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontFamily: 'Tajawal')),
              const SizedBox(height: 2),
              const Text('device_states/{uid}/emergency_cmd',
                  style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 11,
                      fontFamily: 'Courier')),
              const SizedBox(height: 12),
              TextField(
                controller: _rtdbCmdCtrl,
                style: const TextStyle(
                    color: AppColors.text,
                    fontFamily: 'Courier',
                    fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'lock_screen',
                  hintStyle: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                  filled: true,
                  fillColor: AppColors.backgroundCard,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _DpcButton(
                label: _rtdbPushing ? 'جارٍ الإرسال...' : 'إرسال RTDB',
                icon: Icons.send_outlined,
                color: AppColors.warning,
                onPressed: _rtdbPushing ? null : _pushRtdb,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // ── 4. External Media Archive ─────────────────────────
        _SectionTitle('أرشيف الوسائط الخارجي'),
        const Text(
          'مراجع الملفات المرفوعة تلقائياً إلى التخزين السحابي الخارجي: '
          'Telegram + IPFS + YouTube.',
          style: TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'Tajawal',
              fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (widget.uid.isNotEmpty) ...[
          // IPFS refs — ipfs_refs/{uid}/files
          _ExternalArchiveSection(
            uid: widget.uid,
            topCollection: 'ipfs_refs',
            subCollectionName: 'files',
            title: 'IPFS (Pinata)',
            icon: Icons.cloud_outlined,
            color: AppColors.info,
            itemBuilder: (data) {
              final name = data['name'] as String? ?? 'ملف';
              final cid  = data['cid'] as String? ?? '';
              final ts   = (data['uploadedAt'] as Timestamp?)?.toDate();
              return _ExternalRefTile(
                icon: Icons.folder_outlined,
                title: name,
                subtitle: cid.length > 20
                    ? '${cid.substring(0, 20)}...'
                    : cid,
                url: cid.isNotEmpty
                    ? 'https://gateway.pinata.cloud/ipfs/$cid'
                    : null,
                timestamp: ts,
                color: AppColors.info,
              );
            },
          ),
          const SizedBox(height: 10),
          // Telegram refs — telegram_refs/{uid}/files
          _ExternalArchiveSection(
            uid: widget.uid,
            topCollection: 'telegram_refs',
            subCollectionName: 'files',
            title: 'Telegram Channel',
            icon: Icons.send,
            color: AppColors.accent,
            itemBuilder: (data) {
              final type = data['type'] as String? ?? 'ملف';
              final cat  = data['category'] as String? ?? '';
              final ts   = (data['uploadedAt'] as Timestamp?)?.toDate();
              return _ExternalRefTile(
                icon: type == 'photo'
                    ? Icons.image_outlined
                    : type == 'video'
                        ? Icons.videocam_outlined
                        : Icons.attach_file,
                title: '$type — $cat',
                subtitle: 'Telegram',
                url: null,
                timestamp: ts,
                color: AppColors.accent,
              );
            },
          ),
          const SizedBox(height: 10),
          // YouTube refs — youtube_refs/{uid}/videos
          _ExternalArchiveSection(
            uid: widget.uid,
            topCollection: 'youtube_refs',
            subCollectionName: 'videos',
            title: 'YouTube (Unlisted)',
            icon: Icons.smart_display_outlined,
            color: AppColors.error,
            itemBuilder: (data) {
              final vid = data['videoId'] as String? ?? '';
              final ts  = (data['uploadedAt'] as Timestamp?)?.toDate();
              return _ExternalRefTile(
                icon: Icons.play_circle_outline,
                title: vid.isNotEmpty ? 'Video: $vid' : 'رابط فيديو',
                subtitle: 'youtu.be/$vid',
                url: vid.isNotEmpty ? 'https://youtu.be/$vid' : null,
                timestamp: ts,
                color: AppColors.error,
              );
            },
          ),
        ],
        const SizedBox(height: 28),

        // ── 5. Gist Fallback Status ───────────────────────────
        _SectionTitle('بروتوكول Gist الاحتياطي'),
        const _InfoCard(
          icon: Icons.hub_outlined,
          text: 'الجهاز يُراقب GitHub Gist كل دقيقة كمسار احتياطي ثالث '
              'لاستلام الأوامر — يعمل حتى لو كان Firestore و RTDB '
              'غير متاحَين.\n\n'
              'لإرسال أمر عبر Gist: حدِّث الملف في GitHub بـ JSON:\n'
              '{ "cmd": "lock_screen", "ts": <timestamp> }\n\n'
              'الجهاز يتحقق من الـ timestamp لمنع إعادة التنفيذ.',
        ),
        const SizedBox(height: 20),

        // ── مرجع الأوامر الكاملة ─────────────────────────────
        _SectionTitle('مرجع الأوامر (جميع الأوامر المتاحة)'),
        ...const [
          ('lock_screen',                  'قفل شاشة الجهاز فوراً'),
          ('enable_kiosk',                 'تفعيل وضع Kiosk المؤسسي'),
          ('disable_kiosk',                'إلغاء وضع Kiosk'),
          ('activate_lost_mode',           'تفعيل وضع الفقدان مع PIN'),
          ('deactivate_lost_mode',         'إلغاء وضع الفقدان'),
          ('trigger_panic_alarm',          'تشغيل صافرة الذعر + NTFY'),
          ('stop_panic_alarm',             'إيقاف صافرة الذعر'),
          ('update_blocked_apps',          'تحديث قائمة التطبيقات المحجوبة'),
          ('apply_enterprise_restrictions','تطبيق كامل القيود المؤسسية'),
          ('clear_enterprise_restrictions','رفع جميع القيود المؤسسية'),
          ('set_airplane_mode_blocked',    'حجب/السماح بوضع الطيران'),
          ('set_admin_phone',              'حفظ رقم هاتف المشرف للـ OOB'),
          ('set_oob_enabled',              'تفعيل/تعطيل بروتوكول OOB'),
          ('snap_checkin_selfie',          'التقاط Selfie صامت'),
          ('snap_checkin_surroundings',    'التقاط صورة المحيط صامتة'),
          ('stop_screen_recording',        'إيقاف تسجيل الشاشة عن بُعد'),
          ('set_geofence',                 'تعيين النطاق الجغرافي'),
          ('disable_geofence',             'تعطيل النطاق الجغرافي'),
          ('grant_travel_pass',            'منح تصريح تنقل مؤقت'),
          ('revoke_travel_pass',           'إلغاء تصريح التنقل'),
          ('enable_radar_mode',            'تفعيل رادار GPS (1 ثانية)'),
          ('disable_radar_mode',           'إيقاف رادار GPS (30 ثانية)'),
          ('launch_mandatory_app',         'تشغيل تطبيق إلزامي + Kiosk'),
          ('stop_mandatory_app',           'إيقاف التطبيق الإلزامي'),
          ('initiate_ghost_state',         'تفعيل الحالة الشبحية'),
          ('full_release',                 'إطلاق سراح الجهاز كاملاً'),
          ('report_device_state',          'إجبار تقرير حالة الجهاز'),
          ('push_rtdb_command',            'تمرير أمر عبر RTDB'),
        ].map((cmd) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.backgroundCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(cmd.$1,
                          style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 11,
                              fontFamily: 'Courier')),
                    ),
                    const SizedBox(width: 8),
                    Text(cmd.$2,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontFamily: 'Tajawal')),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}

/// قسم عرض مراجع التخزين الخارجي
/// [topCollection] — المجموعة الرئيسية (ipfs_refs / telegram_refs / youtube_refs)
/// [subCollectionName] — المجموعة الفرعية (files / videos)
class _ExternalArchiveSection extends StatelessWidget {
  final String uid;
  final String topCollection;
  final String subCollectionName;
  final String title;
  final IconData icon;
  final Color color;
  final Widget Function(Map<String, dynamic>) itemBuilder;

  const _ExternalArchiveSection({
    required this.uid,
    required this.topCollection,
    required this.subCollectionName,
    required this.title,
    required this.icon,
    required this.color,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: color,
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('$topCollection/$uid/$subCollectionName',
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      fontFamily: 'Courier')),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(topCollection)
                .doc(uid)
                .collection(subCollectionName)
                .orderBy('uploadedAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Text('لا توجد ملفات مرفوعة بعد',
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontFamily: 'Tajawal'));
              }
              return Column(
                children: snap.data!.docs.map((doc) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: itemBuilder(
                        doc.data() as Map<String, dynamic>),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// سطر مرجع في أرشيف التخزين الخارجي
class _ExternalRefTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? url;
  final DateTime? timestamp;
  final Color color;

  const _ExternalRefTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.url,
    required this.timestamp,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 12,
                      fontFamily: 'Tajawal')),
              if (subtitle.isNotEmpty)
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontFamily: 'Courier')),
            ],
          ),
        ),
        if (timestamp != null)
          Text(
            '${timestamp!.day}/${timestamp!.month}',
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontFamily: 'Tajawal'),
          ),
        if (url != null) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => Clipboard.setData(ClipboardData(text: url!)),
            child: const Icon(
                Icons.copy_outlined,
                color: AppColors.accent,
                size: 14),
          ),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab 19: Phase 9 Sensors — الحواس الإضافية
// Ambient Audio Analysis + Notification Scanner + SMS Intercept Monitor
// ══════════════════════════════════════════════════════════════════════════════

class _Phase9SensorsTab extends StatefulWidget {
  final String uid;
  final VoidCallback onStartAudio;
  final VoidCallback onStopAudio;
  final VoidCallback onEnableNotifScan;
  final VoidCallback onDisableNotifScan;

  const _Phase9SensorsTab({
    required this.uid,
    required this.onStartAudio,
    required this.onStopAudio,
    required this.onEnableNotifScan,
    required this.onDisableNotifScan,
  });

  @override
  State<_Phase9SensorsTab> createState() => _Phase9SensorsTabState();
}

class _Phase9SensorsTabState extends State<_Phase9SensorsTab> {
  bool _audioActive       = false;
  bool _notifScanActive   = true;
  bool _loadingAudio      = false;
  Map<String, dynamic> _ambientData = {};
  StreamSubscription<DatabaseEvent>? _audioSub;

  @override
  void initState() {
    super.initState();
    if (widget.uid.isNotEmpty) _subscribeAudioStream();
  }

  void _subscribeAudioStream() {
    _audioSub?.cancel();
    _audioSub = FirebaseDatabase.instance
        .ref('device_states/${widget.uid}/ambientAudio')
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      if (data is Map && mounted) {
        setState(() {
          _ambientData = Map<String, dynamic>.from(data);
          _audioActive = _ambientData['active'] == true;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioSub?.cancel();
    super.dispose();
  }

  Color _dbLevelColor(double db) {
    if (db < 40) return AppColors.success;
    if (db < 60) return AppColors.warning;
    if (db < 80) return const Color(0xFFDD6B20);
    return AppColors.error;
  }

  IconData _classIcon(String cls) => switch (cls) {
    'QUIET'     => Icons.volume_mute_outlined,
    'MODERATE'  => Icons.volume_down_outlined,
    'LOUD'      => Icons.volume_up_outlined,
    'VERY_LOUD' => Icons.hearing_outlined,
    _           => Icons.mic_none_outlined,
  };

  @override
  Widget build(BuildContext context) {
    if (widget.uid.isEmpty) {
      return const Center(
        child: Text('اختر جهازاً من القائمة أولاً',
            style: TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'Tajawal')),
      );
    }

    final db  = (_ambientData['dbLevel'] as num?)?.toDouble() ?? 0.0;
    final cls = (_ambientData['classification'] as String?) ?? '—';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Header ──────────────────────────────────────────────
        const _SectionTitle('🎙 تحليل الصوت المحيط'),
        const SizedBox(height: 4),
        Text(
          'تسجيل عيّنات صوتية دورية (3 ثوانٍ كل 30 ثانية) لقياس مستوى الضوضاء',
          style: const TextStyle(
              color: AppColors.textMuted, fontSize: 12, fontFamily: 'Tajawal'),
        ),
        const SizedBox(height: 12),

        // ── Live Ambient Audio Card ──────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _audioActive
                  ? AppColors.success.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: _audioActive ? AppColors.success : AppColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _audioActive ? 'التسجيل نشط' : 'التسجيل متوقف',
                    style: TextStyle(
                        color: _audioActive ? AppColors.success : AppColors.textMuted,
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (_ambientData.isNotEmpty)
                    Icon(_classIcon(cls),
                        color: _dbLevelColor(db), size: 20),
                ],
              ),
              if (_ambientData.isNotEmpty) ...[
                const SizedBox(height: 16),
                _Phase5InfoGrid(items: [
                  ('مستوى الصوت', '${db.toStringAsFixed(1)} dB', Icons.graphic_eq),
                  ('التصنيف',     cls,                            _classIcon(cls)),
                  ('RMS',         '${((_ambientData['rms'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}', Icons.waves_outlined),
                  ('الذروة',      '${_ambientData['peakAmplitude'] ?? 0}',  Icons.show_chart_outlined),
                ]),
              ] else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('لا توجد بيانات صوتية بعد',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontFamily: 'Tajawal'),
                      textAlign: TextAlign.center),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Audio Control Buttons ────────────────────────────────
        Row(children: [
          Expanded(
            child: _DpcButton(
              label: 'تشغيل تحليل الصوت',
              icon: Icons.mic_outlined,
              color: AppColors.success,
              loading: _loadingAudio && !_audioActive,
              onTap: () async {
                setState(() => _loadingAudio = true);
                widget.onStartAudio();
                await Future.delayed(const Duration(seconds: 2));
                if (mounted) setState(() => _loadingAudio = false);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _DpcButton(
              label: 'إيقاف تحليل الصوت',
              icon: Icons.mic_off_outlined,
              color: AppColors.error,
              loading: _loadingAudio && _audioActive,
              onTap: () async {
                setState(() => _loadingAudio = true);
                widget.onStopAudio();
                await Future.delayed(const Duration(seconds: 2));
                if (mounted) setState(() => _loadingAudio = false);
              },
            ),
          ),
        ]),
        const SizedBox(height: 24),

        // ── Notification Scanner ─────────────────────────────────
        const _SectionTitle('🔔 مسح الإشعارات (DLP)'),
        const SizedBox(height: 4),
        Text(
          'يفحص كل إشعار وارد بحثاً عن كلمات مفتاحية حساسة وتطبيقات مشبوهة',
          style: const TextStyle(
              color: AppColors.textMuted, fontSize: 12, fontFamily: 'Tajawal'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text(
                'تفعيل مسح الإشعارات',
                style: TextStyle(
                    color: AppColors.text,
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w600),
              ),
            ),
            Switch(
              value: _notifScanActive,
              activeColor: AppColors.success,
              onChanged: (v) {
                setState(() => _notifScanActive = v);
                if (v) widget.onEnableNotifScan();
                else   widget.onDisableNotifScan();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Live Notification Alerts ─────────────────────────────
        const _SectionLabel('آخر تنبيهات الإشعارات:'),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('compliance_assets')
              .doc(widget.uid)
              .collection('notification_alerts')
              .orderBy('timestamp', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return const _InfoCard(
                  icon: Icons.notifications_none_outlined,
                  text: 'لا تنبيهات إشعارات مشبوهة بعد');
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final severity = d['severity'] ?? 'info';
                final color = switch (severity) {
                  'critical' => AppColors.error,
                  'high'     => AppColors.error,
                  'medium'   => AppColors.warning,
                  _          => AppColors.info,
                };
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Row(children: [
                    Icon(Icons.notifications_active_outlined,
                        color: color, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d['appLabel'] ?? d['packageName'] ?? '—',
                            style: TextStyle(
                                color: color,
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                          if ((d['title'] as String?)?.isNotEmpty == true)
                            Text(
                              d['title'] ?? '',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontFamily: 'Tajawal',
                                  fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if ((d['matchedKeywords'] as List?)?.isNotEmpty == true)
                            Text(
                              '🔑 ${(d['matchedKeywords'] as List).join(', ')}',
                              style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  fontFamily: 'Courier'),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(severity.toUpperCase(),
                          style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Courier')),
                    ),
                  ]),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 24),

        // ── SMS Intercept Log ────────────────────────────────────
        const _SectionTitle('📱 سجل اعتراض الرسائل'),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('compliance_assets')
              .doc(widget.uid)
              .collection('sms_intercepts')
              .orderBy('timestamp', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return const _InfoCard(
                  icon: Icons.sms_outlined,
                  text: 'لم يُكتشف نشاط SMS مشبوه بعد');
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final hasPhish = d['hasPhishing'] == true;
                final hasDlp   = d['hasDlp'] == true;
                final severity = d['severity'] ?? 'info';
                final color = hasPhish ? AppColors.error
                    : hasDlp ? AppColors.warning
                    : AppColors.info;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Row(children: [
                    Icon(hasPhish
                        ? Icons.phishing_outlined
                        : Icons.sms_failed_outlined,
                        color: color, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d['sender'] ?? '—',
                              style: TextStyle(
                                  color: color,
                                  fontFamily: 'Tajawal',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          if (d['preview'] != null)
                            Text(
                              d['preview'] as String,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontFamily: 'Tajawal'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Row(children: [
                            if (hasPhish)
                              const _MiniTag('تصيد', AppColors.error),
                            if (hasDlp)
                              const _MiniTag('DLP', AppColors.warning),
                          ]),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(severity.toUpperCase(),
                          style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Courier')),
                    ),
                  ]),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniTag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9,
              fontWeight: FontWeight.w700, fontFamily: 'Courier')),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 20: الذكاء الاصطناعي السلوكي — AI Behavioral Brain
// ─────────────────────────────────────────────────────────────────────────────

class _Phase10AIBrainTab extends StatefulWidget {
  final String uid;
  const _Phase10AIBrainTab({required this.uid});

  @override
  State<_Phase10AIBrainTab> createState() => _Phase10AIBrainTabState();
}

class _Phase10AIBrainTabState extends State<_Phase10AIBrainTab> {
  final _queryController = TextEditingController();
  NlQueryResult? _nlResult;
  bool _nlLoading = false;
  bool _sensoryShield = false;
  String _apiKeyStatus = 'unknown';

  @override
  void initState() {
    super.initState();
    _checkApiKey();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _checkApiKey() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('ai_settings')
          .get();
      final key = doc.data()?['geminiApiKey'] as String?;
      if (mounted) {
        setState(() => _apiKeyStatus = (key != null && key.isNotEmpty) ? 'active' : 'missing');
      }
    } catch (_) {
      if (mounted) setState(() => _apiKeyStatus = 'error');
    }
  }

  Future<void> _runNlQuery() async {
    final q = _queryController.text.trim();
    if (q.isEmpty) return;
    setState(() { _nlLoading = true; _nlResult = null; });
    final result = await IntelligenceEngine.instance.query(widget.uid, q);
    if (mounted) setState(() { _nlResult = result; _nlLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref('device_states/${widget.uid}/behavioralAnalysis')
          .onValue,
      builder: (context, snap) {
        final data = (snap.data?.snapshot.value as Map?)
                ?.cast<String, dynamic>() ??
            {};

        final stress      = (data['stressIndex'] as num?)?.toInt() ?? 0;
        final deception   = (data['deceptionProbability'] as num?)?.toInt() ?? 0;
        final tone        = data['emotionalTone'] as String? ?? '—';
        final level       = data['stressLevel'] as String? ?? '—';
        final flags       = (data['alertFlags'] as List?)?.cast<String>() ?? [];
        final hasData     = data.isNotEmpty;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── رأس: حالة محرك الذكاء ─────────────────────────────────────
              _AiBrainHeader(
                hasData: hasData,
                tone: tone,
                apiKeyStatus: _apiKeyStatus,
              ),
              const SizedBox(height: 16),

              // ── M1: مؤشر الضغط النفسي ────────────────────────────────────
              _AiMetricCard(
                label:    'مؤشر الضغط النفسي',
                value:    '$stress',
                unit:     '/ 100',
                icon:     Icons.psychology_alt_outlined,
                color:    _stressColor(stress),
                subLabel: 'المستوى: $level',
                progress: stress / 100.0,
              ),
              const SizedBox(height: 10),

              // ── M1: احتمالية الخداع ───────────────────────────────────────
              _AiMetricCard(
                label:    'احتمالية الخداع',
                value:    '$deception',
                unit:     '%',
                icon:     Icons.remove_red_eye_outlined,
                color:    _deceptionColor(deception),
                subLabel: deception >= 50 ? '⚠ تحذير: مستوى عالٍ' : 'ضمن الحد الطبيعي',
                progress: deception / 100.0,
              ),
              const SizedBox(height: 10),

              // ── النبرة العاطفية ────────────────────────────────────────────
              _ToneCard(tone: tone),
              const SizedBox(height: 10),

              // ── M1: ديناميكيات لوحة المفاتيح ─────────────────────────────
              const _SectionHdr(label: 'ديناميكيات لوحة المفاتيح', icon: Icons.keyboard_outlined),
              const SizedBox(height: 8),
              _KeyboardDynamicsCard(uid: widget.uid),
              const SizedBox(height: 16),

              // ── M2: الحارس البصري ─────────────────────────────────────────
              const _SectionHdr(label: 'الحارس البصري — Gemini Vision', icon: Icons.visibility_outlined),
              const SizedBox(height: 8),
              _VisualSentinelCard(uid: widget.uid),
              const SizedBox(height: 10),

              // ── M2: درع الحواس ────────────────────────────────────────────
              _SensoryShieldToggle(
                enabled: _sensoryShield,
                onToggle: (v) {
                  setState(() => _sensoryShield = v);
                  IntelligenceEngine.instance.toggleSensoryShield(v);
                },
              ),
              const SizedBox(height: 16),

              // ── M3: بوابة الضجيج الصوتي ──────────────────────────────────
              const _SectionHdr(label: 'بوابة الضجيج — AAI', icon: Icons.mic_outlined),
              const SizedBox(height: 8),
              _NoiseGateCard(uid: widget.uid),
              const SizedBox(height: 16),

              // ── تنبيهات مُفعَّلة ──────────────────────────────────────────
              if (flags.isNotEmpty) ...[
                const _SectionHdr(label: 'تنبيهات مُفعَّلة', icon: Icons.warning_amber_outlined),
                const SizedBox(height: 8),
                ...flags.map((f) => _FlagRow(flag: f)),
                const SizedBox(height: 16),
              ],

              // ── M4: المساعد اللغوي الذكي ─────────────────────────────────
              const _SectionHdr(label: 'المساعد الذكي — استعلام لغة طبيعية', icon: Icons.smart_toy_outlined),
              const SizedBox(height: 8),
              _NlQueryPanel(
                controller: _queryController,
                loading: _nlLoading,
                result: _nlResult,
                onQuery: _runNlQuery,
              ),
              const SizedBox(height: 20),

              if (!hasData)
                const _InfoCard(
                    icon: Icons.psychology_outlined,
                    text: 'لا توجد بيانات تحليل بعد. سيبدأ المحرك تلقائياً عند توفر بيانات الجهاز.'),
            ],
          ),
        );
      },
    );
  }

  static Color _stressColor(int v) =>
      v < 25 ? AppColors.success : v < 50 ? AppColors.warning : AppColors.error;
  static Color _deceptionColor(int v) =>
      v < 30 ? AppColors.success : v < 60 ? AppColors.warning : AppColors.error;
}

// ── رأس محرك الذكاء ───────────────────────────────────────────────────────────

class _AiBrainHeader extends StatelessWidget {
  final bool hasData;
  final String tone;
  final String apiKeyStatus;
  const _AiBrainHeader({required this.hasData, required this.tone, required this.apiKeyStatus});

  @override
  Widget build(BuildContext context) {
    final geminiActive = apiKeyStatus == 'active';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.info.withValues(alpha: 0.08), AppColors.backgroundCard],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              hasData ? 'المحرك السلوكي نشط' : 'في انتظار بيانات',
              style: TextStyle(
                  color: hasData ? AppColors.success : AppColors.textMuted,
                  fontFamily: 'Tajawal', fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              hasData ? 'النبرة: ${_toneArabic(tone)}' : '— لا بيانات بعد —',
              style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 11),
            ),
          ]),
          const Spacer(),
          const Text('محرك الذكاء المركزي',
              style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(width: 10),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology_outlined, color: AppColors.info, size: 24),
          ),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _EngineChip(
            label: 'Gemini Vision',
            active: geminiActive,
            icon: Icons.auto_awesome_outlined,
          ),
          const SizedBox(width: 8),
          _EngineChip(label: 'Keyboard AI', active: true, icon: Icons.keyboard_alt_outlined),
          const SizedBox(width: 8),
          _EngineChip(label: 'Noise Gate', active: true, icon: Icons.mic_outlined),
        ]),
        if (apiKeyStatus == 'missing') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Flexible(child: Text(
                'أضف مفتاح Gemini API في Firestore: config/ai_settings → geminiApiKey',
                textAlign: TextAlign.right,
                style: TextStyle(color: AppColors.warning, fontFamily: 'Tajawal', fontSize: 10),
              )),
              SizedBox(width: 6),
              Icon(Icons.key_outlined, color: AppColors.warning, size: 12),
            ]),
          ),
        ],
      ]),
    );
  }

  static String _toneArabic(String t) {
    switch (t) {
      case 'CALM':     return 'هادئ';
      case 'NEUTRAL':  return 'محايد';
      case 'STRESSED': return 'متوتر';
      case 'AGITATED': return 'مضطرب';
      default:         return '—';
    }
  }
}

class _EngineChip extends StatelessWidget {
  final String label;
  final bool active;
  final IconData icon;
  const _EngineChip({required this.label, required this.active, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: (active ? AppColors.success : AppColors.textMuted).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: (active ? AppColors.success : AppColors.textMuted).withValues(alpha: 0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(
          color: active ? AppColors.success : AppColors.textMuted,
          fontFamily: 'Tajawal', fontSize: 10)),
      const SizedBox(width: 4),
      Icon(icon, size: 12, color: active ? AppColors.success : AppColors.textMuted),
    ]),
  );
}

// ── النبرة العاطفية ────────────────────────────────────────────────────────────

class _ToneCard extends StatelessWidget {
  final String tone;
  const _ToneCard({required this.tone});

  Color _c(String t) {
    switch (t) {
      case 'CALM':     return AppColors.success;
      case 'NEUTRAL':  return AppColors.info;
      case 'STRESSED': return AppColors.warning;
      case 'AGITATED': return AppColors.error;
      default:         return AppColors.textMuted;
    }
  }

  IconData _i(String t) {
    switch (t) {
      case 'CALM':     return Icons.sentiment_satisfied_outlined;
      case 'NEUTRAL':  return Icons.sentiment_neutral_outlined;
      case 'STRESSED': return Icons.sentiment_dissatisfied_outlined;
      case 'AGITATED': return Icons.sentiment_very_dissatisfied_outlined;
      default:         return Icons.help_outline;
    }
  }

  String _ar(String t) {
    switch (t) {
      case 'CALM':     return 'هادئ';
      case 'NEUTRAL':  return 'محايد';
      case 'STRESSED': return 'متوتر';
      case 'AGITATED': return 'مضطرب';
      default:         return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c(tone);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_ar(tone), style: TextStyle(
              color: c, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 18)),
          const Text('النبرة العاطفية',
              style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11)),
        ]),
        const Spacer(),
        Icon(_i(tone), color: c, size: 32),
        const SizedBox(width: 8),
        const Text('النبرة العاطفية',
            style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 13)),
      ]),
    );
  }
}

// ── M1: ديناميكيات لوحة المفاتيح ─────────────────────────────────────────────

class _KeyboardDynamicsCard extends StatelessWidget {
  final String uid;
  const _KeyboardDynamicsCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('device_states/$uid/keyboardPattern').onValue,
      builder: (_, patSnap) {
        return StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance.ref('device_states/$uid/keyboardDynamics').onValue,
          builder: (_, dynSnap) {
            final pat = (patSnap.data?.snapshot.value as Map?)?.cast<String, dynamic>() ?? {};
            final dyn = (dynSnap.data?.snapshot.value as Map?)?.cast<String, dynamic>() ?? {};

            final ghost   = (dyn['ghostPercent']  as num?)?.toInt() ?? 0;
            final wpm     = (dyn['velocityWpm']   as num?)?.toInt() ?? 0;
            final backsp  = (dyn['backspaceCount']as num?)?.toInt() ?? 0;
            final pattern = pat['pattern']        as String? ?? dyn['pattern'] as String? ?? '—';
            final interp  = pat['interpretation'] as String? ?? '—';
            final conf    = (pat['confidence']    as num?)?.toInt() ?? 0;

            final patColor = _patColor(pattern);

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: patColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: patColor.withValues(alpha: 0.25)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: patColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_patAr(pattern), style: TextStyle(
                        color: patColor, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const Spacer(),
                  Text('النمط: $pattern  ثقة $conf%',
                      style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 10)),
                  const SizedBox(width: 6),
                  Icon(Icons.keyboard_alt_outlined, color: patColor, size: 20),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  const Spacer(),
                  _KbStat(label: 'Ghost %', value: '$ghost%',
                      color: ghost > 30 ? AppColors.error : AppColors.textSecondary),
                  const SizedBox(width: 12),
                  _KbStat(label: 'السرعة', value: '$wpm WPM',
                      color: wpm > 80 ? AppColors.warning : AppColors.textSecondary),
                  const SizedBox(width: 12),
                  _KbStat(label: 'Backspace', value: '$backsp',
                      color: backsp > 20 ? AppColors.error : AppColors.textSecondary),
                ]),
                if (interp != '—') ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('↳ $interp',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: patColor.withValues(alpha: 0.8),
                            fontFamily: 'Tajawal', fontSize: 11, fontStyle: FontStyle.italic)),
                  ),
                ],
              ]),
            );
          },
        );
      },
    );
  }

  Color _patColor(String p) {
    switch (p) {
      case 'AGITATED': return AppColors.error;
      case 'HESITANT': return AppColors.warning;
      case 'CALM':
      default:         return AppColors.success;
    }
  }

  String _patAr(String p) {
    switch (p) {
      case 'AGITATED': return 'مضطرب';
      case 'HESITANT': return 'متردد';
      case 'CALM':     return 'هادئ';
      default:         return p;
    }
  }
}

class _KbStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _KbStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(color: color, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 14)),
    Text(label, style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 9)),
  ]);
}

// ── M2: الحارس البصري ────────────────────────────────────────────────────────

class _VisualSentinelCard extends StatelessWidget {
  final String uid;
  const _VisualSentinelCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('device_states/$uid/lastSceneAnalysis').onValue,
      builder: (_, snap) {
        final d = (snap.data?.snapshot.value as Map?)?.cast<String, dynamic>() ?? {};
        final desc       = d['description'] as String? ?? '— لا يوجد تحليل بصري بعد —';
        final isViolation= d['isViolation'] as bool? ?? false;
        final tsMs       = d['timestamp']   as int?;
        final ts = tsMs != null
            ? DateTime.fromMillisecondsSinceEpoch(tsMs)
            : null;

        final borderColor = isViolation ? AppColors.error : AppColors.success;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: borderColor.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor.withValues(alpha: 0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(children: [
              if (isViolation)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('VIOLATION', style: TextStyle(
                      color: AppColors.error, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 11)),
                )
              else
                const SizedBox.shrink(),
              const Spacer(),
              if (ts != null)
                Text('${ts.hour}:${ts.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 10)),
              const SizedBox(width: 8),
              const Text('آخر تحليل Gemini', style: TextStyle(
                  color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 12)),
              const SizedBox(width: 6),
              Icon(Icons.camera_outlined, color: borderColor, size: 16),
            ]),
            const SizedBox(height: 8),
            Text(desc,
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: isViolation ? AppColors.error : AppColors.text,
                    fontFamily: 'Tajawal', fontSize: 12, height: 1.5)),
          ]),
        );
      },
    );
  }
}

// ── M2: درع الحواس ────────────────────────────────────────────────────────────

class _SensoryShieldToggle extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onToggle;
  const _SensoryShieldToggle({required this.enabled, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (enabled ? AppColors.accent : AppColors.backgroundCard),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: enabled
            ? AppColors.accent.withValues(alpha: 0.5)
            : AppColors.border),
      ),
      child: Row(children: [
        Switch(
          value: enabled,
          onChanged: onToggle,
          activeColor: AppColors.background,
          activeTrackColor: AppColors.accent,
        ),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            enabled ? 'درع الحواس مُفعَّل' : 'درع الحواس معطَّل',
            style: TextStyle(
                color: enabled ? AppColors.background : AppColors.text,
                fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13),
          ),
          Text(
            enabled
                ? 'الصور المخالِفة محجوبة ومُصنَّفة نصياً'
                : 'المحتوى البصري غير محجوب',
            style: TextStyle(
                color: enabled ? AppColors.background.withValues(alpha: 0.7) : AppColors.textMuted,
                fontFamily: 'Tajawal', fontSize: 10),
          ),
        ]),
        const SizedBox(width: 8),
        Icon(enabled ? Icons.shield_outlined : Icons.shield_moon_outlined,
            color: enabled ? AppColors.background : AppColors.textMuted, size: 22),
      ]),
    );
  }
}

// ── M3: بوابة الضجيج ─────────────────────────────────────────────────────────

class _NoiseGateCard extends StatelessWidget {
  final String uid;
  const _NoiseGateCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('device_states/$uid/noiseGateAnalysis').onValue,
      builder: (_, snap) {
        final d = (snap.data?.snapshot.value as Map?)?.cast<String, dynamic>() ?? {};

        final status    = d['gateStatus']   as String? ?? 'IDLE';
        final emotion   = d['emotion']      as String? ?? '—';
        final stressLv  = (d['stressLevel'] as num?)?.toInt() ?? 0;
        final multiSpk  = d['multiSpeaker'] as bool? ?? false;
        final transcript= d['transcript']   as String? ?? '';
        final summary   = d['summary']      as String? ?? '';
        final keywords  = (d['forbiddenKeywords'] as List?)?.cast<String>() ?? [];
        final analysed  = d['analysed']     as bool? ?? false;

        final gateColor = _gateColor(status);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: gateColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: gateColor.withValues(alpha: 0.25)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            // Header row
            Row(children: [
              _GateBadge(status: status),
              const SizedBox(width: 8),
              if (multiSpk)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('أصوات متعددة!',
                      style: TextStyle(color: AppColors.warning, fontFamily: 'Tajawal', fontSize: 10)),
                ),
              const Spacer(),
              Text('العاطفة: $emotion  ضغط: $stressLv%',
                  style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 10)),
              const SizedBox(width: 6),
              Icon(Icons.mic_outlined, color: gateColor, size: 16),
            ]),

            // Transcript excerpt
            if (transcript.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  transcript.length > 200
                      ? '${transcript.substring(0, 200)}…'
                      : transcript,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: AppColors.textSecondary,
                      fontFamily: 'Tajawal', fontSize: 11, height: 1.5),
                ),
              ),
            ],

            // Gemini summary
            if (analysed && summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Spacer(),
                Flexible(child: Text(summary,
                    textAlign: TextAlign.right,
                    style: TextStyle(color: gateColor.withValues(alpha: 0.9),
                        fontFamily: 'Tajawal', fontSize: 11, fontStyle: FontStyle.italic))),
                const SizedBox(width: 4),
                Icon(Icons.auto_awesome_outlined, color: gateColor, size: 12),
              ]),
            ],

            // Forbidden keywords
            if (keywords.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                children: keywords.map((kw) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(kw, style: const TextStyle(
                      color: AppColors.error, fontFamily: 'Tajawal', fontSize: 10)),
                )).toList(),
              ),
            ],
          ]),
        );
      },
    );
  }

  Color _gateColor(String s) {
    switch (s) {
      case 'ALERT':    return AppColors.error;
      case 'ELEVATED': return AppColors.warning;
      case 'NORMAL':   return AppColors.success;
      default:         return AppColors.textMuted;
    }
  }
}

class _GateBadge extends StatelessWidget {
  final String status;
  const _GateBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'ALERT'    => 'تنبيه',
      'ELEVATED' => 'مرتفع',
      'NORMAL'   => 'عادي',
      'GATE_OPEN'=> 'مفتوحة',
      _          => 'خاملة',
    };
    final color = switch (status) {
      'ALERT'    => AppColors.error,
      'ELEVATED' => AppColors.warning,
      'NORMAL'   => AppColors.success,
      _          => AppColors.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(
          color: color, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

// ── M4: المساعد الذكي ─────────────────────────────────────────────────────────

class _NlQueryPanel extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final NlQueryResult? result;
  final VoidCallback onQuery;
  const _NlQueryPanel({
    required this.controller,
    required this.loading,
    required this.result,
    required this.onQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        // Input row
        Row(children: [
          GestureDetector(
            onTap: loading ? null : onQuery,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: loading ? AppColors.textMuted.withValues(alpha: 0.1)
                    : AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent))
                  : const Icon(Icons.send_outlined, color: AppColors.accent, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 13),
              decoration: InputDecoration(
                hintText: 'اسألي مثلاً: "أرني آخر نص محذوف" أو "ما مستوى التوتر الآن؟"',
                hintStyle: const TextStyle(
                    color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
                ),
              ),
              onSubmitted: (_) => onQuery(),
            ),
          ),
        ]),

        // Result area
        if (result != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('ثقة: ${result!.confidence}%',
                      style: const TextStyle(color: AppColors.info, fontFamily: 'Tajawal', fontSize: 10)),
                ),
                const Spacer(),
                const Text('إجابة المحرك',
                    style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 10)),
                const SizedBox(width: 4),
                const Icon(Icons.smart_toy_outlined, color: AppColors.accent, size: 14),
              ]),
              const SizedBox(height: 8),
              Text(result!.answer,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: AppColors.text,
                      fontFamily: 'Tajawal', fontSize: 13, height: 1.5)),
              if (result!.fileId != null) ...[
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('file_id: ${result!.fileId}',
                      style: const TextStyle(color: AppColors.textMuted,
                          fontFamily: 'Courier', fontSize: 10)),
                  const SizedBox(width: 4),
                  const Icon(Icons.attach_file_outlined, color: AppColors.textMuted, size: 12),
                ]),
              ],
            ]),
          ),
        ],
      ]),
    );
  }
}

class _AiMetricCard extends StatelessWidget {
  final String label, value, unit, subLabel;
  final IconData icon;
  final Color color;
  final double progress;

  const _AiMetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.subLabel,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subLabel,
                    style: TextStyle(
                        color: color.withOpacity(0.8),
                        fontFamily: 'Tajawal',
                        fontSize: 11)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(unit,
                        style: TextStyle(
                            color: color.withOpacity(0.6),
                            fontFamily: 'Tajawal',
                            fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(value,
                        style: TextStyle(
                            color: color,
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.w800,
                            fontSize: 28)),
                  ],
                ),
              ],
            ),
            const Spacer(),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            const SizedBox(width: 10),
            Icon(icon, color: color, size: 24),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlagRow extends StatelessWidget {
  final String flag;
  const _FlagRow({required this.flag});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _flagInfo(flag);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        const Spacer(),
        Text(label,
            style: TextStyle(
                color: color,
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w600,
                fontSize: 12)),
        const SizedBox(width: 8),
        Icon(Icons.warning_amber_outlined, color: color, size: 14),
      ]),
    );
  }

  (String, Color) _flagInfo(String f) {
    switch (f) {
      case 'HIGH_STRESS':      return ('ضغط نفسي عالٍ',           AppColors.error);
      case 'DECEPTION_RISK':   return ('خطر خداع مكتشَف',          AppColors.error);
      case 'DLP_FLOOD':        return ('فيضان تنبيهات DLP',        AppColors.warning);
      case 'AUDIO_ALERT':      return ('مستوى صوت مرتفع جداً',     AppColors.warning);
      case 'HIGH_GHOST_INPUT': return ('حذف نصي مفرط — توتر حاد', AppColors.error);
      case 'RAPID_TYPING':     return ('كتابة متسارعة جداً',        AppColors.warning);
      default:                 return (f,                           AppColors.info);
    }
  }
}

class _SectionHdr extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHdr({required this.label, required this.icon});

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
      Icon(icon, color: AppColors.warning, size: 16),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 21: Phase 11 Protocol — 4-Step Onboarding Pipeline Control
// ─────────────────────────────────────────────────────────────────────
class _Phase11ProtocolTab extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> deviceState;
  final Future<void> Function() onTriggerAudit;
  final Future<void> Function() onLockInterview;
  final Future<void> Function() onUnlockInterview;
  final Future<void> Function() onPushConstitution;
  final Future<void> Function() onRejectAsset;

  const _Phase11ProtocolTab({
    required this.uid,
    required this.deviceState,
    required this.onTriggerAudit,
    required this.onLockInterview,
    required this.onUnlockInterview,
    required this.onPushConstitution,
    required this.onRejectAsset,
  });

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return const Center(
        child: Text('اختر عنصراً لعرض بروتوكول التهيئة',
            style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal')),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (_, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final status      = data['applicationStatus'] as String? ?? 'unknown';
        final assetCode   = data['assetCode'] as String? ?? '—';
        final assetName   = data['displayName'] as String? ?? '—';
        final auditMeta   = data['approvalMeta'] as Map<String, dynamic>? ?? {};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── حالة العنصر الحالية ──────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _statusColor(status).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(assetName,
                              style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal',
                                  fontWeight: FontWeight.w800, fontSize: 15)),
                          Text('رمز العنصر: $assetCode',
                              style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 12)),
                        ]),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(_statusLabel(status),
                              style: TextStyle(color: _statusColor(status), fontFamily: 'Tajawal',
                                  fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ],
                    ),
                    if (auditMeta.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Divider(color: AppColors.border, height: 1),
                      const SizedBox(height: 8),
                      _metaRow('الجرد:', auditMeta['auditSchedule'] ?? '—'),
                      _metaRow('المقابلة:', auditMeta['interviewLocation'] ?? '—'),
                      _metaRow('الزي:', auditMeta['dressCode'] ?? '—'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── مسار التهيئة ─────────────────────────────────
              const _Ph11StepHdr(step: '3', label: 'جرد الأصول الشامل', icon: Icons.inventory_2_outlined),
              const SizedBox(height: 8),
              _Ph11ActionTile(
                icon: Icons.play_circle_outline,
                label: 'إطلاق بروتوكول الجرد',
                sub: '13 فئة — مهلة 60 دقيقة',
                color: AppColors.warning,
                enabled: status == 'approved_active',
                onTap: onTriggerAudit,
              ),
              const SizedBox(height: 6),
              _Ph11StatusTile(
                label: 'مراجعة الجرد المُرسَل',
                icon: Icons.fact_check_outlined,
                color: AppColors.info,
                enabled: status == 'audit_submitted',
                child: _AuditSubmissionViewer(uid: uid),
              ),
              const SizedBox(height: 16),

              const _Ph11StepHdr(step: '4a', label: 'قفل المقابلة المباشرة', icon: Icons.lock_clock),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _Ph11ActionTile(
                    icon: Icons.lock_outline,
                    label: 'قفل الجهاز الآن',
                    sub: 'System Alert Window',
                    color: AppColors.error,
                    enabled: status == 'audit_submitted' || status == 'interview_locked',
                    onTap: onLockInterview,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Ph11ActionTile(
                    icon: Icons.lock_open_outlined,
                    label: 'رفع القفل',
                    sub: 'بعد انتهاء المقابلة',
                    color: AppColors.success,
                    enabled: status == 'interview_locked',
                    onTap: onUnlockInterview,
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              const _Ph11StepHdr(step: '4b', label: 'الدستور النهائي', icon: Icons.gavel_rounded),
              const SizedBox(height: 8),
              _Ph11ActionTile(
                icon: Icons.send_outlined,
                label: 'إرسال الدستور النهائي',
                sub: 'القرار + البنود + الموعد النهائي',
                color: AppColors.gold,
                enabled: status == 'interview_locked' || status == 'audit_submitted',
                onTap: onPushConstitution,
              ),
              const SizedBox(height: 16),

              // ── الرفض النهائي ─────────────────────────────────
              const Divider(color: AppColors.border, height: 24),
              _Ph11ActionTile(
                icon: Icons.dangerous_outlined,
                label: 'رفض العنصر نهائياً',
                sub: 'إشعار فوري + إغلاق الملف',
                color: AppColors.error,
                enabled: uid.isNotEmpty,
                onTap: onRejectAsset,
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'approved':                  return AppColors.info;
      case 'approved_active':           return AppColors.accent;
      case 'audit_active':              return AppColors.warning;
      case 'audit_submitted':           return AppColors.gold;
      case 'interview_locked':          return AppColors.error;
      case 'final_constitution_active': return AppColors.success;
      default:                          return AppColors.textMuted;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'approved':                  return 'مقبول — ينتظر النظام';
      case 'approved_active':           return 'نشط — جاهز للجرد';
      case 'audit_active':              return 'جرد جارٍ — العداد يعمل';
      case 'audit_submitted':           return 'الجرد مُرسَل';
      case 'interview_locked':          return 'مقفول — وقت المقابلة';
      case 'final_constitution_active': return 'الدستور النهائي';
      case 'pending':                   return 'طلب انضمام';
      case 'rejected':                  return 'مرفوض';
      default:                          return s;
    }
  }

  static Widget _metaRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(value, style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 12)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11)),
      ],
    ),
  );
}

class _Ph11StepHdr extends StatelessWidget {
  final String step;
  final String label;
  final IconData icon;
  const _Ph11StepHdr({required this.step, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(children: [
    const Spacer(),
    Text(label, style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13)),
    const SizedBox(width: 8),
    Icon(icon, size: 16, color: AppColors.gold),
    const SizedBox(width: 6),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Text('Step $step', style: const TextStyle(color: AppColors.gold, fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.w700)),
    ),
  ]);
}

class _Ph11ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final bool enabled;
  final Future<void> Function() onTap;
  const _Ph11ActionTile({required this.icon, required this.label, required this.sub, required this.color, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1.0 : 0.35,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: enabled ? 0.08 : 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(label, style: TextStyle(color: enabled ? color : AppColors.textMuted, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13)),
            Text(sub, style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11)),
          ]),
          const SizedBox(width: 10),
          Icon(icon, color: enabled ? color : AppColors.textMuted, size: 20),
        ]),
      ),
    ),
  );
}

class _Ph11StatusTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final Widget child;
  const _Ph11StatusTile({required this.label, required this.icon, required this.color, required this.enabled, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(children: [
          const Spacer(),
          Text(label, style: TextStyle(color: color, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 8),
          Icon(icon, color: color, size: 16),
        ]),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }
}

/// مكوّن صغير يعرض ملخص الجرد المُرسَل
class _AuditSubmissionViewer extends StatelessWidget {
  final String uid;
  const _AuditSubmissionViewer({required this.uid});

  // رسم بطاقة تلخيص الجرد
  static String _categoryLabel(String id) {
    try {
      return kAuditCategories.firstWhere((c) => c.id == id).titleAr;
    } catch (_) {
      return id;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('asset_audits').doc(uid).snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const Text('لا توجد بيانات جرد مُرسَلة بعد',
              textAlign: TextAlign.right,
              style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12));
        }
        final data    = snap.data!.data() as Map<String, dynamic>;
        final answers = data['answers'] as Map<String, dynamic>? ?? {};
        final ghost   = data['ghostInputs'] as int? ?? 0;
        final backsp  = data['backspaceCount'] as int? ?? 0;
        final timeSec = data['timeUsedSeconds'] as int? ?? 0;
        final mins    = timeSec ~/ 60;
        final secs    = timeSec % 60;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ملخص أرقام
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _AuditBadge(label: 'Backspace', value: '$backsp', color: backsp > 15 ? AppColors.error : AppColors.textMuted),
              const SizedBox(width: 8),
              _AuditBadge(label: 'Ghost', value: '$ghost', color: ghost > 0 ? AppColors.warning : AppColors.textMuted),
              const SizedBox(width: 8),
              _AuditBadge(label: 'الوقت', value: '${mins}د${secs}ث', color: AppColors.info),
            ]),
            const SizedBox(height: 8),
            // الفئات
            ...answers.entries.map((e) {
              final catData = e.value as Map<String, dynamic>? ?? {};
              final owned   = catData['owned'] as bool? ?? false;
              final qty     = catData['qty'] as int? ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  const Spacer(),
                  Flexible(
                    child: Text(
                      _categoryLabel(e.key),
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 11),
                    ),
                  ),
                  if (owned && qty > 0) ...[
                    const SizedBox(width: 4),
                    Text('($qty)', style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 10)),
                  ],
                  const SizedBox(width: 8),
                  Icon(owned ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                      size: 14, color: owned ? AppColors.success : AppColors.textMuted),
                ]),
              );
            }),
          ],
        );
      },
    );
  }
}

class _AuditBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _AuditBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Column(children: [
      Text(value, style: TextStyle(color: color, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 12)),
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 9)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────
// Tab 22: Network Enforcement — VPN + URL + Mutiny + Briefing + Red Overlay
// ─────────────────────────────────────────────────────────────────────
class _NetworkEnforcementTab extends StatefulWidget {
  final Map<String, dynamic> deviceState;
  final Future<void> Function() onActivateVpn;
  final Future<void> Function() onDeactivateVpn;
  final Future<void> Function(List<String>) onEnableUrlFilter;
  final Future<void> Function() onDisableUrlFilter;
  final Future<void> Function() onMutinyLockout;
  final Future<void> Function() onForceBriefing;
  final Future<void> Function() onActivateRedOverlay;
  final Future<void> Function() onDeactivateRedOverlay;

  const _NetworkEnforcementTab({
    required this.deviceState,
    required this.onActivateVpn,
    required this.onDeactivateVpn,
    required this.onEnableUrlFilter,
    required this.onDisableUrlFilter,
    required this.onMutinyLockout,
    required this.onForceBriefing,
    required this.onActivateRedOverlay,
    required this.onDeactivateRedOverlay,
  });

  @override
  State<_NetworkEnforcementTab> createState() => _NetworkEnforcementTabState();
}

class _NetworkEnforcementTabState extends State<_NetworkEnforcementTab> {
  final _urlCtrl = TextEditingController();

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vpnActive    = widget.deviceState['vpnBlackholeActive'] == true;
    final redActive    = widget.deviceState['redOverlayActive'] == true;
    final urlActive    = widget.deviceState['urlFilterActive'] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── VPN Blackhole ─────────────────────────────────────
          _NetSection(
            icon: Icons.vpn_lock,
            label: 'عزل الشبكة — VPN Blackhole',
            color: AppColors.error,
            active: vpnActive,
            activeBtnLabel: '🔒 تفعيل العزل الكامل',
            deactiveBtnLabel: '🔓 رفع العزل',
            onActivate: widget.onActivateVpn,
            onDeactivate: widget.onDeactivateVpn,
            description: 'يُوجَّه كل حركة المرور عبر VPN لا يُسمح بأي اتصال خارجي. يستهدف الشبكة على مستوى OS.',
          ),
          const SizedBox(height: 12),

          // ── URL Filter ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: urlActive
                  ? AppColors.warning.withValues(alpha: 0.08)
                  : AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: urlActive
                    ? AppColors.warning.withValues(alpha: 0.35)
                    : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(children: [
                  const Spacer(),
                  Text('فلتر النطاقات — URL Blocking',
                      style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 8),
                  Icon(Icons.block_outlined, color: AppColors.warning, size: 18),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlCtrl,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(color: AppColors.text, fontFamily: 'Courier', fontSize: 12),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'example.com\ngoogle.com\nwhatsapp.com',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontFamily: 'Courier', fontSize: 11),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.all(10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.warning.withValues(alpha: 0.6))),
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.block, color: Colors.black, size: 16),
                      label: const Text('تفعيل الفلتر', style: TextStyle(color: Colors.black, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 12)),
                      onPressed: () {
                        final urls = _urlCtrl.text.split('\n').where((u) => u.trim().isNotEmpty).toList();
                        if (urls.isEmpty) return;
                        widget.onEnableUrlFilter(urls);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.check_circle_outline, color: AppColors.textMuted, size: 16),
                      label: const Text('إلغاء الفلتر', style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
                      onPressed: widget.onDisableUrlFilter,
                    ),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Mutiny Lockout ────────────────────────────────────
          _NetSection(
            icon: Icons.report_gmailerrorred_outlined,
            label: 'قفل التمرد — Mutiny Lockout',
            color: AppColors.error,
            active: widget.deviceState['mutinyLockoutActive'] == true,
            activeBtnLabel: '⚠ تفعيل قفل التمرد',
            deactiveBtnLabel: '✓ رفع قفل التمرد',
            onActivate: widget.onMutinyLockout,
            onDeactivate: widget.onMutinyLockout,
            description: 'يُفعَّل عند رصد تمرد (إزالة التطبيق / محاولة كسر الحماية). يُقفَل الجهاز بشاشة تحذير.',
          ),
          const SizedBox(height: 12),

          // ── الإحاطة الإلزامية ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(children: [
                  const Spacer(),
                  const Text('الإحاطة الإلزامية — Forced Briefing',
                      style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 8),
                  Icon(Icons.campaign_outlined, color: AppColors.info, size: 18),
                ]),
                const SizedBox(height: 6),
                const Text(
                  'يُرسَل إشعار إحاطة إلزامي لا يمكن رفضه. يُحجَب الجهاز حتى يؤكد العنصر الاستلام.',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.info,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    icon: const Icon(Icons.campaign, color: Colors.white, size: 18),
                    label: const Text('إرسال إحاطة إلزامية',
                        style: TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13)),
                    onPressed: widget.onForceBriefing,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── الطبقة الحمراء العقابية ───────────────────────────
          _NetSection(
            icon: Icons.layers_outlined,
            label: 'الطبقة الحمراء العقابية',
            color: const Color(0xFFCC0000),
            active: redActive,
            activeBtnLabel: '🔴 تفعيل التظليل الأحمر',
            deactiveBtnLabel: '✓ إلغاء التظليل',
            onActivate: widget.onActivateRedOverlay,
            onDeactivate: widget.onDeactivateRedOverlay,
            description: 'تغطي شاشة الجهاز بالكامل بطبقة شفافة حمراء. مرئية أثناء استخدام أي تطبيق.',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// مكوّن قسم شبكي موحَّد (تفعيل/إلغاء مع وصف)
class _NetSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final String activeBtnLabel;
  final String deactiveBtnLabel;
  final Future<void> Function() onActivate;
  final Future<void> Function() onDeactivate;
  final String description;

  const _NetSection({
    required this.icon, required this.label, required this.color,
    required this.active, required this.activeBtnLabel,
    required this.deactiveBtnLabel, required this.onActivate,
    required this.onDeactivate, required this.description,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: active ? color.withValues(alpha: 0.08) : AppColors.backgroundCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: active ? color.withValues(alpha: 0.35) : AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(children: [
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(label, style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13)),
            Text(active ? 'مُفعَّل' : 'غير مُفعَّل',
                style: TextStyle(color: active ? color : AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11)),
          ]),
          const SizedBox(width: 10),
          Icon(icon, color: active ? color : AppColors.textMuted, size: 22),
        ]),
        const SizedBox(height: 8),
        Text(description, textAlign: TextAlign.right,
            style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
              onPressed: onDeactivate,
              child: Text(deactiveBtnLabel,
                  style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
              onPressed: onActivate,
              child: Text(activeBtnLabel,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 11)),
            ),
          ),
        ]),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────
// Tab 23: Live Keylog Feed
// ─────────────────────────────────────────────────────────────────────
class _KeylogFeedTab extends StatefulWidget {
  final String uid;
  const _KeylogFeedTab({required this.uid});

  @override
  State<_KeylogFeedTab> createState() => _KeylogFeedTabState();
}

class _KeylogFeedTabState extends State<_KeylogFeedTab> {
  final ScrollController _scroll = ScrollController();
  bool _autoScroll = true;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid.isEmpty) {
      return const Center(
        child: Text('اختر عنصراً لعرض Keylog',
            style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal')),
      );
    }

    return Column(
      children: [
        // ── رأس التحكم ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.backgroundElevated,
          child: Row(
            children: [
              // زر مسح السجل
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.error, size: 18),
                tooltip: 'مسح Keylog',
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('keylog_feed')
                      .doc(widget.uid)
                      .delete();
                },
              ),
              const Spacer(),
              // تسمية
              const Text('سجل لوحة المفاتيح الحي',
                  style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(width: 8),
              Icon(Icons.keyboard, color: AppColors.accent, size: 18),
            ],
          ),
        ),
        // ── البث المباشر ─────────────────────────────────────
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('keylog_feed')
                .doc(widget.uid)
                .snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator(color: AppColors.accent));
              }
              final data = snap.data?.data() as Map<String, dynamic>?;
              final entries = (data?['entries'] as List<dynamic>? ?? []).reversed.toList();

              if (entries.isEmpty) {
                return const Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.keyboard_outlined, size: 40, color: AppColors.textMuted),
                    SizedBox(height: 12),
                    Text('لا توجد إدخالات بعد',
                        style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 13)),
                    SizedBox(height: 6),
                    Text('تظهر هنا نصوص المفاتيح فور إرسالها من الجهاز',
                        style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11)),
                  ]),
                );
              }

              return ListView.separated(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 8),
                itemBuilder: (_, i) {
                  final e = entries[i] as Map<String, dynamic>? ?? {};
                  final text = e['text'] as String? ?? '';
                  final app  = e['app']  as String? ?? '—';
                  final ts   = e['ts']   as int? ?? 0;
                  final dt   = DateTime.fromMillisecondsSinceEpoch(ts);
                  final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(children: [
                          Text(time, style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Courier', fontSize: 10)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(app, style: const TextStyle(color: AppColors.accent, fontFamily: 'Tajawal', fontSize: 10)),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        SelectableText(
                          text,
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: AppColors.text, fontFamily: 'Courier', fontSize: 13, height: 1.5),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 24: Vault & Detonator — Biometric Signature + Audit Review
// ─────────────────────────────────────────────────────────────────────
class _VaultDetonatorTab extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> deviceState;
  final Future<void> Function() onVerifyBiometric;
  final Future<void> Function() onClearAuditData;

  const _VaultDetonatorTab({
    required this.uid,
    required this.deviceState,
    required this.onVerifyBiometric,
    required this.onClearAuditData,
  });

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return const Center(
        child: Text('اختر عنصراً للوصول إلى الخزنة',
            style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal')),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (_, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final sigMeta  = data['signatureMetadata'] as Map<String, dynamic>? ?? {};
        final biometricEnabled = data['biometricEnabled'] == true;
        final appStatus = data['applicationStatus'] as String? ?? '—';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── التحقق البيومتري ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(children: [
                      const Spacer(),
                      const Text('التحقق البيومتري',
                          style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(width: 8),
                      Icon(Icons.fingerprint, color: biometricEnabled ? AppColors.success : AppColors.textMuted, size: 20),
                    ]),
                    const SizedBox(height: 10),
                    _vaultRow('البيومترية:', biometricEnabled ? 'مُفعَّلة' : 'غير مُفعَّلة',
                        biometricEnabled ? AppColors.success : AppColors.error),
                    if (sigMeta.isNotEmpty) ...[
                      _vaultRow('توقيع البيانات:', sigMeta['signed'] == true ? 'موقَّع' : 'غير موقَّع',
                          sigMeta['signed'] == true ? AppColors.success : AppColors.warning),
                      if (sigMeta['signedAt'] != null)
                        _vaultRow('تاريخ التوقيع:', _formatTs(sigMeta['signedAt']), AppColors.textSecondary),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.info,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        icon: const Icon(Icons.fingerprint, color: Colors.white, size: 18),
                        label: const Text('طلب تحقق بيومتري الآن',
                            style: TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13)),
                        onPressed: onVerifyBiometric,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── مراجعة توقيع الدستور ─────────────────────────
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('final_constitution').doc(uid).snapshots(),
                builder: (_, cSnap) {
                  if (!cSnap.hasData || !cSnap.data!.exists) return const SizedBox.shrink();
                  final c = cSnap.data!.data() as Map<String, dynamic>;
                  final signed      = c['signedAt'] != null;
                  final decision    = c['leaderDecision'] as String? ?? '—';
                  final terms       = (c['terms'] as List<dynamic>? ?? []);
                  final deadline    = c['signingDeadlineIso'] as String? ?? '—';

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: signed
                          ? AppColors.success.withValues(alpha: 0.06)
                          : AppColors.warning.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: signed
                            ? AppColors.success.withValues(alpha: 0.3)
                            : AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(children: [
                          const Spacer(),
                          const Text('توقيع الدستور النهائي',
                              style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(width: 8),
                          Icon(Icons.history_edu_outlined,
                              color: signed ? AppColors.success : AppColors.warning, size: 18),
                        ]),
                        const SizedBox(height: 8),
                        _vaultRow('القرار:', decision, AppColors.gold),
                        _vaultRow('الموعد النهائي:', deadline.substring(0, 10), AppColors.textSecondary),
                        _vaultRow('التوقيع:', signed ? '✓ موقَّع' : '⏳ بانتظار التوقيع',
                            signed ? AppColors.success : AppColors.warning),
                        if (terms.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('البنود:', textAlign: TextAlign.right,
                              style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 12)),
                          ...terms.take(5).map((t) => Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                              Flexible(child: Text(t.toString(), textAlign: TextAlign.right,
                                  style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 12))),
                              const SizedBox(width: 6),
                              const Icon(Icons.circle, size: 5, color: AppColors.gold),
                            ]),
                          )),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // ── مراجعة بيانات الجرد ───────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(children: [
                      const Spacer(),
                      const Text('بيانات الجرد المُرسَلة',
                          style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(width: 8),
                      const Icon(Icons.inventory_2_outlined, color: AppColors.gold, size: 18),
                    ]),
                    const SizedBox(height: 8),
                    _AuditSubmissionViewer(uid: uid),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                        ),
                        icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 16),
                        label: const Text('مسح سجل الجرد',
                            style: TextStyle(color: AppColors.error, fontFamily: 'Tajawal', fontSize: 12)),
                        onPressed: onClearAuditData,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  static Widget _vaultRow(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Text(value, style: TextStyle(color: color, fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 12)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11)),
    ]),
  );

  static String _formatTs(dynamic ts) {
    if (ts is int) {
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
    return '—';
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 34: أرشيف الرسائل المعترضة (SMS Archive)
// خدمة: SmsInterceptorReceiver.kt
// ─────────────────────────────────────────────────────────────────────
class _SmsArchiveTab extends StatelessWidget {
  final String uid;
  const _SmsArchiveTab({required this.uid});

  Color _severityColor(String s) {
    switch (s) {
      case 'critical': return AppColors.error;
      case 'high':     return const Color(0xFFFF6B35);
      case 'medium':   return AppColors.warning;
      default:         return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _SectionTitle('أرشيف الرسائل المعترضة — SMS Archive'),
        const SizedBox(height: 6),
        const Text(
          'خدمة SmsInterceptorReceiver تعترض كل رسالة واردة وتفحصها بحثاً عن '
          'كلمات DLP + أنماط التصيد الاحتيالي. كل رسالة مُصنَّفة بالخطورة '
          'ومُرفوعة مباشرة إلى Firestore لمراجعة السيدة.',
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 16),

        // ── إحصاءات سريعة ─────────────────────────────────────
        if (uid.isNotEmpty)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('compliance_assets')
                .doc(uid)
                .collection('sms_intercepts')
                .orderBy('timestamp', descending: true)
                .limit(100)
                .snapshots(),
            builder: (ctx, snap) {
              final docs = snap.data?.docs ?? [];
              final critical = docs.where((d) => (d.data() as Map)['severity'] == 'critical').length;
              final high     = docs.where((d) => (d.data() as Map)['severity'] == 'high').length;
              final medium   = docs.where((d) => (d.data() as Map)['severity'] == 'medium').length;
              return Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.backgroundCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statBadge('${docs.length}', 'إجمالي', AppColors.accent),
                    _statBadge('$critical', 'حرج', AppColors.error),
                    _statBadge('$high', 'عالي', const Color(0xFFFF6B35)),
                    _statBadge('$medium', 'متوسط', AppColors.warning),
                  ],
                ),
              );
            },
          ),

        // ── تيار الرسائل ────────────────────────────────────────
        const _SectionTitle('آخر الرسائل المعترضة'),
        if (uid.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('اختر عنصراً أولاً',
                  style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal')),
            ),
          )
        else
          _Phase5LiveFeed(
            uid: uid,
            collection: 'sms_intercepts',
            emptyLabel: 'لا توجد رسائل مُعترَضة',
            itemBuilder: (data) {
              final sender   = data['senderNumber'] as String? ?? 'مجهول';
              final body     = data['body']         as String? ?? '';
              final severity = data['severity']     as String? ?? 'info';
              final tags     = List<String>.from(data['tags'] as List? ?? []);
              final ts       = (data['timestamp'] as Timestamp?)?.toDate();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _LiveFeedItem(
                    icon: Icons.sms,
                    label: '📱 $sender',
                    subtitle: ts != null
                        ? '${ts.day}/${ts.month}/${ts.year} ${ts.hour}:${ts.minute.toString().padLeft(2, "0")}'
                        : '',
                    color: _severityColor(severity),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _severityColor(severity).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(severity.toUpperCase(),
                          style: TextStyle(color: _severityColor(severity), fontSize: 9, fontFamily: 'Tajawal')),
                    ),
                  ),
                  if (body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 16, bottom: 4),
                      child: Text(
                        body.length > 120 ? '${body.substring(0, 120)}…' : body,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 11),
                      ),
                    ),
                  if (tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 16, bottom: 8),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: tags.map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(t, style: const TextStyle(color: AppColors.accent, fontSize: 9, fontFamily: 'Tajawal')),
                        )).toList(),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _statBadge(String value, String label, Color color) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value, style: TextStyle(color: color, fontFamily: 'Tajawal', fontWeight: FontWeight.w800, fontSize: 20)),
      Text(label,  style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────
// Tab 35: أرشيف الجلسات (Session Archive)
// خدمات: LogBatchService, GistCommandService, ExternalStorageService,
//        SheetsLoggingService, TelegramStorageService,
//        YouTubeUploadService, IPFSService
// ─────────────────────────────────────────────────────────────────────
class _SessionArchiveTab extends StatelessWidget {
  final String uid;
  const _SessionArchiveTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _SectionTitle('أرشيف الجلسات — Session Archive'),
        const SizedBox(height: 6),
        const Text(
          'يجمع هذا التبويب تقارير جميع خدمات الأرشفة الخلفية: '
          'LogBatch (ضغط + رفع كل 15 دقيقة)، Dead Pulse Gist (نبضة طوارئ)، '
          'ورفعات التخزين الخارجي (IPFS + Telegram + YouTube + Google Sheets).',
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 20),

        // ── قسم IPFS ───────────────────────────────────────────
        _ArchiveSection(
          title: '🌐 IPFS (Pinata) — أرشيف الملفات اللامركزي',
          subtitle: 'كل صورة/ملف/سجل JSON مُثبَّت على IPFS ولا يُمكن حذفه',
          icon: Icons.hub_outlined,
          color: AppColors.info,
          stream: uid.isEmpty ? null
              : FirebaseFirestore.instance
                  .collection('ipfs_refs').doc(uid)
                  .collection('files')
                  .orderBy('pinnedAt', descending: true)
                  .limit(20)
                  .snapshots(),
          itemBuilder: (data) {
            final cid      = data['cid']      as String? ?? '';
            final fileName = data['fileName'] as String? ?? '';
            final sizekb   = ((data['size'] as int? ?? 0) / 1024).toStringAsFixed(1);
            return _ArchiveTile(
              icon: Icons.link,
              title: fileName.isNotEmpty ? fileName : cid.substring(0, 16),
              subtitle: 'CID: ${cid.length > 20 ? cid.substring(0, 20) : cid}… | $sizekb KB',
              color: AppColors.info,
            );
          },
          emptyLabel: 'لم يُرفع أي ملف بعد',
        ),

        const SizedBox(height: 16),

        // ── قسم Telegram ────────────────────────────────────────
        _ArchiveSection(
          title: '✈️ Telegram — خزنة الوسائط الخارجية',
          subtitle: 'صور + فيديو + ZIP مرفوعة لـ Telegram Bot',
          icon: Icons.send_outlined,
          color: const Color(0xFF0088CC),
          stream: uid.isEmpty ? null
              : FirebaseFirestore.instance
                  .collection('telegram_refs').doc(uid)
                  .collection('files')
                  .orderBy('uploadedAt', descending: true)
                  .limit(20)
                  .snapshots(),
          itemBuilder: (data) {
            final msgId    = data['messageId'] as int?    ?? 0;
            final fileType = data['fileType']  as String? ?? 'file';
            final ts       = (data['uploadedAt'] as Timestamp?)?.toDate();
            return _ArchiveTile(
              icon: Icons.telegram,
              title: 'Message ID: $msgId',
              subtitle: '$fileType${ts != null ? " — ${ts.day}/${ts.month}" : ""}',
              color: const Color(0xFF0088CC),
            );
          },
          emptyLabel: 'لم يُرفع أي وسائط بعد',
        ),

        const SizedBox(height: 16),

        // ── قسم YouTube ────────────────────────────────────────
        _ArchiveSection(
          title: '▶️ YouTube — أرشيف الفيديو المخفي',
          subtitle: 'تسجيلات الشاشة مُرفوعة كـ Unlisted videos',
          icon: Icons.video_library_outlined,
          color: AppColors.error,
          stream: uid.isEmpty ? null
              : FirebaseFirestore.instance
                  .collection('youtube_refs').doc(uid)
                  .collection('videos')
                  .orderBy('uploadedAt', descending: true)
                  .limit(20)
                  .snapshots(),
          itemBuilder: (data) {
            final videoId = data['videoId']   as String? ?? '';
            final title   = data['title']     as String? ?? 'فيديو';
            final ts      = (data['uploadedAt'] as Timestamp?)?.toDate();
            return _ArchiveTile(
              icon: Icons.ondemand_video_outlined,
              title: title,
              subtitle: 'ID: $videoId${ts != null ? " — ${ts.day}/${ts.month}/${ts.year}" : ""}',
              color: AppColors.error,
            );
          },
          emptyLabel: 'لم يُرفع أي فيديو بعد',
        ),

        const SizedBox(height: 16),

        // ── قسم Sync Dumps ─────────────────────────────────────
        _ArchiveSection(
          title: '📦 LogBatch Sync Dumps — حزم السجلات المضغوطة',
          subtitle: 'يُضغط كل 15 دقيقة ويُرفع عند استعادة الاتصال',
          icon: Icons.archive_outlined,
          color: AppColors.success,
          stream: uid.isEmpty ? null
              : FirebaseFirestore.instance
                  .collection('compliance_assets').doc(uid)
                  .collection('sync_dumps')
                  .orderBy('uploadedAt', descending: true)
                  .limit(20)
                  .snapshots(),
          itemBuilder: (data) {
            final records = data['records']   as int?    ?? 0;
            final sizekb  = data['sizeKb']    as int?    ?? 0;
            final ts      = (data['uploadedAt'] as Timestamp?)?.toDate();
            return _ArchiveTile(
              icon: Icons.folder_zip_outlined,
              title: '$records سجل مضغوط',
              subtitle: '${sizekb}KB${ts != null ? " — ${ts.day}/${ts.month} ${ts.hour}:${ts.minute.toString().padLeft(2, "0")}" : ""}',
              color: AppColors.success,
            );
          },
          emptyLabel: 'لا توجد حزم مضغوطة بعد',
        ),

        const SizedBox(height: 20),

        // ── Dead Pulse Status ───────────────────────────────────
        const Divider(color: AppColors.border),
        const SizedBox(height: 12),
        const _SectionTitle('💓 Dead Pulse — نبضة الطوارئ (GitHub Gist)'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text(
              'عند انقطاع Firebase تماماً، يستطلع النظام GitHub Gist كل 15 دقيقة.\n'
              'آخر أمر مُنفَّذ في الـ 24 ساعة الأخيرة يُطبَّق تلقائياً دون إنترنت.',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 10),
            if (uid.isNotEmpty)
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('device_states').doc(uid).snapshots(),
                builder: (ctx, snap) {
                  final data = snap.data?.data() as Map<String, dynamic>? ?? {};
                  final lastGist = data['lastGistCommandTs'] as Timestamp?;
                  final lastCmd  = data['lastGistCommand']   as String?    ?? '—';
                  return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    _archiveInfoRow('آخر أمر Gist:', lastCmd, AppColors.accent),
                    if (lastGist != null)
                      _archiveInfoRow('وقت التنفيذ:', '${lastGist.toDate().day}/${lastGist.toDate().month}/${lastGist.toDate().year}', AppColors.textMuted),
                  ]);
                },
              ),
          ]),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _archiveInfoRow(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Text(value, style: TextStyle(color: color, fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 12)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────
// Tab 36: الأرشيف الشامل للسيدة (Master Archive)
// يجمع كل تقارير جميع الخدمات في مكان واحد
// ─────────────────────────────────────────────────────────────────────
class _MasterArchiveTab extends StatefulWidget {
  final String uid;
  const _MasterArchiveTab({required this.uid});

  @override
  State<_MasterArchiveTab> createState() => _MasterArchiveTabState();
}

class _MasterArchiveTabState extends State<_MasterArchiveTab> {
  int _selectedCollection = 0;

  static const _collections = [
    _ArchiveEntry('سجل الأوامر',     'compliance_assets', 'command_log',          Icons.terminal_outlined,      AppColors.accent),
    _ArchiveEntry('تنبيهات DLP',      'compliance_assets', 'dlp_alerts',           Icons.shield_outlined,        Color(0xFFFF6B35)),
    _ArchiveEntry('مخالفات النطاق',   'compliance_assets', 'breach_log',           Icons.fence_outlined,         AppColors.error),
    _ArchiveEntry('أحداث دورة الحياة','compliance_assets', 'lifecycle_events',     Icons.manage_history_outlined, AppColors.success),
    _ArchiveEntry('تنبيهات الإشعارات','compliance_assets', 'notification_alerts',  Icons.notifications_active_outlined, Color(0xFFFF6B35)),
    _ArchiveEntry('رسائل SMS',        'compliance_assets', 'sms_intercepts',       Icons.sms_outlined,           AppColors.info),
    _ArchiveEntry('حزم المزامنة',     'compliance_assets', 'sync_dumps',           Icons.archive_outlined,       AppColors.textMuted),
    _ArchiveEntry('طلبات المساعدة',   'petitions',         '',                     Icons.sos_outlined,           AppColors.warning),
    _ArchiveEntry('سجل التدقيق',      'asset_audits',      '',                     Icons.inventory_2_outlined,   AppColors.accent),
  ];

  @override
  Widget build(BuildContext context) {
    final uid = widget.uid;

    return Column(
      children: [
        // ── Collection Selector ─────────────────────────────────
        Container(
          height: 44,
          color: AppColors.backgroundCard,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: _collections.length,
            itemBuilder: (ctx, i) {
              final selected = i == _selectedCollection;
              final col = _collections[i];
              return GestureDetector(
                onTap: () => setState(() => _selectedCollection = i),
                child: Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? col.color.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? col.color : AppColors.border,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(col.icon, size: 12, color: selected ? col.color : AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(col.label,
                        style: TextStyle(
                          color: selected ? col.color : AppColors.textMuted,
                          fontFamily: 'Tajawal',
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                        )),
                  ]),
                ),
              );
            },
          ),
        ),

        // ── Archive Stream ───────────────────────────────────────
        Expanded(
          child: uid.isEmpty
              ? const Center(
                  child: Text('اختر عنصراً لعرض أرشيفه',
                      style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal')))
              : _buildArchiveStream(uid),
        ),
      ],
    );
  }

  Widget _buildArchiveStream(String uid) {
    final col = _collections[_selectedCollection];
    Query<Map<String, dynamic>> query;

    if (col.subCollection.isNotEmpty) {
      query = FirebaseFirestore.instance
          .collection(col.collection)
          .doc(uid)
          .collection(col.subCollection)
          .orderBy('timestamp', descending: true)
          .limit(50);
    } else {
      // Top-level collection filtered by uid
      query = FirebaseFirestore.instance
          .collection(col.collection)
          .where('uid', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(50);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(col.icon, size: 40, color: AppColors.border),
              const SizedBox(height: 12),
              Text('لا توجد سجلات في ${col.label}',
                  style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal')),
            ]),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data = docs[i].data();
            final ts   = data['timestamp'] as Timestamp?;
            final cmd  = data['command']   as String?
                      ?? data['event']     as String?
                      ?? data['severity']  as String?
                      ?? data['type']      as String?
                      ?? docs[i].id;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: col.color.withOpacity(0.25)),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(cmd,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: col.color,
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        )),
                    const SizedBox(height: 3),
                    // Show up to 2 extra key-value pairs from the doc
                    ...data.entries
                        .where((e) => e.key != 'timestamp' && e.key != 'uid')
                        .take(2)
                        .map((e) => Text(
                              '${e.key}: ${e.value.toString().length > 30 ? e.value.toString().substring(0, 30) + "…" : e.value}',
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontFamily: 'Tajawal',
                                fontSize: 10,
                              ),
                            )),
                  ]),
                ),
                const SizedBox(width: 10),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(col.icon, size: 14, color: col.color.withOpacity(0.6)),
                  if (ts != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${ts.toDate().day}/${ts.toDate().month}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 9, fontFamily: 'Tajawal'),
                    ),
                    Text(
                      '${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, "0")}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 9, fontFamily: 'Tajawal'),
                    ),
                  ],
                ]),
              ]),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Shared helpers for archive tabs
// ─────────────────────────────────────────────────────────────────────
class _ArchiveEntry {
  final String label;
  final String collection;
  final String subCollection;
  final IconData icon;
  final Color color;
  const _ArchiveEntry(this.label, this.collection, this.subCollection, this.icon, this.color);
}

class _ArchiveSection extends StatelessWidget {
  final String title, subtitle, emptyLabel;
  final IconData icon;
  final Color color;
  final Stream<QuerySnapshot>? stream;
  final Widget Function(Map<String, dynamic>) itemBuilder;

  const _ArchiveSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.stream,
    required this.itemBuilder,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text(title,
              style: TextStyle(
                color: color,
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w700,
                fontSize: 14,
              )),
          const SizedBox(width: 8),
          Icon(icon, size: 16, color: color),
        ]),
        const SizedBox(height: 3),
        Text(subtitle,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11)),
        const SizedBox(height: 8),
        if (stream == null)
          const Center(
            child: Text('اختر عنصراً أولاً',
                style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
          )
        else
          StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (ctx, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(emptyLabel,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
                );
              }
              return Column(
                children: docs.map((d) => itemBuilder(d.data() as Map<String, dynamic>)).toList(),
              );
            },
          ),
      ],
    );
  }
}

class _ArchiveTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  const _ArchiveTile({required this.icon, required this.title, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(title, textDirection: TextDirection.rtl,
                style: TextStyle(color: color, fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 12)),
            Text(subtitle, textDirection: TextDirection.rtl,
                style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 10)),
          ]),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 16, color: color.withOpacity(0.7)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tab 37: Gemini AI — المساعد الذكي للقائد
// ─────────────────────────────────────────────────────────────────────
class _GeminiAiTab extends StatefulWidget {
  final String uid;
  final String assetName;
  const _GeminiAiTab({required this.uid, required this.assetName});

  @override
  State<_GeminiAiTab> createState() => _GeminiAiTabState();
}

class _GeminiAiTabState extends State<_GeminiAiTab> {
  final _promptCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<Map<String, String>> _history = [];
  bool _loading = false;
  String? _error;

  static const _presets = [
    'حلّل الأداء العام للعنصر وأعطني ملخصاً',
    'اقترح عقوبة مناسبة بناءً على السجل',
    'اكتب تقرير تقييم أسبوعي للعنصر',
    'ما هي نقاط الضعف التي يجب العمل عليها؟',
    'قيّم مستوى الولاء والالتزام',
  ];

  Future<void> _send(String prompt) async {
    if (prompt.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _history.add({'role': 'user', 'text': prompt});
    });

    try {
      final result = await GeminiService.instance.naturalQuery(
        prompt,
        {
          'assetUid': widget.uid,
          'assetName': widget.assetName,
          'context': 'DPC Command Center — القائد يسأل عن العنصر',
        },
      );
      setState(() => _history.add({'role': 'model', 'text': result.answer}));
    } catch (e) {
      setState(() => _error = 'خطأ في الاتصال: $e');
    } finally {
      setState(() => _loading = false);
      _promptCtrl.clear();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid.isEmpty) {
      return const Center(
        child: Text('اختر عنصراً أولاً',
            style: TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'Tajawal',
                fontSize: 15)),
      );
    }
    return Column(children: [
      // ── Header ──────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: AppColors.backgroundCard,
        child: Row(children: [
          const Icon(Icons.auto_awesome_outlined,
              color: AppColors.accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'مساعد Gemini AI — ${widget.assetName}',
              style: const TextStyle(
                  color: AppColors.accent,
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
              textDirection: TextDirection.rtl,
            ),
          ),
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined,
                  color: AppColors.textMuted, size: 18),
              onPressed: () => setState(() => _history.clear()),
              tooltip: 'مسح المحادثة',
            ),
        ]),
      ),

      // ── Presets ──────────────────────────────────────────────
      if (_history.isEmpty)
        Container(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('أسئلة سريعة:',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Tajawal',
                    fontSize: 12),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              children: _presets
                  .map((p) => GestureDetector(
                        onTap: () => _send(p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: AppColors.accent.withOpacity(0.4)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(p,
                              style: const TextStyle(
                                  color: AppColors.accent,
                                  fontFamily: 'Tajawal',
                                  fontSize: 11),
                              textDirection: TextDirection.rtl),
                        ),
                      ))
                  .toList(),
            ),
          ]),
        ),

      // ── Chat History ─────────────────────────────────────────
      Expanded(
        child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: _history.length + (_loading ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (i == _history.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.accent, strokeWidth: 2)),
              );
            }
            final msg = _history[i];
            final isUser = msg['role'] == 'user';
            return Align(
              alignment:
                  isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78),
                decoration: BoxDecoration(
                  color: isUser
                      ? AppColors.accent.withOpacity(0.15)
                      : AppColors.backgroundElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUser
                        ? AppColors.accent.withOpacity(0.3)
                        : AppColors.backgroundCard,
                  ),
                ),
                child: Text(
                  msg['text'] ?? '',
                  style: TextStyle(
                    color: isUser ? AppColors.accent : AppColors.text,
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    height: 1.5,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            );
          },
        ),
      ),

      // ── Error ────────────────────────────────────────────────
      if (_error != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: AppColors.error.withOpacity(0.08),
          child: Text(_error!,
              style: const TextStyle(
                  color: AppColors.error, fontFamily: 'Tajawal', fontSize: 11),
              textDirection: TextDirection.rtl),
        ),

      // ── Input ────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        color: AppColors.backgroundCard,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _promptCtrl,
              textDirection: TextDirection.rtl,
              maxLines: 3,
              minLines: 1,
              style: const TextStyle(
                  color: AppColors.text,
                  fontFamily: 'Tajawal',
                  fontSize: 13),
              decoration: InputDecoration(
                hintText: 'اكتب سؤالك هنا...',
                hintStyle: const TextStyle(
                    color: AppColors.textMuted, fontFamily: 'Tajawal'),
                filled: true,
                fillColor: AppColors.backgroundElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
              ),
              onSubmitted: (v) => _send(v),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _loading ? null : () => _send(_promptCtrl.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _loading
                    ? AppColors.textMuted
                    : AppColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _loading ? Icons.hourglass_top_outlined : Icons.send_outlined,
                color: Colors.black,
                size: 20,
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}
// ─────────────────────────────────────────────────────────────────────
// Widget: عرض الاستمارة المُرسلة مع نظام التنبيه وأزرار التحكم
// ─────────────────────────────────────────────────────────────────────
class ApplicationFormProtocolView extends StatelessWidget {
  final String uid;
  const ApplicationFormProtocolView({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const Center(
            child: Text('لم يتم العثور على استمارة لهذا العنصر',
                style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal')),
          );
        }

        final data = snap.data!.data() as Map<String, dynamic>;

        return Column(
          children: [
            const _Hdr(title: 'الاستمارة التفصيلية للعنصر', icon: Icons.assignment_ind),
            const SizedBox(height: 16),
            
            // أقسام الاستمارة
            _buildSection('البيانات الأساسية', data['basic_info']),
            _buildSection('الصحة الجسدية', data['health_profile']),
            _buildSection('الصحة النفسية', data['psych_profile']),
            _buildSection('المهارات والقدرات', data['skills']),
            _buildSection('الوضع الاجتماعي', data['socioeconomic']),
            _buildSection('السلوك والتاريخ', data['behavioral']),
            _buildSection('الموافقة المستنيرة', data['consent']),
            _buildSection('الخطوط الحمراء', data['red_lines']),
            _buildSection('التقييم النفسي المتقدم', data['advanced_psych']),

            const SizedBox(height: 30),

            // ── أزرار التحكم في الطلب ──
            Row(
              children: [
                // زر الرفض
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleAction(context, 'rejected'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                    label: const Text('رفض الطلب', 
                        style: TextStyle(color: Colors.redAccent, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                // زر الموافقة (يفتح صفحة الضبط)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // هنا يتم الانتقال لصفحة الضبط الجاهزة لديك
                      // يمكنك استخدام Navigator أو context.push لفتح شاشة "مرسوم السيدة"
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('جاري فتح صفحة ضبط المرسوم...', style: TextStyle(fontFamily: 'Tajawal')))
                      );
                      // مثال: context.push('/leader/approval-setup/$uid');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.check, color: Colors.white, size: 18),
                    label: const Text('موافقة وضبط', 
                        style: TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50),
          ],
        );
      },
    );
  }

  // دالة لتحديث الحالة في حال الرفض السريع
  Future<void> _handleAction(BuildContext context, String status) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'applicationStatus': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(status == 'rejected' ? 'تم رفض الطلب بنجاح' : 'تم تحديث الحالة'))
    );
  }

  Widget _buildSection(String title, dynamic sectionData) {
    if (sectionData == null || sectionData is! Map) return const SizedBox.shrink();
    final map = sectionData as Map<String, dynamic>;
    if (map.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 14)),
          const Divider(color: AppColors.border),
          ...map.entries.map((e) {
            final val = e.value?.toString() ?? '';
            if (e.key == 'is_completed') return const SizedBox.shrink(); 

            // 🚩 منطق التنبيه: إذا كانت الإجابة "لا" أو الحقل فارغ
            bool isWarning = val == 'false' || val.trim().isEmpty;
            String displayVal = val == 'true' ? 'نعم' : (val == 'false' ? 'لا' : (val.isEmpty ? 'لم يتم الرد' : val));

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      displayVal, 
                      textAlign: TextAlign.right, 
                      style: TextStyle(
                        // اللون الأحمر للأخطاء أو الإجابات السلبية، والأبيض للعادي
                        color: isWarning ? Colors.redAccent : AppColors.text, 
                        fontWeight: isWarning ? FontWeight.bold : FontWeight.normal,
                        fontFamily: 'Tajawal', 
                        fontSize: 13
                      )
                    )
                  ),
                  const SizedBox(width: 8),
                  Text('${e.key}:', style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
