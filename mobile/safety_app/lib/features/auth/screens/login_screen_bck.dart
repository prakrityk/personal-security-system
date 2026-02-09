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
  bool _isCheckingBiometric = true;

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

  /// Check if biometric login should be shown
  Future<void> _checkBiometricAvailability() async {
    try {
      // Step 1: Check if device supports biometrics
      final deviceSupports = await _biometricService.isBiometricAvailable();
      
      if (!deviceSupports) {
        setState(() {
          _showBiometricOption = false;
          _isCheckingBiometric = false;
        });
        print('ℹ️ Device does not support biometrics');
        return;
      }

      // Step 2: Check if user previously enabled biometric
      final biometricEnabled = await _secureStorage.isBiometricEnabled();
      
      // Step 3: Check if refresh token exists (user was logged in before)
      final refreshToken = await _secureStorage.getRefreshToken();
      
      // ✅ FIXED THIS LINE: Check ALL conditions
      final shouldShow = deviceSupports && 
                         biometricEnabled && 
                         (refreshToken != null && refreshToken.isNotEmpty);

      setState(() {
        _showBiometricOption = shouldShow;
        _isCheckingBiometric = false;
      });

      print('✅ Biometric check complete:');
      print('   - Device supports: $deviceSupports');
      print('   - Previously enabled: $biometricEnabled');
      print('   - Has refresh token: ${refreshToken != null && refreshToken.isNotEmpty}');
      print('   - Show biometric: $shouldShow');

      // Optional: Auto-fill phone if available
      if (shouldShow) {
        final lastPhone = await _secureStorage.getLastLoginPhone();
        if (lastPhone != null && mounted) {
          _phoneController.text = lastPhone;
        }
      }
    } catch (e) {
      print('❌ Error checking biometric: $e');
      setState(() {
        _showBiometricOption = false;
        _isCheckingBiometric = false;
      });
    }
  }

  /// Handle regular password login with phone and password
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
      print('📱 Logging in with phone: $phone');
      
      final response = await _authApiService.login(
        phoneNumber: phone,
        password: password,
      );

      if (!mounted) return;

      final user = response.user;

      if (user != null) {
        // ✅ Save phone for future logins
        await _secureStorage.saveLastLoginPhone(phone);
        
        // ✅ ADDED: Prompt to enable biometric after successful login
        _promptEnableBiometric(phone);
        
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
      print('❌ Login error: $e');
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ✅ ADDED: Prompt to enable biometric after successful password login
  Future<void> _promptEnableBiometric(String phone) async {
    // Check if device supports biometrics
    final deviceSupports = await _biometricService.isBiometricAvailable();
    if (!deviceSupports) return;
    
    // Check if already enabled
    final alreadyEnabled = await _secureStorage.isBiometricEnabled();
    if (alreadyEnabled) return;
    
    // Show dialog to ask user
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          title: Text("Enable Biometric Login"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Do you want to enable biometric login for faster access?"),
              SizedBox(height: 8),
              Text(
                phone,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Not Now"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _enableBiometric();
              },
              child: Text("Enable"),
            ),
          ],
        ),
      );
    });
  }

  /// ✅ ADDED: Enable biometric authentication
  Future<void> _enableBiometric() async {
    try {
      // First authenticate with biometric
      final authenticated = await _biometricService.authenticate(
        reason: 'Enable biometric login for faster access',
      );
      
      if (authenticated) {
        await _secureStorage.setBiometricEnabled(true);
        _showSuccess("Biometric login enabled!");
      } else {
        _showError("Biometric authentication failed");
      }
    } catch (e) {
      print('❌ Failed to enable biometric: $e');
      _showError("Failed to enable biometric login");
    }
  }

  /// Handle biometric login
  Future<void> _handleBiometricLogin() async {
    setState(() => _isLoading = true);

    try {
      // Use existing refresh token to login
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
      
      // If refresh token is invalid/expired, remove biometric option
      if (e.toString().contains('Session expired') || 
          e.toString().contains('Invalid token') ||
          e.toString().contains('refresh')) {
        // Clear refresh token and biometric preference
        await _secureStorage.delete('access_token');
        await _secureStorage.delete('refresh_token');
        await _secureStorage.setBiometricEnabled(false);
        
        setState(() {
          _showBiometricOption = false;
        });
        
        _showError('Session expired. Please login with your password.');
      } else {
        print('❌ Biometric login error: $e');
        _showError('Biometric login failed: ${e.toString().replaceAll('Exception: ', '')}');
      }
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
        child: _isCheckingBiometric
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Column(
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

                          // ✅ BIOMETRIC OPTION - Always in same position
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
                                Expanded(
                                  child: Divider(color: Colors.grey.shade400),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    "or",
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(color: Colors.grey.shade400),
                                ),
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
                                      // TODO: Navigate to forgot password
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