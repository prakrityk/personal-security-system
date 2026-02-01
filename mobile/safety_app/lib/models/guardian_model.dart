// ===================================================================
// FIXED: guardian_model.dart - WITH guardian_type field
// ===================================================================
// lib/models/guardian_model.dart

class GuardianModel {
  final int id; // Relationship ID
  final int guardianId; // Actual user ID of guardian
  final String guardianName;
  final String guardianEmail;
  final String phoneNumber;
  final String relation; // "child" or "elderly"
  final bool isPrimary;
  final String guardianType; // ✅ ADDED: "primary" or "collaborator"
  final String? profilePicture;
  final DateTime linkedAt;

  GuardianModel({
    required this.id,
    required this.guardianId,
    required this.guardianName,
    required this.guardianEmail,
    required this.phoneNumber,
    required this.relation,
    required this.isPrimary,
    required this.guardianType, // ✅ ADDED
    this.profilePicture,
    required this.linkedAt,
  });

  /// ✅ NEW: Get display text for guardian type
  String get guardianTypeDisplay {
    if (guardianType == "primary" || isPrimary) {
      return "Primary Guardian";
    } else {
      return "Collaborator Guardian";
    }
  }

  /// Get display text for relation
  String get relationDisplay {
    switch (relation.toLowerCase()) {
      case 'child':
        return 'Guardian (Child)';
      case 'elderly':
        return 'Guardian (Elderly)';
      default:
        return 'Guardian';
    }
  }

  /// ✅ NEW: Check if this is primary guardian
  bool get isPrimaryGuardian => guardianType == "primary" || isPrimary;

  /// ✅ NEW: Check if this is collaborator
  bool get isCollaborator => guardianType == "collaborator" && !isPrimary;

  factory GuardianModel.fromJson(Map<String, dynamic> json) {
    return GuardianModel(
      id: json['id'] as int,
      guardianId: json['guardian_id'] as int,
      guardianName: json['guardian_name'] as String,
      guardianEmail: json['guardian_email'] as String,
      phoneNumber: json['phone_number'] as String? ?? '',
      relation: json['relation'] as String,
      isPrimary: json['is_primary'] as bool? ?? false,
      guardianType:
          json['guardian_type'] as String? ??
          'primary', // ✅ ADDED with fallback
      profilePicture: json['profile_picture'] as String?,
      linkedAt: DateTime.parse(json['linked_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'guardian_id': guardianId,
      'guardian_name': guardianName,
      'guardian_email': guardianEmail,
      'phone_number': phoneNumber,
      'relation': relation,
      'is_primary': isPrimary,
      'guardian_type': guardianType, // ✅ ADDED
      'profile_picture': profilePicture,
      'linked_at': linkedAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'GuardianModel(id: $id, name: $guardianName, type: $guardianType, isPrimary: $isPrimary)';
  }
}
