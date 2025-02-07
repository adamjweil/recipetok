import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/custom_cache_manager.dart';
import './save_options_modal.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:math' show max;

class VideoCard extends StatefulWidget {
  final Map<String, dynamic> videoData;
  final String videoId;
  final VoidCallback onUserTap;
  final VoidCallback onLike;
  final VoidCallback onBookmark;
  final String currentUserId;
  final bool autoPlay;

  const VideoCard({
    super.key,
    required this.videoData,
    required this.videoId,
    required this.onUserTap,
    required this.onLike,
    required this.onBookmark,
    required this.currentUserId,
    this.autoPlay = false,
  });

  @override
  State<VideoCard> createState() => VideoCardState();
}

class VideoCardState extends State<VideoCard> {
  late VideoPlayerController _videoController;
  bool _isInitialized = false;
  bool _hasRecordedView = false;
  int? _nextIndex;
  bool _isMuted = true;
  late int _localLikeCount;
  late bool _localIsLiked;
  late int _localViewCount;
  StreamSubscription<DocumentSnapshot>? _likeSubscription;
  bool _showIngredients = false;
  bool _showInstructions = false;
  bool _isPreloaded = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    print('Current user: ${user?.uid ?? 'Not authenticated'}');
    
    _localViewCount = _parseCount(widget.videoData['views']);
    _localLikeCount = _parseCount(widget.videoData['likes']);
    _localIsLiked = false;
    _initializeVideo();
    _initializeLikeStream();
  }

  int _parseCount(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is List) return value.length;
    return 0;
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
    print('Disposing video controller for ${widget.videoId}');
    _isPreloaded = false;
    _likeSubscription?.cancel();
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      if (_isInitialized) {
        print('Video already initialized: ${widget.videoId}');
        return;
      }
    
      final videoUrl = widget.videoData['videoUrl'];
      print('Starting video initialization for ${widget.videoId} from URL: $videoUrl');
    
      _videoController = VideoPlayerController.network(videoUrl);
      
      await _videoController.initialize();
      print('Video initialized successfully: ${widget.videoId}');
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        
        if (widget.autoPlay) {
          print('AutoPlaying video: ${widget.videoId}');
          _videoController.play();
          _videoController.setLooping(true);
          if (!_hasRecordedView) {
            _recordView();
          }
        }
      }
    } catch (e) {
      print('Error initializing video ${widget.videoId}: $e');
    }
  }

  void playVideo() {
    if (_isInitialized && mounted) {
      print('Playing video via playVideo: ${widget.videoId}');
      _videoController.play();
      _videoController.setLooping(true);
      if (!_hasRecordedView) {
        _recordView();
      }
    }
  }

  void pauseVideo() {
    if (_isInitialized && mounted) {
      print('Pausing video: ${widget.videoId}');
      _videoController.pause();
    }
  }

  @override
  void didUpdateWidget(VideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Add this to handle changes in autoPlay
    if (widget.autoPlay && !oldWidget.autoPlay && _isInitialized && mounted) {
      print('AutoPlay changed, playing video: ${widget.videoId}');
      playVideo();
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
            })
            .catchError((e) {
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

    widget.onLike.call();
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

    final aspectRatio = _videoController.value.aspectRatio;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      color: Colors.black,
      height: screenHeight,
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: screenHeight * 0.05),

            // Ingredients Panel (collapsible)
            if (widget.videoData['ingredients'] != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: _showIngredients ? null : 56,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.9),
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Make the header row tappable
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showIngredients = !_showIngredients;
                              });
                            },
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.restaurant_outlined,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Ingredients',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  _showIngredients 
                                    ? Icons.keyboard_arrow_up 
                                    : Icons.keyboard_arrow_down,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                          if (_showIngredients) ...[
                            const SizedBox(height: 8),
                            ...List<Widget>.from(
                              (widget.videoData['ingredients'] as List).map(
                                (ingredient) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).primaryColor.withOpacity(0.8),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            ingredient,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Video Section with Overlay Buttons
            Container(
              height: max(
                MediaQuery.of(context).size.width / aspectRatio,
                MediaQuery.of(context).size.height * 0.5,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AspectRatio(
                    aspectRatio: aspectRatio,
                    child: VideoPlayer(_videoController),
                  ),
                  
                  // Interaction buttons overlay
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _localIsLiked ? Icons.favorite : Icons.favorite_border,
                              color: _localIsLiked ? Colors.red : Colors.white,
                              size: 24,
                            ),
                            onPressed: _handleLike,
                          ),
                          Text(
                            '$_localLikeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.bookmark_border,
                              color: Colors.white,
                              size: 24,
                            ),
                            onPressed: () => _toggleBookmark(context),
                          ),
                          const SizedBox(height: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.comment,
                              color: Colors.white,
                              size: 24,
                            ),
                            onPressed: () => _showComments(context),
                          ),
                          Text(
                            '0',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Icon(
                            Icons.remove_red_eye,
                            color: Colors.white,
                            size: 24,
                          ),
                          Text(
                            '$_localViewCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Instructions Section (collapsible)
            if (widget.videoData['instructions'] != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: _showInstructions ? null : 56,
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  color: Colors.black,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Instructions Header - Always visible
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showInstructions = !_showInstructions;
                            });
                          },
                          child: Row(
                            children: [
                              const Icon(
                                Icons.menu_book_outlined,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Instructions',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                _showInstructions 
                                  ? Icons.keyboard_arrow_up 
                                  : Icons.keyboard_arrow_down,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                        // Instructions Content - Only visible when expanded
                        if (_showInstructions) ...[
                          const SizedBox(height: 12),
                          ...List<Widget>.from(
                            (widget.videoData['instructions'] as List)
                                .asMap()
                                .entries
                                .map((entry) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${entry.key + 1}.',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        entry.value.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

            SizedBox(height: screenHeight * 0.05),
          ],
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

  // Add this new public method
  bool isPlaying() {
    return _isInitialized && _videoController.value.isPlaying;
  }

  Future<void> preloadVideo() async {
    if (_isInitialized || _isPreloaded) return;
    
    try {
      print('Preloading video: ${widget.videoId}');
      final videoUrl = widget.videoData['videoUrl'];
      _videoController = VideoPlayerController.network(videoUrl);
      await _videoController.initialize();
      _isPreloaded = true;
      print('Successfully preloaded video: ${widget.videoId}');
    } catch (e) {
      print('Error preloading video ${widget.videoId}: $e');
    }
  }

  Future<void> initializeAndPlay() async {
    try {
      if (!_isInitialized && !_isPreloaded) {
        await _initializeVideo();
      } else if (_isPreloaded && !_isInitialized) {
        setState(() {
          _isInitialized = true;
        });
      }
      
      if (_isInitialized && mounted) {
        print('Playing video: ${widget.videoId}');
        await _videoController.play();
        _videoController.setLooping(true);
        if (!_hasRecordedView) {
          _recordView();
        }
      }
    } catch (e) {
      print('Error in initializeAndPlay: $e');
    }
  }
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