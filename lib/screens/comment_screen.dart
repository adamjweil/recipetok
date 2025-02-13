import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/meal_post.dart';
import '../widgets/meal_post/like_button.dart';
import '../utils/custom_cache_manager.dart';
import 'dart:io';
import '../utils/time_formatter.dart';
import './profile_screen.dart';

class CommentScreen extends StatefulWidget {
  final MealPost post;

  const CommentScreen({
    super.key,
    required this.post,
  });

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  XFile? _selectedImage;
  late AnimationController _animationController;
  bool _isPostingComment = false;

  // Add this list at the top of the class
  final List<String> _quickComments = [
    "Damn bro, nice meal! 🔥",
    "Those gains incoming 💪",
    "Meal prep on point! 👊",
    "Macros looking clean bro",
    "This is the whey 🏋️‍♂️",
    "Absolute unit of a meal 😤",
    "Chef mode activated 👨‍🍳",
    "Protein game strong 💯",
    "Eating like a champion 🏆",
    "Beast mode fuel right there",
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Add listener to text controller
    _commentController.addListener(() {
      setState(() {}); // Trigger rebuild when text changes
    });
    // Auto-focus and show keyboard
    Future.delayed(const Duration(milliseconds: 300), () {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _commentController.removeListener(() { setState(() {}); }); // Clean up listener
    _commentController.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty && _selectedImage == null) return;
    setState(() => _isPostingComment = true);

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        // Upload image logic here
        // imageUrl = await uploadImage(_selectedImage!);
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Create references
      final postRef = FirebaseFirestore.instance.collection('meal_posts').doc(widget.post.id);
      final commentRef = postRef.collection('comments').doc();

      // Use a transaction to update both the comment and the post's comment count
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Get the current post data
        final postDoc = await transaction.get(postRef);
        final currentComments = postDoc.data()?['commentsCount'] ?? 0;

        // Create the comment with all required fields
        transaction.set(commentRef, {
          'userId': currentUser.uid,
          'text': _commentController.text.trim(),
          'imageUrl': imageUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'isPinned': false,
          'displayName': currentUser.displayName ?? 'User',
          'avatarUrl': currentUser.photoURL,
        });

        // Update the post's comment count
        transaction.update(postRef, {
          'commentsCount': currentComments + 1
        });
      });

