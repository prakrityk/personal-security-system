// lib/features/location/services/location_api_service.dart

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safety_app/core/network/api_endpoints.dart';

/// ------------------------------
/// Location API Service
/// ------------------------------
class LocationApiService {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  LocationApiService({Dio? dio, FlutterSecureStorage? storage})
      : _dio = dio ?? Dio(),
        _storage = storage ?? const FlutterSecureStorage();

  static final String _locationUrl =
      '${ApiEndpoints.baseUrl}${ApiEndpoints.liveLocation}';

  /// Send user's live location to backend
  Future<void> sendLocation(Position position, {bool isRetry = false}) async {
    try {
      String? token = await _storage.read(key: "access_token");

      if (token == null) {
        print("❌ No access token found. Cannot send location.");
        return;
      }

      final response = await _dio.post(
        _locationUrl,
        data: {
          "latitude": position.latitude,
          "longitude": position.longitude,
          "accuracy": position.accuracy,
          "altitude": position.altitude,
          "heading": position.heading,
          "speed": position.speed,
        },
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print(
            "📍 Location synced successfully: Lat=${position.latitude}, Lng=${position.longitude}");
      } else if ((response.statusCode == 401 || response.statusCode == 403) &&
          !isRetry) {
        // Only attempt refresh once — isRetry flag prevents infinite loop
        print(
            "⚠️ Token invalid/expired (status ${response.statusCode}). Attempting refresh...");

        final refreshToken = await _storage.read(key: "refresh_token");
        if (refreshToken != null) {
          final refreshed = await _refreshAccessToken(refreshToken);
          if (refreshed) {
            print("🔄 Token refreshed. Retrying location send...");
            await sendLocation(position, isRetry: true); // Retry once only
          } else {
            print("❌ Token refresh failed. User needs to log in again.");
          }
        } else {
          print("❌ No refresh token found. User needs to log in again.");
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        print("❌ Still unauthorized after token refresh. Giving up.");
      } else {
        print(
            "❌ Failed to send location. Status: ${response.statusCode}, Data: ${response.data}");
      }
    } catch (e) {
      print("❌ Exception sending location: $e");
    }
  }

  /// Refresh the access token using refresh token
  Future<bool> _refreshAccessToken(String refreshToken) async {
    try {
      final response = await _dio.post(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.refresh}',
        options: Options(
          headers: {"Content-Type": "application/json"},
        ),
        data: {"refresh_token": refreshToken},
      );

      if (response.statusCode == 200 && response.data['access_token'] != null) {
        await _storage.write(
            key: "access_token", value: response.data['access_token']);
        print("✅ Access token refreshed successfully");
        return true;
      }
    } catch (e) {
      print("❌ Error refreshing access token: $e");
    }
    return false;
  }
}

/// ------------------------------
/// Riverpod Provider
/// ------------------------------
final locationApiServiceProvider =
    Provider<LocationApiService>((ref) => LocationApiService());