// lib/core/network/api_endpoints.dart
// Complete API endpoints - Firebase, Biometric, and Traditional Auth

class ApiEndpoints {
  // ============================================================================
  // BASE URL CONFIGURATION
  // ============================================================================

  // ✅ Use your laptop's IP address for physical device
  // Change this to match your actual backend server IP
  // static const String baseUrl = 'http://localhost:8000/api';
  //'http://192.168.21.102:8000/api';
  static const String baseUrl =
      'https://yevette-oxycephalic-lanell.ngrok-free.dev/api';
  // For emulator testing, use: 'http://10.0.2.2:8000/api'
  // For localhost web testing, use: 'http://localhost:8000/api'

  // ============================================================================
  // 🔥 FIREBASE AUTHENTICATION ENDPOINTS
  // ============================================================================

  /// Complete registration with Firebase token
  /// This is the MAIN endpoint for new Firebase registration flow
  static const String completeFirebaseRegistration =
      '/auth/firebase/complete-registration';

  /// Firebase login — used after password reset when normal login fails
  /// Verifies Firebase token, finds user, syncs password, issues JWTs
  static const String firebaseLogin = '/auth/firebase/login';

  // ============================================================================
  // 🔐 BIOMETRIC AUTHENTICATION ENDPOINTS
  // ============================================================================

  /// Enable biometric authentication for current user
  /// For Guardian users: This also assigns the Guardian role
  static const String enableBiometric = '/auth/enable-biometric';

  // ============================================================================
  // 📱 PHONE VERIFICATION ENDPOINTS
  // ============================================================================

  /// Send verification code to phone number
  static const String sendVerificationCode = '/auth/send-verification-code';

  /// Verify phone number with OTP
  static const String verifyPhone = '/auth/verify-phone';

  /// Check if phone number exists
  static const String checkPhone = '/auth/check-phone';

  // ============================================================================
  // 📧 EMAIL VERIFICATION ENDPOINTS
  // ============================================================================

  /// Check if email exists
  static const String checkEmail = '/auth/check-email';

  /// Verify email with OTP (old registration system)
  static const String verifyEmail = '/auth/verify-email';

  /// Resend email OTP (old registration system)
  static const String resendEmailOTP = '/auth/resend-email-otp';

  // ============================================================================
  // 🔑 AUTHENTICATION ENDPOINTS
  // ============================================================================

  /// Traditional registration (may be deprecated in favor of Firebase flow)
  static const String register = '/auth/register';

  /// Login with phone/email and password
  static const String login = '/auth/login';

  /// Get current authenticated user
  static const String me = '/auth/me';

  /// Refresh access token
  static const String refresh = '/auth/refresh';

  /// Logout current session
  static const String logout = '/auth/logout';

  /// Logout from all devices
  static const String logoutAll = '/auth/logout-all';

  /// Update password
  static const String updatePassword = '/auth/update-password';

  // ============================================================================
  // 👤 PROFILE MANAGEMENT ENDPOINTS
  // ============================================================================

  /// Update user profile (name only)
  static const String updateProfile = '/auth/profile';

  /// Upload profile picture
  static const String uploadProfilePicture = '/auth/profile/picture';

  /// Delete profile picture
  static const String deleteProfilePicture = '/auth/profile/picture';

  // ============================================================================
  // 🎭 ROLE MANAGEMENT ENDPOINTS
  // ============================================================================

  /// Get all available roles
  static const String getRoles = '/auth/roles';

  /// Select/assign role to user
  static const String selectRole = '/auth/select-role';

  // ============================================================================
  // 👨‍👩‍👧‍👦 GUARDIAN ENDPOINTS
  // ============================================================================

  /// Create pending dependent invitation
  static const String createPendingDependent = '/guardian/pending-dependents';

  /// Get pending dependent invitations
  static const String getPendingDependents = '/guardian/pending-dependents';

  /// Delete pending dependent invitation
  static const String deletePendingDependent = '/guardian/pending-dependents';

  /// Generate QR code for dependent invitation
  static const String generateQR = '/guardian/generate-qr';

  /// Get QR invitation details
  static const String getQRInvitation = '/guardian/qr-invitation';

  /// Get pending QR invitations
  static const String getPendingQRInvitations =
      '/guardian/pending-qr-invitations';

  /// Approve QR invitation
  static const String approveQR = '/guardian/approve-qr';

  /// Reject QR invitation
  static const String rejectQR = '/guardian/reject-qr';

  /// Get my dependents list
  static const String getMyDependents = '/guardian/my-dependents';

  // ============================================================================
  // 👶 DEPENDENT ENDPOINTS
  // ============================================================================

  /// Scan QR code to connect with guardian
  static const String scanQR = '/dependent/scan-qr';

  /// Get my guardians list
  static const String getMyGuardians = '/dependent/my-guardians';

  /// Remove guardian relationship
  static const String removeGuardian = '/dependent/remove-guardian';

  // ============================================================================
  // 🤝 COLLABORATOR ENDPOINTS
  // ============================================================================

