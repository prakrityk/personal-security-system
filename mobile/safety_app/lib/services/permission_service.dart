// lib/services/permission_service.dart
import 'package:flutter/material.dart';
import 'package:safety_app/models/user_model.dart';
import 'package:safety_app/services/auth_service.dart';
import 'package:safety_app/services/guardian_service.dart';
import 'package:safety_app/services/family_service.dart';

/// Permission Service - Handles role-based permissions and access control
class PermissionService {
  final AuthService _authService = AuthService();
  final GuardianService _guardianService = GuardianService();
  final FamilyService _familyService = FamilyService();

  UserModel? _currentUser;

  // ================================================
  // INITIALIZATION
  // ================================================

  /// Initialize service with current user
  Future<void> initialize() async {
    _currentUser = await _authService.getCurrentUser();
    print('🔐 PermissionService initialized for user: ${_currentUser?.email}');
  }

  /// Refresh user data
  Future<void> refreshUser() async {
    _currentUser = await _authService.getCurrentUser();
  }

  // ================================================
  // ROLE CHECKERS (Updated to use your UserModel)
  // ================================================

  /// Check if user is a personal user (global_user role)
  bool get isPersonalUser {
    return _hasRole('global_user');
  }

  /// Check if user is a guardian
  bool get isGuardian {
    return _hasRole('guardian');
  }

  /// Check if user is a dependent
  bool get isDependent {
    return _hasRole('dependent') || _hasRole('child') || _hasRole('elderly');
  }

  /// Check if user is a child
  bool get isChild {
    return _hasRole('child');
  }

  /// Check if user is an elderly
  bool get isElderly {
    return _hasRole('elderly');
  }

  /// Helper method to check if user has a specific role
  bool _hasRole(String roleName) {
    if (_currentUser == null || _currentUser!.roles.isEmpty) return false;

    final role = roleName.toLowerCase();
    return _currentUser!.roles.any(
      (r) =>
          r.roleName.toLowerCase().contains(role) ||
          role.contains(r.roleName.toLowerCase()),
    );
  }

  /// Check if user is a primary guardian
  Future<bool> isPrimaryGuardian() async {
    if (!isGuardian) return false;

    try {
      final dependents = await _guardianService.getMyDependents();
      return dependents.any((d) => d.isPrimaryGuardian);
    } catch (e) {
      print('❌ Error checking primary guardian status: $e');
      return false;
    }
  }

  /// Check if user is a collaborator guardian
  Future<bool> isCollaboratorGuardian() async {
    if (!isGuardian) return false;

    try {
      final dependents = await _guardianService.getMyDependents();
      return dependents.any((d) => d.isCollaborator);
    } catch (e) {
      print('❌ Error checking collaborator status: $e');
      return false;
    }
  }

  /// Check if user has multiple roles
  bool get hasMultipleRoles {
    if (_currentUser == null) return false;
    return _currentUser!.roles.length > 1;
  }

  /// Get user's primary role for display
  String get primaryRoleDisplay {
    if (_currentUser == null) return 'User';
    return _currentUser!.displayRole;
  }

  // ================================================
  // SPECIFIC PERMISSION CHECKERS
  // ================================================

  /// Check if user can logout (dependents cannot logout)
  bool get canLogout {
    return !isDependent;
  }

  /// Check if user can access Map tab
  bool get canAccessMapTab {
    return !isDependent;
  }

  /// Check if user can access Safety tab
  bool get canAccessSafetyTab {
    return !isDependent;
  }

  /// Check if user can edit personal profile
  bool get canEditProfile {
    return !isDependent;
  }

  /// Check if user can add new dependents
  Future<bool> get canAddDependents async {
    if (!isGuardian) return false;
    return await isPrimaryGuardian();
  }

  /// Check if user can invite collaborators
  Future<bool> canInviteCollaborators(int dependentId) async {
    if (!isGuardian) return false;
    return await isPrimaryGuardianForDependent(dependentId);
  }

  /// Check if user can scan QR codes (dependents only)
  bool get canScanQR {
    return isDependent;
  }

  // ================================================
  // DEPENDENT-SPECIFIC PERMISSIONS
  // ================================================

  /// Core rule: can user edit dependent contacts?
  bool _canEditDependentContactsCore({
    required bool isViewingDependent,
    required bool isPrimaryGuardianForThatDependent,
  }) {
    if (!isViewingDependent) return true; // editing own contacts
    return isPrimaryGuardianForThatDependent;
  }

