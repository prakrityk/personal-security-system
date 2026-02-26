// lib/features/auth/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import 'package:safety_app/core/widgets/nepal_phone_field.dart';
import 'package:safety_app/features/auth/widgets/biometric_button.dart';
import 'package:safety_app/services/auth_api_service.dart';
import 'package:safety_app/services/biometric_service.dart';
import 'package:safety_app/core/storage/secure_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'package:safety_app/services/firebase/firebase_auth_service.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:safety_app/core/widgets/app_text_field.dart';
import 'package:safety_app/services/native_back_tap_service.dart'; // 👈 ADD THIS IMPORT

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Controller now holds ONLY local digits (e.g. "9812345678")
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthApiService _authApiService = AuthApiService();
  final BiometricService _biometricService = BiometricService();
  final SecureStorageService _secureStorage = SecureStorageService();
  final FirebaseAuthService _firebaseAuthService = FirebaseAuthService();

  bool _isLoading = false;
  bool _showBiometricOption = false;
  bool _isBiometricCheckComplete = false;

  @override
  void initState() {
    super.initState();
    _initializeBiometric();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initializeBiometric() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _debugBiometricSetup();
    await _checkBiometricAvailability();
  }

  Future<void> _debugBiometricSetup() async {
    print('\n╔═══════════════════════════════════════════════════╗');
    print('║     BIOMETRIC SETUP DIAGNOSTIC (Login Screen)     ║');
    print('╚═══════════════════════════════════════════════════╝\n');

    try {
      final canCheck = await _biometricService.canCheckBiometrics();
      print('1️⃣  Can check biometrics: $canCheck');
      final available = await _biometricService.getAvailableBiometrics();
      print('2️⃣  Available biometrics: $available');
      final isAvailable = await _biometricService.isBiometricAvailable();
      print('3️⃣  Biometric is available: $isAvailable');
      final refreshToken = await _secureStorage.getRefreshToken();
      print('4️⃣  Refresh token exists: ${refreshToken != null}');
      final biometricEnabled = await _secureStorage.isBiometricEnabled();
      print('5️⃣  Biometric enabled flag: $biometricEnabled');
      final lastPhone = await _secureStorage.getLastLoginPhone();
      print('6️⃣  Last login phone: $lastPhone');
      final accessToken = await _secureStorage.getAccessToken();
      print('7️⃣  Access token exists: ${accessToken != null}');
      print('\n✅ DIAGNOSIS COMPLETE\n');
    } catch (e) {
      print('❌ Error during diagnostic: $e\n');
    }
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final deviceSupports = await _biometricService.isBiometricAvailable();
      final refreshToken = await _secureStorage.getRefreshToken();
      final hasRefreshToken = refreshToken != null && refreshToken.isNotEmpty;
      final biometricEnabled = await _secureStorage.isBiometricEnabled();
      final shouldShow = deviceSupports && hasRefreshToken && biometricEnabled;

      if (mounted) {
        setState(() {
          _showBiometricOption = shouldShow;
          _isBiometricCheckComplete = true;
        });
      }

      if (shouldShow) {
        final lastPhone = await _secureStorage.getLastLoginPhone();
        // lastPhone is stored as full number (+97798XXXXXXXX).
        // Strip the +977 prefix before showing in the local-only field.
        if (lastPhone != null && lastPhone.isNotEmpty && mounted) {
          final localPart = lastPhone.startsWith('+977')
              ? lastPhone.substring(4)
              : lastPhone;
          print('✅ Pre-filling local phone digits: $localPart');
          _phoneController.text = localPart;
        }
      }
    } catch (e) {
      print('❌ Error checking biometric availability: $e\n');
      if (mounted) {
        setState(() {
          _showBiometricOption = false;
          _isBiometricCheckComplete = true;
        });
      }
    }
  }

  // ============================================================================
  // 🔐 LOGIN
  // ============================================================================

  Future<void> _handleLogin() async {
    final localDigits = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (localDigits.isEmpty || password.isEmpty) {
      _showError("Please fill all fields");
      return;
    }

    if (localDigits.length != 10) {
      _showError("Please enter a valid 10-digit phone number");
      return;
    }

    // Always build full E.164 number for the API
    final phone = NepalPhoneField.fullNumber(localDigits);

    setState(() => _isLoading = true);

    try {
      print('📱 Attempting normal login with phone: $phone');

      dynamic response;

      try {
        response = await _authApiService.login(
          phoneNumber: phone,
          password: password,
        );
        print('✅ Normal login succeeded');
        final user = await ref.read(authApiServiceProvider).fetchCurrentUser();
        ref.read(authStateProvider.notifier).updateUser(user);
      } catch (e) {
        final errorMsg = e.toString();
        print('⚠️ Normal login failed: $errorMsg');

        if (errorMsg.contains('Invalid phone number or password') ||
            errorMsg.contains('Invalid credentials')) {
          print('🔥 Trying Firebase login fallback...');
          response = await _firebaseFallbackLogin(phone, password);
        } else {
          rethrow;
        }
      }

      if (!mounted) return;

      final user = response.user;

      if (user != null) {
        print('✅ Login successful for: ${user.fullName}');

        // Save full number for pre-fill next time
        await _secureStorage.saveLastLoginPhone(phone);

        // ✅ Persist access token for NativeBackTapService
        try {
          final accessToken = await _secureStorage.getAccessToken();
          if (accessToken != null) {
            await NativeBackTapService.instance.saveToken(accessToken);
            final hasToken = await NativeBackTapService.instance.hasToken();
            debugPrint('📝 Token persisted: $hasToken');
          } else {
            debugPrint(
              '⚠️ No access token found to persist for NativeBackTapService',
            );
          }
        } catch (e) {
          debugPrint(
            '⚠️ NativeBackTapService token save failed (continuing anyway): $e',
          );
        }

        print('🔄 Refreshing auth state...');
        await ref.read(authStateProvider.notifier).refreshUser();
        print('✅ Auth state refreshed');

        _showSuccess("Welcome back, ${user.fullName}!");

        bool deviceSupports = false;
        bool biometricEnabled = false;

        try {
          await Future.delayed(const Duration(milliseconds: 300));
          deviceSupports = await _biometricService.isBiometricAvailable();
          biometricEnabled = await _secureStorage.isBiometricEnabled();
        } catch (e) {
          print('⚠️ Biometric check failed (continuing anyway): $e');
        }

        if (user.hasRole) {
          context.go('/home');
        } else {
          context.go('/role-intent');
        }

        if (deviceSupports && !biometricEnabled) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) _promptEnableBiometric();
          });
        }
      } else {
        _showError("Login failed: No user data received");
      }
    } catch (e) {
      print('❌ Login error: $e');
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<dynamic> _firebaseFallbackLogin(String phone, String password) async {
    try {
      print('📧 Auto-fetching email from backend for phone: $phone');
      final email = await _authApiService.getEmailByPhone(phone);

      if (email == null || email.isEmpty) {
        throw Exception(
          'No email found for this phone number. Please contact support.',
        );
      }

      print('✅ Retrieved email: $email');
      final idToken = await _firebaseAuthService.signInWithEmail(
        email: email,
        password: password,
      );

      final response = await _authApiService.firebaseLogin(
        firebaseToken: idToken,
        password: password,
      );

      print('✅ Backend verified token and synced password hash');
      return response;
    } catch (e) {
      print('❌ Firebase fallback login failed: $e');
      rethrow;
    }
  }

  Future<void> _handleForgotPassword() async {
    final localDigits = _phoneController.text.trim();

    if (localDigits.isEmpty) {
      _showError("Please enter your phone number first");
      return;
    }

    final phone = NepalPhoneField.fullNumber(localDigits);

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset Password"),
        content: Text(
          "We'll send a password reset link to the email associated with $phone.\n\nContinue?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Send Link"),
          ),
        ],
      ),
    );

    if (shouldProceed != true) return;

    try {
      setState(() => _isLoading = true);

      final email = await _authApiService.getEmailByPhone(phone);

      if (email == null || email.isEmpty) {
        throw Exception('No email found for this phone number.');
      }

      await _firebaseAuthService.sendPasswordResetEmail(email);

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Email Sent"),
          content: Text(
            "A password reset link has been sent to:\n\n$email\n\n"
            "Please check your inbox and follow the instructions.",
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      print('❌ Password reset error: $e');
      if (!mounted) return;
      _showError("Failed to send reset link: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _promptEnableBiometric() async {
    if (!mounted) return;

    final shouldEnable = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enable Biometric Login?"),
        content: const Text(
          "Would you like to use fingerprint/face recognition for faster login?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Not now"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Enable"),
          ),
        ],
      ),
    );

    if (shouldEnable == true) await _enableBiometric();
  }

  Future<void> _enableBiometric() async {
    try {
      final isAvailable = await _biometricService.isBiometricAvailable();
      if (!isAvailable) {
        throw Exception(
          "Biometric authentication not available on this device",
        );
      }

      final authenticated = await _biometricService.authenticate(
        reason: "Verify your identity to enable biometric login",
      );

      if (!authenticated) throw Exception("Biometric authentication failed");

      await _secureStorage.setBiometricEnabled(true);

      if (!mounted) return;
      setState(() => _showBiometricOption = true);
      _showSuccess("Biometric login enabled!");
    } catch (e) {
      if (!mounted) return;
      _showError("Could not enable biometric: ${e.toString()}");
    }
  }

  Future<void> _handleBiometricLogin() async {
    setState(() => _isLoading = true);

    try {
      final response = await _authApiService.biometricLogin();
      if (!mounted) return;

      // ✅ Persist access token for NativeBackTapService after biometric login
      try {
        final accessToken = await _secureStorage.getAccessToken();
        if (accessToken != null) {
          await NativeBackTapService.instance.saveToken(accessToken);
          final hasToken = await NativeBackTapService.instance.hasToken();
          debugPrint('📝 Token persisted (biometric): $hasToken');
        } else {
          debugPrint(
            '⚠️ No access token found to persist after biometric login',
          );
        }
      } catch (e) {
        debugPrint(
          '⚠️ NativeBackTapService token save failed after biometric (continuing anyway): $e',
        );
      }

      _showSuccess("Welcome back!");

      if (response.user?.hasRole ?? false) {
        context.go('/home');
      } else {
        context.go('/role-intent');
      }
    } catch (e) {
      if (!mounted) return;

      if (e.toString().contains('Session expired') ||
          e.toString().contains('Invalid token') ||
          e.toString().contains('refresh')) {
        await _secureStorage.delete('access_token');
        await _secureStorage.delete('refresh_token');
        await _secureStorage.setBiometricEnabled(false);

        if (mounted) setState(() => _showBiometricOption = false);
        _showError('Session expired. Please login with your password.');
      } else {
        _showError('Biometric login failed: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
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
    if (!mounted) return;
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

                    // BIOMETRIC BUTTON
                    if (_isBiometricCheckComplete && _showBiometricOption) ...[
                      Center(
                        child: BiometricLoginButton(
                          isLoading: _isLoading,
                          onSuccess: _handleBiometricLogin,
                          onError: (error) => _showError(error),
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

                    // ✅ Replaced AppTextField with NepalPhoneField
                    NepalPhoneField(
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
                        onPressed: _isLoading ? null : _handleForgotPassword,
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
                              : () => context.go('/lets-get-started'),
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
