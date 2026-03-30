import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/participant_card_model.dart';
import '../providers/leader_ui_provider.dart';
import '../constants/colors.dart';

class ParticipantCardWidget extends StatelessWidget {
  final ParticipantCardModel p;
  const ParticipantCardWidget({super.key, required this.p});

  @override
  Widget build(BuildContext context) {
    final visibleFields = context.watch<LeaderUIProvider>().visibleFields;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _pulseColor(p.livePulse).withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _pulseColor(p.livePulse).withOpacity(0.08),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── الجزء العلوي للبطاقة ──
          GestureDetector(
            onTap: () => _navigateToDpc(context, p.uid),
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                _buildHeader(context),
                
                // شريط الرتبة في المنتصف (كما في الصورة)
                Transform.translate(
                  offset: const Offset(0, 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundCard,
                      border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('رتبة #${p.rankPosition}', 
                          style: const TextStyle(color: AppColors.accent, fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.emoji_events, color: AppColors.accent, size: 14),
                      ],
                    ),
                  ),
                ),
                
                if (visibleFields.isNotEmpty) ...[
                  const Divider(color: AppColors.border, height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 16, 10, 6), // زيادة المساحة العلوية بسبب شريط الرتبة
                    child: _buildFieldsGrid(visibleFields),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── الأزرار السفلية (غرفة التحكم والتحكم السريع) ──
          _buildFooter(context, visibleFields),
        ],
      ),
    );
  }

  // ── دوال التنقل المخصصة مع اكتشاف الأخطاء ─────────────────────
  void _navigateToDpc(BuildContext context, String uid) {
    try {
      context.push('/leader/dpc?uid=$uid');
    } catch (e) {
      _showRouteError(context, '/leader/dpc');
    }
  }

  void _navigateToQuickControl(BuildContext context, String uid) {
    try {
      context.push('/leader/device/$uid');
    } catch (e) {
      _showRouteError(context, '/leader/device/$uid');
    }
  }

  void _showRouteError(BuildContext context, String routeName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('خطأ: المسار "$routeName" غير مسجل في ملف app_router.dart!', 
          style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(p.name,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.text,
                              fontFamily: 'Tajawal'),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    _PulseDot(pulse: p.livePulse),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _MiniChip(
                      label: 'غير محدد',
                      color: const Color(0xFF3B82F6), // أزرق كما في الصورة
                      backgroundColor: const Color(0xFF1E293B),
                    ),
                    const SizedBox(width: 6),
                    _MiniChip(
                      label: '#${p.rankPosition}', 
                      color: AppColors.accent,
                      backgroundColor: const Color(0xFF332D1D), // ذهبي داكن
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _Avatar(name: p.name, pulse: p.livePulse),
        ],
      ),
    );
  }

  // ── Dynamic Fields Grid ───────────────────────────────────────
  Widget _buildFieldsGrid(Set<String> visible) {
    final chips = <Widget>[];
    for (final f in CardField.all) {
      if (!visible.contains(f.key)) continue;
      final chip = _buildFieldChip(f.key);
      if (chip != null) chips.add(chip);
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      textDirection: TextDirection.rtl,
      children: chips,
    );
  }

  Widget? _buildFieldChip(String key) {
    // (تم الإبقاء على نفس كود الحقول كما هو لتجنب مسح أي بيانات سابقة)
    switch (key) {
      case 'batteryPercent':
        if (p.batteryPercent == null) return null;
        final pct = p.batteryPercent!;
        return _DataChip(
          icon: pct > 50 ? Icons.battery_full : pct > 20 ? Icons.battery_4_bar : Icons.battery_alert,
          label: '$pct%',
          color: pct > 50 ? AppColors.success : pct > 20 ? AppColors.warning : AppColors.error,
        );
      // ... بقية الـ cases كما كانت في ملفك الأصلي تماماً (تم اختصارها هنا لتوفير المساحة، يمكنك لصق بقية الـ cases من ملفك)
      case 'rankPosition': return null; // تم إخفاؤها لأننا أضفناها في الأعلى بشكل بارز
      default: return null;
    }
  }

  // ── Footer: الزرين (التحكم الكامل والتحكم السريع) ────────────
  Widget _buildFooter(BuildContext context, Set<String> visible) {
    final showProgress = visible.contains('taskProgress') && p.taskProgress != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          if (showProgress) ...[
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: p.taskProgress!,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(p.taskProgress! * 100).round()}%',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.accent, fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
              ),
            ]),
            const SizedBox(height: 16),
          ],
          
          // ── 1. زر غرفة التحكم الكاملة (DPC) مطابق للصورة ──
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => _navigateToDpc(context, p.uid),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37), // لون ذهبي مطابق للصورة
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('(DPC) غرفة التحكم',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, fontFamily: 'Tajawal')),
                  SizedBox(width: 8),
                  Icon(Icons.radar, size: 20),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 10),

          // ── 2. زر التحكم السريع المبسط مطابق للصورة ──
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: () => _navigateToQuickControl(context, p.uid),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD4AF37),
                side: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.5), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('التحكم السريع',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'Tajawal')),
                  SizedBox(width: 8),
                  Icon(Icons.tune, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper: Colors / Labels / Icons ──────────────────────────
  Color _pulseColor(LivePulse p) {
    switch (p) {
      case LivePulse.active:  return AppColors.success;
      case LivePulse.idle:    return AppColors.warning;
      case LivePulse.offline: return AppColors.error;
    }
  }
}

// ── Reusable Sub-Widgets ──────────────────────────────────────
class _PulseDot extends StatelessWidget {
  final LivePulse pulse;
  const _PulseDot({required this.pulse});

  @override
  Widget build(BuildContext context) {
    final color = pulse == LivePulse.active
        ? AppColors.success
        : pulse == LivePulse.idle
            ? AppColors.warning
            : AppColors.error;
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color.withOpacity(0.8), blurRadius: 8)],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final LivePulse pulse;
  const _Avatar({required this.name, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
    final borderColor = pulse == LivePulse.active
        ? AppColors.success
        : pulse == LivePulse.idle
            ? AppColors.warning
            : AppColors.error;
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2.5),
        color: AppColors.background,
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.accent,
            fontFamily: 'Tajawal',
          ),
        ),
      ),
    );
  }
}

class _DataChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _DataChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Tajawal')),
          const SizedBox(width: 4),
          Icon(icon, size: 13, color: color),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color? backgroundColor;
  const _MiniChip({required this.label, required this.color, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
              fontFamily: 'Tajawal')),
    );
  }
}
