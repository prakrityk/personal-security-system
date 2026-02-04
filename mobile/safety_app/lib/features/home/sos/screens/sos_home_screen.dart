// lib/features/home/sos/screens/sos_home_screen_improved.dart
// ✅ FIXED: Uses SEPARATE provider for personal contacts to prevent state pollution
// ✅ FIXED: Countdown timer now properly uses setState instead of markNeedsBuild

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:safety_app/core/providers/personal_emergency_contact_provider.dart';
import 'package:safety_app/core/providers/permission_provider.dart';
import 'package:safety_app/features/home/sos/widgets/personal_emergency_contacts_widget.dart';
import 'package:safety_app/services/sos_event_service.dart';
import '../widgets/sos_button.dart';

class SosHomeScreen extends ConsumerStatefulWidget {
  const SosHomeScreen({super.key});

  @override
  ConsumerState<SosHomeScreen> createState() => _SosHomeScreenState();
}

class _SosHomeScreenState extends ConsumerState<SosHomeScreen> {
  final SosEventService _sosService = SosEventService();
  static const int _countdownSeconds = 5;

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
                Icons.warning_amber,
                color: AppColors.sosRed,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Confirm SOS Alert')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will immediately alert all your emergency contacts.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 1,
                ),
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
                      'You will have $_countdownSeconds seconds to cancel before SOS is sent.',
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
              Navigator.pop(context);
              _showCountdownAndSend(context, isDark);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sosRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showCountdownAndSend(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _CountdownDialog(
          countdownSeconds: _countdownSeconds,
          isDark: isDark,
          onComplete: () => _sendSosEvent(context, isDark),
        );
      },
    );
  }

  Future<void> _sendSosEvent(BuildContext context, bool isDark) async {
    try {
      // Minimal MVP: no location yet, just record + notify.
      final eventId = await _sosService.createSosEvent(
        triggerType: 'manual',
        eventType: 'panic_button',
        appState: 'foreground',
      );

      print('✅ SOS event created: $eventId');
      _showSOSActivatedConfirmation(context, isDark);
    } catch (e) {
      print('❌ Failed to create SOS event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send SOS. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
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

/// Separate StatefulWidget for countdown to properly handle timer and state
class _CountdownDialog extends StatefulWidget {
  final int countdownSeconds;
  final bool isDark;
  final VoidCallback onComplete;

  const _CountdownDialog({
    required this.countdownSeconds,
    required this.isDark,
    required this.onComplete,
  });

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.countdownSeconds;
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remaining--;
      });

      if (_remaining <= 0) {
        timer.cancel();
        if (mounted) {
          Navigator.of(context).pop(); // close countdown dialog
          widget.onComplete();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Sending SOS...'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SOS will be sent in $_remaining seconds.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'Tap "Cancel" if you are safe.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context).pop(); // close countdown dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('SOS cancelled'),
                backgroundColor: widget.isDark
                    ? AppColors.darkSurface
                    : AppColors.lightSurface,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
              ),
            );
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
