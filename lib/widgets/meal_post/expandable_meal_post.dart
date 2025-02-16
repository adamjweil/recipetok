import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/meal_post.dart';
import '../../utils/time_formatter.dart';
import 'like_button.dart';
import 'package:share_plus/share_plus.dart';
import '../../screens/comment_screen.dart';
import '../../utils/custom_cache_manager.dart';

class ExpandableMealPost extends StatefulWidget {
  final MealPost post;
  final bool isExpanded;
  final VoidCallback onToggle;

  const ExpandableMealPost({
    super.key,
    required this.post,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  State<ExpandableMealPost> createState() => _ExpandableMealPostState();
}

class _ExpandableMealPostState extends State<ExpandableMealPost> {
  final TextEditingController _commentController = TextEditingController();
  bool _isPostingComment = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _commentController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;
    setState(() => _isPostingComment = true);

    try {
      final commentRef = FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(widget.post.id)
          .collection('comments')
          .doc();

      await commentRef.set({
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'text': _commentController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(widget.post.id)
          .update({
        'comments': FieldValue.increment(1),
      });

      if (mounted) {
        _commentController.clear();
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting comment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPostingComment = false);
    }
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
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        // Like
        batch.set(likeRef, {
          'timestamp': FieldValue.serverTimestamp(),
        });
        batch.update(postRef, {
          'likeCount': FieldValue.increment(1),
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image and Description Row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),  // Removed bottom padding
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.post.photoUrls.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: _buildPostImage(widget.post.photoUrls.first),
                    ),
                  ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.post.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (FirebaseAuth.instance.currentUser?.uid == widget.post.userId)
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.more_vert, size: 20),
                              color: Colors.grey[700],
                              onPressed: () => _showOptionsMenu(context),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            getTimeAgo(widget.post.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (widget.post.description != null)
                        Text(
                          widget.post.description!,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Interaction buttons row (full width)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Like and Comment buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LikeButton(
                      postId: widget.post.id,
                      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                      onLikeToggle: _toggleLike,
                    ),
                    const SizedBox(width: 8),
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.grey[600],
                            size: 16,
                          ),
                          const SizedBox(width: 2),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('meal_posts')
                                .doc(widget.post.id)
                                .collection('comments')
                                .snapshots(),
                            builder: (context, snapshot) {
                              final commentCount = snapshot.data?.docs.length ?? 0;
                              return Text(
                                '$commentCount',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 11,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                // Likes avatars and count
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('meal_posts')
                        .doc(widget.post.id)
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
                            width: likes.length * 16.0 - (likes.length - 1) * 10.0,
                            height: 20,
                            child: Stack(
                              children: likes.asMap().entries.map((entry) {
                                final index = entry.key;
                                final like = entry.value;
                                return Positioned(
                                  left: index * 10.0,
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
                                          radius: 8,
                                          backgroundImage: userData?['avatarUrl'] != null
                                              ? CachedNetworkImageProvider(userData!['avatarUrl'])
                                              : null,
                                          child: userData?['avatarUrl'] == null
                                              ? const Icon(Icons.person, size: 10)
                                              : null,
                                        ),
                                      );
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$likeCount gave props',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                // Share button
                IconButton(
                  icon: Icon(
                    Icons.share_outlined,
                    color: Colors.grey[600],
                    size: 16,
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

          // Comments section
          if (widget.isExpanded) ...[
            const Divider(),
            // Comments list and input field implementation...
            // Add your existing comments section code here
          ],
        ],
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete Post',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context); // Close the menu
                _showDeleteConfirmation(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePost(BuildContext context) async {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    
    try {
      // Close the confirmation dialog
      rootNavigator.pop();

      // Delete the post document
      await FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(widget.post.id)
          .delete();

      if (!mounted) return;

      // Pop all the way back to the main screen
      rootNavigator.popUntil((route) => route.isFirst);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post deleted successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting post: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text(
          'This action cannot be undone. Are you sure you want to delete this post?',
          style: TextStyle(fontSize: 14),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _deletePost(context),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostImage(String? imageUrl) {
    return Stack(
      children: [
        if (widget.post.photoUrls.isEmpty)
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              color: Colors.grey[200],
              child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
            ),
          )
        else
          AspectRatio(
            aspectRatio: 1,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.post.photoUrls.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) {
                final url = widget.post.photoUrls[index];
                if (!CustomCacheManager.isValidImageUrl(url)) {
                  return Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
                  );
                }

                return CachedNetworkImage(
                  imageUrl: url,
                  cacheManager: CustomCacheManager.instance,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.error_outline, color: Colors.grey[400]),
                  ),
                );
              },
            ),
          ),
        // Add page indicator dots if there are multiple photos
        if (widget.post.photoUrls.length > 1)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentPage + 1}/${widget.post.photoUrls.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
} 