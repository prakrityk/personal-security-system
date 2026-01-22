import 'package:flutter/material.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import 'package:safety_app/core/widgets/app_text_field.dart';
import 'package:safety_app/core/widgets/onboarding_progress_indicator.dart';
import 'package:safety_app/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'otp_verification_screen.dart';

class PhoneNumberScreen extends StatefulWidget {
  const PhoneNumberScreen({super.key});

  @override
  State<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends State<PhoneNumberScreen> {
  final _phoneController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;

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
      // Send OTP via API
      final response = await _authService.sendVerificationCode(phone);

      if (!mounted) return;

      _showSuccess(response.message);

      // Navigate to OTP screen with phone number
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(phoneNumber: phone),
        ),
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
                // Added ScrollView
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
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: OnboardingProgressIndicator(currentStep: 0, totalSteps: 3),
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
