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


  //=============================== WE DONT USE THIS FUNCTION, ONLY CREATE SOS WITH VOICE FROM VOICE MESSAGE SERVICE============================================
  // Future<int> createSosEvent({
  //   required String triggerType, // "manual" | "motion"
  //   required String eventType, // e.g. "panic_button", "possible_fall"
  //   String appState = 'foreground', // "foreground" | "background"
  //   double? latitude, // ADDED: separate lat parameter
  //   double? longitude, // ADDED: separate lng parameter
  //   Map<String, double>? location, // kept for backward compatibility
  // }) async {
  //   final data = <String, dynamic>{
  //     'trigger_type': triggerType,
  //     'event_type': eventType,
  //     'timestamp': DateTime.now().toUtc().toIso8601String(),
  //     'app_state': appState,
  //   };

    // Handle location - prioritize separate lat/lng params
    if (latitude != null && longitude != null) {
      data['location'] = {'lat': latitude, 'lng': longitude};
    } else if (location != null) {
      data['location'] = {'lat': location['lat'], 'lng': location['lng']};
    }

    final response = await _dioClient.post(ApiEndpoints.createSosEvent, data: data);

    // Expected: { status: "success", event_id: <int>, message: "..." }
    if (response.data is Map && response.data['event_id'] != null) {
      return response.data['event_id'] as int;
    }

    throw Exception('Unexpected SOS API response');
  }

  /// ✅ NEW: Get SOS event details by ID
  Future<Map<String, dynamic>> getSosEventById(int eventId) async {
    try {
      print('📡 Fetching SOS event details for ID: $eventId');
      
      final response = await _dioClient.get('/sos/events/$eventId');
      
      if (response.data != null) {
        print('✅ SOS event details fetched successfully');
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('No data received');
      }
    } catch (e) {
      print('❌ Error fetching SOS event: $e');
      rethrow;
    }
  }
}