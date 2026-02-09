// lib/core/providers/emergency_contact_provider.dart (UPDATED - PRODUCTION READY)
// ====================
// SERVICE PROVIDER
// ====================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:safety_app/models/emergency_contact.dart';
import 'package:safety_app/services/emergency_contact_service.dart';

final emergencyContactServiceProvider = Provider<EmergencyContactService>((ref) {
  return EmergencyContactService();
});

// ====================
// PERSONAL EMERGENCY CONTACTS (Read-only providers)
// ====================

/// Provider for fetching current user's emergency contacts
final personalEmergencyContactsProvider = FutureProvider<List<EmergencyContact>>((ref) async {
  final service = ref.watch(emergencyContactServiceProvider);
  return await service.getMyEmergencyContacts();
});

// ====================
// DEPENDENT EMERGENCY CONTACTS (Read-only providers)
// ====================

/// Provider for fetching a specific dependent's emergency contacts
/// Used by guardians in Family Detail Screen
final dependentEmergencyContactsProvider =
    FutureProvider.family<List<EmergencyContact>, int>((ref, dependentId) async {
  final service = ref.watch(emergencyContactServiceProvider);
  return await service.getDependentEmergencyContacts(dependentId);
});

// ====================
// STATE NOTIFIER FOR CRUD OPERATIONS
// ====================

/// State for emergency contacts management
class EmergencyContactsState {
  final List<EmergencyContact> contacts;
  final bool isLoading;
  final String? error;
  final int? currentDependentId; // null means personal contacts

  const EmergencyContactsState({
    required this.contacts,
    required this.isLoading,
    this.error,
    this.currentDependentId,
  });

  EmergencyContactsState copyWith({
    List<EmergencyContact>? contacts,
    bool? isLoading,
    String? error,
    int? currentDependentId,
  }) {
    return EmergencyContactsState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentDependentId: currentDependentId ?? this.currentDependentId,
    );
  }

  factory EmergencyContactsState.initial() {
    return const EmergencyContactsState(
      contacts: [],
      isLoading: false,
      error: null,
      currentDependentId: null,
    );
  }

  factory EmergencyContactsState.loading() {
    return const EmergencyContactsState(
      contacts: [],
      isLoading: true,
      error: null,
    );
  }
}

/// Notifier for managing emergency contacts with full CRUD operations
class EmergencyContactNotifier extends StateNotifier<EmergencyContactsState> {
  final EmergencyContactService _service;

  EmergencyContactNotifier(this._service) : super(EmergencyContactsState.initial());

  // ====================
  // LOAD OPERATIONS
  // ====================

