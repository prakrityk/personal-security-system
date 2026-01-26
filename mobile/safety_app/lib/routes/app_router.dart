import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/features/auth/screens/login_screen.dart';
import 'package:safety_app/features/auth/screens/otp_verification_screen.dart';
import 'package:safety_app/features/auth/screens/registration_screen.dart';
import 'package:safety_app/features/home/general_home_screen.dart';
import 'package:safety_app/features/onboarding/screens/lets_get_started_screen.dart';
import 'package:safety_app/features/auth/screens/phone_number_screen.dart';
import 'package:safety_app/features/intent/screens/role_intent_screen.dart';
import 'package:safety_app/features/dependent/screens/dependent_type_selection_screen.dart';
import 'package:safety_app/features/dependent/screens/scan_or_upload_qr_screen.dart';
import 'package:safety_app/features/guardian/screens/guardian_setup_choice_screen.dart';
import 'package:safety_app/features/guardian/screens/guardian_add_dependent_screen.dart';
import 'package:safety_app/routes/splash_screen.dart';

class AppRouter {
  // Route paths
  static const String splash = '/';
  static const String login = '/login';
  static const String letsGetStarted = '/lets-get-started';
  static const String phoneNumber = '/phone-number';
  static const String otpVerification = '/otp-verification';
  static const String registration = '/registration';
  static const String roleIntent = '/role-intent';
  static const String home = '/home';

  // Role-based onboarding
  static const String personalOnboarding = '/personal-onboarding';
  static const String guardianSetup = '/guardian-setup';
  static const String guardianAddDependent = '/guardian-add-dependent';
  static const String guardianCollaborator = '/guardian-collaborator';
  static const String dependentTypeSelection = '/dependent-type-selection';
  static const String scanQr = '/scan-qr';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    redirect: (context, state) {
      return null; // No global redirects for now
    },
    routes: [
      // ==================== AUTH FLOW ====================

      // Splash Screen
      GoRoute(
        path: splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Login Screen
      GoRoute(
        path: login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Let's Get Started Screen
      GoRoute(
        path: letsGetStarted,
        name: 'letsGetStarted',
        builder: (context, state) => const LetsGetStartedScreen(),
      ),

      // Phone Number Screen
      GoRoute(
        path: phoneNumber,
        name: 'phoneNumber',
        builder: (context, state) => const PhoneNumberScreen(),
      ),

      // OTP Verification Screen
      GoRoute(
        path: otpVerification,
        name: 'otpVerification',
        builder: (context, state) {
          final phoneNumber = state.extra as String;
          return OtpVerificationScreen(phoneNumber: phoneNumber);
        },
      ),

      // Registration Screen
      GoRoute(
        path: registration,
        name: 'registration',
        builder: (context, state) {
          final phoneNumber = state.extra as String;
          return RegistrationScreen(phoneNumber: phoneNumber);
        },
      ),

      // ==================== ROLE SELECTION ====================

      // Role Intent Screen
      GoRoute(
        path: roleIntent,
        name: 'roleIntent',
        builder: (context, state) => const RoleIntentScreen(),
      ),

      // ==================== PERSONAL USER FLOW ====================

      // Personal Onboarding Screen
      GoRoute(
        path: personalOnboarding,
        name: 'personalOnboarding',
        builder: (context, state) => const PersonalOnboardingScreen(),
      ),

      // ==================== GUARDIAN FLOW ====================

      // Guardian Setup Choice Screen
      GoRoute(
        path: guardianSetup,
        name: 'guardianSetup',
        builder: (context, state) => const GuardianSetupChoiceScreen(),
      ),

      // Guardian Add Dependent Screen
      GoRoute(
        path: guardianAddDependent,
        name: 'guardianAddDependent',
        builder: (context, state) => const GuardianAddDependentScreen(),
      ),

      // Guardian Collaborator Link Screen
      GoRoute(
        path: guardianCollaborator,
        name: 'guardianCollaborator',
        builder: (context, state) => const GuardianCollaboratorLinkScreen(),
      ),

      // ==================== DEPENDENT FLOW ====================

      // Dependent Type Selection Screen
      GoRoute(
        path: dependentTypeSelection,
        name: 'dependentTypeSelection',
        builder: (context, state) => const DependentTypeSelectionScreen(),
      ),

      // Scan or Upload QR Screen
      GoRoute(
        path: scanQr,
        name: 'scanQr',
        builder: (context, state) {
          final dependentType = state.extra as DependentType;
          return ScanOrUploadQrScreen(dependentType: dependentType);
        },
      ),

      // ==================== HOME ====================

      // Home Screen
      GoRoute(
        path: home,
        name: 'home',
        builder: (context, state) => const GeneralHomeScreen(),
      ),
    ],

    // Error handler
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page not found: ${state.uri}'))),
  );
}
