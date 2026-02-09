// lib/features/auth/widgets/biometric_button.dart
// FIXED VERSION - Better error handling, logging, and user experience

import 'package:flutter/material.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/services/biometric_service.dart';

/// Biometric login button widget
/// Triggers fingerprint/face authentication and calls onSuccess callback
class BiometricLoginButton extends StatefulWidget {
  final VoidCallback onSuccess;
  final Function(String)? onError; // Optional error callback with error message
  final bool isLoading;

  const BiometricLoginButton({
    Key? key,
    required this.onSuccess,
    this.onError,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<BiometricLoginButton> createState() => _BiometricLoginButtonState();
}

class _BiometricLoginButtonState extends State<BiometricLoginButton>
    with SingleTickerProviderStateMixin {
  final BiometricService _biometricService = BiometricService();
  bool _isAuthenticating = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Handle biometric login attempt
  /// This authenticates the user with fingerprint/face
  /// Then calls onSuccess() callback to trigger API login
  Future<void> _handleBiometricLogin() async {
    // Don't allow concurrent authentication attempts
    if (_isAuthenticating || widget.isLoading) {
      print('⚠️ Already authenticating, ignoring tap');
      return;
    }

    print('\n╔═══════════════════════════════════════════════════╗');
    print('║      BIOMETRIC LOGIN BUTTON PRESSED              ║');
    print('╚═══════════════════════════════════════════════════╝\n');

    setState(() => _isAuthenticating = true);
    _animationController.repeat();

    try {
      print('Step 1️⃣: Requesting biometric authentication...');
      
      final isAuthenticated = await _biometricService.authenticate(
        reason: 'Authenticate to log in to your account',
      );

      if (!mounted) {
        print('⚠️ Widget disposed during authentication');
        return;
      }

      if (isAuthenticated) {
        print('Step 2️⃣: Authentication successful! ✅');
        print('Step 3️⃣: Calling parent onSuccess() callback...\n');
        
        // Stop animation before callback
        _animationController.stop();
        setState(() => _isAuthenticating = false);
        
        // Call parent callback to trigger API login
        widget.onSuccess();
        
        print('✅ BiometricLoginButton completed successfully\n');
      } else {
        print('Step 2️⃣: Authentication cancelled by user ❌\n');
        
        if (!mounted) return;

        // Stop animation
        _animationController.stop();
        setState(() => _isAuthenticating = false);

        const errorMsg = 'Biometric authentication cancelled. Please try again.';
        print('   Error: $errorMsg');
        
        if (widget.onError != null) {
          widget.onError!(errorMsg);
        } else {
          _showError(errorMsg);
        }
      }
    } catch (e) {
      if (!mounted) {
        print('⚠️ Widget disposed during error handling');
        return;
      }

      print('Step 2️⃣: Authentication error! ❌');
      print('   Exception: $e\n');

      // Stop animation
      _animationController.stop();
      setState(() => _isAuthenticating = false);

      final errorMessage = _parseErrorMessage(e.toString());
      print('   User-friendly error: $errorMessage');

      if (widget.onError != null) {
        widget.onError!(errorMessage);
      } else {
        _showError(errorMessage);
      }
    }
  }

  /// Parse error and return user-friendly message
  String _parseErrorMessage(String error) {
    print('🔍 Parsing error: $error');

    if (error.contains('NotAvailable')) {
      return 'Biometric is not available on this device';
    } else if (error.contains('NotEnrolled')) {
      return 'No biometric data found. Please enroll in device settings.';
    } else if (error.contains('LockedOut')) {
      return 'Biometric is locked. Please use your password.';
    } else if (error.contains('TemporaryLockout')) {
      return 'Too many failed attempts. Try again in a few moments.';
    } else if (error.contains('PermanentlyLockedOut')) {
      return 'Biometric is disabled. Please use your password.';
    } else if (error.contains('UserCanceled') || error.contains('goBackError')) {
      return 'Authentication cancelled. Please try again.';
    } else if (error.contains('PasscodeNotSet')) {
      return 'Device passcode not set. Please set it in device settings.';
    } else if (error.contains('NoDeviceSupport') ||
        error.contains('NotSupported')) {
      return 'This device does not support biometric authentication';
    } else if (error.contains('canceled')) {
      return 'Authentication cancelled.';
    } else {
      return 'Biometric authentication failed. Please try again or use password.';
    }
  }

  /// Show error snackbar
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLoading = _isAuthenticating || widget.isLoading;

    return Column(
      children: [
        // Animated fingerprint icon
        if (isLoading)
          ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.2).animate(
              CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
            ),
            child: Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryGreen.withOpacity(0.2),
                border: Border.all(
                  color: AppColors.primaryGreen,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.fingerprint,
                color: AppColors.primaryGreen,
                size: 28,
              ),
            ),
          )
        else
          GestureDetector(
            onTap: _handleBiometricLogin,
            child: Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryGreen.withOpacity(0.1),
                border: Border.all(
                  color: AppColors.primaryGreen,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.fingerprint,
                color: AppColors.primaryGreen,
                size: 28,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          isLoading ? 'Authenticating...' : 'Use Biometric',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Alternative: Full-width biometric button (for use in login screens)
/// Better for full-screen layouts
class BiometricLoginButtonFull extends StatefulWidget {
  final VoidCallback onSuccess;
  final Function(String)? onError;
  final bool isLoading;

  const BiometricLoginButtonFull({
    Key? key,
    required this.onSuccess,
    this.onError,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<BiometricLoginButtonFull> createState() =>
      _BiometricLoginButtonFullState();
}

class _BiometricLoginButtonFullState extends State<BiometricLoginButtonFull> {
  final BiometricService _biometricService = BiometricService();
  bool _isAuthenticating = false;

  /// Handle biometric login attempt
  Future<void> _handleBiometricLogin() async {
    if (_isAuthenticating || widget.isLoading) {
      print('⚠️ Already authenticating, ignoring tap');
      return;
    }

    print('\n╔═══════════════════════════════════════════════════╗');
    print('║   FULL BIOMETRIC LOGIN BUTTON PRESSED            ║');
    print('╚═══════════════════════════════════════════════════╝\n');

    setState(() => _isAuthenticating = true);

    try {
      print('Step 1️⃣: Requesting biometric authentication...');

      final isAuthenticated = await _biometricService.authenticate(
        reason: 'Authenticate to log in to your account',
      );

      if (!mounted) {
        print('⚠️ Widget disposed during authentication');
        return;
      }

      if (isAuthenticated) {
        print('Step 2️⃣: Authentication successful! ✅');
        print('Step 3️⃣: Calling parent onSuccess() callback...\n');

        setState(() => _isAuthenticating = false);

        // Call parent callback to trigger API login
        widget.onSuccess();

        print('✅ BiometricLoginButtonFull completed successfully\n');
      } else {
        print('Step 2️⃣: Authentication cancelled by user ❌\n');

        if (!mounted) return;

        setState(() => _isAuthenticating = false);

        const errorMsg = 'Biometric authentication cancelled. Please try again.';
        print('   Error: $errorMsg');

        if (widget.onError != null) {
          widget.onError!(errorMsg);
        } else {
          _showError(errorMsg);
        }
      }
    } catch (e) {
      if (!mounted) {
        print('⚠️ Widget disposed during error handling');
        return;
      }

      print('Step 2️⃣: Authentication error! ❌');
      print('   Exception: $e\n');

      setState(() => _isAuthenticating = false);

      final errorMessage = _parseErrorMessage(e.toString());
      print('   User-friendly error: $errorMessage');

      if (widget.onError != null) {
        widget.onError!(errorMessage);
      } else {
        _showError(errorMessage);
      }
    }
  }

  /// Parse error and return user-friendly message
  String _parseErrorMessage(String error) {
    print('🔍 Parsing error: $error');

    if (error.contains('NotAvailable')) {
      return 'Biometric is not available on this device';
    } else if (error.contains('NotEnrolled')) {
      return 'No biometric data found. Please enroll in device settings.';
    } else if (error.contains('LockedOut')) {
      return 'Biometric is locked. Please use your password.';
    } else if (error.contains('TemporaryLockout')) {
      return 'Too many failed attempts. Try again in a few moments.';
    } else if (error.contains('PermanentlyLockedOut')) {
      return 'Biometric is disabled. Please use your password.';
    } else if (error.contains('UserCanceled') || error.contains('goBackError')) {
      return 'Authentication cancelled. Please try again.';
    } else if (error.contains('PasscodeNotSet')) {
      return 'Device passcode not set. Please set it in device settings.';
    } else if (error.contains('NoDeviceSupport') ||
        error.contains('NotSupported')) {
      return 'This device does not support biometric authentication';
    } else if (error.contains('canceled')) {
      return 'Authentication cancelled.';
    } else {
      return 'Biometric authentication failed. Please try again or use password.';
    }
  }

  /// Show error snackbar
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _isAuthenticating || widget.isLoading;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : _handleBiometricLogin,
        icon: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              )
            : const Icon(Icons.fingerprint, size: 20),
        label: Text(
          isLoading ? 'Authenticating...' : 'Login with Biometric',
          style: AppTextStyles.body,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

/// Minimal biometric button - just a simple button
/// Use this for compact layouts
class BiometricLoginButtonSimple extends StatefulWidget {
  final VoidCallback onSuccess;
  final Function(String)? onError;
  final bool isLoading;
  final String buttonText;

  const BiometricLoginButtonSimple({
    Key? key,
    required this.onSuccess,
    this.onError,
    this.isLoading = false,
    this.buttonText = 'Fingerprint Login',
  }) : super(key: key);

  @override
  State<BiometricLoginButtonSimple> createState() =>
      _BiometricLoginButtonSimpleState();
}

class _BiometricLoginButtonSimpleState
    extends State<BiometricLoginButtonSimple> {
  final BiometricService _biometricService = BiometricService();
  bool _isAuthenticating = false;

  Future<void> _handleBiometricLogin() async {
    if (_isAuthenticating || widget.isLoading) return;

    setState(() => _isAuthenticating = true);

    try {
      print('🔐 Simple biometric login started...');

      final isAuthenticated = await _biometricService.authenticate(
        reason: 'Authenticate to log in to your account',
      );

      if (!mounted) return;

      if (isAuthenticated) {
        print('✅ Biometric authentication successful');
        setState(() => _isAuthenticating = false);
        widget.onSuccess();
      } else {
        print('❌ Biometric authentication cancelled');
        setState(() => _isAuthenticating = false);
        
        const errorMsg = 'Authentication cancelled';
        if (widget.onError != null) {
          widget.onError!(errorMsg);
        }
      }
    } catch (e) {
      if (!mounted) return;
      print('❌ Biometric error: $e');
      setState(() => _isAuthenticating = false);

      final errorMessage = _parseErrorMessage(e.toString());
      if (widget.onError != null) {
        widget.onError!(errorMessage);
      }
    }
  }

  String _parseErrorMessage(String error) {
    if (error.contains('NotAvailable')) {
      return 'Biometric not available';
    } else if (error.contains('NotEnrolled')) {
      return 'No biometric enrolled';
    } else if (error.contains('LockedOut')) {
      return 'Biometric locked';
    } else if (error.contains('TemporaryLockout')) {
      return 'Too many attempts';
    } else {
      return 'Authentication failed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _isAuthenticating || widget.isLoading;

    return ElevatedButton(
      onPressed: isLoading ? null : _handleBiometricLogin,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLoading ? Icons.hourglass_top : Icons.fingerprint,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              isLoading ? 'Authenticating...' : widget.buttonText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}