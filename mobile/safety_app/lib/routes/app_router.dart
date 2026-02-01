// lib/routes/app_router.dart (FIXED - Logout redirect issue resolved)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/navigation/role_navigation_guard.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:safety_app/features/account/screens/account_screen.dart';
import 'package:safety_app/features/account/screens/profile_edit_screen.dart';
import 'package:safety_app/features/auth/screens/login_screen.dart';
import 'package:safety_app/features/auth/screens/otp_verification_screen.dart';
import 'package:safety_app/features/auth/screens/registration_screen.dart';
import 'package:safety_app/features/auth/screens/email_verification_screen.dart';
import 'package:safety_app/features/home/family/screens/family_member_detail_screen.dart';
import 'package:safety_app/features/home/general_home_screen.dart';
import 'package:safety_app/features/onboarding/screens/lets_get_started_screen.dart';
import 'package:safety_app/features/auth/screens/phone_number_screen.dart';
import 'package:safety_app/features/intent/screens/role_intent_screen.dart';
import 'package:safety_app/features/dependent/screens/dependent_type_selection_screen.dart';
import 'package:safety_app/features/dependent/screens/scan_or_upload_qr_screen.dart';
import 'package:safety_app/features/guardian/screens/guardian_setup_choice_screen.dart';
import 'package:safety_app/features/guardian/screens/guardian_add_dependent_screen.dart';
import 'package:safety_app/features/guardian/screens/collaborator_join_screen.dart';
import 'package:safety_app/models/dependent_model.dart';
import 'package:safety_app/routes/router_notifier.dart';
import 'package:safety_app/routes/splash_screen.dart';

class AppRouter {
  // Route paths
  static const String splash = '/';
  static const String login = '/login';
  static const String letsGetStarted = '/lets-get-started';
  static const String phoneNumber = '/phone-number';
  static const String otpVerification = '/otp-verification';
  static const String registration = '/registration';
  static const String emailVerification = '/email-verification';
  static const String roleIntent = '/role-intent';
  static const String home = '/home';
  static const String account = '/account';
  static const String editProfile = '/account/edit-profile';

  // Role-based onboarding
  static const String personalOnboarding = '/personal-onboarding';
  static const String guardianSetup = '/guardian-setup';
  static const String guardianAddDependent = '/guardian-add-dependent';
  static const String guardianCollaborator = '/guardian-collaborator';
  static const String collaboratorJoin = '/collaborator-join';
  static const String dependentTypeSelection = '/dependent-type-selection';
  static const String dependentDetailScreen = '/dependent-detail';
  static const String scanQr = '/scan-qr';

