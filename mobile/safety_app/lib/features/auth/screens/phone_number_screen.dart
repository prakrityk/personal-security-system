import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import 'package:safety_app/core/widgets/app_text_field.dart';
import 'package:safety_app/core/widgets/onboarding_progress_indicator.dart';
import 'package:safety_app/services/firebase/firebase_auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class PhoneNumberScreen extends StatefulWidget {
  const PhoneNumberScreen({super.key});

  @override
  State<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends State<PhoneNumberScreen> {
  final _phoneController = TextEditingController();
  final FirebaseAuthService _firebaseAuthService = FirebaseAuthService();

  bool _isLoading = false;
  // ignore: unused_field
  String? _verificationId; // Store this for OTP screen

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    String phone = _phoneController.text.trim();

    // Validation
    if (phone.isEmpty) {
      _showError("Please enter your phone number");
      return;
    }

    // Add country code if not present
    if (!phone.startsWith('+')) {
      // Assuming Nepal, adjust country code as needed
      phone = '+977$phone';
    }

    // Validate format
    if (phone.length < 11 || phone.length > 16) {
      _showError("Please enter a valid phone number");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🔥 Send OTP via Firebase
      await _firebaseAuthService.sendPhoneOTP(
        phoneNumber: phone,

        // ✅ OTP sent successfully
        onCodeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;

          if (!mounted) return;

          _showSuccess("OTP sent to $phone");

          // Navigate to OTP verification screen
          context.push(
            '/otp-verification',
            extra: {'phoneNumber': phone, 'verificationId': verificationId},
          );
        },

        // ❌ Verification failed
        onVerificationFailed: (String error) {
          if (!mounted) return;
          _showError(error);
          setState(() => _isLoading = false);
        },

        // 🤖 Auto-verification completed (Android only)
        onVerificationCompleted: (credential) {
          if (!mounted) return;
          _showSuccess("Phone verified automatically!");

          // Navigate directly to email screen
          context.push('/email-verification', extra: {'phoneNumber': phone});
        },
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceAll('Exception: ', ''));
      setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Let's Get Started", style: AppTextStyles.heading),
                      const SizedBox(height: 8),
                      Text(
                        "Enter your phone number to continue",
                        style: AppTextStyles.body,
                      ),

                      const SizedBox(height: 40),

                      AppTextField(
                        label: "Phone Number",
                        hint: "+977 98XXXXXXXX",
                        keyboardType: TextInputType.phone,
                        controller: _phoneController,
                        enabled: !_isLoading,
                      ),

                      const SizedBox(height: 8),

                      // Helper text
                      Text(
                        "Include country code (e.g., +977)",
                        style: AppTextStyles.caption.copyWith(
                          color: isDark
                              ? AppColors.darkHint
                              : AppColors.lightHint,
                        ),
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
                                "You'll receive a verification code via SMS",
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
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: OnboardingProgressIndicator(currentStep: 0, totalSteps: 4),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: AnimatedBottomButton(
                label: _isLoading ? "Sending OTP..." : "Send OTP",
                usePositioned: false,
                onPressed: _isLoading ? () {} : _sendOTP,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
