// lib/features/account/widgets/theme_selector_tile.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_text_styles.dart';

class ThemeSelectorTile extends ConsumerWidget {
  const ThemeSelectorTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return ListTile(
      leading: const Icon(Icons.color_lens_outlined),
      title: const Text('Theme'),
      subtitle: Text(
        themeMode.name.toUpperCase(),
        style: AppTextStyles.bodySmall,
      ),
      onTap: () async {
        final selected = await showModalBottomSheet<ThemeMode>(
          context: context,
          builder: (_) => const _ThemePickerSheet(),
        );

        if (selected != null) {
          ref.read(themeModeProvider.notifier).setThemeMode(selected);
        }
      },
    );
  }
}

class _ThemePickerSheet extends StatelessWidget {
  const _ThemePickerSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: ThemeMode.values.map((mode) {
          return ListTile(
            title: Text(mode.name.toUpperCase()),
            onTap: () => Navigator.pop(context, mode),
          );
        }).toList(),
      ),
    );
  }
}
