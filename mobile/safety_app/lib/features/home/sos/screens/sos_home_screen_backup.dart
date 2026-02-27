// lib/features/home/sos/screens/sos_home_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart'; // ✅ ADDED
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/core/providers/personal_emergency_contact_provider.dart';
import 'package:safety_app/core/providers/permission_provider.dart';
import 'package:safety_app/features/home/sos/widgets/personal_emergency_contacts_widget.dart';
import 'package:safety_app/services/voice_message_service.dart';
import '../widgets/sos_button.dart';
import 'package:safety_app/services/device_permission_service.dart';
import 'package:safety_app/core/network/dio_client.dart';
import 'package:safety_app/features/voice_activation/services/sos_listen_service.dart';
import 'package:safety_app/services/dependent_safety_service.dart';
import 'package:safety_app/core/providers/auth_provider.dart'; // ✅ ADDED
import 'package:safety_app/models/user_model.dart'; // ✅ ADDED

class SosHomeScreen extends ConsumerStatefulWidget {
  const SosHomeScreen({super.key});

  @override
  ConsumerState<SosHomeScreen> createState() => _SosHomeScreenState();
}

class _SosHomeScreenState extends ConsumerState<SosHomeScreen> {
  late final VoiceMessageService _voiceMessageService;
  SOSListenService? _sosListenService;
  bool _isContinuousListeningActive = false;
  bool _isLoadingSettings = false;

  static const int _countdownSeconds = 3;

  // Recording overlay state
  bool _showRecordingOverlay = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    
    print('🎯 [SOS Home] Initializing SOS Home Screen');
    
    _voiceMessageService = VoiceMessageService(
      dioClient: ref.read(dioClientProvider),
    );
    _sosListenService = SOSListenService();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('📞 [SOS Home] Loading personal contacts');
      ref.read(personalContactsNotifierProvider.notifier).loadMyContacts();
      
