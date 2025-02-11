import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/chat_message.dart';
import '../../utils/custom_cache_manager.dart';

class LikeButton extends StatelessWidget {
  final String postId;
  final String userId;

  const LikeButton({
    super.key,
    required this.postId,
    required this.userId,
  });

  Future<void> _toggleLike() async {
    try {  // Add try-catch for better error handling
      final likesRef = FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(postId)
          .collection('likes');

      final existingLike = await likesRef.doc(userId).get();

      if (existingLike.exists) {
        // Unlike - just remove the like
        await likesRef.doc(userId).delete();
      } else {
        // Like - add like and send notification
        await likesRef.doc(userId).set({
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Get post details
        final postDoc = await FirebaseFirestore.instance
            .collection('meal_posts')
            .doc(postId)
            .get();
        
        if (!postDoc.exists) {
          debugPrint('Post not found');
          return;
        }

        final postData = postDoc.data()!;
        final postOwnerId = postData['userId'] as String;

        // Don't send notification if liking your own post
        if (postOwnerId == userId) {
          return;
        }
        
        // Check if chat exists or create new one
        final chatId = await _getOrCreateChat(userId, postOwnerId);
        
        final photoUrl = postData['photoUrls']?[0];
        debugPrint('Debug: Photo URL from post: $photoUrl');

        if (!CustomCacheManager.isValidImageUrl(photoUrl)) {
          debugPrint('Debug: Invalid photo URL detected, skipping image');
        }
        
        // Send like notification message
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .add({
              'senderId': userId,
              'receiverId': postOwnerId,
              'type': 'MessageType.postLike',
              'postId': postId,
              'timestamp': FieldValue.serverTimestamp(),
            });

        // Update last message in chat
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .update({
              'lastMessage': 'Liked your post',
              'lastMessageTimestamp': FieldValue.serverTimestamp(),
            });

        debugPrint('Like notification sent successfully');
      }
    } catch (e) {
      debugPrint('Error in _toggleLike: $e');
    }
  }

  Future<String> _getOrCreateChat(String user1Id, String user2Id) async {
    try {
      // Sort IDs to ensure consistent chat ID
      final sortedIds = [user1Id, user2Id]..sort();
      final chatId = sortedIds.join('_');

      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      if (!chatDoc.exists) {
        // Create new chat
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .set({
              'participants': sortedIds,
              'lastMessage': null,
              'lastMessageTimestamp': FieldValue.serverTimestamp(),
              'createdAt': FieldValue.serverTimestamp(),
            });
        debugPrint('Created new chat: $chatId');
      }

      return chatId;
    } catch (e) {
      debugPrint('Error in _getOrCreateChat: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(postId)
          .collection('likes')
          .doc(userId)
          .snapshots(),
      builder: (context, likeSnapshot) {
        final isLiked = likeSnapshot.data?.exists ?? false;

        return Row(
          children: [
            GestureDetector(
              onTap: _toggleLike,
              child: AnimatedCrossFade(
                firstChild: Icon(
                  Icons.thumb_up,
                  color: Theme.of(context).primaryColor,
                  size: 18,
                ),
                secondChild: Icon(
                  Icons.thumb_up_outlined,
                  color: Colors.grey[600],
                  size: 18,
                ),
                crossFadeState: isLiked
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 200),
              ),
            ),
            const SizedBox(width: 4),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('meal_posts')
                  .doc(postId)
                  .snapshots(),
              builder: (context, postSnapshot) {
                final likes = (postSnapshot.data?.data() 
                  as Map<String, dynamic>?)?['likes'] ?? 0;
                return Text(
                  '$likes',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
} 