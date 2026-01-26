import 'package:flutter/material.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';

class SafetyToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isEnabled;
  final ValueChanged<bool> onToggle;
  final Color? accentColor;

  const SafetyToggleTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.isEnabled,
    required this.onToggle,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEnabled
              ? AppColors.primaryGreen.withOpacity(0.3)
              : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onToggle(!isEnabled),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon Container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primaryGreen, size: 24),
                ),
                const SizedBox(width: 16),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: isDark
                              ? AppColors.darkOnSurface
                              : AppColors.lightOnSurface,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.darkHint
                                : AppColors.lightHint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Toggle Switch
                Switch(
                  value: isEnabled,
                  onChanged: onToggle,
                  activeColor: AppColors.primaryGreen,
                  activeTrackColor: AppColors.primaryGreen.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
