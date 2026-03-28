import 'package:flutter/material.dart';
import '../constants/colors.dart';

class GoldInput extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final Widget? prefixIcon;
  final String? errorText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final int maxLines;

  const GoldInput({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.prefixIcon,
    this.errorText,
    this.keyboardType,
    this.onChanged,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
  });

  @override
  State<GoldInput> createState() => _GoldInputState();
}

class _GoldInputState extends State<GoldInput> {
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            fontFamily: 'Tajawal',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.controller,
          obscureText: widget.obscureText && _obscure,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          maxLength: widget.maxLength,
          textCapitalization: widget.textCapitalization,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 15,
            fontFamily: 'Tajawal',
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
              fontFamily: 'Tajawal',
            ),
            prefixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : widget.prefixIcon,
            errorText: widget.errorText,
            errorStyle: const TextStyle(
              color: AppColors.error,
              fontFamily: 'Tajawal',
            ),
            counterText: '',
            filled: true,
            fillColor: AppColors.backgroundCard,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }
}
