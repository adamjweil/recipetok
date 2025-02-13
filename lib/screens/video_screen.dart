import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import '../utils/custom_cache_manager.dart';
import '../widgets/video_card.dart';
import './video_player_screen.dart';
import 'dart:async' show unawaited;

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  final PageController _pageController = PageController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  int _currentVideoIndex = 0;
  List<QueryDocumentSnapshot>? _cachedVideos;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playInitialVideo();
    });
  }

  void _onScroll() {
    final pageIndex = (_pageController.page ?? 0).round();
    if (pageIndex != _currentVideoIndex && _cachedVideos != null) {
      setState(() {
        _currentVideoIndex = pageIndex;
      });
    }
  }

  void _playInitialVideo() {
    if (_cachedVideos != null && _cachedVideos!.isNotEmpty) {
      setState(() {
        _currentVideoIndex = 0;
      });
    }
  }

  Stream<List<QueryDocumentSnapshot>> _getVideosStream() {
    debugPrint('🎥 Fetching videos stream...');
    return _firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          debugPrint('📊 Received ${snapshot.docs.length} videos from Firestore');
          final docs = snapshot.docs;
          if (docs.isEmpty) return docs;
          
          // Debug log each video's basic info
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            debugPrint('📹 Video: ${doc.id}');
            debugPrint('👤 Creator: ${data['userId']}');
            debugPrint('📝 Title: ${data['title']}');
            debugPrint('-------------------');
          }
          
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
            
            // If no video from a different user is found, just take the next one
            if (nextIndex == -1) nextIndex = 0;
            
            // Add the selected video and update lastUserId
            reordered.add(remaining.removeAt(nextIndex));
            lastUserId = (reordered.last.data() as Map<String, dynamic>)['userId'] ?? '';
          }
          
          debugPrint('🔄 Reordered videos count: ${reordered.length}');
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
  void dispose() {
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<List<QueryDocumentSnapshot>>(
        stream: _getVideosStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting && _cachedVideos == null) {
            return const Center(child: CircularProgressIndicator());
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
            },
            itemBuilder: (context, index) {
              final videoData = videos[index].data() as Map<String, dynamic>;
              final videoId = videos[index].id;
              
              return VideoCard(
                key: ValueKey('video_$videoId'),
                videoData: videoData,
                videoId: videoId,
                onUserTap: () {},
                onLike: () => _toggleVideoLike(videoId),
                onBookmark: () => _toggleBookmark(videoId, videoData),
                currentUserId: currentUserId,
                autoPlay: _currentVideoIndex == index,
              );
            },
          );
        },
      ),
    );
  }
} 