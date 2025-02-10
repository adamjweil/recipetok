import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LikeButton extends StatelessWidget {
  final String postId;
  final String userId;

  const LikeButton({
    super.key,
    required this.postId,
    required this.userId,
  });

  Future<void> _toggleLike() async {
    try {
      final postRef = FirebaseFirestore.instance.collection('meal_posts').doc(postId);
      final likeRef = postRef.collection('likes').doc(userId);

      final likeDoc = await likeRef.get();
      final batch = FirebaseFirestore.instance.batch();

      if (likeDoc.exists) {
        // Unlike
        batch.delete(likeRef);
        batch.update(postRef, {
          'likes': FieldValue.increment(-1),
        });
      } else {
        // Like
        batch.set(likeRef, {
          'timestamp': FieldValue.serverTimestamp(),
        });
        batch.update(postRef, {
          'likes': FieldValue.increment(1),
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error toggling like: $e');
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