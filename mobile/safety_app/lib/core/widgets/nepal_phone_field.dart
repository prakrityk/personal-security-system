// lib/core/widgets/nepal_phone_field.dart
// A reusable phone input widget with a static Nepal (+977) country code prefix.
// Drop-in replacement for AppTextField wherever phone input is needed.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class NepalPhoneField extends StatelessWidget {
  const NepalPhoneField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.label = "Phone Number",
    this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final String label;
  final ValueChanged<String>? onChanged;

  /// Returns the full phone number with country code (e.g. +97798XXXXXXXX)
  static String fullNumber(String localNumber) {
    final digits = localNumber.replaceAll(RegExp(r'\D'), '');
    return '+977$digits';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderColor = isDark
        ? Colors.white.withOpacity(0.15)
        : Colors.black.withOpacity(0.12);

    final fillColor = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.03);

    final disabledColor = isDark
        ? Colors.white.withOpacity(0.03)
        : Colors.black.withOpacity(0.02);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: enabled ? fillColor : disabledColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              // ── Static country prefix ──────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nepal flag emoji
                    const Text('🇳🇵', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      '+977',
                      style: AppTextStyles.body.copyWith(
                        color: enabled
                            ? (isDark ? Colors.white70 : Colors.black87)
                            : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Decorative non-interactive chevron (visually consistent
                    // with apps that have real dropdowns, but clearly static)
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ],
                ),
              ),

              // ── Local number input ─────────────────────────────────
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType: TextInputType.phone,
                  onChanged: onChanged,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10), // Nepal: 10 digits
                  ],
                  style: AppTextStyles.body.copyWith(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: '98XXXXXXXX',
                    hintStyle: AppTextStyles.body.copyWith(
                      color: isDark ? AppColors.darkHint : AppColors.lightHint,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
