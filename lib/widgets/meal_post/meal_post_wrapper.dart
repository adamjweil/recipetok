import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/custom_cache_manager.dart';
import '../../screens/profile_screen.dart';
import '../../models/meal_post.dart';
import 'expandable_meal_post.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../../screens/comment_screen.dart';
import 'like_button.dart';
import '../../widgets/profile/user_list_item_skeleton.dart';
import '../../utils/time_formatter.dart';
import '../../models/story.dart';
import '../../services/story_service.dart';
import '../../widgets/story_viewer.dart';
import '../../screens/main_navigation_screen.dart';

class MealPostWrapper extends StatefulWidget {
  final MealPost post;
  final bool showUserInfo;
  
  const MealPostWrapper({
    super.key,
    required this.post,
    this.showUserInfo = true,
  });

  @override
  State<MealPostWrapper> createState() => _MealPostWrapperState();
}

class _MealPostWrapperState extends State<MealPostWrapper> {
  // Move static caches to the widget class
  static final Map<String, Future<DocumentSnapshot>> _userCache = {};
  static final Map<String, Map<String, dynamic>> _userDataCache = {};
  static final Map<String, Stream<QuerySnapshot>> _likesStreamCache = {};
  static final Map<String, Stream<QuerySnapshot>> _commentsStreamCache = {};

  Future<DocumentSnapshot> _getUserData(String userId) {
    // Return cached future if it exists
    _userCache[userId] ??= FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get()
        .then((snapshot) {
          // Cache the user data
          _userDataCache[userId] = snapshot.data() as Map<String, dynamic>;
          return snapshot;
        });
    return _userCache[userId]!;
  }

  Stream<QuerySnapshot> _getLikesStream(String postId) {
    _likesStreamCache[postId] ??= FirebaseFirestore.instance
        .collection('meal_posts')
        .doc(postId)
        .collection('likes')
        .limit(3)
        .snapshots();
    return _likesStreamCache[postId]!;
  }

