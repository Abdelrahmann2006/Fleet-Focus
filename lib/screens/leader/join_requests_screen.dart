import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/participant_stream_provider.dart';
import '../../services/firestore_service.dart';

/// شاشة مركز الإشعارات والطلبات (مدمجة مع الاستمارات وطلبات الاستغاثة)
class JoinRequestsScreen extends StatefulWidget {
  const JoinRequestsScreen({super.key});

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen> {
  @override
  Widget build(BuildContext context) {
    final leaderUid = context.read<AuthProvider>().user?.uid ?? '';

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService().watchLeaderNotifications(leaderUid),
      builder: (context, allSnap) {
        final allNotifs = allSnap.data ?? [];
        final msgUnread = allNotifs.where((n) => n['type'] == 'message' && n['status'] == 'pending').length;
        final formUnread = allNotifs.where((n) => n['type'] == 'form' && n['status'] == 'pending').length;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.backgroundCard,
              elevation: 0,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('مركز الإشعارات',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.text)),
                  if (msgUnread + formUnread > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(10)),
                      child: Text('${msgUnread + formUnread}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, fontFamily: 'Tajawal')),
                    ),
                  ],
                ],
              ),
              centerTitle: true,
              bottom: TabBar(
                indicatorColor: AppColors.accent,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mail_outline, size: 18),
                        const SizedBox(width: 6),
                        const Text('الرسائل'),
                        if (msgUnread > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                            child: Text('$msgUnread', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.assignment_outlined, size: 18),
                        const SizedBox(width: 6),
                        const Text('الاستمارات'),
                        if (formUnread > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                            child: Text('$formUnread', style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        body: Column(
          children: [
            // ── قسم الرسائل المباشرة وطلبات المساعدة (دائماً في الأعلى) ──
            _PetitionSection(),
            
            // ── تبويبات الإشعارات والاستمارات ──
            Expanded(
              child: TabBarView(
                children: [
                  _buildNotificationsList(leaderUid, 'message'), // تبويب رسائل النظام
                  _buildNotificationsList(leaderUid, 'form'),    // تبويب الاستمارات
                ],
              ),
            ),
          ],
        ),
      ),
    );
  },
  );
  }

  Widget _buildNotificationsList(String leaderUid, String type) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService().watchLeaderNotifications(leaderUid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        
        final items = snapshot.data!.where((n) => n['type'] == type).toList();

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(type == 'message' ? Icons.notifications_off_outlined : Icons.inbox_outlined, 
                     size: 52, color: AppColors.textMuted.withOpacity(0.5)),
                const SizedBox(height: 12),
                Text(type == 'message' ? 'لا توجد إشعارات نظام' : 'لا توجد استمارات معلقة',
                  style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 15)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            final bool isPendingForm = type == 'form' && item['status'] == 'pending';

            return Dismissible(
              key: Key(item['id']),
              direction: isPendingForm ? DismissDirection.none : DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.delete_sweep, color: Colors.white),
              ),
              onDismissed: (_) => FirestoreService().deleteNotification(leaderUid, item['id']),
              child: NotificationCard(item: item, type: type),
            );
          },
        );
      },
    );
  }
}

