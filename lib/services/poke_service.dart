import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';

class PokeService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _notificationService = NotificationService();

  Future<void> pokeUser(String targetUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('Not authenticated');
    if (currentUserId == targetUserId) throw Exception('Cannot poke yourself');

    // Check if user is following the target
    final currentUserDoc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .get();
    
    final List following = currentUserDoc.data()?['following'] ?? [];
    if (!following.contains(targetUserId)) {
      throw Exception('You must follow this user before you can poke them');
    }

    // Check cooldown first
    final cooldown = await getCooldown(targetUserId);
    if (cooldown != null) {
      throw Exception('Cannot poke user yet, please wait ${_formatDuration(cooldown)}');
    }

    // Create the poke document
    final pokeRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('pokes')
        .doc();  // Generate a new document ID

    await pokeRef.set({
      'timestamp': FieldValue.serverTimestamp(),
      'fromUserId': currentUserId,
      'toUserId': targetUserId,
    });

    // Create notification
    await _notificationService.createNotification(
      userId: targetUserId,
      triggerUserId: currentUserId,
      type: NotificationType.poke,
    );
  }

  Future<Duration?> getCooldown(String targetUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return null;

    try {
      final pokesQuery = await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('pokes')
          .where('fromUserId', isEqualTo: currentUserId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (pokesQuery.docs.isEmpty) return null;

      final lastPokeAt = pokesQuery.docs.first.data()['timestamp'] as Timestamp?;
      if (lastPokeAt == null) return null;

      final now = DateTime.now();
      final pokeTime = lastPokeAt.toDate();
      final nextPokeTime = pokeTime.add(const Duration(hours: 24));

      if (now.isBefore(nextPokeTime)) {
        return nextPokeTime.difference(now);
      }

      return null;
    } catch (e) {
      print('Error getting cooldown: $e');
      return null;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours} hours';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} minutes';
    } else {
      return '${duration.inSeconds} seconds';
    }
  }
} 