// // lib/features/home/widgets/account_menu_sheet.dart

// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';
// import 'package:safety_app/core/theme/app_colors.dart';
// import 'package:safety_app/core/theme/app_text_styles.dart';
// import 'package:safety_app/core/providers/auth_provider.dart';
// import 'package:safety_app/routes/app_router.dart';
// import '../../core/widgets/theme_selector.dart';

// class AccountMenuSheet extends ConsumerWidget {
//   const AccountMenuSheet({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final userState = ref.watch(authStateProvider);
//     final isDark = Theme.of(context).brightness == Brightness.dark;

//     final user = userState.value;
//     final userName = user?.fullName ?? 'Guest';
//     final userRole = user?.displayRole ?? 'User';

//     // ✅ FIX: Check if user is a dependent (child or elderly)
//     final roleName = user?.currentRole?.roleName;
//     final isDependent = roleName == 'child' || roleName == 'elderly';

//     return Container(
//       decoration: BoxDecoration(
//         color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
//         borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       padding: const EdgeInsets.all(20),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // Handle bar
//           _buildHandleBar(isDark),
//           const SizedBox(height: 20),

//           // Account Section
//           _buildAccountSection(userName, userRole, isDark),
//           const SizedBox(height: 24),

//           // Theme Selector
//           const ThemeSelector(),

//           // ✅ FIX: Only show logout button if NOT a dependent
//           if (!isDependent) ...[
//             const SizedBox(height: 16),
//             _buildLogoutButton(context, ref),
//           ],

//           const SizedBox(height: 8),
//         ],
//       ),
//     );
//   }

//   Widget _buildHandleBar(bool isDark) {
//     return Container(
//       width: 40,
//       height: 4,
//       decoration: BoxDecoration(
//         color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
//         borderRadius: BorderRadius.circular(2),
//       ),
//     );
//   }

//   Widget _buildAccountSection(String userName, String userRole, bool isDark) {
//     return Row(
//       children: [
//         CircleAvatar(
//           radius: 32,
//           backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
//           child: Icon(
//             Icons.person,
//             color: isDark ? AppColors.darkAccentGreen1 : AppColors.primaryGreen,
//             size: 36,
//           ),
//         ),
//         const SizedBox(width: 16),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 userName,
//                 style: AppTextStyles.h4.copyWith(
//                   color: isDark
//                       ? AppColors.darkOnSurface
//                       : AppColors.lightOnSurface,
//                 ),
//               ),
//               Text(
//                 userRole,
//                 style: AppTextStyles.bodySmall.copyWith(
//                   color: isDark ? AppColors.darkHint : AppColors.lightHint,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
//     return SizedBox(
//       width: double.infinity,
//       child: ElevatedButton.icon(
//         onPressed: () => _handleLogout(context, ref),
//         icon: const Icon(Icons.logout),
//         label: const Text('Logout'),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: AppColors.sosRed,
//           foregroundColor: Colors.white,
//           padding: const EdgeInsets.symmetric(vertical: 16),
//         ),
//       ),
//     );
//   }

//   void _handleLogout(BuildContext context, WidgetRef ref) {
//     print('🔘 Logout button pressed');

//     // Capture auth notifier
//     final authNotifier = ref.read(authStateProvider.notifier);

//     // Close bottom sheet first
//     Navigator.of(context).pop();

//     // Handle logout after sheet closes
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (context.mounted) {
//         _performLogout(context, authNotifier);
//       }
//     });
//   }

//   Future<void> _performLogout(
//     BuildContext context,
//     AuthStateNotifier authNotifier,
//   ) async {
//     if (!context.mounted) return;

//     // Show confirmation dialog
//     final confirm = await _showLogoutConfirmation(context);
//     if (confirm != true || !context.mounted) return;

//     // Show loading dialog
//     _showLoadingDialog(context);

//     try {
//       await authNotifier.logout();

//       if (!context.mounted) return;

//       Navigator.of(context).pop(); // Close loading
//       context.go(AppRouter.login);

//       await Future.delayed(const Duration(milliseconds: 200));

//       if (context.mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Logged out successfully'),
//             backgroundColor: AppColors.primaryGreen,
//             duration: Duration(seconds: 2),
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//       }
//     } catch (e) {
//       if (!context.mounted) return;

//       Navigator.of(context).pop();
//       context.go(AppRouter.login);

//       await Future.delayed(const Duration(milliseconds: 200));

//       if (context.mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Logged out: ${e.toString()}'),
//             backgroundColor: AppColors.sosRed,
//             duration: const Duration(seconds: 3),
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//       }
//     }
//   }

//   Future<bool?> _showLogoutConfirmation(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;

//     return showDialog<bool>(
//       context: context,
//       barrierDismissible: false,
//       builder: (dialogContext) => AlertDialog(
//         backgroundColor: isDark
//             ? AppColors.darkSurface
//             : AppColors.lightSurface,
//         title: Text(
//           'Logout',
//           style: AppTextStyles.h4.copyWith(
//             color: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
//           ),
//         ),
//         content: Text(
//           'Are you sure you want to logout?',
//           style: AppTextStyles.bodyMedium.copyWith(
//             color: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(dialogContext).pop(false),
//             child: Text(
//               'Cancel',
//               style: TextStyle(
//                 color: isDark ? AppColors.darkHint : AppColors.lightHint,
//               ),
//             ),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.of(dialogContext).pop(true),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: AppColors.sosRed,
//               foregroundColor: Colors.white,
//             ),
//             child: const Text('Logout'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showLoadingDialog(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (loadingContext) => PopScope(
//         canPop: false,
//         child: Center(
//           child: Container(
//             padding: const EdgeInsets.all(24),
//             decoration: BoxDecoration(
//               color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 CircularProgressIndicator(
//                   color: isDark
//                       ? AppColors.darkAccentGreen1
//                       : AppColors.primaryGreen,
//                 ),
//                 const SizedBox(height: 16),
//                 Text(
//                   'Logging out...',
//                   style: AppTextStyles.bodyMedium.copyWith(
//                     color: isDark
//                         ? AppColors.darkOnSurface
//                         : AppColors.lightOnSurface,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
