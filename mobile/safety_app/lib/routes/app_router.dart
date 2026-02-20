// lib/routes/app_router.dart
// ✅ FIXED: Handles AsyncValue.loading() — does not redirect while auth is being restored

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:safety_app/features/account/screens/account_screen.dart';
import 'package:safety_app/features/account/screens/profile_edit_screen.dart';
import 'package:safety_app/features/auth/screens/login_screen.dart';
import 'package:safety_app/features/auth/screens/otp_verification_screen.dart';
import 'package:safety_app/features/auth/screens/registration_screen.dart';
import 'package:safety_app/features/auth/screens/email_verification_screen.dart';
import 'package:safety_app/features/home/family/screens/family_member_detail_screen.dart';
import 'package:safety_app/features/home/general_home_screen.dart';
import 'package:safety_app/features/notifications/screens/notification_list_screen.dart';
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
        final location = state.matchedLocation;

        print('🔀 Router redirect: $location');

        // ✅ CRITICAL FIX: While _loadUser() is still running (restoring session
        // from secure storage), authState is AsyncValue.loading().
        // Do NOT redirect during this time — just stay on splash and wait.
        // Without this check, the router sees user == null (because loading
        // hasn't finished yet) and immediately sends the user to /login even
        // though their token is perfectly valid in storage.
        if (authState.isLoading) {
          print('⏳ Auth still loading — holding at splash, no redirect');
          // Only hold on splash. If we're already past splash somehow, don't
          // interfere — let the screen stay where it is until loading resolves.
          if (location == splash) return null;
          return null;
        }

        final user = authState.value;
        print(
          '👤 User state: ${user != null ? "Authenticated" : "Not authenticated"}',
        );

        // ==================== SPLASH ====================
        // Now that loading is done, decide where to go from splash.
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

        // ==================== AUTH SCREENS ====================
        // Always allow these screens regardless of auth state.
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

        // ==================== NOT AUTHENTICATED ====================
        // If loading is done and there is genuinely no user, redirect to login.
        // This handles the explicit logout case.
        if (user == null) {
          print('❌ No user → Redirecting to Login');
          return login;
        }

        // ==================== ONBOARDING FLOWS ====================
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

        // ==================== NO ROLE YET ====================
        if (!user.hasRole || user.currentRole == null) {
          if (location == home) {
            print('⚠️ No role but allowing home navigation');
            return null;
          }
          if (location != roleIntent) {
            print('⚠️ No role → RoleIntent');
            return roleIntent;
          }
          print('✅ Already at RoleIntent');
          return null;
        }

        // ==================== AUTHENTICATED WITH ROLE ====================
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
        // ==================== NOTIFICATIONS ====================
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const NotificationListScreen(),
          ),
        ),

        // ==================== AUTH FLOW ====================

        GoRoute(
          path: splash,
          name: 'splash',
          pageBuilder: (context, state) =>
              const MaterialPage(child: SplashScreen(), fullscreenDialog: true),
        ),

        GoRoute(
          path: login,
          name: 'login',
          pageBuilder: (context, state) =>
              const MaterialPage(child: LoginScreen()),
        ),

        GoRoute(
          path: letsGetStarted,
          name: 'letsGetStarted',
          pageBuilder: (context, state) =>
              const MaterialPage(child: LetsGetStartedScreen()),
        ),

        GoRoute(
          path: phoneNumber,
          name: 'phoneNumber',
          pageBuilder: (context, state) =>
              const MaterialPage(child: PhoneNumberScreen()),
        ),

        GoRoute(
          path: otpVerification,
          name: 'otpVerification',
          pageBuilder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            final phoneNumber = extra['phoneNumber'] as String? ?? '';
            final verificationId = extra['verificationId'] as String? ?? '';

            if (phoneNumber.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go(AppRouter.phoneNumber);
              });
            }

            return MaterialPage(
              child: OtpVerificationScreen(
                phoneNumber: phoneNumber,
                verificationId: verificationId,
              ),
            );
          },
        ),

        GoRoute(
          path: emailVerification,
          name: 'emailVerification',
          pageBuilder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            final phoneNumber = extra['phoneNumber'] as String? ?? '';

            if (phoneNumber.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go(AppRouter.phoneNumber);
              });
            }

            return MaterialPage(
              child: EmailVerificationScreen(phoneNumber: phoneNumber),
            );
          },
        ),

        GoRoute(
          path: registration,
          name: 'registration',
          pageBuilder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            final phoneNumber = extra['phoneNumber'] as String? ?? '';
            final email = extra['email'] as String? ?? '';
            final password = extra['password'] as String? ?? '';

            if (phoneNumber.isEmpty || email.isEmpty || password.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go(AppRouter.phoneNumber);
              });
            }

            return MaterialPage(
              child: RegistrationScreen(
                phoneNumber: phoneNumber,
                email: email,
                password: password,
              ),
            );
          },
        ),

        // ==================== ROLE SELECTION ====================

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

        GoRoute(
          path: personalOnboarding,
          name: 'personalOnboarding',
          pageBuilder: (context, state) =>
              const MaterialPage(child: Placeholder()),
        ),

        // ==================== GUARDIAN FLOW ====================

        GoRoute(
          path: guardianSetup,
          name: 'guardianSetup',
          pageBuilder: (context, state) =>
              const MaterialPage(child: GuardianSetupChoiceScreen()),
        ),

        GoRoute(
          path: guardianAddDependent,
          name: 'guardianAddDependent',
          pageBuilder: (context, state) =>
              const MaterialPage(child: GuardianAddDependentScreen()),
        ),

        GoRoute(
          path: collaboratorJoin,
          name: 'collaboratorJoin',
          pageBuilder: (context, state) =>
              const MaterialPage(child: CollaboratorJoinScreen()),
        ),

        // ==================== DEPENDENT FLOW ====================

        GoRoute(
          path: dependentTypeSelection,
          name: 'dependentTypeSelection',
          pageBuilder: (context, state) =>
              const MaterialPage(child: DependentTypeSelectionScreen()),
        ),

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

        GoRoute(
          path: home,
          name: 'home',
          pageBuilder: (context, state) =>
              const MaterialPage(child: GeneralHomeScreen()),
        ),
      ],

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