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

  const VideoCard({
    Key? key,
    required this.video,
    this.autoplay = false,
  }) : super(key: key);

  @override
  VideoCardState createState() => VideoCardState();
}

// Public interface for the state
class VideoCardState extends State<VideoCard> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  bool _isDescriptionExpanded = false;
  bool _isFollowing = false;
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  void playVideo() {
    _controller.play();
    setState(() {
      _isPlaying = true;
    });
  }

  void pauseVideo() {
    _controller.pause();
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    initializePlayer();
    _checkFollowStatus();
  }

  Future<void> initializePlayer() async {
    _controller = VideoPlayerController.network(widget.video.videoUrl);
    
    try {
      await _controller.initialize();
      _controller.setLooping(true);
      if (widget.autoplay) {
        _controller.play();
        _isPlaying = true;
      }
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error initializing video player: $e');
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
      final userLikeRef = videoRef.collection('likes').doc(currentUserId);
      
      final likeDoc = await userLikeRef.get();
      final isLiked = likeDoc.exists;

      final batch = FirebaseFirestore.instance.batch();

      if (isLiked) {
        batch.update(videoRef, {
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([currentUserId]),
        });
        batch.delete(userLikeRef);
      } else {
        batch.update(videoRef, {
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([currentUserId]),
        });
        batch.set(userLikeRef, {
          'timestamp': FieldValue.serverTimestamp(),
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
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
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
              // Video
              Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              ),

              // Right side buttons
              Positioned(
                right: 8,
                bottom: 100,
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
                    const SizedBox(height: 16),
                    // Bookmark button
                    _buildSideButton(
                      icon: Icons.bookmark_border,
                      label: 'Save',
                      onTap: _showSaveOptions,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),

              // Bottom overlay
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                        fontSize: 16,
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
                                        size: 20,
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
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                        const SizedBox(height: 8),
                        // User info with follow button
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
                                    radius: 15,
                                    backgroundImage: CachedNetworkImageProvider(
                                      widget.video.userImage,
                                      cacheManager: CustomCacheManager.instance,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.video.username,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (currentUserId != null && currentUserId != widget.video.userId)
                              GestureDetector(
                                onTap: _toggleFollow,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isFollowing 
                                        ? Colors.white.withOpacity(0.2)
                                        : Theme.of(context).primaryColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _isFollowing ? 'Following' : 'Follow',
                                    style: TextStyle(
                                      color: _isFollowing ? Colors.white : Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 50,
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
    if (icon == Icons.favorite || icon == Icons.favorite_border) {
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('videos')
            .doc(widget.video.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Column(
              children: [
                IconButton(
                  icon: Icon(Icons.thumb_up_outlined, color: color, size: 30),
                  onPressed: onTap,
                ),
                Text(
                  '0',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                  ),
                ),
              ],
            );
          }

          final videoData = snapshot.data!.data() as Map<String, dynamic>?;
          final likedBy = List<String>.from(videoData?['likedBy'] ?? []);
          final isLiked = likedBy.contains(currentUserId);
          final likesCount = videoData?['likes'] ?? 0;

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
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('groups')
            .snapshots(),
        builder: (context, groupsSnapshot) {
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('videos')
                .doc(widget.video.id)
                .snapshots(),
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
    _controller.pause();
    _controller.dispose();
    super.dispose();
  }
} 