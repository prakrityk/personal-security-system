import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
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
  bool _recordEvidence = false;
  bool _isVoiceActivationEnabled = false;

  late final SOSListenService sosService;

  @override
  void initState() {
    super.initState();
      sosService = SOSListenService(); // ✅ ADD THIS

    // 🔹 Refresh user state on screen load to get the latest isVoiceRegistered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authStateProvider.notifier).refreshUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Watch user async state
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
              // Header with icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
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

              // 1. Live Location Toggle
              SafetyToggleTile(
                icon: Icons.location_on_outlined,
                title: 'Live Location',
                subtitle: 'Share your real-time location with guardians',
                isEnabled: _liveLocation,
                onToggle: (value) => setState(() => _liveLocation = value),
              ),

              const SizedBox(height: 16),

             
              // 2. Voice Registration Toggle
              SafetyToggleTile(
                // ✅ Visuals depend ONLY on DB status
                icon: isAlreadyRegistered ? Icons.check_circle : Icons.mic_outlined,
                title: 'Voice Registration',
                subtitle: isAlreadyRegistered
                    ? 'Voice is successfully registered'
                    : 'Register your voice to activate SOS hands-free',
                
                // ✅ Toggle State depends ONLY on DB status
                isEnabled: isAlreadyRegistered,
                
                onToggle: (value) async {
                  // ✅ Gatekeeper: If DB says true, BLOCK EVERYTHING
                  if (isAlreadyRegistered) {
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Voice registration is already active."),
                        backgroundColor: Colors.blueGrey,
                      ),
                    );
                    return; // 🛑 STOP HERE
                  }


                  // If not registered, allow navigation
                  if (value == true) {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VoiceRegistrationScreen(),
                      ),
                    );
                    
                    // If they returned with success (true), refresh the provider
                    if (result == true) {
                         await ref.read(authStateProvider.notifier).updateVoiceRegistrationStatus(true);
                    }
                  }
                },
              ),              const SizedBox(height: 16),

//  voice activtion toggle 
              SafetyToggleTile(
                    icon: Icons.mic_outlined,
                    title: 'Voice Activation',
                    subtitle: 'Enable voice activation for SOS',
                    isEnabled: _isVoiceActivationEnabled,
                    onToggle: (value) async {
                      final user = ref.read(authStateProvider).value;

                      // 1️⃣ Must register voice first
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

                      if (value == true) {
                        print("🎤 Starting SOS Listener...");

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
                          onStatusChange: (status) => print("SOS: $status"),
                        );
                      } else {
                        print("🛑 Stopping SOS Listener...");
                        await sosService.stopListening();
                      }
                    },
                  ),


              const SizedBox(height: 16),

              // 3. Motion Detection Toggle
              SafetyToggleTile(
                icon: Icons.sensors_outlined,
                title: 'Motion Detection',
                subtitle: 'Alert on unusual movement patterns',
                isEnabled: _motionDetection,
                onToggle: (value) => setState(() => _motionDetection = value),
              ),

              const SizedBox(height: 16),

              // 4. Record Evidence Toggle
              SafetyToggleTile(
                icon: Icons.videocam_outlined,
                title: 'Record Evidence',
                subtitle: 'Auto-record during emergency',
                isEnabled: _recordEvidence,
                onToggle: (value) => setState(() => _recordEvidence = value),
              ),

              const SizedBox(height: 100), // Space for bottom nav
            ],
          ),
        ),
      ),
    );
  }


  @override
void dispose() {
  sosService.stopListening(); // ✅ prevent background mic
  super.dispose();
}
}
