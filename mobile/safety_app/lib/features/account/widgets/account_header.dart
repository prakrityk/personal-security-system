// ===================================================================
// FIXED: account_header.dart — Live profile picture update
// ===================================================================
// lib/features/account/widgets/account_header.dart
//
// WHY THIS WORKS:
// ProfileSectionWidget (dependent, which works) is a StatefulWidget
// holding `_currentProfilePicture` locally and calls setState() right
// after upload — forcing a fresh widget subtree before CachedNetworkImage
// can serve the stale disk cache.
//
// We replicate that same pattern:
//   1. Convert to ConsumerStatefulWidget.
//   2. Hold `_pictureVersion` (epoch ms) in local state.
//   3. On every build, check if authStateProvider picture path changed;
//      if so, bump `_pictureVersion` — same idea as ProfileSectionWidget's
//      setState(() => _currentProfilePicture = newPath).
//   4. Use `'${path}_$_pictureVersion'` as cacheKey → always unique per
//      upload, even when the server reuses the same filename.
// ===================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/profile_picture_widget.dart';

class AccountHeader extends ConsumerStatefulWidget {
  const AccountHeader({super.key});

  @override
  ConsumerState<AccountHeader> createState() => _AccountHeaderState();
}

class _AccountHeaderState extends ConsumerState<AccountHeader> {
  String? _lastKnownPicture;
  int _pictureVersion = 0;

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(authStateProvider);
    final user = userState.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentPicture = user?.profilePicture;

    // Mirror of ProfileSectionWidget's didUpdateWidget pattern:
    // whenever the path coming from the provider changes, generate a new
    // unique version stamp so CachedNetworkImage is forced to re-fetch,
    // regardless of whether the filename is the same or different.
    if (currentPicture != _lastKnownPicture) {
      _lastKnownPicture = currentPicture;
      _pictureVersion = DateTime.now().millisecondsSinceEpoch;
    }

    final pictureCacheKey = currentPicture != null
        ? '${currentPicture}_$_pictureVersion'
        : null;

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
          ProfilePictureWidget(
            profilePicturePath: currentPicture,
            fullName: user?.fullName ?? 'Guest',
            radius: 36,
            showBorder: true,
            cacheKey: pictureCacheKey,
          ),

          const SizedBox(width: 16),

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

          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Profile',
            onPressed: () => context.pushNamed('editProfile'),
          ),
        ],
      ),
    );
  }
}