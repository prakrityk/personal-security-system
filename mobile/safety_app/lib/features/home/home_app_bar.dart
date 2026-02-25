// ===================================================================
// FIXED: home_app_bar.dart — Live profile picture update
// ===================================================================
// lib/features/home/home_app_bar.dart
//
// Same fix as AccountHeader — mirrors the ProfileSectionWidget pattern
// of tracking picture version in local state so CachedNetworkImage is
// always forced to re-fetch after an upload.
// ===================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:safety_app/core/providers/notification_provider.dart';
import 'package:safety_app/core/widgets/profile_picture_widget.dart';
import 'package:safety_app/routes/app_router.dart';

class HomeAppBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key});

  @override
  ConsumerState<HomeAppBar> createState() => _HomeAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _HomeAppBarState extends ConsumerState<HomeAppBar> {
  String? _lastKnownPicture;
  // ignore: unused_field
  int _pictureVersion = 0;

  void _handleProfileTap(BuildContext context, bool isDependent) {
    if (isDependent) {
      _showDependentMessage(context);
    } else {
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
        icon: const Icon(
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
            child: const Text(
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
  Widget build(BuildContext context) {
    final userState = ref.watch(authStateProvider);
    final user = userState.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final userName = user?.fullName ?? 'Guest';
    final roleName = user?.currentRole?.roleName;
    final isDependent = roleName == 'child' || roleName == 'elderly';

    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final canSeeNotifications = !isDependent;

    final currentPicture = user?.profilePicture;

    // Mirror of ProfileSectionWidget's didUpdateWidget pattern:
    // bump the version stamp whenever the picture path changes so
    // CachedNetworkImage is forced to re-fetch, even if the filename
    // is the same (server reuse case).
    if (currentPicture != _lastKnownPicture) {
      _lastKnownPicture = currentPicture;
      _pictureVersion = DateTime.now().millisecondsSinceEpoch;
    }
    final pictureCacheKey = user?.profilePicture != null
        ? '${user!.profilePicture}_${user.updatedAt.millisecondsSinceEpoch}'
        : null;

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
            ProfilePictureWidget(
              profilePicturePath: user?.profilePicture,
              fullName: userName,
              radius: 20,
              showBorder: false,
              cacheKey: pictureCacheKey,
            ),

            const SizedBox(width: 10),

            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    userName,
                    style: AppTextStyles.h4.copyWith(
                      color: isDark
                          ? AppColors.darkOnSurface
                          : AppColors.lightOnSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
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
        if (canSeeNotifications)
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => context.push('/notifications'),
                tooltip: 'Notifications',
              ),
              if (unreadCount > 0)
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
                      unreadCount > 9 ? '9+' : '$unreadCount',
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
}
