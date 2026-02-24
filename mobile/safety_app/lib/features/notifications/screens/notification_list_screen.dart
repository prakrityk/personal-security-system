// lib/features/notifications/screens/notification_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safety_app/core/providers/notification_provider.dart';
import 'package:safety_app/core/theme/app_colors.dart';
import 'package:safety_app/core/theme/app_text_styles.dart';
import 'package:safety_app/features/home/sos/screens/sos_alert_detail_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationState = ref.watch(notificationProvider);
    final notifications = notificationState.sortedNotifications;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          // Mark all as read
          if (notificationState.unreadCount > 0)
            TextButton.icon(
              onPressed: () {
                ref.read(notificationProvider.notifier).markAllAsRead();
              },
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark all read'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
              ),
            ),
          // Clear all
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                _showClearAllDialog(context, ref);
              },
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: notifications.isEmpty
          ? _buildEmptyState(isDark)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationCard(
                  notification: notification,
                  onTap: () => _handleNotificationTap(context, ref, notification),
                  onDelete: () => _handleDelete(ref, notification.id),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: isDark ? AppColors.darkOnSurface.withOpacity(0.3) : AppColors.lightOnSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: AppTextStyles.h3.copyWith(
              color: isDark ? AppColors.darkOnSurface.withOpacity(0.5) : AppColors.lightOnSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.darkOnSurface.withOpacity(0.5) : AppColors.lightOnSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(BuildContext context, WidgetRef ref, NotificationItem notification) {
    // Mark as read
    ref.read(notificationProvider.notifier).markAsRead(notification.id);

    // Navigate based on notification type
    if (notification.eventId != null) {
      // ✅ Use /sos/detail with extra data instead of /sos/18
      context.push('/sos/detail', extra: {
        'eventId': notification.eventId,
        'dependentName': notification.title?.replaceAll('SOS Alert from ', '') ?? 'Unknown',
        'triggeredAt': notification.timestamp,
        'triggerType': SosTriggerType.manual,
        'latitude': null, // Will be fetched from API if needed
        'longitude': null,
        'voiceMessageUrl': null,
      });
    } else {
      switch (notification.type) {
        case 'SOS_EVENT':
        case 'PANIC_MODE':
        case 'MOTION_DETECTION':
        case 'SOS_ACKNOWLEDGED':
          context.push('/sos');
          break;
        case 'TRACKING_ACTIVE':
        case 'EVIDENCE_COLLECTION':
          context.push('/map');
          break;
        default:
          context.push('/home');
      }
    }
  }

  void _handleDelete(WidgetRef ref, String id) {
    ref.read(notificationProvider.notifier).deleteNotification(id);
  }

  void _showClearAllDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(notificationProvider.notifier).clearAll();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.sosRed,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.sosRed,
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: notification.isRead
              ? (isDark ? AppColors.darkSurface : AppColors.lightSurface)
              : (isDark ? AppColors.darkSurface.withOpacity(0.8) : AppColors.lightSurface.withOpacity(0.8)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notification.isRead
                ? Colors.transparent
                : notification.color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: notification.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    notification.icon,
                    color: notification.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: notification.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Body
                      Text(
                        notification.body,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark
                              ? AppColors.darkOnSurface.withOpacity(0.7)
                              : AppColors.lightOnSurface.withOpacity(0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Timestamp
                      Text(
                        timeago.format(notification.timestamp),
                        style: AppTextStyles.caption.copyWith(
                          color: isDark
                              ? AppColors.darkOnSurface.withOpacity(0.5)
                              : AppColors.lightOnSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}