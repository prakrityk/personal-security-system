// lib/features/home/family/widgets/safety_settings_section_widget.dart
//
// Guardian view of a dependent's safety settings.
// When the primary guardian toggles motion detection the API is updated.
// refreshRemoteSetting() is called so the sensor on the dependent's device
// stops/starts on next evaluate() without requiring an app restart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:safety_app/core/providers/shared_providers.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/models/dependent_model.dart';
import 'package:safety_app/services/dependent_safety_service.dart';
import 'package:safety_app/services/motion_detection_gate.dart';

class SafetySettingsSectionWidget extends ConsumerStatefulWidget {
  final DependentModel dependent;

  const SafetySettingsSectionWidget({super.key, required this.dependent});

  @override
  ConsumerState<SafetySettingsSectionWidget> createState() =>
      _SafetySettingsSectionWidgetState();
}

class _SafetySettingsSectionWidgetState
    extends ConsumerState<SafetySettingsSectionWidget> {
  final DependentSafetyService _safetyService = DependentSafetyService();

  bool _liveLocationTracking = false;
  bool _audioRecording = false;
  bool _motionDetection = false;
  bool _autoRecording = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSafetySettings();
  }

  Future<void> _loadSafetySettings() async {
    try {
      debugPrint(
        '📡 Loading safety settings for dependent '
        '${widget.dependent.dependentId}',
      );
      final settings = await _safetyService.getDependentSafetySettings(
        widget.dependent.dependentId,
      );
      if (!mounted) return;
      setState(() {
        _liveLocationTracking = settings.liveLocation;
        _audioRecording = settings.audioRecording;
        _motionDetection = settings.motionDetection;
        _autoRecording = settings.autoRecording;
        _isLoading = false;
      });
      debugPrint(
        '✅ Safety settings loaded: '
        'location=$_liveLocationTracking, '
        'audio=$_audioRecording, '
        'motion=$_motionDetection',
      );
    } catch (e) {
      debugPrint('❌ Failed to load safety settings: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorSnackbar('Failed to load safety settings');
    }
  }

  Future<void> _toggleSafetySetting(String setting, bool value) async {
    if (!widget.dependent.isPrimaryGuardian) {
      _showErrorSnackbar('Only primary guardians can modify safety settings');
      return;
    }

    try {
      debugPrint('🔄 Updating $setting to $value');

      // Build the patch payload
      final Map<String, dynamic> updates = switch (setting) {
        'location' => {'live_location': value},
        'audio' => {'audio_recording': value},
        'motion' => {'motion_detection': value},
        'auto_recording' => {'auto_recording': value},
        _ => {},
      };

      await _safetyService.updateDependentSafetySettings(
        dependentId: widget.dependent.dependentId,
        updates: updates,
      );

      if (!mounted) return;

      // Update local UI state
      setState(() {
        switch (setting) {
          case 'location':
            _liveLocationTracking = value;
            break;
          case 'audio':
            _audioRecording = value;
            break;
          case 'motion':
            _motionDetection = value;
            break;
          case 'auto_recording':
            _autoRecording = value;
            break;
        }
      });

      // After updating the DB, tell the gate to re-fetch the remote setting.
      // The gate runs on the GUARDIAN's device here — it calls
      // _fetchAndCacheRemoteSetting() which hits getMySafetySettings().
      // On the dependent's device, evaluate() will pick up the new value
      // next time it is called (app resume / next login).
      if (setting == 'motion') {
        final prefs = ref.read(sharedPreferencesProvider);
        final user = ref.read(authStateProvider).value;
        final gateUser = user != null
            ? GateUser(user.roles?.map((r) => r.roleName).toList() ?? [])
            : null;
        await MotionDetectionGate.instance.refreshRemoteSetting(
          prefs,
          gateUser,
        );
      }

      _showSuccessSnackbar('Safety setting updated successfully');
      debugPrint('✅ $setting setting updated to $value');
    } catch (e) {
      debugPrint('❌ Failed to update $setting setting: $e');
      if (!mounted) return;
      _showErrorSnackbar('Failed to update safety setting');
    }
  }

  void _viewAllSafetySettings() {
    context.push(
      '/dependent-safety-settings',
      extra: {
        'dependentId': widget.dependent.dependentId,
        'dependentName': widget.dependent.dependentName,
        'isPrimaryGuardian': widget.dependent.isPrimaryGuardian,
      },
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.sosRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ─────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.security,
                        color: AppColors.primaryGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Safety Settings',
                        style: AppTextStyles.h4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.dependent.isPrimaryGuardian)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.visibility,
                        size: 14,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'View Only',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.orange,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Content ────────────────────────────────────────────────────
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              ),
            )
          else ...[
            _buildSafetyToggle(
              icon: Icons.location_on,
              title: 'Live Location Tracking',
              subtitle: 'Real-time location monitoring',
              value: _liveLocationTracking,
              onChanged: (v) => _toggleSafetySetting('location', v),
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            _buildSafetyToggle(
              icon: Icons.mic,
              title: 'Audio Recording',
              subtitle: 'Record audio during SOS',
              value: _audioRecording,
              onChanged: (v) => _toggleSafetySetting('audio', v),
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            _buildSafetyToggle(
              icon: Icons.motion_photos_on,
              title: 'Motion Detection',
              subtitle: 'Alert on unusual movement',
              value: _motionDetection,
              onChanged: (v) => _toggleSafetySetting('motion', v),
              isDark: isDark,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _viewAllSafetySettings,
                icon: const Icon(Icons.settings),
                label: const Text('View All Settings'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: const BorderSide(color: AppColors.primaryGreen),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSafetyToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? AppColors.primaryGreen.withOpacity(0.3)
              : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: value
                  ? AppColors.primaryGreen.withOpacity(0.1)
                  : (isDark
                        ? AppColors.darkSurface.withOpacity(0.3)
                        : AppColors.lightSurface.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: value ? AppColors.primaryGreen : Colors.grey,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isDark
                        ? AppColors.darkOnBackground
                        : AppColors.lightOnBackground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: isDark ? AppColors.darkHint : AppColors.lightHint,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: widget.dependent.isPrimaryGuardian ? onChanged : null,
            activeThumbColor: AppColors.primaryGreen,
          ),
        ],
      ),
    );
  }
}
