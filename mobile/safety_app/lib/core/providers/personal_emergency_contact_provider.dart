// lib/core/providers/personal_emergency_contact_provider.dart
// SEPARATE PROVIDER FOR PERSONAL CONTACTS - Prevents state pollution

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safety_app/models/emergency_contact.dart';
import 'package:safety_app/services/emergency_contact_service.dart';
import 'package:flutter_riverpod/legacy.dart';
// ====================
// PERSONAL CONTACTS STATE
// ====================

class PersonalContactsState {
  final List<EmergencyContact> contacts;
  final bool isLoading;
  final String? error;

  const PersonalContactsState({
    required this.contacts,
    required this.isLoading,
    this.error,
  });

  PersonalContactsState copyWith({
    List<EmergencyContact>? contacts,
    bool? isLoading,
    String? error,
  }) {
    return PersonalContactsState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  factory PersonalContactsState.initial() {
    return const PersonalContactsState(
      contacts: [],
      isLoading: false,
      error: null,
    );
  }

  factory PersonalContactsState.loading() {
    return const PersonalContactsState(
      contacts: [],
      isLoading: true,
      error: null,
    );
  }
}

// ====================
// PERSONAL CONTACTS NOTIFIER
// ====================

class PersonalContactsNotifier extends StateNotifier<PersonalContactsState> {
  final EmergencyContactService _service;

  PersonalContactsNotifier(this._service)
    : super(PersonalContactsState.initial());

  /// Load personal emergency contacts
  Future<void> loadMyContacts() async {
    print('🔄 [PersonalContacts] Loading MY contacts...');
    state = PersonalContactsState.loading();

    try {
      final contacts = await _service.getMyEmergencyContacts();
      state = PersonalContactsState(
        contacts: contacts,
        isLoading: false,
        error: null,
      );
      print('✅ [PersonalContacts] Loaded ${contacts.length} personal contacts');
    } catch (e) {
      print('❌ [PersonalContacts] Error loading: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Add new personal contact
  Future<bool> addContact(CreateEmergencyContact contactData) async {
    try {
      print('➕ [PersonalContacts] Adding: ${contactData.name}');
      final newContact = await _service.createMyEmergencyContact(
        contactData.toJson(),
      );

      state = state.copyWith(
        contacts: [...state.contacts, newContact],
        error: null,
      );

      print('✅ [PersonalContacts] Contact added');
      return true;
    } catch (e) {
      print('❌ [PersonalContacts] Add failed: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Update contact
  Future<bool> updateContact(UpdateEmergencyContact contactData) async {
    try {
      print('✏️ [PersonalContacts] Updating: ${contactData.id}');
      final updatedContact = await _service.updateMyEmergencyContact(
        contactData.id,
        contactData.toJson(),
      );

      final updatedList = state.contacts.map((contact) {
        return contact.id == contactData.id ? updatedContact : contact;
      }).toList();

      state = state.copyWith(contacts: updatedList, error: null);

      print('✅ [PersonalContacts] Contact updated');
      return true;
    } catch (e) {
      print('❌ [PersonalContacts] Update failed: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Delete contact
  Future<bool> deleteContact(int contactId) async {
    try {
      print('🗑️ [PersonalContacts] Deleting: $contactId');
      await _service.deleteMyEmergencyContact(contactId);

      final updatedList = state.contacts
          .where((c) => c.id != contactId)
          .toList();

      state = state.copyWith(contacts: updatedList, error: null);

      print('✅ [PersonalContacts] Contact deleted');
      return true;
    } catch (e) {
      print('❌ [PersonalContacts] Delete failed: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Bulk import
  Future<bool> bulkImportContacts(List<Map<String, dynamic>> contacts) async {
    try {
      print('📥 Importing ${contacts.length} contacts');

      await _service.bulkImportContacts(contacts);
      await loadMyContacts();

      // ✅ Don't access result fields you're not sure about
      print('✅ Bulk import successful');
      return true;
    } catch (e) {
      print(
        '❌ Error importing contacts: $e',
      ); // ← this will now tell you exactly what failed
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Refresh
  Future<void> refresh() async {
    await loadMyContacts();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ====================
// PROVIDER
// ====================

final personalContactsNotifierProvider =
    StateNotifierProvider<PersonalContactsNotifier, PersonalContactsState>((
      ref,
    ) {
      final service = EmergencyContactService();
      return PersonalContactsNotifier(service);
    });

// ====================
// CONVENIENCE PROVIDERS
// ====================

final personalContactsListProvider = Provider<List<EmergencyContact>>((ref) {
  final state = ref.watch(personalContactsNotifierProvider);
  return state.contacts;
});

final hasPersonalContactsProvider = Provider<bool>((ref) {
  final state = ref.watch(personalContactsNotifierProvider);
  return state.contacts.isNotEmpty;
});

final personalContactsLoadingProvider = Provider<bool>((ref) {
  final state = ref.watch(personalContactsNotifierProvider);
  return state.isLoading;
});

final personalContactsErrorProvider = Provider<String?>((ref) {
  final state = ref.watch(personalContactsNotifierProvider);
  return state.error;
});