  /// Check if user is primary guardian for a specific dependent
  Future<bool> isPrimaryGuardianForDependent(int dependentId) async {
    if (!isGuardian) return false;

    try {
      final dependents = await _guardianService.getMyDependents();
      final dependent = dependents.firstWhere(
        (d) => d.dependentId == dependentId,
        orElse: () => throw Exception('Dependent not found in your list'),
      );
      return dependent.isPrimaryGuardian;
    } catch (e) {
      print('❌ Error checking primary guardian for dependent: $e');
      return false;
    }
  }

  /// Check if user is any guardian (primary or collaborator) for a dependent
  Future<bool> isGuardianForDependent(int dependentId) async {
    if (!isGuardian) return false;

    try {
      final dependents = await _guardianService.getMyDependents();
      return dependents.any((d) => d.dependentId == dependentId);
    } catch (e) {
      print('❌ Error checking guardian for dependent: $e');
      return false;
    }
  }

  /// Check if user can edit emergency contacts for a dependent
  Future<bool> canEditDependentEmergencyContacts(int dependentId) async {
    final isPrimary = await isPrimaryGuardianForDependent(dependentId);

    return _canEditDependentContactsCore(
      isViewingDependent: true,
      isPrimaryGuardianForThatDependent: isPrimary,
    );
  }
  

  /// Check if user can edit safety features for a dependent
  Future<bool> canEditDependentSafetyFeatures(int dependentId) async {
    return await isPrimaryGuardianForDependent(dependentId);
  }

  /// Check if user can view dependent's safety features
  Future<bool> canViewDependentSafetyFeatures(int dependentId) async {
    return await isGuardianForDependent(dependentId);
  }

  /// Check if user can view dependent's live location
  Future<bool> canViewDependentLocation(int dependentId) async {
    return await isGuardianForDependent(dependentId);
  }

  /// Check if user can set geofencing for a dependent
  Future<bool> canSetDependentGeofencing(int dependentId) async {
    return await isPrimaryGuardianForDependent(dependentId);
  }

  /// Check if user can update dependent's information
  Future<bool> canUpdateDependentInfo(int dependentId) async {
    return await isPrimaryGuardianForDependent(dependentId);
  }

  /// Check if user can remove a dependent
  Future<bool> canRemoveDependent(int dependentId) async {
    return await isPrimaryGuardianForDependent(dependentId);
  }

  // ================================================
  // EMERGENCY CONTACT PERMISSIONS
  // ================================================

  /// Check if user can edit their own emergency contacts
  bool get canEditOwnEmergencyContacts {
    return !isDependent;
  }

  /// Check if user can view emergency contacts (dependents can view but not edit)
  bool get canViewEmergencyContacts {
    return true; // Everyone can view emergency contacts
  }

  /// Check if user can delete an emergency contact
  Future<bool> canDeleteEmergencyContact(int contactId, String source) async {
    // Auto-generated guardian contacts cannot be deleted
    if (source == 'auto_guardian') {
      return false;
    }

    if (isDependent) {
      return false; // Dependents cannot delete any contacts
    }

    return true;
  }

  /// Check if user can import contacts from phone
  bool get canImportPhoneContacts {
    return !isDependent;
  }

  // ================================================
  // COLLABORATOR PERMISSIONS
  // ================================================

  /// Check if user can view collaborators for a dependent
  Future<bool> canViewCollaborators(int dependentId) async {
    return await isPrimaryGuardianForDependent(dependentId);
  }

  /// Check if user can remove a collaborator
  Future<bool> canRemoveCollaborator(
    int dependentId,
    int collaboratorId,
  ) async {
    if (collaboratorId == _currentUser?.id) {
      return false; // Cannot remove yourself
    }
    return await isPrimaryGuardianForDependent(dependentId);
  }

  /// Check if user can accept collaborator invitations
  bool get canAcceptCollaboratorInvitations {
    return isGuardian;
  }

  // ================================================
  // NAVIGATION PERMISSIONS
  // ================================================

  /// Get available bottom navigation tabs based on role
  List<String> getAvailableTabs() {
    if (isDependent) {
      return ['home', 'family']; // Dependents only get Home and Family tabs
    } else {
      return ['home', 'map', 'safety', 'family']; // Others get all tabs
    }
  }

  /// Get tab display names
  Map<String, String> getTabDisplayNames() {
    return {
      'home': 'Home',
      'map': 'Map',
      'safety': 'Safety',
      'family': 'Family',
    };
  }

  /// Get tab icons
  Map<String, IconData> getTabIcons() {
    return {
      'home': Icons.home,
      'map': Icons.map,
      'safety': Icons.security,
      'family': Icons.family_restroom,
    };
  }

  // ================================================
  // APP BAR PERMISSIONS
  // ================================================

  /// Check if user can access account settings
  bool get canAccessAccountSettings {
    return !isDependent;
  }