  Stream<QuerySnapshot> _getCommentsStream(String postId) {
    _commentsStreamCache[postId] ??= FirebaseFirestore.instance
        .collection('meal_posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots();
    return _commentsStreamCache[postId]!;
  }

  @override
  Widget build(BuildContext context) {
    // Try to get cached user data first
    final cachedUserData = _userDataCache[widget.post.userId];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info section (if showing)
          if (widget.showUserInfo)
            Padding(
              padding: const EdgeInsets.all(12),
              child: cachedUserData != null
                  ? _buildUserInfo(context, cachedUserData)
                  : FutureBuilder<DocumentSnapshot>(
                      future: _getUserData(widget.post.userId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const UserListItemSkeleton();
                        }

                        final userData = snapshot.data!.data() as Map<String, dynamic>;
                        return _buildUserInfo(context, userData);
                      },
                    ),
            ),

          // Image and Description Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.post.photoUrls.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 120,  // Matching profile size
                      height: 120,
                      child: CustomCacheManager.buildCachedImage(
                        url: widget.post.photoUrls.firstOrNull,
                        width: 120,
                        height: 120,
                      ),
                    ),
                  ),

                const SizedBox(width: 12),

                // Description and Interaction Buttons
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (context.findAncestorStateOfType<MainNavigationScreenState>() != null) {
                            context.findAncestorStateOfType<MainNavigationScreenState>()!
                              .navigateToUserProfile(widget.post.userId);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MainNavigationScreen(
                                  initialIndex: 4,
                                  userId: widget.post.userId,
                                ),
                              ),
                            );
                          }
                        },
                        child: Text(
                          widget.post.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (widget.post.description != null)
                        Text(
                          widget.post.description!,
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
                      postId: widget.post.id,
                      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                      onLikeToggle: _toggleLike,
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CommentScreen(post: widget.post),
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
                            stream: _getCommentsStream(widget.post.id),
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
                  stream: _getLikesStream(widget.post.id),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox();
                    }
                    
                    final likes = snapshot.data!.docs;
                    final totalLikes = widget.post.likes;  // Use the total likes from post

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Overlapping Avatars
                        if (likes.isNotEmpty)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 60),
                            child: SizedBox(
                              width: likes.length * 20.0 - (likes.length - 1) * 12.0,
                              height: 24,
                              child: Stack(
                                children: likes.take(3).map((like) {
                                  final index = likes.indexOf(like);
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
                                            radius: 9,
                                            backgroundImage: userData?['avatarUrl'] != null
                                                ? CachedNetworkImageProvider(userData!['avatarUrl'])
                                                : null,
                                            child: userData?['avatarUrl'] == null
                                                ? const Icon(Icons.person, size: 11)
                                                : null,
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        
                        // Names or Count Text
                        Flexible(
                          child: totalLikes <= 2
                            ? FutureBuilder<List<String>>(
                                future: Future.wait(
                                  likes.take(2).map((like) async {
                                    final userDoc = await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(like.id)
                                        .get();
                                    final fullName = userDoc.data()?['displayName'] ?? 'Unknown';
                                    return fullName.split(' ')[0];
                                  }),
                                ),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                    return totalLikes == 0 ? const SizedBox() : Text(
                                      '$totalLikes gave props',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  }

                                  final names = snapshot.data!;
                                  if (names.isEmpty) {
                                    return const SizedBox();
                                  } else if (names.length == 1) {
                                    return Text(
                                      '${names[0]} gave props',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  } else {
                                    return Text(
                                      '${names[0]} and ${names[1]} gave props',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  }
                                },
                              )
                            : totalLikes > 0
                                ? Text(
                                    '$totalLikes gave props',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : const SizedBox(),
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
                      'Check out this meal post: ${widget.post.description}',
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

  Widget _buildImage(String? imageUrl) {
    if (!CustomCacheManager.isValidImageUrl(imageUrl)) {
      return Container(
        color: Colors.grey[200],
        child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      cacheManager: CustomCacheManager.instance,
      fit: BoxFit.cover,
      memCacheWidth: 400,
      memCacheHeight: 400,
      placeholder: (context, url) => Container(
        color: Colors.grey[200],
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[200],
        child: Icon(Icons.error_outline, color: Colors.grey[400]),
      ),
    );
  }

  Future<void> _toggleLike(String postId, String userId) async {
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
          'likedBy': FieldValue.arrayRemove([userId])
        });
      } else {
        // Like
        batch.set(likeRef, {
          'timestamp': FieldValue.serverTimestamp(),
          'userId': userId
        });
        batch.update(postRef, {
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([userId])
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error toggling like: $e');
      // Optionally show error message to user
    }
  }

  // Update the helper method to handle MealType enum
  IconData _getMealTypeIcon(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return Icons.breakfast_dining;
      case MealType.lunch:
        return Icons.lunch_dining;
      case MealType.dinner:
        return Icons.dinner_dining;
      case MealType.snack:
        return Icons.cookie;
      default:
        return Icons.restaurant;
    }
  }

  // Add helper method to convert MealType to display string
  String _getMealTypeString(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return 'breakfast';
      case MealType.lunch:
        return 'lunch';
      case MealType.dinner:
        return 'dinner';
      case MealType.snack:
        return 'snack';
      default:
        return 'meal';
    }
  }

  // Update _buildUserInfo to accept BuildContext
  Widget _buildUserInfo(BuildContext context, Map<String, dynamic> userData) {
    final avatarUrl = userData['avatarUrl'] as String?;
    final firstName = userData['firstName'] as String? ?? 'Unknown';
    final lastName = userData['lastName'] as String? ?? '';
    final formattedName = lastName.isNotEmpty 
        ? '$firstName ${lastName[0]}.' 
        : firstName;

    return Row(
      children: [
        GestureDetector(
          onTap: () {
            if (context.findAncestorStateOfType<MainNavigationScreenState>() != null) {
              context.findAncestorStateOfType<MainNavigationScreenState>()!
                .navigateToUserProfile(widget.post.userId);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MainNavigationScreen(
                    initialIndex: 4,
                    userId: widget.post.userId,
                  ),
                ),
              );
            }
          },
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[200],
            child: ClipOval(
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? CustomCacheManager.buildCachedImage(
                      url: avatarUrl,
                      width: 36,
                      height: 36,
                    )
                  : Container(
                      width: 36,
                      height: 36,
                      color: Colors.grey[200],
                      child: Icon(
                        Icons.person,
                        size: 20,
                        color: Colors.grey[400],
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (context.findAncestorStateOfType<MainNavigationScreenState>() != null) {
                context.findAncestorStateOfType<MainNavigationScreenState>()!
                  .navigateToUserProfile(widget.post.userId);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MainNavigationScreen(
                      initialIndex: 4,
                      userId: widget.post.userId,
                    ),
                  ),
                );
              }
            },
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(
                    text: formattedName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  const TextSpan(
                    text: ' made ',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 11,
                    ),
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        _getMealTypeIcon(widget.post.mealType),
                        size: 13,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  TextSpan(
                    text: _getMealTypeString(widget.post.mealType),
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          getTimeAgo(widget.post.createdAt),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
} 