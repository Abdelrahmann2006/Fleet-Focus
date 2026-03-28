import 'dart:async';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/colors.dart';
import '../../services/task_governance_service.dart';
import '../../services/discord_webhook_service.dart';

/// Tab 26 — إدارة المهام والتدوير اليومي
class DpcTaskGovernanceTab extends StatefulWidget {
  final String uid;
  final String assetName;
  const DpcTaskGovernanceTab({super.key, required this.uid, required this.assetName});

  @override
  State<DpcTaskGovernanceTab> createState() => _DpcTaskGovernanceTabState();
}

class _DpcTaskGovernanceTabState extends State<DpcTaskGovernanceTab> {
  final _titleCtrl    = TextEditingController();
  final _calIdCtrl    = TextEditingController();
  final _calKeyCtrl   = TextEditingController();
  bool _rotating      = false;
  bool _checking      = false;
  bool _fetching      = false;
  RoleAssignment? _lastRole;
  FalsificationReport? _potReport;
  List<CalendarEvent> _events = [];
  String _selectedCategory = 'general';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _calIdCtrl.dispose();
    _calKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _rotateRole() async {
    setState(() => _rotating = true);
    final role = await TaskGovernanceService.instance.rotateRole(widget.uid);
    if (mounted) setState(() { _rotating = false; _lastRole = role; });
  }

  Future<void> _checkPoT() async {
    setState(() { _checking = true; _potReport = null; });
    final report = await TaskGovernanceService.instance.checkFalsification(widget.uid);
    if (report.isSuspicious) {
      await DiscordWebhookService.instance.alertPoT(
          widget.uid, widget.assetName, report.windowSec);
    }
    if (mounted) setState(() { _checking = false; _potReport = report; });
  }

  Future<void> _fetchCalendar() async {
    final id  = _calIdCtrl.text.trim();
    final key = _calKeyCtrl.text.trim();
    if (id.isEmpty || key.isEmpty) return;
    setState(() => _fetching = true);
    final events = await TaskGovernanceService.instance.fetchLockoutEvents(
        id, key, widget.uid);
    if (mounted) setState(() { _fetching = false; _events = events; });
  }

  Future<void> _addTask() async {
    final t = _titleCtrl.text.trim();
    if (t.isEmpty) return;
    await TaskGovernanceService.instance.addTask(
      uid:      widget.uid,
      title:    t,
      category: _selectedCategory,
      deadline: DateTime.now().add(const Duration(hours: 24)),
    );
    _titleCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✓ مهمة "$t" أُضيفت', style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppColors.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid.isEmpty) {
      return const Center(child: Text('اختر عنصراً', style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal')));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [

        // ── الدور اليومي ──────────────────────────────────────────────────
        _TaskHdr(label: 'التدوير الخوارزمي للأدوار', icon: Icons.shuffle_outlined),
        const SizedBox(height: 8),
        _RoleRotatorCard(
          rotating: _rotating,
          lastRole: _lastRole,
          uid: widget.uid,
          onRotate: _rotateRole,
        ),
        const SizedBox(height: 20),

        // ── إضافة مهمة ───────────────────────────────────────────────────
        _TaskHdr(label: 'إضافة مهمة جديدة', icon: Icons.add_task_outlined),
        const SizedBox(height: 8),
        _AddTaskPanel(
          titleCtrl: _titleCtrl,
          category: _selectedCategory,
          onCategoryChange: (v) => setState(() => _selectedCategory = v),
          onAdd: _addTask,
        ),
        const SizedBox(height: 16),

        // ── قائمة المهام ──────────────────────────────────────────────────
        _TaskHdr(label: 'المهام الجارية', icon: Icons.list_alt_outlined),
        const SizedBox(height: 8),
        _TaskList(uid: widget.uid),
        const SizedBox(height: 20),

        // ── Proof of Task ─────────────────────────────────────────────────
        _TaskHdr(label: 'كاشف تزوير المهام (PoT)', icon: Icons.fingerprint_outlined),
        const SizedBox(height: 8),
        _PotCard(
          checking: _checking,
          report: _potReport,
          onCheck: _checkPoT,
        ),
        const SizedBox(height: 20),

        // ── Time Dungeon / Google Calendar ────────────────────────────────
        _TaskHdr(label: 'الزنزانة الزمنية — Google Calendar', icon: Icons.calendar_today_outlined),
        const SizedBox(height: 8),
        _CalendarPanel(
          calIdCtrl:  _calIdCtrl,
          calKeyCtrl: _calKeyCtrl,
          events:     _events,
          fetching:   _fetching,
          uid:        widget.uid,
          onFetch:    _fetchCalendar,
          onLock:     (e) => TaskGovernanceService.instance.triggerTimeDungeon(widget.uid, e.start, e.end),
        ),
      ]),
    );
  }
}

