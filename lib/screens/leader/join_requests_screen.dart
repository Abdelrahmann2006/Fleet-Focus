import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/approval_meta_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/participant_stream_provider.dart';

/// شاشة طلبات الانضمام
/// تقرأ حصراً من Firestore الحقيقي وتدعم بروتوكول الموافقة الصارم
class JoinRequestsScreen extends StatelessWidget {
  const JoinRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final streamProvider = context.watch<ParticipantStreamProvider>();
    final int pendingCount = streamProvider.pendingCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, pendingCount),
            _PetitionSection(),
            Expanded(
              child: _buildLiveList(context, streamProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveList(BuildContext context, ParticipantStreamProvider provider) {
    final requests = provider.pendingRequests;
    if (requests.isEmpty) return _buildEmpty();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _LiveRequestCard(req: requests[i]),
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
                    child: const Text('إعداد بروتوكول القبول',
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

  /// ✦ بروتوكول الموافقة الصارم (النسخة الكاملة)
  void _confirmAccept(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final ladyName = auth.user?.fullName ?? 'السيدة';

    // توليد رمز عنصر فريد
    final assetCode = 'E-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase().substring(4)}';

    // متغيرات النموذج
    String auditSchedule    = 'تفعيل مفاجئ بدون إنذار مسبق';
    String locationType     = 'تحديد الزمان والمكان الآن';
    DateTime? interviewDt;
    final locationCtrl      = TextEditingController();
    final dressCodeCtrl     = TextEditingController(text: 'حلاقة الشعر واللحية بالكامل.\nارتداء تي شيرت أسود سادة، بنطلون أسود، وحذاء رياضي أسود. يُمنع منعاً باتاً وجود أي شعارات أو علامات تجارية.\nيُمنع منعاً باتاً ارتداء أي إكسسوارات، سلاسل، خواتم، أو حتى ساعات يد.');
    final extraNotesCtrl    = TextEditingController();
    bool submitting         = false;

    final auditOptions = [
      'تفعيل مفاجئ بدون إنذار مسبق',
      'في موعد محدد بالضبط (سيتم إشعارك)',
      'سيتم إبلاغك لاحقاً',
    ];

    final locationOptions = [
      'تحديد الزمان والمكان الآن',
      'سيتم إرسال الإحداثيات والموعد لاحقاً',
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          Future<void> pickInterviewTime() async {
            final now  = DateTime.now();
            final date = await showDatePicker(
              context: dialogCtx,
              initialDate: now.add(const Duration(days: 1)),
              firstDate: now,
              lastDate: now.add(const Duration(days: 60)),
              builder: (_, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.gold)), child: child!),
            );
            if (date == null) return;
            final time = await showTimePicker(
              context: dialogCtx,
              initialTime: const TimeOfDay(hour: 10, minute: 0),
              builder: (_, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.gold)), child: child!),
            );
            if (time == null) return;
            setDialogState(() {
              interviewDt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
            });
          }

          final interviewFormatted = interviewDt == null
              ? 'اضغط لاختيار الموعد'
              : '${interviewDt!.day}/${interviewDt!.month}/${interviewDt!.year} — الساعة ${interviewDt!.hour.toString().padLeft(2,'0')}:${interviewDt!.minute.toString().padLeft(2,'0')}';

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
                  Row(
                    children: [
                      const Icon(Icons.gavel_rounded, color: AppColors.gold, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'بروتوكول الموافقة (System Trigger Logic)',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.border, height: 20),

                  _labeledRow('رمز العنصر المخصص:', assetCode, color: AppColors.gold),
                  const SizedBox(height: 16),

                  _fieldLabel('١. بروتوكول الجرد الشامل:'),
                  DropdownButtonFormField<String>(
                    value: auditSchedule,
                    dropdownColor: AppColors.backgroundElevated,
                    style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 13),
                    decoration: _inputDecoration(''),
                    items: auditOptions.map((o) => DropdownMenuItem(value: o, child: Text(o, textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13)))).toList(),
                    onChanged: (v) => setDialogState(() => auditSchedule = v ?? auditSchedule),
                  ),
                  const SizedBox(height: 12),

                  _fieldLabel('٢. الزمان والمكان:'),
                  DropdownButtonFormField<String>(
                    value: locationType,
                    dropdownColor: AppColors.backgroundElevated,
                    style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 13),
                    decoration: _inputDecoration(''),
                    items: locationOptions.map((o) => DropdownMenuItem(value: o, child: Text(o, textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13)))).toList(),
                    onChanged: (v) => setDialogState(() => locationType = v ?? locationType),
                  ),
                  if (locationType == 'تحديد الزمان والمكان الآن') ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: pickInterviewTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, color: AppColors.gold, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(interviewFormatted, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 13))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: locationCtrl,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 13),
                      decoration: _inputDecoration('العنوان/الإحداثيات بدقة'),
                    ),
                  ],
                  const SizedBox(height: 12),

                  _fieldLabel('٣. المظهر العام (الزي الرسمي):'),
                  TextField(
                    controller: dressCodeCtrl,
                    maxLines: 4,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 13),
                    decoration: _inputDecoration('التعليمات الخاصة بالزي...'),
                  ),
                  const SizedBox(height: 12),

                  _fieldLabel('٤. تعليمات إضافية لبروتوكول الحضور (اختياري):'),
                  TextField(
                    controller: extraNotesCtrl,
                    maxLines: 2,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 13),
                    decoration: _inputDecoration('مثال: قف بجوار الباب الحديدي على اليمين...'),
                  ),
                  const SizedBox(height: 16),

                  // رسالة المعاينة الشاملة
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.gold.withOpacity(0.35))),
                    child: Text(
                      _buildFullMessage(
                        name: req.name,
                        assetCode: assetCode,
                        ladyName: ladyName,
                        auditSchedule: auditSchedule,
                        locationType: locationType,
                        interviewStr: interviewFormatted,
                        locationText: locationCtrl.text.trim(),
                        dressCode: dressCodeCtrl.text.trim(),
                        extraNotes: extraNotesCtrl.text.trim(),
                      ),
                      style: const TextStyle(fontSize: 11, color: AppColors.text, fontFamily: 'Tajawal', height: 1.6),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: submitting ? null : () => Navigator.pop(dialogCtx),
                          child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: submitting ? null : () async {
                            if (locationType == 'تحديد الزمان والمكان الآن') {
                              if (interviewDt == null || locationCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تحديد الموعد والمكان بدقة', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: AppColors.error));
                                return;
                              }
                            }

                            setDialogState(() => submitting = true);

                            // تجميع الرسالة كمتغير جاهز للحفظ في Firebase
                            final finalMessage = _buildFullMessage(
                              name: req.name,
                              assetCode: assetCode,
                              ladyName: ladyName,
                              auditSchedule: auditSchedule,
                              locationType: locationType,
                              interviewStr: interviewFormatted,
                              locationText: locationCtrl.text.trim(),
                              dressCode: dressCodeCtrl.text.trim(),
                              extraNotes: extraNotesCtrl.text.trim(),
                            );

                            final metaData = {
                              'ladyName': ladyName,
                              'assetCode': assetCode,
                              'systemMessage': finalMessage, // الرسالة الكاملة هتتسجل هنا
                              'aiContext': "This is the current active protocol. The system is in a transitional 'Pre-Interview Lockdown' phase. Adjust all monitoring parameters, risk scores, and automated responses to align with these strict rules until the final Constitution is signed.",
                            };

                            try {
                              await context.read<ParticipantStreamProvider>().approveWithMeta(
                                uid: req.uid,
                                meta: metaData,
                                assetCode: assetCode,
                              );
                              if (context.mounted) Navigator.pop(dialogCtx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('✓ تم تفعيل بروتوكول النظام وإرساله إلى ${req.name}', style: const TextStyle(fontFamily: 'Tajawal')),
                                  backgroundColor: AppColors.success,
                                ));
                              }
                            } catch (e) {
                              setDialogState(() => submitting = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                          child: submitting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Text('تفعيل وإرسال', style: TextStyle(color: Colors.black, fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13)),
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

  // دوال مساعدة للنافذة
  static Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold)),
  );

  static Widget _labeledRow(String label, String value, {Color? color}) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Text(value, style: TextStyle(color: color ?? AppColors.text, fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
    ],
  );

  static InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintTextDirection: TextDirection.rtl,
    hintStyle: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12),
    filled: true,
    fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.6))),
  );

  void _confirmReject(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('تأكيد الرفض', textAlign: TextAlign.right, style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 16)),
        content: Text('سيُرفض طلب ${req.name} وسيتلقى إشعاراً فورياً.', textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<ParticipantStreamProvider>().rejectRequest(req.uid);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('✗ تم رفض ${req.name}', style: const TextStyle(fontFamily: 'Tajawal')),
                  backgroundColor: AppColors.error,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('تأكيد الرفض', style: TextStyle(color: Colors.white, fontFamily: 'Tajawal')),
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

  /// بناء الرسالة المعقدة الخاصة ببروتوكول القبول بصياغة سيادية صارمة
  static String _buildFullMessage({
    required String name,
    required String assetCode,
    required String ladyName,
    required String auditSchedule,
    required String locationType,
    required String interviewStr,
    required String locationText,
    required String dressCode,
    required String extraNotes,
  }) {
    String locationTimeSection = locationType == 'سيتم إرسال الإحداثيات والموعد لاحقاً'
        ? '[سيتم إرسال إحداثيات الموقع المشفر والتوقيت الدقيق في إشعار لاحق]'
        : 'اليوم: $interviewStr\nالمقر: $locationText';

    return '''[إشعار نظام أمني عالي الأهمية]
صادر من: القيادة العليا - السيدة $ladyName
الوجهة: العنصر $assetCode
الحالة: تفعيل بروتوكول "الجرد وما قبل المقابلة" (Pre-Interview Lockdown)

بناءً على التماس الانضمام الذي قدمته بملء إرادتك، تقرر منحك فرصة العرض المبدئي للمثول أمام السيدة $ladyName.
اعتباراً من لحظة استلامك لهذا الإشعار، تم تفعيل نظام التحكم الرقمي الشامل. جهازك الآن تحت إدارة السيدة عن بُعد، و هاتفك بالكامل يخضع لأحكام النظام. اقرأ كل حرف بعناية تامة؛ فالخطأ الأول هو الأخير، وعواقبه الطرد النهائي غير القابل للاستئناف.

أولاً: بروتوكول الجرد والرقابة المطلقة
سيُفرض عليك إجراء جرد دقيق وشامل لكافة ممتلكاتك.
- توقيت الجرد: [$auditSchedule]
بمجرد حلول وقت الجرد، ستُقفل شاشة جهازك إجبارياً ولن يُسمح لك بتجاوز شاشة الجرد. بعد رفع البيانات، ستُقرر السيدة وحدها ما يحق لك الاحتفاظ به وما يجب إحضاره يوم المقابلة لتقرير مصيره.

ثانياً: الاستدعاء والمثول المباشر لحضور المقابلة
$locationTimeSection

- تنبيه تقني حرج: بحلول موعد المقابلة، سيدخل جهازك في حالة "الإغلاق التام" (Total Lockdown). لن تُحرر الشاشة إلا بقرار مباشر من السيدة بعد انتهاء المقابلة واعتماد ممتلكاتك في النظام.

ثالثاً: هيئة المثول (الزي الرسمي)
$dressCode

رابعاً: قواعد التواجد الصارمة (غير قابلة للتفاوض أو التبرير)
- التواجد أمام نقطة المقر المحددة قبل الموعد بـ ١٥ دقيقة تماماً.
- يُمنع النطق بأي كلمة، أو المبادرة بالتحية، أو طرق الباب، أو محاولة فتحه بأي شكل.
- قف في وضع الاستعداد، يداك معقودتان خلف ظهرك، ونظرك مثبت نحو الأرض لا يحيد.
- عند حلول التوقيت بالثانية، افتح الباب، وتقدم بخطى ثابتة نحو النقطة المحددة سلفاً، وتجمد في مكانك (مع ترك مسافة متر عن أي شخص مجاور).
- ستظل على هذه الحالة من الثبات التام والسكون المطلق حتى تتفضل السيدة بالظهور.
${extraNotes.isNotEmpty ? '\nتوجيهات إضافية واجبة النفاذ:\n$extraNotes' : ''}

خامساً: المرحلة النهائية
في حال اجتيازك للمقابلة، وتقييم السيدة أنك جدير بالبقاء تحت مظلتها، سيُفرض عليك في نهاية المقابلة قراءة "دستور النظام" كاملاً، والتوقيع عليه بـ "توقيع إلكتروني حي" كإعلان نهائي لإقرار الإنضمام.

تحذير نهائي:
التأخر لثانية واحدة، التلاعب أو إخفاء أي عنصر أثناء الجرد، الإخلال بأي تفصيلة في المظهر، أو إبداء أي بادرة تردد أو ضعف، سيؤدي إلى رفض طلبك وإدراجك في القائمة السوداء للنظام للأبد.

القيادة المركزية - نظام Panopticon''';
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
