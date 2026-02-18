import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import '../widgets/safety_toggle_tile.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:safety_app/features/voice_activation/screens/voice_registration_screen.dart';

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

  @override
  void initState() {
    super.initState();

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
              // 2. Voice Registration Toggle
userAsync.when(
  data: (user) {
    if (user == null) return const SizedBox();

    // 🔹 Debug: print user's voice registration status
    print("📢 DEBUG: User's isVoiceRegistered = ${user.isVoiceRegistered}");

    final isAlreadyRegistered = user.isVoiceRegistered;

    return SafetyToggleTile(
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
          final registered = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const VoiceRegistrationScreen(),
            ),
          );

          if (registered == true) {
            await ref
                .read(authStateProvider.notifier)
                .updateVoiceRegistrationStatus(true);
          }
        }
      },
    );
  },
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (err, _) => Text('Error loading user: $err'),
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
}
