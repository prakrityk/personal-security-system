// lib/services/contact_import_service.dart
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

/// Model for imported phone contact
class PhoneContactModel {
  final String displayName;
  final String? phoneNumber;
  final String? email;
  final bool hasPhone;
  final bool hasEmail;

  PhoneContactModel({
    required this.displayName,
    this.phoneNumber,
    this.email,
    required this.hasPhone,
    required this.hasEmail,
  });

  /// Convert to emergency contact format
  Map<String, dynamic> toEmergencyContactJson({
    required String relationship,
    int priority = 2,
  }) {
    return {
      'contact_name': displayName,
      'contact_phone': phoneNumber ?? '',
      'contact_email': email ?? '',
      'contact_relationship': relationship,
      'priority': priority,
      'source': 'phone_contacts',
      'is_active': true,
    };
  }
}

class ContactImportService {
  /// Check if contacts permission is granted
  Future<bool> checkContactsPermission() async {
    final status = await Permission.contacts.status;
    return status.isGranted;
  }

  /// Request contacts permission
  Future<bool> requestContactsPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  /// Format phone number to include country code
  String _formatPhoneNumber(
    String phoneNumber, {
    String defaultCountryCode = '+977',
  }) {
    // Remove all non-digit characters
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // If already has +, return as is
    if (cleaned.startsWith('+')) {
      return cleaned;
    }

    // If starts with country code without +, add +
    if (cleaned.startsWith('977') && cleaned.length > 10) {
      return '+$cleaned';
    }

    // If starts with 0, remove it (common in Nepal)
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }

    // Add default country code
    return '$defaultCountryCode$cleaned';
  }

  /// Get all phone contacts
  Future<List<PhoneContactModel>> getPhoneContacts() async {
    try {
      // Check permission first
      final hasPermission = await checkContactsPermission();
      if (!hasPermission) {
        final granted = await requestContactsPermission();
        if (!granted) {
          throw Exception('Contacts permission denied');
        }
      }

      // Fetch contacts with phones and emails
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      // Convert to PhoneContactModel
      final List<PhoneContactModel> phoneContacts = [];

      for (final contact in contacts) {
        // Skip contacts without name
        if (contact.displayName.isEmpty) {
          continue;
        }

        // Get primary phone number
        String? phoneNumber;
        if (contact.phones.isNotEmpty) {
          phoneNumber = contact.phones.first.number;
          // Format phone number with country code
          phoneNumber = _formatPhoneNumber(phoneNumber);
        }

        // Get primary email
        String? email;
        if (contact.emails.isNotEmpty) {
          email = contact.emails.first.address;
        }

        // Only include contacts with at least phone or email
        if (phoneNumber != null || email != null) {
          phoneContacts.add(
            PhoneContactModel(
              displayName: contact.displayName,
              phoneNumber: phoneNumber,
              email: email,
              hasPhone: phoneNumber != null,
              hasEmail: email != null,
            ),
          );
        }
      }

      // Sort contacts alphabetically
      phoneContacts.sort((a, b) => a.displayName.compareTo(b.displayName));

      print('✅ Loaded ${phoneContacts.length} contacts from phone');
      return phoneContacts;
    } catch (e) {
      print('❌ Error loading contacts: $e');
      rethrow;
    }
  }

  /// Search contacts by name
  Future<List<PhoneContactModel>> searchContacts(String query) async {
    final contacts = await getPhoneContacts();

    if (query.isEmpty) {
      return contacts;
    }

    final lowerQuery = query.toLowerCase();
    return contacts.where((contact) {
      return contact.displayName.toLowerCase().contains(lowerQuery) ||
          (contact.phoneNumber?.contains(lowerQuery) ?? false) ||
          (contact.email?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// Get contacts grouped by first letter
  Future<Map<String, List<PhoneContactModel>>> getGroupedContacts() async {
    final contacts = await getPhoneContacts();
    final Map<String, List<PhoneContactModel>> grouped = {};

    for (final contact in contacts) {
      final firstLetter = contact.displayName[0].toUpperCase();
      if (!grouped.containsKey(firstLetter)) {
        grouped[firstLetter] = [];
      }
      grouped[firstLetter]!.add(contact);
    }

    return grouped;
  }

  /// Check if contact already exists in emergency contacts
  bool isDuplicate(
    PhoneContactModel phoneContact,
    List<dynamic> existingContacts,
  ) {
    for (final existing in existingContacts) {
      // Get phone number from existing contact (handle different field names)
      String? existingPhone;
      if (existing is Map) {
        existingPhone =
            existing['phoneNumber'] ??
            existing['phone_number'] ??
            existing['contact_phone'];
      } else {
        // If it's an EmergencyContact object
        try {
          existingPhone = (existing as dynamic).phoneNumber;
        } catch (e) {
          continue;
        }
      }

      // Check if phone number matches
      if (phoneContact.phoneNumber != null && existingPhone != null) {
        // Clean both numbers for comparison
        final cleanPhone1 = phoneContact.phoneNumber!.replaceAll(
          RegExp(r'[^\d]'),
          '',
        );
        final cleanPhone2 = existingPhone.replaceAll(RegExp(r'[^\d]'), '');

        if (cleanPhone1 == cleanPhone2 ||
            cleanPhone1.endsWith(cleanPhone2) ||
            cleanPhone2.endsWith(cleanPhone1)) {
          return true;
        }
      }

      // Check if email matches
      String? existingEmail;
      if (existing is Map) {
        existingEmail = existing['email'] ?? existing['contact_email'];
      } else {
        try {
          existingEmail = (existing as dynamic).email;
        } catch (e) {
          continue;
        }
      }

      if (phoneContact.email != null &&
          existingEmail != null &&
          phoneContact.email!.toLowerCase() == existingEmail.toLowerCase()) {
        return true;
      }

      // Check if name matches (fuzzy)
      String? existingName;
      if (existing is Map) {
        existingName = existing['name'] ?? existing['contact_name'];
      } else {
        try {
          existingName = (existing as dynamic).name;
        } catch (e) {
          continue;
        }
      }

      if (existingName != null &&
          existingName.toLowerCase() ==
              phoneContact.displayName.toLowerCase()) {
        return true;
      }
    }
    return false;
  }
}
