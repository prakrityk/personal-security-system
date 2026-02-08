// ===================================================================
// UPDATED: account_screen.dart - Block Dependents from Editing
// ===================================================================
// lib/features/account/screens/account_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/features/account/widgets/theme_selector.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../routes/app_router.dart';
import '../widgets/account_header.dart';
import '../widgets/account_action_tile.dart';
import '../widgets/logout_button.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check if user is dependent
    final userState = ref.watch(authStateProvider);
    final user = userState.value;
    final roleName = user?.currentRole?.roleName;
    final isDependent = roleName == 'child' || roleName == 'elderly';

    // ❌ BLOCK DEPENDENTS - Show message instead of account screen
    if (isDependent) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Account'),
          backgroundColor: isDark
              ? AppColors.darkSurface
              : AppColors.lightSurface,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: isDark ? AppColors.darkHint : AppColors.lightHint,
                ),
                const SizedBox(height: 24),
                Text(
                  'Account Managed by Guardian',
                  style: AppTextStyles.h3.copyWith(
                    color: isDark
                        ? AppColors.darkOnSurface
                        : AppColors.lightOnSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your profile and settings are managed by your guardian for your safety.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? AppColors.darkHint : AppColors.lightHint,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryGreen.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            color: AppColors.primaryGreen,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Contact Your Guardian',
                              style: AppTextStyles.labelMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'If you need to update your profile or change settings, please ask your guardian to make the changes for you.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.darkOnSurface
                              : AppColors.lightOnSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ✅ NORMAL ACCOUNT SCREEN for non-dependents
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account & Settings'),
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Header (with single edit button)
          const AccountHeader(),
          const SizedBox(height: 24),

          /// -------- ACCOUNT --------
          Text('Account', style: AppTextStyles.h4),
          const SizedBox(height: 8),

          // ❌ REMOVED: Duplicate "Edit Profile" tile
          // Only keep the edit button in AccountHeader
          AccountActionTile(
            icon: Icons.security,
            title: 'Privacy & Security',
            onTap: () {
              // TODO: Navigate to privacy settings
            },
          ),

          const SizedBox(height: 24),

          /// -------- SETTINGS --------
          Text('Appearance', style: AppTextStyles.h4),
          const SizedBox(height: 8),

          const ThemeSelectorTile(),

          const SizedBox(height: 32),

          /// -------- LOGOUT --------
          // LogoutButton(
          //   onLogoutSuccess: () {
          //     context.go(AppRouter.login);
          //   },
          //),
          const LogoutButton(),
        ],
      ),
    );
  }
}
