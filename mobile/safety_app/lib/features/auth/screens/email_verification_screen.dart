import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/widgets/animated_bottom_button.dart';
import 'package:safety_app/core/widgets/app_text_field.dart';
import 'package:safety_app/core/widgets/onboarding_progress_indicator.dart';
import 'package:safety_app/services/firebase/firebase_auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'dart:async';

class EmailVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const EmailVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuthService _firebaseAuthService = FirebaseAuthService();

  bool _isLoading = false;
  bool _emailSent = false;
  bool _isPolling = false;
  Timer? _pollingTimer;
  int _pollingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _checkCurrentUserState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  /// 🔍 DIAGNOSTIC: Check current Firebase user state
  Future<void> _checkCurrentUserState() async {
    print('\n🔍 ========== EMAIL VERIFICATION SCREEN LOADED ==========');
    print('📱 Phone Number from previous screen: ${widget.phoneNumber}');
    
    final currentUser = _firebaseAuthService.currentUser;
    if (currentUser != null) {
      print('✅ Firebase user is signed in:');
      print('   UID: ${currentUser.uid}');
      print('   Phone: ${currentUser.phoneNumber}');
      print('   Email: ${currentUser.email ?? "NOT SET"}');
      print('   Email Verified: ${currentUser.emailVerified}');
      print('   Phone Verified: ${currentUser.phoneNumber != null}');
      
      // Test token generation immediately
      print('\n🧪 Testing token generation...');
      try {
        final token = await _firebaseAuthService.getFirebaseIdToken(forceRefresh: true);
        if (token != null) {
          print('✅ Token generation SUCCESSFUL');
          print('   Token length: ${token.length}');
        } else {
          print('❌ Token generation returned NULL');
        }
      } catch (e) {
        print('❌ Token generation FAILED: $e');
      }
    } else {
      print('❌ NO Firebase user signed in!');
      print('⚠️  This is a problem - user should be signed in after phone verification');
    }
    print('========================================================\n');
  }

  Future<void> _handleSendVerification() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Validation
    if (email.isEmpty || !email.contains('@')) {
      _showError("Please enter a valid email address");
      return;
    }

    if (password.isEmpty || password.length < 8) {
      _showError("Password must be at least 8 characters");
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('\n📧 ========== STARTING EMAIL LINKING ==========');
      print('Email: $email');
      print('Password: [HIDDEN]');
      
      // Check user before linking
      final userBefore = _firebaseAuthService.currentUser;
      print('\n👤 User state BEFORE linking:');
      print('   UID: ${userBefore?.uid}');
      print('   Phone: ${userBefore?.phoneNumber}');
      print('   Email: ${userBefore?.email ?? "NOT SET"}');
      
      // 1️⃣ Link email to Firebase account (phone already verified)
      print('\n🔗 Calling linkEmailToAccount...');
      await _firebaseAuthService.linkEmailToAccount(
        email: email,
        password: password,
      );
      print('✅ linkEmailToAccount completed');

      if (!mounted) return;

      // Check user after linking
      final userAfter = _firebaseAuthService.currentUser;
      print('\n👤 User state AFTER linking:');
      print('   UID: ${userAfter?.uid}');
      print('   Phone: ${userAfter?.phoneNumber}');
      print('   Email: ${userAfter?.email ?? "STILL NOT SET - ERROR!"}');
      print('   Email Verified: ${userAfter?.emailVerified}');

      // 2️⃣ Send verification email
      print('\n📨 Sending verification email...');
      await _firebaseAuthService.sendEmailVerification();
      print('✅ Verification email sent');

      if (!mounted) return;

      _showSuccess("Verification email sent to $email");

      setState(() {
        _emailSent = true;
        _isLoading = false;
      });

      print('========================================================\n');

      // 3️⃣ Start polling for email verification
      _startPollingEmailVerification();
    } catch (e) {
      print('\n❌ EMAIL LINKING FAILED: $e');
      print('Error type: ${e.runtimeType}');
      if (!mounted) return;
      _showError(e.toString().replaceAll('Exception: ', ''));
      setState(() => _isLoading = false);
    }
  }

  void _startPollingEmailVerification() {
    setState(() {
      _isPolling = true;
      _pollingSeconds = 0;
    });

    print('\n🔄 Starting email verification polling...');

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _pollingSeconds += 3;

      // Stop polling after 5 minutes
      if (_pollingSeconds > 300) {
        timer.cancel();
        setState(() => _isPolling = false);
        _showError("Verification timeout. Please click 'Check Status' manually.");
        return;
      }

      // Check if email is verified
      print('🔍 Checking email verification status (${_pollingSeconds}s elapsed)...');
      final isVerified = await _firebaseAuthService.checkEmailVerified();
      print('   Result: ${isVerified ? "✅ VERIFIED" : "⏳ Not verified yet"}');

      if (isVerified) {
        timer.cancel();
        if (!mounted) return;

        _showSuccess("Email verified successfully!");
        setState(() => _isPolling = false);

        print('\n✅ EMAIL VERIFIED - Preparing to navigate...');
        
        // Test token generation before navigation
        print('🧪 Testing final token generation...');
        try {
          final token = await _firebaseAuthService.getFirebaseIdToken(forceRefresh: true);
          if (token != null) {
            print('✅ Final token generated successfully (length: ${token.length})');
          } else {
            print('❌ Final token is NULL - this will cause registration to fail!');
          }
        } catch (e) {
          print('❌ Final token generation failed: $e');
        }

        // Navigate to registration screen
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;

        print('🚀 Navigating to registration screen...\n');
        context.pushReplacement('/registration', extra: {
          'phoneNumber': widget.phoneNumber,
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
        });
      }
    });
  }

  Future<void> _handleCheckStatus() async {
    setState(() => _isLoading = true);

    print('\n🔍 ========== MANUAL EMAIL CHECK ==========');

    try {
      final isVerified = await _firebaseAuthService.checkEmailVerified();
      print('Email verified: $isVerified');

      if (!mounted) return;

      if (isVerified) {
        _showSuccess("Email verified successfully!");

        // Test token before navigation
        print('🧪 Testing token generation...');
        final token = await _firebaseAuthService.getFirebaseIdToken(forceRefresh: true);
        print('Token: ${token != null ? "✅ Generated (${token.length})" : "❌ NULL"}');

        // Navigate to registration screen
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;

        print('🚀 Navigating to registration...\n');
        context.pushReplacement('/registration', extra: {
          'phoneNumber': widget.phoneNumber,
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
        });
      } else {
        _showError("Email not verified yet. Please check your inbox.");
      }
    } catch (e) {
      print('❌ Error: $e');
      if (!mounted) return;
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResendEmail() async {
    setState(() => _isLoading = true);

    try {
      print('\n📨 Resending verification email...');
      await _firebaseAuthService.sendEmailVerification();
      print('✅ Email resent');

      if (!mounted) return;

      _showSuccess("Verification email resent");

      // Restart polling
      _startPollingEmailVerification();
    } catch (e) {
      print('❌ Resend failed: $e');
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Email icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _emailSent ? Icons.mark_email_read : Icons.email_outlined,
                        size: 50,
                        color: AppColors.primaryGreen,
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      _emailSent ? "Check your email" : "Verify your email",
                      style: AppTextStyles.h3,
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    if (!_emailSent) ...[
                      Text(
                        "Enter your email address and create a password",
                        style: AppTextStyles.body.copyWith(
                          color: isDark
                              ? AppColors.darkHint
                              : AppColors.lightHint,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 32),

                      AppTextField(
                        label: "Email Address",
                        hint: "your.email@example.com",
                        controller: _emailController,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 16),

                      AppTextField(
                        label: "Password",
                        hint: "Create a secure password",
                        controller: _passwordController,
                        enabled: !_isLoading,
                        obscureText: true,
                      ),

                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Min 8 characters (this will be used for daily login)",
                          style: AppTextStyles.caption.copyWith(
                            color: isDark
                                ? AppColors.darkHint
                                : AppColors.lightHint,
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        "We've sent a verification link to",
                        style: AppTextStyles.body.copyWith(
                          color: isDark
                              ? AppColors.darkHint
                              : AppColors.lightHint,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 4),

                      Text(
                        _emailController.text,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGreen,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 24),

                      if (_isPolling) ...[
                        const CircularProgressIndicator(
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Waiting for verification...",
                          style: AppTextStyles.body.copyWith(
                            color: isDark
                                ? AppColors.darkHint
                                : AppColors.lightHint,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Resend button
                      TextButton(
                        onPressed: _isLoading ? null : _handleResendEmail,
                        child: Text(
                          "Resend verification email",
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

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
                              _emailSent
                                  ? "Click the link in your email to verify. Check spam folder if needed."
                                  : "You'll need this email and password for daily login",
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

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: OnboardingProgressIndicator(currentStep: 2, totalSteps: 4),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: AnimatedBottomButton(
                label: _isLoading
                    ? "Processing..."
                    : _emailSent
                        ? "Check Verification Status"
                        : "Send Verification Email",
                usePositioned: false,
                onPressed: _isLoading
                    ? () {}
                    : _emailSent
                        ? _handleCheckStatus
                        : _handleSendVerification,
              ),
            ),
          ],
        ),
      ),
    );
  }
}