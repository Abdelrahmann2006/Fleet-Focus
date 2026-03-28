import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/cdn_service.dart';
import '../constants/colors.dart';

/// CdnImage — Widget لعرض الصور من JSDelivr CDN
///
/// مزايا:
///  - كاش محلي تلقائي (لا تُحمَّل مرتين)
///  - Placeholder أثناء التحميل
///  - Fallback عند فشل التحميل
///  - يدعم جميع صيغ الحجم

class CdnImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const CdnImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  /// استخدام Enum مباشرة
  factory CdnImage.asset(
    AppImage asset, {
    Key? key,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    return CdnImage(
      key: key,
      url: asset.url,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    final img = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) =>
          placeholder ??
          Container(
            color: AppColors.backgroundCard,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
      errorWidget: (context, url, error) =>
          errorWidget ??
          Container(
            color: AppColors.backgroundCard,
            child: const Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.textMuted,
                size: 28,
              ),
            ),
          ),
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: img);
    }
    return img;
  }
}

/// CdnWarningBanner — يُظهر تحذيراً إذا لم يُعدَّ CDN بعد
class CdnWarningBanner extends StatelessWidget {
  const CdnWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (CdnService.isConfigured) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_outlined, color: AppColors.warning, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'CDN غير مُهيَّأ: استبدل GITHUB_USERNAME في cdn_service.dart',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.warning,
                fontFamily: 'Tajawal',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