  /// Create router with role-based navigation
  static GoRouter createRouter(WidgetRef ref) {
    return GoRouter(
      initialLocation: splash,
      refreshListenable: ref.read(routerNotifierProvider),

      redirect: (context, state) {
        final authState = ref.read(authStateProvider);
        final user = authState.value;
        final location = state.matchedLocation;

        print('🔀 Router redirect: $location');
        print(
          '👤 User state: ${user != null ? "Authenticated" : "Not authenticated"}',
        );

        // ✅ FIX 1: Handle splash screen redirect - always navigate away from splash
        if (location == splash) {
          print('📍 Redirecting from splash...');

          if (user == null) {
            print('📍 Splash → Login (no user)');
            return login;
          } else if (user.hasRole && user.currentRole != null) {
            print('📍 Splash → Home (has role: ${user.currentRole?.roleName})');
            return home;
          } else {
            print('📍 Splash → RoleIntent (no role)');
            return roleIntent;
          }
        }

        // ✅ FIX 2: Allow all auth screens without restriction
        const authScreens = [
          login,
          letsGetStarted,
          phoneNumber,
          otpVerification,
          registration,
          emailVerification,
        ];

        if (authScreens.any((path) => location.startsWith(path))) {
          print('✅ Allowing auth screen: $location');
          return null;
        }

        // ✅ FIX 3: CRITICAL - If not authenticated, redirect to login
        // This handles logout - when user becomes null, redirect immediately
        if (user == null) {
          print('❌ No user → Redirecting to Login');
          return login;
        }

        // ✅ FIX 4: Allow role-specific onboarding flows (these are part of setup)
        const onboardingFlows = [
          guardianSetup,
          guardianAddDependent,
          guardianCollaborator,
          collaboratorJoin,
          dependentTypeSelection,
          scanQr,
          personalOnboarding,
        ];

        if (onboardingFlows.any((path) => location.startsWith(path))) {
          print('✅ Allowing onboarding flow: $location');
          return null;
        }

        // ✅ FIX 5: If authenticated but no role, redirect to role selection
        if (!user.hasRole || user.currentRole == null) {
          if (location != roleIntent) {
            print('⚠️ No role → RoleIntent');
            return roleIntent;
          }
          print('✅ Already at RoleIntent');
          return null;
        }

        // ✅ FIX 6: Allow home and account screens for authenticated users with roles
        const allowedScreens = [
          home,
          account,
          editProfile,
          dependentDetailScreen,
        ];
        if (allowedScreens.any((path) => location.startsWith(path))) {
          print('✅ Allowing authenticated screen: $location');
          return null;
        }

        print('✅ No redirect needed');
        return null;
      },

      routes: [
        // ==================== AUTH FLOW ====================

        // Splash Screen
        GoRoute(
          path: splash,
          name: 'splash',
          pageBuilder: (context, state) =>
              const MaterialPage(child: SplashScreen(), fullscreenDialog: true),
        ),

        // Login Screen
        GoRoute(
          path: login,
          name: 'login',
          pageBuilder: (context, state) =>
              const MaterialPage(child: LoginScreen()),
        ),

        // Let's Get Started Screen
        GoRoute(
          path: letsGetStarted,
          name: 'letsGetStarted',
          pageBuilder: (context, state) =>
              const MaterialPage(child: LetsGetStartedScreen()),
        ),

        // Phone Number Screen
        GoRoute(
          path: phoneNumber,
          name: 'phoneNumber',
          pageBuilder: (context, state) =>
              const MaterialPage(child: PhoneNumberScreen()),
        ),

        // OTP Verification Screen (Phone)
        GoRoute(
          path: otpVerification,
          name: 'otpVerification',
          pageBuilder: (context, state) {
            final phoneNumber = state.extra as String? ?? '';
            if (phoneNumber.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go(AppRouter.phoneNumber);
              });
            }
            return MaterialPage(
              child: OtpVerificationScreen(phoneNumber: phoneNumber),
            );
          },
        ),

        // Registration Screen
        GoRoute(
          path: registration,
          name: 'registration',
          pageBuilder: (context, state) {
            final phoneNumber = state.extra as String? ?? '';
            if (phoneNumber.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go(AppRouter.phoneNumber);
              });
            }
            return MaterialPage(
              child: RegistrationScreen(phoneNumber: phoneNumber),
            );
          },
        ),

        // Email Verification Screen
        GoRoute(
          path: emailVerification,
          name: 'emailVerification',
          pageBuilder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final email = extra?['email'] as String? ?? '';
            return MaterialPage(child: EmailVerificationScreen(email: email));
          },
        ),

        // ==================== ROLE SELECTION ====================

        // Role Intent Screen
        GoRoute(
          path: roleIntent,
          name: 'roleIntent',
          pageBuilder: (context, state) =>
              const MaterialPage(child: RoleIntentScreen()),
        ),

        // ==================== ACCOUNT SCREENS ====================
        GoRoute(
          path: account,
          name: 'account',
          pageBuilder: (context, state) =>
              const MaterialPage(child: AccountScreen()),
        ),

        GoRoute(
          path: editProfile,
          name: 'editProfile',
          pageBuilder: (context, state) =>
              const MaterialPage(child: ProfileEditScreen()),
        ),

        // ==================== PERSONAL USER FLOW ====================

        // Personal Onboarding Screen
        GoRoute(
          path: personalOnboarding,
          name: 'personalOnboarding',
          pageBuilder: (context, state) =>
              const MaterialPage(child: Placeholder()),
        ),

        // ==================== GUARDIAN FLOW ====================

        // Guardian Setup Choice Screen
        GoRoute(
          path: guardianSetup,
          name: 'guardianSetup',
          pageBuilder: (context, state) =>
              const MaterialPage(child: GuardianSetupChoiceScreen()),
        ),

        // Guardian Add Dependent Screen
        GoRoute(
          path: guardianAddDependent,
          name: 'guardianAddDependent',
          pageBuilder: (context, state) =>
              const MaterialPage(child: GuardianAddDependentScreen()),
        ),

        // Collaborator Join Screen
        GoRoute(
          path: collaboratorJoin,
          name: 'collaboratorJoin',
          pageBuilder: (context, state) =>
              const MaterialPage(child: CollaboratorJoinScreen()),
        ),

        // ==================== DEPENDENT FLOW ====================

        // Dependent Type Selection Screen
        GoRoute(
          path: dependentTypeSelection,
          name: 'dependentTypeSelection',
          pageBuilder: (context, state) =>
              const MaterialPage(child: DependentTypeSelectionScreen()),
        ),

        // Scan or Upload QR Screen
        GoRoute(
          path: scanQr,
          name: 'scanQr',
          pageBuilder: (context, state) {
            final dependentType =
                state.extra as DependentType? ?? DependentType.child;
            return MaterialPage(
              child: ScanOrUploadQrScreen(dependentType: dependentType),
            );
          },
        ),

        // Dependent detail screen
        GoRoute(
          path: dependentDetailScreen,
          name: 'dependentDetailScreen',
          pageBuilder: (context, state) {
            final dependent = state.extra as DependentModel?;
            if (dependent == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go(AppRouter.home);
              });
              return const MaterialPage(
                child: Scaffold(body: SizedBox.shrink()),
              );
            }
            return MaterialPage(
              child: FamilyMemberDetailScreen(dependent: dependent),
            );
          },
        ),

        // ==================== HOME ====================

        // Home Screen (Role-based navigation handled within)
        GoRoute(
          path: home,
          name: 'home',
          pageBuilder: (context, state) =>
              const MaterialPage(child: GeneralHomeScreen()),
        ),
      ],

      // Error handler
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Page not found',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('${state.uri}'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(home),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
