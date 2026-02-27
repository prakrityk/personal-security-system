import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/core/providers/shared_providers.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/services/motion_detection_gate.dart';
import '../widgets/safety_toggle_tile.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:safety_app/features/voice_activation/screens/voice_registration_screen.dart';
import 'package:safety_app/features/voice_activation/services/sos_listen_service.dart';

class SafetySettingsScreen extends ConsumerStatefulWidget {
  const SafetySettingsScreen({super.key});

  @override
  ConsumerState<SafetySettingsScreen> createState() =>
      _SafetySettingsScreenState();
}

class _SafetySettingsScreenState extends ConsumerState<SafetySettingsScreen> {
  bool _liveLocation = false;
  bool _motionDetection = false;
  bool _isVoiceActivationEnabled = false;

  late final SOSListenService sosService;

  @override
  void initState() {
    super.initState();
    sosService = SOSListenService();

    // Load saved motion setting immediately — prefs are already initialized
    final prefs = ref.read(sharedPreferencesProvider);
    _motionDetection = prefs.getBool(kMotionDetectionEnabled) ?? false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authStateProvider.notifier).refreshUser();
    });
  }

  Future<void> _onMotionToggle(bool value) async {
    setState(() => _motionDetection = value);
    final prefs = ref.read(sharedPreferencesProvider);
    final user = ref.read(authStateProvider).value;
    final gateUser = user != null
        ? GateUser(user.roles?.map((r) => r.roleName).toList() ?? [])
        : null;
    await MotionDetectionGate.instance.setLocalToggle(value, prefs, gateUser);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final userAsync = ref.watch(authStateProvider);
    final user = userAsync.value;
    final bool isAlreadyRegistered = user?.isVoiceRegistered ?? false;

    return Container(
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shield,
                      color: AppColors.primaryGreen,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Safety Features',
                          style: AppTextStyles.h3.copyWith(
                            color: isDark
                                ? AppColors.darkOnBackground
                                : AppColors.lightOnBackground,
                          ),
                        ),
                        Text(
                          'Customize your safety settings',
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

              // 1. Live Location
              SafetyToggleTile(
                icon: Icons.location_on_outlined,
                title: 'Live Location',
                subtitle: 'Share your real-time location with guardians',
                isEnabled: _liveLocation,
                onToggle: (value) => setState(() => _liveLocation = value),
              ),
              const SizedBox(height: 16),

              // 2. Voice Registration
              SafetyToggleTile(
                icon: isAlreadyRegistered
                    ? Icons.check_circle
                    : Icons.mic_outlined,
                title: 'Voice Registration',
                subtitle: isAlreadyRegistered
                    ? 'Voice is successfully registered'
                    : 'Register your voice to activate SOS hands-free',
                isEnabled: isAlreadyRegistered,
                onToggle: (value) async {
                  if (isAlreadyRegistered) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Voice registration is already active."),
                        backgroundColor: Colors.blueGrey,
                      ),
                    );
                    return;
                  }

                  if (value == true) {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VoiceRegistrationScreen(),
                      ),
                    );

                    if (result == true) {
                      await ref
                          .read(authStateProvider.notifier)
                          .updateVoiceRegistrationStatus(true);
                    }
                  }
                },
              ),
              const SizedBox(height: 16),

              // 3. Voice Activation
              SafetyToggleTile(
                icon: Icons.mic_outlined,
                title: 'Voice Activation',
                subtitle: 'Enable voice activation for SOS',
                isEnabled: _isVoiceActivationEnabled,
                onToggle: (value) async {
                  final user = ref.read(authStateProvider).value;

                  if (user == null || user.isVoiceRegistered != true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please register your voice first."),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  setState(() => _isVoiceActivationEnabled = value);

                  final int? userId = int.tryParse(user.id);
                  if (userId == null) return;

                  if (value) {
                    await sosService.startListening(
                      userId: userId,
                      onSOSConfirmed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("🚨 SOS ACTIVATED!"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      },
                      onStatusChange: (status) => debugPrint("SOS: $status"),
                    );
                  } else {
                    await sosService.stopListening();
                  }
                },
              ),
              const SizedBox(height: 16),

              // 4. Motion Detection
              SafetyToggleTile(
                icon: Icons.sensors_outlined,
                title: 'Motion Detection',
                subtitle: 'Alert on unusual movement patterns',
                isEnabled: _motionDetection,
                onToggle: _onMotionToggle,
              ),
              const SizedBox(height: 12),

              // Back-tap info card
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryGreen.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.back_hand_outlined,
                      size: 18,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tap the back of your phone 5 times to instantly send an SOS alert — works even when the app is closed.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.darkHint
                              : AppColors.lightHint,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    sosService.stopListening();
    super.dispose();
  }
}
