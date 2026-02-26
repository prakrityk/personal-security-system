// lib/features/location/services/dependent_location_service.dart

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/network/api_endpoints.dart';

/// ------------------------------
/// Dependent + Guardian Location Service
/// ------------------------------
class DependentLocationService {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  DependentLocationService({Dio? dio, FlutterSecureStorage? storage})
      : _dio = dio ?? Dio(),
        _storage = storage ?? const FlutterSecureStorage();

  /// Fetch all linked dependents' latest locations + guardian location
  Future<List<Map<String, dynamic>>> fetchDependentsLocations() async {
    try {
      String? token = await _storage.read(key: "access_token");

      if (token == null) {
        print("❌ No access token found. Cannot fetch locations.");
        return [];
      }

      // ✅ Updated endpoint to fetch both guardian + dependents
      final response = await _dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.guardianLiveLocations}',
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 && response.data is List) {
        // Return list of guardian + dependents locations
        return (response.data as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        print(
            "⚠️ Token invalid/expired (status ${response.statusCode}). User needs to log in again.");
      } else {
        print(
            "❌ Failed to fetch locations. Status: ${response.statusCode}, Data: ${response.data}");
      }
    } catch (e) {
      print("❌ Exception fetching locations: $e");
    }
    return [];
  }
}

/// ------------------------------
/// Riverpod Provider
/// ------------------------------
final dependentLocationServiceProvider =
    Provider<DependentLocationService>(
        (ref) => DependentLocationService());