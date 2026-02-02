// lib/features/home/sos/screens/sos_home_screen_improved.dart
// ✅ FIXED: Uses SEPARATE provider for personal contacts to prevent state pollution

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:safety_app/core/providers/personal_emergency_contact_provider.dart';
import 'package:safety_app/core/providers/permission_provider.dart';
import 'package:safety_app/features/home/sos/widgets/personal_emergency_contacts_widget.dart';
import '../widgets/sos_button.dart';

class SosHomeScreen extends ConsumerStatefulWidget {
  const SosHomeScreen({super.key});

  @override
  ConsumerState<SosHomeScreen> createState() => _SosHomeScreenState();
}

class _SosHomeScreenState extends ConsumerState<SosHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load personal emergency contacts when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🏠 [SOS Screen] Loading personal contacts');
      ref.read(personalContactsNotifierProvider.notifier).loadMyContacts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userState = ref.watch(authStateProvider);
    final user = userState.value;

    // Get permission summary to determine capabilities
    final permissionAsync = ref.watch(permissionSummaryProvider);

    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isDark ? AppColors.darkBackground : AppColors.lightBackground,
              isDark
                  ? AppColors.darkBackground.withOpacity(0.8)
                  : AppColors.lightBackground.withOpacity(0.9),
            ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            print('🔄 [SOS Screen] Manual refresh triggered');
            ref
                .read(personalContactsNotifierProvider.notifier)
                .loadMyContacts();
            ref.invalidate(permissionSummaryProvider);
          },
          color: isDark ? AppColors.darkAccentGreen1 : AppColors.primaryGreen,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // SOS Button with Lottie Animation Background
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(1.0),
                    child: SizedBox(
                      width: 305,
                      height: 305,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Lottie Animation Background
                          Positioned.fill(
                            child: Lottie.asset(
                              'assets/lottie/SoSButtonBG.json',
                              fit: BoxFit.contain,
                            ),
                          ),
                          // SOS Button
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SosButton(
                              onPressed: () => _activateSOS(context, ref),
                              size: 220,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Emergency Contacts Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: permissionAsync.when(
                    data: (permissions) {
                      final canEdit =
                          permissions['can_edit_own_contacts'] as bool? ??
                          false;
                      final isDependent = permissions['user_type']
                          .toString()
                          .contains('Dependent');

                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface.withOpacity(0.7)
                              : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkDivider.withOpacity(0.5)
                                : AppColors.lightDivider,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isDark ? 0.3 : 0.05,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: PersonalEmergencyContactsWidget(
                          canEdit: canEdit,
                          isDependent: isDependent,
                        ),
                      );
                    },
                    loading: () => Center(
                      child: Container(
                        padding: const EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                          color: isDark
                              ? AppColors.darkAccentGreen1
                              : AppColors.primaryGreen,
                        ),
                      ),
                    ),
                    error: (error, stack) => _buildErrorState(
                      context,
                      isDark,
                      error.toString(),
                      ref,
                    ),
                  ),
                ),

                const SizedBox(height: 100), // Space for bottom nav
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    bool isDark,
    String error,
    WidgetRef ref,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withOpacity(0.1),
            ),
            child: const Icon(Icons.error_outline, color: Colors.red, size: 48),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to Load Permissions',
            style: AppTextStyles.h4,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: AppTextStyles.caption.copyWith(
              color: isDark ? AppColors.darkHint : AppColors.lightHint,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              ref.invalidate(permissionSummaryProvider);
              ref
                  .read(personalContactsNotifierProvider.notifier)
                  .loadMyContacts();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppColors.darkAccentGreen1
                  : AppColors.primaryGreen,
              foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _activateSOS(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contactsState = ref.read(personalContactsNotifierProvider);

    if (contactsState.contacts.isEmpty) {
      _showNoContactsDialog(context, isDark);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.sosRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.emergency,
                color: AppColors.sosRed,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Activate SOS')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send emergency alert to all ${contactsState.contacts.length} contact${contactsState.contacts.length != 1 ? 's' : ''}?',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your contacts will receive your location and an emergency notification.',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement SOS activation
              Navigator.pop(context);
              _showSOSActivatedConfirmation(context, isDark);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sosRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Send Alert'),
          ),
        ],
      ),
    );
  }

  void _showNoContactsDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_amber,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('No Emergency Contacts')),
          ],
        ),
        content: Text(
          'Please add at least one emergency contact before activating SOS.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppColors.darkAccentGreen1
                  : AppColors.primaryGreen,
              foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSOSActivatedConfirmation(BuildContext context, bool isDark) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'SOS alert sent to all emergency contacts',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.sosRed,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
