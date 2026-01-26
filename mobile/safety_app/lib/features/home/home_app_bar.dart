// lib/features/home/widgets/home_app_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/core/providers/theme_provider.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:safety_app/routes/app_router.dart';

class HomeAppBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  final VoidCallback? onNotificationTap;
  final int notificationCount;

  const HomeAppBar({
    super.key,
    this.onNotificationTap,
    this.notificationCount = 0,
  });

  @override
  ConsumerState<HomeAppBar> createState() => _HomeAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(70);
}

class _HomeAppBarState extends ConsumerState<HomeAppBar> {
  bool _isThemeExpanded = false;

  void _showAccountMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return Consumer(
            builder: (context, ref, child) {
              final themeMode = ref.watch(themeModeProvider);
              final userState = ref.watch(authStateProvider);

              // Get current theme from context (updates immediately)
              final isDark = Theme.of(context).brightness == Brightness.dark;

              final user = userState.value;
              final userName = user?.fullName ?? 'Guest';
              final userRole = user?.displayRole ?? 'User';

              return Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkDivider
                            : AppColors.lightDivider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Account Section
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.primaryGreen.withOpacity(
                            0.1,
                          ),
                          child: Icon(
                            Icons.person,
                            color: isDark
                                ? AppColors.darkAccentGreen1
                                : AppColors.primaryGreen,
                            size: 36,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: AppTextStyles.h4.copyWith(
                                  color: isDark
                                      ? AppColors.darkOnSurface
                                      : AppColors.lightOnSurface,
                                ),
                              ),
                              Text(
                                userRole,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isDark
                                      ? AppColors.darkHint
                                      : AppColors.lightHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Expandable Theme Section
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkBackground
                            : AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkDivider
                              : AppColors.lightDivider,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Theme Header (Expandable)
                          ListTile(
                            leading: Icon(
                              themeMode == ThemeMode.dark
                                  ? Icons.dark_mode
                                  : themeMode == ThemeMode.light
                                  ? Icons.light_mode
                                  : Icons.settings_suggest,
                              color: isDark
                                  ? AppColors.darkAccentGreen1
                                  : AppColors.primaryGreen,
                            ),
                            title: Text(
                              'Theme',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: isDark
                                    ? AppColors.darkOnSurface
                                    : AppColors.lightOnSurface,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (isDark
                                                ? AppColors.darkAccentGreen1
                                                : AppColors.primaryGreen)
                                            .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    themeMode == ThemeMode.dark
                                        ? 'Dark'
                                        : themeMode == ThemeMode.light
                                        ? 'Light'
                                        : 'System',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: isDark
                                          ? AppColors.darkAccentGreen1
                                          : AppColors.primaryGreen,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  _isThemeExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: isDark
                                      ? AppColors.darkHint
                                      : AppColors.lightHint,
                                ),
                              ],
                            ),
                            onTap: () {
                              setModalState(() {
                                _isThemeExpanded = !_isThemeExpanded;
                              });
                            },
                          ),

                          // Expandable Theme Options
                          if (_isThemeExpanded) ...[
                            Divider(
                              height: 1,
                              color: isDark
                                  ? AppColors.darkDivider
                                  : AppColors.lightDivider,
                            ),
                            // Light Mode
                            ListTile(
                              contentPadding: const EdgeInsets.only(
                                left: 72,
                                right: 16,
                              ),
                              title: Text(
                                'Light',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: isDark
                                      ? AppColors.darkOnSurface
                                      : AppColors.lightOnSurface,
                                ),
                              ),
                              trailing: themeMode == ThemeMode.light
                                  ? Icon(
                                      Icons.check_circle,
                                      color: isDark
                                          ? AppColors.darkAccentGreen1
                                          : AppColors.primaryGreen,
                                      size: 20,
                                    )
                                  : null,
                              onTap: () {
                                ref
                                    .read(themeModeProvider.notifier)
                                    .setThemeMode(ThemeMode.light);
                              },
                            ),
                            // Dark Mode
                            ListTile(
                              contentPadding: const EdgeInsets.only(
                                left: 72,
                                right: 16,
                              ),
                              title: Text(
                                'Dark',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: isDark
                                      ? AppColors.darkOnSurface
                                      : AppColors.lightOnSurface,
                                ),
                              ),
                              trailing: themeMode == ThemeMode.dark
                                  ? Icon(
                                      Icons.check_circle,
                                      color: isDark
                                          ? AppColors.darkAccentGreen1
                                          : AppColors.primaryGreen,
                                      size: 20,
                                    )
                                  : null,
                              onTap: () {
                                ref
                                    .read(themeModeProvider.notifier)
                                    .setThemeMode(ThemeMode.dark);
                              },
                            ),
                            // System Default
                            ListTile(
                              contentPadding: const EdgeInsets.only(
                                left: 72,
                                right: 16,
                              ),
                              title: Text(
                                'System Default',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: isDark
                                      ? AppColors.darkOnSurface
                                      : AppColors.lightOnSurface,
                                ),
                              ),
                              trailing: themeMode == ThemeMode.system
                                  ? Icon(
                                      Icons.check_circle,
                                      color: isDark
                                          ? AppColors.darkAccentGreen1
                                          : AppColors.primaryGreen,
                                      size: 20,
                                    )
                                  : null,
                              onTap: () {
                                ref
                                    .read(themeModeProvider.notifier)
                                    .setThemeMode(ThemeMode.system);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(bottomSheetContext); // Close menu

                          // Show confirmation dialog
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: Text('Logout', style: AppTextStyles.h4),
                              content: Text(
                                'Are you sure you want to logout?',
                                style: AppTextStyles.bodyMedium,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.sosRed,
                                  ),
                                  child: const Text('Logout'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true && context.mounted) {
                            // Show loading dialog
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (loadingContext) {
                                final dialogIsDark =
                                    Theme.of(loadingContext).brightness ==
                                    Brightness.dark;
                                return Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: dialogIsDark
                                          ? AppColors.darkSurface
                                          : AppColors.lightSurface,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const CircularProgressIndicator(),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Logging out...',
                                          style: AppTextStyles.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );

                            // Perform logout (now guaranteed to succeed)
                            await ref.read(authStateProvider.notifier).logout();

                            if (context.mounted) {
                              // Close loading dialog
                              Navigator.pop(context);

                              // Navigate to login - use pushReplacement to clear history
                              context.go(AppRouter.login);

                              // Optional: Show success message
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Logged out successfully'),
                                  backgroundColor: AppColors.primaryGreen,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },

                        label: const Text('Logout'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.sosRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userState = ref.watch(authStateProvider);

    final user = userState.value;
    final userName = user?.fullName ?? 'Guest';
    final userRole = user?.hasRole == true ? user?.displayRole : null;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 8,
      ), //always this
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // User Avatar & Info - Clickable
            InkWell(
              onTap: () => _showAccountMenu(context),
              borderRadius: BorderRadius.circular(30),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                    child: Icon(
                      Icons.person,
                      color: isDark
                          ? AppColors.darkAccentGreen1
                          : AppColors.primaryGreen,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Welcome $userName!',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: isDark
                              ? AppColors.darkOnSurface
                              : AppColors.lightOnSurface,
                        ),
                      ),
                      if (userRole != null)
                        Text(
                          userRole,
                          style: AppTextStyles.caption.copyWith(
                            color: isDark
                                ? AppColors.darkHint
                                : AppColors.lightHint,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Notification Icon
            Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: isDark
                        ? AppColors.darkOnSurface
                        : AppColors.lightOnSurface,
                  ),
                  onPressed: widget.onNotificationTap,
                ),
                if (widget.notificationCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.sosRed,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        widget.notificationCount > 9
                            ? '9+'
                            : '${widget.notificationCount}',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
