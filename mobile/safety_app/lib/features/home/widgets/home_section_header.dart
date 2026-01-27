import 'package:flutter/material.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';

class HomeSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool transparent;
  final Color? iconColor;

  const HomeSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.transparent = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final textColor = transparent
        ? Colors.white
        : isDark
            ? AppColors.darkOnBackground
            : AppColors.lightOnBackground;

    final subTextColor = transparent
        ? Colors.white.withOpacity(0.9)
        : isDark
            ? AppColors.darkHint
            : AppColors.lightHint;

    return Container(
      decoration: transparent
          ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primaryGreen).withOpacity(
                  transparent ? 0.9 : 0.1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 28,
                color: transparent ? Colors.white : iconColor ?? AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.h3.copyWith(
                      color: textColor,
                      shadows: transparent
                          ? [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: subTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
