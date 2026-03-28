import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';

/// FinalConstitutionScreen — الدستور النهائي (Appendix E) — Step 4b
///
/// يُعرض بعد انتهاء المقابلة عندما ترسل السيدة payload الدستور النهائي.
/// البيانات الواردة: { leaderDecision, terms[], signingDeadlineIso }
/// المطلوب من العنصر: توقيع إلكتروني حي بلون أحمر (#e53e3e) لإنهاء العملية.
class FinalConstitutionScreen extends StatefulWidget {
  const FinalConstitutionScreen({super.key});

  @override
  State<FinalConstitutionScreen> createState() => _FinalConstitutionScreenState();
}

class _FinalConstitutionScreenState extends State<FinalConstitutionScreen> {
  // ── إشارات التوقيع ───────────────────────────────────────────
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;
  bool _signatureValid = false;
  bool _submitting = false;

  // ── بيانات الدستور من Firestore ──────────────────────────────
  Map<String, dynamic>? _constitutionPayload;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConstitutionPayload();
  }

  Future<void> _loadConstitutionPayload() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) { setState(() => _loading = false); return; }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('final_constitution')
          .doc(uid)
          .get();
      setState(() {
        _constitutionPayload = doc.data();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  // ── التوقيع ────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails d) {
    setState(() {
      _currentStroke = [d.localPosition];
      _strokes.add(_currentStroke!);
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _currentStroke?.add(d.localPosition);
      _signatureValid = _strokes.fold<int>(0, (s, l) => s + l.length) > 20;
    });
  }

  void _onPanEnd(DragEndDetails _) {
    setState(() => _currentStroke = null);
  }

  void _clearSignature() {
    setState(() {
      _strokes.clear();
      _signatureValid = false;
    });
  }

  Future<void> _submitFinalConstitution() async {
    if (!_signatureValid || _submitting) return;
    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();
    final uid  = auth.user?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'applicationStatus':          'finalized',
        'finalConstitutionSignedAt':  FieldValue.serverTimestamp(),
        'finalConstitutionComplete':  true,
      });
      await auth.updateApplicationStatus('approved_active');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✓ تم التوقيع على الدستور النهائي بنجاح',
              style: TextStyle(fontFamily: 'Tajawal')),
          backgroundColor: Color(0xFF2D7A27),
        ));
      }
    } catch (e) {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final payload   = _constitutionPayload;
    final decision  = payload?['leaderDecision'] ?? 'قرار السيدة في انتظار الإرسال';
    final terms     = (payload?['terms'] as List?)?.cast<String>() ?? _defaultTerms;
    final deadline  = payload?['signingDeadlineIso'] ?? '';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ── ترويسة ──────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.gavel_rounded, color: AppColors.gold, size: 28),
                const SizedBox(width: 10),
                const Text('الدستور النهائي — الملحق (ه)',
                    style: TextStyle(
                      color: AppColors.text,
                      fontFamily: 'Tajawal',
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    )),
              ],
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text('Appendix E — Final Constitution',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'Tajawal')),
            ),
            const Divider(color: AppColors.border, height: 32),

            // ── قرار السيدة ──────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1A0A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('قرار السيدة:',
                      style: TextStyle(color: AppColors.gold, fontFamily: 'Tajawal',
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(decision,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 14, height: 1.7)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── بنود الاتفاق ──────────────────────────────
            const Align(
              alignment: Alignment.centerRight,
              child: Text('بنود الاتفاق النهائي:',
                  style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal',
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            ...terms.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                textDirection: TextDirection.rtl,
                children: [
                  Text('${e.key + 1}. ', style: TextStyle(color: AppColors.gold, fontFamily: 'Tajawal', fontSize: 13)),
                  Expanded(
                    child: Text(e.value,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 13, height: 1.6)),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 8),

            if (deadline.isNotEmpty)
              Center(
                child: Text('موعد التوقيع قبل: $deadline',
                    style: const TextStyle(color: Colors.redAccent, fontFamily: 'Tajawal', fontSize: 12)),
              ),
            const SizedBox(height: 24),

            // ── لوحة التوقيع الحي ────────────────────────
            const Align(
              alignment: Alignment.centerRight,
              child: Text('التوقيع الإلكتروني الحي (باللون الأحمر):',
                  style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal',
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                border: Border.all(
                  color: _signatureValid ? const Color(0xFFe53e3e) : AppColors.border,
                  width: _signatureValid ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: CustomPaint(
                    painter: _SignaturePainter(strokes: _strokes),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _clearSignature,
                  child: const Text('مسح التوقيع',
                      style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
                ),
                Text(
                  _signatureValid ? '✓ التوقيع مُسجَّل' : 'وقِّع فوق للتأكيد',
                  style: TextStyle(
                    color: _signatureValid ? AppColors.success : AppColors.textMuted,
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── زر الإرسال ──────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _signatureValid && !_submitting ? _submitFinalConstitution : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _signatureValid ? const Color(0xFFe53e3e) : AppColors.backgroundCard,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('أوافق وأُوقِّع على الدستور النهائي',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Tajawal',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        )),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static const _defaultTerms = [
    'يُقرّ العنصر بقبول جميع القرارات الصادرة عن السيدة دون اعتراض.',
    'تُصبح جميع البيانات المُقدَّمة في نموذج الجرد ملكاً للمشروع.',
    'يلتزم العنصر بالحضور في الأوقات المحددة دون تأخير.',
    'أي مخالفة تُلغي هذا الاتفاق فوراً دون الحاجة لإشعار مسبق.',
    'توقيع هذا الدستور يُعدّ موافقة رسمية وقانونية على جميع البنود.',
  ];
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _SignaturePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFe53e3e)
      ..strokeWidth = 3.0
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
  bool shouldRepaint(_SignaturePainter old) => true;
}
