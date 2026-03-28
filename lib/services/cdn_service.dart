/// CdnService — خدمة CDN عبر JSDelivr + GitHub
///
/// الفكرة: كل الأصول الثابتة (صور، أصوات، شعارات) تُرفع على
/// مستودع GitHub عام ثم تُجلب عبر JSDelivr CDN المجاني
/// بدلاً من Firebase Storage → يُلغي تكاليف النطاق الترددي.
///
/// بنية المستودع المقترحة:
///   github.com/{GITHUB_USERNAME}/{GITHUB_REPO}/
///   └── assets/
///       ├── images/
///       │   ├── logo.png
///       │   ├── splash_bg.png
///       │   └── ...
///       └── audio/
///           ├── buzzer.mp3
///           ├── success.mp3
///           └── ...
///
/// رابط CDN الناتج:
///   https://cdn.jsdelivr.net/gh/{GITHUB_USERNAME}/{GITHUB_REPO}@main/assets/...
///
/// ⚠️ استبدل القيمتين أدناه بمعلومات مستودعك الفعلي:

class CdnService {
  // ─────────────────────────────────────────────────────
  //  إعداد المستودع — استبدل هذه القيم بمستودعك الفعلي
  // ─────────────────────────────────────────────────────
  static const String _githubUsername = 'Abdelrahmann2006';
  static const String _githubRepo     = 'competition-assets';
  static const String _branch         = 'main';

  static const String _cdnBase =
      'https://cdn.jsdelivr.net/gh/$_githubUsername/$_githubRepo@$_branch';

  // ─────────────────────────────────────────────────────
  //  روابط الصور
  // ─────────────────────────────────────────────────────
  static String image(String filename) =>
      '$_cdnBase/assets/images/$filename';

  static String logo([String ext = 'png']) =>
      image('logo.$ext');

  static String splashBackground() =>
      image('splash_bg.png');

  static String leaderIcon() =>
      image('leader_icon.png');

  static String participantIcon() =>
      image('participant_icon.png');

  // ─────────────────────────────────────────────────────
  //  روابط الأصوات (Buzzers / FX)
  // ─────────────────────────────────────────────────────
  static String audio(String filename) =>
      '$_cdnBase/assets/audio/$filename';

  static String buzzer()       => audio('buzzer.mp3');
  static String successSound() => audio('success.mp3');
  static String alertSound()   => audio('alert.mp3');
  static String countdownBeep() => audio('countdown_beep.mp3');
  static String eliminationSound() => audio('elimination.mp3');

  // ─────────────────────────────────────────────────────
  //  رابط مخصص لأي ملف بالمسار الكامل
  // ─────────────────────────────────────────────────────
  static String custom(String relativePath) =>
      '$_cdnBase/$relativePath';

  // ─────────────────────────────────────────────────────
  //  معلومات للتشخيص
  // ─────────────────────────────────────────────────────
  static String get cdnBaseUrl => _cdnBase;
  static bool get isConfigured =>
      _githubUsername != 'YOUR_GITHUB_USERNAME' &&
      _githubRepo.isNotEmpty;
}

/// قائمة بكل الأصوات المستخدمة في التطبيق
enum AppSound {
  buzzer,
  success,
  alert,
  countdown,
  elimination;

  String get url {
    switch (this) {
      case AppSound.buzzer:      return CdnService.buzzer();
      case AppSound.success:     return CdnService.successSound();
      case AppSound.alert:       return CdnService.alertSound();
      case AppSound.countdown:   return CdnService.countdownBeep();
      case AppSound.elimination: return CdnService.eliminationSound();
    }
  }
}

/// قائمة بكل الصور الثابتة في التطبيق
enum AppImage {
  logo,
  splashBackground,
  leaderIcon,
  participantIcon;

  String get url {
    switch (this) {
      case AppImage.logo:             return CdnService.logo();
      case AppImage.splashBackground: return CdnService.splashBackground();
      case AppImage.leaderIcon:       return CdnService.leaderIcon();
      case AppImage.participantIcon:  return CdnService.participantIcon();
    }
  }
}
