import 'package:flutter/material.dart';
import '../../models/meal_post.dart';
import 'expandable_meal_post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../screens/comment_screen.dart';
import 'like_button.dart';
import '../../widgets/profile/user_list_item_skeleton.dart';
import '../../utils/time_formatter.dart';

class MealPostWrapper extends StatelessWidget {
  final MealPost post;
  final bool showUserInfo;

  const MealPostWrapper({
    super.key,
    required this.post,
    this.showUserInfo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),  // Matching profile margin
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info section (if showing)
          if (showUserInfo)
            Padding(
              padding: const EdgeInsets.all(12),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(post.userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const UserListItemSkeleton();
                  }

                  final userData = snapshot.data!.data() as Map<String, dynamic>;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/profile/${post.userId}',
                        ),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundImage: userData['avatarUrl'] != null
                              ? CachedNetworkImageProvider(userData['avatarUrl'])
                              : null,
                          child: userData['avatarUrl'] == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  userData['username'] ?? 'Unknown User',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  ' • ',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  getTimeAgo(post.createdAt),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

          // Image and Description Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.photoUrls.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 120,  // Matching profile size
                      height: 120,
                      child: Stack(
                        children: [
                          CachedNetworkImage(
                            imageUrl: post.photoUrls.first,
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                post.mealType.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(width: 12),

                // Description and Interaction Buttons
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (post.description != null)
                        Text(
                          post.description!,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 0),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Update the full-width interaction row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                // Like and Comment buttons on the left
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LikeButton(
                      postId: post.id,
                      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CommentScreen(post: post),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.grey[600],
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('meal_posts')
                                .doc(post.id)
                                .collection('comments')
                                .snapshots(),
                            builder: (context, snapshot) {
                              final commentCount = snapshot.data?.docs.length ?? 0;
                              return Text(
                                '$commentCount',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),  // Add spacing between comment button and avatars
                // Likes avatars and count right after comment button
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('meal_posts')
                      .doc(post.id)
                      .collection('likes')
                      .limit(3)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const SizedBox(width: 0);
                    }
                    
                    final likes = snapshot.data!.docs;
                    final likeCount = likes.length;

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: likes.length * 20.0 - (likes.length - 1) * 12.0,
                          height: 24,
                          child: Stack(
                            children: likes.asMap().entries.map((entry) {
                              final index = entry.key;
                              final like = entry.value;
                              return Positioned(
                                left: index * 12.0,
                                child: StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(like.id)
                                      .snapshots(),
                                  builder: (context, userSnapshot) {
                                    final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                                    return Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 10,
                                        backgroundImage: userData?['avatarUrl'] != null
                                            ? CachedNetworkImageProvider(userData!['avatarUrl'])
                                            : null,
                                        child: userData?['avatarUrl'] == null
                                            ? const Icon(Icons.person, size: 12)
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$likeCount gave props',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const Spacer(),  // Only one spacer to push share button to the right
                // Share button on the right
                IconButton(
                  icon: Icon(
                    Icons.share_outlined,
                    color: Colors.grey[600],
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Share.share(
                      'Check out this meal post: ${post.description}',
                      subject: 'Check out this meal post!',
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 