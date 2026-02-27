import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:safety_app/background/motion_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'package:safety_app/core/theme/app_theme.dart';
import 'package:safety_app/routes/app_router.dart';
import 'package:safety_app/core/providers/theme_provider.dart';
import 'package:safety_app/core/providers/auth_provider.dart';
import 'package:safety_app/services/notification_service.dart';
import 'package:safety_app/services/motion_detection_service.dart';
import 'package:safety_app/services/motion_detection_gate.dart';
import 'package:safety_app/services/native_back_tap_service.dart';
import 'package:safety_app/core/network/api_endpoints.dart';
import 'package:safety_app/features/home/sos/screens/sos_alert_detail_screen.dart';
import 'package:safety_app/core/network/dio_client.dart';
import 'package:safety_app/core/storage/secure_storage_service.dart';
import 'package:safety_app/core/providers/shared_providers.dart';

// ✅ Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 🔥 Background notification handler — MUST be top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.setupFlutterNotifications();
  await NotificationService.showNotification(message);
  debugPrint('🔔 Background message handled: ${message.notification?.title}');
}

/// Retries Firebase.initializeApp up to [maxAttempts] times.
/// The platform channel can be temporarily unavailable on cold start
/// due to a FlutterJNI detach/reattach race, so we back off and retry.
Future<void> _initializeFirebase({int maxAttempts = 5}) async {
  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase initialized (attempt $attempt)');
      return;
    } catch (e) {
      debugPrint('⚠️ Firebase init attempt $attempt failed: $e');
      if (attempt == maxAttempts) rethrow;
      // Exponential back-off: 300ms, 600ms, 900ms, 1200ms
      await Future.delayed(Duration(milliseconds: 300 * attempt));
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Wait for platform channels before touching Firebase.
  // The FlutterJNI detach/reattach race on cold start causes a brief
  // window where the pigeon channel is unavailable.
  await Future.delayed(const Duration(milliseconds: 500));

  try {
    await _initializeFirebase();
    debugPrint('✅ Platform channels ready');

    // ── 1. Save base URL (needed for killed-app SOS HTTP call) ──
    await NativeBackTapService.instance.saveBaseUrl(ApiEndpoints.baseUrl);
    debugPrint('✅ Backend base URL saved for killed-app SOS path');

    // ── 2. Load token from secure storage and persist to SharedPreferences
    //       so Kotlin can fire SOS even when the app is killed. ──
    try {
      final secureStorage = SecureStorageService();
      final token = await secureStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        await NativeBackTapService.instance.saveToken(token);
        debugPrint('✅ Token saved to SharedPreferences for native back-tap');
      } else {
        debugPrint('ℹ️ No token in secure storage at startup');
      }
    } catch (e) {
      debugPrint('⚠️ Could not load token for native service: $e');
    }

    // ── 3. Start NativeBackTapService immediately — it is ALWAYS ON.
    //       It does NOT depend on the motion toggle, login state, or
    //       any gate. The Kotlin foreground service will keep the sensor
    //       alive in background and handle SOS via HTTP when killed. ──
    await NativeBackTapService.instance.start();
    debugPrint('✅ NativeBackTapService started (always-on)');

    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      debugPrint('✅ Background message handler registered');
    }

    final sharedPreferences = await SharedPreferences.getInstance();

    // ── 4. Configure background motion detection service ──
    // Must be called once before the service is ever started.
    await initMotionBackgroundService();
    debugPrint('✅ Motion background service configured');

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

class _SOSAppState extends ConsumerState<SOSApp> with WidgetsBindingObserver {
  late final GoRouter _router;
  late final DioClient _dioClient;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _dioClient = DioClient();
    MotionDetectionService.instance.initialize(dioClient: _dioClient);

    _router = AppRouter.createRouter(ref);
    _initNotificationService();

