import 'package:flutter/material.dart';
import '../constants/colors.dart';

class GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outlined;
  final IconData? icon;
  final double? width;

  const GoldButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.outlined = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return SizedBox(
        width: width ?? double.infinity,
        height: 54,
        child: OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.accent, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _child(),
        ),
      );
    }

    return SizedBox(
      width: width ?? double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: loading || onPressed == null
              ? null
              : AppGradients.goldGradient,
          color: loading || onPressed == null
              ? AppColors.border
              : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: onPressed != null && !loading
              ? [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: MaterialButton(
          onPressed: loading ? null : onPressed,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: _child(dark: true),
        ),
      ),
    );
  }

  Widget _child({bool dark = false}) {
    if (loading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: dark ? AppColors.background : AppColors.accent,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: dark ? AppColors.background : AppColors.accent),
          const SizedBox(width: 10),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: dark ? AppColors.background : AppColors.accent,
            fontFamily: 'Tajawal',
          ),
        ),
      ],
    );
  }
}
