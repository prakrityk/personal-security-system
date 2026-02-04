// lib/core/providers/notification_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Notification data model
class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String? eventId;
  final String type;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? data;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.eventId,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.data,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? body,
    String? eventId,
    String? type,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      eventId: eventId ?? this.eventId,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }

  /// Create from RemoteMessage
  factory NotificationItem.fromRemoteMessage(RemoteMessage message) {
    return NotificationItem(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: message.notification?.title ?? message.data['title'] ?? '🚨 Alert',
      body: message.notification?.body ?? message.data['body'] ?? 'Emergency detected',
      eventId: message.data['event_id']?.toString(),
      type: message.data['type'] ?? 'SOS_EVENT',
      timestamp: DateTime.now(),
      isRead: false,
      data: message.data,
    );
  }

  /// Get icon based on notification type
  IconData get icon {
    switch (type) {
      case 'SOS_EVENT':
      case 'PANIC_MODE':
        return Icons.warning_amber_rounded;
      case 'MOTION_DETECTION':
        return Icons.sensors;
      case 'SOS_ACKNOWLEDGED':
        return Icons.check_circle_outline;
      case 'COUNTDOWN_WARNING':
        return Icons.timer;
      case 'SAFETY_STATUS':
        return Icons.shield_outlined;
      case 'TRACKING_ACTIVE':
        return Icons.my_location;
      case 'EVIDENCE_COLLECTION':
        return Icons.camera_alt_outlined;
      case 'PERMISSION_REQUIRED':
        return Icons.lock_outline;
      case 'BATTERY_WARNING':
        return Icons.battery_alert;
      default:
        return Icons.notifications;
    }
  }

  /// Get color based on notification type
  Color get color {
    switch (type) {
      case 'SOS_EVENT':
      case 'PANIC_MODE':
      case 'MOTION_DETECTION':
        return const Color(0xFFE74C3C); // Red for emergencies
      case 'SOS_ACKNOWLEDGED':
        return const Color(0xFF27AE60); // Green for acknowledgments
      case 'COUNTDOWN_WARNING':
        return const Color(0xFFF39C12); // Orange for warnings
      case 'SAFETY_STATUS':
        return const Color(0xFF3498DB); // Blue for status
      default:
        return const Color(0xFF95A5A6); // Gray for others
    }
  }
}

/// State class for notification management
class NotificationState {
  final List<NotificationItem> notifications;
  final bool isLoading;

  NotificationState({
    this.notifications = const [],
    this.isLoading = false,
  });

  NotificationState copyWith({
    List<NotificationItem>? notifications,
    bool? isLoading,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Get unread notification count
  int get unreadCount => notifications.where((n) => !n.isRead).length;

  /// Get notifications sorted by timestamp (newest first)
  List<NotificationItem> get sortedNotifications {
    final list = List<NotificationItem>.from(notifications);
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }
}

/// Notification provider
class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier() : super(NotificationState()) {
    _initializeListeners();
  }

  /// Initialize FCM message listeners
  void _initializeListeners() {
    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📬 Adding notification to list: ${message.notification?.title}');
      addNotification(NotificationItem.fromRemoteMessage(message));
    });

    // Listen for background message taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📬 Message opened from background');
      addNotification(NotificationItem.fromRemoteMessage(message));
      markAsRead(message.messageId ?? '');
    });

    // Check for initial message (app opened from terminated state)
    _checkInitialMessage();
  }

  Future<void> _checkInitialMessage() async {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('📬 App opened from notification (terminated state)');
      addNotification(NotificationItem.fromRemoteMessage(initialMessage));
      markAsRead(initialMessage.messageId ?? '');
    }
  }

  /// Add new notification
  void addNotification(NotificationItem notification) {
    // Check if notification already exists
    final exists = state.notifications.any((n) => n.id == notification.id);
    if (exists) {
      debugPrint('⚠️ Notification already exists: ${notification.id}');
      return;
    }

    state = state.copyWith(
      notifications: [...state.notifications, notification],
    );
    debugPrint('✅ Notification added. Total: ${state.notifications.length}, Unread: ${state.unreadCount}');
  }

  /// Mark notification as read
  void markAsRead(String id) {
    final notifications = state.notifications.map((n) {
      return n.id == id ? n.copyWith(isRead: true) : n;
    }).toList();

    state = state.copyWith(notifications: notifications);
    debugPrint('✅ Marked notification as read: $id');
  }

  /// Mark all notifications as read
  void markAllAsRead() {
    final notifications = state.notifications.map((n) {
      return n.copyWith(isRead: true);
    }).toList();

    state = state.copyWith(notifications: notifications);
    debugPrint('✅ Marked all notifications as read');
  }

  /// Delete notification
  void deleteNotification(String id) {
    final notifications = state.notifications.where((n) => n.id != id).toList();
    state = state.copyWith(notifications: notifications);
    debugPrint('✅ Deleted notification: $id');
  }

  /// Clear all notifications
  void clearAll() {
    state = state.copyWith(notifications: []);
    debugPrint('✅ Cleared all notifications');
  }

  /// Get notification by ID
  NotificationItem? getNotificationById(String id) {
    try {
      return state.notifications.firstWhere((n) => n.id == id);
    } catch (e) {
      return null;
    }
  }
}

/// Provider for notification state
final notificationProvider = StateNotifierProvider<NotificationNotifier, NotificationState>(
  (ref) => NotificationNotifier(),
);

/// Provider for unread notification count
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationProvider).unreadCount;
});