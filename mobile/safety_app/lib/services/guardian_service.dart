// lib/services/guardian_service.dart

import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/pending_dependent_model.dart';
import '../models/dependent_model.dart'; // 🆕 NEW

/// Guardian Service - handles guardian-related API calls
class GuardianService {
  final DioClient _dioClient = DioClient();

  /// Create a pending dependent
  Future<PendingDependentResponse> createPendingDependent(
    PendingDependentCreate dependentData,
  ) async {
    try {
      print('📤 Creating pending dependent: ${dependentData.dependentName}');

      final response = await _dioClient.post(
        ApiEndpoints.createPendingDependent,
        data: dependentData.toJson(),
      );

      print('✅ Pending dependent created successfully');
      return PendingDependentResponse.fromJson(response.data);
    } catch (e) {
      print('❌ Error creating pending dependent: $e');
      rethrow;
    }
  }

  /// Get all pending dependents for current guardian
  Future<List<PendingDependentWithQR>> getPendingDependents() async {
    try {
      print('📥 Fetching pending dependents...');

      final response = await _dioClient.get(ApiEndpoints.getPendingDependents);

      final List<PendingDependentWithQR> dependents = (response.data as List)
          .map((json) => PendingDependentWithQR.fromJson(json))
          .toList();

      print('✅ Fetched ${dependents.length} pending dependents');
      return dependents;
    } catch (e) {
      print('❌ Error fetching pending dependents: $e');
      rethrow;
    }
  }

  /// 🆕 Get all approved dependents (works for both primary and collaborator guardians)
  Future<List<DependentModel>> getMyDependents() async {
    try {
      print('📥 Fetching my dependents...');

      final response = await _dioClient.get(ApiEndpoints.getMyDependents);

      final List<DependentModel> dependents = (response.data as List)
          .map((json) => DependentModel.fromJson(json))
          .toList();

      print('✅ Fetched ${dependents.length} dependents');

      // Log guardian types for debugging
      for (var dep in dependents) {
        print(
          '  - ${dep.dependentName}: ${dep.guardianType} (primary: ${dep.isPrimary})',
        );
      }

      return dependents;
    } catch (e) {
      print('❌ Error fetching dependents: $e');
      rethrow;
    }
  }

  /// Generate QR code for a pending dependent
  Future<GenerateQRResponse> generateQR(int pendingDependentId) async {
    try {
      print('🔄 Generating QR for pending dependent $pendingDependentId');

      final response = await _dioClient.post(
        ApiEndpoints.generateQR,
        data: {'pending_dependent_id': pendingDependentId},
      );

      print('✅ QR generated successfully');
      return GenerateQRResponse.fromJson(response.data);
    } catch (e) {
      print('❌ Error generating QR: $e');
      rethrow;
    }
  }

  /// Delete a pending dependent
  Future<void> deletePendingDependent(int pendingDependentId) async {
    try {
      print('🗑️ Deleting pending dependent $pendingDependentId');

      await _dioClient.delete(
        '${ApiEndpoints.deletePendingDependent}/$pendingDependentId',
      );

      print('✅ Pending dependent deleted successfully');
    } catch (e) {
      print('❌ Error deleting pending dependent: $e');
      rethrow;
    }
  }

  /// Get QR invitation details
  Future<Map<String, dynamic>> getQRInvitation(int pendingDependentId) async {
    try {
      print('📥 Fetching QR invitation for dependent $pendingDependentId');

      final response = await _dioClient.get(
        '${ApiEndpoints.getQRInvitation}/$pendingDependentId',
      );

      return response.data;
    } catch (e) {
      print('❌ Error fetching QR invitation: $e');
      rethrow;
    }
  }

  /// Get pending QR invitations (scanned but not approved)
  Future<List<Map<String, dynamic>>> getPendingQRInvitations() async {
    try {
      print('📥 Fetching pending QR invitations...');

      final response = await _dioClient.get(
        ApiEndpoints.getPendingQRInvitations,
      );

      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      print('❌ Error fetching pending QR invitations: $e');
      rethrow;
    }
  }

  /// Approve a QR invitation
  Future<Map<String, dynamic>> approveQRInvitation(int qrInvitationId) async {
    try {
      print('✅ Approving QR invitation $qrInvitationId');

      final response = await _dioClient.post(
        ApiEndpoints.approveQR,
        data: {'qr_invitation_id': qrInvitationId},
      );

      print('✅ QR invitation approved successfully');
      return response.data;
    } catch (e) {
      print('❌ Error approving QR invitation: $e');
      rethrow;
    }
  }

  /// Reject a QR invitation
  Future<void> rejectQRInvitation(int qrInvitationId) async {
    try {
      print('❌ Rejecting QR invitation $qrInvitationId');

      await _dioClient.post(
        ApiEndpoints.rejectQR,
        data: {'qr_invitation_id': qrInvitationId},
      );

      print('✅ QR invitation rejected successfully');
    } catch (e) {
      print('❌ Error rejecting QR invitation: $e');
      rethrow;
    }
  }
  // Add to guardian_service.dart
Future<List<Map<String, dynamic>>> getDependentCollaborators(int dependentId) async {
  try {
    final response = await _dioClient.get(
      '${ApiEndpoints.getCollaborators}/$dependentId/collaborators',
    );
    return List<Map<String, dynamic>>.from(response.data);
  } catch (e) {
    print('❌ Error fetching collaborators: $e');
    rethrow;
  }
}
}
