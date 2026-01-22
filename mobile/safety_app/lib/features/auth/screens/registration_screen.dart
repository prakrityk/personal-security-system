import 'package:flutter/material.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import 'package:safety_app/core/widgets/app_text_field.dart';
import 'package:safety_app/core/widgets/avatar_picker.dart';
import 'package:safety_app/features/intent/screens/role_intent_screen.dart';
import 'package:safety_app/core/widgets/onboarding_progress_indicator.dart';
import 'package:safety_app/models/auth_response_model.dart';
import 'package:safety_app/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class RegistrationScreen extends StatefulWidget {
  final String phoneNumber;
  const RegistrationScreen({super.key, required this.phoneNumber});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Future<void> _handleRegistration() async {
  //   // Validate form
  //   if (!_formKey.currentState!.validate()) {
  //     return;
  //   }

  //   setState(() => _isLoading = true);

  //   try {
  //     // ✅ Register - phone is already verified in backend
  //     final response = await _authService.register(
  //       email: _emailController.text.trim(),
  //       password: _passwordController.text,
  //       fullName: _fullNameController.text.trim(),
  //       phoneNumber: widget.phoneNumber,
  //     );

  //     if (!mounted) return;

  //     _showSuccess("Account created successfully!");

  //     // Navigate to role selection or home
  //     Navigator.pushAndRemoveUntil(
  //       context,
  //       MaterialPageRoute(builder: (_) => const RoleIntentScreen()),
  //       (route) => false, // Remove all previous routes
  //     );
  //   } catch (e) {
  //     if (!mounted) return;
  //     _showError(e.toString().replaceAll('Exception: ', ''));
  //   } finally {
  //     if (mounted) {
  //       setState(() => _isLoading = false);
  //     }
  //   }
  // }

  Future<void> _handleRegistration() async {
    // 1️⃣ Validate form
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 2️⃣ Ensure phone is verified before registering
      final PhoneCheckResponse check = await _authService.checkPhone(
        widget.phoneNumber,
      );
      if (!check.prefill) {
        _showError("Phone not verified yet");
        setState(() => _isLoading = false);
        return;
      }

      // 3️⃣ Register user
      final response = await _authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        phoneNumber: widget.phoneNumber,
      );

      if (!mounted) return;

      _showSuccess("Account created successfully!");

      // 4️⃣ Navigate to role selection or home
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoleIntentScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
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

                      Text("Create your profile", style: AppTextStyles.h3),

                      const SizedBox(height: 32),

                      AppTextField(
                        label: "Full Name",
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

                      AppTextField(
                        label: "Email",
                        keyboardType: TextInputType.emailAddress,
                        controller: _emailController,
                        enabled: !_isLoading,
                        validator: (value) {
                          if (value == null || !value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      AppTextField(
                        label: "Password",
                        obscureText: true,
                        controller: _passwordController,
                        enabled: !_isLoading,
                        validator: (value) {
                          if (value == null || value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          if (!value.contains(RegExp(r'[A-Z]'))) {
                            return 'Password must contain uppercase letter';
                          }
                          if (!value.contains(RegExp(r'[a-z]'))) {
                            return 'Password must contain lowercase letter';
                          }
                          if (!value.contains(RegExp(r'[0-9]'))) {
                            return 'Password must contain a number';
                          }
                          if (!value.contains(RegExp(r'[@$!%*?&#]'))) {
                            return 'Password must contain special character';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 8),

                      // Password requirements hint
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Min 8 chars, uppercase, lowercase, number, special char",
                          style: AppTextStyles.caption.copyWith(
                            color: isDark
                                ? AppColors.darkHint
                                : AppColors.lightHint,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      AppTextField(
                        label: "Confirm Password",
                        obscureText: true,
                        controller: _confirmPasswordController,
                        enabled: !_isLoading,
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: OnboardingProgressIndicator(currentStep: 2, totalSteps: 3),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: AnimatedBottomButton(
                label: _isLoading ? "Creating Account..." : "Register",
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
