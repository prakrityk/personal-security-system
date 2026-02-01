// lib/models/user_model.dart

import 'package:safety_app/models/role_info.dart';

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String phoneNumber;
  final List<RoleInfo> roles;
  final String? profilePicture;
  final bool biometricEnabled;  // 🔐 ADDED: Biometric authentication status
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    this.roles = const [],
    this.profilePicture,
    this.biometricEnabled = false,  // 🔐 ADDED: Default to false
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? json['fullName'] ?? '',
      phoneNumber: json['phone_number'] ?? json['phoneNumber'] ?? '',
      roles: (json['roles'] as List? ?? [])
          .map((e) => RoleInfo.fromJson(e))
          .toList(),
      profilePicture: json['profile_picture'] ?? json['profilePicture'],
      biometricEnabled: json['biometric_enabled'] ?? false,  // 🔐 ADDED: Parse from JSON
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'roles': roles.map((r) => r.toJson()).toList(),
      'profile_picture': profilePicture,
      'biometric_enabled': biometricEnabled,  // 🔐 ADDED: Include in JSON
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Check if user has any role assigned
  bool get hasRole => roles.isNotEmpty;

  /// Check if user is a guardian
  bool get isGuardian =>
      roles.any((r) => r.roleName.toLowerCase() == 'guardian');

  /// Check if user is a dependent
  bool get isDependent =>
      roles.any((r) => r.roleName.toLowerCase() == 'dependent');

  /// Get primary role name
  String? get primaryRole => roles.isNotEmpty ? roles.first.roleName : null;

  /// Get display-friendly role name for UI
  String get displayRole {
    if (roles.isEmpty) return 'User';

    final role = roles.first.roleName.toLowerCase();

    // Convert role names to display format
    switch (role) {
      case 'global_user':
        return 'Personal User';
      case 'guardian':
        return 'Guardian';
      case 'dependent':
        return 'Dependent';
      case 'child':
        return 'Child';
      case 'elderly':
        return 'Elderly';
      default:
        // Capitalize first letter of each word
        return role
            .split('_')
            .map(
              (word) =>
                  word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
            )
            .join(' ');
    }
  }

  /// Get role description if available
  String? get roleDescription {
    if (roles.isEmpty) return null;
    return roles.first.roleDescription;
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phoneNumber,
    List<RoleInfo>? roles,
    String? profilePicture,
    bool? biometricEnabled,  // 🔐 ADDED: Include in copyWith
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      roles: roles ?? this.roles,
      profilePicture: profilePicture ?? this.profilePicture,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,  // 🔐 ADDED
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'UserModel(id: $id, email: $email, fullName: $fullName, roles: $roles, biometricEnabled: $biometricEnabled)';
}