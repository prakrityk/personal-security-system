// lib/models/emergency_contact.dart (UPDATED - FIXED toJson methods)

class EmergencyContact {
  final int? id;
  final String name;
  final String phoneNumber;
  final String email;
  final String relationship;
  final bool isPrimary;
  final String source; // 'manual', 'auto_guardian', 'phone_contacts'
  final int? userId; // If personal contact
  final int? dependentId; // If dependent's contact
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const EmergencyContact({
    this.id,
    required this.name,
    required this.phoneNumber,
    this.email = '',
    this.relationship = '',
    this.isPrimary = false,
    this.source = 'manual',
    this.userId,
    this.dependentId,
    this.createdAt,
    this.updatedAt,
  });

  // From JSON (matches your backend response)
  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] as int?,
      name: json['name'] as String? ?? json['contact_name'] as String? ?? '',
      phoneNumber:
          json['phone_number'] as String? ??
          json['contact_phone'] as String? ??
          '',
      email: json['email'] as String? ?? json['contact_email'] as String? ?? '',
      relationship:
          json['relationship'] as String? ??
          json['contact_relationship'] as String? ??
          '',
      isPrimary: json['is_primary'] as bool? ?? json['priority'] == 1 ?? false,
      source: json['source'] as String? ?? 'manual',
      userId: json['user_id'] as int?,
      dependentId: json['dependent_id'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  // To JSON (for API requests)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone_number': phoneNumber,
      if (email.isNotEmpty) 'email': email,
      if (relationship.isNotEmpty) 'relationship': relationship,
      'is_primary': isPrimary,
      'source': source,
      if (userId != null) 'user_id': userId,
      if (dependentId != null) 'dependent_id': dependentId,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  // Copy with
  EmergencyContact copyWith({
    int? id,
    String? name,
    String? phoneNumber,
    String? email,
    String? relationship,
    bool? isPrimary,
    String? source,
    int? userId,
    int? dependentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      relationship: relationship ?? this.relationship,
      isPrimary: isPrimary ?? this.isPrimary,
      source: source ?? this.source,
      userId: userId ?? this.userId,
      dependentId: dependentId ?? this.dependentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Display name with relationship
  String get displayName {
    if (relationship.isNotEmpty) {
      return '$name ($relationship)';
    }
    return name;
  }

  // Check if this is a guardian contact (cannot be deleted by dependent)
  bool get isGuardianContact => source == 'auto_guardian';

  // Check if this contact can be edited
  bool get canEdit => source != 'auto_guardian';

  // Check if this contact can be deleted
  bool get canDelete => source != 'auto_guardian';

  @override
  String toString() {
    return 'EmergencyContact(id: $id, name: $name, phone: $phoneNumber, source: $source)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmergencyContact &&
        other.id == id &&
        other.name == name &&
        other.phoneNumber == phoneNumber;
  }

  @override
  int get hashCode => Object.hash(id, name, phoneNumber);
}

// Model for creating new emergency contact
class CreateEmergencyContact {
  final String name;
  final String phoneNumber;
  final String? email;
  final String? relationship;
  final int? dependentId; // If creating for a dependent

  const CreateEmergencyContact({
    required this.name,
    required this.phoneNumber,
    this.email,
    this.relationship,
    this.dependentId,
  });

  // ✅ FIXED: Use backend field names
  Map<String, dynamic> toJson() {
    return {
      'contact_name': name, // ✅ Backend expects this
      'contact_phone': phoneNumber, // ✅ Backend expects this
      if (email != null && email!.isNotEmpty)
        'contact_email': email, // ✅ Backend expects this
      if (relationship != null && relationship!.isNotEmpty)
        'contact_relationship': relationship, // ✅ Backend expects this
      'priority': 2, // ✅ Added: Default priority
      'source': 'manual', // ✅ Added: Source type
      'is_active': true, // ✅ Added: Active status
      if (dependentId != null) 'dependent_id': dependentId,
    };
  }
}

// Model for updating emergency contact
class UpdateEmergencyContact {
  final int id;
  final String? name;
  final String? phoneNumber;
  final String? email;
  final String? relationship;

  const UpdateEmergencyContact({
    required this.id,
    this.name,
    this.phoneNumber,
    this.email,
    this.relationship,
  });

  // ✅ FIXED: Use backend field names
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'id': id};

    if (name != null) json['contact_name'] = name; // ✅ Backend expects this
    if (phoneNumber != null)
      json['contact_phone'] = phoneNumber; // ✅ Backend expects this
    if (email != null) json['contact_email'] = email; // ✅ Backend expects this
    if (relationship != null)
      json['contact_relationship'] = relationship; // ✅ Backend expects this

    return json;
  }
}
