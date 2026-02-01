// lib/features/home/widgets/theme_selector.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/core/providers/theme_provider.dart';

class ThemeSelector extends ConsumerStatefulWidget {
  const ThemeSelector({super.key});

  @override
  ConsumerState<ThemeSelector> createState() => _ThemeSelectorState();
}

class _ThemeSelectorState extends ConsumerState<ThemeSelector> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
      ),
      child: Column(
        children: [
          _buildHeader(themeMode, isDark),
          if (_isExpanded) ...[
            _buildDivider(isDark),
            _buildThemeOption(
              'Light',
              ThemeMode.light,
              Icons.light_mode,
              themeMode,
              isDark,
            ),
            _buildThemeOption(
              'Dark',
              ThemeMode.dark,
              Icons.dark_mode,
              themeMode,
              isDark,
            ),
            _buildThemeOption(
              'System Default',
              ThemeMode.system,
              Icons.settings_brightness,
              themeMode,
              isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeMode themeMode, bool isDark) {
    return ListTile(
      leading: Icon(
        _getThemeIcon(themeMode),
        color: isDark ? AppColors.darkAccentGreen1 : AppColors.primaryGreen,
      ),
      title: Text(
        'Theme',
        style: AppTextStyles.bodyMedium.copyWith(
          color: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildThemeChip(themeMode, isDark),
          const SizedBox(width: 6),
          Icon(
            _isExpanded ? Icons.expand_less : Icons.expand_more,
            color: isDark ? AppColors.darkHint : AppColors.lightHint,
          ),
        ],
      ),
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
    );
  }

  Widget _buildThemeChip(ThemeMode themeMode, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkAccentGreen1 : AppColors.primaryGreen)
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _getThemeLabel(themeMode),
        style: AppTextStyles.labelSmall.copyWith(
          color: isDark ? AppColors.darkAccentGreen1 : AppColors.primaryGreen,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
    );
  }

  Widget _buildThemeOption(
    String label,
    ThemeMode mode,
    IconData icon,
    ThemeMode currentMode,
    bool isDark,
  ) {
    final isSelected = currentMode == mode;

    return ListTile(
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Icon(
          icon,
          size: 20,
          color: isSelected
              ? (isDark ? AppColors.darkAccentGreen1 : AppColors.primaryGreen)
              : (isDark ? AppColors.darkHint : AppColors.lightHint),
        ),
      ),
      title: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(
          color: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: isDark
                  ? AppColors.darkAccentGreen1
                  : AppColors.primaryGreen,
              size: 20,
            )
          : null,
      onTap: () {
        ref.read(themeModeProvider.notifier).setThemeMode(mode);
      },
    );
  }

  IconData _getThemeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.system:
        return Icons.settings_brightness;
    }
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.system:
        return 'System';
    }
  }
}
