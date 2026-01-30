import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import 'package:safety_app/core/widgets/onboarding_progress_indicator.dart';
import 'package:safety_app/services/firebase/firebase_auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final int otpLength = 6;
  late List<TextEditingController> controllers;
  late List<FocusNode> focusNodes;
  final FirebaseAuthService _firebaseAuthService = FirebaseAuthService();

  bool _isLoading = false;
  bool _canResend = false;
  int _remainingSeconds = 60; // 1 minute for Firebase OTP

  @override
  void initState() {
    super.initState();
    controllers = List.generate(otpLength, (_) => TextEditingController());
    focusNodes = List.generate(otpLength, (_) => FocusNode());
    _startTimer();
  }

  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    for (final f in focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
        _startTimer();
      } else {
        setState(() => _canResend = true);
      }
    });
  }

  String _getOtpCode() {
    return controllers.map((c) => c.text).join();
  }

  Future<void> _verifyOTP() async {
    final otpCode = _getOtpCode();

    if (otpCode.length != otpLength) {
      _showError("Please enter complete OTP");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🔥 Verify OTP with Firebase
      await _firebaseAuthService.verifyPhoneOTP(
        verificationId: widget.verificationId,
        otpCode: otpCode,
      );

      if (!mounted) return;

      _showSuccess("Phone verified successfully!");

      // Navigate to email verification screen
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      context.pushReplacement('/email-verification', extra: {
        'phoneNumber': widget.phoneNumber,
      });
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOTP() async {
    if (!_canResend) return;

    setState(() => _isLoading = true);

    try {
      // 🔥 Resend OTP via Firebase
      await _firebaseAuthService.sendPhoneOTP(
        phoneNumber: widget.phoneNumber,
        onCodeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;

          _showSuccess("OTP resent successfully");

          // Reset timer
          setState(() {
            _remainingSeconds = 60;
            _canResend = false;
          });
          _startTimer();

          // Clear OTP fields
          for (final controller in controllers) {
            controller.clear();
          }
          focusNodes[0].requestFocus();

          // Navigate to new OTP screen with new verificationId
          context.pushReplacement('/otp-verification', extra: {
            'phoneNumber': widget.phoneNumber,
            'verificationId': verificationId,
          });
        },
        onVerificationFailed: (String error) {
          if (!mounted) return;
          _showError(error);
        },
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boxColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Verify OTP",
                      style: AppTextStyles.heading.copyWith(
                        color: isDark
                            ? AppColors.darkOnBackground
                            : AppColors.lightOnBackground,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      "Enter the 6-digit code sent to ${widget.phoneNumber}",
                      style: AppTextStyles.bodyMedium,
                    ),

                    const SizedBox(height: 32),

                    // OTP Boxes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(otpLength, (index) {
                        return SizedBox(
                          width: 48,
                          height: 56,
                          child: TextField(
                            controller: controllers[index],
                            focusNode: focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            enabled: !_isLoading,
                            style: AppTextStyles.h3,
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: boxColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.primaryGreen,
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty && index < otpLength - 1) {
                                focusNodes[index + 1].requestFocus();
                              }
                              if (value.isEmpty && index > 0) {
                                focusNodes[index - 1].requestFocus();
                              }
                            },
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 16),

                    // Timer and Resend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _canResend
                              ? "OTP expired"
                              : "OTP expires in ${_formatTime(_remainingSeconds)}",
                          style: AppTextStyles.caption.copyWith(
                            color: _canResend
                                ? Colors.red
                                : (isDark
                                      ? AppColors.darkHint
                                      : AppColors.lightHint),
                          ),
                        ),
                        if (_canResend)
                          TextButton(
                            onPressed: _isLoading ? null : _resendOTP,
                            child: Text(
                              "Resend OTP",
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Info box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.primaryGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "The code is valid for 1 minute",
                              style: AppTextStyles.caption.copyWith(
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

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: OnboardingProgressIndicator(currentStep: 1, totalSteps: 4),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: AnimatedBottomButton(
                label: _isLoading ? "Verifying..." : "Verify",
                usePositioned: false,
                onPressed: _isLoading ? () {} : _verifyOTP,
              ),
            ),
          ],
        ),
      ),
    );
  }
}