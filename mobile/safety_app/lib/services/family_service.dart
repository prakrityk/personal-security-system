// ===================================================================
// UPDATED: family_service.dart - With Profile Picture Support
// ===================================================================
// lib/services/family_service.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/user_model.dart';
import '../models/dependent_model.dart';
import '../models/guardian_model.dart';
import '../models/emergency_contact.dart';

/// Family Service - Handles all family-related operations
class FamilyService {
  final DioClient _dioClient = DioClient();

  // ================================================
  // GET FAMILY MEMBERS BASED ON ROLE
  // ================================================

  /// Get all family members for the current user (role-based)
  Future<List<Map<String, dynamic>>> getFamilyMembers() async {
    try {
      print('👨‍👩‍👧‍👦 Fetching family members...');

      // First get current user to determine role
      final userResponse = await _dioClient.get(ApiEndpoints.me);
      final currentUser = UserModel.fromJson(userResponse.data);

      if (currentUser.isGuardian) {
        // Guardian: Get their dependents
        return await _getGuardianDependents();
      } else if (currentUser.isDependent) {
        // Dependent: Get their guardians
        return await _getDependentGuardians();
      } else {
        // Personal user: No family members
        print('ℹ️ Personal user - no family members');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching family members: $e');
      rethrow;
    }
  }

  /// Get dependents for guardian (both primary and collaborator)
  Future<List<Map<String, dynamic>>> _getGuardianDependents() async {
    try {
      final response = await _dioClient.get(ApiEndpoints.getMyDependents);
      final dependents = (response.data as List)
          .map((json) => DependentModel.fromJson(json))
          .toList();

      // Transform to uniform format
      return dependents
          .map((dependent) => _dependentToFamilyMember(dependent))
          .toList();
    } catch (e) {
      print('❌ Error fetching dependents: $e');
      rethrow;
    }
  }

  /// Get guardians for dependent
  Future<List<Map<String, dynamic>>> _getDependentGuardians() async {
    try {
      final response = await _dioClient.get(ApiEndpoints.getMyGuardians);
      final guardians = (response.data as List)
          .map((json) => GuardianModel.fromJson(json))
          .toList();

      return guardians
          .map((guardian) => _guardianToFamilyMember(guardian))
          .toList();
    } catch (e) {
      print('❌ Error fetching guardians: $e');
      rethrow;
    }
  }

  // ================================================
  // GET DEPENDENT DETAILS
  // ================================================

  /// Get detailed information about a specific dependent
  /// Includes: Basic info, emergency contacts, safety settings, etc.
  Future<Map<String, dynamic>> getDependentDetails(int dependentId) async {
    try {
      print('📋 Fetching details for dependent $dependentId');

      final details = <String, dynamic>{};

      // 1. Get basic info from dependents list
      final dependentsResponse = await _dioClient.get(
        ApiEndpoints.getMyDependents,
      );
      final dependents = (dependentsResponse.data as List)
          .map((json) => DependentModel.fromJson(json))
          .toList();

      final dependent = dependents.firstWhere(
        (d) => d.dependentId == dependentId,
        orElse: () => throw Exception('Dependent not found'),
      );

      details['basic_info'] = _dependentToFamilyMember(dependent);

      // 2. Get emergency contacts for this dependent
      try {
        final contactsResponse = await _dioClient.get(
          '${ApiEndpoints.getDependentEmergencyContacts}/$dependentId/emergency-contacts',
        );
        details['emergency_contacts'] = (contactsResponse.data as List)
            .map((json) => EmergencyContact.fromJson(json))
            .toList();
      } catch (e) {
        print('⚠️ Could not fetch emergency contacts: $e');
        details['emergency_contacts'] = [];
      }

      // 3. Get safety features status (if available)
      details['safety_features'] = {
        'voice_activation': false,
        'motion_detection': false,
        'live_location': false,
        'auto_recording': false,
      };

      // 4. Get geofencing locations (if available)
      details['safe_locations'] = [];

      // 5. Get collaborators (if primary guardian)
      try {
        final collaboratorsResponse = await _dioClient.get(
          '${ApiEndpoints.getCollaborators}/$dependentId/collaborators',
        );
        details['collaborators'] = collaboratorsResponse.data as List;
      } catch (e) {
        print('⚠️ Could not fetch collaborators: $e');
        details['collaborators'] = [];
      }

      print('✅ Fetched detailed info for dependent $dependentId');
      return details;
    } catch (e) {
      print('❌ Error fetching dependent details: $e');
      rethrow;
    }
  }

  // ================================================
  // UPDATE DEPENDENT INFORMATION
  // ================================================

  /// Update dependent information (Primary guardian only)
  Future<void> updateDependentInfo({
    required int dependentId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      print('✏️ Updating dependent $dependentId info');

      // TODO: Implement when backend endpoint is available
      print('Updates: $updates');

      print('✅ Dependent info updated (simulated)');
    } catch (e) {
      print('❌ Error updating dependent info: $e');
      rethrow;
    }
  }

  // ================================================
  // ADD NEW DEPENDENT (Primary guardian only)
  // ================================================

  /// Create a new dependent (starts with pending dependent)
  Future<Map<String, dynamic>> addNewDependent({
    required String name,
    required String relation, // 'child' or 'elderly'
    required int age,
  }) async {
    try {
      print('➕ Adding new dependent: $name ($relation)');

      // Create pending dependent
      final response = await _dioClient.post(
        ApiEndpoints.createPendingDependent,
        data: {'dependent_name': name, 'relation': relation, 'Age': age},
      );

      print('✅ Pending dependent created');
      return response.data;
    } catch (e) {
      print('❌ Error adding dependent: $e');
      rethrow;
    }
  }

  // ================================================
  // REMOVE DEPENDENT (Primary guardian only)
  // ================================================

  /// Remove a dependent (break guardian-dependent relationship)
  Future<void> removeDependent(int relationshipId) async {
    try {
      print('🗑️ Removing dependent relationship $relationshipId');
      print('Simulating removal of relationship $relationshipId');
      print('✅ Dependent removed (simulated)');
    } catch (e) {
      print('❌ Error removing dependent: $e');
      rethrow;
    }
  }

  // ================================================
  // HELPER METHODS
  // ================================================

  /// Convert dependent model to family member map
  Map<String, dynamic> _dependentToFamilyMember(DependentModel dependent) {
    return {
      'id': dependent.dependentId,
      'relationship_id': dependent.id,
      'name': dependent.dependentName,
      'email': dependent.dependentEmail,
      'phone_number': dependent.phoneNumber, // ✅ Added
      'profile_picture': dependent.profilePicture, // ✅ Added
      'type': 'dependent',
      'relation': dependent.relation,
      'age': dependent.age,
      'guardian_type': dependent.guardianType,
      'is_primary_guardian': dependent.isPrimaryGuardian,
      'is_collaborator': dependent.isCollaborator,
      'linked_at': dependent.linkedAt,
      'can_edit': dependent.isPrimaryGuardian,
      'can_view_safety': true,
      'can_edit_safety': dependent.isPrimaryGuardian,
      'can_manage_contacts': dependent.isPrimaryGuardian,
    };
  }

  /// Convert guardian model to family member map
  Map<String, dynamic> _guardianToFamilyMember(GuardianModel guardian) {
    return {
      'id': guardian.guardianId,
      'relationship_id': guardian.id,
      'name': guardian.guardianName,
      'email': guardian.guardianEmail,
      'phone_number': guardian.phoneNumber, // ✅ Added
      'profile_picture': guardian.profilePicture, // ✅ Added
      'type': 'guardian',
      'relation': guardian.relation,
      'is_primary': guardian.isPrimary,
      'linked_at': guardian.linkedAt,
      'can_edit': false,
      'can_contact': true,
    };
  }

  // ================================================
  // GET FAMILY STATISTICS
  // ================================================

  /// Get family statistics for dashboard
  Future<Map<String, dynamic>> getFamilyStats() async {
    try {
      print('📊 Getting family statistics');

      final familyMembers = await getFamilyMembers();

      int dependentCount = 0;
      int primaryGuardianCount = 0;
      int collaboratorCount = 0;

      for (var member in familyMembers) {
        if (member['type'] == 'dependent') {
          dependentCount++;
          if (member['is_primary_guardian']) {
            primaryGuardianCount++;
          } else if (member['is_collaborator']) {
            collaboratorCount++;
          }
        }
      }

      return {
        'total_members': familyMembers.length,
        'dependents': dependentCount,
        'primary_guardians': primaryGuardianCount,
        'collaborator_guardians': collaboratorCount,
        'has_family': familyMembers.isNotEmpty,
      };
    } catch (e) {
      print('❌ Error getting family stats: $e');
      return {
        'total_members': 0,
        'dependents': 0,
        'primary_guardians': 0,
        'collaborator_guardians': 0,
        'has_family': false,
      };
    }
  }
}
