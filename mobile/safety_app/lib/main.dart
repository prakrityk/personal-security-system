import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'package:safety_app/core/theme/app_theme.dart';
import 'package:safety_app/routes/app_router.dart';
import 'package:safety_app/core/providers/theme_provider.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:safety_app/services/notification_service.dart';
import 'package:safety_app/services/motion_detection_service.dart';
import 'package:safety_app/features/home/sos/screens/sos_alert_detail_screen.dart';
import 'package:safety_app/core/network/dio_client.dart'; // ADD THIS

// ✅ Global navigator key - EXPORTED for use in NotificationService
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 🔥 Background notification handler
/// ⚠️ MUST be top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // ⚠ Web does NOT support background handlers
  if (kIsWeb) return;

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService.setupFlutterNotifications();
  await NotificationService.showNotification(message);

  debugPrint('🔔 Background message handled: ${message.notification?.title}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 🔥 SINGLE Firebase initialization (Web-safe)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized');

    // ✅ FIX: Ensure platform channels are fully ready before proceeding
    await Future.delayed(const Duration(milliseconds: 300));
    debugPrint('✅ Platform channels ready');

    // 🔥 Register background handler (non-web only)
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      debugPrint('✅ Background message handler registered');
    }

    final sharedPreferences = await SharedPreferences.getInstance();

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
    debugPrint(st.toString());
  }
}

class SOSApp extends ConsumerStatefulWidget {
  const SOSApp({super.key});

  @override
  ConsumerState<SOSApp> createState() => _SOSAppState();
}

class _SOSAppState extends ConsumerState<SOSApp> {
  late final GoRouter _router;
  late final DioClient _dioClient; // ADD THIS

  @override
  void initState() {
    super.initState();
    
    // ✅ Initialize DioClient
    _dioClient = DioClient();
    
    // ✅ Initialize MotionDetectionService with DioClient
    MotionDetectionService.instance.initialize(dioClient: _dioClient);
    
    _router = AppRouter.createRouter(ref);
    _initNotificationService();
  }

  Future<void> _initNotificationService() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await NotificationService.init();
        debugPrint('✅ NotificationService initialized');

        final initialMessage = await FirebaseMessaging.instance
            .getInitialMessage();
        if (initialMessage != null && mounted) {
          _handleNotificationTap(initialMessage);
        }

        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          if (mounted) {
            _handleNotificationTap(message);
          }
        });
      } catch (e, st) {
        debugPrint('❌ Notification init error: $e');
        debugPrint(st.toString());
      }
    });
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    debugPrint('👉 Notification tapped with data: $data');

    // Extract data for SOS alert
    final type = data['type'];
    final eventId = data['event_id'] != null ? int.tryParse(data['event_id'].toString()) : null;
    final dependentName = data['dependent_name']?.toString() ?? 'Unknown';
    final lat = data['lat'] != null ? double.tryParse(data['lat'].toString()) : null;
    final lng = data['lng'] != null ? double.tryParse(data['lng'].toString()) : null;
    final voiceMessageUrl = data['voice_message_url']?.toString();
    final triggerTypeStr = data['trigger_type']?.toString() ?? 'manual';

    // Handle SOS alert navigation with full data
    if ((type == 'SOS_EVENT' || type == 'MOTION_DETECTION') && eventId != null) {
      // Convert trigger type
      SosTriggerType triggerType;
      switch (triggerTypeStr) {
        case 'motion':
          triggerType = SosTriggerType.motion;
          break;
        case 'voice':
          triggerType = SosTriggerType.voice;
          break;
        default:
          triggerType = SosTriggerType.manual;
      }

      // Navigate to detail screen with all available data
      _router.push('/sos/detail', extra: {
        'eventId': eventId,
        'dependentName': dependentName,
        'triggerType': triggerType,
        'latitude': lat,
        'longitude': lng,
        'voiceMessageUrl': voiceMessageUrl,
        'triggeredAt': DateTime.now(), // Will be refreshed from API
      });
      return;
    }

    // Fallback navigation based on type
    switch (type) {
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

  @override
  void dispose() {
    // ✅ Clean up MotionDetectionService
    MotionDetectionService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    ref.listen(authStateProvider, (previous, next) async {
      final user = next.value;
      final prefs = ref.read(sharedPreferencesProvider);
      final enabled = prefs.getBool('motion_detection_enabled') ?? false;

      if (user != null && enabled) {
        // ✅ Make sure service is initialized before starting
        if (!MotionDetectionService.instance.isRunning) {
          MotionDetectionService.instance.start();
        }
      } else {
        MotionDetectionService.instance.stop();
      }
    });

    return MaterialApp.router(
      title: 'SOS App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}