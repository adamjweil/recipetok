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

class VideoCardState extends State<VideoCard> with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoController;
  late AnimationController _animationController;
  bool _isInitialized = false;
  bool _hasRecordedView = false;
  bool _isMuted = true;
  late int _localLikeCount;
  late bool _localIsLiked;
  late int _localViewCount;
  bool _isIngredientsExpanded = false;
  bool _isInstructionsExpanded = false;
  bool _isFollowing = false;
  bool _isTryLater = false;
  StreamSubscription<DocumentSnapshot>? _likeSubscription;
  StreamSubscription<DocumentSnapshot>? _followSubscription;
  StreamSubscription<DocumentSnapshot>? _tryLaterSubscription;

  // Colors
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryColor = Color(0xFF424242);
  static const Color accentColor = Color(0xFFE91E63);

  @override
  void initState() {
    super.initState();
    _localViewCount = widget.videoData['views'] ?? 0;
    _localLikeCount = widget.videoData['likes'] ?? 0;
    _localIsLiked = false;
    _initializeVideo();
    _initializeLikeStream();
    _initializeFollowStream();
    _initializeTryLaterStream();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _likeSubscription?.cancel();
    _followSubscription?.cancel();
    _tryLaterSubscription?.cancel();
    _videoController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.network(widget.videoData['videoUrl']);
    try {
      await _videoController.initialize();
      setState(() {
        _isInitialized = true;
      });
      
      if (widget.autoPlay && mounted) {
        playVideo();
      }
    } catch (e) {
      print('Error initializing video: $e');
    }
  }

  void playVideo() {
    if (_isInitialized && mounted) {
      _videoController.play();
      _videoController.setLooping(true);
      if (!_hasRecordedView) {
        _recordView();
      }
    }
  }

  void pauseVideo() {
    if (_isInitialized && mounted) {
      _videoController.pause();
    }
  }

  @override
  void didUpdateWidget(VideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoPlay && !oldWidget.autoPlay && _isInitialized && mounted) {
      playVideo();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          color: primaryColor,
        ),
      );
    }

    return Container(
      color: backgroundColor,
      child: Column(
        children: [
          // Video Section with Overlay
          _buildVideoSection(),
          
          // Action Buttons
          _buildActionButtons(),
          
          // Content Sections
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Title and Description
                  _buildTitleSection(),
                  
                  // Ingredients and Instructions
                  _buildContentSections(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSection() {
    return Stack(
      children: [
        // Video Player
        Container(
          height: MediaQuery.of(context).size.height * 0.4,
          width: double.infinity,
          child: GestureDetector(
            onTap: () {
              if (_videoController.value.isPlaying) {
                _videoController.pause();
              } else {
                _videoController.play();
              }
            },
            child: VideoPlayer(_videoController),
          ),
        ),

        // User Info Overlay
        Positioned(
          left: 16,
          bottom: 16,
          right: 16,
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: widget.videoData['userImage'] != null
                    ? NetworkImage(widget.videoData['userImage'])
                    : null,
                child: widget.videoData['userImage'] == null
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.videoData['username'] ?? 'Anonymous',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${widget.videoData['userHandle'] ?? 'user'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.videoData['userId'] != widget.currentUserId) // Don't show follow button for own videos
                ElevatedButton(
                  onPressed: _toggleFollow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFollowing ? Colors.transparent : primaryColor,
                    foregroundColor: _isFollowing ? Colors.white70 : Colors.white,
                    elevation: _isFollowing ? 0 : 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: _isFollowing 
                          ? const BorderSide(color: Colors.white30)
                          : BorderSide.none,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: Text(_isFollowing ? 'Following' : 'Follow'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildAnimatedActionButton(
            icon: _localIsLiked ? Icons.favorite : Icons.favorite_border,
            label: '$_localLikeCount',
            color: _localIsLiked ? accentColor : secondaryColor,
            onTap: () {
              _handleLike();
              _animationController
                ..reset()
                ..forward();
            },
          ),
          _buildAnimatedActionButton(
            icon: Icons.comment_outlined,
            label: 'Comment',
            onTap: () => _showComments(context),
          ),
          _buildAnimatedActionButton(
            icon: _isTryLater ? Icons.bookmark : Icons.bookmark_border,
            label: 'Save',
            color: _isTryLater ? accentColor : secondaryColor,
            onTap: () => _toggleBookmark(context),
          ),
          _buildAnimatedActionButton(
            icon: Icons.remove_red_eye_outlined,
            label: '$_localViewCount',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = secondaryColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.9).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.videoData['title'] ?? 'Untitled Recipe',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: secondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.videoData['description'] ?? '',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSections() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          _buildExpandableSection(
            title: 'Ingredients',
            icon: Icons.restaurant_menu,
            isExpanded: _isIngredientsExpanded,
            onTap: () => setState(() => _isIngredientsExpanded = !_isIngredientsExpanded),
            child: _buildIngredientsList(),
          ),
          const SizedBox(height: 16),
          _buildExpandableSection(
            title: 'Instructions',
            icon: Icons.format_list_numbered,
            isExpanded: _isInstructionsExpanded,
            onTap: () => setState(() => _isInstructionsExpanded = !_isInstructionsExpanded),
            child: _buildInstructionsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, color: primaryColor),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: secondaryColor,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: secondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0),
            secondChild: child,
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsList() {
    final ingredients = (widget.videoData['ingredients'] as List<dynamic>?) ?? [];
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: ingredients.map<Widget>((ingredient) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ingredient.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInstructionsList() {
    final instructions = (widget.videoData['instructions'] as List<dynamic>?) ?? [];
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: instructions.asMap().entries.map<Widget>((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.value.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
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

  void _initializeFollowStream() {
    final String videoCreatorId = widget.videoData['userId'] ?? '';
    if (videoCreatorId.isEmpty) return;

    _followSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      
      final userData = snapshot.data() as Map<String, dynamic>?;
      final List following = userData?['following'] ?? [];
      final bool isFollowing = following.contains(videoCreatorId);
      
      if (_isFollowing != isFollowing) {
        setState(() {
          _isFollowing = isFollowing;
        });
      }
    });
  }

  void _initializeTryLaterStream() {
    _tryLaterSubscription = FirebaseFirestore.instance
        .collection('videos')
        .doc(widget.videoId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      
      final videoData = snapshot.data();
      if (videoData != null) {
        final List<dynamic> tryLaterBy = videoData['tryLaterBy'] ?? [];
        final bool isTryLater = tryLaterBy.contains(widget.currentUserId);
        
        if (_isTryLater != isTryLater) {
          setState(() {
            _isTryLater = isTryLater;
          });
        }
      }
    });
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

  Future<void> _toggleBookmark(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SaveOptionsModal(
        videoId: widget.videoId,
        videoData: widget.videoData,
        currentUserId: widget.currentUserId,
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

  Future<void> _toggleFollow() async {
    final String videoCreatorId = widget.videoData['userId'] ?? '';
    if (videoCreatorId.isEmpty || videoCreatorId == widget.currentUserId) return;

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId);
          
      final targetUserRef = FirebaseFirestore.instance
          .collection('users')
          .doc(videoCreatorId);

      if (_isFollowing) {
        // Unfollow
        await userRef.update({
          'following': FieldValue.arrayRemove([videoCreatorId])
        });
        await targetUserRef.update({
          'followers': FieldValue.arrayRemove([widget.currentUserId])
        });
      } else {
        // Follow
        await userRef.update({
          'following': FieldValue.arrayUnion([videoCreatorId])
        });
        await targetUserRef.update({
          'followers': FieldValue.arrayUnion([widget.currentUserId])
        });
      }
    } catch (e) {
      print('Error toggling follow: $e');
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