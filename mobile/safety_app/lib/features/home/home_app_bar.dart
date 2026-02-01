// ===================================================================
// FIXED: home_app_bar.dart - Proper Profile Picture URL
// ===================================================================
// lib/features/home/home_app_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:safety_app/features/account/screens/account_screen.dart';
import 'package:safety_app/core/widgets/profile_picture_widget.dart';
import 'package:safety_app/routes/app_router.dart'; // ✅ Add this import

class HomeAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final int notificationCount;
  final VoidCallback? onNotificationTap;

  const HomeAppBar({
    super.key,
    required this.notificationCount,
    this.onNotificationTap,
  });

  void _handleProfileTap(BuildContext context, bool isDependent) {
    if (isDependent) {
      // ❌ Show message to dependents
      _showDependentMessage(context);
    } else {
      // ✅ Navigate to account screen for non-dependents
      // Navigator.of(
      //   context,
      // ).push(MaterialPageRoute(builder: (_) => const AccountScreen()));
      // ✅ NEW
      context.push(AppRouter.account);
    }
  }

  void _showDependentMessage(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        icon: Icon(
          Icons.shield_outlined,
          color: AppColors.primaryGreen,
          size: 48,
        ),
        title: Text(
          'Account Managed by Guardian',
          style: AppTextStyles.h4,
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Your profile and settings are managed by your guardian for your safety. Please contact them if you need to make any changes.',
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(authStateProvider);
    final user = userState.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final userName = user?.fullName ?? 'Guest';

    // Check if user is dependent
    final roleName = user?.currentRole?.roleName;
    final isDependent = roleName == 'child' || roleName == 'elderly';

    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      centerTitle: false,
      title: InkWell(
        onTap: () => _handleProfileTap(context, isDependent),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ FIXED: Use ProfilePictureWidget instead of manual CircleAvatar
            ProfilePictureWidget(
              profilePicturePath: user?.profilePicture,
              fullName: userName,
              radius: 20,
              showBorder: false,
            ),

            const SizedBox(width: 10),

            // User Name
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Hello, $userName',
                    style: AppTextStyles.h4.copyWith(
                      color: isDark
                          ? AppColors.darkOnSurface
                          : AppColors.lightOnSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  // ✅ Show dependent badge if applicable
                  if (isDependent)
                    Text(
                      'Managed Account',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primaryGreen,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Notifications
        Stack(
          alignment: Alignment.topRight,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: onNotificationTap,
            ),
            if (notificationCount > 0)
              Positioned(
                right: 10,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.sosRed,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    notificationCount > 9 ? '9+' : '$notificationCount',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
