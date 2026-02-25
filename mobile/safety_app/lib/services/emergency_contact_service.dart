// lib/services/emergency_contact_service.dart - FIXED FOR COLLABORATORS
import 'package:safety_app/core/network/dio_client.dart';
import 'package:safety_app/models/emergency_contact.dart';

class EmergencyContactService {
  final DioClient _dioClient = DioClient();

  // ================================================
  // PERSONAL EMERGENCY CONTACTS (For all users)
  // ================================================

  Future<List<EmergencyContact>> getMyEmergencyContacts() async {
    final response = await _dioClient.get('/my-emergency-contacts');
    return (response.data as List)
        .map((json) => EmergencyContact.fromJson(json))
        .toList();
  }

  Future<EmergencyContact> createMyEmergencyContact(
    Map<String, dynamic> data,
  ) async {
    final response = await _dioClient.post(
      '/my-emergency-contacts',
      data: data,
    );
    return EmergencyContact.fromJson(response.data);
  }

  Future<EmergencyContact> updateMyEmergencyContact(
    int contactId,
    Map<String, dynamic> data,
  ) async {
    final response = await _dioClient.put(
      '/my-emergency-contacts/$contactId',
      data: data,
    );
    return EmergencyContact.fromJson(response.data);
  }

  Future<void> deleteMyEmergencyContact(int contactId) async {
    await _dioClient.delete('/my-emergency-contacts/$contactId');
  }

  // ================================================
  // DEPENDENT EMERGENCY CONTACTS
  // ================================================

  /// Get dependent's emergency contacts
  /// ✅ WORKS FOR BOTH: Primary Guardian AND Collaborator Guardian
  /// This is a READ-ONLY endpoint that both can access
  Future<List<EmergencyContact>> getDependentEmergencyContacts(
    int dependentId,
  ) async {
    try {
      // Use the guardian endpoint which allows READ access for both primary and collaborator
      final response = await _dioClient.get(
        '/guardian/dependent/$dependentId/emergency-contacts',
      );
      
      return (response.data as List)
          .map((json) => EmergencyContact.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error fetching dependent contacts: $e');
      
      // If 403, it means we don't have access at all (not even view access)
      // This should only happen if we're not a guardian for this dependent
      rethrow;
    }
  }

  // ================================================
  // DEPENDENT EMERGENCY CONTACTS - EDIT OPERATIONS
  // (Primary Guardian ONLY)
  // ================================================

  /// Create new emergency contact for dependent
  /// ⚠️ PRIMARY GUARDIAN ONLY - Collaborators will get 403
  Future<EmergencyContact> createDependentEmergencyContact(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dioClient.post(
        '/dependent/emergency-contacts',
        data: data,
      );
      return EmergencyContact.fromJson(response.data);
    } catch (e) {
      print('❌ Error creating dependent contact: $e');
      
      // Provide better error message for collaborators
      if (e.toString().contains('403') || 
          e.toString().contains('Only primary guardian')) {
        throw Exception(
          'Only primary guardian can add emergency contacts for dependents'
        );
      }
      rethrow;
    }
  }

  /// Update existing emergency contact for dependent
  /// ⚠️ PRIMARY GUARDIAN ONLY - Collaborators will get 403
  Future<EmergencyContact> updateDependentEmergencyContact(
    int contactId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dioClient.put(
        '/dependent/emergency-contacts/$contactId',
        data: data,
      );
      return EmergencyContact.fromJson(response.data);
    } catch (e) {
      print('❌ Error updating dependent contact: $e');
      
      if (e.toString().contains('403') || 
          e.toString().contains('Only primary guardian')) {
        throw Exception(
          'Only primary guardian can edit emergency contacts for dependents'
        );
      }
      rethrow;
    }
  }

  /// Delete emergency contact for dependent
  /// ⚠️ PRIMARY GUARDIAN ONLY - Collaborators will get 403
  Future<void> deleteDependentEmergencyContact(int contactId) async {
    try {
      await _dioClient.delete('/dependent/emergency-contacts/$contactId');
    } catch (e) {
      print('❌ Error deleting dependent contact: $e');
      
      if (e.toString().contains('403') || 
          e.toString().contains('Only primary guardian')) {
        throw Exception(
          'Only primary guardian can delete emergency contacts for dependents'
        );
      }
      rethrow;
    }
  }

  // ================================================
  // BULK IMPORT (Personal contacts only)
  // ================================================

  Future<Map<String, dynamic>> bulkImportContacts(
    List<Map<String, dynamic>> contacts,
  ) async {
    final response = await _dioClient.post(
      '/my-emergency-contacts/bulk',
      data: {'contacts': contacts},
    );
    return response.data;
  }

  // ================================================
  // UTILITY METHODS
  // ================================================

  /// Check if a contact can be deleted
  /// Auto-guardian contacts cannot be deleted
  bool canDeleteContact(EmergencyContact contact) {
    // Auto-guardian contacts are protected
    if (contact.source == 'auto_guardian') {
      return false;
    }
    return true;
  }

  /// Check if a contact can be edited
  bool canEditContact(EmergencyContact contact) {
    // All contacts can be edited (except maybe some special validation)
    return true;
  }
}