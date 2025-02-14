import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int _notificationLimit = 10;

  // Create a new notification
  Future<void> createNotification({
    required String userId,  // Recipient user ID
    required String triggerUserId,  // User who triggered the notification
    required NotificationType type,
    String? postId,
    String? commentId,
    String? message,
  }) async {
    final notificationsRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications');

    // Create the notification
    await notificationsRef.add({
      'userId': triggerUserId,
      'type': type.toString(),
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'postId': postId,
      'commentId': commentId,
      'message': message,
    });

    // Delete old notifications if limit is exceeded
    final querySnapshot = await notificationsRef
        .orderBy('timestamp', descending: true)
        .get();

    if (querySnapshot.docs.length > _notificationLimit) {
      final batch = _firestore.batch();
      final docsToDelete = querySnapshot.docs.sublist(_notificationLimit);
      
      for (var doc in docsToDelete) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    }
  }

  // Get notifications stream
  Stream<List<AppNotification>> getNotificationsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(_notificationLimit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromMap(
                  doc.data(),
                  doc.id,
                ))
            .toList());
  }

  // Mark notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  // Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    final batch = _firestore.batch();
    final notifications = await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  // Delete a notification
  Future<void> deleteNotification(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  // Delete all notifications
  Future<void> deleteAllNotifications(String userId) async {
    final batch = _firestore.batch();
    final notifications = await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .get();

    for (var doc in notifications.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // Get unread notification count
  Stream<int> getUnreadCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
} 