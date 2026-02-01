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
      print('🔍 Validating invitation code: ${invitationCode.substring(0, 8)}...');

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

  /// Get all collaborators for a dependent (Primary guardian only)
  Future<List<Map<String, dynamic>>> getCollaborators(int dependentId) async {
    try {
      print('📥 Fetching collaborators for dependent $dependentId');

      final response = await _dioClient.get(
        '${ApiEndpoints.getCollaborators}/$dependentId/collaborators',
      );

      final List<Map<String, dynamic>> collaborators =
          List<Map<String, dynamic>>.from(response.data);

      print('✅ Fetched ${collaborators.length} collaborators');
      return collaborators;
    } catch (e) {
      print('❌ Error fetching collaborators: $e');
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
  Future<void> revokeCollaborator(int relationshipId) async {
    try {
      print('🗑️ Revoking collaborator relationship $relationshipId');

      await _dioClient.delete(
        '${ApiEndpoints.revokeCollaborator}/$relationshipId',
      );

      print('✅ Collaborator access revoked');
    } catch (e) {
      print('❌ Error revoking collaborator: $e');
      rethrow;
    }
  }
}