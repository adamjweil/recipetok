import 'dart:async';
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
  late int _localLikeCount;
  late bool _localIsLiked;
  late int _localViewCount;

  // Add stream subscription
  StreamSubscription<DocumentSnapshot>? _likeSubscription;

  @override
  void initState() {
    super.initState();
    _localViewCount = widget.videoData['views'] ?? 0;
    _localLikeCount = widget.videoData['likes'] ?? 0;
    _localIsLiked = false;
    _initializeVideo();
    _initializeLikeStream();
  }

  void _initializeLikeStream() {
    _likeSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .collection('videoLikes')
        .doc(widget.videoId)
        .snapshots()
        .listen((snapshot) {
      if (mounted && _localIsLiked != snapshot.exists) {
        setState(() {
          _localIsLiked = snapshot.exists;
        });
      }
    });
  }

  @override
  void dispose() {
    _likeSubscription?.cancel();
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
        
        // Just play the video, view will be recorded when playVideo is called
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

  void playVideo() {
    if (_isInitialized && mounted) {
      _videoController!.play();
      // Always try to record the view when explicitly playing
      _recordView();
    }
  }

  // Update the pauseVideo method
  void pauseVideo() {
    if (_isInitialized && mounted && _videoController!.value.isPlaying) {
      _videoController!.pause();
    }
  }

  Future<void> _recordView() async {
    if (!mounted || _hasRecordedView) return;
    
    try {
      final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (currentUserId.isEmpty) return;

      // Update local state immediately
      setState(() {
        _localViewCount += 1;
        _hasRecordedView = true;
      });

      // Update Firestore in the background
      unawaited(
        FirebaseFirestore.instance
            .collection('videos')
            .doc(widget.videoId)
            .update({
          'views': FieldValue.increment(1),
        }).then((_) {
          widget.onVideoPlay?.call();
        }).catchError((e) {
          print('Error recording view: $e');
        })
      );
    } catch (e) {
      print('Error recording view: $e');
    }
  }

  Future<void> _handleLike() async {
    setState(() {
      _localIsLiked = !_localIsLiked;
      _localLikeCount += _localIsLiked ? 1 : -1;
    });

    widget.onLike?.call();
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

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final aspectRatio = _videoController!.value.aspectRatio;
    
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Video
          Center(
            child: GestureDetector(
              onTap: togglePlay,
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: Stack(
                  children: [
                    VideoPlayer(_videoController!),
                    if (!_videoController!.value.isPlaying)
                      Container(
                        color: Colors.black26,
                        child: const Center(
                          child: Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 64,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Interaction buttons - vertical column on right
          Positioned(
            right: 8,
            bottom: 0, // Increased the bottom value to move buttons down
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Like button - simplified without StreamBuilder
                    _buildActionButton(
                      icon: _localIsLiked ? Icons.favorite : Icons.favorite_border,
                      label: '$_localLikeCount',
                      onTap: _handleLike,
                      color: _localIsLiked ? Colors.red : Colors.white,
                    ),
                    const SizedBox(height: 16),

                    // Comments button
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
                    const SizedBox(height: 16),

                    // Bookmark button
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
                          final isInGroup = groupsSnapshot.docs.any((groupDoc) {
                            final groupData = groupDoc.data() as Map<String, dynamic>;
                            final videos = groupData['videos'] as Map<String, dynamic>?;
                            return videos?.containsKey(widget.videoId) ?? false;
                          });
                          return isBookmarked || isInGroup;
                        },
                      ).distinct(),
                      builder: (context, snapshot) {
                        final isSaved = snapshot.data ?? false;
                        return _buildActionButton(
                          icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                          label: '',
                          onTap: () => _toggleBookmark(context),
                          color: Colors.white,
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Views count
                    _buildActionButton(
                      icon: Icons.remove_red_eye,
                      label: '$_localViewCount',
                      onTap: () {},
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              if (label.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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