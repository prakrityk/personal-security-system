// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:safety_app/core/theme/app_theme.dart';
import 'package:safety_app/routes/app_router.dart';
import 'package:safety_app/core/providers/theme_provider.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:safety_app/services/notification_service.dart';
import 'package:safety_app/services/motion_detection_service.dart';
import 'package:safety_app/services/dependent_safety_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// (Optional) GlobalKey for navigation if you decide to hook it up later.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 🔥 Initialize Firebase (CRITICAL - Must be done before anything else)
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized');

    // Initialize SharedPreferences
    final sharedPreferences = await SharedPreferences.getInstance();

    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const SOSApp(),
      ),
    );
  } catch (e, st) {
    debugPrint('❌ Error in main: $e');
    debugPrint('$st');
  }
}

class SOSApp extends ConsumerStatefulWidget {
  const SOSApp({super.key});

  @override
  ConsumerState<SOSApp> createState() => _SOSAppState();
}

class _SOSAppState extends ConsumerState<SOSApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    // Initialize router once
    _router = AppRouter.createRouter(ref);

    // Initialize notification service
    _initNotificationService();
  }

  Future<void> _initNotificationService() async {
    // Wait for app to fully initialize
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // ✅ Initialize NotificationService (handles permissions and foreground messages)
        await NotificationService.init();
        debugPrint('✅ NotificationService initialized in main.dart');

        // Handle initial notification (app opened from terminated state)
        final initialMessage = await FirebaseMessaging.instance
            .getInitialMessage();
        if (initialMessage != null && mounted) {
          debugPrint('🔔 App opened from terminated state via notification');
          _handleNotificationTap(initialMessage);
        }

        // Handle notification tap when app was in background
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          debugPrint('🔔 App opened from background via notification');
          if (mounted) {
            _handleNotificationTap(message);
          }
        });
      } catch (e, stack) {
        debugPrint('❌ Error initializing NotificationService: $e');
        debugPrint(stack.toString());
      }
    });
  }

  /// Navigate based on notification data
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;

    if (data.containsKey('event_id')) {
      final eventId = data['event_id'];
      debugPrint('📍 Navigating to SOS event: $eventId');
      _router.go('/sos/$eventId');
    } else if (data.containsKey('type')) {
      // Handle different notification types
      switch (data['type']) {
        case 'SOS_EVENT':
        case 'PANIC_MODE':
        case 'MOTION_DETECTION':
          _router.go('/sos');
          break;
        case 'GEOFENCE_ALERT':
          _router.go('/map');
          break;
        case 'SOS_ACKNOWLEDGED':
          _router.go('/sos');
          break;
        default:
          _router.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    // ✅ FIXED: Listen to auth changes in build method instead of initState
    ref.listen(authStateProvider, (previous, next) async {
      final user = next.value;
      final prefs = ref.read(sharedPreferencesProvider);

      // If the logged-in user is a dependent, always respect the guardian's
      // per-dependent settings from the backend.
      if (user != null && user.isDependent) {
        try {
          final safetyService = DependentSafetyService();
          final safety = await safetyService.getMySafetySettings();
          final motionEnabled = safety.motionDetection;

          await prefs.setBool('motion_detection_enabled', motionEnabled);

          if (motionEnabled) {
            debugPrint(
              '🎯 Dependent logged in - motion detection enabled by guardian, starting service',
            );
            MotionDetectionService.instance.start();
          } else {
            debugPrint(
              '🛑 Dependent logged in - motion detection disabled by guardian, stopping service',
            );
            MotionDetectionService.instance.stop();
          }
        } catch (e, st) {
          debugPrint(
            '❌ Failed to load dependent safety settings for motion detection: $e',
          );
          debugPrint(st.toString());
          // In case of failure, fall back to local preference below.
        }
      }

      final enabled = prefs.getBool('motion_detection_enabled') ?? false;

      if (user != null && enabled) {
        debugPrint(
          '🎯 User logged in and motion detection enabled - starting service',
        );
        MotionDetectionService.instance.start();
      } else {
        debugPrint(
          '🛑 User logged out or motion detection disabled - stopping service',
        );
        MotionDetectionService.instance.stop();
      }
    });

    // ✅ CRITICAL: Use MaterialApp.router to provide MaterialLocalizations
    return MaterialApp.router(
      title: 'SOS App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: _router,
      // Add navigatorKey for programmatic navigation
      // Note: With GoRouter, we typically use router.go() instead
    );
  }
}
