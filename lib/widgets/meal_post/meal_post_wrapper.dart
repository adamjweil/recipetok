import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';
import 'dart:ui';
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

class _MealPostWrapperState extends State<MealPostWrapper> with SingleTickerProviderStateMixin {
  // Move static caches to the widget class
  static final Map<String, Future<DocumentSnapshot>> _userCache = {};
  static final Map<String, Map<String, dynamic>> _userDataCache = {};
  static final Map<String, Stream<DocumentSnapshot>> _postStreamCache = {};

  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;
  bool _isExpanded = false;

  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

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

  Stream<DocumentSnapshot> _getPostStream(String postId) {
    _postStreamCache[postId] ??= FirebaseFirestore.instance
        .collection('meal_posts')
        .doc(postId)
        .snapshots();
    return _postStreamCache[postId]!;
  }

  Stream<QuerySnapshot> _getCommentsStream(String postId) {
    return FirebaseFirestore.instance
        .collection('meal_posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots();
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
                    child: Stack(
                      children: [
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: Hero(
                            tag: 'post_image_${widget.post.id}',
                            child: CustomCacheManager.buildCachedImage(
                              url: widget.post.photoUrls.first,
                              width: 120,
                              height: 120,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Material(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _showExpandedView,
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.open_in_full,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 12),
                // Title and Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.post.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.post.description!,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
                StreamBuilder<DocumentSnapshot>(
                  stream: _getPostStream(widget.post.id),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox();
                    }
                    
                    final postData = snapshot.data!.data() as Map<String, dynamic>?;
                    if (postData == null) return const SizedBox();
                    
                    final likedBy = (postData['likedBy'] as List<dynamic>?) ?? [];
                    final totalLikes = likedBy.length;
                    
                    if (totalLikes == 0) return const SizedBox();

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Overlapping Avatars
                        if (likedBy.isNotEmpty)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 60),
                            child: SizedBox(
                              width: likedBy.take(3).length * 20.0 - (likedBy.take(3).length - 1) * 12.0,
                              height: 24,
                              child: Stack(
                                children: likedBy.take(3).map((userId) {
                                  final index = likedBy.indexOf(userId);
                                  return Positioned(
                                    left: index * 12.0,
                                    child: FutureBuilder<DocumentSnapshot>(
                                      future: _getUserData(userId.toString()),
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
                                  likedBy.take(2).map((userId) async {
                                    final userDoc = await _getUserData(userId.toString());
                                    final fullName = (userDoc.data() as Map<String, dynamic>?)?['displayName'] ?? 'Unknown';
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
                            : Text(
                                '$totalLikes gave props',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
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
                      'Check out this meal post: ${widget.post.description}',
                      subject: 'Check out this meal post!',
                    );
                  },
                ),
              ],
            ),
          ),

          // Add this after the image section to show comments when expanded
          if (_isExpanded) ...[
            AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, child) {
                return SizeTransition(
                  sizeFactor: _expandAnimation,
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      // Comments section
                      StreamBuilder<QuerySnapshot>(
                        stream: _getCommentsStream(widget.post.id),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final comments = snapshot.data!.docs;
                          return Column(
                            children: [
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: comments.length,
                                itemBuilder: (context, index) {
                                  final comment = comments[index].data() as Map<String, dynamic>;
                                  return FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(comment['userId'])
                                        .get(),
                                    builder: (context, userSnapshot) {
                                      if (!userSnapshot.hasData) {
                                        return const SizedBox();
                                      }

                                      final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundImage: userData['avatarUrl'] != null
                                                  ? CachedNetworkImageProvider(userData['avatarUrl'])
                                                  : null,
                                              child: userData['avatarUrl'] == null
                                                  ? const Icon(Icons.person, size: 16)
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    userData['displayName'] ?? 'Unknown',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    comment['text'] ?? '',
                                                    style: const TextStyle(fontSize: 14),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                              // Comment input field
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _commentController,
                                        decoration: InputDecoration(
                                          hintText: 'Add a comment...',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(24),
                                            borderSide: BorderSide.none,
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey[100],
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                        ),
                                        onSubmitted: (_) => _sendComment(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.send),
                                      color: Theme.of(context).primaryColor,
                                      onPressed: _sendComment,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
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
          onTap: () => _navigateToUserProfile(context, widget.post.userId),
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
            onTap: () => _navigateToUserProfile(context, widget.post.userId),
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

  void _navigateToUserProfile(BuildContext context, String userId) {
    final mainNavigationState = context.findAncestorStateOfType<MainNavigationScreenState>();
    
    if (mainNavigationState != null) {
      mainNavigationState.navigateToUserProfile(userId);
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => ProfileScreen(
            userId: userId,
            showBackButton: false,
          ),
        ),
        (route) => false,  // This removes all previous routes
      );
    }
  }

  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(widget.post.id)
          .collection('comments')
          .add({
        'text': _commentController.text.trim(),
        'userId': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update comment count
      await FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(widget.post.id)
          .update({
        'comments': FieldValue.increment(1),
      });

      if (mounted) {
        _commentController.clear();
      }
    } catch (e) {
      debugPrint('Error sending comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error sending comment')),
        );
      }
    }
  }

  void _showExpandedView() {
    _expandController.forward();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AnimatedBuilder(
        animation: _expandAnimation,
        builder: (context, child) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Image Section
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.4,
                  width: double.infinity,
                  child: Hero(
                    tag: 'post_image_${widget.post.id}',
                    child: CustomCacheManager.buildCachedImage(
                      url: widget.post.photoUrls.first,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
                // Comments Section
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _getCommentsStream(widget.post.id),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final comments = snapshot.data!.docs;
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index].data() as Map<String, dynamic>;
                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(comment['userId'])
                                .get(),
                            builder: (context, userSnapshot) {
                              if (!userSnapshot.hasData) {
                                return const SizedBox();
                              }

                              final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundImage: userData['avatarUrl'] != null
                                          ? CachedNetworkImageProvider(userData['avatarUrl'])
                                          : null,
                                      child: userData['avatarUrl'] == null
                                          ? const Icon(Icons.person, size: 16)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userData['displayName'] ?? 'Unknown',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            comment['text'] ?? '',
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                // Comment Input
                Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                    top: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          onSubmitted: (_) => _sendComment(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send),
                        color: Theme.of(context).primaryColor,
                        onPressed: _sendComment,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() => _expandController.reverse());
  }
} 