// ── بطاقة تدوير الأدوار ──────────────────────────────────────────────────────

class _RoleRotatorCard extends StatelessWidget {
  final bool rotating;
  final RoleAssignment? lastRole;
  final String uid;
  final VoidCallback onRotate;
  const _RoleRotatorCard({
    required this.rotating, required this.lastRole,
    required this.uid, required this.onRotate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        // عرض الدور الأخير من Firestore
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('task_assignments').doc(uid)
              .collection('daily_roles')
              .orderBy('assignedAt', descending: true).limit(1)
              .snapshots(),
          builder: (_, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return const Text('لم يُعيَّن دور بعد',
                  style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12));
            }
            final d    = snap.data!.docs.first.data() as Map<String, dynamic>;
            final role = d['roleAr'] as String? ?? '';
            final ts   = (d['assignedAt'] as Timestamp?)?.toDate();
            return Row(children: [
              if (ts != null) Text(DateFormat('dd/MM HH:mm').format(ts),
                  style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 10)),
              const Spacer(),
              Text(role, style: const TextStyle(color: AppColors.accent,
                  fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(width: 8),
              const Text('الدور الحالي',
                  style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 11)),
            ]);
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: rotating ? null : onRotate,
            icon: rotating ? const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.shuffle_outlined, size: 16),
            label: Text(rotating ? 'جارٍ التدوير…' : 'تدوير الدور الآن',
                style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text('لا يُعاد تعيين نفس الدور ليومين متتاليين',
            textAlign: TextAlign.right,
            style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 10)),
      ]),
    );
  }
}

// ── إضافة مهمة ───────────────────────────────────────────────────────────────

class _AddTaskPanel extends StatelessWidget {
  final TextEditingController titleCtrl;
  final String category;
  final ValueChanged<String> onCategoryChange;
  final VoidCallback onAdd;
  const _AddTaskPanel({required this.titleCtrl, required this.category,
      required this.onCategoryChange, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        DropdownButtonFormField<String>(
          value: category,
          decoration: InputDecoration(
            labelText: 'الفئة',
            labelStyle: const TextStyle(fontFamily: 'Tajawal', color: AppColors.textMuted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          dropdownColor: AppColors.backgroundCard,
          style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.text, fontSize: 13),
          items: const [
            DropdownMenuItem(value: 'general',     child: Text('عام')),
            DropdownMenuItem(value: 'housekeeper', child: Text('عاملة المنزل')),
            DropdownMenuItem(value: 'companion',   child: Text('المرافقة')),
            DropdownMenuItem(value: 'secretary',   child: Text('السكرتيرة')),
          ],
          onChanged: (v) { if (v != null) onCategoryChange(v); },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: titleCtrl,
          textAlign: TextAlign.right,
          textDirection: ui.TextDirection.rtl,
          style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal'),
          decoration: InputDecoration(
            hintText: 'عنوان المهمة',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal'),
            filled: true, fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('إضافة المهمة', style: TextStyle(fontFamily: 'Tajawal')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.info, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10), elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── قائمة المهام ──────────────────────────────────────────────────────────────

class _TaskList extends StatelessWidget {
  final String uid;
  const _TaskList({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('task_assignments').doc(uid).collection('tasks')
          .where('status', whereIn: ['pending', 'in_progress'])
          .orderBy('deadline')
          .limit(20)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: const Text('لا توجد مهام جارية.',
                textAlign: TextAlign.right,
                style: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 12)),
          );
        }
        return Column(
          children: snap.data!.docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final title    = data['title'] as String? ?? '';
            final status   = data['status'] as String? ?? 'pending';
            final deadline = (data['deadline'] as Timestamp?)?.toDate();
            final isLate   = deadline != null && deadline.isBefore(DateTime.now());
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isLate ? AppColors.error.withValues(alpha: 0.07) : AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isLate ? AppColors.error.withValues(alpha: 0.3) : AppColors.border),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_statusAr(status), style: TextStyle(
                      color: _statusColor(status), fontFamily: 'Tajawal', fontSize: 9,
                      fontWeight: FontWeight.w700)),
                ),
                const Spacer(),
                Flexible(child: Text(title,
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 12))),
              ]),
            );
          }).toList(),
        );
      },
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'completed':   return AppColors.success;
      case 'in_progress': return AppColors.info;
      default:            return AppColors.textMuted;
    }
  }

  String _statusAr(String s) {
    switch (s) {
      case 'completed':   return 'مكتملة';
      case 'in_progress': return 'جارية';
      default:            return 'معلقة';
    }
  }
}

