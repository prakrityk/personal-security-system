// lib/features/auth/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import 'package:safety_app/core/widgets/app_text_field.dart';
import 'package:safety_app/features/auth/widgets/biometric_button.dart';
import 'package:safety_app/services/auth_api_service.dart';
import 'package:safety_app/services/biometric_service.dart';
import 'package:safety_app/core/storage/secure_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthApiService _authApiService = AuthApiService();
  final BiometricService _biometricService = BiometricService();
  final SecureStorageService _secureStorage = SecureStorageService();

  bool _isLoading = false;
  bool _showBiometricOption = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Check if biometric login is available for this user
  Future<void> _checkBiometricAvailability() async {
    try {
      final isBiometricAvailable = await _biometricService.isBiometricAvailable();
      
      // Also check if user has biometric enabled (check secure storage)
      final hasSavedBiometricData = await _secureStorage.containsKey('biometric_user_id');
      
      if (!mounted) return;
      
      setState(() {
        _showBiometricOption = isBiometricAvailable && hasSavedBiometricData;
      });

      print('✅ Biometric available: $isBiometricAvailable');
      print('✅ Has saved biometric data: $hasSavedBiometricData');
    } catch (e) {
      print('❌ Error checking biometric: $e');
    }
  }

  /// Handle regular password login
  Future<void> _handleLogin() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    // Validation
    if (phone.isEmpty || password.isEmpty) {
      _showError("Please fill all fields");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _authApiService.login(
        email: phone,
        password: password,
      );

      if (!mounted) return;

      final user = response.user;

      if (user != null) {
        _showSuccess("Welcome back, ${user.fullName}!");

        if (user.hasRole) {
          context.go('/home');
        } else {
          context.go('/role-intent');
        }
      } else {
        _showError("Login successful, but user data not found.");
      }
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Handle biometric login
Future<void> _handleBiometricLogin() async {
  setState(() => _isLoading = true);

  try {
    // Biometric login uses existing refresh token
    final response = await _authApiService.biometricLogin();

    if (!mounted) return;

    _showSuccess("Welcome back!");
    
    if (response.user?.hasRole ?? false) {
      context.go('/home');
    } else {
      context.go('/role-intent');
    }
  } catch (e) {
    if (!mounted) return;
    _showError('Failed to login: ${e.toString().replaceAll('Exception: ', '')}');
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

                    // ✅ BIOMETRIC OPTION - Show if available
                    if (_showBiometricOption) ...[
                      Center(
                        child: BiometricLoginButton(
                          isLoading: _isLoading,
                          onSuccess: _handleBiometricLogin,
                          onError: (error) {
                            _showError(error);
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade400)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              "or",
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade400)),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ✅ PASSWORD LOGIN
                    AppTextField(
                      label: "Phone",
                      hint: "+977XXXXXXXX",
                      controller: _phoneController,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),

                    AppTextField(
                      label: "Password",
                      obscureText: true,
                      controller: _passwordController,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 12),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
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
                          onTap: _isLoading
                              ? null
                              : () {
                                  context.push('/lets-get-started');
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