// ── Petition Section Widget — الخط الساخن (رسائل التابع الطارئة) ─────────────────────────
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
          return const SizedBox.shrink(); // يختفي تماماً إذا لم يكن هناك رسائل
        }

        final docs = snap.data!.docs;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.error.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end, // لدعم اللغة العربية
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${docs.length} رسالة / طلب مباشر',
                      style: const TextStyle(color: AppColors.error, fontFamily: 'Tajawal', fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                  ],
                ),
              ),
              const Divider(color: AppColors.error, height: 1, thickness: 0.2),
              ...docs.map((doc) {
                final d       = doc.data() as Map<String, dynamic>;
                final uid     = d['uid'] as String? ?? doc.id;
                final ts      = (d['timestamp'] as Timestamp?)?.toDate();
                final timeStr = ts != null ? 'منذ ${DateTime.now().difference(ts).inMinutes} دقيقة' : '—';

                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: [
                      // زر الاستلام
                      ElevatedButton.icon(
                        onPressed: () {
                          FirebaseFirestore.instance.collection('petitions').doc(uid).update({'status': 'acknowledged'});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success.withOpacity(0.2),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                        label: const Text('تم الاستلام', style: TextStyle(color: AppColors.success, fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(d['senderName'] ?? uid, style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold)),
                            Text(d['message'] ?? 'طلب مساعدة / رسالة', style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 12)),
                            Text(timeStr, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'Tajawal')),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
// ── بطاقة الإشعار / الاستمارة (Notification Card) ─────────────────────────────
class NotificationCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String type;

  const NotificationCard({super.key, required this.item, required this.type});

  @override
  Widget build(BuildContext context) {
    final bool isForm = type == 'form';
    final String status = item['status'] ?? 'pending';
    final ts = (item['timestamp'] as Timestamp?)?.toDate();
    final timeStr = ts != null ? _formatTime(ts) : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isForm && status == 'pending' ? AppColors.accent.withOpacity(0.5) : AppColors.border),
        boxShadow: isForm && status == 'pending' 
            ? [BoxShadow(color: AppColors.accent.withOpacity(0.05), blurRadius: 10, spreadRadius: 1)] 
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              if (isForm) _buildStatusBadge(status),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(item['senderName'] ?? 'نظام Panopticon',
                    style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w900, fontFamily: 'Tajawal', fontSize: 15)),
                  if (timeStr.isNotEmpty)
                    Text(timeStr, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'Tajawal')),
                ],
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                backgroundColor: isForm ? AppColors.accent.withOpacity(0.1) : AppColors.backgroundElevated,
                child: Icon(isForm ? Icons.assignment_ind_outlined : Icons.mail_outline, 
                            color: isForm ? AppColors.accent : AppColors.textSecondary, size: 20),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(item['body'] ?? '', textAlign: TextAlign.right,
            style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 13, height: 1.4)),
          const SizedBox(height: 16),
          
          if (isForm && status == 'pending')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showReviewDialog(context, item),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent, 
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12)
                ),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('مراجعة الاستمارة واتخاذ القرار', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = AppColors.warning;
    String text = 'قيد الانتظار';
    if (status == 'approved') { color = AppColors.success; text = 'تم القبول'; }
    if (status == 'rejected') { color = AppColors.error; text = 'تم الرفض'; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
    );
  }

  // ── 1. نافذة مراجعة الاستمارة ─────────────────────────────────────────────
  void _showReviewDialog(BuildContext context, Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 50, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(10)),
            ),
            const Text('مراجعة الاستمارة الشاملة', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'Tajawal')),
            const Divider(color: AppColors.border, height: 30, thickness: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  ...(item['payload'] as Map<String, dynamic>? ?? {}).entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(e.key, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(e.value.toString(), textAlign: TextAlign.right, style: const TextStyle(color: AppColors.text, fontSize: 15, fontFamily: 'Tajawal')),
                        const Divider(color: AppColors.border, thickness: 0.5, height: 20),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(child: _actionBtn('رفض وإتلاف الطلب', AppColors.error, () {
                    Navigator.pop(ctx);
                    _confirmReject(context, item);
                  })),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: _actionBtn('الموافقة وتجهيز البروتوكول', AppColors.success, () {
                    Navigator.pop(ctx);
                    _showAcceptProtocolDialog(context, item);
                  })),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color, 
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
      ),
      child: Text(label, style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }

  // ── 2. نافذة تأكيد الرفض (الاحتفاظ بتصميمك الأصلي) ─────────────────────────
  void _confirmReject(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد الرفض والإتلاف', textAlign: TextAlign.right, style: TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('سيتم رفض طلب ${item['senderName']} ووضعه في الأرشيف المرفوض ولن يتمكن من الدخول.', textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final leaderUid = context.read<AuthProvider>().user!.uid;
              await FirestoreService().updateNotificationStatus(leaderUid, item['id'], 'rejected');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('✗ تم رفض ${item['senderName']} بنجاح', style: const TextStyle(fontFamily: 'Tajawal')),
                  backgroundColor: AppColors.error,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('تأكيد الرفض', style: TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── 3. نافذة بروتوكول القبول الشاملة باللون الذهبي والمعاينة الحية ────────
  void _showAcceptProtocolDialog(BuildContext context, Map<String, dynamic> item) {
    String auditSchedule = 'بمجرد استلام الإشعار، بدون إنذار مسبق';
    String locationText = 'لم يُحدد بعد';
    String dressCode = 'حلاقة الشعر واللحية بالكامل، تيشيرت أسود سادة، بنطلون أسود، حذاء أسود.';
    String extraNotes = '';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setS) {
          final ladyName = context.read<AuthProvider>().user?.fullName ?? 'السيدة';
          final assetCode = 'E-${item['senderUid'].toString().substring(0,4).toUpperCase()}';
          
          final fullMessage = _buildFullMessage(
            ladyName: ladyName,
            assetCode: assetCode,
            auditSchedule: auditSchedule,
            locationTimeSection: locationText,
            dressCode: dressCode,
            extraNotes: extraNotes,
          );

          return Dialog(
            backgroundColor: AppColors.backgroundCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.backgroundElevated, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('صياغة الرسالة السيادية وبروتوكول القبول', style: TextStyle(fontFamily: 'Tajawal', color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 16)),
                        SizedBox(width: 8),
                        Icon(Icons.gavel_rounded, color: AppColors.accent, size: 22),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _fieldLabel('توقيت الجرد الإجباري'),
                          _buildTextField('متى سيبدأ الجرد؟', (v) => setS(() => auditSchedule = v), initial: auditSchedule),
                          const SizedBox(height: 12),
                          
                          _fieldLabel('المقر والموعد الدقيق'),
                          _buildTextField('أدخل الإحداثيات والوقت', (v) => setS(() => locationText = v)),
                          const SizedBox(height: 12),

                          _fieldLabel('الزي الرسمي وهيئة المثول'),
                          _buildTextField('تعليمات الزي', (v) => setS(() => dressCode = v), maxLines: 2, initial: dressCode),
                          const SizedBox(height: 12),

                          _fieldLabel('توجيهات إضافية (اختياري)'),
                          _buildTextField('أوامر خاصة تُضاف للرسالة', (v) => setS(() => extraNotes = v), maxLines: 2),
                          const SizedBox(height: 24),

                          const Divider(color: AppColors.border),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('معاينة الرسالة النهائية التي ستصل للتابع:', textAlign: TextAlign.right, style: TextStyle(color: AppColors.text, fontSize: 13, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.accent.withOpacity(0.4), width: 1.5)),
                            child: SelectableText(fullMessage, textDirection: TextDirection.rtl, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontFamily: 'Courier', height: 1.6)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontWeight: FontWeight.bold))),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () async {
                             final leaderUid = context.read<AuthProvider>().user!.uid;
                             // 1. تحديث حالة الإشعار إلى "مقبول"
                             await FirestoreService().updateNotificationStatus(leaderUid, item['id'], 'approved');
                             
                             // 2. إرسال الـ Join Request للتابع (هنا سنضع كود المرحلة الثالثة الخاص بصلاحيات الجهاز)
                             // مؤقتاً سيتم التحديث:
                             await FirebaseFirestore.instance.collection('users').doc(item['senderUid']).update({'applicationStatus': 'join_request_pending', 'joinRequestPayload': fullMessage});

                             if (context.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الرسالة السيادية بنجاح.', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: AppColors.success));
                             }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          icon: const Icon(Icons.send_rounded, color: Colors.black, size: 18),
                          label: const Text('اعتماد وإرسال للتابع', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontFamily: 'Tajawal')),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── دوال مساعدة للتصميم والنصوص ───────────────────────────────────────────
  
  Widget _buildTextField(String hint, Function(String) onChange, {int maxLines = 1, String? initial}) {
    return TextFormField(
      initialValue: initial,
      onChanged: onChange,
      maxLines: maxLines,
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 13),
      decoration: _inputDecoration(hint),
    );
  }

  static Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold)),
  );

  static InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintTextDirection: TextDirection.rtl,
    hintStyle: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12),
    filled: true,
    fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.gold.withOpacity(0.8), width: 1.5)),
  );

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24)   return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }

  String _buildFullMessage({
    required String ladyName, required String assetCode, required String auditSchedule,
    required String locationTimeSection, required String dressCode, required String extraNotes,
  }) {
    return '''صادر من: القيادة العليا - السيدة $ladyName
الوجهة: العنصر $assetCode
الحالة: تفعيل بروتوكول "العزل وما قبل المقابلة" (Pre-Interview Lockdown)

بناءً على التماس الانضمام الذي قدمته بملء إرادتك، تقرر منحك فرصة العرض المبدئي للمثول أمام السيدة $ladyName.
اعتباراً من لحظة استلامك لهذا الإشعار، تم تفعيل نظام السيطرة الرقمية الشاملة. جهازك الآن تحت الإدارة عن بُعد، وكيانك بالكامل يخضع لأحكام النظام. اقرأ كل حرف بعناية تامة؛ فالخطأ الأول هو الخطأ الأخير، وعواقبه الطرد النهائي غير القابل للاستئناف.

أولاً: بروتوكول الجرد والرقابة المطلقة
سيُفرض عليك إجراء جرد دقيق وشامل لكافة ممتلكاتك.
- توقيت الجرد: [$auditSchedule]
بمجرد تفعيل الخاصية، ستُقفل شاشة جهازك إجبارياً ولن يُسمح لك بتجاوز شاشة الجرد. بعد رفع البيانات، ستُقرر السيدة وحدها ما يحق لك الاحتفاظ به وما يجب إحضاره يوم المقابلة لتقرير مصيره.

ثانياً: الاستدعاء والمثول المباشر
المقر والموعد: [$locationTimeSection]
- تنبيه تقني حرج: بحلول موعد المقابلة، سيدخل جهازك في حالة "الإغلاق التام" (Total Lockdown)، ولن تُحرر الشاشة إلا بقرار مباشر من السيدة بعد انتهاء المقابلة واعتماد ممتلكاتك في النظام.

ثالثاً: هيئة المثول (الزي الرسمي)
$dressCode

رابعاً: قواعد التواجد الصارمة (غير قابلة للتفاوض أو التبرير)
- التواجد أمام نقطة المقر المحددة قبل الموعد بـ ١٥ دقيقة تماماً.
- يُمنع النطق بأي كلمة، أو المبادرة بالتحية، أو طرق الباب، أو محاولة فتحه بأي شكل.
- قف في وضع الاستعداد، يداك معقودتان خلف ظهرك، ونظرك مثبت نحو الأرض لا يحيد.
- عند حلول التوقيت بالثانية، افتح الباب، وتقدم بخطى ثابتة نحو النقطة المحددة سلفاً، وتجمد في مكانك (مع ترك مسافة متر عن أي شخص مجاور).
- ستظل على هذه الحالة من الثبات التام والسكون المطلق حتى تتفضل السيدة بالظهور.
${extraNotes.isNotEmpty ? '\nتوجيهات إضافية واجبة النفاذ:\n$extraNotes\n' : ''}
خامساً: إقرار الخضوع (المرحلة النهائية)
في حال اجتيازك للتقييم، ورؤية السيدة أنك جدير بالبقاء تحت مظلتها، سيُفرض عليك في نهاية المقابلة قراءة "دستور النظام" كاملاً، والتوقيع عليه بـ "توقيع إلكتروني حي" كإعلان نهائي وإقرار بالتبعية المطلقة.

تحذير نهائي:
التأخر لثانية واحدة، التلاعب أو إخفاء أي عنصر أثناء الجرد، الإخلال بأي تفصيلة في المظهر، أو إبداء أي بادرة تردد أو ضعف، سيؤدي إلى سحق طلبك وإدراجك في القائمة السوداء للنظام للأبد.''';
  }
}
