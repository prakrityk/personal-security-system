import 'package:flutter/material.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/features/home/widgets/home_section_header.dart';
import '../widgets/safety_toggle_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safety_app/services/motion_detection_service.dart';

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

  static const _motionPrefKey = 'motion_detection_enabled';

  @override
  void initState() {
    super.initState();
    _loadMotionSetting();
  }

  Future<void> _loadMotionSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_motionPrefKey) ?? false;
    setState(() => _motionDetection = enabled);

    if (enabled) {
      MotionDetectionService.instance.start();
    } else {
      MotionDetectionService.instance.stop();
    }
  }

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
              HomeSectionHeader(
                icon: Icons.shield,
                title: 'Safety Features',
                subtitle: 'Customize your safety settings',
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
                onToggle: (value) => setState(() => _voiceActivation = value),
              ),

              SafetyToggleTile(
                icon: Icons.sensors_outlined,
                title: 'Motion Detection',
                subtitle: 'Alert on unusual movement patterns',
                isEnabled: _motionDetection,
                onToggle: (value) async {
                  setState(() => _motionDetection = value);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(_motionPrefKey, value);
                  if (value) {
                    MotionDetectionService.instance.start();
                  } else {
                    MotionDetectionService.instance.stop();
                  }
                },
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
