// lib/core/storage/secure_storage_service.dart
// UPDATED VERSION - Preserves biometric after logout

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

/// Secure storage service for sensitive data
class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  // Storage keys
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userDataKey = 'user_data';
  static const String _lastLoginPhoneKey = 'last_login_phone';
  static const String _biometricEnabledKey = 'biometric_enabled';

  /// Save access token
  Future<void> saveAccessToken(String token) async {
    try {
      await _storage.write(key: _accessTokenKey, value: token);
      print('✅ Access token saved');
    } catch (e) {
      print('❌ Error saving access token: $e');
      rethrow;
    }
  }

  /// Get access token
  Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _accessTokenKey);
    } catch (e) {
      print('❌ Error reading access token: $e');
      return null;
    }
  }

  /// Save refresh token
  Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: _refreshTokenKey, value: token);
      print('✅ Refresh token saved');
    } catch (e) {
      print('❌ Error saving refresh token: $e');
      rethrow;
    }
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } catch (e) {
      print('❌ Error reading refresh token: $e');
      return null;
    }
  }

  /// Save user data as JSON
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    try {
      final jsonString = jsonEncode(userData);
      await _storage.write(key: _userDataKey, value: jsonString);
      print('✅ User data saved');
    } catch (e) {
      print('❌ Error saving user data: $e');
      rethrow;
    }
  }

  /// Get user data as Map
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final jsonString = await _storage.read(key: _userDataKey);
      if (jsonString == null) return null;
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('❌ Error reading user data: $e');
      return null;
    }
  }

  /// Check if user is logged in (has access token)
  Future<bool> isLoggedIn() async {
    try {
      final token = await getAccessToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      print('❌ Error checking login status: $e');
      return false;
    }
  }

  // ============================================================================
  // BIOMETRIC PREFERENCE METHODS
  // ============================================================================

  /// Save phone number of last logged in user
  Future<void> saveLastLoginPhone(String phoneNumber) async {
    try {
      await _storage.write(key: _lastLoginPhoneKey, value: phoneNumber);
      print('✅ Last login phone saved: $phoneNumber');
    } catch (e) {
      print('❌ Error saving last login phone: $e');
      rethrow;
    }
  }

  /// Get phone number of last logged in user
  Future<String?> getLastLoginPhone() async {
    try {
      return await _storage.read(key: _lastLoginPhoneKey);
    } catch (e) {
      print('❌ Error reading last login phone: $e');
      return null;
    }
  }

  /// Mark that user has biometric enabled
  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
      print('✅ Biometric enabled status saved: $enabled');
    } catch (e) {
      print('❌ Error saving biometric enabled status: $e');
      rethrow;
    }
  }

  /// Check if user has biometric enabled
  Future<bool> isBiometricEnabled() async {
    try {
      final value = await _storage.read(key: _biometricEnabledKey);
      return value == 'true';
    } catch (e) {
      print('❌ Error checking biometric enabled: $e');
      return false;
    }
  }

  // ============================================================================
  // LOGOUT METHODS
  // ============================================================================

  /// ✅ RECOMMENDED: Logout but preserve biometric
  /// This allows biometric login after logout
  /// Clears: access_token, user_data
  /// Keeps: refresh_token, last_login_phone, biometric_enabled
  Future<void> logout() async {
    try {
      // Clear session data
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _userDataKey);
      
      // Keep these for biometric:
      // - refresh_token (for biometric login)
      // - last_login_phone (to show which account)
      // - biometric_enabled (user preference)
      
      print('✅ Logged out (biometric preserved)');
    } catch (e) {
      print('❌ Error during logout: $e');
      rethrow;
    }
  }

  /// Complete logout - Clear everything including biometric
  /// Use this for "Forget this device" or "Switch account"
  Future<void> completeLogout() async {
    try {
      await _storage.deleteAll();
      print('✅ Complete logout (everything cleared)');
    } catch (e) {
      print('❌ Error during complete logout: $e');
      rethrow;
    }
  }

  /// Disable biometric and clear refresh token
  /// Use this when user explicitly disables biometric in settings
  Future<void> disableBiometric() async {
    try {
      await _storage.delete(key: _refreshTokenKey);
      await _storage.delete(key: _biometricEnabledKey);
      print('✅ Biometric disabled');
    } catch (e) {
      print('❌ Error disabling biometric: $e');
      rethrow;
    }
  }

  // ============================================================================
  // LEGACY METHOD - UPDATED
  // ============================================================================

  /// Clear all stored data (called on logout)
  /// ⚠️ UPDATED: Now just calls logout() to preserve biometric
  @Deprecated('Use logout() instead for clarity')
  Future<void> clearAll() async {
    await logout();
  }

  /// Clear everything including biometric preferences
  @Deprecated('Use completeLogout() instead for clarity')
  Future<void> clearAllIncludingBiometric() async {
    await completeLogout();
  }

  // ============================================================================
  // GENERIC METHODS
  // ============================================================================

  /// Clear specific key
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
      print('✅ Deleted key: $key');
    } catch (e) {
      print('❌ Error deleting key $key: $e');
      rethrow;
    }
  }

  /// Check if a specific key exists
  Future<bool> containsKey(String key) async {
    try {
      final value = await _storage.read(key: key);
      return value != null;
    } catch (e) {
      print('❌ Error checking key $key: $e');
      return false;
    }
  }

  /// Save data to secure storage (generic method)
  Future<void> write({
    required String key,
    required String value,
  }) async {
    try {
      await _storage.write(key: key, value: value);
      print('✅ Saved to secure storage: $key');
    } catch (e) {
      print('❌ Error saving to secure storage: $e');
      rethrow;
    }
  }

  /// Read data from secure storage (generic method)
  Future<String?> read({
    required String key,
  }) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      print('❌ Error reading from secure storage: $e');
      return null;
    }
  }
}