      if (mounted) {
        _commentController.clear();
        setState(() {
          _selectedImage = null;
          _isPostingComment = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting comment: $e')),
        );
      }
      setState(() => _isPostingComment = false);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Top pinned post section
          _buildPinnedPost(),
          
          // Comments section
          Expanded(
            child: _buildCommentsList(),
          ),
          
          // Comment input section at bottom
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildPinnedPost() {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with back button
          SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Compact post preview
          _buildCompactPost(),
        ],
      ),
    );
  }

  Widget _buildCompactPost() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(widget.post.id)
          .snapshots(),
      builder: (context, postSnapshot) {
        final postData = postSnapshot.data?.data() as Map<String, dynamic>?;
        final totalLikes = postData?['likes'] ?? widget.post.likes;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Middle column: Image
              if (widget.post.photoUrls.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60,  // Slightly reduced size
                    height: 60, // Slightly reduced size
                    child: CachedNetworkImage(
                      imageUrl: widget.post.photoUrls.first,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.error),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              
              // Right column: Description and Buttons
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.post.description != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          widget.post.description!,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        LikeButton(
                          postId: widget.post.id,
                          userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                          onLikeToggle: _toggleLike,
                        ),
                        const SizedBox(width: 8),
                        // Likes avatars and count
                        Expanded(
                          child: Row(
                            children: [
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('meal_posts')
                                    .doc(widget.post.id)
                                    .collection('likes')
                                    .limit(3)
                                    .snapshots(),
                                builder: (context, likesSnapshot) {
                                  if (!likesSnapshot.hasData || likesSnapshot.data!.docs.isEmpty) {
                                    return const SizedBox(width: 0, height: 24);
                                  }
                                  
                                  final likes = likesSnapshot.data!.docs;
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Overlapping avatars
                                      SizedBox(
                                        width: likes.length * 16.0,
                                        height: 24,
                                        child: Stack(
                                          children: likes.asMap().entries.map((entry) {
                                            final index = entry.key;
                                            final like = entry.value;
                                            return Positioned(
                                              left: index * 12.0,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: StreamBuilder<DocumentSnapshot>(
                                                  stream: FirebaseFirestore.instance
                                                      .collection('users')
                                                      .doc(like.id)
                                                      .snapshots(),
                                                  builder: (context, userSnapshot) {
                                                    final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                                                    return CircleAvatar(
                                                      radius: 9,
                                                      backgroundColor: Colors.grey[200],
                                                      backgroundImage: (userData?['avatarUrl'] != null && 
                                                          userData!['avatarUrl'].toString().isNotEmpty &&
                                                          CustomCacheManager.isValidImageUrl(userData['avatarUrl']))
                                                          ? CachedNetworkImageProvider(
                                                              userData['avatarUrl'],
                                                              cacheManager: CustomCacheManager.instance,
                                                            )
                                                          : null,
                                                      child: (userData?['avatarUrl'] == null || 
                                                          userData!['avatarUrl'].toString().isEmpty ||
                                                          !CustomCacheManager.isValidImageUrl(userData['avatarUrl']))
                                                          ? Icon(Icons.person, size: 11, color: Colors.grey[400])
                                                          : null,
                                                    );
                                                  },
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Like count text
                                      if (totalLikes <= 2)
                                        FutureBuilder<List<String>>(
                                          future: Future.wait(
                                            likes.map((like) async {
                                              final userDoc = await FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(like.id)
                                                  .get();
                                              return userDoc.data()?['firstName'] ?? 'Unknown';
                                            }),
                                          ),
                                          builder: (context, namesSnapshot) {
                                            if (!namesSnapshot.hasData) {
                                              return Text(
                                                '$totalLikes gave props',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.grey[600],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            }

                                            final names = namesSnapshot.data!;
                                            if (names.length == 1) {
                                              return Text(
                                                '${names[0]} gave props',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.grey[600],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            } else {
                                              return Text(
                                                '${names[0]} and ${names[1]} gave props',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.grey[600],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            }
                                          },
                                        )
                                      else
                                        Text(
                                          '$totalLikes gave props',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.grey[600],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  );
                                },
                              ),
                              const Spacer(),
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
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(widget.post.id)
          .collection('comments')
          .orderBy('isPinned', descending: true)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final comments = snapshot.data!.docs;
        
        if (comments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No comments yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index].data() as Map<String, dynamic>;
            final commentId = comments[index].id;
            final isPinned = comment['isPinned'] ?? false;
            
            final timestamp = comment['createdAt'] as Timestamp?;
            final dateTime = timestamp?.toDate() ?? DateTime.now();
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // User info column - anchored to the left
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: 56,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(comment['userId'] as String)
                                .snapshots(),
                            builder: (context, userSnapshot) {
                              final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProfileScreen(userId: comment['userId'] as String),
                                    ),
                                  );
                                },
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: (userData?['avatarUrl'] != null && 
                                      userData!['avatarUrl'].toString().isNotEmpty &&
                                      CustomCacheManager.isValidImageUrl(userData['avatarUrl']))
                                      ? CachedNetworkImageProvider(
                                          userData['avatarUrl'],
                                          cacheManager: CustomCacheManager.instance,
                                        )
                                      : null,
                                  child: (userData?['avatarUrl'] == null || 
                                      userData!['avatarUrl'].toString().isEmpty ||
                                      !CustomCacheManager.isValidImageUrl(userData['avatarUrl']))
                                      ? Icon(Icons.person, size: 16, color: Colors.grey[400])
                                      : null,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Comment bubble - expanded to fill remaining space
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: _CommentItem(
                        key: ValueKey(commentId),
                        commentId: commentId,
                        postId: widget.post.id,
                        userId: comment['userId'] as String,
                        text: comment['text'] as String,
                        imageUrl: comment['imageUrl'] as String?,
                        timestamp: dateTime,
                        isPinned: isPinned,
                        isPostOwner: widget.post.userId == FirebaseAuth.instance.currentUser?.uid,
                        onPin: () => _togglePinComment(commentId, isPinned),
                        onDelete: () => _deleteComment(commentId),
                        animationController: _animationController,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _togglePinComment(String commentId, bool currentPinState) async {
    try {
      await FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(widget.post.id)
          .collection('comments')
          .doc(commentId)
          .update({
        'isPinned': !currentPinState,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating comment: $e')),
        );
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(widget.post.id)
          .collection('comments')
          .doc(commentId)
          .delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting comment: $e')),
        );
      }
    }
  }

  Widget _buildCommentInput() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        maintainBottomViewPadding: true,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom > 0 ? 0 : 4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quick comments
              Container(
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _quickComments.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: TextButton(
                        onPressed: () {
                          _commentController.text = _quickComments[index];
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _quickComments[index],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Input field
              Container(
                color: Colors.white,
                padding: EdgeInsets.only(
                  left: 8,
                  right: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  top: 4,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(Icons.image_outlined, color: Colors.grey[600]),
                      onPressed: () {
                        // Handle image picking
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        maxLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _commentController.text.trim().isEmpty ? null : _postComment,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 32),
                      ),
                      child: Text(
                        'Post',
                        style: TextStyle(
                          color: _commentController.text.trim().isEmpty 
                              ? Colors.grey[400] 
                              : Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentItem extends StatefulWidget {
  final String commentId;
  final String postId;
  final String userId;
  final String text;
  final String? imageUrl;
  final DateTime timestamp;
  final bool isPinned;
  final bool isPostOwner;
  final VoidCallback onPin;
  final VoidCallback onDelete;
  final AnimationController animationController;

  const _CommentItem({
    Key? key,
    required this.commentId,
    required this.postId,
    required this.userId,
    required this.text,
    this.imageUrl,
    required this.timestamp,
    required this.isPinned,
    required this.isPostOwner,
    required this.onPin,
    required this.onDelete,
    required this.animationController,
  }) : super(key: key);

  @override
  State<_CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<_CommentItem> {
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeAnimation = CurvedAnimation(
      parent: widget.animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: widget.animationController,
      curve: Curves.easeOutQuad,
    ));
    widget.animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isPinned)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.push_pin,
                        size: 12,
                        color: Color(0xFFD32F2F),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pinned by author',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.text,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    getTimeAgo(widget.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (widget.isPostOwner || widget.userId == FirebaseAuth.instance.currentUser?.uid)
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.grey[600],
                      ),
                      itemBuilder: (context) => [
                        if (widget.isPostOwner)
                          PopupMenuItem(
                            value: 'pin',
                            child: Row(
                              children: [
                                Icon(
                                  widget.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(widget.isPinned ? 'Unpin' : 'Pin'),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: const [
                              Icon(Icons.delete_outline, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'pin') widget.onPin();
                        if (value == 'delete') widget.onDelete();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 