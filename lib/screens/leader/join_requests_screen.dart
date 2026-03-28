import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/approval_meta_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leader_ui_provider.dart';
import '../../providers/participant_stream_provider.dart';
import '../../repositories/participant_card_repository.dart';

/// شاشة طلبات الانضمام
///
/// ⚡ مُصلَحة: تقرأ من Firestore الحقيقي عبر ParticipantStreamProvider
///    مع الرجوع للـ mock عند عدم توفّر بيانات Firebase
class JoinRequestsScreen extends StatelessWidget {
  const JoinRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final streamProvider = context.watch<ParticipantStreamProvider>();
    final mockProvider   = context.watch<LeaderUIProvider>();

    // ⚡ اختيار مصدر البيانات: Firestore الحقيقي أو Mock
    final bool useRealData = streamProvider.isInitialized;
    final int pendingCount = useRealData
        ? streamProvider.pendingCount
        : mockProvider.pendingCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, pendingCount),
            // ── طلبات المساعدة الطارئة (Petitions) ─────────────
            _PetitionSection(),
            Expanded(
              child: useRealData
                  ? _buildLiveList(context, streamProvider)
                  : _buildMockList(context, mockProvider),
            ),
          ],
        ),
      ),
    );
  }

  // ── قائمة حقيقية (Firestore) ──────────────────────────────────

  Widget _buildLiveList(
      BuildContext context, ParticipantStreamProvider provider) {
    final requests = provider.pendingRequests;
    if (requests.isEmpty) return _buildEmpty();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _LiveRequestCard(req: requests[i]),
    );
  }

  // ── قائمة Mock (تطوير) ────────────────────────────────────────

  Widget _buildMockList(
      BuildContext context, LeaderUIProvider provider) {
    final requests = provider.joinRequests;
    if (requests.isEmpty) return _buildEmpty();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _RequestCard(req: requests[i]),
    );
  }

  Widget _buildHeader(BuildContext context, int pending) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (pending > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.warning.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pending_outlined, size: 14, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text('$pending معلق',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Tajawal')),
                ],
              ),
            ),
          const Spacer(),
          const Text('طلبات الانضمام',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  fontFamily: 'Tajawal')),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 52, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text('لا توجد طلبات انضمام',
              style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 15,
                  fontFamily: 'Tajawal')),
        ],
      ),
    );
  }
}

// ── Live Request Card (Firestore) ─────────────────────────────

class _LiveRequestCard extends StatelessWidget {
  final JoinRequestLive req;
  const _LiveRequestCard({required this.req});

