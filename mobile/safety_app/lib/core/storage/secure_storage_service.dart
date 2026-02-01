// lib/core/storage/secure_storage_service.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

/// Secure storage service for sensitive data
class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  // Storage keys
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userDataKey = 'user_data';

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

  /// Clear all stored data
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      print('✅ All secure storage cleared');
    } catch (e) {
      print('❌ Error clearing storage: $e');
      rethrow;
    }
  }

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

  /// Save data to secure storage (for biometric)
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

  /// Read data from secure storage (for biometric)
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
