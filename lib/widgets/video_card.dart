import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/custom_cache_manager.dart';
import './save_options_modal.dart';
import 'package:rxdart/rxdart.dart';
import '../screens/profile_screen.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/video.dart';
import './comment_modal.dart';

class VideoCard extends StatefulWidget {
  final Video video;
  final bool autoplay;
  final VideoPlayerController? preloadedController;

  const VideoCard({
    Key? key,
    required this.video,
    required this.autoplay,
    this.preloadedController,
  }) : super(key: key);

  @override
  VideoCardState createState() => VideoCardState();
}

// Public interface for video control
class VideoCardState extends State<VideoCard> with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isMuted = true;
  bool _isDescriptionExpanded = false;
  bool _isFollowing = false;
  String _currentSubtitle = '';
  Timer? _subtitleTimer;
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  List<Map<String, dynamic>>? _transcriptSegments;
  bool _isDraggingProgress = false;
  bool _isShowingControls = false;
  Timer? _controlsTimer;

  // Public methods for external control
  void playVideo() {
    if (_isInitialized && !_isPlaying) {
      _controller.play();
      if (mounted) {
        setState(() {
          _isPlaying = true;
        });
      }
      _updateSubtitles();
    }
  }

  void pauseVideo() {
    if (_isInitialized && _isPlaying) {
      _controller.pause();
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
      _subtitleTimer?.cancel();
    }
  }

  bool get isPlaying => _isPlaying;
  bool get isInitialized => _isInitialized;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _checkFollowStatus();
    _loadTranscriptSegments();
  }

  Future<void> _initializeVideo() async {
    try {
      if (widget.preloadedController != null) {
        _controller = widget.preloadedController!;
        _isInitialized = _controller.value.isInitialized;
      } else {
        _controller = VideoPlayerController.network(
          widget.video.videoUrl,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        await _controller.initialize();
        _controller.setLooping(true);
        _controller.setVolume(_isMuted ? 0.0 : 1.0);
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          if (widget.autoplay) {
            _controller.play();
            _isPlaying = true;
          }
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  @override
  void didUpdateWidget(VideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoplay != oldWidget.autoplay) {
      if (widget.autoplay) {
        _controller.play();
        setState(() => _isPlaying = true);
      } else {
        _controller.pause();
        setState(() => _isPlaying = false);
      }
    }
  }

  Future<void> _checkFollowStatus() async {
    if (currentUserId == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      
      if (mounted) {
        setState(() {
          _isFollowing = (userDoc.data()?['following'] ?? []).contains(widget.video.userId);
        });
      }
    } catch (e) {
      print('Error checking follow status: $e');
    }
  }

  Future<void> _toggleFollow() async {
    if (currentUserId == null) return;

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);
      final creatorRef = FirebaseFirestore.instance.collection('users').doc(widget.video.userId);

      if (_isFollowing) {
        // Unfollow
        await userRef.update({
          'following': FieldValue.arrayRemove([widget.video.userId])
        });
        await creatorRef.update({
          'followers': FieldValue.arrayRemove([currentUserId])
        });
      } else {
        // Follow
        await userRef.update({
          'following': FieldValue.arrayUnion([widget.video.userId])
        });
        await creatorRef.update({
          'followers': FieldValue.arrayUnion([currentUserId])
        });
      }

      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
        });
      }
    } catch (e) {
      print('Error toggling follow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _toggleLike() async {
    if (currentUserId == null) return;

    try {
      final videoRef = FirebaseFirestore.instance.collection('videos').doc(widget.video.id);
      
      // First, get the current video data
      final videoDoc = await videoRef.get();
      if (!videoDoc.exists) {
        print('Video document not found');
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      final videoData = videoDoc.data() as Map<String, dynamic>;
      final likedBy = List<String>.from(videoData['likedBy'] ?? []);
      final isLiked = likedBy.contains(currentUserId);

      if (isLiked) {
        // Unlike
        batch.update(videoRef, {
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([currentUserId]),
        });
      } else {
        // Like
        batch.update(videoRef, {
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([currentUserId]),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error toggling like: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentModal(
        postId: widget.video.id,
        postUserId: widget.video.userId,
      ),
    );
  }

  void _showSaveOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SaveOptionsModal(
        videoId: widget.video.id,
        videoData: widget.video.toMap(),
        currentUserId: currentUserId ?? '',
      ),
    );
  }

  Future<void> _loadTranscriptSegments() async {
    try {
      final videoDoc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.video.id)
          .get();
      
      if (videoDoc.exists) {
        final data = videoDoc.data();
        if (data != null && data['transcriptSegments'] != null) {
          setState(() {
            _transcriptSegments = List<Map<String, dynamic>>.from(data['transcriptSegments']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading transcript segments: $e');
    }
  }

  void _updateSubtitles() {
    if (_transcriptSegments == null || !_isPlaying) {
      _subtitleTimer?.cancel();
      setState(() => _currentSubtitle = '');
      return;
    }

    _subtitleTimer?.cancel();
    _subtitleTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || !_isPlaying) {
        timer.cancel();
        return;
      }

      final position = _controller.value.position.inMilliseconds / 1000.0;
      String newSubtitle = '';

      for (final segment in _transcriptSegments!) {
        final startTime = segment['startTime'].toDouble();
        final endTime = segment['endTime'].toDouble();

        if (position >= startTime && position <= endTime) {
          newSubtitle = segment['text'];
          break;
        }
      }

      if (mounted && _currentSubtitle != newSubtitle) {
        setState(() => _currentSubtitle = newSubtitle);
      }
    });
  }

  void _showControlsTemporarily() {
    setState(() => _isShowingControls = true);
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isDraggingProgress) {
        setState(() => _isShowingControls = false);
      }
    });
  }

  Widget _buildProgressBar() {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _controller,
      builder: (context, value, child) {
        final duration = value.duration;
        final position = value.position;

        return LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onHorizontalDragStart: (details) {
                setState(() => _isDraggingProgress = true);
              },
              onHorizontalDragUpdate: (details) {
                final dx = details.localPosition.dx.clamp(0, constraints.maxWidth);
                final newPosition = (dx / constraints.maxWidth) * duration.inMilliseconds;
                _controller.seekTo(Duration(milliseconds: newPosition.toInt()));
              },
              onHorizontalDragEnd: (details) {
                setState(() => _isDraggingProgress = false);
                _showControlsTemporarily();
              },
              onTapDown: (details) {
                final dx = details.localPosition.dx.clamp(0, constraints.maxWidth);
                final newPosition = (dx / constraints.maxWidth) * duration.inMilliseconds;
                _controller.seekTo(Duration(milliseconds: newPosition.toInt()));
                _showControlsTemporarily();
              },
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Stack(
                  children: [
                    // Background track
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    // Progress track
                    FractionallySizedBox(
                      widthFactor: duration.inMilliseconds > 0
                          ? position.inMilliseconds / duration.inMilliseconds
                          : 0.0,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ),
                    // Drag handle
                    if (_isShowingControls || _isDraggingProgress)
                      Positioned(
                        left: duration.inMilliseconds > 0
                            ? (position.inMilliseconds / duration.inMilliseconds) * constraints.maxWidth - 8
                            : -8,
                        top: -5,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    return VisibilityDetector(
      key: Key(widget.video.id),
      onVisibilityChanged: (visibilityInfo) {
        if (!mounted) return;
        
        if (visibilityInfo.visibleFraction < 0.5) {
          pauseVideo();
        } else if (widget.autoplay && !_isPlaying) {
          playVideo();
        }
      },
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (_isPlaying) {
              pauseVideo();
            } else {
              playVideo();
            }
          });
          _showControlsTemporarily();
        },
        child: Container(
          color: Colors.black,
          child: Stack(
            children: [
              // Video player with fade transition and full screen sizing
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: _isInitialized ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                ),
              ),

              // Right side buttons
              Positioned(
                right: 13,
                bottom: (MediaQuery.of(context).size.height * 0.15) - 25,
                child: Column(
                  children: [
                    // Like button
                    _buildSideButton(
                      icon: widget.video.likedBy.contains(currentUserId)
                          ? Icons.thumb_up
                          : Icons.thumb_up_outlined,
                      label: widget.video.likes.toString(),
                      onTap: _toggleLike,
                      color: widget.video.likedBy.contains(currentUserId)
                          ? Theme.of(context).primaryColor
                          : Colors.white,
                    ),
                    const SizedBox(height: 16),
                    // Comment button
                    _buildSideButton(
                      icon: Icons.comment,
                      label: widget.video.commentCount.toString(),
                      onTap: _showComments,
                    ),
                  ],
                ),
              ),

              // Bottom overlay with gradient
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 48 + MediaQuery.of(context).padding.bottom,
                    top: 32,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title and description section
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isDescriptionExpanded = !_isDescriptionExpanded;
                          });
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Container(
                                width: MediaQuery.of(context).size.width - 100,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.video.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(
                                      _isDescriptionExpanded 
                                          ? Icons.keyboard_arrow_up 
                                          : Icons.keyboard_arrow_down,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isDescriptionExpanded) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: MediaQuery.of(context).size.width - 100,
                          child: Text(
                            widget.video.description,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                      // User info with follow button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProfileScreen(userId: widget.video.userId),
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 13.5,
                                      backgroundColor: Colors.grey[300],
                                      backgroundImage: widget.video.userImage.isNotEmpty && widget.video.userImage != 'null'
                                          ? CachedNetworkImageProvider(
                                              widget.video.userImage,
                                              cacheManager: CustomCacheManager.instance,
                                            )
                                          : null,
                                      child: widget.video.userImage.isEmpty || widget.video.userImage == 'null'
                                          ? const Icon(Icons.person, color: Colors.white, size: 18)
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.video.username,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (currentUserId != null && currentUserId != widget.video.userId)
                                GestureDetector(
                                  onTap: _toggleFollow,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _isFollowing 
                                          ? Colors.white.withOpacity(0.2)
                                          : Theme.of(context).primaryColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _isFollowing ? 'Following' : 'Follow',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.75,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUserId)
                                .collection('groups')
                                .snapshots()
                                .distinct(),
                            builder: (context, groupsSnapshot) {
                              return StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('videos')
                                    .doc(widget.video.id)
                                    .snapshots()
                                    .distinct(),
                                builder: (context, videoSnapshot) {
                                  bool isSaved = false;
                                  
                                  if (videoSnapshot.hasData && videoSnapshot.data != null) {
                                    final videoData = videoSnapshot.data!.data() as Map<String, dynamic>?;
                                    final tryLaterBy = List<String>.from(videoData?['tryLaterBy'] ?? []);
                                    if (tryLaterBy.contains(currentUserId)) {
                                      isSaved = true;
                                    }
                                  }

                                  if (!isSaved && groupsSnapshot.hasData && groupsSnapshot.data != null) {
                                    for (var group in groupsSnapshot.data!.docs) {
                                      final videos = (group.data() as Map<String, dynamic>)['videos'] ?? {};
                                      if (videos.containsKey(widget.video.id)) {
                                        isSaved = true;
                                        break;
                                      }
                                    }
                                  }

                                  return IconButton(
                                    icon: Icon(
                                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                                      color: isSaved ? Theme.of(context).primaryColor : Colors.white,
                                      size: 30,
                                    ),
                                    onPressed: _showSaveOptions,
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Play/Pause indicator
              if (!_isPlaying)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                ),

              // Add subtitle overlay
              if (_currentSubtitle.isNotEmpty)
                Positioned(
                  left: 16,
                  right: 80, // Leave space for the right-side buttons
                  bottom: MediaQuery.of(context).size.height * 0.35, // Moved up from 0.3 to 0.35
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _currentSubtitle,
                          key: ValueKey<String>(_currentSubtitle),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black54,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),

              // Add progress bar at the very bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: -10, // Changed from 0 to move it down 10 pixels
                child: _buildProgressBar(),
              ),

              // Add timestamp overlay
              if (_isShowingControls || _isDraggingProgress)
                Positioned(
                  right: 16,
                  bottom: 30, // Changed from 40 to maintain relative positioning
                  child: ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: _controller,
                    builder: (context, value, child) {
                      final position = value.position;
                      final duration = value.duration;
                      
                      String _formatDuration(Duration d) {
                        final minutes = d.inMinutes.toString().padLeft(2, '0');
                        final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
                        return '$minutes:$seconds';
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${_formatDuration(position)} / ${_formatDuration(duration)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSideButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    if (icon == Icons.thumb_up || icon == Icons.thumb_up_outlined) {
      // Use StreamBuilder only for the like button
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('videos')
            .doc(widget.video.id)
            .snapshots()
            .distinct(), // Add distinct to prevent duplicate emissions
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Column(
              children: [
                IconButton(
                  icon: Icon(Icons.thumb_up_outlined, color: color, size: 27),
                  onPressed: onTap,
                ),
                Text(
                  widget.video.likes.toString(),
                  style: TextStyle(
                    color: color,
                    fontSize: 10.8,
                  ),
                ),
              ],
            );
          }

          final videoData = snapshot.data!.data() as Map<String, dynamic>?;
          if (videoData == null) return const SizedBox();

          final likedBy = List<String>.from(videoData['likedBy'] ?? []);
          final isLiked = likedBy.contains(currentUserId);
          final likesCount = videoData['likes'] ?? 0;

          return Column(
            children: [
              IconButton(
                icon: Icon(
                  isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  color: isLiked ? Theme.of(context).primaryColor : color,
                  size: 27,
                ),
                onPressed: onTap,
              ),
              Text(
                likesCount.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 10.8,
                ),
              ),
            ],
          );
        },
      );
    } else if (icon == Icons.bookmark_border || icon == Icons.bookmark) {
      // Rest of the bookmark button code remains the same
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('groups')
            .snapshots()
            .distinct(), // Add distinct here too
        builder: (context, groupsSnapshot) {
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('videos')
                .doc(widget.video.id)
                .snapshots()
                .distinct(), // And here
            builder: (context, videoSnapshot) {
              bool isSaved = false;
              
              // Check if video is in Try Later
              if (videoSnapshot.hasData && videoSnapshot.data != null) {
                final videoData = videoSnapshot.data!.data() as Map<String, dynamic>?;
                final tryLaterBy = List<String>.from(videoData?['tryLaterBy'] ?? []);
                if (tryLaterBy.contains(currentUserId)) {
                  isSaved = true;
                }
              }

              // Check if video is in any groups
              if (!isSaved && groupsSnapshot.hasData && groupsSnapshot.data != null) {
                for (var group in groupsSnapshot.data!.docs) {
                  final videos = (group.data() as Map<String, dynamic>)['videos'] ?? {};
                  if (videos.containsKey(widget.video.id)) {
                    isSaved = true;
                    break;
                  }
                }
              }

              return Column(
                children: [
                  IconButton(
                    icon: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: isSaved ? Theme.of(context).primaryColor : color,
                      size: 30,
                    ),
                    onPressed: onTap,
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSaved ? Theme.of(context).primaryColor : color,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    // Default button for other icons (like comments)
    return Column(
      children: [
        Container(
          width: 60, // Increased touch target width
          height: 60, // Increased touch target height
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(icon, color: color, size: 27),
            onPressed: onTap,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10.8,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _subtitleTimer?.cancel();
    if (widget.preloadedController == null) {
      _controller.dispose();
    }
    super.dispose();
  }
} 