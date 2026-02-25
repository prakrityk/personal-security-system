// lib/features/account/widgets/logout_button.dart - SIMPLEST FIX

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_router.dart';

class LogoutButton extends ConsumerWidget {
  final VoidCallback? onLogoutSuccess;

  const LogoutButton({super.key, this.onLogoutSuccess});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.logout),
      label: const Text('Logout'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.sosRed,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sosRed,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Logout'),
              ),
            ],
          ),
        );

        if (confirm != true) return;

        // ✅ SIMPLIFIED: No loading dialog, just logout and navigate
        try {
          print('🔓 Starting logout process...');

          // Call logout
          await ref.read(authStateProvider.notifier).logout();

          print('✅ Logout successful, auth state cleared');
          print('🚀 Navigating to login...');

          // ✅ CRITICAL: Use mounted check and navigate immediately
          if (!context.mounted) return;

          // Navigate to login - this will trigger router redirect
          if (onLogoutSuccess != null) {
            onLogoutSuccess!();
          } else {
            context.go(AppRouter.login);
          }
        } catch (e) {
          print('❌ Logout error: $e');

          if (!context.mounted) return;

          // Show error only
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logout failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }
}
