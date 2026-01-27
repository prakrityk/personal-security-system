import 'package:flutter/material.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import '../widgets/safety_toggle_tile.dart';
import 'package:safety_app/features/voice_activation/screens/voice_registration_screen.dart';

class SafetySettingsScreen extends StatefulWidget {
  const SafetySettingsScreen({super.key});

  @override
  State<SafetySettingsScreen> createState() => _SafetySettingsScreenState();
}

class _SafetySettingsScreenState extends State<SafetySettingsScreen> {
  bool _liveLocation = false;
  bool _voiceActivation = false;
  bool _motionDetection = false;
  bool _recordEvidence = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              
              // Safety Toggles
              SafetyToggleTile(
                icon: Icons.location_on_outlined,
                title: 'Live Location',
                subtitle: 'Share your real-time location with guardians',
                isEnabled: _liveLocation,
                onToggle: (value) => setState(() => _liveLocation = value),
              ),
                
              SafetyToggleTile(
                icon: Icons.mic_outlined,
                title: 'Voice activation',
                subtitle: 'Activate SOS with voice command',
                isEnabled: _voiceActivation,
                // onToggle: (value) => setState(() => _voiceActivation = value),
                 onToggle: (value) async {
                    if (value == true) {
                      // 👉 First go to voice registration
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VoiceRegistrationScreen(),
                        ),
                      );

                      // After returning, enable toggle
                      setState(() => _voiceActivation = true);
                    } else {
                      setState(() => _voiceActivation = false);
                    }
                  },
                
                ),
              
              
              SafetyToggleTile(
                icon: Icons.sensors_outlined,
                title: 'Motion Detection',
                subtitle: 'Alert on unusual movement patterns',
                isEnabled: _motionDetection,
                onToggle: (value) => setState(() => _motionDetection = value),
              ),
              
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
}