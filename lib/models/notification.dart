import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  follow,
  like,
  comment,
  poke,
  welcome,
}

class AppNotification {
  final String id;
  final String userId;  // User who triggered the notification
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final String? postId;  // Optional: for likes and comments
  final String? commentId;  // Optional: for comments
  final String? message;  // Optional: custom message

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.postId,
    this.commentId,
    this.message,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type.toString(),
      'timestamp': timestamp,
      'isRead': isRead,
      'postId': postId,
      'commentId': commentId,
      'message': message,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
    return AppNotification(
      id: id,
      userId: map['userId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => NotificationType.follow,
      ),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isRead: map['isRead'] ?? false,
      postId: map['postId'],
      commentId: map['commentId'],
      message: map['message'],
    );
  }

  String get notificationMessage {
    switch (type) {
      case NotificationType.follow:
        return 'started following you';
      case NotificationType.like:
        return 'liked your post';
      case NotificationType.comment:
        return 'commented on your post';
      case NotificationType.poke:
        return 'poked you';
      case NotificationType.welcome:
        return 'Welcome to Munchster! Start by sharing your first recipe 🎉';
    }
  }
} 