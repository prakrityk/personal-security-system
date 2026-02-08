import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import 'package:safety_app/core/widgets/onboarding_progress_indicator.dart';
import 'package:safety_app/models/auth_response_model.dart';
import 'package:safety_app/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final int otpLength = 6;
  late List<TextEditingController> controllers;
  late List<FocusNode> focusNodes;
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _canResend = false;
  int _remainingSeconds = 120; // 2 minutes

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

  // Future<void> _verifyOTP() async {
  //   final otpCode = _getOtpCode();

  //   if (otpCode.length != otpLength) {
  //     _showError("Please enter complete OTP");
  //     return;
  //   }

  //   setState(() => _isLoading = true);

  //   try {
  //     final otpResponse = await _authService.verifyPhone(
  //       phoneNumber: widget.phoneNumber,
  //       verificationCode: otpCode,
  //     );

  //     if (!mounted) return;

  //     _showSuccess("Phone verified successfully!");

  //     // Navigate to registration - backend now marks phone as verified
  //     Navigator.pushReplacement(
  //       context,
  //       MaterialPageRoute(
  //         builder: (_) => RegistrationScreen(phoneNumber: widget.phoneNumber),
  //       ),
  //     );
  //   } catch (e) {
  //     if (!mounted) return;
  //     _showError(e.toString().replaceAll('Exception: ', ''));
  //   } finally {
  //     if (mounted) setState(() => _isLoading = false);
  //   }
  // }
  Future<void> _verifyOTP() async {
    final otpCode = _getOtpCode();

    if (otpCode.length != otpLength) {
      _showError("Please enter complete OTP");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1️⃣ Verify OTP via backend
      await _authService.verifyPhone(
        phoneNumber: widget.phoneNumber,
        verificationCode: otpCode,
      );

      // 2️⃣ Check if phone is marked as verified
      final PhoneCheckResponse check = await _authService.checkPhone(
        widget.phoneNumber,
      );
      if (!check.prefill) {
        _showError("Phone not verified yet. Please try again.");
        return;
      }

      if (!mounted) return;

      _showSuccess("Phone verified successfully!");

      // 3️⃣ Navigate to registration screen
      context.pushReplacement('/registration', extra: widget.phoneNumber);
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOTP() async {
    setState(() => _isLoading = true);

    try {
      await _authService.sendVerificationCode(widget.phoneNumber);

      if (!mounted) return;

      _showSuccess("OTP resent successfully");

      // Reset timer
      setState(() {
        _remainingSeconds = 120;
        _canResend = false;
      });
      _startTimer();

      // Clear OTP fields
      for (final controller in controllers) {
        controller.clear();
      }
      focusNodes[0].requestFocus();
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
                      "Enter the OTP sent to ${widget.phoneNumber}",
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
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: OnboardingProgressIndicator(currentStep: 1, totalSteps: 3),
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
