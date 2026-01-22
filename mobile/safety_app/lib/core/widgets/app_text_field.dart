import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool enabled;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? errorText;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = enabled
        ? (isDark ? const Color(0xFF1F2937) : Colors.white)
        : (isDark
            ? const Color(0xFF1F2937).withOpacity(0.6)
            : Colors.white.withOpacity(0.7));

    final borderColor = isDark
        ? const Color(0xFF374151)
        : const Color(0xFFE5E7EB);

    return SizedBox(
      height: 56,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        enabled: enabled,
        style: AppTextStyles.bodyMedium.copyWith(
          color: enabled
              ? (isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827))
              : (isDark ? AppColors.darkHint : AppColors.lightHint),
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: errorText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: backgroundColor,
          labelStyle: TextStyle(
            color:
                isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
          ),
          hintStyle: const TextStyle(
            color: Color(0xFF9CA3AF),
          ),
          enabledBorder: _outline(borderColor),
          focusedBorder: _outline(AppColors.primaryGreen),
          errorBorder: _outline(
              isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444)),
          focusedErrorBorder: _outline(
              isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444)),
        ),
      ),
    );
  }

  OutlineInputBorder _outline(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: 1),
    );
  }
}
