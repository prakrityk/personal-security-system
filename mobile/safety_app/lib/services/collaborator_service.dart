// lib/services/collaborator_service.dart

import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_endpoints.dart';

/// Collaborator Service - handles collaborator-related API calls
class CollaboratorService {
  final DioClient _dioClient = DioClient();

  /// Create invitation for collaborator (Primary guardian only)
  Future<Map<String, dynamic>> createInvitation(int dependentId) async {
    try {
      print('📤 Creating collaborator invitation for dependent $dependentId');

      final response = await _dioClient.post(
        ApiEndpoints.inviteCollaborator,
        data: {'dependent_id': dependentId},
      );

      print('✅ Invitation created successfully');
      return response.data;
    } catch (e) {
      print('❌ Error creating invitation: $e');
      rethrow;
    }
  }

  /// Validate invitation code before accepting
  Future<Map<String, dynamic>> validateInvitation(String invitationCode) async {
    try {
      print(
        '🔍 Validating invitation code: ${invitationCode.substring(0, 8)}...',
      );

      final response = await _dioClient.post(
        ApiEndpoints.validateInvitation,
        data: {'invitation_code': invitationCode},
      );

      print('✅ Invitation validated');
      return response.data;
    } catch (e) {
      print('❌ Error validating invitation: $e');
      rethrow;
    }
  }

  /// Accept invitation and create collaborator relationship
  Future<Map<String, dynamic>> acceptInvitation(String invitationCode) async {
    try {
      print('✅ Accepting invitation: ${invitationCode.substring(0, 8)}...');

      final response = await _dioClient.post(
        ApiEndpoints.acceptInvitation,
        data: {'invitation_code': invitationCode},
      );

      print('✅ Invitation accepted successfully');
      return response.data;
    } catch (e) {
      print('❌ Error accepting invitation: $e');
      rethrow;
    }
  }

  /// ✅ Get all collaborators (non-primary guardians only)
  /// This stays unchanged for backward compatibility with other parts of your code
  Future<List<Map<String, dynamic>>> getCollaborators(int dependentId) async {
    try {
      print('📥 Fetching collaborators for dependent $dependentId');

      // ✅ Use the NEW all-guardians endpoint and filter out primary
      final allGuardians = await getAllGuardians(dependentId);

      // Filter to get only collaborators (non-primary)
      final collaborators = allGuardians
          .where((guardian) => guardian['is_primary'] != true)
          .toList();

      print(
        '✅ Fetched ${collaborators.length} collaborators (filtered from all guardians)',
      );
      return collaborators;
    } catch (e) {
      print('❌ Error fetching collaborators: $e');
      rethrow;
    }
  }

  /// ✅ Get primary guardian for a dependent
  /// This stays unchanged for backward compatibility
  Future<Map<String, dynamic>?> getPrimaryGuardian(int dependentId) async {
    try {
      print('📥 Fetching primary guardian for dependent $dependentId');

      // ✅ Use the NEW all-guardians endpoint and filter for primary
      final allGuardians = await getAllGuardians(dependentId);

      // Find the primary guardian
      final primaryGuardian = allGuardians.firstWhere(
        (guardian) => guardian['is_primary'] == true,
        orElse: () => <String, dynamic>{},
      );

      if (primaryGuardian.isEmpty) {
        print('⚠️ No primary guardian found');
        return null;
      }

      print('✅ Found primary guardian: ${primaryGuardian['guardian_name']}');
      return primaryGuardian;
    } catch (e) {
      print('❌ Error fetching primary guardian: $e');
      return null;
    }
  }

  /// ✅ NEW: Get ALL guardians for a dependent (primary + collaborators)
  /// This is the CORE method that actually calls the backend
  Future<List<Map<String, dynamic>>> getAllGuardians(int dependentId) async {
    try {
      print('📥 Fetching ALL guardians for dependent $dependentId');

      final response = await _dioClient.get(
        '${ApiEndpoints.getCollaborators}/$dependentId/all-guardians',
      );

      final List<Map<String, dynamic>> allGuardians =
          List<Map<String, dynamic>>.from(response.data);

      print('✅ Fetched ${allGuardians.length} total guardians');

      // Debug logging
      final primary = allGuardians.where((g) => g['is_primary'] == true).length;
      final collabs = allGuardians.where((g) => g['is_primary'] != true).length;
      print('   └─ Primary: $primary, Collaborators: $collabs');

      return allGuardians;
    } catch (e) {
      print('❌ Error fetching all guardians: $e');
      rethrow;
    }
  }

  /// Get pending invitations for a dependent (Primary guardian only)
  Future<List<Map<String, dynamic>>> getPendingInvitations(
    int dependentId,
  ) async {
    try {
      print('📥 Fetching pending invitations for dependent $dependentId');

      final response = await _dioClient.get(
        '${ApiEndpoints.getPendingInvitations}/$dependentId/pending-invitations',
      );

      final List<Map<String, dynamic>> invitations =
          List<Map<String, dynamic>>.from(response.data);

      print('✅ Fetched ${invitations.length} pending invitations');
      return invitations;
    } catch (e) {
      print('❌ Error fetching pending invitations: $e');
      rethrow;
    }
  }

  /// Revoke collaborator access (Primary guardian only)
  Future<bool> revokeCollaborator(int relationshipId) async {
    try {
      print('🗑️ Revoking collaborator relationship $relationshipId');

      final response = await _dioClient.delete(
        '${ApiEndpoints.revokeCollaborator}/$relationshipId',
      );

      final success = response.statusCode == 200 || response.statusCode == 204;

      if (success) {
        print('✅ Collaborator access revoked');
      } else {
        print('⚠️ Revoke failed with status ${response.statusCode}');
      }

      return success;
    } catch (e) {
      print('❌ Error revoking collaborator: $e');
      rethrow;
    }
  }
}
