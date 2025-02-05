import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/story.dart';
import '../services/story_service.dart';
import '../utils/custom_cache_manager.dart';

class StoryViewer extends StatefulWidget {
  final Story story;

  const StoryViewer({
    super.key,
    required this.story,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  VideoPlayerController? _videoController;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initializeStory();
    StoryService().markStoryAsViewed(widget.story.id);
  }

  Future<void> _initializeStory() async {
    if (widget.story.mediaType == 'video') {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.story.mediaUrl),
      );

      await _videoController!.initialize();
      await _videoController!.setLooping(true);
      await _videoController!.play();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Story Content
            Center(
              child: widget.story.mediaType == 'video'
                  ? _buildVideoPlayer()
                  : _buildImage(),
            ),
            // Close Button
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // Sound Control for Videos
            if (widget.story.mediaType == 'video')
              Positioned(
                top: 16,
                left: 16,
                child: IconButton(
                  icon: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                  ),
                  onPressed: _toggleSound,
                ),
              ),
            // Story Actions
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: _buildStoryActions(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_videoController?.value.isInitialized != true) {
      return const CircularProgressIndicator();
    }
    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: VideoPlayer(_videoController!),
    );
  }

  Widget _buildImage() {
    return CachedNetworkImage(
      imageUrl: widget.story.mediaUrl,
      cacheManager: CustomCacheManager.instance,
      fit: BoxFit.contain,
      placeholder: (context, url) => const CircularProgressIndicator(),
      errorWidget: (context, url, error) => const Icon(Icons.error),
    );
  }

  Widget _buildStoryActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Extend Duration Button
          if (widget.story.userId == FirebaseAuth.instance.currentUser?.uid)
            ElevatedButton.icon(
              onPressed: _extendDuration,
              icon: const Icon(Icons.timer, size: 18),
              label: const Text(
                'Extend',
                style: TextStyle(fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          // Remove Story Button
          if (widget.story.userId == FirebaseAuth.instance.currentUser?.uid)
            ElevatedButton.icon(
              onPressed: _removeStory,
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              label: const Text(
                'Remove',
                style: TextStyle(fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          // Save as Post Button
          if (widget.story.userId == FirebaseAuth.instance.currentUser?.uid)
            ElevatedButton.icon(
              onPressed: _saveAsPost,
              icon: const Icon(Icons.save, size: 18),
              label: const Text(
                'Save as Post',
                style: TextStyle(fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
        ],
      ),
    );
  }

  void _toggleSound() {
    setState(() {
      _isMuted = !_isMuted;
      if (_isMuted) {
        _videoController?.setVolume(0);
      } else {
        _videoController?.setVolume(1);
      }
    });
  }

  Future<void> _extendDuration() async {
    try {
      await StoryService().extendStoryDuration(widget.story.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Story duration extended by 10 minutes'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(
              top: 20,
              right: 20,
              left: 20,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error extending story duration: $e'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(
              top: 20,
              right: 20,
              left: 20,
            ),
          ),
        );
      }
    }
  }

  Future<void> _removeStory() async {
    try {
      await StoryService().deactivateStory(widget.story.id);
      if (mounted) {
        Navigator.pop(context); // Close the story viewer
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Story removed successfully'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(
              top: 20,
              right: 20,
              left: 20,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing story: $e'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(
              top: 20,
              right: 20,
              left: 20,
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveAsPost() async {
    // TODO: Implement save as post functionality
    // This will need to be implemented based on your video posting logic
  }
} 