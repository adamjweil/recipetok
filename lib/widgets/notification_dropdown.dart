import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';

class NotificationDropdown extends StatelessWidget {
  final NotificationService _notificationService = NotificationService();
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  NotificationDropdown({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (_userId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<List<AppNotification>>(
      stream: _notificationService.getNotificationsStream(_userId),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.where((n) => !n.isRead).length ?? 0;

        return PopupMenuButton<void>(
          offset: const Offset(0, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          position: PopupMenuPosition.under,
          icon: Stack(
            children: [
              const Icon(Icons.notifications_outlined),
              if (unreadCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          onOpened: () {
            // Mark all as read when opened
            _notificationService.markAllAsRead(_userId);
          },
          itemBuilder: (context) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return [
                const PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'No notifications',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ];
            }

            return [
              PopupMenuItem(
                enabled: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _notificationService.deleteAllNotifications(_userId);
                        Navigator.pop(context);
                      },
                      child: const Text('Clear all'),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              ...snapshot.data!.map((notification) => PopupMenuItem(
                    height: 72,
                    child: Dismissible(
                      key: Key(notification.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        color: Colors.red,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 16),
                          child: Icon(Icons.delete, color: Colors.white),
                        ),
                      ),
                      onDismissed: (_) {
                        _notificationService.deleteNotification(_userId, notification.id);
                      },
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _buildNotificationIcon(notification.type),
                        title: Text(
                          notification.notificationMessage,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          timeago.format(notification.timestamp),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  )),
            ];
          },
        );
      },
    );
  }

  Widget _buildNotificationIcon(NotificationType type) {
    IconData iconData;
    Color color;

    switch (type) {
      case NotificationType.follow:
        iconData = Icons.person_add;
        color = Colors.blue;
        break;
      case NotificationType.like:
        iconData = Icons.favorite;
        color = Colors.red;
        break;
      case NotificationType.comment:
        iconData = Icons.comment;
        color = Colors.green;
        break;
      case NotificationType.poke:
        iconData = Icons.back_hand;
        color = Colors.orange;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: color, size: 20),
    );
  }
} 