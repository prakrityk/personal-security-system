// lib/services/biometric_service.dart
// Compatible with local_auth ^3.0.0

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Service to handle biometric authentication (fingerprint, face recognition)
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if device supports biometrics
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } on PlatformException catch (e) {
      print('❌ Error checking biometric support: ${e.code} - ${e.message}');
      return false;
    }
  }

  /// Check if device has biometric hardware
  Future<bool> deviceSupportsBiometric() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException catch (e) {
      print('❌ Error: ${e.code} - ${e.message}');
      return false;
    }
  }

  /// Get available biometric types (fingerprint, face, iris)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      print('✅ Available biometrics: $availableBiometrics');
      return availableBiometrics;
    } on PlatformException catch (e) {
      print('❌ Error getting biometric types: ${e.code} - ${e.message}');
      return [];
    }
  }

  /// Authenticate user with biometrics
  /// Returns true if authentication successful, false otherwise
  Future<bool> authenticate({
    required String reason,
  }) async {
    try {
      print('🔐 Starting biometric authentication...');
      
      final canCheck = await canCheckBiometrics();
      
      if (!canCheck) {
        print('❌ Device does not support biometrics');
        return false;
      }

      // Get available biometrics to show better UI
      final availableBiometrics = await getAvailableBiometrics();
      print('📱 Available biometrics: $availableBiometrics');

      // ✅ For local_auth 3.0.0+
     final isAuthenticated = await _localAuth.authenticate(
  localizedReason: reason,
);

      if (isAuthenticated) {
        print('✅ Biometric authentication successful');
        return true;
      } else {
        print('❌ Biometric authentication cancelled by user or failed');
        return false;
      }
    } on PlatformException catch (e) {
      print('❌ Biometric authentication error: ${e.code}');
      print('   Message: ${e.message}');
      return false;
    } catch (e) {
      print('❌ Unexpected error during authentication: $e');
      return false;
    }
  }

  /// Handle specific biometric errors with user-friendly messages
  String getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'NotAvailable':
        return 'Biometric authentication is not available on this device';
      case 'NotEnrolled':
        return 'No biometric data enrolled. Please enroll in device settings.';
      case 'LockedOut':
        return 'Too many failed attempts. Please use your password.';
      case 'PermanentlyLockedOut':
        return 'Biometric authentication is disabled. Use password to login.';
      case 'PasscodeNotSet':
        return 'Device passcode not set. Set it in device settings.';
      default:
        return 'Biometric authentication failed. Please try again.';
    }
  }

  /// Check if biometrics is available (device capability + enrollment)
  Future<bool> isBiometricAvailable() async {
    try {
      // Check if device supports biometrics
      final canCheck = await canCheckBiometrics();
      final isSupported = await deviceSupportsBiometric();
      
      if (!canCheck || !isSupported) {
        print('⚠️  Biometric not available - canCheck: $canCheck, isSupported: $isSupported');
        return false;
      }
      
      // Check if biometrics are enrolled
      final availableBiometrics = await getAvailableBiometrics();
      final hasEnrolledBiometrics = availableBiometrics.isNotEmpty;
      
      if (hasEnrolledBiometrics) {
        print('✅ Biometric available - Types: $availableBiometrics');
      } else {
        print('⚠️  No biometrics enrolled');
      }
      
      return hasEnrolledBiometrics;
    } catch (e) {
      print('❌ Error checking biometric availability: $e');
      return false;
    }
  }
}