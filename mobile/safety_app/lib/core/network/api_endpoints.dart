class ApiEndpoints {
  // Use your laptop's IP address for physical device
  static const String baseUrl = 'http://localhost:8000/api';
  //static const String baseUrl = 'http://192.168.21.102:8000/api';

  // Auth endpoints
  static const String sendVerificationCode = '/auth/send-verification-code';
  static const String verifyPhone = '/auth/verify-phone';
  static const String checkPhone = '/auth/check-phone';
  static const String checkEmail = '/auth/check-email';
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String me = '/auth/me';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String logoutAll = '/auth/logout-all';

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

  // Dependent endpoints
  static const String scanQR = '/dependent/scan-qr';
  static const String getMyGuardians = '/dependent/my-guardians';
  // Email Verification Endpoints
  static const String verifyEmail = '/auth/verify-email';
  static const String resendEmailOTP = '/auth/resend-email-otp';

  // Other endpoints (add as needed)
  // static const String updateProfile = '/user/profile';
  // static const String uploadAvatar = '/user/avatar';
}
