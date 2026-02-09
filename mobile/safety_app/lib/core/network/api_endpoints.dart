class ApiEndpoints {
  // ✅ Use your laptop's IP address for physical device
  // Change this to match your actual backend server IP
  static const String baseUrl = 'http://localhost:8000/api';
  //'http://192.168.21.102:8000/api';

  // For emulator testing, use: 'http://10.0.2.2:8000/api'
  // For localhost web testing, use: 'http://localhost:8000/api'

  // ============================================================================
  // 🔥 FIREBASE AUTHENTICATION
  // ============================================================================
  
  /// Complete registration with Firebase token
  /// This is the MAIN endpoint for new Firebase registration flow
  static const String completeFirebaseRegistration = '/auth/firebase/complete-registration';

  /// Firebase login — used after password reset when normal login fails
  /// Verifies Firebase token, finds user, syncs password, issues JWTs
  static const String firebaseLogin = '/auth/firebase/login';

  // ============================================================================
  // AUTH ENDPOINTS (EXISTING - KEEP THESE)
  // ============================================================================
  
  // Old phone verification (might deprecate later)
  static const String sendVerificationCode = '/auth/send-verification-code';
  static const String verifyPhone = '/auth/verify-phone';
  static const String checkPhone = '/auth/check-phone';
  static const String checkEmail = '/auth/check-email';
  static const String updatePassword = '/auth/update-password';
  
  // Old registration (replaced by Firebase flow)
  static const String register = '/auth/register';
  
  // Email Verification Endpoints (OLD system)
  static const String verifyEmail = '/auth/verify-email';
  static const String resendEmailOTP = '/auth/resend-email-otp';
  
  // Daily login & token management (STILL USED)
  static const String login = '/auth/login';
  static const String me = '/auth/me';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String logoutAll = '/auth/logout-all';

  // ✅ ADD THIS PROFILE ENDPOINT
  static const String updateProfile = '/auth/profile';

  // ✅ NEW: Profile Picture Endpoints
  static const String uploadProfilePicture = '/auth/profile/picture';
  static const String deleteProfilePicture = '/auth/profile/picture';
  // Role endpoints
  static const String getRoles = '/auth/roles';
  static const String selectRole = '/auth/select-role';

  // Guardian endpoints
  static const String createPendingDependent = '/guardian/pending-dependents';
  static const String getPendingDependents = '/guardian/pending-dependents';
  static const String deletePendingDependent = '/guardian/pending-dependents';
  static const String generateQR = '/guardian/generate-qr';
  static const String getQRInvitation = '/guardian/qr-invitation';
  static const String getPendingQRInvitations =
      '/guardian/pending-qr-invitations';
  static const String approveQR = '/guardian/approve-qr';
  static const String rejectQR = '/guardian/reject-qr';
  static const String getMyDependents = '/guardian/my-dependents';

  // ✅ Dependent endpoints
  static const String scanQR = '/dependent/scan-qr';
  static const String getMyGuardians = '/dependent/my-guardians';
  static const String removeGuardian = '/dependent/remove-guardian';

  // Email Verification Endpoints
  static const String verifyEmail = '/auth/verify-email';
  static const String resendEmailOTP = '/auth/resend-email-otp';

  // 🆕 Collaborator endpoints
  static const String inviteCollaborator = '/guardian/invite-collaborator';
  static const String validateInvitation = '/guardian/validate-invitation';
  static const String acceptInvitation = '/guardian/accept-invitation';
  // Either make it clear:
  static const String getCollaborators = '/guardian/dependent';

  // Or fully define:
  // static const String getCollaborators = '/guardian/dependent/{id}/collaborators';// /{id}/collaborators
  static const String getPendingInvitations =
      '/guardian/dependent'; // /{id}/pending-invitations
  static const String revokeCollaborator = '/guardian/collaborator'; // /{id}

  // Emergency Contact endpoints
  static const String getMyEmergencyContacts = '/my-emergency-contacts';
  static const String createMyEmergencyContact = '/my-emergency-contacts';
  static const String updateMyEmergencyContact =
      '/my-emergency-contacts'; // /{id}
  static const String deleteMyEmergencyContact =
      '/my-emergency-contacts'; // /{id}
  static const String bulkImportContacts = '/my-emergency-contacts/bulk';

  static const String getDependentEmergencyContacts =
      '/dependent'; // /{id}/emergency-contacts
  static const String createDependentEmergencyContact =
      '/dependent/emergency-contacts';
  static const String updateDependentEmergencyContact =
      '/dependent/emergency-contacts'; // /{id}
  static const String deleteDependentEmergencyContact =
      '/dependent/emergency-contacts'; // /{id}

  // ==================== SAFETY SETTINGS (PER-DEPENDENT) ====================
  //
  // Primary guardians configure per-dependent safety features. Dependents and
  // collaborator guardians read the resolved settings.
  //
  // Guardian -> Dependent safety settings:
  //   GET  /api/guardian/dependents/{id}/safety-settings
  //   PATCH  /api/guardian/dependents/{id}/safety-settings
  //
  // Dependent -> Own resolved safety settings:
  //   GET  /api/dependent/my-safety-settings
  static const String dependentSafetySettings = '/guardian/dependents';
  static const String mySafetySettings = '/dependent/my-safety-settings';

  // SOS Event endpoints (manual + motion)
  static const String createSosEvent = '/sos/events';
  // Other endpoints (add as needed)
  // Family Service endpoints
  static const String getFamilyStats =
      '/family/stats'; // If you create this endpoint
  // Note: Family service uses existing endpoints from other services

  // Permission endpoints (mostly client-side, but you might want backend validation)
  // static const String verifyPermission = '/auth/verify-permission'; // Future enhancement
  // static const String updateProfile = '/user/profile';
  // static const String uploadAvatar = '/user/avatar';

  // ==================== DEPENDENT PROFILE PICTURE ====================

  /// Upload/Update profile picture for a dependent (Primary Guardian only)
  /// POST /api/guardian/dependents/{dependent_id}/profile-picture
  static const String uploadDependentProfilePicture = '/guardian/dependents';

  static const String deviceRegister = '/devices/register';
  static const String deviceUnregister = '/devices/unregister';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}