      // Check if continuous listening should be enabled
      _checkAndStartContinuousListening();
    });
  }

  @override
  void dispose() {
    print('🧹 [SOS Home] Disposing SOS Home Screen');
    _recordingTimer?.cancel();
    _voiceMessageService.dispose();
    super.dispose();
  }

  // ── Check and start continuous listening based on user role and settings ──
  Future<void> _checkAndStartContinuousListening() async {
    setState(() => _isLoadingSettings = true);
    
    try {
      final user = ref.read(authProvider).user;
      
      if (user == null) {
        print('❌ [SOS Home] No user found, cannot start continuous listening');
        setState(() => _isLoadingSettings = false);
        return;
      }
      
      print('👤 [SOS Home] Current user: ${user.fullName}');
      print('👤 [SOS Home] User roles: ${user.roleNames}');
      print('👤 [SOS Home] Is guardian: ${user.isGuardian}');
      print('👤 [SOS Home] Is child: ${user.isChild}');
      print('👤 [SOS Home] Is elderly: ${user.isElderly}');
      
      // For guardians: start if voice is registered
      if (user.isGuardian) {
        if (user.isVoiceRegistered) {
          print('🎤 [SOS Home] Guardian with voice registered - starting continuous listening');
          await _startContinuousListening(user);
        } else {
          print('ℹ️ [SOS Home] Guardian voice not registered - continuous listening disabled');
        }
      }
      // For child/elderly: check dependent safety settings
      else if (user.isChild || user.isElderly) {
        print('🔍 [SOS Home] Checking dependent safety settings for ${user.id}');
        await _checkDependentSettingsAndStart(user);
      }
      else {
        print('ℹ️ [SOS Home] User role not eligible for continuous listening');
      }
    } catch (e) {
      print('❌ [SOS Home] Error checking continuous listening: $e');
    } finally {
      setState(() => _isLoadingSettings = false);
    }
  }

  // ── Check dependent settings and start listening if audio_recording is true ──
  Future<void> _checkDependentSettingsAndStart(UserModel user) async {
    try {
      final safetyService = DependentSafetyService();
      final int dependentId = int.tryParse(user.id) ?? 0;
      
      if (dependentId == 0) {
        print('❌ [SOS Home] Invalid dependent ID: ${user.id}');
        return;
      }
      
      print('📡 [SOS Home] Fetching safety settings for dependent $dependentId');
      final settings = await safetyService.getDependentSafetySettings(dependentId);
      
      print('📊 [SOS Home] Safety settings received:');
      print('   - audio_recording: ${settings.audioRecording}');
      print('   - live_location: ${settings.liveLocation}');
      print('   - motion_detection: ${settings.motionDetection}');
      print('   - auto_recording: ${settings.autoRecording}');
      
      if (settings.audioRecording) {
        print('🎤 [SOS Home] Audio recording is ENABLED - starting continuous listening');
        await _startContinuousListening(user);
      } else {
        print('🔇 [SOS Home] Audio recording is DISABLED - continuous listening off');
        
        // Stop if it was previously running
        if (_isContinuousListeningActive) {
          print('🛑 [SOS Home] Stopping previously active listening');
          await _stopContinuousListening();
        }
      }
    } catch (e) {
      print('❌ [SOS Home] Failed to check dependent settings: $e');
    }
  }

  // ── Start continuous listening ──
  Future<void> _startContinuousListening(UserModel user) async {
    if (_sosListenService == null) {
      print('❌ [SOS Home] SOS Listen Service not initialized');
      return;
    }
    
    if (_isContinuousListeningActive) {
      print('ℹ️ [SOS Home] Continuous listening already active');
      return;
    }
    
    try {
      print('🎤 [SOS Home] Starting continuous listening for user ${user.id}');
      
      // Check microphone permission
      var status = await Permission.microphone.status;
      print('📱 [SOS Home] Microphone permission status: $status');
      
      if (!status.isGranted) {
        print('🔐 [SOS Home] Requesting microphone permission');
        status = await Permission.microphone.request();
        print('📱 [SOS Home] Microphone permission after request: $status');
        
        if (!status.isGranted) {
          print('❌ [SOS Home] Microphone permission denied');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Microphone permission needed for SOS monitoring'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }
      
      final int? userId = int.tryParse(user.id);
      if (userId == null) {
        print('❌ [SOS Home] Invalid user ID: ${user.id}');
        return;
      }
      
      print('🎯 [SOS Home] Initializing SOS listen service with userId: $userId');
      
      await _sosListenService!.startListening(
        userId: userId,
        onSOSConfirmed: () {
          print('🚨🚨🚨 [SOS Home] SOS CONFIRMED FROM VOICE DETECTION! 🚨🚨🚨');
          if (mounted) {
            _handleVoiceActivatedSOS();
          }
        },
        onStatusChange: (status) {
          print('📢 [SOS Listen] Status: $status');
        },
      );
      
      setState(() {
        _isContinuousListeningActive = true;
      });
      
      print('✅ [SOS Home] Continuous listening started successfully');
      print('🎤 [SOS Home] App is now listening for "help" keywords');
      
      // Show subtle indicator that listening is active
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'SOS voice monitoring active',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      
    } catch (e) {
      print('❌ [SOS Home] Failed to start continuous listening: $e');
      setState(() {
        _isContinuousListeningActive = false;
      });
    }
  }

  // ── Stop continuous listening ──
  Future<void> _stopContinuousListening() async {
    if (_sosListenService == null || !_isContinuousListeningActive) {
      print('ℹ️ [SOS Home] No active listening to stop');
      return;
    }
    
    try {
      print('🛑 [SOS Home] Stopping continuous listening');
      await _sosListenService!.stopListening();
      setState(() {
        _isContinuousListeningActive = false;
      });
      print('✅ [SOS Home] Continuous listening stopped');
    } catch (e) {
      print('❌ [SOS Home] Error stopping continuous listening: $e');
    }
  }

  // ── Handle voice-activated SOS ──
  void _handleVoiceActivatedSOS() {
    print('🚨 [SOS Home] Processing voice-activated SOS');
    
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
                Icons.auto_awesome,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '🚨 Voice keyword detected! SOS activated!',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.sosRed,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Get current location helper ──────────────────────────────────────────
  Future<Position?> _getCurrentLocation() async {
    try {
      print('📍 [SOS Home] Getting current location');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print('📍 [SOS Home] Location obtained: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('❌ [SOS Home] Location error: $e');
      return null;
    }
  }

  // ── Long press: start recording ──────────────────────────────────────────
  void _onLongPressStart() {
    print('👆 [SOS Home] Long press started');
    
    final contactsState = ref.read(personalContactsNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (contactsState.contacts.isEmpty) {
      print('⚠️ [SOS Home] No emergency contacts found');
      _showNoContactsDialog(context, isDark);
      return;
    }

    print('🎙️ [SOS Home] Starting voice message recording');
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
      print('⏱️ [SOS Home] Recording: ${_recordingSeconds}s');
    });

    _voiceMessageService.startManualRecording(
      onComplete: (filePath) {
        print('✅ [SOS Home] Recording completed at: $filePath');
        _finishRecordingAndSendSOS(filePath);
      },
      onError: (error) {
        print('❌ [SOS Home] Recording error: $error');
        _stopRecordingOverlay();
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
    print('👆 [SOS Home] Long press ended');
    
    if (!_voiceMessageService.isRecording) {
      print('ℹ️ [SOS Home] No active recording to stop');
      return;
    }

    print('⏹️ [SOS Home] Stopping recording');
    _voiceMessageService.stopRecording(
      onComplete: (filePath) {
        print('✅ [SOS Home] Recording stopped, file: $filePath');
        _finishRecordingAndSendSOS(filePath);
      },
      onError: (error) {
        print('❌ [SOS Home] Error stopping recording: $error');
        _stopRecordingOverlay();
      },
    );
  }

  // ── After recording: send SOS with voice using unified endpoint ───────────
  Future<void> _finishRecordingAndSendSOS(String filePath) async {
    print('📤 [SOS Home] Finishing recording and sending SOS');
    _stopRecordingOverlay();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    try {
      final position = await _getCurrentLocation();
      
      print('🚨 [SOS Home] Creating SOS with voice message');
      print('   - File: $filePath');
      print('   - Location: ${position != null ? "${position.latitude}, ${position.longitude}" : "Not available"}');
      
      final result = await _voiceMessageService.createSosWithVoice(
        filePath: filePath,
        triggerType: 'manual',
        eventType: 'panic_button',
        latitude: position?.latitude,
        longitude: position?.longitude,
        appState: 'foreground',
      );

      if (result != null && result['event_id'] != null) {
        print('✅ [SOS Home] SOS event created successfully!');
        print('   - Event ID: ${result['event_id']}');
        print('   - Voice URL: ${result['voice_url']}');
        
        if (!mounted) return;
        _showSOSActivatedConfirmation(context, isDark, withVoice: true);
      } else {
        throw Exception('Failed to create SOS with voice');
      }
    } catch (e) {
      print('❌ [SOS Home] Failed to send SOS: $e');
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
    print('🛑 [SOS Home] Stopping recording overlay');
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
    print('🆘 [SOS Home] Activate SOS button tapped');
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contactsState = ref.read(personalContactsNotifierProvider);

    if (contactsState.contacts.isEmpty) {
      print('⚠️ [SOS Home] No emergency contacts, showing dialog');
      _showNoContactsDialog(context, isDark);
      return;
    }

    print('📋 [SOS Home] Showing confirmation dialog');
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
            onPressed: () {
              print('❌ [SOS Home] SOS cancelled by user');
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              print('✅ [SOS Home] SOS confirmed by user');
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
    print('⏱️ [SOS Home] Showing countdown dialog');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _CountdownDialog(
          countdownSeconds: _countdownSeconds,
          isDark: isDark,
          onComplete: () {
            print('⏱️ [SOS Home] Countdown complete, sending SOS');
            _sendSosEventNoVoice(context, isDark);
          },
        );
      },
    );
  }

  Future<void> _sendSosEventNoVoice(BuildContext context, bool isDark) async {
    print('📤 [SOS Home] Sending SOS without voice');
    
    try {
      final position = await _getCurrentLocation();
      
      print('🚨 [SOS Home] Creating SOS event (no voice)');
      print('   - Location: ${position != null ? "${position.latitude}, ${position.longitude}" : "Not available"}');
      
      final result = await _voiceMessageService.createSosWithVoice(
        filePath: null,
        triggerType: 'manual',
        eventType: 'panic_button',
        latitude: position?.latitude,
        longitude: position?.longitude,
        appState: 'foreground',
      );

      if (result != null && result['event_id'] != null) {
        print('✅ [SOS Home] SOS event created: ${result['event_id']}');
        if (!mounted) return;
        _showSOSActivatedConfirmation(context, isDark, withVoice: false);
      } else {
        throw Exception('Failed to create SOS');
      }
    } catch (e) {
      print('❌ [SOS Home] Failed to send SOS: $e');
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
    print('✅ [SOS Home] Showing SOS confirmation (withVoice: $withVoice)');
    
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final permissionAsync = ref.watch(permissionSummaryProvider);
    final user = ref.watch(authProvider).user;

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
                print('🔄 [SOS Home] Refreshing data');
                ref.read(personalContactsNotifierProvider.notifier).loadMyContacts();
                ref.invalidate(permissionSummaryProvider);
                await _checkAndStartContinuousListening();
              },
              color: isDark ? AppColors.darkAccentGreen1 : AppColors.primaryGreen,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    
                    if (_isContinuousListeningActive)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.5),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '🎤 SOS voice monitoring active',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    if (_isLoadingSettings)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    
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