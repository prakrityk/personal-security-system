// lib/features/account/screens/account_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/features/account/widgets/theme_selector.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../routes/app_router.dart';
import '../widgets/account_header.dart';
import '../widgets/account_action_tile.dart';
import '../widgets/logout_button.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account & Settings'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AccountHeader(),
          const SizedBox(height: 24),

          /// -------- ACCOUNT --------
          Text('Account', style: AppTextStyles.h4),
          const SizedBox(height: 8),

          AccountActionTile(
            icon: Icons.person_outline,
            title: 'Edit Profile',
            onTap: () {
              // TODO: Navigate to profile edit screen
            },
          ),

          AccountActionTile(
            icon: Icons.security,
            title: 'Privacy & Security',
            onTap: () {},
          ),

          const SizedBox(height: 24),

          /// -------- SETTINGS --------
          Text('Appearance', style: AppTextStyles.h4),
          const SizedBox(height: 8),

          const ThemeSelectorTile(),

          const SizedBox(height: 32),

          /// -------- LOGOUT --------
          LogoutButton(
            onLogoutSuccess: () {
              context.go(AppRouter.login);
            },
          ),
        ],
      ),
    );
  }
}
