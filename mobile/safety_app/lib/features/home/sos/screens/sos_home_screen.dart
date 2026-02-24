// lib/features/home/sos/screens/sos_home_screen.dart
//
// Changes from original:
//   - Added location capture at SOS trigger time
//   - Updated to use unified createSosWithVoice() method
//   - Location passed to backend and stored in SOSEvent

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/core/providers/personal_emergency_contact_provider.dart';
import 'package:safety_app/core/providers/permission_provider.dart';
import 'package:safety_app/features/home/sos/widgets/personal_emergency_contacts_widget.dart';
import 'package:safety_app/services/voice_message_service.dart'; // ✅ Only using VoiceMessageService
import '../widgets/sos_button.dart';
import 'package:safety_app/services/device_permission_service.dart';
import 'package:safety_app/core/network/dio_client.dart';

class SosHomeScreen extends ConsumerStatefulWidget {
  const SosHomeScreen({super.key});

  @override
  ConsumerState<SosHomeScreen> createState() => _SosHomeScreenState();
}

class _SosHomeScreenState extends ConsumerState<SosHomeScreen> {
  // ✅ Removed SosEventService - not needed anymore
  late final VoiceMessageService _voiceService;

  static const int _countdownSeconds = 3;

  // Recording overlay state
  bool _showRecordingOverlay = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    
    _voiceService = VoiceMessageService(
      dioClient: ref.read(dioClientProvider),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(personalContactsNotifierProvider.notifier).loadMyContacts();
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _voiceService.dispose();
    super.dispose();
  }

  // ── Get current location helper ──────────────────────────────────────────
  // ── Get current location helper ──────────────────────────────────────────
Future<Position?> _getCurrentLocation() async {
  try {
    // ✅ Permission checks removed - handled at login by DevicePermissionService
    // Just get the location directly
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  } catch (e) {
    print('❌ Location error: $e');
    return null;
  }
}

  // ── Long press: start recording ──────────────────────────────────────────

