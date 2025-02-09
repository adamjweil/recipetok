import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/meal_post.dart';
import '../utils/custom_cache_manager.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/comment_modal.dart';

class MealPostCard extends StatefulWidget {
  final MealPost post;
  final VoidCallback onTap;

  const MealPostCard({
    super.key,
    required this.post,
    required this.onTap,
  });

  @override
  State<MealPostCard> createState() => _MealPostCardState();
}

class _MealPostCardState extends State<MealPostCard> with SingleTickerProviderStateMixin {
  late AnimationController _likeController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _likeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 1.2).animate(
      CurvedAnimation(
        parent: _likeController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  Future<void> _handleLike() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final postRef = FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(widget.post.id);

      // Start the animation
      _likeController.forward().then((_) => _likeController.reverse());

      if (widget.post.likedBy.contains(currentUserId)) {
        // Unlike
        await postRef.update({
          'likedBy': FieldValue.arrayRemove([currentUserId]),
          'likesCount': FieldValue.increment(-1),
        });
      } else {
        // Like
        await postRef.update({
          'likedBy': FieldValue.arrayUnion([currentUserId]),
          'likesCount': FieldValue.increment(1),
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating like: ${e.toString()}')),
      );
    }
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: CommentsSection(
            postId: widget.post.id,
            scrollController: controller,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Info Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // User Avatar
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: widget.post.userAvatarUrl != null 
                      ? NetworkImage(widget.post.userAvatarUrl!) 
                      : null,
                  child: widget.post.userAvatarUrl == null
                      ? const Icon(Icons.person, size: 18)
                      : null,
                ),
                const SizedBox(width: 8),
                
                // Title and User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'by ${widget.post.userName}',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            widget.post.mealType.icon,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateTime(widget.post.createdAt),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Description
          if (widget.post.description != null && widget.post.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                widget.post.description!,
                style: const TextStyle(fontSize: 15),
              ),
            ),

          // Photo
          if (widget.post.photoUrls.isNotEmpty)
            CachedNetworkImage(
              imageUrl: widget.post.photoUrls.first,
              width: double.infinity,
              height: 225,
              fit: BoxFit.cover,
            ),

          // Metrics Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMetric(
                      'Cook Time',
                      '${widget.post.cookTime}min',
                      Icons.timer_outlined,
                    ),
                    _buildMetric(
                      'Calories',
                      '${widget.post.calories}',
                      Icons.local_fire_department_outlined,
                    ),
                    _buildMetric(
                      'Protein',
                      '${widget.post.protein}g',
                      Icons.fitness_center_outlined,
                    ),
                    if (widget.post.isVegetarian)
                      _buildMetric(
                        'CO₂ Saved',
                        '${widget.post.carbonSaved}kg',
                        Icons.eco_outlined,
                      ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Action Buttons
                Row(
                  children: [
                    // Like Button with Animation
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: IconButton(
                        icon: Icon(
                          widget.post.likedBy.contains(
                            FirebaseAuth.instance.currentUser?.uid
                          ) 
                              ? Icons.thumb_up
                              : Icons.thumb_up_outlined,
                          color: widget.post.likedBy.contains(
                            FirebaseAuth.instance.currentUser?.uid
                          )
                              ? Theme.of(context).primaryColor
                              : Colors.grey[600],
                          size: 20,
                        ),
                        onPressed: _handleLike,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    Text(
                      widget.post.likesCount.toString(),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 16),
                    
                    // Comment Button
                    IconButton(
                      icon: Icon(Icons.chat_bubble_outline, color: Colors.grey[600]),
                      onPressed: _showComments,
                    ),
                    Text(
                      widget.post.commentsCount.toString(),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return 'Today at ${DateFormat('h:mm a').format(dateTime)}';
  }

  Widget _buildMetric(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// Add this new widget for comments
class CommentsSection extends StatefulWidget {
  final String postId;
  final ScrollController scrollController;

  const CommentsSection({
    super.key,
    required this.postId,
    required this.scrollController,
  });

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final TextEditingController _commentController = TextEditingController();

  // Add this list of quick comments
  final List<String> _quickComments = [
    "Looks delicious! 😋",
    "Great recipe! 👨‍🍳",
    "Need to try this! 🔥",
    "Yummy! 😍",
    "Well done! 👏",
    "Making this ASAP! ⭐️",
  ];

  Future<void> _addComment() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _commentController.text.trim().isEmpty) return;

    try {
      final commentRef = FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(widget.postId)
          .collection('comments')
          .doc();

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      await commentRef.set({
        'userId': currentUser.uid,
        'userName': userDoc.data()?['displayName'] ?? 'Anonymous',
        'userAvatar': userDoc.data()?['avatarUrl'],
        'text': _commentController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'likedBy': [],
        'likesCount': 0,
      });

      // Update comment count
      await FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(widget.postId)
          .update({
        'commentsCount': FieldValue.increment(1),
      });

      _commentController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error posting comment: ${e.toString()}')),
      );
    }
  }

  // Add this method to handle quick comment selection
  void _addQuickComment(String comment) async {
    _commentController.text = comment;
    await _addComment();
  }

  String _getTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  Future<void> _handleCommentLike(String commentId, bool isLiked) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final commentRef = FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId);

      if (isLiked) {
        await commentRef.update({
          'likedBy': FieldValue.arrayRemove([currentUser.uid]),
          'likesCount': FieldValue.increment(-1),
        });
      } else {
        await commentRef.update({
          'likedBy': FieldValue.arrayUnion([currentUser.uid]),
          'likesCount': FieldValue.increment(1),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating like: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Comments Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                'Comments',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Comments List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('meal_posts')
                .doc(widget.postId)
                .collection('comments')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final comments = snapshot.data?.docs ?? [];

              return ListView.builder(
                controller: widget.scrollController,
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index].data() as Map<String, dynamic>;
                  final timestamp = comment['timestamp'];
                  final commentId = comments[index].id;
                  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                  final likedBy = List<String>.from(comment['likedBy'] ?? []);
                  final isLiked = currentUserId != null && likedBy.contains(currentUserId);
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: comment['userAvatar'] != null
                          ? NetworkImage(comment['userAvatar'])
                          : null,
                      child: comment['userAvatar'] == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Row(
                      children: [
                        Text(comment['userName'] ?? 'Anonymous'),
                        const SizedBox(width: 8),
                        Text(
                          timestamp != null 
                              ? _getTimeAgo(timestamp as Timestamp)
                              : 'now',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(comment['text'] ?? ''),
                        if ((comment['likesCount'] ?? 0) > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${comment['likesCount']} ${(comment['likesCount'] ?? 0) == 1 ? 'like' : 'likes'}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : Colors.grey[600],
                        size: 20,
                      ),
                      onPressed: () => _handleCommentLike(commentId, isLiked),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Add Quick Comments Section
        Container(
          height: 50,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _quickComments.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ElevatedButton(
                  onPressed: () => _addQuickComment(_quickComments[index]),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(_quickComments[index]),
                ),
              );
            },
          ),
        ),

        // Existing Comment Input
        Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    hintText: 'Add a comment...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _addComment,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
} 