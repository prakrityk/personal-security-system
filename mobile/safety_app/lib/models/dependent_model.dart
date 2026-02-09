// ===================================================================
// UPDATED: dependent_model.dart - With Profile Picture
// ===================================================================
// lib/models/dependent_model.dart

class DependentModel {
  final int id; // Relationship ID
  final int dependentId; // Actual user ID of dependent
  final String dependentName;
  final String dependentEmail;
  final String? phoneNumber; // ✅ Added
  final String relation; // "child" or "elderly"
  final int? age;
  final bool isPrimary;
  final String guardianType; // "primary" or "collaborator"
  final String? profilePicture; // ✅ Added
  final DateTime linkedAt;

  DependentModel({
    required this.id,
    required this.dependentId,
    required this.dependentName,
    required this.dependentEmail,
    this.phoneNumber, // ✅ Added
    required this.relation,
    this.age,
    required this.isPrimary,
    required this.guardianType,
    this.profilePicture, // ✅ Added
    required this.linkedAt,
  });

  /// Check if current user is the primary guardian
  bool get isPrimaryGuardian => guardianType == "primary" && isPrimary;

  /// Check if current user is a collaborator guardian
  bool get isCollaborator => guardianType == "collaborator";

  /// Get display text for guardian type
  String get guardianTypeDisplay =>
      isPrimaryGuardian ? "Primary Guardian" : "Collaborator";

  /// Get display text for relation
  String get relationDisplay {
    switch (relation.toLowerCase()) {
      case 'child':
        return 'Child';
      case 'elderly':
        return 'Elderly';
      default:
        return relation;
    }
  }

  factory DependentModel.fromJson(Map<String, dynamic> json) {
    return DependentModel(
      id: json['id'] as int,
      dependentId: json['dependent_id'] as int,
      dependentName: json['dependent_name'] as String,
      dependentEmail: json['dependent_email'] as String,
      phoneNumber: json['phone_number'] as String?, // ✅ Added
      relation: json['relation'] as String,
      age: json['Age'] as int?,
      isPrimary: json['is_primary'] as bool? ?? false,
      guardianType: json['guardian_type'] as String? ?? 'primary',
      profilePicture: json['profile_picture'] as String?, // ✅ Added
      linkedAt: DateTime.parse(json['linked_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dependent_id': dependentId,
      'dependent_name': dependentName,
      'dependent_email': dependentEmail,
      'phone_number': phoneNumber, // ✅ Added
      'relation': relation,
      'Age': age,
      'is_primary': isPrimary,
      'guardian_type': guardianType,
      'profile_picture': profilePicture, // ✅ Added
      'linked_at': linkedAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'DependentModel(id: $id, name: $dependentName, guardianType: $guardianType)';
  }
}
