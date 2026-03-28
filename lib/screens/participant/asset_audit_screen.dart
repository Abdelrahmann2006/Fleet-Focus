import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/asset_audit_model.dart';
import '../../models/approval_meta_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/e2e_vault_service.dart';

// ─── محرك الضغط — ثوابت ──────────────────────────────────────
const _kAuditDuration = 3600; // 60 دقيقة
const _kLevel1Threshold = 600; // 10 دقائق → level 1
const _kLevel2Threshold = 300; // 5 دقائق  → level 2
const _kLevel3Threshold = 60;  // 60 ثانية  → level 3

/// AssetAuditScreen — نموذج الجرد الشامل (Step 3)
///
/// وضع Kiosk — لا يمكن الخروج حتى الإرسال أو انتهاء الوقت.
/// يتضمن:
///  - محرك الضغط (60 دقيقة + تدهور بصري)
///  - 13 فئة جرد ديناميكية مع رفع صور إلزامية
///  - تتبع المدخلات الوهمية + إجبار الصدق
///  - لوحة توقيع حية بالأحمر لتفعيل الإرسال
class AssetAuditScreen extends StatefulWidget {
  const AssetAuditScreen({super.key});

  @override
  State<AssetAuditScreen> createState() => _AssetAuditScreenState();
}

