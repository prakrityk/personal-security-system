// lib/services/sos_event_service.dart
//
// Minimal client for the backend SOS Event API.
// Used for BOTH:
// - manual SOS press
// - motion detection escalation (later)

import '../core/network/api_endpoints.dart';
import '../core/network/dio_client.dart';

class SosEventService {
  final DioClient _dioClient = DioClient();

  /// Create an SOS event for the current authenticated user.
  ///
  /// Backend derives user_id from the access token (no spoofing).
  Future<int> createSosEvent({
    required String triggerType, // "manual" | "motion"
    required String eventType, // e.g. "panic_button", "possible_fall"
    String appState = 'foreground', // "foreground" | "background"
    Map<String, double>? location, // {"lat": ..., "lng": ...} (optional)
  }) async {
    final data = <String, dynamic>{
      'trigger_type': triggerType,
      'event_type': eventType,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'app_state': appState,
    };

    if (location != null) {
      data['location'] = {'lat': location['lat'], 'lng': location['lng']};
    }

    final response = await _dioClient.post(ApiEndpoints.createSosEvent, data: data);

    // Expected: { status: "success", event_id: <int>, message: "..." }
    if (response.data is Map && response.data['event_id'] != null) {
      return response.data['event_id'] as int;
    }

    throw Exception('Unexpected SOS API response');
  }
}

