// ===================================================================
// FIXED: account_header.dart - Proper Profile Picture URL
// ===================================================================
// lib/features/account/widgets/account_header.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/profile_picture_widget.dart'; // ✅ Use the reusable widget

class AccountHeader extends ConsumerWidget {
  const AccountHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(authStateProvider);
    final user = userState.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
      ),
      child: Row(
        children: [
          // ✅ FIXED: Use ProfilePictureWidget instead of manual CircleAvatar
          ProfilePictureWidget(
            profilePicturePath: user?.profilePicture,
            fullName: user?.fullName ?? 'Guest',
            radius: 36,
            showBorder: true,
          ),

          const SizedBox(width: 16),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.fullName ?? 'Guest',
                  style: AppTextStyles.h4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  user?.displayRole ?? 'User',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.darkHint : AppColors.lightHint,
                  ),
                ),
              ],
            ),
          ),

          // ✅ SINGLE Edit Button
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Profile',
            onPressed: () {
              context.pushNamed('editProfile');
            },
          ),
        ],
      ),
    );
  }
}
