// lib/features/home/home_app_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:safety_app/features/account/screens/account_screen.dart';

class HomeAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final int notificationCount;
  final VoidCallback? onNotificationTap;

  const HomeAppBar({
    super.key,
    required this.notificationCount,
    this.onNotificationTap,
  });

  void _openAccountScreen(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AccountScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(authStateProvider);
    final user = userState.value;

    final userName = user?.fullName ?? 'Guest';

    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      centerTitle: false,
      title: InkWell(
        onTap: () => _openAccountScreen(context),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
              child: Icon(
                Icons.person,
                size: 24,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkAccentGreen1
                    : AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Hello, $userName',
              style: AppTextStyles.h4.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkOnSurface
                    : AppColors.lightOnSurface,
              ),
            ),
          ],
        ),
      ),
      actions: [
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
                  decoration: const BoxDecoration(
                    color: AppColors.sosRed,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    notificationCount > 9 ? '9+' : '$notificationCount',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontSize: 10,
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