  void _onLongPressStart() {
    final contactsState = ref.read(personalContactsNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (contactsState.contacts.isEmpty) {
      _showNoContactsDialog(context, isDark);
      return;
    }

    setState(() {
      _showRecordingOverlay = true;
      _recordingSeconds = 0;
    });

    // Tick every second to show progress
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _recordingSeconds++);
    });

    _voiceService.startManualRecording(
      onComplete: (filePath) {
        // 20s hit — auto sends SOS
        _finishRecordingAndSendSOS(filePath);
      },
      onError: (error) {
        _stopRecordingOverlay();
        print('❌ [VoiceMessage] $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      },
    );
  }

  // ── Long press: release → send SOS with recorded audio ──────────────────

  void _onLongPressEnd() {
    if (!_voiceService.isRecording) return;

    _voiceService.stopRecording(
      onComplete: (filePath) => _finishRecordingAndSendSOS(filePath),
      onError: (error) {
        _stopRecordingOverlay();
        print('❌ [VoiceMessage] $error');
      },
    );
  }

  // ── After recording: send SOS with voice using unified endpoint ───────────

  Future<void> _finishRecordingAndSendSOS(String filePath) async {
    _stopRecordingOverlay();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    try {
      // 🔴 GET LOCATION AT SOS TRIGGER TIME
      final position = await _getCurrentLocation();
      
      // ✅ Use unified endpoint that creates SOS + uploads voice in one call
      final result = await _voiceService.createSosWithVoice(
        filePath: filePath, // Has file for voice SOS
        triggerType: 'manual',
        eventType: 'panic_button',
        latitude: position?.latitude,
        longitude: position?.longitude,
        appState: 'foreground',
      );

      if (result != null && result['event_id'] != null) {
        print('✅ [SOS] Event created: ${result['event_id']} with voice: ${result['voice_url']}');
        
        if (!mounted) return;
        _showSOSActivatedConfirmation(context, isDark, withVoice: true);
      } else {
        throw Exception('Failed to create SOS with voice');
      }
    } catch (e) {
      print('❌ [SOS] Failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to send SOS. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _stopRecordingOverlay() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    if (mounted) {
      setState(() {
        _showRecordingOverlay = false;
        _recordingSeconds = 0;
      });
    }
  }

  // ── Tap: existing confirm → countdown → send (no voice) ─────────────────

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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.2), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mic_rounded, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tip: Hold the SOS button to record a voice message with your alert.',
                      style: AppTextStyles.caption.copyWith(color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You will have $_countdownSeconds seconds to cancel.',
                      style: AppTextStyles.caption.copyWith(color: Colors.orange.shade800),
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
            child: const Text('Send SOS'),
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
          onComplete: () => _sendSosEventNoVoice(context, isDark),
        );
      },
    );
  }

  // ✅ FIXED: Now using VoiceMessageService.createSosWithVoice with null filePath
  Future<void> _sendSosEventNoVoice(BuildContext context, bool isDark) async {
    try {
      // 🔴 GET LOCATION AT SOS TRIGGER TIME (even for no-voice SOS)
      final position = await _getCurrentLocation();
      
      // ✅ Use the SAME unified method with null filePath for no-voice SOS
      final result = await _voiceService.createSosWithVoice(
        filePath: null,  // ← No voice file for tap SOS
        triggerType: 'manual',
        eventType: 'panic_button',
        latitude: position?.latitude,
        longitude: position?.longitude,
        appState: 'foreground',
      );

      if (result != null && result['event_id'] != null) {
        print('✅ [SOS] Event created: ${result['event_id']} (no voice)');
        if (!mounted) return;
        _showSOSActivatedConfirmation(context, isDark, withVoice: false);
      } else {
        throw Exception('Failed to create SOS');
      }
    } catch (e) {
      print('❌ [SOS] Failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to send SOS. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // ── UI helpers ───────────────────────────────────────────────────────────

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
              child: const Icon(Icons.warning_amber, color: Colors.orange, size: 24),
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
              backgroundColor: isDark ? AppColors.darkAccentGreen1 : AppColors.primaryGreen,
              foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSOSActivatedConfirmation(BuildContext context, bool isDark,
      {required bool withVoice}) {
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
              child: Icon(
                withVoice ? Icons.mic_rounded : Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                withVoice
                    ? 'SOS sent with voice message'
                    : 'SOS alert sent to all emergency contacts',
                style: const TextStyle(fontWeight: FontWeight.w500),
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

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final permissionAsync = ref.watch(permissionSummaryProvider);

    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  isDark ? AppColors.darkBackground : AppColors.lightBackground,
                  isDark ? AppColors.darkBackground.withOpacity(0.8) : AppColors.lightBackground.withOpacity(0.9),
                ],
              ),
            ),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.read(personalContactsNotifierProvider.notifier).loadMyContacts();
                ref.invalidate(permissionSummaryProvider);
              },
              color: isDark ? AppColors.darkAccentGreen1 : AppColors.primaryGreen,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(1.0),
                        child: SizedBox(
                          width: 305,
                          height: 305,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: Lottie.asset(
                                  'assets/lottie/SoSButtonBG.json',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: SosButton(
                                  onPressed: () => _activateSOS(context, ref),
                                  onLongPressStart: _onLongPressStart,
                                  onLongPressEnd: _onLongPressEnd,
                                  size: 220,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: permissionAsync.when(
                        data: (permissions) {
                          final canEdit = permissions['can_edit_own_contacts'] as bool? ?? false;
                          final isDependent = permissions['user_type'].toString().contains('Dependent');
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface.withOpacity(0.7) : AppColors.lightSurface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isDark ? AppColors.darkDivider.withOpacity(0.5) : AppColors.lightDivider,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
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
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: CircularProgressIndicator(
                              color: isDark ? AppColors.darkAccentGreen1 : AppColors.primaryGreen,
                            ),
                          ),
                        ),
                        error: (error, stack) => _buildErrorState(context, isDark, error.toString(), ref),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),

          // ── Recording overlay ────────────────────────────────────────────
          if (_showRecordingOverlay)
            Positioned.fill(
              child: _RecordingOverlay(
                secondsElapsed: _recordingSeconds,
                maxSeconds: VoiceMessageService.maxRecordingSeconds,
                isDark: isDark,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, bool isDark, String error, WidgetRef ref) {
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
          Text('Failed to Load Permissions', style: AppTextStyles.h4, textAlign: TextAlign.center),
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
            onPressed: () => ref.invalidate(permissionSummaryProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.darkAccentGreen1 : AppColors.primaryGreen,
              foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recording overlay ────────────────────────────────────────────────────────

class _RecordingOverlay extends StatelessWidget {
  final int secondsElapsed;
  final int maxSeconds;
  final bool isDark;

  const _RecordingOverlay({
    required this.secondsElapsed,
    required this.maxSeconds,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final progress = secondsElapsed / maxSeconds;
    final remaining = maxSeconds - secondsElapsed;

    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2623) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.sosRed.withOpacity(0.3),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing mic icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.sosRed.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: AppColors.sosRed,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Recording Voice Message',
                style: TextStyle(
                  color: isDark ? const Color(0xFFF0F0F0) : const Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Release to send SOS',
                style: TextStyle(
                  color: AppColors.sosRed,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: isDark ? const Color(0xFF3E4340) : const Color(0xFFE0E0E0),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sosRed),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                remaining > 0 ? 'Auto-sends in ${remaining}s' : 'Sending...',
                style: TextStyle(
                  color: isDark ? const Color(0xFF9E9E9E) : const Color(0xFF9E9E9E),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Countdown dialog ───────────────────────────────────────────────

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
      setState(() => _remaining--);
      if (_remaining <= 0) {
        timer.cancel();
        if (mounted) {
          Navigator.of(context).pop();
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
          Text('SOS will be sent in $_remaining seconds.', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 12),
          const Text('Tap "Cancel" if you are safe.', style: AppTextStyles.caption),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context).pop();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('SOS cancelled'),
                backgroundColor: widget.isDark ? AppColors.darkSurface : AppColors.lightSurface,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

// Provider at the bottom
final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient();
});