// lib/services/dependent_service.dart

import '../core/network/dio_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/guardian_model.dart';

/// Dependent Service - handles dependent-related API calls
class DependentService {
  final DioClient _dioClient = DioClient();

  /// Scan QR code to link with guardian
  Future<Map<String, dynamic>> scanQRCode(String qrToken) async {
    try {
      print('📱 Scanning QR code: ${qrToken.substring(0, 8)}...');

      final response = await _dioClient.post(
        ApiEndpoints.scanQR,
        data: {'qr_token': qrToken},
      );

      print('✅ QR scan successful');
      return response.data;
    } catch (e) {
      print('❌ Error scanning QR code: $e');
      rethrow;
    }
  }

  /// Get all guardians linked to current dependent
  Future<List<GuardianModel>> getMyGuardians() async {
    try {
      print('📥 Fetching my guardians...');

      final response = await _dioClient.get(ApiEndpoints.getMyGuardians);

      final List<GuardianModel> guardians = (response.data as List)
          .map((json) => GuardianModel.fromJson(json))
          .toList();

      print('✅ Fetched ${guardians.length} guardians');
      return guardians;
    } catch (e) {
      print('❌ Error fetching guardians: $e');
      rethrow;
    }
  }

  /// Remove a guardian-dependent relationship
  Future<void> removeGuardian(int relationshipId) async {
    try {
      print('🗑️ Removing guardian relationship $relationshipId');

      await _dioClient.delete('${ApiEndpoints.removeGuardian}/$relationshipId');

      print('✅ Guardian relationship removed');
    } catch (e) {
      print('❌ Error removing guardian: $e');
      rethrow;
    }
  }
}