  /// Invite collaborator guardian
  static const String inviteCollaborator = '/guardian/invite-collaborator';

  /// Validate invitation token
  static const String validateInvitation = '/guardian/validate-invitation';

  /// Accept collaborator invitation
  static const String acceptInvitation = '/guardian/accept-invitation';

  /// Get collaborators for a dependent
  /// Usage: ${ApiEndpoints.getCollaborators}/{dependentId}/collaborators
  static const String getCollaborators = '/guardian/dependent';

  /// Get pending invitations for a dependent
  /// Usage: ${ApiEndpoints.getPendingInvitations}/{dependentId}/pending-invitations
  static const String getPendingInvitations = '/guardian/dependent';

  /// Revoke collaborator access
  /// Usage: ${ApiEndpoints.revokeCollaborator}/{relationshipId}
  static const String revokeCollaborator = '/guardian/collaborator';

  // ============================================================================
  // 🚨 EMERGENCY CONTACT ENDPOINTS - Personal
  // ============================================================================

  /// Get my personal emergency contacts
  static const String getMyEmergencyContacts = '/my-emergency-contacts';

  /// Create my personal emergency contact
  static const String createMyEmergencyContact = '/my-emergency-contacts';

  /// Update my personal emergency contact
  /// Usage: ${ApiEndpoints.updateMyEmergencyContact}/{contactId}
  static const String updateMyEmergencyContact = '/my-emergency-contacts';

  /// Delete my personal emergency contact
  /// Usage: ${ApiEndpoints.deleteMyEmergencyContact}/{contactId}
  static const String deleteMyEmergencyContact = '/my-emergency-contacts';

  /// Bulk import contacts from device
  static const String bulkImportContacts = '/my-emergency-contacts/bulk';

  // ============================================================================
  // 🚨 EMERGENCY CONTACT ENDPOINTS - Dependent
  // ============================================================================

  /// Get emergency contacts for a dependent
  /// Usage: ${ApiEndpoints.getDependentEmergencyContacts}/{dependentId}/emergency-contacts
  static const String getDependentEmergencyContacts = '/dependent';

  /// Create emergency contact for a dependent
  static const String createDependentEmergencyContact =
      '/dependent/emergency-contacts';

  /// Update emergency contact for a dependent
  /// Usage: ${ApiEndpoints.updateDependentEmergencyContact}/{contactId}
  static const String updateDependentEmergencyContact =
      '/dependent/emergency-contacts';

  /// Delete emergency contact for a dependent
  /// Usage: ${ApiEndpoints.deleteDependentEmergencyContact}/{contactId}
  static const String deleteDependentEmergencyContact =
      '/dependent/emergency-contacts';

  // ============================================================================
  // ⚙️ SAFETY SETTINGS ENDPOINTS (PER-DEPENDENT)
  // ============================================================================

  /// Guardian -> Dependent safety settings
  /// GET: ${ApiEndpoints.dependentSafetySettings}/{dependentId}/safety-settings
  /// PATCH: ${ApiEndpoints.dependentSafetySettings}/{dependentId}/safety-settings
  ///
  /// Primary guardians configure per-dependent safety features.
  /// Collaborator guardians can read the resolved settings.
  static const String dependentSafetySettings = '/guardian/dependents';

  /// Dependent -> Own resolved safety settings
  /// GET: ${ApiEndpoints.mySafetySettings}
  ///
  /// Dependents read their own safety settings (configured by primary guardian)
  static const String mySafetySettings = '/dependent/my-safety-settings';

  // ============================================================================
  // 🆘 SOS EVENT ENDPOINTS
  // ============================================================================

  /// Create SOS event (manual trigger or motion detection)
  static const String createSosEvent = '/sos/events';

  // ============================================================================
  // 👪 FAMILY SERVICE ENDPOINTS
  // ============================================================================

  /// Get family statistics
  static const String getFamilyStats = '/family/stats';

  // ============================================================================
  // 🖼️ DEPENDENT PROFILE PICTURE ENDPOINTS
  // ============================================================================

  /// Upload/Update profile picture for a dependent (Primary Guardian only)
  /// POST: ${ApiEndpoints.uploadDependentProfilePicture}/{dependentId}/profile-picture
  /// DELETE: ${ApiEndpoints.uploadDependentProfilePicture}/{dependentId}/profile-picture
  static const String uploadDependentProfilePicture = '/guardian/dependents';

  // ============================================================================
  // 📱 DEVICE MANAGEMENT ENDPOINTS
  // ============================================================================

  /// Register device for push notifications
  static const String deviceRegister = '/devices/register';

  /// Unregister device
  static const String deviceUnregister = '/devices/unregister';

  // ============================================================================
  // ⏱️ TIMEOUT CONFIGURATION
  // ============================================================================

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);

  // ============================================================================
  // 🔮 FUTURE/PLANNED ENDPOINTS (Commented out - add when needed)
  // ============================================================================

  // Permission endpoints (mostly client-side, but might add backend validation)
  // static const String verifyPermission = '/auth/verify-permission';

  // Additional endpoints can be added here as backend develops
}