  @override
  Widget build(BuildContext context) {
    final isPending   = req.status == 'pending';
    final borderColor = isPending ? AppColors.warning
        : req.status == 'approved' ? AppColors.success
        : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Text(
                _formatTime(req.requestedAt),
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontFamily: 'Tajawal'),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(req.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: AppColors.text, fontFamily: 'Tajawal')),
                  Text(req.deviceModel,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Tajawal')),
                ],
              ),
              const SizedBox(width: 12),
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor.withOpacity(0.5), width: 2),
                  color: AppColors.backgroundElevated,
                ),
                child: Center(
                  child: Text(
                    req.name.split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join(),
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: borderColor, fontFamily: 'Tajawal'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!isPending) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  req.status == 'approved' ? Icons.check_circle_outline : Icons.cancel_outlined,
                  size: 14, color: borderColor,
                ),
                const SizedBox(width: 5),
                Text(
                  req.status == 'approved' ? 'مقبول' : 'مرفوض',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: borderColor, fontFamily: 'Tajawal'),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _confirmReject(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('رفض',
                        style: TextStyle(fontSize: 13, color: AppColors.error, fontFamily: 'Tajawal')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _confirmAccept(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('قبول',
                        style: TextStyle(fontSize: 13, color: Colors.white, fontFamily: 'Tajawal')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// ✦ بروتوكول الموافقة الكاملة (Phase 11 — Step 2)
  /// يفتح نافذة إدخال: توقيت الجرد + موعد/مكان المقابلة + الزي الرسمي
  void _confirmAccept(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final ladyName = auth.user?.fullName ?? 'السيدة';

    // توليد رمز عنصر فريد
    final assetCode = 'E-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase().substring(4)}';

    // حالة النموذج
    String auditSchedule    = 'خلال 24 ساعة من الإخطار';
    DateTime? interviewDt;
    final locationCtrl      = TextEditingController();
    final dressCodeCtrl     = TextEditingController();
    bool submitting         = false;

    final auditOptions = [
      'فوراً',
      'خلال ساعتين من الإخطار',
      'خلال 24 ساعة من الإخطار',
      'خلال 48 ساعة من الإخطار',
      'في موعد المقابلة مباشرةً',
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          // ── دالة اختيار التاريخ/الوقت ─────────────────
          Future<void> pickInterviewTime() async {
            final now  = DateTime.now();
            final date = await showDatePicker(
              context: dialogCtx,
              initialDate: now.add(const Duration(days: 1)),
              firstDate: now,
              lastDate: now.add(const Duration(days: 60)),
              builder: (_, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(primary: AppColors.gold),
                ),
                child: child!,
              ),
            );
            if (date == null) return;
            final time = await showTimePicker(
              context: dialogCtx,
              initialTime: TimeOfDay(hour: 10, minute: 0),
              builder: (_, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(primary: AppColors.gold),
                ),
                child: child!,
              ),
            );
            if (time == null) return;
            setDialogState(() {
              interviewDt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
            });
          }

          final interviewFormatted = interviewDt == null
              ? 'اضغط لاختيار الموعد'
              : ApprovalMeta(
                  ladyName: ladyName,
                  assetCode: assetCode,
                  auditSchedule: auditSchedule,
                  interviewTimeIso: interviewDt!.toIso8601String(),
                  interviewLocation: '',
                  dressCode: '',
                ).formattedInterviewTime;

          return Dialog(
            backgroundColor: AppColors.backgroundCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── ترويسة ────────────────────────────
                  Row(
                    children: [
                      Icon(Icons.gavel_rounded, color: AppColors.gold, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'بروتوكول الموافقة — إعداد تعليمات العنصر',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: AppColors.text,
                            fontFamily: 'Tajawal',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.border, height: 20),

                  // ── رمز العنصر ────────────────────────
                  _labeledRow('رمز العنصر:', assetCode, color: AppColors.gold),
                  const SizedBox(height: 12),

                  // ── توقيت الجرد ───────────────────────
                  _fieldLabel('1. توقيت بروتوكول الجرد الشامل:'),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: auditSchedule,
                    dropdownColor: AppColors.backgroundElevated,
                    style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 13),
                    decoration: _inputDecoration('اختر توقيت الجرد'),
                    items: auditOptions.map((o) => DropdownMenuItem(
                      value: o,
                      child: Text(o, textAlign: TextAlign.right,
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
                    )).toList(),
                    onChanged: (v) => setDialogState(() => auditSchedule = v ?? auditSchedule),
                  ),
                  const SizedBox(height: 12),

                  // ── موعد المقابلة ─────────────────────
                  _fieldLabel('2. موعد المقابلة المباشرة:'),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: pickInterviewTime,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: interviewDt != null ? AppColors.gold.withValues(alpha: 0.6) : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              color: interviewDt != null ? AppColors.gold : AppColors.textMuted,
                              size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(interviewFormatted,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: interviewDt != null ? AppColors.text : AppColors.textMuted,
                                  fontFamily: 'Tajawal',
                                  fontSize: 13,
                                )),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── مكان المقابلة ─────────────────────
                  _fieldLabel('3. مكان المقابلة:'),
                  const SizedBox(height: 4),
                  TextField(
                    controller: locationCtrl,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 13),
                    decoration: _inputDecoration('العنوان الكامل للمقر'),
                  ),
                  const SizedBox(height: 12),

                  // ── الزي الرسمي ───────────────────────
                  _fieldLabel('4. الزي الرسمي المطلوب:'),
                  const SizedBox(height: 4),
                  TextField(
                    controller: dressCodeCtrl,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 13),
                    decoration: _inputDecoration('مثال: بدلة رسمية داكنة، قميص أبيض'),
                  ),
                  const SizedBox(height: 16),

                  // ── Appendix C — نموذج رسالة القبول ──
                  _fieldLabel('5. معاينة رسالة القبول (Appendix C):'),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.gold.withOpacity(0.35))),
                    child: Text(
                      _buildAppendixCMessage(
                        name: req.name,
                        assetCode: assetCode,
                        ladyName: ladyName,
                        interviewDt: interviewDt,
                        location: locationCtrl.text.trim(),
                        dressCode: dressCodeCtrl.text.trim(),
                        auditSchedule: auditSchedule,
                      ),
                      style: const TextStyle(
                        fontSize: 12, color: AppColors.text,
                        fontFamily: 'Tajawal', height: 1.6),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── أزرار الإجراء ─────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: submitting ? null : () => Navigator.pop(dialogCtx),
                          child: const Text('إلغاء',
                              style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: submitting ? null : () async {
                            if (interviewDt == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('يرجى تحديد موعد المقابلة',
                                    style: TextStyle(fontFamily: 'Tajawal')),
                                backgroundColor: AppColors.error,
                              ));
                              return;
                            }
                            if (locationCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('يرجى إدخال مكان المقابلة',
                                    style: TextStyle(fontFamily: 'Tajawal')),
                                backgroundColor: AppColors.error,
                              ));
                              return;
                            }

                            setDialogState(() => submitting = true);

                            final meta = ApprovalMeta(
                              ladyName:           ladyName,
                              assetCode:          assetCode,
                              auditSchedule:      auditSchedule,
                              interviewTimeIso:   interviewDt!.toIso8601String(),
                              interviewLocation:  locationCtrl.text.trim(),
                              dressCode:          dressCodeCtrl.text.trim().isEmpty
                                  ? 'وفق التعليمات' : dressCodeCtrl.text.trim(),
                            );

                            try {
                              await context.read<ParticipantStreamProvider>().approveWithMeta(
                                uid: req.uid,
                                meta: meta.toMap(),
                                assetCode: assetCode,
                              );
                              if (context.mounted) Navigator.pop(dialogCtx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(
                                    '✓ تم إرسال بروتوكول القبول إلى العنصر ${req.name}',
                                    style: const TextStyle(fontFamily: 'Tajawal'),
                                  ),
                                  backgroundColor: AppColors.success,
                                ));
                              }
                            } catch (e) {
                              setDialogState(() => submitting = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                          child: submitting
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Text('إرسال البروتوكول',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontFamily: 'Tajawal',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  )),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _fieldLabel(String text) => Text(text,
      textAlign: TextAlign.right,
      style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 12));

  static Widget _labeledRow(String label, String value, {Color? color}) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Text(value,
          style: TextStyle(
            color: color ?? AppColors.text,
            fontFamily: 'Tajawal',
            fontSize: 13,
            fontWeight: FontWeight.w700,
          )),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
    ],
  );

  static InputDecoration _inputDecoration(String hint) => InputDecoration(
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

  void _confirmReject(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد الرفض',
            textAlign: TextAlign.right,
            style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 16)),
        content: Text('سيُرفض طلب ${req.name} وسيتلقى إشعاراً فورياً.',
            textAlign: TextAlign.right,
            style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء',
                style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<ParticipantStreamProvider>().rejectRequest(req.uid);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('✗ تم رفض ${req.name}',
                      style: const TextStyle(fontFamily: 'Tajawal')),
                  backgroundColor: AppColors.error,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('تأكيد الرفض',
                style: TextStyle(color: Colors.white, fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes}د';
    if (diff.inHours < 24)   return 'منذ ${diff.inHours}س';
    return 'منذ ${diff.inDays}ي';
  }

  /// Appendix C — نموذج رسالة القبول الرسمي
  static String _buildAppendixCMessage({
    required String name,
    required String assetCode,
    required String ladyName,
    required DateTime? interviewDt,
    required String location,
    required String dressCode,
    required String auditSchedule,
  }) {
    final interviewStr = interviewDt == null
        ? '[لم يُحدَّد بعد]'
        : '${interviewDt.day}/${interviewDt.month}/${interviewDt.year} — الساعة ${interviewDt.hour.toString().padLeft(2, '0')}:${interviewDt.minute.toString().padLeft(2, '0')}';

    return '''بسم الله الرحمن الرحيم

إلى: $name
الرمز المخصص: $assetCode

تحيةً طيبةً وبعد،

يسعدنا إبلاغك بأن طلب انضمامك قد نال موافقة $ladyName — المشرفة العليا على النظام — وذلك بعد مراجعة بياناتك الكاملة وتقييم ملفك بعناية.

━━━ تفاصيل الخطوة التالية ━━━

📋 موعد الجرد الشامل:
$auditSchedule

📅 موعد المقابلة الشخصية:
$interviewStr

📍 مكان المقابلة:
${location.isEmpty ? '[سيُحدَّد لاحقاً]' : location}

👔 الزي الرسمي المطلوب:
${dressCode.isEmpty ? 'وفق التعليمات' : dressCode}

━━━ التعليمات الإلزامية ━━━

١. يجب الحضور في الموعد المحدد بدقة تامة — التأخر بدون إذن مسبق يُعدّ مخالفة صريحة.
٢. يجب إحضار جميع المستندات الأصلية المذكورة في الاستمارة.
٣. يجب تحميل التطبيق وتفعيله قبل موعد المقابلة بـ 24 ساعة على الأقل.
٤. أي تواصل خارجي يخص هذا النظام يمر عبر القنوات الرسمية حصراً.
٥. التزامك بهذه التعليمات يُعدّ اختباراً أولياً لأهليتك للانضمام.

مع أطيب التحيات والتقدير،
$ladyName — المشرفة العليا
نظام البانوبتيكون — وحدة القيادة المركزية''';
  }
}

