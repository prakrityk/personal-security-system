// lib/core/network/api_endpoints.dart
// Complete API endpoints - Firebase, Biometric, and Traditional Auth

class ApiEndpoints {
  // ============================================================================
  // BASE URL CONFIGURATION
  // ============================================================================

  // ✅ CURRENT NGROK URL (updated)
  static const String baseUrl = 'https://isaias-nonfermented-odorously.ngrok-free.dev/api';
                                // https://isaias-nonfermented-odorously.ngrok-free.dev
  
  // ⚠️ IMPORTANT: Update this URL whenever you restart ngrok!
  // The URL changes every time you run 'ngrok http 8000'
  
  // Other options (commented out for reference):
  // static const String baseUrl = 'http://localhost:8000/api';  // For web testing
  // static const String baseUrl = 'http://10.0.2.2:8000/api';   // For Android emulator
  // static const String baseUrl = 'http://192.168.1.x:8000/api'; // For physical device on same WiFi

  // ============================================================================
  // 🔥 FIREBASE AUTHENTICATION ENDPOINTS
  // ============================================================================

  /// Complete registration with Firebase token
  static const String completeFirebaseRegistration =
      '/auth/firebase/complete-registration';

  /// Firebase login — used after password reset when normal login fails
  static const String firebaseLogin = '/auth/firebase/login';

  // ============================================================================
  // 🔐 BIOMETRIC AUTHENTICATION ENDPOINTS
  // ============================================================================

  /// Enable biometric authentication for current user
  static const String enableBiometric = '/auth/enable-biometric';

  // ============================================================================
  // 📱 PHONE VERIFICATION ENDPOINTS
  // ============================================================================

  static const String sendVerificationCode = '/auth/send-verification-code';
  static const String verifyPhone = '/auth/verify-phone';
  static const String checkPhone = '/auth/check-phone';

  // ============================================================================
  // 📧 EMAIL VERIFICATION ENDPOINTS
  // ============================================================================

  static const String checkEmail = '/auth/check-email';
  static const String verifyEmail = '/auth/verify-email';
  static const String resendEmailOTP = '/auth/resend-email-otp';

  // ============================================================================
  // 🔑 AUTHENTICATION ENDPOINTS
  // ============================================================================

  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String me = '/auth/me';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String logoutAll = '/auth/logout-all';
  static const String updatePassword = '/auth/update-password';

  // ============================================================================
  // 👤 PROFILE MANAGEMENT ENDPOINTS
  // ============================================================================

  static const String updateProfile = '/auth/profile';
  static const String uploadProfilePicture = '/auth/profile/picture';
  static const String deleteProfilePicture = '/auth/profile/picture';

  // ============================================================================
  // 🎭 ROLE MANAGEMENT ENDPOINTS
  // ============================================================================

  static const String getRoles = '/auth/roles';
  static const String selectRole = '/auth/select-role';

  // ============================================================================
  // 👨‍👩‍👧‍👦 GUARDIAN ENDPOINTS
  // ============================================================================

  static const String createPendingDependent = '/guardian/pending-dependents';
  static const String getPendingDependents = '/guardian/pending-dependents';
  static const String deletePendingDependent = '/guardian/pending-dependents';
  static const String generateQR = '/guardian/generate-qr';
  static const String getQRInvitation = '/guardian/qr-invitation';
  static const String getPendingQRInvitations = '/guardian/pending-qr-invitations';
  static const String approveQR = '/guardian/approve-qr';
  static const String rejectQR = '/guardian/reject-qr';
  static const String getMyDependents = '/guardian/my-dependents';

  // ============================================================================
  // 👶 DEPENDENT ENDPOINTS
  // ============================================================================

  static const String scanQR = '/dependent/scan-qr';
  static const String getMyGuardians = '/dependent/my-guardians';
  static const String removeGuardian = '/dependent/remove-guardian';

  // ============================================================================
  // 🤝 COLLABORATOR ENDPOINTS
  // ============================================================================

  static const String inviteCollaborator = '/guardian/invite-collaborator';
  static const String validateInvitation = '/guardian/validate-invitation';
  static const String acceptInvitation = '/guardian/accept-invitation';
  static const String getCollaborators = '/guardian/dependent';
  static const String getPendingInvitations = '/guardian/dependent';
  static const String revokeCollaborator = '/guardian/collaborator';

  // ============================================================================
  // 🚨 EMERGENCY CONTACT ENDPOINTS - Personal
  // ============================================================================

  static const String getMyEmergencyContacts = '/my-emergency-contacts';
  static const String createMyEmergencyContact = '/my-emergency-contacts';
  static const String updateMyEmergencyContact = '/my-emergency-contacts';
  static const String deleteMyEmergencyContact = '/my-emergency-contacts';
  static const String bulkImportContacts = '/my-emergency-contacts/bulk';

  // ============================================================================
  // 🚨 EMERGENCY CONTACT ENDPOINTS - Dependent
  // ============================================================================

  static const String getDependentEmergencyContacts = '/dependent';
  static const String createDependentEmergencyContact =
      '/dependent/emergency-contacts';
  static const String updateDependentEmergencyContact =
      '/dependent/emergency-contacts';
  static const String deleteDependentEmergencyContact =
      '/dependent/emergency-contacts';

  // ============================================================================
  // ⚙️ SAFETY SETTINGS ENDPOINTS
  // ============================================================================

  static const String dependentSafetySettings = '/guardian/dependents';
  static const String mySafetySettings = '/dependent/my-safety-settings';

  // ============================================================================
  // 🆘 SOS EVENT ENDPOINTS
  // ============================================================================

  /// Create SOS event with voice (unified endpoint)
  static const String createSosEvent = '/sos/with-voice';

  // ============================================================================
  // 👪 FAMILY SERVICE ENDPOINTS
  // ============================================================================

  static const String getFamilyStats = '/family/stats';

  // ============================================================================
  // 🖼️ DEPENDENT PROFILE PICTURE ENDPOINTS
  // ============================================================================

  static const String uploadDependentProfilePicture = '/guardian/dependents';

  // ============================================================================
  // 📱 DEVICE MANAGEMENT ENDPOINTS
  // ============================================================================

  static const String deviceRegister = '/devices/register';
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

  // for voice registration
  static const String voiceRegister ='/voice/voice/register';
  static const String voiceverify = '/voice/voice/verify-sos';
}