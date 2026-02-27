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

  //  

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

  /// ✅ NEW: Get live location of a dependent by their user ID
  /// Queries live_locations table via GET /live-locations/:userId
  /// Called by SosAlertDetailScreen every 5 seconds to update the blue marker
  Future<Map<String, dynamic>> getLiveLocation(int userId) async {
    try {
      print('📍 Fetching live location for user ID: $userId');

      final response = await _dioClient.get('/live-locations/$userId');

      if (response.data != null) {
        print('✅ Live location fetched: ${response.data}');
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('No live location data received');
      }
    } catch (e) {
      print('❌ Error fetching live location: $e');
      rethrow;
    }
  }
}