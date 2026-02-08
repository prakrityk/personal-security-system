import 'package:dio/dio.dart';

import '../core/network/api_endpoints.dart';
import '../core/network/dio_client.dart';

/// Per-dependent safety settings (as configured by guardians).
class DependentSafetySettings {
  final bool liveLocation;
  final bool audioRecording;
  final bool motionDetection;
  final bool autoRecording;

  const DependentSafetySettings({
    required this.liveLocation,
    required this.audioRecording,
    required this.motionDetection,
    required this.autoRecording,
  });

  factory DependentSafetySettings.fromJson(Map<String, dynamic> json) {
    return DependentSafetySettings(
      liveLocation: json['live_location'] as bool? ?? false,
      audioRecording: json['audio_recording'] as bool? ?? false,
      motionDetection: json['motion_detection'] as bool? ?? false,
      autoRecording: json['auto_recording'] as bool? ?? false,
    );
  }
}

/// Service responsible for reading/updating per-dependent safety settings.
///
/// - Primary guardians can update settings for a specific dependent
/// - Collaborator guardians can read but not modify
/// - Dependents read their own resolved settings (what guardians configured)
class DependentSafetyService {
  final DioClient _dioClient = DioClient();

  /// Get safety settings for a specific dependent (guardian view).
  Future<DependentSafetySettings> getDependentSafetySettings(
    int dependentId,
  ) async {
    try {
      final endpoint =
          '${ApiEndpoints.dependentSafetySettings}/$dependentId/safety-settings';
      final response = await _dioClient.get(endpoint);
      if (response.data is Map<String, dynamic>) {
        return DependentSafetySettings.fromJson(
          response.data as Map<String, dynamic>,
        );
      }
      if (response.data is Map) {
        return DependentSafetySettings.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      throw Exception('Unexpected safety settings response');
    } on DioException catch (e) {
      // Surface a clean error message to the UI layer.
      final message =
          e.response?.data is Map && e.response?.data['detail'] is String
              ? e.response?.data['detail'] as String
              : 'Failed to load safety settings';
      throw Exception(message);
    }
  }

  /// Update one or more safety settings for a dependent (primary guardian only).
  ///
  /// Pass a partial [updates] map, e.g. `{ 'motion_detection': true }`.
  Future<void> updateDependentSafetySettings({
    required int dependentId,
    required Map<String, dynamic> updates,
  }) async {
    if (updates.isEmpty) return;

    try {
      final endpoint =
          '${ApiEndpoints.dependentSafetySettings}/$dependentId/safety-settings';
      await _dioClient.patch(endpoint, data: updates);
    } on DioException catch (e) {
      final message =
          e.response?.data is Map && e.response?.data['detail'] is String
              ? e.response?.data['detail'] as String
              : 'Failed to update safety settings';
      throw Exception(message);
    }
  }

  /// Get the current user's resolved safety settings (dependent device).
  ///
  /// This is what a dependent phone should respect for background motion
  /// detection etc. as configured by their guardians.
  Future<DependentSafetySettings> getMySafetySettings() async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.mySafetySettings,
      );
      if (response.data is Map<String, dynamic>) {
        return DependentSafetySettings.fromJson(
          response.data as Map<String, dynamic>,
        );
      }
      if (response.data is Map) {
        return DependentSafetySettings.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      throw Exception('Unexpected safety settings response');
    } on DioException catch (e) {
      final message =
          e.response?.data is Map && e.response?.data['detail'] is String
              ? e.response?.data['detail'] as String
              : 'Failed to load safety settings';
      throw Exception(message);
    }
  }
}

