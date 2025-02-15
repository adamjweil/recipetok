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
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // Public methods for external control
  void playVideo() {
    if (_isInitialized && !_isPlaying) {
      _controller.play();
      if (mounted) {
        setState(() {
          _isPlaying = true;
        });
      }
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
    }
  }

  bool get isPlaying => _isPlaying;
  bool get isInitialized => _isInitialized;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _checkFollowStatus();
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
          _controller.pause();
          if (mounted) {
            setState(() {
              _isPlaying = false;
            });
          }
        } else if (widget.autoplay && !_isPlaying) {
          _controller.play();
          if (mounted) {
            setState(() {
              _isPlaying = true;
            });
          }
        }
      },
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (_isPlaying) {
              _controller.pause();
              _isPlaying = false;
            } else {
              _controller.play();
              _isPlaying = true;
            }
          });
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
                right: 8,
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
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isDescriptionExpanded = !_isDescriptionExpanded;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 8 + MediaQuery.of(context).padding.bottom,
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.video.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _isDescriptionExpanded = !_isDescriptionExpanded;
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Icon(
                                        _isDescriptionExpanded 
                                            ? Icons.keyboard_arrow_up 
                                            : Icons.keyboard_arrow_down,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_isDescriptionExpanded) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.video.description,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
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
                  icon: Icon(Icons.thumb_up_outlined, color: color, size: 30),
                  onPressed: onTap,
                ),
                Text(
                  widget.video.likes.toString(),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
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
                  size: 30,
                ),
                onPressed: onTap,
              ),
              Text(
                likesCount.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
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
        IconButton(
          icon: Icon(icon, color: color, size: 30),
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
  void dispose() {
    // Only dispose if it's not a preloaded controller
    if (widget.preloadedController == null) {
      _controller.dispose();
    }
    super.dispose();
  }
} 