class ApiEndpoints {
  // Use your laptop's IP address for physical device
  static const String baseUrl = 'http://localhost:8000/api';
  //static const String baseUrl = 'http://172.18.240.1:8000/api';

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

  // ============================================================================
  // 🔐 BIOMETRIC AUTHENTICATION (NEW)
  // ============================================================================
  
  /// Enable biometric authentication for current user
  /// Only available for guardian accounts
  static const String enableBiometric = '/auth/enable-biometric';
  
  /// Disable biometric authentication for current user
  static const String disableBiometric = '/auth/disable-biometric';

  // ============================================================================
  // ROLE ENDPOINTS
  // ============================================================================
  
  static const String getRoles = '/auth/roles';
  static const String selectRole = '/auth/select-role';

  // ============================================================================
  // GUARDIAN ENDPOINTS
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
  // DEPENDENT ENDPOINTS
  // ============================================================================
  
  static const String scanQR = '/dependent/scan-qr';
  static const String getMyGuardians = '/dependent/my-guardians';
  static const String removeGuardian = '/dependent/remove-guardian';

  // Other endpoints (add as needed)
  // static const String updateProfile = '/user/profile';
  // static const String uploadAvatar = '/user/avatar';
}