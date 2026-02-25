import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:safety_app/services/auth_api_service.dart';
import '../services/voice_record_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';

/// Voice registration screen used by two flows:
///
/// 1. **Dependent gate** (mandatory, one-time): The router pushes this screen
///    automatically when a dependent user's [isVoiceRegistered] is false.
///    Back navigation is blocked so they cannot skip it.
///    After completion, [AuthStateNotifier.updateVoiceRegistrationStatus(true)]
///    triggers a router refresh which redirects them to /home.
///
/// 2. **Guardian / personal toggle** (optional): Pushed via Navigator from the
///    safety settings screen. Back navigation works normally.
///    Pass `isGated: false` (the default) for this flow.
///
/// Usage from guardian settings:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => const VoiceRegistrationScreen(isGated: false),
/// ));
/// ```
class VoiceRegistrationScreen extends ConsumerStatefulWidget {
  /// When true the back button / system back gesture is disabled so that
  /// dependent users cannot bypass the mandatory voice registration step.
  final bool isGated;

  const VoiceRegistrationScreen({super.key, this.isGated = false});

  @override
  ConsumerState<VoiceRegistrationScreen> createState() =>
      _VoiceRegistrationScreenState();
}

class _VoiceRegistrationScreenState
    extends ConsumerState<VoiceRegistrationScreen> {
  final VoiceRecordService _recordService = VoiceRecordService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool isRecording = false;
  bool isRetaking = false;

  int sampleCount = 0;
  String? latestSamplePath;

  bool registrationCompleted = false;

  String statusText = "Press record & speak clearly";

  /// Whether this screen was opened as the mandatory dependent gate.
  /// Auto-detected from the user's role — 'child' and 'elderly' are both
  /// dependent-type roles that require the one-time voice registration gate.
  bool get _isGated {
    if (widget.isGated) return true;
    final roleName =
        ref
            .read(authStateProvider)
            .value
            ?.currentRole
            ?.roleName
            ?.toLowerCase() ??
        '';
    return roleName == 'child' || roleName == 'elderly';
  }

  @override
  void initState() {
    super.initState();
    Permission.microphone.request();
  }

  void startRecording() async {
    if (sampleCount >= 3) return;

    final permissionStatus = await Permission.microphone.request();
    if (!permissionStatus.isGranted) {
      setState(() => statusText = "Microphone permission denied");
      return;
    }

    isRetaking = false;
    final path = await _recordService.startRecording(sampleCount + 1);

    setState(() {
      isRecording = true;
      latestSamplePath = path;
      statusText = "Recording sample ${sampleCount + 1}...";
    });
  }

  void stopRecording() async {
    await _recordService.stopRecording();
    if (!mounted) return;
    // Track which sample we're saving BEFORE incrementing
    final uploadSampleNumber = isRetaking ? sampleCount : sampleCount + 1;
    setState(() {
      isRecording = false;
      if (!isRetaking) sampleCount++;
    });

    if (latestSamplePath != null) {
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        final response = await AuthApiService().uploadVoice(
          userId: int.parse(user.id),
          sampleNumber: uploadSampleNumber,
          filePath: latestSamplePath!,
        );

        if (!mounted) return;

        if (sampleCount == 3 && response) {
          // ✅ Persist isVoiceRegistered = true in secure storage AND in-memory
          // state. For the gated (dependent) flow this triggers the GoRouter
          // redirect listener which navigates to /home automatically.
          // For the non-gated (guardian/personal) flow we also pop manually
          // so the settings screen knows registration succeeded.
          await ref
              .read(authStateProvider.notifier)
              .updateVoiceRegistrationStatus(true);

          if (mounted) {
            setState(() {
              registrationCompleted = true;
              statusText = "Registration Successful!";
            });
          }

          if (!_isGated && mounted) {
            // Non-gated flow: pop back to caller after a short delay.
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) Navigator.pop(context, true);
            });
          }
          // Gated flow: router redirect handles navigation — no pop needed.
        } else if (mounted) {
          setState(() {
            statusText = sampleCount < 3
                ? "Sample $sampleCount recorded. ${3 - sampleCount} more to go."
                : statusText;
          });
        }
      }
    }
  }

  void playLatestSample() async {
    if (latestSamplePath == null) return;
    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(latestSamplePath!));
    setState(() => statusText = "Playing latest sample...");
  }

  void retakeLatestSample() async {
    if (sampleCount == 0 || latestSamplePath == null) return;
    isRetaking = true;
    final path = await _recordService.startRecording(sampleCount);
    setState(() {
      isRecording = true;
      latestSamplePath = path;
      statusText = "Retaking sample $sampleCount...";
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ WillPopScope blocks the Android back button and iOS swipe-back gesture
    // when this screen is acting as the mandatory dependent gate.
    return WillPopScope(
      onWillPop: () async {
        if (_isGated && !registrationCompleted) {
          // Show a friendly reminder instead of allowing back navigation.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please complete voice registration to continue.'),
              duration: Duration(seconds: 2),
            ),
          );
          return false; // Block back
        }
        return true; // Allow back for non-gated flow
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Voice Registration", style: AppTextStyles.h4),
          // ✅ Hide the back arrow when gated so the UI matches the behaviour.
          automaticallyImplyLeading: !_isGated || registrationCompleted,
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Gated flow header ──
              if (_isGated && !registrationCompleted)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.mic_rounded,
                        size: 48,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "One-time Voice Setup",
                        style: AppTextStyles.h4,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Record 3 voice samples so the app can recognise you "
                        "in an emergency. This only needs to be done once.",
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark
                              ? AppColors.darkHint
                              : AppColors.lightHint,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

              // ── Progress Indicator ──
              _SampleProgressIndicator(sampleCount: sampleCount),
              const SizedBox(height: 32),

              // ── Status text ──
              Text(
                statusText,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.darkHint : AppColors.lightHint,
                ),
              ),
              const SizedBox(height: 48),

              // ── Record Button ──
              if (!registrationCompleted)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isRecording ? stopRecording : startRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRecording
                          ? AppColors.sosRed
                          : colorScheme.primary,
                      foregroundColor: isRecording
                          ? Colors.white
                          : colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 22,
                    ),
                    label: Text(
                      isRecording ? "Stop Recording" : "Start Recording",
                      style: AppTextStyles.labelLarge,
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // ── Play / Retake ──
              if (latestSamplePath != null && !registrationCompleted)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: playLatestSample,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text("Play"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: retakeLatestSample,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text("Retake"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          side: const BorderSide(color: AppColors.warning),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              // ── Success ──
              if (registrationCompleted)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 56,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Voice Registration Completed",
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                      if (_isGated)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            "Taking you to the app…",
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: isDark
                                  ? AppColors.darkHint
                                  : AppColors.lightHint,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three-dot progress indicator showing collected samples
class _SampleProgressIndicator extends StatelessWidget {
  final int sampleCount;

  const _SampleProgressIndicator({required this.sampleCount});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = Theme.of(context).colorScheme.primary;
    final inactiveColor = isDark
        ? AppColors.darkDivider
        : AppColors.lightDivider;

    return Column(
      children: [
        Text(
          "Voice Samples",
          style: AppTextStyles.labelMedium.copyWith(
            color: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final isCollected = index < sampleCount;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isCollected
                          ? activeColor.withOpacity(0.15)
                          : inactiveColor.withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCollected ? activeColor : inactiveColor,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      isCollected ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: isCollected ? activeColor : inactiveColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Sample ${index + 1}",
                    style: AppTextStyles.caption.copyWith(
                      color: isCollected ? activeColor : inactiveColor,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Text(
          "$sampleCount / 3 collected",
          style: AppTextStyles.caption.copyWith(
            color: isDark ? AppColors.darkHint : AppColors.lightHint,
          ),
        ),
      ],
    );
  }
}