// ── PoT Card ────────────────────────────────────────────────────────────────

class _PotCard extends StatelessWidget {
  final bool checking;
  final FalsificationReport? report;
  final VoidCallback onCheck;
  const _PotCard({required this.checking, required this.report, required this.onCheck});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (report != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (report!.isSuspicious ? AppColors.error : AppColors.success).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: (report!.isSuspicious ? AppColors.error : AppColors.success).withValues(alpha: 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(report!.isSuspicious ? '⚠ مشتبه بالتزوير' : '✓ لا شبهة تزوير',
                  style: TextStyle(
                      color: report!.isSuspicious ? AppColors.error : AppColors.success,
                      fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 13)),
              if (report!.isSuspicious)
                Text('${report!.count} مهام في ${report!.windowSec}ث',
                    style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Tajawal', fontSize: 11)),
            ]),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: checking ? null : onCheck,
            icon: checking ? const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search, size: 16),
            label: Text(checking ? 'جارٍ الفحص…' : 'فحص نمط الإنجاز',
                style: const TextStyle(fontFamily: 'Tajawal')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning.withValues(alpha: 0.15),
              foregroundColor: AppColors.warning, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: AppColors.warning.withValues(alpha: 0.4))),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Calendar Panel ────────────────────────────────────────────────────────────

class _CalendarPanel extends StatelessWidget {
  final TextEditingController calIdCtrl, calKeyCtrl;
  final List<CalendarEvent> events;
  final bool fetching;
  final String uid;
  final VoidCallback onFetch;
  final Future<void> Function(CalendarEvent) onLock;
  const _CalendarPanel({
    required this.calIdCtrl, required this.calKeyCtrl,
    required this.events, required this.fetching,
    required this.uid, required this.onFetch, required this.onLock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Text('أحداث Lockout في تقويم Google الخاص',
            style: TextStyle(color: AppColors.info, fontFamily: 'Tajawal', fontSize: 12)),
        const SizedBox(height: 10),
        TextField(controller: calIdCtrl, textAlign: TextAlign.right,
          style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 12),
          decoration: const InputDecoration(hintText: 'Calendar ID',
            hintStyle: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11),
            isDense: true, contentPadding: EdgeInsets.all(8))),
        const SizedBox(height: 6),
        TextField(controller: calKeyCtrl, textAlign: TextAlign.right,
          obscureText: true,
          style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 12),
          decoration: const InputDecoration(hintText: 'API Key',
            hintStyle: TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 11),
            isDense: true, contentPadding: EdgeInsets.all(8))),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: fetching ? null : onFetch,
            icon: fetching ? const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sync, size: 14),
            label: const Text('جلب أحداث Lockout', style: TextStyle(fontFamily: 'Tajawal')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.info, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10), elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        if (events.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...events.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              ElevatedButton(
                onPressed: () => onLock(e),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('قفل', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
              ),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(e.title, style: const TextStyle(color: AppColors.text, fontFamily: 'Tajawal', fontSize: 12)),
                Text('${DateFormat('dd/MM HH:mm').format(e.start)} — ${DateFormat('HH:mm').format(e.end)}',
                    style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Tajawal', fontSize: 10)),
              ]),
            ]),
          )),
        ],
      ]),
    );
  }
}

class _TaskHdr extends StatelessWidget {
  final String label;
  final IconData icon;
  const _TaskHdr({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(children: [
    const Spacer(),
    Text(label, style: const TextStyle(color: AppColors.textSecondary,
        fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 13)),
    const SizedBox(width: 6),
    Icon(icon, color: AppColors.accent, size: 16),
  ]);
}
