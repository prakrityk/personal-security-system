// lib/widgets/common/theme_toggle_button.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/theme_provider.dart';

/// A simple icon button to toggle between light and dark theme
class ThemeToggleButton extends ConsumerWidget {
  final double? iconSize;
  final Color? iconColor;

  const ThemeToggleButton({super.key, this.iconSize, this.iconColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      icon: Icon(
        themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
        size: iconSize,
        color:
            iconColor ??
            (isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface),
      ),
      onPressed: () {
        ref.read(themeModeProvider.notifier).toggleTheme();
      },
      tooltip: themeMode == ThemeMode.dark
          ? 'Switch to Light Mode'
          : 'Switch to Dark Mode',
    );
  }
}

/// A switch widget to toggle theme with label
class ThemeToggleSwitch extends ConsumerWidget {
  final String? label;
  final bool showLabel;

  const ThemeToggleSwitch({super.key, this.label, this.showLabel = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel) ...[
          Icon(
            Icons.light_mode,
            size: 20,
            color: themeMode == ThemeMode.light
                ? AppColors.primaryGreen
                : (isDark ? AppColors.darkHint : AppColors.lightHint),
          ),
          const SizedBox(width: 8),
        ],
        Switch(
          value: themeMode == ThemeMode.dark,
          onChanged: (value) {
            ref.read(themeModeProvider.notifier).toggleTheme();
          },
          activeColor: AppColors.primaryGreen,
        ),
        if (showLabel) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.dark_mode,
            size: 20,
            color: themeMode == ThemeMode.dark
                ? AppColors.primaryGreen
                : (isDark ? AppColors.darkHint : AppColors.lightHint),
          ),
        ],
      ],
    );
  }
}

/// A segmented button for theme selection (Light/Dark/System)
class ThemeSegmentedButton extends ConsumerWidget {
  const ThemeSegmentedButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment<ThemeMode>(
          value: ThemeMode.light,
          label: Text('Light'),
          icon: Icon(Icons.light_mode),
        ),
        ButtonSegment<ThemeMode>(
          value: ThemeMode.dark,
          label: Text('Dark'),
          icon: Icon(Icons.dark_mode),
        ),
        ButtonSegment<ThemeMode>(
          value: ThemeMode.system,
          label: Text('System'),
          icon: Icon(Icons.settings_suggest),
        ),
      ],
      selected: {themeMode},
      onSelectionChanged: (Set<ThemeMode> newSelection) {
        ref.read(themeModeProvider.notifier).setThemeMode(newSelection.first);
      },
    );
  }
}
