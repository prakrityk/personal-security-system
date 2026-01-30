import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firebase Authentication Service
/// Handles phone OTP verification, email linking & verification, and token generation
class FirebaseAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // ============================================================================
  // PHONE AUTHENTICATION
  // ============================================================================

  /// Send OTP to phone number
  /// Returns verification ID that will be used in verifyPhoneOTP
  Future<String> sendPhoneOTP({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String error) onVerificationFailed,
    Function(PhoneAuthCredential)? onVerificationCompleted,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    String? verificationIdResult;

    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: timeout,
        
        // Auto-verification completed (Android only, when OTP is auto-detected)
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (onVerificationCompleted != null) {
            onVerificationCompleted(credential);
          }
          // Optionally auto-sign in
          await _firebaseAuth.signInWithCredential(credential);
        },

        // Verification failed
        verificationFailed: (FirebaseAuthException e) {
          String errorMessage = _getFirebaseErrorMessage(e);
          onVerificationFailed(errorMessage);
        },

        // OTP sent successfully
        codeSent: (String verificationId, int? resendToken) {
          verificationIdResult = verificationId;
          onCodeSent(verificationId, resendToken);
        },

        // Auto-retrieval timeout
        codeAutoRetrievalTimeout: (String verificationId) {
          verificationIdResult = verificationId;
        },
      );

      return verificationIdResult ?? '';
    } catch (e) {
      throw Exception('Failed to send OTP: ${e.toString()}');
    }
  }

  /// Verify OTP code and sign in with phone credential
  Future<UserCredential> verifyPhoneOTP({
    required String verificationId,
    required String otpCode,
  }) async {
    try {
      // Create phone auth credential
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otpCode,
      );

      // Sign in with credential
      UserCredential userCredential = 
          await _firebaseAuth.signInWithCredential(credential);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getFirebaseErrorMessage(e));
    } catch (e) {
      throw Exception('Failed to verify OTP: ${e.toString()}');
    }
  }

  // ============================================================================
  // EMAIL AUTHENTICATION
  // ============================================================================

  /// Link email to existing phone-authenticated account
  /// ✅ FIXED: Removed updateEmail() call - not needed after linkWithCredential
  Future<void> linkEmailToAccount({
    required String email,
    required String password,
  }) async {
    try {
      User? user = currentUser;
      if (user == null) {
        throw Exception('No authenticated user found. Please verify phone first.');
      }

      // Create email credential
      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      // Link credential to existing user
      // This automatically sets the email on the user account
      await user.linkWithCredential(credential);

      // ✅ IMPORTANT: Reload user to get updated email
      await user.reload();
      
      // ✅ WAIT a moment for Firebase to sync
      await Future.delayed(const Duration(milliseconds: 500));
      
      debugPrint('✅ Email linked successfully to Firebase user');
    } on FirebaseAuthException catch (e) {
      throw Exception(_getFirebaseErrorMessage(e));
    } catch (e) {
      throw Exception('Failed to link email: ${e.toString()}');
    }
  }

  /// Send email verification link
  Future<void> sendEmailVerification() async {
    try {
      User? user = currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      if (user.emailVerified) {
        throw Exception('Email is already verified');
      }

      await user.sendEmailVerification();
      debugPrint('✅ Verification email sent to ${user.email}');
    } on FirebaseAuthException catch (e) {
      throw Exception(_getFirebaseErrorMessage(e));
    } catch (e) {
      throw Exception('Failed to send verification email: ${e.toString()}');
    }
  }

  /// Check if current user's email is verified
  /// Returns true if verified, false otherwise
  Future<bool> checkEmailVerified() async {
    try {
      User? user = currentUser;
      if (user == null) {
        return false;
      }

      // Reload user to get latest email verification status
      await user.reload();
      user = _firebaseAuth.currentUser; // Get fresh user instance

      return user?.emailVerified ?? false;
    } catch (e) {
      debugPrint('Error checking email verification: ${e.toString()}');
      return false;
    }
  }

  /// Poll email verification status until verified or timeout
  /// Useful for auto-navigation after email verification
  Future<bool> waitForEmailVerification({
    Duration timeout = const Duration(minutes: 5),
    Duration checkInterval = const Duration(seconds: 3),
  }) async {
    final endTime = DateTime.now().add(timeout);
    
    while (DateTime.now().isBefore(endTime)) {
      final isVerified = await checkEmailVerified();
      if (isVerified) {
        return true;
      }
      await Future.delayed(checkInterval);
    }
    
    return false;
  }

  // ============================================================================
  // FIREBASE TOKEN MANAGEMENT
  // ============================================================================

  /// Get Firebase ID Token for backend authentication
  /// This token is sent to your FastAPI backend for user creation
  /// ✅ FIXED: Added user reload and better error handling
  Future<String?> getFirebaseIdToken({bool forceRefresh = true}) async {
    try {
      User? user = currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      // ✅ IMPORTANT: Reload user first to ensure we have latest state
      await user.reload();
      user = _firebaseAuth.currentUser; // Get fresh instance
      
      if (user == null) {
        throw Exception('User session expired');
      }

      // ✅ Get token with force refresh
      String? idToken = await user.getIdToken(forceRefresh);
      
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Failed to generate Firebase ID token');
      }
      
      debugPrint('✅ Firebase ID token retrieved (length: ${idToken.length})');
      return idToken;
    } catch (e) {
      debugPrint('❌ Error getting Firebase ID token: ${e.toString()}');
      return null;
    }
  }

  /// Get current user's email
  String? getUserEmail() {
    return currentUser?.email;
  }

  /// Get current user's phone number
  String? getUserPhoneNumber() {
    return currentUser?.phoneNumber;
  }

  /// Get current user's UID (Firebase UID)
  String? getUserUid() {
    return currentUser?.uid;
  }

  // ============================================================================
  // SIGN OUT
  // ============================================================================

  /// Sign out from Firebase
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      debugPrint('✅ Signed out from Firebase');
    } catch (e) {
      throw Exception('Failed to sign out: ${e.toString()}');
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Convert Firebase error codes to user-friendly messages
  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      // Phone Auth Errors
      case 'invalid-phone-number':
        return 'The phone number format is invalid. Please check and try again.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-verification-code':
        return 'Invalid OTP code. Please check and try again.';
      case 'session-expired':
        return 'OTP expired. Please request a new code.';
      
      // Email Auth Errors
      case 'email-already-in-use':
        return 'This email is already registered. Please use a different email.';
      case 'invalid-email':
        return 'Invalid email format. Please check and try again.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'provider-already-linked':
        return 'This email is already linked to your account.';
      case 'credential-already-in-use':
        return 'This credential is already associated with another account.';
      
      // General Errors
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'operation-not-allowed':
        return 'This operation is not allowed. Contact support.';
      
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }

  /// Check if phone number is verified
  bool isPhoneVerified() {
    return currentUser?.phoneNumber != null;
  }

  /// Check if email is verified
  bool isEmailVerified() {
    return currentUser?.emailVerified ?? false;
  }

  /// Check if both phone and email are verified
  bool isFullyVerified() {
    return isPhoneVerified() && isEmailVerified();
  }
}