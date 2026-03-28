import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/cdn_service.dart';
import '../constants/colors.dart';

/// CdnAudioService — تشغيل الأصوات من JSDelivr CDN
///
/// Singleton — يُنشأ مرة واحدة ويُعاد استخدامه في كل التطبيق
/// يدعم: تشغيل، إيقاف، تنظيف الموارد

class CdnAudioService {
  static final CdnAudioService _instance = CdnAudioService._internal();
  factory CdnAudioService() => _instance;
  CdnAudioService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;

  Future<void> _ensureInit() async {
    if (_isInitialized) return;
    await _player.setReleaseMode(ReleaseMode.stop);
    _isInitialized = true;
  }

  /// تشغيل صوت من CDN عبر URL
  Future<void> playFromUrl(String url) async {
    await _ensureInit();
    try {
      await _player.stop();
      await _player.play(UrlSource(url));
    } catch (e) {
      debugPrint('CdnAudioService: فشل تشغيل $url — $e');
    }
  }

  /// تشغيل صوت باستخدام AppSound enum
  Future<void> play(AppSound sound) async {
    await playFromUrl(sound.url);
  }

  /// تشغيل buzzer (زر التنبيه)
  Future<void> playBuzzer() => play(AppSound.buzzer);

  /// تشغيل صوت النجاح
  Future<void> playSuccess() => play(AppSound.success);

  /// تشغيل صوت التنبيه
  Future<void> playAlert() => play(AppSound.alert);

  /// تشغيل Beep العد التنازلي
  Future<void> playCountdown() => play(AppSound.countdown);

  /// تشغيل صوت الإقصاء
  Future<void> playElimination() => play(AppSound.elimination);

  /// إيقاف التشغيل
  Future<void> stop() async => await _player.stop();

  /// ضبط مستوى الصوت (0.0 - 1.0)
  Future<void> setVolume(double volume) async =>
      await _player.setVolume(volume.clamp(0.0, 1.0));

  /// تحرير الموارد عند انتهاء الاستخدام
  void dispose() => _player.dispose();
}

/// CdnAudioButton — زر يُشغّل صوتاً عند الضغط
class CdnAudioButton extends StatefulWidget {
  final AppSound sound;
  final Widget child;
  final VoidCallback? onPressed;

  const CdnAudioButton({
    super.key,
    required this.sound,
    required this.child,
    this.onPressed,
  });

  @override
  State<CdnAudioButton> createState() => _CdnAudioButtonState();
}

class _CdnAudioButtonState extends State<CdnAudioButton> {
  final _audio = CdnAudioService();
  bool _playing = false;

  Future<void> _handleTap() async {
    setState(() => _playing = true);
    await _audio.play(widget.sound);
    widget.onPressed?.call();
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _playing ? null : _handleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          if (_playing)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accent),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// BuzzerButton — زر جاهز الاستخدام للـ Leader لإطلاق البزر
class BuzzerButton extends StatefulWidget {
  final String label;
  final Color? color;

  const BuzzerButton({
    super.key,
    this.label = 'بزّر',
    this.color,
  });

  @override
  State<BuzzerButton> createState() => _BuzzerButtonState();
}

class _BuzzerButtonState extends State<BuzzerButton>
    with SingleTickerProviderStateMixin {
  final _audio = CdnAudioService();
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.1)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    _pulseCtrl.forward().then((_) => _pulseCtrl.reverse());
    await _audio.playBuzzer();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.error;
    return ScaleTransition(
      scale: _pulseAnim,
      child: GestureDetector(
        onTap: _onTap,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.notifications_active,
                    color: Colors.white, size: 30),
                const SizedBox(height: 4),
                Text(widget.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        fontFamily: 'Tajawal')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
