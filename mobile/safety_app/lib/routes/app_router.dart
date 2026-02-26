// lib/routes/app_router.dart
// ✅ MERGED: Combines Firebase auth flow with role-based navigation
// lib/routes/app_router.dart
// ✅ MERGED: Combines Firebase auth flow with role-based navigation
// ✅ NEW: Dependent voice registration gate — dependents must register voice once before home

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
import 'package:safety_app/features/home/sos/screens/sos_alert_detail_screen.dart';
import 'package:safety_app/features/notifications/screens/notification_list_screen.dart';
import 'package:safety_app/features/onboarding/screens/lets_get_started_screen.dart';
import 'package:safety_app/features/auth/screens/phone_number_screen.dart';
import 'package:safety_app/features/intent/screens/role_intent_screen.dart';
import 'package:safety_app/features/dependent/screens/dependent_type_selection_screen.dart';
import 'package:safety_app/features/dependent/screens/scan_or_upload_qr_screen.dart';
import 'package:safety_app/features/guardian/screens/guardian_setup_choice_screen.dart';
import 'package:safety_app/features/guardian/screens/guardian_add_dependent_screen.dart';
import 'package:safety_app/features/guardian/screens/collaborator_join_screen.dart';
import 'package:safety_app/features/voice_activation/screens/voice_registration_screen.dart';
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

  // SOS Routes
  static const String sosDetail = '/sos/detail';

  // ✅ NEW: Voice registration gate for dependents
  static const String voiceRegistration = '/voice-registration';

  /// Returns true if the user has a dependent-type role.
  /// Backend returns 'child' or 'elderly' — both require the voice gate.
  static bool _isDependent(dynamic user) {
    final roleName =
        user?.currentRole?.roleName?.toString().toLowerCase() ?? '';
    return roleName == 'child' || roleName == 'elderly';
  }

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
        if (authState.isLoading) {
          print('⏳ Auth still loading — holding at splash, no redirect');
          return null;
        }

        final user = authState.value;
        print(
          '👤 User state: ${user != null ? "Authenticated" : "Not authenticated"}',
        );

        // ==================== SPLASH ====================
        if (location == splash) {
          print('📍 Redirecting from splash...');

          if (user == null) {
            print('📍 Splash → Login (no user)');
            return login;
          } else if (user.hasRole && user.currentRole != null) {
            // ✅ NEW: Dependent voice gate check at splash redirect
            if (_isDependent(user) && !(user.isVoiceRegistered ?? false)) {
              print(
                '📍 Splash → VoiceRegistration (dependent, voice not registered)',
              );
              return voiceRegistration;
            }
            print('📍 Splash → Home (has role: ${user.currentRole?.roleName})');
            return home;
          } else {
            print('📍 Splash → RoleIntent (no role)');
            return roleIntent;
          }
        }

        // ==================== AUTH SCREENS ====================
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
        if (user == null) {
          print('❌ No user → Redirecting to Login');
          return login;
        }

        // ==================== VOICE REGISTRATION GATE ====================
        // Allow the voice registration screen itself to render (no loop).
        if (location == voiceRegistration) {
          // Once voice is registered, push them to home instead.
          if (user.isVoiceRegistered ?? false) {
            print('✅ Voice already registered → Home');
            return home;
          }
          print('✅ Allowing voice registration screen');
          return null;
        }

        // ✅ NEW: If user is a dependent with an unregistered voice, block
        // navigation to any protected screen and send them to voice registration.
        if (_isDependent(user) && !(user.isVoiceRegistered ?? false)) {
          print('🎤 Dependent voice not registered → VoiceRegistration');
          return voiceRegistration;
        }

        // ✅ FIX 4: Allow role-specific onboarding flows
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

        // ✅ FIX 6: Allow authenticated screens
        const allowedScreens = [
          home,
          account,
          editProfile,
          dependentDetailScreen,
          sosDetail,
        ];
        if (allowedScreens.any((path) => location.startsWith(path))) {
          print('✅ Allowing authenticated screen: $location');
          return null;
        }

        print('✅ No redirect needed');
        return null;
      },

      routes: [
   // ==================== SOS ROUTES ====================
GoRoute(
  path: sosDetail,
  name: 'sosDetail',
  pageBuilder: (context, state) {
    final extra = state.extra as Map<String, dynamic>?;
    
    debugPrint('🔍 [AppRouter] ========== ROUTER CALLED ==========');
    debugPrint('🔍 [AppRouter] Extra data: $extra');
    
    if (extra != null) {
      // Check for voice URL specifically
      final voiceUrl = extra['voiceMessageUrl']?.toString();
      debugPrint('🔊 [AppRouter] Voice URL from extra: "$voiceUrl"');
      debugPrint('🔊 [AppRouter] Voice URL exists: ${voiceUrl != null && voiceUrl.isNotEmpty}');
      
      // Handle eventId
      int eventId;
      if (extra['eventId'] is int) {
        eventId = extra['eventId'] as int;
      } else {
        eventId = int.tryParse(extra['eventId']?.toString() ?? '0') ?? 0;
      }

      // Handle location
      double? latitude;
      if (extra['latitude'] != null) {
        latitude = double.tryParse(extra['latitude'].toString());
      }

      double? longitude;
      if (extra['longitude'] != null) {
        longitude = double.tryParse(extra['longitude'].toString());
      }

      final alertData = SosAlertData(
        dependentName: extra['dependentName']?.toString() ?? 'Unknown',
        dependentAvatarUrl: extra['dependentAvatarUrl']?.toString() ?? '',
        triggeredAt: extra['triggeredAt'] is DateTime 
            ? extra['triggeredAt'] as DateTime 
            : DateTime.now(),
        triggerType: extra['triggerType'] ?? SosTriggerType.manual,
        sosEventId: eventId,
        latitude: latitude,
        longitude: longitude,
        voiceMessageUrl: voiceUrl,
      );
      
      debugPrint('✅ [AppRouter] Created SosAlertData with voice: ${alertData.voiceMessageUrl}');
      
      return MaterialPage(
        key: state.pageKey,
        child: SosAlertDetailScreen(
          alert: alertData,
        ),
      );
    }
    
    debugPrint('⚠️ [AppRouter] No extra data, using fallback');
    
    final eventIdFromQuery = int.tryParse(
        state.uri.queryParameters['eventId']?.toString() ?? '0'
    ) ?? 0;
    
    return MaterialPage(
      key: state.pageKey,
      child: SosAlertDetailScreen(
        alert: SosAlertData(
          dependentName: 'Loading...',
          dependentAvatarUrl: '',
          triggeredAt: DateTime.now(),
          triggerType: SosTriggerType.manual,
          sosEventId: eventIdFromQuery,
        ),
      ),
    );
  },
),
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

        // ✅ OTP Verification Screen (Phone) - FRIEND'S VERSION
        // Passes verificationId from Firebase
        // ✅ OTP Verification Screen (Phone) - FRIEND'S VERSION
        // Passes verificationId from Firebase
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

        // ✅ Email Verification Screen - FRIEND'S VERSION
        // Passes phoneNumber (NOT email) parameter
        // ✅ Email Verification Screen - FRIEND'S VERSION
        // Passes phoneNumber (NOT email) parameter
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

        // ✅ Registration Screen - FRIEND'S VERSION
        // Passes phoneNumber, email, and password
        // ✅ Registration Screen - FRIEND'S VERSION
        // Passes phoneNumber, email, and password
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

        // ==================== VOICE REGISTRATION (DEPENDENT GATE) ====================
        // ✅ NEW: Shown once to dependents who haven't registered their voice.
        // After successful registration, updateVoiceRegistrationStatus(true) is
        // called in AuthStateNotifier which triggers a router refresh → home.
        // The back button / system back is intentionally blocked via WillPopScope
        // inside VoiceRegistrationScreen so the dependent cannot skip this step.
        GoRoute(
          path: voiceRegistration,
          name: 'voiceRegistration',
          pageBuilder: (context, state) => const MaterialPage(
            child: VoiceRegistrationScreen(),
            // Prevent swipe-back on iOS from bypassing the gate
            fullscreenDialog: true,
          ),
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
