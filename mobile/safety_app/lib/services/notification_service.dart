import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_endpoints.dart';
import '../core/network/dio_client.dart';

// ==============================
// BACKGROUND MESSAGE HANDLER
// ==============================
// MUST be top-level function (outside class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.setupFlutterNotifications();
  await NotificationService.showNotification(message);
  debugPrint('🔔 Background message handled: ${message.notification?.title}');
}

class NotificationService {
  // ==============================
  // SINGLETON PATTERN
  // ==============================
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  // ==============================
  // CORE INSTANCES
  // ==============================
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final DioClient _dioClient = DioClient();

  static bool _isFlutterLocalNotificationsInitialized = false;

  static const String _tokenKey = 'fcm_token';
  static const String _tokenSentKey = 'fcm_token_sent';

  // ==============================
  // CHANNEL IDS - Match backend exactly
  // ==============================
  static const String channelSosAlerts = 'sos_alerts';
  static const String channelLocationTracking = 'location_tracking';
  static const String channelSecurityUpdates = 'security_updates';
  static const String channelAppSystem = 'app_system';

  // ==============================
  // MAIN INITIALIZATION
  // ==============================
  static Future<void> init() async {
    try {
      debugPrint('📱 Initializing NotificationService');

      // 1. Set background message handler
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // 2. Request permissions
      await _requestPermission();

      // 3. Setup notification channels and local notifications
      await setupFlutterNotifications();

      // 4. Setup message handlers for different app states
      await _setupMessageHandlers();

      // 5. Get and save FCM token
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenLocally(token);
        debugPrint('🔥 FCM Token: $token');
      }

      // 6. Setup token refresh listener
      _setupTokenRefreshListener();

      debugPrint('✅ NotificationService initialized successfully');
    } catch (e, st) {
      debugPrint('❌ NotificationService init failed: $e');
      debugPrint('$st');
    }
  }

  // ==============================
  // PERMISSION HANDLING
  // ==============================
  static Future<void> _requestPermission() async {
    // Request FCM permissions (iOS and some Android versions)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    debugPrint('📋 FCM Permission: ${settings.authorizationStatus}');

    // Request Android 13+ runtime notification permission
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (status.isDenied || status.isRestricted) {
        final result = await Permission.notification.request();
        debugPrint('📋 Android Notification Permission: $result');
      }
    }

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('⚠️ Notification permission not granted');
    }
  }

  // ==============================
  // LOCAL NOTIFICATIONS + CHANNELS
  // ==============================
  static Future<void> setupFlutterNotifications() async {
    if (_isFlutterLocalNotificationsInitialized) return;

    // Initialize local notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channels
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android != null) {
      await _createChannels(android);
    }

    _isFlutterLocalNotificationsInitialized = true;
    debugPrint('✅ Flutter Local Notifications initialized');
  }

  static Future<void> _createChannels(
    AndroidFlutterLocalNotificationsPlugin plugin,
  ) async {
    // 1. SOS Emergency Alerts (MAX priority)
    await plugin.createNotificationChannel(
      AndroidNotificationChannel(
        channelSosAlerts,
        'SOS Emergency Alerts',
        description: 'Critical emergency SOS alerts',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
        showBadge: true,
      ),
    );

    // 2. Location & Evidence Tracking (LOW priority)
    await plugin.createNotificationChannel(
      const AndroidNotificationChannel(
        channelLocationTracking,
        'Location & Evidence Tracking',
        description: 'Live tracking and evidence recording',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );

    // 3. Security Status Updates (DEFAULT priority)
    await plugin.createNotificationChannel(
      AndroidNotificationChannel(
        channelSecurityUpdates,
        'Security Status Updates',
        description: 'Safety acknowledgements and warnings',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 200, 100, 200]),
      ),
    );

    // 4. System & App Alerts (LOW priority)
    await plugin.createNotificationChannel(
      const AndroidNotificationChannel(
        channelAppSystem,
        'System & App Alerts',
        description: 'Permissions and system alerts',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );

    debugPrint('✅ All notification channels created');
  }

  // ==============================
  // MESSAGE HANDLERS FOR DIFFERENT APP STATES
  // ==============================
  static Future<void> _setupMessageHandlers() async {
    // 1. FOREGROUND: Handle messages when app is open
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 Foreground notification received');
      debugPrint('   Title: ${message.notification?.title}');
      debugPrint('   Body: ${message.notification?.body}');
      debugPrint('   Data: ${message.data}');

      // ✅ CRITICAL: Display the notification
      showNotification(message);
    });

    // 2. BACKGROUND: Handle when app is in background and user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 Background message opened');
      debugPrint('   Title: ${message.notification?.title}');
      debugPrint('   Data: ${message.data}');
      _handleBackgroundMessage(message);
    });

    // 3. TERMINATED: Handle app launch from terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🔔 App opened from terminated state');
      _handleBackgroundMessage(initialMessage);
    }
  }

  // ==============================
  // DISPLAY NOTIFICATION
  // ==============================
  static Future<void> showNotification(RemoteMessage message) async {
    final title =
        message.notification?.title ?? message.data['title'] ?? '🚨 Alert';
    final body =
        message.notification?.body ??
        message.data['body'] ??
        'Emergency detected';
    final type = message.data['type'] ?? 'SOS_EVENT';
    final eventId = message.data['event_id']?.toString();

    debugPrint('📨 Showing notification: $title - $body');

    // Determine channel and priority based on type
    String channelId;
    Importance importance;
    Priority priority;

    switch (type) {
      case 'SOS_EVENT':
      case 'PANIC_MODE':
      case 'MOTION_DETECTION':
        channelId = channelSosAlerts;
        importance = Importance.max;
        priority = Priority.max;
        break;

      case 'SOS_ACKNOWLEDGED':
      case 'COUNTDOWN_WARNING':
      case 'SAFETY_STATUS':
        channelId = channelSecurityUpdates;
        importance = Importance.defaultImportance;
        priority = Priority.defaultPriority;
        break;

      case 'TRACKING_ACTIVE':
      case 'EVIDENCE_COLLECTION':
        channelId = channelLocationTracking;
        importance = Importance.low;
        priority = Priority.low;
        break;

      default:
        channelId = channelSecurityUpdates;
        importance = Importance.defaultImportance;
        priority = Priority.defaultPriority;
    }

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId,
          importance: importance,
          priority: priority,
          icon: '@mipmap/ic_launcher',
          showWhen: true,
          when: DateTime.now().millisecondsSinceEpoch,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: eventId,
    );

    debugPrint('✅ Notification displayed successfully');
  }

  // ==============================
  // NAVIGATION HANDLERS
  // ==============================
  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('👉 Notification tapped: ${response.payload}');
    // TODO: Navigate using GoRouter
    // Example: navigatorKey.currentState?.push(...)
  }

  static void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint('🔔 Handling background message navigation');
    // TODO: Navigate using GoRouter
    // Example: navigatorKey.currentState?.push(...)
  }

  // ==============================
  // TOKEN MANAGEMENT
  // ==============================
  static Future<void> _saveTokenLocally(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static void _setupTokenRefreshListener() {
    _messaging.onTokenRefresh.listen((token) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenSentKey);
      await prefs.setString(_tokenKey, token);
      debugPrint('🔄 FCM token refreshed: $token');
    });
  }

  static Future<bool> registerDeviceToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('❌ No FCM token available');
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final sentToken = prefs.getString(_tokenSentKey);

      // Skip if already sent this token
      if (sentToken == token) {
        debugPrint('✅ Token already registered');
        return true;
      }

      debugPrint('📤 Registering FCM token with backend...');

      final res = await _dioClient.post(
        ApiEndpoints.deviceRegister,
        data: {
          'fcm_token': token,
          'platform': Platform.isAndroid ? 'android' : 'ios',
        },
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        await prefs.setString(_tokenSentKey, token);
        debugPrint('✅ FCM token registered successfully');
        return true;
      } else {
        debugPrint('❌ Failed to register token: ${res.statusCode}');
        return false;
      }
    } catch (e, st) {
      debugPrint('❌ Error registering FCM token: $e');
      debugPrint('$st');
      return false;
    }
  }

  // ==============================
  // TOPIC SUBSCRIPTION (For broadcasts)
  // ==============================
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Error subscribing to topic $topic: $e');
    }
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic $topic: $e');
    }
  }
}