  /// Check if user can change app theme
  bool get canChangeTheme {
    return !isDependent;
  }

  /// Check if user can access app settings
  bool get canAccessSettings {
    return !isDependent;
  }

  // ================================================
  // SOS FEATURE PERMISSIONS
  // ================================================

  /// Check if user can trigger SOS
  bool get canTriggerSOS {
    return true; // Everyone can trigger SOS
  }

  /// Check if user can configure SOS settings
  bool get canConfigureSOS {
    return !isDependent;
  }

  /// Check if user can view SOS history
  bool get canViewSOSHistory {
    return !isDependent;
  }

  // ================================================
  // PERMISSION SUMMARY
  // ================================================

  /// Get comprehensive permission summary for current user
  Future<Map<String, dynamic>> getPermissionSummary() async {
    await refreshUser();

    final isPrimary = await isPrimaryGuardian();
    final isCollaborator = await isCollaboratorGuardian();

    return {
      'user_type': _getUserTypeString(),
      'primary_role': primaryRoleDisplay,
      'is_child': isChild,
      'is_elderly': isElderly,
      'is_primary_guardian': isPrimary,
      'is_collaborator_guardian': isCollaborator,
      'has_multiple_roles': hasMultipleRoles,
      'can_logout': canLogout,
      'available_tabs': getAvailableTabs(),
      'can_add_dependents': await canAddDependents,
      'can_edit_profile': canEditProfile,
      'can_access_map': canAccessMapTab,
      'can_access_safety': canAccessSafetyTab,
      'can_scan_qr': canScanQR,
      'can_edit_own_contacts': canEditOwnEmergencyContacts,
      'can_view_contacts': canViewEmergencyContacts,
      'can_import_contacts': canImportPhoneContacts,
      'can_accept_collaborator_invites': canAcceptCollaboratorInvitations,
      'can_access_account': canAccessAccountSettings,
      'can_trigger_sos': canTriggerSOS,
      'can_configure_sos': canConfigureSOS,
    };
  }

  String _getUserTypeString() {
    if (isDependent) {
      if (isChild) return 'Child Dependent';
      if (isElderly) return 'Elderly Dependent';
      return 'Dependent';
    }
    if (isGuardian) return 'Guardian';
    if (isPersonalUser) return 'Personal User';
    return 'User';
  }

  /// Get detailed role information
  List<Map<String, dynamic>> getRoleDetails() {
    if (_currentUser == null) return [];

    return _currentUser!.roles.map((role) {
      return {
        'id': role.id,
        'name': role.roleName,
        'description': role.roleDescription,
        'display_name': _getRoleDisplayName(role.roleName),
      };
    }).toList();
  }

  String _getRoleDisplayName(String roleName) {
    switch (roleName.toLowerCase()) {
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
        return roleName;
    }
  }

  // ================================================
  // UTILITY METHODS
  // ================================================

  /// Check if an action is allowed and throw exception if not
  Future<void> requirePermission({
    required String permission,
    required Future<bool> check,
    int? dependentId,
  }) async {
    final isAllowed = await check;

    if (!isAllowed) {
      String message = 'You do not have permission to $permission';
      if (dependentId != null) {
        message += ' for dependent $dependentId';
      }

      if (isDependent) {
        message +=
            '\n\nDependents have limited permissions for safety reasons.';
      } else if (await isCollaboratorGuardian()) {
        message +=
            '\n\nCollaborator guardians can only view information. '
            'Please contact the primary guardian for changes.';
      } else if (isPersonalUser) {
        message +=
            '\n\nPersonal users cannot access family features. '
            'Please select a guardian role.';
      }

      throw Exception(message);
    }
  }

  /// Get permission error message for UI display
  Future<String> getPermissionErrorMessage({
    required String action,
    int? dependentId,
  }) async {
    if (isDependent) {
      return 'Dependents cannot $action. This feature is only available to guardians.';
    }

    if (await isCollaboratorGuardian()) {
      return 'Collaborator guardians can only view information. '
          'Only primary guardians can $action.';
    }

    if (isPersonalUser) {
      return 'Personal users cannot $action. Please select a guardian role first.';
    }

    return 'You do not have permission to $action';
  }

  /// Check if user should see onboarding for a feature
  Future<bool> shouldShowFeatureOnboarding(String feature) async {
    if (isDependent) return false;

    // First-time users might need guidance
    final isFirstTime = await _checkFirstTimeFeature(feature);
    return isFirstTime;
  }

  Future<bool> _checkFirstTimeFeature(String feature) async {
    // TODO: Implement using SharedPreferences
    // Check if user has used this feature before
    return true; // For now, assume first time
  }
}
