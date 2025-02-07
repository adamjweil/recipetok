import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:http/http.dart' as http;

class HLSVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? mp4Fallback;
  final List<String>? qualities;
  final bool autoPlay;
  final VoidCallback? onPlay;
  static final _key = GlobalKey<_HLSVideoPlayerState>();

  const HLSVideoPlayer({
    super.key,
    required this.videoUrl,
    this.mp4Fallback,
    this.qualities,
    this.autoPlay = false,
    this.onPlay,
  });

  void playVideo() {
    _key.currentState?.playVideo();
  }

  void pauseVideo() {
    _key.currentState?.pauseVideo();
  }

  void dispose() {
    _key.currentState?._videoPlayerController.dispose();
    _key.currentState?._chewieController?.dispose();
  }

  @override
  State<HLSVideoPlayer> createState() => _HLSVideoPlayerState();
}

class _HLSVideoPlayerState extends State<HLSVideoPlayer> with WidgetsBindingObserver {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _videoPlayerController.pause();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialized) {
      final bool isVisible = ModalRoute.of(context)?.isCurrent ?? false;
      if (!isVisible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _videoPlayerController.pause();
          }
        });
      }
    }
  }

  @override
  void deactivate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _videoPlayerController.pause();
      }
    });
    super.deactivate();
  }

  Future<void> _initializePlayer() async {
    try {
      // First try HLS
      await _initializeHLSPlayer();
    } catch (e) {
      print('HLS playback failed, falling back to MP4: $e');
      if (widget.mp4Fallback != null) {
        await _initializeFallbackPlayer();
      }
    }
  }

  Future<void> _initializeHLSPlayer() async {
    try {
      print('=== HLS Debug Information ===');
      print('Attempting to play HLS: ${widget.videoUrl}');
      
      // Parse and validate URL
      final uri = Uri.parse(widget.videoUrl);
      print('\nURL Components:');
      print('  Scheme: ${uri.scheme}');
      print('  Host: ${uri.host}');
      print('  Path: ${uri.path}');
      print('  Query: ${uri.query}');

      // Try to fetch the M3U8 file directly
      try {
        final response = await http.get(uri);
        print('\nM3U8 File Access Test:');
        print('  Status Code: ${response.statusCode}');
        print('  Content Type: ${response.headers['content-type']}');
        print('  First 200 chars of response:');
        print('  ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
        
        if (!response.body.contains('#EXTM3U')) {
          print('\n⚠️ Warning: Response doesn\'t look like a valid M3U8 file!');
        }
      } catch (e) {
        print('\n❌ Failed to fetch M3U8 file directly: $e');
      }
      
      // Create video controller
      print('\nInitializing VideoPlayerController...');
      _videoPlayerController = VideoPlayerController.networkUrl(uri);

      print('Waiting for initialization...');
      await _videoPlayerController.initialize();
      print('✅ HLS initialization successful');
      print('Video details:');
      print('  Duration: ${_videoPlayerController.value.duration}');
      print('  Aspect Ratio: ${_videoPlayerController.value.aspectRatio}');
      print('  Size: ${_videoPlayerController.value.size}');
      print('  Is playing: ${_videoPlayerController.value.isPlaying}');
      print('  Position: ${_videoPlayerController.value.position}');
      print('  Has error: ${_videoPlayerController.value.hasError}');
      if (_videoPlayerController.value.hasError) {
        print('  Error: ${_videoPlayerController.value.errorDescription}');
      }

      // Rest of initialization
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: widget.autoPlay,
        looping: true,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        autoInitialize: true,
        showControls: true,
        showControlsOnInitialize: false,
        allowFullScreen: true,
        allowMuting: true,
        placeholder: Container(
          color: Colors.black,
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      // Add enhanced listener for play state
      _videoPlayerController.addListener(() {
        if (_videoPlayerController.value.hasError) {
          print('❌ Playback Error: ${_videoPlayerController.value.errorDescription}');
        }
        if (_videoPlayerController.value.isPlaying) {
          print('▶️ Video started playing');
          widget.onPlay?.call();
        }
      });

      setState(() {
        _isInitialized = true;
      });
      print('=== End of HLS Debug Information ===\n');

    } catch (e, stack) {
      print('\n❌ HLS initialization failed with error:');
      print(e);
      print('\nStack trace:');
      print(stack);
      rethrow;
    }
  }

  Future<void> _initializeFallbackPlayer() async {
    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(widget.mp4Fallback!),
    );

    await _videoPlayerController.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: widget.autoPlay,
      looping: true,
      aspectRatio: _videoPlayerController.value.aspectRatio,
      autoInitialize: true,
      showControls: true,
      showControlsOnInitialize: false,
      allowFullScreen: true,
      allowMuting: true,
      placeholder: Container(
        color: Colors.black,
      ),
    );

    setState(() {
      _isInitialized = true;
    });
  }

  void playVideo() {
    if (_isInitialized && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _videoPlayerController.play();
      });
    }
  }

  void pauseVideo() {
    if (_isInitialized && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _videoPlayerController.pause();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return AspectRatio(
      aspectRatio: _videoPlayerController.value.aspectRatio,
      child: Chewie(controller: _chewieController!),
    );
  }
} 