// ── Request Card (Mock — تطوير فقط) ──────────────────────────

class _RequestCard extends StatelessWidget {
  final JoinRequest req;
  const _RequestCard({required this.req});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<LeaderUIProvider>();
    final isPending = req.status == JoinRequestStatus.pending;
    final borderColor = _statusColor(req.status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Header
          Row(
            children: [
              // تايم ستامب
              Text(
                _formatTime(req.requestedAt),
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontFamily: 'Tajawal'),
              ),
              const Spacer(),
              // الاسم + موديل الجهاز
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(req.name,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                          fontFamily: 'Tajawal')),
                  Text(req.deviceModel,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontFamily: 'Tajawal')),
                ],
              ),
              const SizedBox(width: 12),
              // الأفاتار
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor.withOpacity(0.5), width: 2),
                  color: AppColors.backgroundElevated,
                ),
                child: Center(
                  child: Text(
                    req.name.split(' ').take(2).map((w) => w[0]).join(),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: borderColor,
                        fontFamily: 'Tajawal'),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (!isPending) ...[
            // حالة: مقبول / مرفوض
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(_statusIcon(req.status), size: 14, color: borderColor),
                const SizedBox(width: 5),
                Text(
                  _statusLabel(req.status),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: borderColor,
                      fontFamily: 'Tajawal'),
                ),
              ],
            ),
          ] else ...[
            // أزرار الإجراء
            Row(
              children: [
                // رفض
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _confirmReject(context, provider),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('رفض',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.error,
                            fontFamily: 'Tajawal')),
                  ),
                ),
                const SizedBox(width: 10),
                // قبول
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _confirmAccept(context, provider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('قبول',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontFamily: 'Tajawal')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── قبول ─────────────────────────────────────────────────────

  void _confirmAccept(BuildContext context, LeaderUIProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد القبول',
            textAlign: TextAlign.right,
            style: TextStyle(
                color: AppColors.text, fontFamily: 'Tajawal', fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('سيُقبل طلب ${req.name}.',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Tajawal',
                    fontSize: 13)),
            const SizedBox(height: 12),
            // تنبيه الصلاحيات الإلزامية
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  Row(
                    children: [
                      Expanded(child: SizedBox()),
                      Text('صلاحيات إلزامية على الجهاز',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                              fontFamily: 'Tajawal')),
                      SizedBox(width: 5),
                      Icon(Icons.warning_amber_outlined, size: 14, color: AppColors.warning),
                    ],
                  ),
                  SizedBox(height: 8),
                  _PermRow(icon: Icons.admin_panel_settings_outlined, text: 'مشرف الجهاز (Device Admin)'),
                  _PermRow(icon: Icons.accessibility_outlined, text: 'خدمات إمكانية الوصول'),
                  _PermRow(icon: Icons.layers_outlined, text: 'الرسم فوق التطبيقات'),
                  _PermRow(icon: Icons.battery_charging_full_outlined, text: 'تجاهل تحسين البطارية'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'سيُطلب من العنصر منح هذه الصلاحيات يدوياً من إعدادات الجهاز.',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 11, color: AppColors.textMuted, fontFamily: 'Tajawal'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء',
                style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              provider.acceptRequest(req.uid);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✓ تم قبول ${req.name}',
                      style: const TextStyle(fontFamily: 'Tajawal')),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('تأكيد القبول',
                style: TextStyle(color: Colors.white, fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
  }

  // ── رفض ──────────────────────────────────────────────────────

  void _confirmReject(BuildContext context, LeaderUIProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد الرفض',
            textAlign: TextAlign.right,
            style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('سيُرفض طلب ${req.name}.',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Expanded(child: SizedBox()),
                  Text('سيتلقى إشعار رفض فوري ويُمسح الكاش المحلي على جهازه.',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 11, color: AppColors.error, fontFamily: 'Tajawal')),
                  SizedBox(width: 6),
                  Icon(Icons.info_outline, size: 13, color: AppColors.error),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء',
                style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              provider.rejectRequest(req.uid);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✗ تم رفض ${req.name} وإرسال إشعار له',
                      style: const TextStyle(fontFamily: 'Tajawal')),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('تأكيد الرفض',
                style: TextStyle(color: Colors.white, fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  Color _statusColor(JoinRequestStatus s) {
    switch (s) {
      case JoinRequestStatus.pending:  return AppColors.warning;
      case JoinRequestStatus.accepted: return AppColors.success;
      case JoinRequestStatus.rejected: return AppColors.error;
    }
  }

  IconData _statusIcon(JoinRequestStatus s) {
    switch (s) {
      case JoinRequestStatus.pending:  return Icons.pending_outlined;
      case JoinRequestStatus.accepted: return Icons.check_circle_outline;
      case JoinRequestStatus.rejected: return Icons.cancel_outlined;
    }
  }

  String _statusLabel(JoinRequestStatus s) {
    switch (s) {
      case JoinRequestStatus.pending:  return 'معلق';
      case JoinRequestStatus.accepted: return 'مقبول';
      case JoinRequestStatus.rejected: return 'مرفوض';
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes}د';
    if (diff.inHours < 24)   return 'منذ ${diff.inHours}س';
    return 'منذ ${diff.inDays}ي';
  }
}

// ── Permission Row Widget ─────────────────────────────────────

class _PermRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PermRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontFamily: 'Tajawal')),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 13, color: AppColors.warning),
        ],
      ),
    );
  }
}

