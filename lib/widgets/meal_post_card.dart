import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/meal_post.dart';
import '../utils/custom_cache_manager.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

class MealPostCard extends StatelessWidget {
  final MealPost post;
  final VoidCallback? onTap;

  const MealPostCard({
    super.key,
    required this.post,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        elevation: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post Date
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                DateFormat.yMMMd().format(post.createdAt),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),

            // Photos
            SizedBox(
              height: 300,
              child: PageView.builder(
                itemCount: post.photoUrls.length,
                itemBuilder: (context, index) {
                  return CachedNetworkImage(
                    imageUrl: post.photoUrls[index],
                    fit: BoxFit.cover,
                    cacheManager: CustomCacheManager.instance,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.error),
                    ),
                  );
                },
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  _buildLikeButton(),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.comment_outlined),
                    onPressed: () {
                      // TODO: Implement comments
                    },
                  ),
                  Text(
                    post.commentsCount.toString(),
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () {
                      Share.share('Check out this meal post!'); // TODO: Add proper sharing URL
                    },
                  ),
                ],
              ),
            ),

            // Title and Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (post.description != null && post.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      post.description!,
                      style: TextStyle(
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    post.mealType.toString().split('.').last.toUpperCase(),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildLikeButton() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(post.id)
          .snapshots(),
      builder: (context, snapshot) {
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final postData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final likedBy = List<String>.from(postData['likedBy'] ?? []);
        final isLiked = currentUserId != null && likedBy.contains(currentUserId);

        return Row(
          children: [
            IconButton(
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Colors.red : null,
              ),
              onPressed: () => _toggleLike(context),
            ),
            Text(
              likedBy.length.toString(),
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMoreOptions(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUserId == post.userId;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        switch (value) {
          case 'delete':
            if (isOwner) {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Post'),
                  content: const Text('Are you sure you want to delete this post?'),
                  actions: [
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    TextButton(
                      child: const Text('Delete'),
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await FirebaseFirestore.instance
                    .collection('meal_posts')
                    .doc(post.id)
                    .delete();
              }
            }
            break;
          case 'report':
            // TODO: Implement report functionality
            break;
        }
      },
      itemBuilder: (context) => [
        if (isOwner)
          const PopupMenuItem(
            value: 'delete',
            child: Text('Delete'),
          ),
        if (!isOwner)
          const PopupMenuItem(
            value: 'report',
            child: Text('Report'),
          ),
      ],
    );
  }

  Future<void> _toggleLike(BuildContext context) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final postRef = FirebaseFirestore.instance
        .collection('meal_posts')
        .doc(post.id);

    final postDoc = await postRef.get();
    final likedBy = List<String>.from(postDoc.data()?['likedBy'] ?? []);

    if (likedBy.contains(currentUserId)) {
      await postRef.update({
        'likedBy': FieldValue.arrayRemove([currentUserId]),
        'likesCount': FieldValue.increment(-1),
      });
    } else {
      await postRef.update({
        'likedBy': FieldValue.arrayUnion([currentUserId]),
        'likesCount': FieldValue.increment(1),
      });
    }
  }
} 