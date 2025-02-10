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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Auto-focus and show keyboard
    Future.delayed(const Duration(milliseconds: 300), () {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
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

      final commentRef = FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(widget.post.id)
          .collection('comments')
          .doc();

      await commentRef.set({
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'text': _commentController.text.trim(),
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'isPinned': false,
      });

      if (mounted) {
        _commentController.clear();
        setState(() => _selectedImage = null);
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
          
          // Comment input section
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildPinnedPost() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with back button
            Row(
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
            // Compact post preview
            _buildCompactPost(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactPost() {
    return Container(
      padding: const EdgeInsets.all(12),
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
          // Left column: User Avatar
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.post.userId)
                .snapshots(),
            builder: (context, snapshot) {
              final userData = snapshot.data?.data() as Map<String, dynamic>?;
              return GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/profile/${widget.post.userId}');
                },
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: userData?['avatarUrl'] != null
                      ? CachedNetworkImageProvider(userData!['avatarUrl'])
                      : null,
                  child: userData?['avatarUrl'] == null
                      ? const Icon(Icons.person, size: 16)
                      : null,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          
          // Middle column: Image
          if (widget.post.photoUrls.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 70,  // Reduced size
                height: 70, // Reduced size
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
                  Text(
                    widget.post.description!,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,  // Reduced max lines
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    LikeButton(
                      postId: widget.post.id,
                      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                    ),
                    const SizedBox(width: 8),
                    // Likes avatars and count
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('meal_posts')
                          .doc(widget.post.id)
                          .collection('likes')
                          .limit(3)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const SizedBox();  // Return empty widget if no likes
                        }
                        
                        final likes = snapshot.data!.docs;
                        final likeCount = likes.length;

                        return Row(
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(widget.post.id)
          .collection('comments')
          .orderBy('isPinned', descending: true)
          .orderBy('timestamp', descending: true)
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
          padding: const EdgeInsets.only(bottom: 80), // Space for input field
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index].data() as Map<String, dynamic>;
            final commentId = comments[index].id;
            final isPinned = comment['isPinned'] ?? false;
            
            // Handle null timestamp by using current time as fallback
            final timestamp = comment['timestamp'] as Timestamp?;
            final dateTime = timestamp?.toDate() ?? DateTime.now();
            
            return _CommentItem(
              key: ValueKey(commentId),
              commentId: commentId,
              postId: widget.post.id,
              userId: comment['userId'] as String,
              text: comment['text'] as String,
              imageUrl: comment['imageUrl'] as String?,
              timestamp: dateTime,  // Use the handled timestamp
              isPinned: isPinned,
              isPostOwner: widget.post.userId == FirebaseAuth.instance.currentUser?.uid,
              onPin: () => _togglePinComment(commentId, isPinned),
              onDelete: () => _deleteComment(commentId),
              animationController: _animationController,
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
      padding: MediaQuery.of(context).viewInsets.bottom > 0
          ? EdgeInsets.zero
          : const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedImage != null)
              Container(
                height: 80,
                padding: const EdgeInsets.all(8),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_selectedImage!.path),
                        height: 64,
                        width: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() => _selectedImage = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.photo_library_outlined),
                    onPressed: _pickImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      maxLines: null,
                    ),
                  ),
                  IconButton(
                    icon: _isPostingComment
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    onPressed: _isPostingComment ? null : _postComment,
                  ),
                ],
              ),
            ),
          ],
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
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .snapshots(),
            builder: (context, snapshot) {
              final userData = snapshot.data?.data() as Map<String, dynamic>?;
              final isCurrentUser = widget.userId == FirebaseAuth.instance.currentUser?.uid;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Avatar
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/profile/${widget.userId}');
                      },
                      child: CircleAvatar(
                        radius: 14,
                        backgroundImage: userData?['avatarUrl'] != null
                            ? CachedNetworkImageProvider(userData!['avatarUrl'])
                            : null,
                        child: userData?['avatarUrl'] == null
                            ? const Icon(Icons.person, size: 14)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Comment Content
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
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
                          children: [
                            // Username and Pin/Delete Options
                            Row(
                              children: [
                                Text(
                                  userData?['username'] ?? 'Unknown User',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                if (widget.isPinned) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.push_pin,
                                    size: 14,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ],
                                const Spacer(),
                                if (isCurrentUser || widget.isPostOwner)
                                  PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    icon: Icon(
                                      Icons.more_vert,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    itemBuilder: (context) => [
                                      if (widget.isPostOwner)
                                        PopupMenuItem(
                                          value: 'pin',
                                          child: Row(
                                            children: [
                                              Icon(
                                                widget.isPinned
                                                    ? Icons.push_pin_outlined
                                                    : Icons.push_pin,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                widget.isPinned
                                                    ? 'Unpin'
                                                    : 'Pin',
                                              ),
                                            ],
                                          ),
                                        ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.delete_outline,
                                              size: 16,
                                              color: Colors.red,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Delete',
                                              style: TextStyle(color: Colors.red),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onSelected: (value) {
                                      if (value == 'pin') {
                                        widget.onPin();
                                      } else if (value == 'delete') {
                                        widget.onDelete();
                                      }
                                    },
                                  ),
                              ],
                            ),
                            
                            // Comment Text
                            if (widget.text.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.text,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                            
                            // Comment Image
                            if (widget.imageUrl != null) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: widget.imageUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[200],
                                    height: 150,
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.grey[200],
                                    height: 150,
                                    child: const Icon(Icons.error),
                                  ),
                                ),
                              ),
                            ],
                            
                            // Timestamp
                            const SizedBox(height: 4),
                            Text(
                              getTimeAgo(widget.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
} 