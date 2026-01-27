// lib/features/account/widgets/account_header.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class AccountHeader extends ConsumerWidget {
  const AccountHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(authStateProvider);
    final user = userState.value;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: AppColors.primaryGreen.withOpacity(0.15),
          child: const Icon(Icons.person, size: 36),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.fullName ?? 'Guest',
                style: AppTextStyles.h4,
              ),
              const SizedBox(height: 4),
              Text(
                user?.displayRole ?? 'User',
                style: AppTextStyles.bodySmall.copyWith(
                  color:
                      isDark ? AppColors.darkHint : AppColors.lightHint,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () {
            // TODO: Profile edit
          },
        ),
      ],
    );
  }
}
