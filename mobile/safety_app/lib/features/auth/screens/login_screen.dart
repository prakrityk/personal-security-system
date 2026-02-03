// lib/features/auth/screens/login_screen.dart
// FIXED VERSION - Better biometric state management and error handling

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
import 'package:safety_app/services/firebase/firebase_auth_service.dart';

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
  final FirebaseAuthService _firebaseAuthService = FirebaseAuthService();

  bool _isLoading = false;
  bool _showBiometricOption = false;
  bool _isBiometricCheckComplete = false; // ✅ Track if check is done

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
    // ✅ Run debug first
    await _debugBiometricSetup();
    
    // Then check availability
    await _checkBiometricAvailability();
  }

  /// Debug biometric setup - call this to diagnose issues
  Future<void> _debugBiometricSetup() async {
    print('\n╔═══════════════════════════════════════════════════╗');
    print('║     BIOMETRIC SETUP DIAGNOSTIC (Login Screen)     ║');
    print('╚═══════════════════════════════════════════════════╝\n');
    
    try {
      // 1. Device support
      final canCheck = await _biometricService.canCheckBiometrics();
      print('1️⃣  Can check biometrics: $canCheck');
      
      // 2. Available biometrics
      final available = await _biometricService.getAvailableBiometrics();
      print('2️⃣  Available biometrics: $available');
      
      // 3. Is available (device + enrolled)
      final isAvailable = await _biometricService.isBiometricAvailable();
      print('3️⃣  Biometric is available: $isAvailable');
      
      // 4. Refresh token
      final refreshToken = await _secureStorage.getRefreshToken();
      print('4️⃣  Refresh token exists: ${refreshToken != null}');
      if (refreshToken != null && refreshToken.isNotEmpty) {
        print('    Token length: ${refreshToken.length}');
      }
      
      // 5. Biometric flag
      final biometricEnabled = await _secureStorage.isBiometricEnabled();
      print('5️⃣  Biometric enabled flag: $biometricEnabled');
      
      // 6. Last phone
      final lastPhone = await _secureStorage.getLastLoginPhone();
      print('6️⃣  Last login phone: $lastPhone');
      
      // 7. Access token (for current session)
      final accessToken = await _secureStorage.getAccessToken();
      print('7️⃣  Access token exists: ${accessToken != null}');
      
      print('\n✅ DIAGNOSIS COMPLETE\n');
      
    } catch (e) {
      print('❌ Error during diagnostic: $e\n');
    }
  }

  /// Check if biometric option should be shown
  /// Show if: Device supports + Has refresh token + User enabled biometric
  Future<void> _checkBiometricAvailability() async {
    try {
      print('🔍 Checking biometric availability...');
      
      // Check device support
      final deviceSupports = await _biometricService.isBiometricAvailable();
      
      // Check if user has refresh token (means they logged in before)
      final refreshToken = await _secureStorage.getRefreshToken();
      final hasRefreshToken = refreshToken != null && refreshToken.isNotEmpty;
      
      // Check if user explicitly enabled biometric
      final biometricEnabled = await _secureStorage.isBiometricEnabled();
      
      // Show biometric if all conditions are met
      final shouldShow = deviceSupports && hasRefreshToken && biometricEnabled;
      
      // ✅ Update state with checked flag
      if (mounted) {
        setState(() {
          _showBiometricOption = shouldShow;
          _isBiometricCheckComplete = true; // Mark check as done
        });
      }

      print('🔍 Biometric availability check:');
      print('   ✓ Device supports: $deviceSupports');
      print('   ✓ Has refresh token: $hasRefreshToken');
      print('   ✓ Biometric enabled: $biometricEnabled');
      print('   → Show biometric button: $shouldShow\n');

      // Pre-fill phone if available
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
  ///        a. Sign into Firebase with email + new password
  ///        b. Get Firebase ID token
  ///        c. POST /auth/firebase/login with token + password
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

        _showSuccess("Welcome back, ${user.fullName}!");

        // Check if we should prompt for biometric setup
        final deviceSupports = await _biometricService.isBiometricAvailable();
        final biometricEnabled = await _secureStorage.isBiometricEnabled();

        print('🔐 Post-login biometric check:');
        print('   Device supports: $deviceSupports');
        print('   Already enabled: $biometricEnabled');

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

  /// Firebase fallback login.
  /// Called when normal /auth/login returns 401 — likely means password was
  /// reset via Firebase but the DB hash is still the old one.
  ///
  /// Signs into Firebase with email + password to prove the password is valid
  /// on Firebase's side, grabs a Firebase ID token, then sends both to
  /// /auth/firebase/login which syncs the DB and issues JWTs.
  ///
  /// We need the user's email for Firebase sign-in. We look it up from the
  /// phone number — if Firebase sign-in fails it means the password really
  /// is wrong (not a reset scenario) and we surface a clean error.
  Future<dynamic> _firebaseFallbackLogin(String phone, String password) async {
    try {
      // We don't have the email in the login form, so we ask for it.
      // Show a quick dialog to get the email.
      final email = await _askForEmail();
      if (email == null) {
        // User cancelled
        throw Exception('Login cancelled');
      }

      print('🔥 Signing into Firebase with email: $email');

      // Sign into Firebase → this will throw if password is truly wrong
      final firebaseToken = await _firebaseAuthService.signInWithEmail(
        email: email,
        password: password,
      );

      print('✅ Firebase sign-in succeeded, sending token to backend');

      // Send token + password to backend — it verifies, syncs hash, issues JWTs
      final response = await _authApiService.firebaseLogin(
        firebaseToken: firebaseToken,
        password: password,
      );

      print('✅ Firebase fallback login complete');
      return response;

    } catch (e) {
      print('❌ Firebase fallback failed: $e');
      // Clean up the error message for the user
      final msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('Incorrect password') || msg.contains('wrong-password')) {
        throw Exception('Invalid phone number or password');
      }
      throw Exception(msg);
    }
  }

  /// Show a small dialog that asks the user for their email.
  /// Returns null if the user cancels.
  Future<String?> _askForEmail() async {
    final emailController = TextEditingController();
    String? result;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Verify Your Email"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "It looks like your password was recently reset. Please enter your email to continue.",
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email",
                hintText: "you@example.com",
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              result = emailController.text.trim();
              Navigator.of(dialogContext).pop();
            },
            child: const Text("Continue"),
          ),
        ],
      ),
    );

    emailController.dispose();

    if (result != null && result!.isEmpty) return null;
    return result;
  }

  // ============================================================================
  // FORGOT PASSWORD
  // ============================================================================

  /// Show a dialog asking for email, then fire Firebase reset email
  Future<void> _handleForgotPassword() async {
    final emailController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Reset Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter your registered email. We'll send you a link to reset your password.",
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email",
                hintText: "you@example.com",
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text("Send Link"),
          ),
        ],
      ),
    );

    if (result != true) return;

    final email = emailController.text.trim();
    emailController.dispose();

    if (email.isEmpty) {
      _showError("Please enter your email.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _firebaseAuthService.sendPasswordResetEmail(email);

      if (mounted) {
        // Always show this message — even if email doesn't exist (security)
        _showSuccess("If this email is registered, you'll receive a reset link.");
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  /// Prompt user to enable biometric
  Future<void> _promptEnableBiometric() async {
    if (!mounted) return;

    final phone = _phoneController.text.trim();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Enable Biometric Login?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Login faster next time using your fingerprint or face.",
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.phone_android,
                    size: 16,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      phone,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("Not Now"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text("Enable"),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      _enableBiometric();
    }
  }

  /// Enable biometric authentication
  Future<void> _enableBiometric() async {
    try {
      print('🔐 Requesting biometric authentication for setup...');
      
      final authenticated = await _biometricService.authenticate(
        reason: 'Authenticate to enable biometric login',
      );

      if (authenticated) {
        print('✅ User authenticated with biometric');
        
        // Save biometric enabled flag
        await _secureStorage.setBiometricEnabled(true);
        print('✅ Biometric enabled flag saved');
        
        _showSuccess("Biometric login enabled! You can use it on next login.");
        
        // ✅ Update UI immediately
        if (mounted) {
          setState(() {
            _showBiometricOption = true;
          });
        }
      } else {
        print('❌ User cancelled biometric authentication');
      }
    } catch (e) {
      print('❌ Error enabling biometric: $e');
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
      // Note: The button already handles the biometric prompt
      // This is called AFTER the button successfully authenticates
      
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
      
      // If token is invalid/expired
      if (e.toString().contains('Session expired') || 
          e.toString().contains('Invalid token') ||
          e.toString().contains('refresh')) {
        print('⚠️ Token expired, clearing biometric...');
        
        // Clear tokens and biometric
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

                    // ✅ BIOMETRIC BUTTON (only show if check is complete)
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