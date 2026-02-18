// lib/core/utils/token_utils.dart
import 'package:safety_app/core/storage/secure_storage_service.dart';
import 'package:dio/dio.dart';
import 'package:safety_app/core/network/api_endpoints.dart';

class TokenUtils {
  static final SecureStorageService _storage = SecureStorageService();

  /// Validate and refresh token if needed
  static Future<bool> ensureValidToken() async {
    try {
      final token = await _storage.getAccessToken();
      if (token == null || token.isEmpty) {
        print('❌ TokenUtils: No access token found');
        return false;
      }

      // Check if token is expired by making a test call
      final dio = Dio();
      dio.options.headers['Authorization'] = 'Bearer $token';
      
      try {
        await dio.get('${ApiEndpoints.baseUrl}${ApiEndpoints.me}');
        print('✅ TokenUtils: Token is valid');
        return true;
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          print('⚠️ TokenUtils: Token expired, attempting refresh...');
          return await refreshToken();
        }
        throw e;
      }
    } catch (e) {
      print('❌ TokenUtils: Error validating token: $e');
      return false;
    }
  }

  /// Refresh access token
  static Future<bool> refreshToken() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        print('❌ TokenUtils: No refresh token available');
        return false;
      }

      final dio = Dio();
      final response = await dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.refresh}',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final tokenData = response.data;
        final newAccessToken = tokenData['access_token'] as String;
        final newRefreshToken = tokenData['refresh_token'] as String?;

        // Save new tokens
        await _storage.saveAccessToken(newAccessToken);
        if (newRefreshToken != null) {
          await _storage.saveRefreshToken(newRefreshToken);
        }

        print('✅ TokenUtils: Tokens refreshed successfully');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ TokenUtils: Error refreshing token: $e');
      return false;
    }
  }

  /// Get current access token
  static Future<String?> getCurrentToken() async {
    return await _storage.getAccessToken();
  }

  /// Clear all tokens
  static Future<void> clearTokens() async {
    await _storage.clearAll();
  }
}