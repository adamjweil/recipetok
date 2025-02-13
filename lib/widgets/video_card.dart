import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/custom_cache_manager.dart';
import './save_options_modal.dart';
import 'package:rxdart/rxdart.dart';
import '../screens/profile_screen.dart';

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
  VideoPlayerController? _videoController;
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
  bool _isUserInfoVisible = true;
  Timer? _userInfoTimer;
  StreamSubscription<DocumentSnapshot>? _likeSubscription;
  StreamSubscription<DocumentSnapshot>? _followSubscription;
  StreamSubscription<DocumentSnapshot>? _tryLaterSubscription;
  String? _posterDisplayName;
  String? _posterImage;
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;
  bool _isDescriptionExpanded = false;
  late TextEditingController _commentController;

  // Colors
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryColor = Color(0xFF424242);
  static const Color accentColor = Color(0xFFE91E63);

  @override
  void initState() {
    super.initState();
    _localViewCount = widget.videoData['views'] ?? 0;
    
    // Handle both integer and list cases for likes
    final likesData = widget.videoData['likes'];
    if (likesData is List) {
      _localLikeCount = likesData.length;
      _localIsLiked = likesData.contains(widget.currentUserId);
    } else if (likesData is int) {
      _localLikeCount = likesData;
      _localIsLiked = false;
      _updateLikesFormat();
    } else {
      _localLikeCount = 0;
      _localIsLiked = false;
      _updateLikesFormat();
    }

    _initializeUserDataStream();
    _initializeVideo();
    _initializeLikeStream();
    _initializeFollowStream();
    _initializeTryLaterStream();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _startUserInfoTimer();
    _commentController = TextEditingController();
    _initializeCommentCount();

    // Add video position listener
    if (_videoController != null) {
      _videoController!.addListener(_onVideoProgressChanged);
    }
  }

  @override
  void dispose() {
    if (_videoController != null) {
      _videoController!.removeListener(_onVideoProgressChanged);
    }
    _videoController?.dispose();
    _animationController.dispose();
    _likeSubscription?.cancel();
    _followSubscription?.cancel();
    _tryLaterSubscription?.cancel();
    _userInfoTimer?.cancel();
    _userDataSubscription?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoPlay != oldWidget.autoPlay) {
      if (widget.autoPlay) {
        playVideo();
      } else {
        pauseVideo();
      }
    }
  }

  Future<void> _initializeVideo() async {
    if (_videoController != null) {
      await _videoController!.dispose();
    }

    _videoController = VideoPlayerController.network(
      widget.videoData['videoUrl'],
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    
    try {
      await _videoController!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        
        if (widget.autoPlay) {
          playVideo();
        }
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  void playVideo() {
    if (_isInitialized && mounted && _videoController != null) {
      _videoController!.play();
      _videoController!.setLooping(true);
      if (!_hasRecordedView) {
        _recordView();
      }
    }
  }

  void pauseVideo() {
    if (_isInitialized && mounted && _videoController != null) {
      _videoController!.pause();
    }
  }

  void _onVideoProgressChanged() {
    if (mounted) {
      setState(() {});  // Trigger rebuild to update progress bar
    }
  }

  Widget _buildProgressBar() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final Duration position = _videoController!.value.position;
    final Duration duration = _videoController!.value.duration;
    final double progress = position.inMilliseconds / duration.inMilliseconds;

    return Container(
      height: 4.5,
      width: MediaQuery.of(context).size.width,
      color: Colors.white.withOpacity(0.3), // Slightly more visible background
      child: Stack(
        children: [
          // Bright white progress bar
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              color: Colors.white, // Pure white color to match the text
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white,
                      blurRadius: 3.0,
                      spreadRadius: 0.5,
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

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _videoController == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: primaryColor,
        ),
      );
    }

    return Stack(
      children: [
        // Full screen video
        SizedBox(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: GestureDetector(
            onTap: () {
              if (_videoController!.value.isPlaying) {
                pauseVideo();
              } else {
                playVideo();
              }
            },
            child: VideoPlayer(_videoController!),
          ),
        ),

        // Progress bar at the bottom (moved up in the stack order)
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.of(context).padding.bottom, // Adjusted position to be at the very bottom
          child: _buildProgressBar(),
        ),

        // Top gradient for better visibility of top buttons
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 100,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Top buttons for ingredients and instructions
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 0,
          right: 0,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildOverlayButton(
                  icon: Icons.restaurant_menu,
                  label: 'Ingredients',
                  onTap: () => _toggleSection('ingredients'),
                  isActive: _isIngredientsExpanded,
                ),
                const SizedBox(width: 12),
                _buildOverlayButton(
                  icon: Icons.format_list_numbered,
                  label: 'Instructions',
                  onTap: () => _toggleSection('instructions'),
                  isActive: _isInstructionsExpanded,
                ),
              ],
            ),
          ),
        ),

        // Right side interaction buttons
        Positioned(
          right: 6,
          bottom: MediaQuery.of(context).size.height * 0.05,
          child: _buildInteractionButtons(),
        ),

        // Bottom user info with fade
        Positioned(
          left: 0,
          right: 0,
          bottom: 0, // Adjusted to be right above the progress bar
          child: _buildUserInfoSection(),
        ),

        // Sliding overlays for ingredients and instructions
        if (_isIngredientsExpanded)
          _buildSlidingOverlay(
            child: _buildIngredientsList(),
            onClose: () => setState(() => _isIngredientsExpanded = false),
          ),
        
        if (_isInstructionsExpanded)
          _buildSlidingOverlay(
            child: _buildInstructionsList(),
            onClose: () => setState(() => _isInstructionsExpanded = false),
          ),
      ],
    );
  }

  Widget _buildInteractionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildInteractionButton(
          icon: _localIsLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
          label: 'Like',
          count: _localLikeCount,
          onTap: _handleLike,
          isActive: _localIsLiked,
        ),
        const SizedBox(height: 20),
        _buildInteractionButton(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Comment',
          count: widget.videoData['commentCount'] ?? 0,
          onTap: () => _showComments(context),
        ),
        const SizedBox(height: 20),
        _buildInteractionButton(
          icon: _isTryLater ? Icons.bookmark : Icons.bookmark_outline_rounded,
          label: 'Save',
          count: widget.videoData['saveCount'] ?? 0,
          onTap: () => _toggleBookmark(context),
          isActive: _isTryLater,
        ),
      ],
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required String label,
    required int count,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final Color iconColor = isActive 
        ? const Color(0xFF2196F3) // Primary blue when active
        : const Color(0xFFFFFFFF); // Pure white when inactive
    
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              color: iconColor,
              size: 26,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 17, // Height of the text + some padding
          child: count > 0
              ? Text(
                  count.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildUserInfoSection() {
    final String displayName = _posterDisplayName ?? 'Anonymous';
    final String userId = widget.videoData['userId'] ?? '';
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isDescriptionExpanded = !_isDescriptionExpanded;
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              widget.videoData['title'] ?? 'Untitled Recipe',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                height: 1.1,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _isDescriptionExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_isDescriptionExpanded && widget.videoData['description'] != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    margin: EdgeInsets.only(right: MediaQuery.of(context).size.width * 0.2),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.videoData['description'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
                if (_isDescriptionExpanded && widget.videoData['description'] == null)
                  Container(
                    margin: EdgeInsets.only(right: MediaQuery.of(context).size.width * 0.2),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'No description available',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  if (userId.isNotEmpty) {
                    pauseVideo();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(
                          userId: userId,
                          showBackButton: true,
                        ),
                      ),
                    );
                  }
                },
                child: CircleAvatar(
                  radius: 9,
                  backgroundImage: (_posterImage != null && _posterImage!.isNotEmpty)
                      ? NetworkImage(_posterImage!)
                      : null,
                  child: (_posterImage == null || _posterImage!.isEmpty)
                      ? const Icon(Icons.person, color: Colors.white, size: 9)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: () {
                          if (userId.isNotEmpty) {
                            pauseVideo();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(
                                  userId: userId,
                                  showBackButton: true,
                                ),
                              ),
                            );
                          }
                        },
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (widget.videoData['userId'] != widget.currentUserId) ...[
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: _toggleFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                            side: BorderSide(color: Colors.white.withOpacity(0.6), width: 0.8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          minimumSize: const Size(35, 14),
                        ),
                        child: Text(
                          _isFollowing ? 'Following' : 'Follow',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.black.withOpacity(0.7)
              : Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlidingOverlay({
    required Widget child,
    required VoidCallback onClose,
  }) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! > 0) {
            onClose();
          }
        },
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _initializeLikeStream() {
    _likeSubscription = FirebaseFirestore.instance
        .collection('videos')
        .doc(widget.videoId)
        .snapshots()
        .listen((snapshot) {
      if (mounted && snapshot.exists) {
        final videoData = snapshot.data() as Map<String, dynamic>;
        final likes = videoData['likes'] as List<dynamic>? ?? [];
        setState(() {
          _localLikeCount = likes.length;
          _localIsLiked = likes.contains(widget.currentUserId);
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
      _localLikeCount = _localIsLiked ? _localLikeCount + 1 : _localLikeCount - 1;
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

  Future<void> _updateLikesFormat() async {
    try {
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoId)
          .update({
        'likes': [],
      });
    } catch (e) {
      debugPrint('Error updating likes format: $e');
    }
  }

  void _startUserInfoTimer() {
    _userInfoTimer?.cancel();
    _userInfoTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isUserInfoVisible = false;
        });
      }
    });
  }

  void _initializeUserDataStream() {
    final String userId = widget.videoData['userId'];
    if (userId != null && userId.isNotEmpty) {
      _userDataSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots()
          .listen((snapshot) {
        if (mounted && snapshot.exists) {
          final userData = snapshot.data() as Map<String, dynamic>;
          setState(() {
            // First try to construct full name from firstName and lastName
            final String? firstName = userData['firstName'];
            final String? lastName = userData['lastName'];
            if (firstName != null && firstName.isNotEmpty) {
              _posterDisplayName = lastName != null && lastName.isNotEmpty
                  ? '$firstName $lastName'
                  : firstName;
            } else {
              // If no full name, fall back to username or email
              _posterDisplayName = userData['username'] ?? 
                                 userData['email'] ?? 
                                 widget.videoData['username'] ?? 
                                 widget.videoData['email'] ?? 
                                 'Anonymous';
            }
            // Get the current user image, checking multiple possible fields
            _posterImage = userData['avatar'] ?? 
                         userData['avatarUrl'] ?? 
                         widget.videoData['userImage'];
          });
        }
      });
    }
  }

  Widget _buildIngredientsList() {
    final ingredients = (widget.videoData['ingredients'] as List<dynamic>?) ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'Ingredients',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...ingredients.map<Widget>((ingredient) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ingredient.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildInstructionsList() {
    final instructions = (widget.videoData['instructions'] as List<dynamic>?) ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'Instructions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...instructions.asMap().entries.map<Widget>((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.8),
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
                      fontSize: 16,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  void _toggleSection(String section) {
    setState(() {
      if (section == 'ingredients') {
        _isIngredientsExpanded = !_isIngredientsExpanded;
        _isInstructionsExpanded = false;
      } else {
        _isInstructionsExpanded = !_isInstructionsExpanded;
        _isIngredientsExpanded = false;
      }
    });
  }

  Future<void> _initializeCommentCount() async {
    try {
      final commentsSnapshot = await FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .count()
          .get();

      final actualCount = commentsSnapshot.count;
      
      // Update the video document with the actual count if it differs
      final videoDoc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoId)
          .get();
      
      final currentCount = videoDoc.data()?['commentCount'] ?? 0;
      
      if (currentCount != actualCount) {
        await FirebaseFirestore.instance
            .collection('videos')
            .doc(widget.videoId)
            .update({
          'commentCount': actualCount,
        });
      }
    } catch (e) {
      print('Error initializing comment count: $e');
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

      // Start a batch write
      final batch = _firestore.batch();
      
      // Add the comment
      final commentRef = _firestore
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .doc();

      batch.set(commentRef, {
        'text': _commentController.text.trim(),
        'userId': user.uid,
        'username': user.displayName ?? 'User',
        'userImage': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
      });

      // Update the comment count on the video document
      final videoRef = _firestore.collection('videos').doc(widget.videoId);
      batch.update(videoRef, {
        'commentCount': FieldValue.increment(1),
      });

      // Commit the batch
      await batch.commit();

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
                        Icon(Icons.chat_bubble_outline_rounded,
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