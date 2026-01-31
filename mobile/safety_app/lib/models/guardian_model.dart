// ===================================================================
// UPDATED: guardian_model.dart - With Profile Picture
// ===================================================================
// lib/models/guardian_model.dart

class GuardianModel {
  final int id; // Relationship ID
  final int guardianId; // Actual user ID of guardian
  final String guardianName;
  final String guardianEmail;
  final String phoneNumber; // ✅ Added
  final String relation; // "child" or "elderly"
  final bool isPrimary;
  final String? profilePicture; // ✅ Added
  final DateTime linkedAt;

  GuardianModel({
    required this.id,
    required this.guardianId,
    required this.guardianName,
    required this.guardianEmail,
    required this.phoneNumber, // ✅ Added
    required this.relation,
    required this.isPrimary,
    this.profilePicture, // ✅ Added
    required this.linkedAt,
  });

  /// Get display text for guardian type
  String get guardianTypeDisplay =>
      isPrimary ? "Primary Guardian" : "Collaborator";

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

  factory GuardianModel.fromJson(Map<String, dynamic> json) {
    return GuardianModel(
      id: json['id'] as int,
      guardianId: json['guardian_id'] as int,
      guardianName: json['guardian_name'] as String,
      guardianEmail: json['guardian_email'] as String,
      phoneNumber: json['phone_number'] as String? ?? '', // ✅ Added
      relation: json['relation'] as String,
      isPrimary: json['is_primary'] as bool? ?? false,
      profilePicture: json['profile_picture'] as String?, // ✅ Added
      linkedAt: DateTime.parse(json['linked_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'guardian_id': guardianId,
      'guardian_name': guardianName,
      'guardian_email': guardianEmail,
      'phone_number': phoneNumber, // ✅ Added
      'relation': relation,
      'is_primary': isPrimary,
      'profile_picture': profilePicture, // ✅ Added
      'linked_at': linkedAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'GuardianModel(id: $id, name: $guardianName, isPrimary: $isPrimary)';
  }
}