// ── Petition Section Widget — طلبات المساعدة الطارئة ─────────────────────────

class _PetitionSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('petitions')
          .where('status', isEqualTo: 'pending')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final docs = snap.data!.docs;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.error.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Row(children: [
                  const Icon(Icons.sos_outlined, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${docs.length} طلب مساعدة طارئة',
                    style: const TextStyle(
                        color: AppColors.error,
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                ]),
              ),
              ...docs.map((doc) {
                final d       = doc.data() as Map<String, dynamic>;
                final uid     = d['uid'] as String? ?? doc.id;
                final ts      = (d['timestamp'] as Timestamp?)?.toDate();
                final timeStr = ts != null
                    ? 'منذ ${DateTime.now().difference(ts).inMinutes}د'
                    : '—';

                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(uid,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontFamily: 'Courier',
                                  fontSize: 11)),
                          Text(d['message'] ?? 'طلب مساعدة',
                              style: const TextStyle(
                                  color: AppColors.text,
                                  fontFamily: 'Tajawal',
                                  fontSize: 12)),
                          Text(timeStr,
                              style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  fontFamily: 'Tajawal')),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        FirebaseFirestore.instance
                            .collection('petitions')
                            .doc(uid)
                            .update({'status': 'acknowledged'});
                      },
                      icon: const Icon(Icons.check_outlined,
                          size: 14, color: AppColors.success),
                      label: const Text('تم الاستلام',
                          style: TextStyle(
                              color: AppColors.success,
                              fontFamily: 'Tajawal',
                              fontSize: 12)),
                    ),
                  ]),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
