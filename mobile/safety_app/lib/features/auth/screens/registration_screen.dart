import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import 'package:safety_app/core/widgets/app_text_field.dart';
import 'package:safety_app/core/widgets/avatar_picker.dart';
import 'package:safety_app/core/widgets/onboarding_progress_indicator.dart';
import 'package:safety_app/services/firebase/firebase_auth_service.dart';
import 'package:safety_app/services/auth_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';


class RegistrationScreen extends StatefulWidget {
  final String phoneNumber;
  final String email;
  final String password;

  const RegistrationScreen({
    super.key,
    required this.phoneNumber,
    required this.email,
    required this.password,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final FirebaseAuthService _firebaseAuthService = FirebaseAuthService();
  final AuthApiService _authApiService = AuthApiService();

  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _handleRegistration() async {
    // 1️⃣ Validate form
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 🔍 Debug: Check current Firebase user state
      print('🔍 Current Firebase User:');
      print('   UID: ${_firebaseAuthService.getUserUid()}');
      print('   Email: ${_firebaseAuthService.getUserEmail()}');
      print('   Phone: ${_firebaseAuthService.getUserPhoneNumber()}');
      print('   Email Verified: ${_firebaseAuthService.isEmailVerified()}');
      print('   Phone Verified: ${_firebaseAuthService.isPhoneVerified()}');

      // 2️⃣ Get Firebase ID token (single attempt, no retry)
      print('🔄 Getting Firebase token...');
      
      final firebaseToken = await _firebaseAuthService.getFirebaseIdToken(
        forceRefresh: true,
      );

      if (firebaseToken == null || firebaseToken.isEmpty) {
        throw Exception('Failed to get Firebase token. Please try again.');
      }

      print('✅ Firebase token obtained successfully');
      print('🔍 Token length: ${firebaseToken.length}');

      if (!mounted) return;

      // 3️⃣ Send to backend: Firebase token + name + password
      print('📤 Sending registration request to backend...');
      final authResponse = await _authApiService.completeFirebaseRegistration(
        firebaseToken: firebaseToken,
        fullName: _fullNameController.text.trim(),
        password: widget.password,
      );

      if (!mounted) return;

      // Check if registration was successful
      if (response['success'] == true) {
        _showSuccess("Verification code sent to your email!");

      // 4️⃣ Navigate based on user roles
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      final user = authResponse.user;

      if (user != null && user.hasRole) {
        // User already has role assigned
        print('✅ User has role, navigating to home...');
        context.go('/home');
      } else {
        // Navigate to role selection
        print('ℹ️ User needs to select role, navigating to role-intent...');
        context.go('/role-intent');
      }
    } catch (e) {
      if (!mounted) return;
      print('❌ Registration error: $e');
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AvatarPicker(
                        onTap: () {
                          // TODO: Implement image picker
                        },
                      ),

                      const SizedBox(height: 16),

                      Text("Complete your profile", style: AppTextStyles.h3),

                      const SizedBox(height: 8),

                      Text(
                        "Just one more step!",
                        style: AppTextStyles.body.copyWith(
                          color: isDark
                              ? AppColors.darkHint
                              : AppColors.lightHint,
                        ),
                      ),

                      const SizedBox(height: 32),

                      AppTextField(
                        label: "Full Name",
                        hint: "Enter your full name",
                        controller: _fullNameController,
                        enabled: !_isLoading,
                        validator: (value) {
                          if (value == null || value.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Phone number (read-only, already verified)
                      AppTextField(
                        label: "Phone Number",
                        controller: TextEditingController(
                          text: widget.phoneNumber,
                        ),
                        enabled: false,
                        suffixIcon: const Icon(
                          Icons.verified,
                          color: Colors.green,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Email (read-only, already verified)
                      AppTextField(
                        label: "Email",
                        controller: TextEditingController(
                          text: widget.email,
                        ),
                        enabled: false,
                        suffixIcon: const Icon(
                          Icons.verified,
                          color: Colors.green,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Password indicator (not shown, but confirmed)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lock,
                              color: AppColors.primaryGreen,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Password set securely ✓",
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Info box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Your phone and email are verified. Use your phone number and password for daily login.",
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
              child: OnboardingProgressIndicator(currentStep: 3, totalSteps: 4),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: AnimatedBottomButton(
                label: _isLoading ? "Creating Account..." : "Complete Registration",
                usePositioned: false,
                onPressed: _isLoading ? () {} : _handleRegistration,
              ),
            ),
          ],
        ),
      ),
    );
  }
}