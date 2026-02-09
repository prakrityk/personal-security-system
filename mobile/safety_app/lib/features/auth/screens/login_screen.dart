// lib/features/auth/screens/login_screen.dart
// FIXED VERSION - Automatic email lookup for Firebase fallback login

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import 'package:safety_app/core/widgets/app_text_field.dart';
import 'package:safety_app/features/auth/widgets/biometric_button.dart';
import 'package:safety_app/services/auth_api_service.dart';
import 'package:safety_app/services/biometric_service.dart';
import 'package:safety_app/core/storage/secure_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'package:safety_app/services/firebase/firebase_auth_service.dart';
import 'package:safety_app/core/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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

  /// Initialize biometric check and debug
  Future<void> _initializeBiometric() async {
    // ✅ FIX: Add delay to ensure platform channels are ready
    await Future.delayed(const Duration(milliseconds: 500));
    await _debugBiometricSetup();
    await _checkBiometricAvailability();
  }

  /// Debug biometric setup - call this to diagnose issues
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
      if (refreshToken != null && refreshToken.isNotEmpty) {
        print('    Token length: ${refreshToken.length}');
      }
      
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

  /// Check if biometric option should be shown
  Future<void> _checkBiometricAvailability() async {
    try {
      print('🔍 Checking biometric availability...');
      
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

      print('🔍 Biometric availability check:');
      print('   ✓ Device supports: $deviceSupports');
      print('   ✓ Has refresh token: $hasRefreshToken');
      print('   ✓ Biometric enabled: $biometricEnabled');
      print('   → Show biometric button: $shouldShow\n');

      if (shouldShow) {
        final lastPhone = await _secureStorage.getLastLoginPhone();
        if (lastPhone != null && lastPhone.isNotEmpty && mounted) {
          print('✅ Pre-filling phone: $lastPhone');
          _phoneController.text = lastPhone;
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
  // 🔐 LOGIN — tries normal first, falls back to Firebase if 401
  // ============================================================================

  /// Handle regular password login.
  /// Flow:
  ///   1. Try POST /auth/login (phone + password against DB hash)
  ///   2. If 401 → password might have been reset via Firebase.
  ///      Fall back to Firebase login:
  ///        a. Auto-fetch user's email from backend using phone
  ///        b. Sign into Firebase with email + new password
  ///        c. Get Firebase ID token
  ///        d. POST /auth/firebase/login with token + password
  ///           → backend verifies token, syncs password hash, returns JWTs
  ///   3. Navigate on success.
  Future<void> _handleLogin() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      _showError("Please fill all fields");
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('📱 Attempting normal login with phone: $phone');

      dynamic response;

      try {
        // ── Step 1: Try normal login ──────────────────────────────────
        response = await _authApiService.login(
          phoneNumber: phone,
          password: password,
        );
        print('✅ Normal login succeeded');

      } catch (e) {
        // ── Step 2: If 401, try Firebase fallback ─────────────────────
        final errorMsg = e.toString();
        print('⚠️ Normal login failed: $errorMsg');

        if (errorMsg.contains('Invalid phone number or password') ||
            errorMsg.contains('Invalid credentials')) {
          print('🔥 Trying Firebase login fallback (password may have been reset)...');
          response = await _firebaseFallbackLogin(phone, password);
        } else {
          // Not a credentials error — rethrow as-is
          rethrow;
        }
      }

      // ── Step 3: Success — navigate ────────────────────────────────
      if (!mounted) return;

      final user = response.user;

      if (user != null) {
        print('✅ Login successful for: ${user.fullName}');

        // Save phone for future reference
        await _secureStorage.saveLastLoginPhone(phone);

        // ✅ CRITICAL: Refresh auth state so router knows user is logged in
        print('🔄 Refreshing auth state...');
        await ref.read(authStateProvider.notifier).refreshUser();
        print('✅ Auth state refreshed');

        _showSuccess("Welcome back, ${user.fullName}!");

        // ✅ FIX: Wrap biometric check in try-catch with delay
        bool deviceSupports = false;
        bool biometricEnabled = false;
        
        try {
          // Add small delay to ensure platform channels are ready
          await Future.delayed(const Duration(milliseconds: 300));
          
          deviceSupports = await _biometricService.isBiometricAvailable();
          biometricEnabled = await _secureStorage.isBiometricEnabled();

          print('🔐 Post-login biometric check:');
          print('   Device supports: $deviceSupports');
          print('   Already enabled: $biometricEnabled');
        } catch (e) {
          print('⚠️ Biometric check failed (continuing anyway): $e');
          // Don't crash - just skip biometric setup
          deviceSupports = false;
          biometricEnabled = false;
        }

        // Navigate first
        if (user.hasRole) {
          context.go('/home');
        } else {
          context.go('/role-intent');
        }

        // Prompt to enable biometric if device supports it and user hasn't enabled yet
        if (deviceSupports && !biometricEnabled) {
          print('💡 Prompting user to enable biometric...');
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

  /// Firebase fallback login when normal login fails.
  /// Auto-fetches email from backend using phone number.
  Future<dynamic> _firebaseFallbackLogin(String phone, String password) async {
    try {
      print('📧 Step 2a: Auto-fetching email from backend for phone: $phone');

      // Call your backend to get the email for this phone
      final email = await _authApiService.getEmailByPhone(phone);

      if (email == null || email.isEmpty) {
        throw Exception('No email found for this phone number. Please contact support.');
      }

      print('✅ Retrieved email: $email');
      print('🔥 Step 2b: Signing into Firebase with email + new password...');

      // Sign into Firebase with email + password
      final idToken = await _firebaseAuthService.signInWithEmail(
        email: email,
        password: password,
      );

      print('✅ Firebase login successful');
      print('🔑 Got Firebase ID token (length: ${idToken.length})');
      print('🔄 Step 2c: Sending to backend /auth/login...');

      // Send to backend with Firebase token
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

  /// Forgot password flow
  Future<void> _handleForgotPassword() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      _showError("Please enter your phone number first");
      return;
    }

    // Show dialog to confirm
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset Password"),
        content: Text(
          "We'll send a password reset link to the email associated with $phone.\n\n"
          "Continue?",
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

      // 1. Get email from backend
      print('📧 Fetching email for phone: $phone');
      final email = await _authApiService.getEmailByPhone(phone);

      if (email == null || email.isEmpty) {
        throw Exception('No email found for this phone number.');
      }

      print('✅ Email found: $email');
      print('📧 Sending Firebase password reset email...');

      // 2. Send Firebase password reset email
      await _firebaseAuthService.sendPasswordResetEmail(email);

      if (!mounted) return;

      // 3. Show success message
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

  /// Prompt user to enable biometric authentication
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

    if (shouldEnable == true) {
      await _enableBiometric();
    }
  }

  /// Enable biometric authentication
  Future<void> _enableBiometric() async {
    try {
      print('🔐 Enabling biometric authentication...');

      // Verify biometric capability
      final isAvailable = await _biometricService.isBiometricAvailable();
      if (!isAvailable) {
        throw Exception("Biometric authentication not available on this device");
      }

      // Authenticate once to confirm
      final authenticated = await _biometricService.authenticate(
        reason: "Verify your identity to enable biometric login",
      );

      if (!authenticated) {
        throw Exception("Biometric authentication failed");
      }

      // Enable biometric flag
      await _secureStorage.setBiometricEnabled(true);
      print('✅ Biometric enabled successfully');

      if (!mounted) return;

      setState(() {
        _showBiometricOption = true;
      });

      _showSuccess("Biometric login enabled!");
    } catch (e) {
      print('❌ Failed to enable biometric: $e');
      if (!mounted) return;
      _showError("Could not enable biometric: ${e.toString()}");
    }
  }

  /// Handle biometric login
  /// This is called when user taps the biometric button
  Future<void> _handleBiometricLogin() async {
    print('\n🔐 STARTING BIOMETRIC LOGIN FLOW\n');
    
    setState(() => _isLoading = true);

    try {
      print('Step 1️⃣: Authenticating with biometric...');
      
      print('Step 2️⃣: Calling API biometricLogin()...');
      final response = await _authApiService.biometricLogin();

      if (!mounted) return;

      print('Step 3️⃣: Biometric login successful!');
      _showSuccess("Welcome back!");
      
      if (response.user?.hasRole ?? false) {
        print('✅ User has role, navigating to /home');
        context.go('/home');
      } else {
        print('⚠️ User has no role, navigating to /role-intent');
        context.go('/role-intent');
      }
      
      print('✅ BIOMETRIC LOGIN COMPLETE\n');
    } catch (e) {
      if (!mounted) return;
      
      print('❌ Biometric login failed: $e');
      
      if (e.toString().contains('Session expired') || 
          e.toString().contains('Invalid token') ||
          e.toString().contains('refresh')) {
        print('⚠️ Token expired, clearing biometric...');
        
        await _secureStorage.delete('access_token');
        await _secureStorage.delete('refresh_token');
        await _secureStorage.setBiometricEnabled(false);
        
        if (mounted) {
          setState(() {
            _showBiometricOption = false;
          });
        }
        
        _showError('Session expired. Please login with your password.');
      } else {
        _showError('Biometric login failed: ${e.toString()}');
      }
      
      print('❌ BIOMETRIC LOGIN FAILED\n');
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

                    // PASSWORD LOGIN FIELDS
                    AppTextField(
                      label: "Phone Number",
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
                              : () {
                                  context.go('/lets-get-started');
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