  /// Load personal emergency contacts
  Future<void> loadMyContacts() async {
    state = EmergencyContactsState.loading();
    
    try {
      final contacts = await _service.getMyEmergencyContacts();
      state = EmergencyContactsState(
        contacts: contacts,
        isLoading: false,
        error: null,
        currentDependentId: null,
      );
      print('✅ Loaded ${contacts.length} personal emergency contacts');
    } catch (e) {
      print('❌ Error loading personal contacts: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load emergency contacts for a specific dependent
  Future<void> loadDependentContacts(int dependentId) async {
    state = EmergencyContactsState.loading();
    
    try {
      final contacts = await _service.getDependentEmergencyContacts(dependentId);
      state = EmergencyContactsState(
        contacts: contacts,
        isLoading: false,
        error: null,
        currentDependentId: dependentId,
      );
      print('✅ Loaded ${contacts.length} contacts for dependent $dependentId');
    } catch (e) {
      print('❌ Error loading dependent contacts: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // ====================
  // CREATE OPERATIONS
  // ====================

  /// Add new personal emergency contact
  Future<bool> addMyContact(CreateEmergencyContact contactData) async {
    try {
      print('➕ Adding personal contact: ${contactData.name}');
      final newContact = await _service.createMyEmergencyContact(contactData.toJson());
      
      // Add to current list
      state = state.copyWith(
        contacts: [...state.contacts, newContact],
        error: null,
      );
      
      print('✅ Personal contact added successfully');
      return true;
    } catch (e) {
      print('❌ Error adding personal contact: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Add new emergency contact for a dependent (Primary guardian only)
  Future<bool> addDependentContact(
    int dependentId,
    CreateEmergencyContact contactData,
  ) async {
    try {
      print('➕ Adding contact for dependent $dependentId: ${contactData.name}');
      
      // Create contact data with dependent ID
      final dataWithDependent = contactData.toJson()..['dependent_id'] = dependentId;
      final newContact = await _service.createDependentEmergencyContact(dataWithDependent);
      
      // Add to current list only if we're viewing this dependent's contacts
      if (state.currentDependentId == dependentId) {
        state = state.copyWith(
          contacts: [...state.contacts, newContact],
          error: null,
        );
      }
      
      print('✅ Dependent contact added successfully');
      return true;
    } catch (e) {
      print('❌ Error adding dependent contact: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // ====================
  // UPDATE OPERATIONS
  // ====================

  /// Update an existing emergency contact
  Future<bool> updateContact(UpdateEmergencyContact contactData) async {
    try {
      print('✏️ Updating contact ${contactData.id}');
      
      final updatedContact = await _service.updateMyEmergencyContact(
        contactData.id,
        contactData.toJson(),
      );
      
      // Update in current list
      final updatedList = state.contacts.map((contact) {
        return contact.id == contactData.id ? updatedContact : contact;
      }).toList();
      
      state = state.copyWith(
        contacts: updatedList,
        error: null,
      );
      
      print('✅ Contact updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating contact: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Update a dependent's emergency contact
  Future<bool> updateDependentContact(UpdateEmergencyContact contactData) async {
    try {
      print('✏️ Updating dependent contact ${contactData.id}');
      
      final updatedContact = await _service.updateDependentEmergencyContact(
        contactData.id,
        contactData.toJson(),
      );
      
      // Update in current list
      final updatedList = state.contacts.map((contact) {
        return contact.id == contactData.id ? updatedContact : contact;
      }).toList();
      
      state = state.copyWith(
        contacts: updatedList,
        error: null,
      );
      
      print('✅ Dependent contact updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating dependent contact: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // ====================
  // DELETE OPERATIONS
  // ====================

  /// Delete a personal emergency contact
  Future<bool> deleteContact(int contactId) async {
    try {
      print('🗑️ Deleting contact $contactId');
      
      await _service.deleteMyEmergencyContact(contactId);
      
      // Remove from current list
      final updatedList = state.contacts.where((c) => c.id != contactId).toList();
      
      state = state.copyWith(
        contacts: updatedList,
        error: null,
      );
      
      print('✅ Contact deleted successfully');
      return true;
    } catch (e) {
      print('❌ Error deleting contact: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Delete a dependent's emergency contact (Primary guardian only)
  Future<bool> deleteDependentContact(int contactId) async {
    try {
      print('🗑️ Deleting dependent contact $contactId');
      
      await _service.deleteDependentEmergencyContact(contactId);
      
      // Remove from current list
      final updatedList = state.contacts.where((c) => c.id != contactId).toList();
      
      state = state.copyWith(
        contacts: updatedList,
        error: null,
      );
      
      print('✅ Dependent contact deleted successfully');
      return true;
    } catch (e) {
      print('❌ Error deleting dependent contact: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // ====================
  // BULK OPERATIONS
  // ====================

  /// Import multiple contacts at once
  Future<bool> bulkImportContacts(List<Map<String, dynamic>> contacts) async {
    try {
      print('📥 Importing ${contacts.length} contacts');
      
      final result = await _service.bulkImportContacts(contacts);
      
      // Reload contacts after bulk import
      await loadMyContacts();
      
      print('✅ Bulk import successful: ${result['imported']} contacts imported');
      return true;
    } catch (e) {
      print('❌ Error importing contacts: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // ====================
  // UTILITY METHODS
  // ====================

  /// Refresh current contacts list
  Future<void> refresh() async {
    if (state.currentDependentId != null) {
      await loadDependentContacts(state.currentDependentId!);
    } else {
      await loadMyContacts();
    }
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Get contacts synchronously (for immediate access)
  List<EmergencyContact> get contacts => state.contacts;

  /// Get primary contact
  EmergencyContact? get primaryContact {
    try {
      return state.contacts.firstWhere((c) => c.isPrimary);
    } catch (e) {
      return null;
    }
  }

  /// Get guardian contacts only
  List<EmergencyContact> get guardianContacts {
    return state.contacts.where((c) => c.isGuardianContact).toList();
  }

  /// Get manual contacts only
  List<EmergencyContact> get manualContacts {
    return state.contacts.where((c) => !c.isGuardianContact).toList();
  }

  /// Check if has any contacts
  bool get hasContacts => state.contacts.isNotEmpty;

  /// Check if is loading
  bool get isLoading => state.isLoading;

  /// Get error message
  String? get error => state.error;
}

// ====================
// PROVIDER FOR STATE NOTIFIER
// ====================

final emergencyContactNotifierProvider =
    StateNotifierProvider<EmergencyContactNotifier, EmergencyContactsState>((ref) {
  final service = ref.watch(emergencyContactServiceProvider);
  return EmergencyContactNotifier(service);
});

// ====================
// CONVENIENCE PROVIDERS
// ====================

/// Provider to get just the contacts list
final emergencyContactsListProvider = Provider<List<EmergencyContact>>((ref) {
  final state = ref.watch(emergencyContactNotifierProvider);
  return state.contacts;
});

/// Provider to check if user has any emergency contacts
final hasEmergencyContactsProvider = Provider<bool>((ref) {
  final state = ref.watch(emergencyContactNotifierProvider);
  return state.contacts.isNotEmpty;
});

/// Provider to get primary contact
final primaryEmergencyContactProvider = Provider<EmergencyContact?>((ref) {
  final state = ref.watch(emergencyContactNotifierProvider);
  try {
    return state.contacts.firstWhere((c) => c.isPrimary);
  } catch (e) {
    return null;
  }
});

/// Provider to check loading state
final emergencyContactsLoadingProvider = Provider<bool>((ref) {
  final state = ref.watch(emergencyContactNotifierProvider);
  return state.isLoading;
});

/// Provider to get error state
final emergencyContactsErrorProvider = Provider<String?>((ref) {
  final state = ref.watch(emergencyContactNotifierProvider);
  return state.error;
});