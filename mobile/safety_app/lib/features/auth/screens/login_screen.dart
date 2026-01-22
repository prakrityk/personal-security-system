import 'package:flutter/material.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import 'package:safety_app/core/widgets/app_text_field.dart';
import 'package:safety_app/features/intent/screens/role_intent_screen.dart';
import 'package:safety_app/features/onboarding/screens/lets_get_started_screen.dart';
import 'package:safety_app/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailOrPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailOrPhoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final emailOrPhone = _emailOrPhoneController.text.trim();
    final password = _passwordController.text.trim();

    // Validation
    if (emailOrPhone.isEmpty || password.isEmpty) {
      _showError("Please fill all fields");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Call API
      final response = await _authService.login(
        email: emailOrPhone,
        password: password,
      );

      if (!mounted) return;

      // Success message with user name
      _showSuccess("Welcome back, ${response.user.fullName}!");

      // Navigate to next screen
      // Using pushReplacement to prevent going back to login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RoleIntentScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Show error message
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Welcome back", style: AppTextStyles.heading),
                    const SizedBox(height: 8),
                    Text("Login to continue", style: AppTextStyles.body),

                    const SizedBox(height: 40),

                    AppTextField(
                      label: "Phone or Email",
                      hint: "98XXXXXXXX or email",
                      controller: _emailOrPhoneController,
                      enabled: !_isLoading, // Disable when loading
                    ),

                    const SizedBox(height: 16),

                    AppTextField(
                      label: "Password",
                      obscureText: true,
                      controller: _passwordController,
                      enabled: !_isLoading, // Disable when loading
                    ),

                    const SizedBox(height: 12),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : () {
                          // TODO: Navigate to forgot password screen
                        },
                        child: Text(
                          "Forgot password?",
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: AppTextStyles.bodySmall,
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: _isLoading ? null : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LetsGetStartedScreen(),
                              ),
                            );
                          },
                          child: Text(
                            "Sign up",
                            style: AppTextStyles.bodySmall.copyWith(
                              color: _isLoading 
                                  ? Colors.grey 
                                  : AppColors.primaryGreen,
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
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: AnimatedBottomButton(
                label: _isLoading ? "Logging in..." : "Login",
                usePositioned: false,
                onPressed: _isLoading ? () {} : _handleLogin,
              ),
            ),
          ],
        ),
      ),
    );
  }
}