import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert'; // ADD THIS for JSON encoding/decoding

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../core/network/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../features/home/sos/screens/sos_alert_detail_screen.dart';
import '../main.dart'; // Import navigatorKey

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
  static late final DioClient _dioClient;

  static bool _isFlutterLocalNotificationsInitialized = false;

  // Simple in-memory dedupe for rapid duplicate SOS notifications.
  static String? _lastNotificationKey;
  static DateTime? _lastNotificationAt;

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
      
      // Initialize DioClient
      _dioClient = DioClient();

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

      // 5. Check for token changes and register
      await _checkAndRegisterToken();

      // 6. Setup token refresh listener
      _setupTokenRefreshListener();

      debugPrint('✅ NotificationService initialized successfully');
    } catch (e, st) {
      debugPrint('❌ NotificationService init failed: $e');
      debugPrint('$st');
    }
  }

  // ==============================
  // TOKEN CHANGE DETECTION
  // ==============================
  static Future<void> _checkAndRegisterToken() async {
    try {
      final currentToken = await _messaging.getToken();
      if (currentToken == null) {
        debugPrint('❌ No FCM token available');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final oldToken = prefs.getString(_tokenKey);
      final sentToken = prefs.getString(_tokenSentKey);

      debugPrint('🔍 Token check:');
      debugPrint('   Current token: ${currentToken.substring(0, 20)}...');
      debugPrint('   Old token: ${oldToken?.substring(0, 20)}...');
      debugPrint('   Sent token: ${sentToken?.substring(0, 20)}...');

      // If token changed, delete old one from backend
      if (oldToken != null && oldToken != currentToken) {
        debugPrint('🔄 Token changed! Deleting old token...');
        await _deleteOldToken(oldToken);
      }

      // Save current token locally
      await prefs.setString(_tokenKey, currentToken);

      // Register if needed
      if (sentToken != currentToken) {
        await registerDeviceToken();
      } else {
        debugPrint('✅ Token already registered');
      }
    } catch (e) {
      debugPrint('❌ Error in token check: $e');
    }
  }

  static Future<void> _deleteOldToken(String oldToken) async {
    try {
      debugPrint('🗑️ Attempting to delete old token from backend...');
      
      // Try to delete the old token
      await _dioClient.post(
        '/api/devices/remove-token',
        data: {'fcm_token': oldToken},
      );
      
      debugPrint('✅ Old token deleted successfully');
      
      // Clear the sent flag so new token will be registered
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenSentKey);
      
    } catch (e) {
      // If it fails (token already expired, etc.), just log and continue
      debugPrint('⚠️ Could not delete old token (may already be expired): $e');
      
      // Still clear the sent flag
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenSentKey);
    }
  }

  // ==============================
  // PERMISSION HANDLING
  // ==============================
  static Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    debugPrint('📋 FCM Permission: ${settings.authorizationStatus}');

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
      onDidReceiveBackgroundNotificationResponse: _onNotificationTap,
    );

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
      showNotification(message);
    });

    // 2. BACKGROUND: Handle when app is in background and user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 Background message opened');
      debugPrint('   Title: ${message.notification?.title}');
      debugPrint('   Data: ${message.data}');
      _handleNotificationNavigation(message.data);
    });

    // 3. TERMINATED: Handle app launch from terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🔔 App opened from terminated state');
      _handleNotificationNavigation(initialMessage.data);
    }
  }

  // ==============================
  // NOTIFICATION TAP HANDLER
  // ==============================
  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('👉 Notification tapped from system tray: ${response.payload}');
    
    if (response.payload != null) {
      final eventId = int.tryParse(response.payload!);
      if (eventId != null) {
        // ✅ Retrieve the full stored data from SharedPreferences
        SharedPreferences.getInstance().then((prefs) {
          final storedData = prefs.getString('notification_data_$eventId');
          if (storedData != null) {
            try {
              final Map<String, dynamic> fullData = jsonDecode(storedData);
              debugPrint('📦 Retrieved full notification data for event $eventId: $fullData');
              _handleNotificationNavigation(fullData);
            } catch (e) {
              debugPrint('❌ Error parsing stored data: $e');
              _navigateToSosDetail(eventId: eventId);
            }
          } else {
            debugPrint('⚠️ No stored data found for event $eventId, using fallback');
            _navigateToSosDetail(eventId: eventId);
          }
        });
      }
    }
  }

  static void _handleNotificationNavigation(Map<String, dynamic> data) {
    debugPrint('🔔 ========== NOTIFICATION TAPPED ==========');
    debugPrint('🔔 Raw notification data: $data');
    
    // Check voice URL specifically
    final voiceMessageUrl = data['voice_message_url']?.toString();
    debugPrint('🔊 Voice URL from notification: "$voiceMessageUrl"');
    
    final type = data['type'];
    final eventId = data['event_id'] != null ? int.tryParse(data['event_id'].toString()) : null;
    
    // ✅ FIX: Get the actual dependent name, not the notification title
    final dependentName = data['dependent_name']?.toString() ?? 'Unknown';
    
    final lat = data['lat'] != null ? double.tryParse(data['lat'].toString()) : null;
    final lng = data['lng'] != null ? double.tryParse(data['lng'].toString()) : null;
    final triggerTypeStr = data['trigger_type']?.toString() ?? 'manual';
    
    debugPrint('📛 Dependent name from data: "$dependentName"');
    debugPrint('📍 Location: lat=$lat, lng=$lng');
    debugPrint('🎤 Voice URL present: ${voiceMessageUrl != null && voiceMessageUrl.isNotEmpty}');
    
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

    if ((type == 'SOS_EVENT' || type == 'MOTION_DETECTION') && eventId != null) {
      debugPrint('✅ Creating SosAlertData with voice URL: "$voiceMessageUrl"');
      debugPrint('✅ Dependent name: "$dependentName"');
      
      final alertData = SosAlertData(
        dependentName: dependentName,
        dependentAvatarUrl: '',
        triggeredAt: DateTime.now(),
        triggerType: triggerType,
        sosEventId: eventId,
        latitude: lat,
        longitude: lng,
        voiceMessageUrl: voiceMessageUrl,
      );
      
      _navigateToSosDetailWithData(alertData);
    } else {
      debugPrint('❌ Not a valid SOS notification: type=$type, eventId=$eventId');
    }
  }

  static void _navigateToSosDetail({required int eventId}) {
    debugPrint('🚀 Navigating to SosAlertDetailScreen with eventId: $eventId');
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => SosAlertDetailScreen(
          alert: SosAlertData(
            dependentName: 'Loading...',
            dependentAvatarUrl: '',
            triggeredAt: DateTime.now(),
            triggerType: SosTriggerType.manual,
            sosEventId: eventId,
          ),
        ),
      ),
    );
  }

  static void _navigateToSosDetailWithData(SosAlertData alertData) {
    debugPrint('🚀 Navigating to SosAlertDetailScreen with:');
    debugPrint('   dependentName: ${alertData.dependentName}');
    debugPrint('   eventId: ${alertData.sosEventId}');
    debugPrint('   voiceUrl: ${alertData.voiceMessageUrl}');
    debugPrint('   hasVoice: ${alertData.voiceMessageUrl != null && alertData.voiceMessageUrl!.isNotEmpty}');
    
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => SosAlertDetailScreen(
          alert: alertData,
        ),
      ),
    );
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

    // ✅ STORE the full notification data locally for later retrieval
    if (eventId != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('notification_data_$eventId', jsonEncode(message.data));
        debugPrint('💾 Stored full notification data for event $eventId');
      } catch (e) {
        debugPrint('⚠️ Failed to store notification data: $e');
      }
    }

    final dedupeKey = '$type:$eventId:$title:$body';
    final now = DateTime.now();
    if (_lastNotificationKey == dedupeKey &&
        _lastNotificationAt != null &&
        now.difference(_lastNotificationAt!).inSeconds < 2) {
      debugPrint('⏭️ Skipping duplicate notification for key: $dedupeKey');
      return;
    }
    _lastNotificationKey = dedupeKey;
    _lastNotificationAt = now;

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
      payload: eventId, // Store eventId in payload for navigation
    );

    debugPrint('✅ Notification displayed successfully');
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
      debugPrint('🔄 FCM token refreshed: ${token.substring(0, 20)}...');
      
      final prefs = await SharedPreferences.getInstance();
      final oldToken = prefs.getString(_tokenKey);
      
      // Delete old token if it exists
      if (oldToken != null && oldToken != token) {
        await _deleteOldToken(oldToken);
      }
      
      // Save new token
      await prefs.setString(_tokenKey, token);
      await prefs.remove(_tokenSentKey);
      
      // Register new token
      await registerDeviceToken();
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

      if (sentToken == token) {
        debugPrint('✅ Token already registered');
        return true;
      }

      debugPrint('📤 Registering FCM token with backend...');
      debugPrint('   Token: ${token.substring(0, 30)}...');

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
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        debugPrint('⚠️ Token rejected by backend (may be expired)');
        // Clear sent flag so we try again later
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tokenSentKey);
      } else {
        debugPrint('❌ Error registering FCM token: $e');
      }
      return false;
    } catch (e, st) {
      debugPrint('❌ Error registering FCM token: $e');
      debugPrint('$st');
      return false;
    }
  }

  // ==============================
  // TOPIC SUBSCRIPTION
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