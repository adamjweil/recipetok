import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/custom_cache_manager.dart';
import './save_options_modal.dart';
import 'package:rxdart/rxdart.dart';

class VideoCard extends StatefulWidget {
  final Map<String, dynamic> videoData;
  final VoidCallback onUserTap;
  final String videoId;
  final VoidCallback? onVideoPlay;
  final VoidCallback? onLike;
  final VoidCallback? onBookmark;
  final String? currentUserId;

  const VideoCard({
    super.key,
    required this.videoData,
    required this.onUserTap,
    required this.videoId,
    this.onVideoPlay,
    this.onLike,
    this.onBookmark,
    this.currentUserId,
  });

  @override
  State<VideoCard> createState() => VideoCardState();
}

class VideoCardState extends State<VideoCard> {
  VideoPlayerController? _videoController;
  VideoPlayerController? _nextVideoController;
  bool _isInitialized = false;
  bool _hasRecordedView = false;
  int? _nextIndex;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _videoController?.pause();
    _videoController?.dispose();
    _nextVideoController?.pause();
    _nextVideoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    if (!mounted) return;
    
    final videoUrl = widget.videoData['videoUrl'] as String?;
    if (videoUrl == null || videoUrl.isEmpty) return;

    try {
      _videoController = VideoPlayerController.network(videoUrl);
      await _videoController?.initialize();
      
      if (mounted) {
        _videoController?.setLooping(true);
        _videoController?.setVolume(0.0);
        setState(() {
          _isInitialized = true;
        });
        
        // Auto-play the first video
        _videoController?.play();
        
        _preloadNextVideo();
      }
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  Future<void> _preloadNextVideo() async {
    try {
      final nextVideoSnapshot = await FirebaseFirestore.instance
          .collection('videos')
          .orderBy('createdAt', descending: true)
          .where('createdAt', isLessThan: widget.videoData['createdAt'])
          .limit(1)
          .get();

      if (nextVideoSnapshot.docs.isNotEmpty) {
        final nextVideoData = nextVideoSnapshot.docs.first.data();
        final nextVideoUrl = nextVideoData['videoUrl'] as String?;
        
        if (nextVideoUrl != null && nextVideoUrl.isNotEmpty) {
          _nextVideoController = VideoPlayerController.network(nextVideoUrl);
          await _nextVideoController?.initialize();
          _nextVideoController?.setVolume(0);
          _nextVideoController?.setLooping(true);
        }
      }
    } catch (e) {
      print('Error preloading next video: $e');
    }
  }

  void _switchToNextVideo() {
    if (!mounted) return;
    if (_nextVideoController != null) {
      _videoController?.pause();
      _videoController?.dispose();
      
      _videoController = _nextVideoController;
      _nextVideoController = null;
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
      _preloadNextVideo();
    }
  }

  void togglePlay() {
    if (!_isInitialized || !mounted) return;

    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
    } else {
      _videoController!.play();
      if (!_hasRecordedView) {
        _recordView();
      }
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  // Add this method to play video directly
  void playVideo() {
    if (_isInitialized && mounted && !_videoController!.value.isPlaying) {
      _videoController!.play();
      if (!_hasRecordedView) {
        _recordView();
      }
    }
  }

  // Update the pauseVideo method
  void pauseVideo() {
    if (_isInitialized && mounted && _videoController!.value.isPlaying) {
      _videoController!.pause();
    }
  }

  Future<void> _recordView() async {
    if (!mounted) return;
    
    try {
      final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (currentUserId.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoId)
          .update({
        'views': FieldValue.increment(1),
      });

      if (mounted) {
        setState(() => _hasRecordedView = true);
        widget.onVideoPlay?.call();
      }
    } catch (e) {
      print('Error recording view: $e');
    }
  }

  Future<void> _handleLike(BuildContext context) async {
    try {
      final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (currentUserId.isEmpty) return;

      final videoRef = FirebaseFirestore.instance.collection('videos').doc(widget.videoId);
      final userLikesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('likes')
          .doc(widget.videoId);

      final likeDoc = await userLikesRef.get();
      final bool isLiked = likeDoc.exists;

      if (isLiked) {
        await videoRef.update({
          'likes': FieldValue.increment(-1),
        });
        await userLikesRef.delete();
      } else {
        await videoRef.update({
          'likes': FieldValue.increment(1),
        });
        await userLikesRef.set({
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _toggleBookmark(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SaveOptionsModal(
        videoId: widget.videoId,
        videoData: widget.videoData,
        currentUserId: widget.currentUserId ?? '',
      ),
    );
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(
        videoId: widget.videoId,
        videoData: widget.videoData,
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: color),
          onPressed: onTap,
        ),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_isInitialized)
          GestureDetector(
            onTap: togglePlay,
            child: VideoPlayer(_videoController!),
          )
        else
          _buildPlaceholder(),

        // Video Info Overlay
        Positioned(
          left: 16,
          right: 100,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.videoData['title'] ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.videoData['description'] ?? '',
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                (widget.videoData['ingredients'] as List?)?.join(', ') ?? '',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),

        // Action Buttons
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.currentUserId)
                    .collection('videoLikes')
                    .doc(widget.videoId)
                    .snapshots(),
                builder: (context, snapshot) {
                  final isLiked = snapshot.data?.exists ?? false;
                  return Column(
                    children: [
                      IconButton(
                        icon: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.white,
                        ),
                        onPressed: widget.onLike,
                      ),
                      Text(
                        '${widget.videoData['likes'] ?? 0}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              StreamBuilder<bool>(
                stream: Rx.combineLatest2(
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.currentUserId)
                      .collection('bookmarks')
                      .doc(widget.videoId)
                      .snapshots(),
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.currentUserId)
                      .collection('groups')
                      .snapshots(),
                  (DocumentSnapshot bookmarkDoc, QuerySnapshot groupsSnapshot) {
                    final isBookmarked = bookmarkDoc.exists;
                    
                    // Check if video exists in any group
                    final isInGroup = groupsSnapshot.docs.any((groupDoc) {
                      final groupData = groupDoc.data() as Map<String, dynamic>;
                      final videos = groupData['videos'] as Map<String, dynamic>?;
                      return videos?.containsKey(widget.videoId) ?? false;
                    });
                    
                    // Return true if either bookmarked OR in any group
                    return isBookmarked || isInGroup;
                  },
                ).distinct(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    print('Bookmark stream error: ${snapshot.error}');
                    return const Icon(Icons.error, color: Colors.red);
                  }

                  final isSaved = snapshot.data ?? false;
                  
                  return IconButton(
                    icon: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => SaveOptionsModal(
                          videoId: widget.videoId,
                          videoData: widget.videoData,
                          currentUserId: widget.currentUserId ?? '',
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildActionButton(
                icon: Icons.remove_red_eye,
                label: '${widget.videoData['views'] ?? 0}',
                onTap: () {},
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('videos')
                    .doc(widget.videoId)
                    .collection('comments')
                    .snapshots(),
                builder: (context, snapshot) {
                  final commentCount = snapshot.data?.docs.length ?? 0;
                  return _buildActionButton(
                    icon: Icons.comment,
                    label: '$commentCount',
                    onTap: () => _showComments(context),
                    color: Colors.white,
                  );
                },
              ),
            ],
          ),
        ),

        if (!_isInitialized || !_videoController!.value.isPlaying)
          Center(
            child: IconButton(
              icon: Icon(
                _isInitialized ? Icons.play_circle_outline : Icons.error_outline,
                size: 64,
                color: Colors.white70,
              ),
              onPressed: _isInitialized ? togglePlay : null,
            ),
          ),

        // Add volume control button
        Positioned(
          left: 16,
          bottom: 120,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isMuted = !_isMuted;
                _videoController?.setVolume(_isMuted ? 0.0 : 1.0);
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isMuted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    final thumbnailUrl = widget.videoData['thumbnailUrl'] as String?;
    
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: thumbnailUrl,
        fit: BoxFit.cover,
        cacheManager: CustomCacheManager.instance,
        placeholder: (context, url) => Container(
          color: Colors.grey[900],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => _buildErrorPlaceholder(),
      );
    }
    
    return _buildErrorPlaceholder();
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'Video thumbnail not available',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Make _videoController accessible
  VideoPlayerController? get videoController => _videoController;
}

class CommentsSheet extends StatefulWidget {
  final String videoId;
  final Map<String, dynamic> videoData;

  const CommentsSheet({
    super.key,
    required this.videoId,
    required this.videoData,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Add this list of quick comments
  final List<String> quickComments = [
    "Looks delicious! 😋",
    "Great recipe! 👨‍🍳",
    "Can't wait to try this! 🔥",
    "Amazing work! ⭐️",
    "Thanks for sharing! 🙏",
    "Saved for later! 📌",
  ];

  // Add this method to handle quick comment selection
  void _insertQuickComment(String comment) {
    final currentText = _commentController.text;
    final currentPosition = _commentController.selection.baseOffset;
    final newPosition = currentPosition + comment.length;

    if (currentText.isEmpty) {
      _commentController.text = comment;
    } else {
      final beforeCursor = currentText.substring(0, currentPosition);
      final afterCursor = currentText.substring(currentPosition);
      _commentController.text = beforeCursor + comment + afterCursor;
    }

    _commentController.selection = TextSelection.collapsed(offset: newPosition);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _firestore
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .add({
        'text': _commentController.text.trim(),
        'userId': user.uid,
        'username': user.displayName ?? 'User',
        'userImage': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
      });

      _commentController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting comment: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Comments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('videos')
                  .doc(widget.videoId)
                  .collection('comments')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final comments = snapshot.data?.docs ?? [];

                if (comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No comments yet',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to comment!',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index].data() as Map<String, dynamic>;
                    final commentId = comments[index].id;
                    final dateTime = (comment['createdAt'] as Timestamp?)?.toDate();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: comment['userImage'] != null
                                ? NetworkImage(comment['userImage'])
                                : null,
                            child: comment['userImage'] == null
                                ? const Icon(Icons.person, color: Colors.grey)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comment['username'] ?? 'Anonymous',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(comment['text'] ?? ''),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      _getTimeAgo(dateTime),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    StreamBuilder<DocumentSnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(currentUserId)
                                          .collection('commentLikes')
                                          .doc(commentId)
                                          .snapshots(),
                                      builder: (context, snapshot) {
                                        final isLiked = snapshot.data?.exists ?? false;
                                        return Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () => _toggleCommentLike(commentId),
                                              child: Icon(
                                                isLiked ? Icons.favorite : Icons.favorite_border,
                                                size: 16,
                                                color: isLiked ? Colors.red : Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${comment['likes'] ?? 0}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
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
                  },
                );
              },
            ),
          ),

          // Add Quick Comments Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                top: BorderSide(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Quick Comments',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: quickComments.map((comment) {
                    return InkWell(
                      onTap: () => _insertQuickComment(comment),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(context).primaryColor.withOpacity(0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          comment,
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Comment Input Section
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  offset: const Offset(0, -1),
                  spreadRadius: 1,
                  blurRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
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
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded),
                  onPressed: _postComment,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';
    final difference = DateTime.now().difference(dateTime);
    
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

  Future<void> _toggleCommentLike(String commentId) async {
    try {
      final commentRef = _firestore
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .doc(commentId);

      final userLikeRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('commentLikes')
          .doc(commentId);

      final likeDoc = await userLikeRef.get();
      final isLiked = likeDoc.exists;

      if (isLiked) {
        await commentRef.update({
          'likes': FieldValue.increment(-1),
        });
        await userLikeRef.delete();
      } else {
        await commentRef.update({
          'likes': FieldValue.increment(1),
        });
        await userLikeRef.set({
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
} 