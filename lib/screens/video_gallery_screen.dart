import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

class VideoGalleryScreen extends StatefulWidget {
  const VideoGalleryScreen({super.key});

  @override
  State<VideoGalleryScreen> createState() => _VideoGalleryScreenState();
}

class _VideoGalleryScreenState extends State<VideoGalleryScreen> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _videos = [];
  bool _isLoading = true;
  final int _maxDurationSeconds = 60;
  Map<String, Duration> _videoDurations = {};
  Map<String, String> _thumbnails = {};

  // Add supported formats based on OpenAI Whisper API requirements
  final Set<String> _supportedFormats = {
    'mp4', 'mpeg', 'mpga', 'webm', 'm4a', 'wav'
  };

  bool _isFormatSupported(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    return _supportedFormats.contains(extension);
  }

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    try {
      final videos = await _picker.pickMultipleMedia();
      if (!mounted) return;

      // Filter videos by supported formats
      final filteredVideos = videos.where((video) => _isFormatSupported(video.name)).toList();
      
      // Show warning if some videos were filtered out
      if (filteredVideos.length < videos.length && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Some videos were filtered out. Supported formats: ${_supportedFormats.join(", ")}'
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }

      setState(() {
        _videos = filteredVideos;
        _isLoading = false;
      });

      // Generate thumbnails and get durations for all videos
      for (var video in _videos) {
        final thumbnail = await _generateThumbnail(video);
        if (thumbnail != null && mounted) {
          setState(() {
            _thumbnails[video.path] = thumbnail;
          });
        }
        await _getVideoDuration(video);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading videos: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String?> _generateThumbnail(XFile video) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = '${tempDir.path}/thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final thumbnail = await VideoThumbnail.thumbnailFile(
        video: video.path,
        thumbnailPath: thumbnailPath,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
        maxWidth: 300,
        maxHeight: 300,
      );

      if (thumbnail == null) {
        debugPrint('Failed to generate thumbnail for video: ${video.path}');
        return null;
      }

      final thumbnailFile = File(thumbnail);
      if (!await thumbnailFile.exists()) {
        debugPrint('Thumbnail file does not exist: $thumbnail');
        return null;
      }

      return thumbnail;
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }

  Future<void> _getVideoDuration(XFile video) async {
    try {
      final controller = VideoPlayerController.file(File(video.path));
      await controller.initialize();
      if (mounted) {
        setState(() {
          _videoDurations[video.path] = controller.value.duration;
        });
      }
      await controller.dispose();
    } catch (e) {
      debugPrint('Error getting video duration: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_videos.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Select Video'),
        ),
        body: const Center(
          child: Text('No videos found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Video'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _videos.length,
        itemBuilder: (context, index) {
          final video = _videos[index];
          final thumbnail = _thumbnails[video.path];
          final duration = _videoDurations[video.path];

          if (thumbnail == null || duration == null) {
            return const Card(
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return GestureDetector(
            onTap: () {
              if (duration.inSeconds > _maxDurationSeconds) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select a video under 60 seconds'),
                  ),
                );
                return;
              }
              Navigator.pop(context, File(video.path));
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(thumbnail),
                  fit: BoxFit.cover,
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                if (duration.inSeconds > _maxDurationSeconds)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(
                      child: Icon(
                        Icons.warning,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    // Clean up thumbnail files
    for (var thumbnail in _thumbnails.values) {
      try {
        File(thumbnail).deleteSync();
      } catch (e) {
        debugPrint('Error deleting thumbnail: $e');
      }
    }
    super.dispose();
  }
} 