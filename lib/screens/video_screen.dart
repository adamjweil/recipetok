import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import '../utils/custom_cache_manager.dart';
import '../widgets/video_card.dart';
import './video_player_screen.dart';
import '../models/video.dart';
import 'dart:async' show unawaited;

class VideoScreen extends StatefulWidget {
  final Video? initialVideo;
  final bool showBackButton;
  
  const VideoScreen({
    super.key,
    this.initialVideo,
    this.showBackButton = false,
  });

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  final PageController _pageController = PageController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  int _currentVideoIndex = 0;
  List<QueryDocumentSnapshot>? _cachedVideos;
  VideoPlayerController? _preloadedController;
  VideoPlayerController? _nextVideoController;
  bool _isPreloadedVideoReady = false;
  bool _isLoadingFirstVideo = true;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onScroll);
    if (widget.initialVideo != null) {
      _loadSpecificVideo();
    } else {
      _loadFirstVideoImmediately();
    }
  }

  void _onScroll() {
    final pageIndex = (_pageController.page ?? 0).round();
    if (pageIndex != _currentVideoIndex && _cachedVideos != null) {
      setState(() {
        _currentVideoIndex = pageIndex;
      });
      // Preload next video when scrolling
      _preloadNextVideo(pageIndex);
    }
  }

  Future<void> _preloadNextVideo(int currentIndex) async {
    if (_cachedVideos == null || currentIndex >= _cachedVideos!.length - 1) return;

    try {
      // Clean up previous next video controller if it exists
      final previousController = _nextVideoController;
      _nextVideoController = null;
      if (previousController != null) {
        try {
          await previousController.dispose();
        } catch (e) {
          debugPrint('Error disposing previous controller: $e');
        }
      }

      if (!mounted) return;

      final nextVideoData = _cachedVideos![currentIndex + 1].data() as Map<String, dynamic>;
      _nextVideoController = VideoPlayerController.network(
        nextVideoData['videoUrl'],
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      if (!mounted) {
        _nextVideoController?.dispose();
        _nextVideoController = null;
        return;
      }

      await _nextVideoController!.initialize();
      
      if (!mounted) {
        _nextVideoController?.dispose();
        _nextVideoController = null;
        return;
      }

      _nextVideoController!
        ..setLooping(true)
        ..setVolume(0.0);
        
      // Don't play it yet, just have it ready
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error preloading next video: $e');
      if (_nextVideoController != null) {
        try {
          await _nextVideoController!.dispose();
        } catch (e) {
          debugPrint('Error disposing controller after error: $e');
        }
        _nextVideoController = null;
      }
    }
  }

  Future<void> _loadFirstVideoImmediately() async {
    try {
      setState(() => _isLoadingFirstVideo = true);
      
      // Get the first video document
      final snapshot = await _firestore
          .collection('videos')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() => _isLoadingFirstVideo = false);
        return;
      }

      final firstVideoData = snapshot.docs.first.data();
      _preloadedController = VideoPlayerController.network(
        firstVideoData['videoUrl'],
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await _preloadedController!.initialize();
      
      if (mounted) {
        setState(() {
          _isPreloadedVideoReady = true;
          _isLoadingFirstVideo = false;
        });
        
        // Start playing immediately
        _preloadedController!
          ..setLooping(true)
          ..setVolume(0.0)
          ..play();
      }
    } catch (e) {
      debugPrint('Error loading first video: $e');
      setState(() => _isLoadingFirstVideo = false);
    }
  }

  Future<void> _loadSpecificVideo() async {
    try {
      setState(() => _isLoadingFirstVideo = true);
      
      // Get all videos to find the index of our target video
      final snapshot = await _firestore
          .collection('videos')
          .orderBy('createdAt', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() => _isLoadingFirstVideo = false);
        return;
      }

      // Find the index of our target video
      final targetIndex = snapshot.docs.indexWhere((doc) => doc.id == widget.initialVideo!.id);
      if (targetIndex != -1) {
        _cachedVideos = snapshot.docs;
        _currentVideoIndex = targetIndex;
        
        // Initialize the video controller
        _preloadedController = VideoPlayerController.network(
          widget.initialVideo!.videoUrl,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );

        await _preloadedController!.initialize();
        
        if (mounted) {
          setState(() {
            _isPreloadedVideoReady = true;
            _isLoadingFirstVideo = false;
          });
          
          // Start playing immediately
          _preloadedController!
            ..setLooping(true)
            ..setVolume(0.0)
            ..play();
            
          // Jump to the correct page
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _pageController.jumpToPage(targetIndex);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading specific video: $e');
      setState(() => _isLoadingFirstVideo = false);
    }
  }

  Stream<List<QueryDocumentSnapshot>> _getVideosStream() {
    return _firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs;
          if (docs.isEmpty) return docs;
          
          // Create a new list to store the reordered videos
          List<QueryDocumentSnapshot> reordered = [];
          List<QueryDocumentSnapshot> remaining = List.from(docs);
          
          // Add the first video
          reordered.add(remaining.removeAt(0));
          
          // Keep track of the last user ID to avoid consecutive videos
          String lastUserId = (reordered.last.data() as Map<String, dynamic>)['userId'] ?? '';
          
          while (remaining.isNotEmpty) {
            // Try to find a video from a different user
            int nextIndex = remaining.indexWhere((doc) {
              String userId = (doc.data() as Map<String, dynamic>)['userId'] ?? '';
              return userId != lastUserId;
            });
            
            if (nextIndex == -1) nextIndex = 0;
            
            reordered.add(remaining.removeAt(nextIndex));
            lastUserId = (reordered.last.data() as Map<String, dynamic>)['userId'] ?? '';
          }
          
          return reordered;
        });
  }

  Future<void> _toggleVideoLike(String videoId) async {
    try {
      final videoRef = _firestore.collection('videos').doc(videoId);
      final videoDoc = await videoRef.get();
      
      if (!videoDoc.exists) return;
      
      final likes = List<String>.from(videoDoc.data()?['likes'] ?? []);
      final isLiked = likes.contains(currentUserId);

      if (isLiked) {
        await videoRef.update({
          'likes': FieldValue.arrayRemove([currentUserId]),
        });
      } else {
        await videoRef.update({
          'likes': FieldValue.arrayUnion([currentUserId]),
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

  Future<void> _toggleBookmark(String videoId, Map<String, dynamic> videoData) async {
    try {
      final videoRef = _firestore.collection('videos').doc(videoId);
      final videoDoc = await videoRef.get();
      
      // Initialize tryLaterBy array if it doesn't exist
      if (!videoDoc.exists || !videoDoc.data()!.containsKey('tryLaterBy')) {
        await videoRef.set({
          'tryLaterBy': [],
        }, SetOptions(merge: true));
      }

      final tryLaterBy = List<String>.from(videoDoc.data()?['tryLaterBy'] ?? []);
      final isBookmarked = tryLaterBy.contains(currentUserId);

      if (isBookmarked) {
        // Remove from tryLaterBy array
        await videoRef.update({
          'tryLaterBy': FieldValue.arrayRemove([currentUserId])
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video removed from Try Later')),
          );
        }
      } else {
        // Add to tryLaterBy array
        await videoRef.update({
          'tryLaterBy': FieldValue.arrayUnion([currentUserId])
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video added to Try Later')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          StreamBuilder<List<QueryDocumentSnapshot>>(
            stream: _getVideosStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              // Show loading state with preloaded video
              if (_isLoadingFirstVideo) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              // Show preloaded video while waiting for stream
              if (snapshot.connectionState == ConnectionState.waiting && 
                  _cachedVideos == null && 
                  _isPreloadedVideoReady &&
                  _preloadedController != null) {
                return Stack(
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: _preloadedController!.value.aspectRatio,
                        child: VideoPlayer(_preloadedController!),
                      ),
                    ),
                  ],
                );
              }

              final videos = snapshot.data ?? _cachedVideos ?? [];
              
              if (snapshot.hasData) {
                _cachedVideos = snapshot.data;
                if (_currentVideoIndex >= videos.length) {
                  _currentVideoIndex = videos.length - 1;
                }
              }

              if (videos.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.video_library, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No videos yet',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: videos.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentVideoIndex = index;
                  });
                  _preloadNextVideo(index);
                },
                itemBuilder: (context, index) {
                  final videoData = videos[index].data() as Map<String, dynamic>;
                  final videoId = videos[index].id;
                  
                  // Use preloaded controller for first video
                  final usePreloadedController = index == 0 && _preloadedController != null;
                  
                  return VideoCard(
                    key: ValueKey('video_$videoId'),
                    video: Video.fromMap(
                      videoId,
                      videoData,
                    ),
                    autoplay: _currentVideoIndex == index,
                    preloadedController: usePreloadedController ? _preloadedController : null,
                  );
                },
              );
            },
          ),
          // Add back button if showBackButton is true
          if (widget.showBackButton)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    try {
      _pageController.removeListener(_onScroll);
      _pageController.dispose();
      if (_preloadedController != null) {
        _preloadedController!.dispose();
        _preloadedController = null;
      }
      if (_nextVideoController != null) {
        _nextVideoController!.dispose();
        _nextVideoController = null;
      }
    } catch (e) {
      debugPrint('Error during disposal: $e');
    }
    super.dispose();
  }
} 