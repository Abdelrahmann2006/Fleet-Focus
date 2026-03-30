import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/participant_card_model.dart';
import '../providers/leader_ui_provider.dart';
import '../constants/colors.dart';

/// بطاقة المشارك الديناميكية
/// تعرض الحقول المحددة في LeaderUIProvider فقط
class ParticipantCardWidget extends StatelessWidget {
  final ParticipantCardModel p;
  const ParticipantCardWidget({super.key, required this.p});

  @override
  Widget build(BuildContext context) {
    final visibleFields = context.watch<LeaderUIProvider>().visibleFields;

    // تم تغليف البطاقة بالكامل بـ GestureDetector لتفتح غرفة التحكم عند الضغط على أي مكان
    return GestureDetector(
      onTap: () => context.push('/leader/dpc?uid=${p.uid}'),
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _pulseColor(p.livePulse).withOpacity(0.35)),
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
            // ── Header ────────────────────────────────────────────
            _buildHeader(context),

            // ── Fields Grid ───────────────────────────────────────
            if (visibleFields.isNotEmpty) ...[
              const Divider(color: AppColors.border, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: _buildFieldsGrid(visibleFields),
              ),
            ],

            // ── Footer: Task Progress + Control Buttons ────────
            _buildFooter(context, visibleFields),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
      child: Row(
        children: [
          const Spacer(), // تم إزالة الزر الصغير من هنا لترتيب التصميم
          // اسم + كود + رتبة
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulseDot(pulse: p.livePulse),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(p.name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                              fontFamily: 'Tajawal'),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MiniChip(
                      label: '#${p.rankPosition}',
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 4),
                    _MiniChip(label: p.code, color: AppColors.info),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // الأفاتار
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
      spacing: 5,
      runSpacing: 5,
      alignment: WrapAlignment.end,
      children: chips,
    );
  }

  Widget? _buildFieldChip(String key) {
    switch (key) {
      case 'batteryPercent':
        if (p.batteryPercent == null) return null;
        final pct = p.batteryPercent!;
        return _DataChip(
          icon: pct > 50
              ? Icons.battery_full
              : pct > 20
                  ? Icons.battery_4_bar
                  : Icons.battery_alert,
          label: '$pct%',
          color: pct > 50
              ? AppColors.success
              : pct > 20
                  ? AppColors.warning
                  : AppColors.error,
        );
      case 'batteryHealth':
        if (p.batteryHealth == null) return null;
        return _DataChip(
          icon: Icons.favorite_outline,
          label: _batteryHealthLabel(p.batteryHealth!),
          color: _batteryHealthColor(p.batteryHealth!),
        );
      case 'obedienceGrade':
        if (p.obedienceGrade == null) return null;
        return _DataChip(
          icon: Icons.military_tech_outlined,
          label: '${p.obedienceGrade}%',
          color: _gradeColor(p.obedienceGrade!),
        );
      case 'rebellionStatus':
        if (p.rebellionStatus == null) return null;
        return _DataChip(
          icon: p.rebellionStatus! ? Icons.warning_amber : Icons.check_circle_outline,
          label: p.rebellionStatus! ? 'تمرد' : 'ممتثل',
          color: p.rebellionStatus! ? AppColors.error : AppColors.success,
        );
      case 'focusApp':
        if (p.focusApp == null) return null;
        return _DataChip(
          icon: Icons.apps_outlined,
          label: p.focusApp!.split('.').last,
          color: AppColors.textSecondary,
        );
      case 'physicalPresence':
        if (p.physicalPresence == null) return null;
        return _DataChip(
          icon: _presenceIcon(p.physicalPresence!),
          label: _presenceLabel(p.physicalPresence!),
          color: AppColors.info,
        );
      case 'ambientLight':
        if (p.ambientLight == null) return null;
        return _DataChip(
          icon: Icons.wb_sunny_outlined,
          label: '${p.ambientLight} lux',
          color: const Color(0xFFD4A017),
        );
      case 'activityState':
        if (p.activityState == null) return null;
        return _DataChip(
          icon: _activityIcon(p.activityState!),
          label: _activityLabel(p.activityState!),
          color: _activityColor(p.activityState!),
        );
      case 'storageHealth':
        if (p.storageHealth == null) return null;
        return _DataChip(
          icon: Icons.storage_outlined,
          label: '${p.storageHealth}% حر',
          color: p.storageHealth! > 30 ? AppColors.success : AppColors.warning,
        );
      case 'adminShield':
        if (p.adminShield == null) return null;
        return _DataChip(
          icon: p.adminShield! ? Icons.security : Icons.security_update_warning,
          label: p.adminShield! ? 'Admin ✓' : 'Admin ✗',
          color: p.adminShield! ? AppColors.success : AppColors.error,
        );
      case 'connectionQuality':
        if (p.connectionQuality == null) return null;
        return _DataChip(
          icon: Icons.signal_cellular_alt,
          label: _connLabel(p.connectionQuality!),
          color: _connColor(p.connectionQuality!),
        );
      case 'credits':
        return _DataChip(
          icon: Icons.account_balance_wallet_outlined,
          label: '${p.credits > 0 ? '+' : ''}${p.credits}',
          color: p.credits >= 0 ? AppColors.success : AppColors.error,
        );
      case 'stressIndex':
        if (p.stressIndex == null) return null;
        return _DataChip(
          icon: Icons.psychology_outlined,
          label: 'توتر ${p.stressIndex}%',
          color: _stressColor(p.stressIndex!),
        );
      case 'ambientNoise':
        if (p.ambientNoise == null) return null;
        return _DataChip(
          icon: Icons.volume_up_outlined,
          label: '${p.ambientNoise} dB',
          color: p.ambientNoise! > 70 ? AppColors.warning : AppColors.textSecondary,
        );
      case 'deviceOrientation':
        if (p.deviceOrientation == null) return null;
        return _DataChip(
          icon: p.deviceOrientation! == OrientationMode.portrait
              ? Icons.stay_current_portrait
              : Icons.stay_current_landscape,
          label: p.deviceOrientation! == OrientationMode.portrait ? 'عمودي' : 'أفقي',
          color: AppColors.textSecondary,
        );
      case 'lightExposure':
        if (p.lightExposure == null) return null;
        return _DataChip(
          icon: Icons.light_mode_outlined,
          label: _lightLabel(p.lightExposure!),
          color: const Color(0xFFD4A017),
        );
      case 'rankPosition':
        return _DataChip(
          icon: Icons.emoji_events_outlined,
          label: 'رتبة #${p.rankPosition}',
          color: AppColors.accent,
        );
      case 'geofenceName':
        if (p.geofenceName == null) return null;
        return _DataChip(
          icon: Icons.location_on_outlined,
          label: p.geofenceName!,
          color: const Color(0xFF9F7AEA),
        );
      case 'appUsagePulse':
        if (p.appUsagePulse == null) return null;
        return _DataChip(
          icon: Icons.bar_chart_outlined,
          label: '${p.appUsagePulse} تطبيق/س',
          color: AppColors.info,
        );
      case 'physicalStamina':
        if (p.physicalStamina == null) return null;
        return _DataChip(
          icon: Icons.fitness_center_outlined,
          label: 'قدرة ${p.physicalStamina}%',
          color: _gradeColor(p.physicalStamina!),
        );
      case 'sleepDebt':
        if (p.sleepDebt == null) return null;
        return _DataChip(
          icon: Icons.bedtime_outlined,
          label: 'نوم -${p.sleepDebt!.toStringAsFixed(1)}س',
          color: p.sleepDebt! > 3 ? AppColors.error : AppColors.warning,
        );
      case 'currentPosture':
        if (p.currentPosture == null) return null;
        return _DataChip(
          icon: _postureIcon(p.currentPosture!),
          label: _postureLabel(p.currentPosture!),
          color: AppColors.textSecondary,
        );
      case 'liveBlur':
        if (p.liveBlur == null) return null;
        return _DataChip(
          icon: p.liveBlur! ? Icons.blur_on : Icons.blur_off,
          label: p.liveBlur! ? 'ضبابي' : 'واضح',
          color: p.liveBlur! ? AppColors.warning : AppColors.success,
        );
      case 'backspaceCount':
        if (p.backspaceCount == null) return null;
        return _DataChip(
          icon: Icons.backspace_outlined,
          label: '${p.backspaceCount}/س',
          color: p.backspaceCount! > 30 ? AppColors.warning : AppColors.textSecondary,
        );
      case 'emotionalTone':
        if (p.emotionalTone == null) return null;
        return _DataChip(
          icon: _emotionIcon(p.emotionalTone!),
          label: _emotionLabel(p.emotionalTone!),
          color: _emotionColor(p.emotionalTone!),
        );
      case 'antiCheatStatus':
        if (p.antiCheatStatus == null) return null;
        return _DataChip(
          icon: p.antiCheatStatus! == AntiCheatStatus.clean
              ? Icons.verified_outlined
              : Icons.gpp_bad_outlined,
          label: _cheatLabel(p.antiCheatStatus!),
          color: _cheatColor(p.antiCheatStatus!),
        );
      case 'lastCommunication':
        if (p.lastCommunication == null) return null;
        final mins = DateTime.now().difference(p.lastCommunication!).inMinutes;
        return _DataChip(
          icon: Icons.access_time_outlined,
          label: '${mins}د',
          color: mins > 60 ? AppColors.error : AppColors.textSecondary,
        );
      case 'nextJob':
        if (p.nextJob == null) return null;
        return _DataChip(
          icon: Icons.work_outline,
          label: p.nextJob!,
          color: AppColors.info,
        );
      case 'nextJobCountdown':
        if (p.nextJobCountdown == null) return null;
        final d = p.nextJobCountdown!;
        return _DataChip(
          icon: Icons.timer_outlined,
          label: '${d.inHours}س ${d.inMinutes.remainder(60)}د',
          color: AppColors.accent,
        );
      case 'classification':
        if (p.classification == null) return null;
        return _DataChip(
          icon: p.classification! == Classification.resident
              ? Icons.home_outlined
              : Icons.directions_bus_outlined,
          label: p.classification! == Classification.resident ? 'مقيم' : 'وافد',
          color: const Color(0xFF9F7AEA),
        );
      case 'loyaltyStreak':
        if (p.loyaltyStreak == null) return null;
        return _DataChip(
          icon: Icons.local_fire_department_outlined,
          label: '${p.loyaltyStreak}ي',
          color: AppColors.warning,
        );
      case 'deceptionProbability':
        if (p.deceptionProbability == null) return null;
        return _DataChip(
          icon: Icons.masks_outlined,
          label: 'خداع ${p.deceptionProbability}%',
          color: _stressColor(p.deceptionProbability!),
        );
      case 'emotionalVolatility':
        if (p.emotionalVolatility == null) return null;
        return _DataChip(
          icon: Icons.show_chart,
          label: 'تقلب ${p.emotionalVolatility}%',
          color: _stressColor(p.emotionalVolatility!),
        );
      case 'cognitiveLoad':
        if (p.cognitiveLoad == null) return null;
        return _DataChip(
          icon: Icons.memory_outlined,
          label: 'حمل ${p.cognitiveLoad}%',
          color: _stressColor(p.cognitiveLoad!),
        );
      case 'spaceDistance':
        if (p.spaceDistance == null) return null;
        return _DataChip(
          icon: Icons.social_distance_outlined,
          label: '${p.spaceDistance!.toStringAsFixed(0)}م',
          color: AppColors.textSecondary,
        );
      case 'debtToCreditRatio':
        if (p.debtToCreditRatio == null) return null;
        return _DataChip(
          icon: Icons.balance_outlined,
          label: p.debtToCreditRatio!.toStringAsFixed(2),
          color: p.debtToCreditRatio! > 1.5 ? AppColors.error : AppColors.success,
        );
      case 'pleadingQuota':
        if (p.pleadingQuota == null) return null;
        return _DataChip(
          icon: Icons.front_hand_outlined,
          label: 'استجداء ${p.pleadingQuota}%',
          color: AppColors.textSecondary,
        );
      case 'currentJob':
        if (p.currentJob == null) return null;
        return _DataChip(
          icon: Icons.badge_outlined,
          label: p.currentJob!,
          color: AppColors.textSecondary,
        );
      case 'inventoryExpiry':
        if (p.inventoryExpiry == null) return null;
        final days = p.inventoryExpiry!.difference(DateTime.now()).inDays;
        return _DataChip(
          icon: Icons.inventory_2_outlined,
          label: 'مخزون +$days ي',
          color: days < 5 ? AppColors.error : AppColors.textSecondary,
        );
      default:
        return null;
    }
  }

  // ── Footer: الزرين (التحكم الكامل والتحكم السريع) ────────────

  Widget _buildFooter(BuildContext context, Set<String> visible) {
    final showProgress = visible.contains('taskProgress') && p.taskProgress != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Column(
        children: [
          if (showProgress) ...[
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: p.taskProgress!,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${(p.taskProgress! * 100).round()}%',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.accent, fontFamily: 'Tajawal'),
              ),
            ]),
            const SizedBox(height: 12),
          ],
          
          // ── 1. زر غرفة التحكم الكاملة (DPC) ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/leader/dpc?uid=${p.uid}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC9A84C), // لون ذهبي لتمييزه
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.radar, size: 18),
              label: const Text('غرفة التحكم (DPC)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'Tajawal')),
            ),
          ),
          
          const SizedBox(height: 8),

          // ── 2. زر التحكم السريع المبسط ──
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/leader/device/${p.uid}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: BorderSide(color: AppColors.accent.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('التحكم السريع',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')),
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

  Color _gradeColor(int v) => v >= 70
      ? AppColors.success
      : v >= 40
          ? AppColors.warning
          : AppColors.error;

  Color _stressColor(int v) => v < 40
      ? AppColors.success
      : v < 70
          ? AppColors.warning
          : AppColors.error;

  String _batteryHealthLabel(BatteryHealth h) {
    switch (h) {
      case BatteryHealth.good:     return 'ممتازة';
      case BatteryHealth.fair:     return 'جيدة';
      case BatteryHealth.poor:     return 'ضعيفة';
      case BatteryHealth.critical: return 'حرجة';
    }
  }

  Color _batteryHealthColor(BatteryHealth h) {
    switch (h) {
      case BatteryHealth.good:     return AppColors.success;
      case BatteryHealth.fair:     return AppColors.warning;
      case BatteryHealth.poor:     return AppColors.warning;
      case BatteryHealth.critical: return AppColors.error;
    }
  }

  IconData _presenceIcon(PhysicalPresence p) {
    switch (p) {
      case PhysicalPresence.indoor:  return Icons.home_outlined;
      case PhysicalPresence.outdoor: return Icons.park_outlined;
      case PhysicalPresence.transit: return Icons.directions_car_outlined;
      case PhysicalPresence.unknown: return Icons.help_outline;
    }
  }

    String _presenceLabel(PhysicalPresence p) {
    switch (p) {
      case PhysicalPresence.indoor:  return 'داخلي';
      case PhysicalPresence.outdoor: return 'خارجي';
      case PhysicalPresence.transit: return 'في تنقل';
      case PhysicalPresence.unknown: return 'مجهول';
    }
  }

  IconData _activityIcon(ActivityState a) {
    switch (a) {
      case ActivityState.active:   return Icons.directions_run;
      case ActivityState.idle:     return Icons.pause_circle_outline;
      case ActivityState.sleeping: return Icons.bedtime_outlined;
    }
  }

  String _activityLabel(ActivityState a) {
    switch (a) {
      case ActivityState.active:   return 'نشط';
      case ActivityState.idle:     return 'خامل';
      case ActivityState.sleeping: return 'نائم';
    }
  }

  Color _activityColor(ActivityState a) {
    switch (a) {
      case ActivityState.active:   return AppColors.success;
      case ActivityState.idle:     return AppColors.warning;
      case ActivityState.sleeping: return AppColors.info;
    }
  }

  String _connLabel(ConnectionQuality c) {
    switch (c) {
      case ConnectionQuality.excellent: return 'ممتاز';
      case ConnectionQuality.good:      return 'جيد';
      case ConnectionQuality.poor:      return 'ضعيف';
      case ConnectionQuality.offline:   return 'منقطع';
    }
  }

  Color _connColor(ConnectionQuality c) {
    switch (c) {
      case ConnectionQuality.excellent: return AppColors.success;
      case ConnectionQuality.good:      return AppColors.info;
      case ConnectionQuality.poor:      return AppColors.warning;
      case ConnectionQuality.offline:   return AppColors.error;
    }
  }

  String _lightLabel(LightExposure l) {
    switch (l) {
      case LightExposure.bright: return 'مضيء';
      case LightExposure.dim:    return 'خافت';
      case LightExposure.dark:   return 'مظلم';
    }
  }

  IconData _postureIcon(Posture p) {
    switch (p) {
      case Posture.sitting:  return Icons.event_seat_outlined;
      case Posture.standing: return Icons.accessibility_outlined;
      case Posture.walking:  return Icons.directions_walk;
      case Posture.lying:    return Icons.airline_seat_flat_outlined;
    }
  }

  String _postureLabel(Posture p) {
    switch (p) {
      case Posture.sitting:  return 'جالس';
      case Posture.standing: return 'واقف';
      case Posture.walking:  return 'يمشي';
      case Posture.lying:    return 'مستلقٍ';
    }
  }

  IconData _emotionIcon(EmotionalTone t) {
    switch (t) {
      case EmotionalTone.positive: return Icons.sentiment_very_satisfied_outlined;
      case EmotionalTone.neutral:  return Icons.sentiment_neutral_outlined;
      case EmotionalTone.negative: return Icons.sentiment_dissatisfied_outlined;
      case EmotionalTone.stressed: return Icons.crisis_alert;
    }
  }

  String _emotionLabel(EmotionalTone t) {
    switch (t) {
      case EmotionalTone.positive: return 'إيجابي';
      case EmotionalTone.neutral:  return 'محايد';
      case EmotionalTone.negative: return 'سلبي';
      case EmotionalTone.stressed: return 'متوتر';
    }
  }

  Color _emotionColor(EmotionalTone t) {
    switch (t) {
      case EmotionalTone.positive: return AppColors.success;
      case EmotionalTone.neutral:  return AppColors.info;
      case EmotionalTone.negative: return AppColors.warning;
      case EmotionalTone.stressed: return AppColors.error;
    }
  }

  String _cheatLabel(AntiCheatStatus s) {
    switch (s) {
      case AntiCheatStatus.clean:      return 'نظيف';
      case AntiCheatStatus.suspicious: return 'مشبوه';
      case AntiCheatStatus.flagged:    return 'مُبلَّغ';
    }
  }

  Color _cheatColor(AntiCheatStatus s) {
    switch (s) {
      case AntiCheatStatus.clean:      return AppColors.success;
      case AntiCheatStatus.suspicious: return AppColors.warning;
      case AntiCheatStatus.flagged:    return AppColors.error;
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
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 6)],
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
    final initials = name.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join();
    final borderColor = pulse == LivePulse.active
        ? AppColors.success
        : pulse == LivePulse.idle
            ? AppColors.warning
            : AppColors.error;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
        gradient: const LinearGradient(
          colors: [
            AppColors.backgroundElevated,
            AppColors.backgroundCard,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
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
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              fontFamily: 'Tajawal')),
    );
  }
}