class _AssetAuditScreenState extends State<AssetAuditScreen>
    with TickerProviderStateMixin {
  // ── محرك الضغط ──────────────────────────────────────────────
  int _remaining = _kAuditDuration;
  Timer? _timer;

  // مستوى التدهور البصري (0-3)
  int get _degradeLevel {
    if (_remaining <= _kLevel3Threshold) return 3;
    if (_remaining <= _kLevel2Threshold) return 2;
    if (_remaining <= _kLevel1Threshold) return 1;
    return 0;
  }

  // ── وميض الشاشة ──────────────────────────────────────────────
  late AnimationController _flashCtrl;
  late Animation<double> _flashAnim;
  bool _flashVisible = false;

  // وميض العداد (المستوى 3)
  late AnimationController _timerFlashCtrl;
  late Animation<double> _timerFlashAnim;

  // ── حالة الفئات ──────────────────────────────────────────────
  late List<AuditCategoryState> _states;
  int _expandedIndex = -1;

  // ── عداد المسح (backspace) ───────────────────────────────────
  int _backspaceCount = 0;

  // ── المدخلات الوهمية ─────────────────────────────────────────
  final List<String> _ghostInputs = [];

  // ── التوقيع الحي ──────────────────────────────────────────────
  final List<List<Offset>> _sigStrokes = [];
  List<Offset>? _currentStroke;
  bool get _sigValid => _sigStrokes.fold<int>(0, (s, l) => s + l.length) > 25;

  // ── حالة الإرسال ─────────────────────────────────────────────
  bool _submitting = false;
  bool _lockoutTriggered = false;

  // ── تحميل الصور ──────────────────────────────────────────────
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    // إخفاء شريط الحالة — Kiosk
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // تهيئة حالات الفئات
    _states = kAuditCategories.map((c) => AuditCategoryState(category: c)).toList();

    // وميض الشاشة (backspace > 15)
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _flashAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_flashCtrl);

    // وميض العداد (المستوى 3)
    _timerFlashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat(reverse: true);
    _timerFlashAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_timerFlashCtrl);

    _startTimer();
  }

  // ── الإحصائيات اللحظية ───────────────────────────────────────

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _timer?.cancel();
        _triggerMasterLockout();
      }
    });
  }

  Future<void> _triggerMasterLockout() async {
    if (_lockoutTriggered) return;
    _lockoutTriggered = true;
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'applicationStatus': 'audit_timeout',
        'auditTimeoutAt': FieldValue.serverTimestamp(),
        'auditGhostInputs': _ghostInputs,
      });
    }
    if (mounted) {
      await context.read<AuthProvider>().updateApplicationStatus('audit_timeout');
    }
  }

  // ── إجبار الصدق — استبدال كلمات التقريب ─────────────────────
  String _enforceHonesty(String v) =>
      v.replaceAll(RegExp(r'تقريبا|تقريباً|حوالي|يمكن'), '').trim();

  // ── تتبع المسح (backspace) ───────────────────────────────────
  void _onBackspace() {
    _backspaceCount++;
    if (_backspaceCount > 15) {
      _triggerFlash();
    }
  }

  void _triggerFlash() async {
    if (!mounted) return;
    setState(() => _flashVisible = true);
    await _flashCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 50));
    await _flashCtrl.reverse();
    if (mounted) setState(() => _flashVisible = false);
  }

  // ── رصد المدخلات الوهمية ────────────────────────────────────
  void _trackGhostInput(String prev, String curr) {
    if (prev.length > 2 && curr.isEmpty) {
      _ghostInputs.add(prev);
    }
  }

  // ── اختيار صورة ──────────────────────────────────────────────
  Future<File?> _pickImage() async {
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.accent),
              title: const Text('الكاميرا', style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.accent),
              title: const Text('المعرض', style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return null;
    try {
      final xf = await _picker.pickImage(source: choice, imageQuality: 75, maxWidth: 1280);
      return xf != null ? File(xf.path) : null;
    } catch (_) {
      return null;
    }
  }

  // ── إرسال الجرد ──────────────────────────────────────────────
  Future<void> _submitAudit() async {
    if (!_sigValid || _submitting) return;
    setState(() => _submitting = true);
    _timer?.cancel();

    final auth = context.read<AuthProvider>();
    final uid  = auth.user?.uid;
    if (uid == null) return;

    final leaderUid = auth.user?.linkedLeaderUid ?? '';

    // بناء خريطة الإجابات (مع تشفير كلمات المرور)
    final Map<String, dynamic> answers = {};
    for (final state in _states) {
      Map<String, dynamic> submitMap = state.toSubmitMap();

      // تشفير كلمات مرور الحسابات الرقمية
      if (state.category.requiresEncryption && state.owned) {
        final encryptedForms = <Map<String, String>>[];
        for (final form in state.subForms) {
          final enc = Map<String, String>.from(form);
          if (enc.containsKey('password') && enc['password']!.isNotEmpty) {
            enc['password'] = await E2eVaultService.instance.encryptPassword(
              leaderUid: leaderUid,
              plaintext: enc['password']!,
            );
          }
          encryptedForms.add(enc);
        }
        submitMap['items'] = encryptedForms;
      }
      answers[state.category.id] = submitMap;
    }

    try {
      await FirebaseFirestore.instance.collection('asset_audits').doc(uid).set({
        'uid': uid,
        'leaderUid': leaderUid,
        'submittedAt': FieldValue.serverTimestamp(),
        'timeUsedSeconds': _kAuditDuration - _remaining,
        'answers': answers,
        'ghostInputs': _ghostInputs,
        'backspaceCount': _backspaceCount,
        'signaturePoints': _sigStrokes.fold<int>(0, (s, l) => s + l.length),
      });

      await auth.markAuditSubmitted();

      if (mounted) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✓ تم إرسال الجرد بنجاح', style: TextStyle(fontFamily: 'Tajawal')),
          backgroundColor: Color(0xFF2D7A27),
        ));
      }
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ في الإرسال: $e', style: const TextStyle(fontFamily: 'Tajawal')),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flashCtrl.dispose();
    _timerFlashCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── بناء الواجهة الرئيسية ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: _buildDegradedWrapper(
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              Column(
                children: [
                  _buildPressureHeader(),
                  Expanded(child: _buildCategoryList()),
                  _buildSignatureSection(),
                  _buildSubmitButton(),
                ],
              ),
              // ── وميض الشاشة ───────────────────────────
              if (_flashVisible)
                AnimatedBuilder(
                  animation: _flashAnim,
                  builder: (_, __) => Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: _flashAnim.value * 0.6,
                        child: Container(color: Colors.black),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── تغليف التدهور البصري ─────────────────────────────────────
  Widget _buildDegradedWrapper({required Widget child}) {
    if (_degradeLevel == 0) return child;
    return ColorFiltered(
      colorFilter: _degradationMatrix(_degradeLevel),
      child: child,
    );
  }

  static ColorFilter _degradationMatrix(int level) {
    final double b = level == 1 ? 0.8 : level == 2 ? 0.6 : 0.4;
    final double g = level >= 3 ? 0.5 : 0.0;

    // معامل الرمادي
    final double sr = (1 - g) + g * 0.2126;
    final double sg = g * 0.7152;
    final double sb = g * 0.0722;

    return ColorFilter.matrix([
      sr * b, sg * b, sb * b, 0, 0,
      (1-g) * 0.2126 * b + sg, (1-g) * b + sg * b - sg * b, sb * b, 0, 0,
      (1-g) * 0.0722 * b, sg * b, (1-g + g*0.9278) * b, 0, 0,
      0, 0, 0, 1, 0,
    ]);
  }

  // ── شريط الضغط (الرأس) ───────────────────────────────────────

  Widget _buildPressureHeader() {
    final mins = _remaining ~/ 60;
    final secs = _remaining % 60;
    final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final isRed = _degradeLevel >= 1;
    final isCritical = _degradeLevel >= 3;

    return Container(
      color: isRed
          ? Color.lerp(AppColors.background, Colors.red.shade900, (_kLevel1Threshold - _remaining.clamp(0, _kLevel1Threshold)) / _kLevel1Threshold)
          : AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              // ── معلومات الجرد ──────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('بروتوكول الجرد الشامل',
                        style: TextStyle(
                          color: AppColors.text,
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        )),
                    Text('${_completedCount()} / ${kAuditCategories.length} فئة مكتملة',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontFamily: 'Tajawal',
                          fontSize: 11,
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // ── العداد التنازلي ─────────────────────
              isCritical
                  ? AnimatedBuilder(
                      animation: _timerFlashAnim,
                      builder: (_, __) => _timerBadge(timeStr,
                          color: Color.lerp(Colors.red, Colors.white, _timerFlashAnim.value)!),
                    )
                  : _timerBadge(timeStr, color: isRed ? Colors.red : AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timerBadge(String text, {required Color color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.6)),
    ),
    child: Text(text,
        style: TextStyle(
          color: color,
          fontFamily: 'Tajawal',
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        )),
  );

  int _completedCount() => _states.where((s) => s.isComplete).length;

  // ── قائمة الفئات ─────────────────────────────────────────────

  Widget _buildCategoryList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: kAuditCategories.length,
      itemBuilder: (_, i) => _AuditCategoryTile(
        state: _states[i],
        isExpanded: _expandedIndex == i,
        onToggleExpand: () => setState(() {
          _expandedIndex = _expandedIndex == i ? -1 : i;
        }),
        onOwnedChanged: (v) => setState(() {
          _states[i].owned = v;
          if (v && _states[i].category.ruleType == AuditRuleType.askQty) {
            _ensureSubForms(_states[i]);
          }
        }),
        onQtyChanged: (q) => setState(() {
          _states[i].qty = q;
          _ensureSubForms(_states[i]);
        }),
        onSubFieldChanged: (formIdx, key, value) {
          final enforced = _enforceHonesty(value);
          _states[i].subForms[formIdx][key] = enforced;
        },
        onSubFieldBackspace: _onBackspace,
        onGhostInput: (prev, curr) => _trackGhostInput(prev, curr),
        onImagePick: (formIdx, imgIdx) async {
          final f = await _pickImage();
          if (f != null && mounted) {
            setState(() {
              while (_states[i].subImages[formIdx].length <= imgIdx) {
                _states[i].subImages[formIdx].add(null);
              }
              _states[i].subImages[formIdx][imgIdx] = f;
            });
          }
        },
        onDetailsChanged: (v) => setState(() {
          _states[i].detailsText = _enforceHonesty(v);
        }),
        onRoleSelected: (r) => setState(() {
          _states[i].selectedRole = r;
        }),
        onGhostInputCallback: (g) => _ghostInputs.add(g),
      ),
    );
  }

  void _ensureSubForms(AuditCategoryState state) {
    while (state.subForms.length < state.qty) {
      final emptyForm = <String, String>{
        for (final f in state.category.subItemFields) f.key: ''
      };
      state.subForms.add(emptyForm);
      state.subImages.add([]);
    }
    while (state.subForms.length > state.qty) {
      state.subForms.removeLast();
      state.subImages.removeLast();
    }
  }

  // ── قسم التوقيع ───────────────────────────────────────────────

  Widget _buildSignatureSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('التوقيع الإلكتروني الحي (مطلوب للإرسال):',
              style: TextStyle(
                color: AppColors.text,
                fontFamily: 'Tajawal',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 6),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              border: Border.all(
                color: _sigValid ? const Color(0xFFe53e3e) : AppColors.border,
                width: _sigValid ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GestureDetector(
                onPanStart: (d) {
                  setState(() {
                    _currentStroke = [d.localPosition];
                    _sigStrokes.add(_currentStroke!);
                  });
                },
                onPanUpdate: (d) {
                  setState(() => _currentStroke?.add(d.localPosition));
                },
                onPanEnd: (_) => setState(() => _currentStroke = null),
                child: CustomPaint(
                  painter: _SigPainter(strokes: _sigStrokes),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => setState(() { _sigStrokes.clear(); }),
                child: const Text('مسح', style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
              ),
              Text(
                _sigValid ? '✓ مُسجَّل' : 'وقِّع فوق',
                style: TextStyle(
                  color: _sigValid ? const Color(0xFFe53e3e) : AppColors.textMuted,
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── زر الإرسال ────────────────────────────────────────────────

  bool get _canSubmit => _sigValid && !_submitting;

  Widget _buildSubmitButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _canSubmit ? _submitAudit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _canSubmit ? AppColors.accent : AppColors.backgroundCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _submitting
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : Text(
                    _canSubmit
                        ? 'إرسال الجرد — ${_completedCount()}/${kAuditCategories.length}'
                        : 'أكمل الجرد والتوقيع لتفعيل الإرسال',
                    style: TextStyle(
                      color: _canSubmit ? Colors.black : AppColors.textMuted,
                      fontFamily: 'Tajawal',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  بطاقة الفئة — كل فئة من الـ 13 فئة
// ═══════════════════════════════════════════════════════════════

class _AuditCategoryTile extends StatelessWidget {
  final AuditCategoryState state;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<bool> onOwnedChanged;
  final ValueChanged<int> onQtyChanged;
  final void Function(int formIdx, String key, String value) onSubFieldChanged;
  final VoidCallback onSubFieldBackspace;
  final void Function(String prev, String curr) onGhostInput;
  final void Function(int formIdx, int imgIdx) onImagePick;
  final ValueChanged<String> onDetailsChanged;
  final ValueChanged<String> onRoleSelected;
  final ValueChanged<String> onGhostInputCallback;

  const _AuditCategoryTile({
    required this.state,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onOwnedChanged,
    required this.onQtyChanged,
    required this.onSubFieldChanged,
    required this.onSubFieldBackspace,
    required this.onGhostInput,
    required this.onImagePick,
    required this.onDetailsChanged,
    required this.onRoleSelected,
    required this.onGhostInputCallback,
  });

  @override
  Widget build(BuildContext context) {
    final cat       = state.category;
    final complete  = state.isComplete;
    final borderCol = state.owned
        ? (complete ? AppColors.success : const Color(0xFF1A5C9C))
        : AppColors.border;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol, width: state.owned ? 1.5 : 1),
      ),
      child: Column(
        children: [
          // ── ترويسة البطاقة ───────────────────────────
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                children: [
                  // زر نعم / لا
                  if (cat.ruleType != AuditRuleType.roleSelect)
                    _YesNoToggle(
                      owned: state.owned,
                      onChanged: onOwnedChanged,
                    ),
                  const SizedBox(width: 10),
                  // عنوان الفئة
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(cat.titleAr,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontFamily: 'Tajawal',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                )),
                            const SizedBox(width: 6),
                            Text(cat.emoji, style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                        Text(cat.subtitleAr,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                            )),
                      ],
                    ),
                  ),
                  // مؤشر الاكتمال
                  if (complete)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                    ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textMuted, size: 18,
                  ),
                ],
              ),
            ),
          ),

          // ── محتوى موسَّع ──────────────────────────────
          if (isExpanded) _buildExpandedContent(context),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    final cat = state.category;

    if (!state.owned && cat.ruleType != AuditRuleType.roleSelect) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Text(
          'اضغط "نعم" إذا كنت تمتلك هذا البند',
          textAlign: TextAlign.right,
          style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12),
        ),
      );
    }

    switch (cat.ruleType) {
      case AuditRuleType.roleSelect:
        return _buildRoleSelect(context);

      case AuditRuleType.detailsOnly:
        return _buildDetailsOnly(context);

      case AuditRuleType.singleForm:
      case AuditRuleType.askQty:
        return _buildAskQtyForm(context);
    }
  }

  // ── اختيار الدور (تصنيف المشاركة) ────────────────────────────
  Widget _buildRoleSelect(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: state.category.roleOptions.map((opt) {
          final selected = state.selectedRole == opt;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onRoleSelected(opt),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? AppColors.accent : AppColors.border,
                  ),
                ),
                child: Text(opt,
                    style: TextStyle(
                      color: selected ? Colors.black : AppColors.text,
                      fontFamily: 'Tajawal',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── تفاصيل نصية فقط ──────────────────────────────────────────
  Widget _buildDetailsOnly(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: _AuditTextField(
        label: 'التفاصيل الدقيقة',
        multiline: true,
        onChanged: (v) {
          onDetailsChanged(v);
        },
        onBackspace: onSubFieldBackspace,
        onGhostInput: onGhostInputCallback,
      ),
    );
  }

  // ── نموذج العدد / النموذج الفردي ────────────────────────────
  Widget _buildAskQtyForm(BuildContext context) {
    final cat = state.category;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── حقل الكمية ──────────────────────────────
          if (cat.ruleType == AuditRuleType.askQty) ...[
            const Text('العدد الإجمالي:',
                style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 100,
                  child: _AuditTextField(
                    label: 'الكمية',
                    numeric: true,
                    initialValue: state.qty.toString(),
                    onChanged: (v) {
                      final q = int.tryParse(v) ?? 1;
                      if (q > 0 && q <= 20) onQtyChanged(q);
                    },
                    onBackspace: onSubFieldBackspace,
                    onGhostInput: onGhostInputCallback,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // ── مجموعات الحقول الفرعية ───────────────────
          ...List.generate(state.subForms.length, (formIdx) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // رقم البند
                      Text('البند ${formIdx + 1}',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 8),

                      // حقول البند
                      ...cat.subItemFields.map((field) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _AuditTextField(
                          label: field.labelAr,
                          isRequired: field.isRequired,
                          isPassword: field.isPassword,
                          multiline: field.inputConfig.isMultiline,
                          numeric: field.inputConfig.isNumeric,
                          maxLength: field.inputConfig.maxLength,
                          onChanged: (v) => onSubFieldChanged(formIdx, field.key, v),
                          onBackspace: onSubFieldBackspace,
                          onGhostInput: onGhostInputCallback,
                        ),
                      )),

                      // زر رفع الصورة الإلزامية
                      _ImageUploadButton(
                        image: formIdx < state.subImages.length && state.subImages[formIdx].isNotEmpty
                            ? state.subImages[formIdx].first
                            : null,
                        onTap: () => onImagePick(formIdx, 0),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ودجات مساعدة
// ═══════════════════════════════════════════════════════════════

/// زر نعم / لا للملكية
class _YesNoToggle extends StatelessWidget {
  final bool owned;
  final ValueChanged<bool> onChanged;
  const _YesNoToggle({required this.owned, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Btn(label: 'نعم', active: owned,     color: const Color(0xFF1A5C9C), onTap: () => onChanged(true)),
        const SizedBox(height: 4),
        _Btn(label: 'لا',  active: !owned, color: const Color(0xFF3A1010), onTap: () => onChanged(false)),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? color : AppColors.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? color : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
              color: active ? Colors.white : AppColors.textMuted,
              fontFamily: 'Tajawal',
              fontSize: 11,
              fontWeight: FontWeight.w600,
            )),
      ),
    );
  }
}

/// حقل نص موحَّد لنموذج الجرد
class _AuditTextField extends StatefulWidget {
  final String label;
  final bool isRequired;
  final bool isPassword;
  final bool multiline;
  final bool numeric;
  final int? maxLength;
  final String? initialValue;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;
  final ValueChanged<String> onGhostInput;

  const _AuditTextField({
    required this.label,
    this.isRequired = true,
    this.isPassword = false,
    this.multiline = false,
    this.numeric = false,
    this.maxLength,
    this.initialValue,
    required this.onChanged,
    required this.onBackspace,
    required this.onGhostInput,
  });

  @override
  State<_AuditTextField> createState() => _AuditTextFieldState();
}

// ── ثوابت محرك الصدق الإجباري ────────────────────────────────────────────────

/// الحد الأدنى لعدد الأحرف المضافة في عملية واحدة حتى تُعدَّ لصقاً
const _kPasteThreshold = 6;

/// أنماط اللغة المراوغة التي يُحظر استخدامها
final _kEvasivePatterns = RegExp(
  r'(حوالي|تقريباً|تقريبا|ربما|ربّما|أحياناً|أحيانا|نوعاً ما|نوعا ما|'
  r'قد يكون|يمكن أن|ممكن|أو ربما|شيء ما|نحو|قرابة|ما يقارب|'
  r'approximately|around|maybe|probably|sometimes|sort of)',
  caseSensitive: false,
);

class _AuditTextFieldState extends State<_AuditTextField> {
  late final TextEditingController _ctrl;
  String _prevValue = '';
  bool _obscure = true;
  bool _pasteWarning = false;
  bool _evasiveWarning = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue ?? '');
    _prevValue = _ctrl.text;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── كشف اللصق ───────────────────────────────────────────────────────────

  void _handleChange(String v) {
    final delta = v.length - _prevValue.length;

    // ── محرك الصدق الإجباري — كشف اللصق ──────────────────────────
    if (delta >= _kPasteThreshold && !widget.isPassword) {
      // مسح الحقل + تحذير
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ctrl.clear();
        setState(() { _pasteWarning = true; _evasiveWarning = false; });
        widget.onChanged('');
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _pasteWarning = false);
        });
      });
      _prevValue = '';
      return;
    }

    // ── محرك الصدق الإجباري — فلتر اللغة المراوغة ────────────────
    if (_kEvasivePatterns.hasMatch(v) && !widget.isPassword) {
      final cleaned = v.replaceAll(_kEvasivePatterns, '');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ctrl.value = TextEditingValue(
          text: cleaned,
          selection: TextSelection.collapsed(offset: cleaned.length),
        );
        setState(() { _evasiveWarning = true; _pasteWarning = false; });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _evasiveWarning = false);
        });
        widget.onChanged(cleaned);
      });
      _prevValue = cleaned;
      return;
    }

    // ── تتبع المدخلات الوهمية والـ backspace ─────────────────────
    if (_prevValue.length > 2 && v.isEmpty) {
      widget.onGhostInput(_prevValue);
    }
    if (v.length < _prevValue.length) {
      widget.onBackspace();
    }
    _prevValue = v;
    setState(() { _pasteWarning = false; _evasiveWarning = false; });
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      TextField(
        controller: _ctrl,
        obscureText: widget.isPassword && _obscure,
        maxLines: widget.multiline ? 4 : 1,
        maxLength: widget.maxLength,
        keyboardType: widget.numeric
            ? TextInputType.number
            : widget.multiline
                ? TextInputType.multiline
                : TextInputType.text,
        style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 13),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          labelText: widget.isRequired ? '${widget.label} *' : widget.label,
          labelStyle: TextStyle(
              color: (_pasteWarning || _evasiveWarning) ? AppColors.error : AppColors.textMuted,
              fontFamily: 'Tajawal', fontSize: 12),
          counterStyle: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          filled: true,
          fillColor: (_pasteWarning || _evasiveWarning)
              ? AppColors.error.withValues(alpha: 0.05)
              : AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: (_pasteWarning || _evasiveWarning)
                    ? AppColors.error
                    : AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: (_pasteWarning || _evasiveWarning)
                    ? AppColors.error
                    : AppColors.accent.withValues(alpha: 0.7)),
          ),
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onChanged: _handleChange,
      ),
      // ── رسائل محرك الصدق الإجباري ──────────────────────────────────
      if (_pasteWarning)
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 4),
          child: Text(
            'اللصق محظور. اكتب بياناتك مباشرة.',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.error,
              fontFamily: 'Tajawal',
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        )
      else if (_evasiveWarning)
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 4),
          child: Text(
            'محظور استخدام لغة تقريبية. حُذفت الكلمات المراوغة.',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.warning,
              fontFamily: 'Tajawal',
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
    ]);
  }
}

/// زر رفع صورة إلزامي
class _ImageUploadButton extends StatelessWidget {
  final File? image;
  final VoidCallback onTap;
  const _ImageUploadButton({this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: image != null ? 140 : 50,
        decoration: BoxDecoration(
          color: image != null ? Colors.transparent : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: image != null ? AppColors.success : const Color(0xFFe53e3e),
            width: image != null ? 1 : 1.5,
            style: image != null ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: image != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.file(image!, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4, left: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                  ),
                  Positioned(
                    bottom: 4, right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('تغيير الصورة',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Tajawal')),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt_outlined, color: Color(0xFFe53e3e), size: 18),
                  const SizedBox(width: 6),
                  const Text('رفع صورة إثبات (إلزامي)',
                      style: TextStyle(
                        color: Color(0xFFe53e3e),
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
      ),
    );
  }
}

// ── رسّام التوقيع ──────────────────────────────────────────────

class _SigPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _SigPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFe53e3e)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke[0].dx, stroke[0].dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SigPainter old) => true;
}