    // ✅ FIXED: Session restore moved here from build() so it runs exactly
    // once, inside the ProviderScope, guaranteeing the override is applied.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authState = ref.read(authStateProvider);
      if (authState.value != null) {
        debugPrint('🎯 Session restored → evaluating motion gate');
        final prefs = ref.read(sharedPreferencesProvider);
        final user = authState.value;
        final gateUser = user != null
            ? GateUser(user.roles?.map((r) => r.roleName).toList() ?? [])
            : null;
        await MotionDetectionGate.instance.evaluate(prefs, gateUser);
      }
    });
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
          if (mounted) _handleNotificationTap(message);
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

    final type = data['type'];
    final eventId = data['event_id'] != null
        ? int.tryParse(data['event_id'].toString())
        : null;
    final dependentName = data['dependent_name']?.toString() ?? 'Unknown';
    final lat = data['lat'] != null
        ? double.tryParse(data['lat'].toString())
        : null;
    final lng = data['lng'] != null
        ? double.tryParse(data['lng'].toString())
        : null;
    final voiceMessageUrl = data['voice_message_url']?.toString();
    final triggerTypeStr = data['trigger_type']?.toString() ?? 'manual';

    if ((type == 'SOS_EVENT' || type == 'MOTION_DETECTION') &&
        eventId != null) {
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

      _router.push(
        '/sos/detail',
        extra: {
          'eventId': eventId,
          'dependentName': dependentName,
          'triggerType': triggerType,
          'latitude': lat,
          'longitude': lng,
          'voiceMessageUrl': voiceMessageUrl,
          'triggeredAt': DateTime.now(),
        },
      );
      return;
    }

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
    WidgetsBinding.instance.removeObserver(this);
    // ✅ Only dispose MotionDetectionService here.
    // NativeBackTapService is intentionally NOT disposed — it is always-on.
    MotionDetectionService.instance.dispose();
    super.dispose();
  }

  /// ── Lifecycle → update app_state in SharedPreferences for Kotlin ──
  /// NativeBackTapService needs this so the SOS POST body carries the
  /// correct app_state ("foreground" / "background" / "killed").
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground — sync token in case it was refreshed
        // while the app was backgrounded.
        NativeBackTapService.instance.saveAppState('foreground');
        _syncTokenToNativeService();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        NativeBackTapService.instance.saveAppState('background');
        break;
      case AppLifecycleState.detached:
        // Flutter engine detaching — Kotlin foreground service takes over.
        NativeBackTapService.instance.saveAppState('killed');
        break;
      default:
        break;
    }
  }

  /// Reads the current token from secure storage and pushes it to
  /// SharedPreferences so Kotlin always has the freshest token.
  Future<void> _syncTokenToNativeService() async {
    try {
      final authState = ref.read(authStateProvider);
      if (authState.value == null) return; // not logged in

      final secureStorage = SecureStorageService();
      final token = await secureStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        await NativeBackTapService.instance.saveToken(token);
        debugPrint('✅ Token synced to native service on resume');
      }
    } catch (e) {
      debugPrint('⚠️ Token sync on resume failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    // ── Auth state changes ──
    ref.listen(authStateProvider, (previous, next) async {
      final wasLoggedIn = previous?.value != null;
      final isLoggedIn = next.value != null;
      if (wasLoggedIn == isLoggedIn) return;

      final prefs = ref.read(sharedPreferencesProvider);

      if (isLoggedIn) {
        try {
          final secureStorage = SecureStorageService();
          final token = await secureStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            await NativeBackTapService.instance.saveToken(token);
            debugPrint('✅ Token saved after login for native back-tap');
          }
        } catch (e) {
          debugPrint('⚠️ Could not save token after login: $e');
        }

        debugPrint('🎯 Auth login detected → evaluating motion gate');
        final user = next.value;
        final gateUser = user != null
            ? GateUser(user.roles?.map((r) => r.roleName).toList() ?? [])
            : null;
        await MotionDetectionGate.instance.evaluate(prefs, gateUser);
      } else {
        await NativeBackTapService.instance.clearToken();
        debugPrint('✅ Token cleared from native service on logout');

        debugPrint('🛑 Auth logout → stopping MotionDetectionService');
        MotionDetectionService.instance.stop();

        await prefs.setBool(kMotionDetectionEnabled, false);
        await prefs.setBool(kRemoteMotionDetectionEnabled, false);
      }
    });

    // ✅ REMOVED: addPostFrameCallback that was here before.
    // It was re-registering on every rebuild, causing the provider
    // to be read in an inconsistent state. Moved to initState() above.

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
