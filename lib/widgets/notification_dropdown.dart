import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';
import '../screens/profile_screen.dart';

class NotificationDropdown extends StatelessWidget {
  final NotificationService _notificationService = NotificationService();
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  NotificationDropdown({Key? key}) : super(key: key);

  Future<Map<String, dynamic>> _getUserInfo(String userId) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return {
      'name': '${userDoc.data()?['firstName'] ?? ''} ${userDoc.data()?['lastName'] ?? ''}'.trim(),
      'avatarUrl': userDoc.data()?['avatarUrl'] ?? '',
    };
  }

  void _handleNotificationTap(BuildContext context, AppNotification notification) {
    Navigator.pop(context); // Close the notification dropdown

    switch (notification.type) {
      case NotificationType.follow:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(userId: notification.userId),
          ),
        );
        break;
      case NotificationType.like:
      case NotificationType.comment:
        if (notification.postId != null) {
          // Navigate to the post
          Navigator.pushNamed(
            context,
            '/post',
            arguments: notification.postId,
          );
        }
        break;
      case NotificationType.poke:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(userId: notification.userId),
          ),
        );
        break;
      case NotificationType.welcome:
        // No navigation needed for welcome notification
        break;
    }
  }

  String _getNotificationMessage(AppNotification notification, String userName) {
    switch (notification.type) {
      case NotificationType.follow:
        return '$userName started following you';
      case NotificationType.like:
        return '$userName liked your post';
      case NotificationType.comment:
        return '$userName commented on your post';
      case NotificationType.poke:
        return '$userName poked you';
      case NotificationType.welcome:
        return 'Welcome to Munchster! Start by sharing your first recipe 🎉';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<List<AppNotification>>(
      stream: _notificationService.getNotificationsStream(_userId),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.where((n) => !n.isRead).length ?? 0;

        return PopupMenuButton<void>(
          offset: const Offset(0, 8),
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
              ...snapshot.data!.map((notification) => PopupMenuItem<void>(
                    height: 72,
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: _getUserInfo(notification.userId),
                      builder: (context, userSnapshot) {
                        final userName = userSnapshot.data?['name'] ?? '';
                        final avatarUrl = userSnapshot.data?['avatarUrl'] ?? '';
                        
                        if (!userSnapshot.hasData) {
                          return const SizedBox(
                            height: 56,
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        
                        return InkWell(
                          onTap: () => _handleNotificationTap(context, notification),
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
                              leading: notification.type == NotificationType.welcome
                                ? _buildNotificationIcon(notification.type)
                                : CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: avatarUrl.isNotEmpty
                                      ? CachedNetworkImageProvider(avatarUrl)
                                      : null,
                                    child: avatarUrl.isEmpty
                                      ? const Icon(Icons.person, color: Colors.grey)
                                      : null,
                                  ),
                              title: Text(
                                _getNotificationMessage(notification, userName),
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
                        );
                      },
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
      case NotificationType.welcome:
        iconData = Icons.celebration;
        color = Colors.purple;
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