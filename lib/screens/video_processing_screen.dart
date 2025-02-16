import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as path;
import 'package:recipetok/models/video_draft.dart';
import 'package:recipetok/services/ai_service.dart';
import 'package:recipetok/screens/video_processing_wizard.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_compress/video_compress.dart';

class VideoProcessingScreen extends StatefulWidget {
  final String videoPath;
  final String userId;

  const VideoProcessingScreen({
    super.key,
    required this.videoPath,
    required this.userId,
  });

  @override
  State<VideoProcessingScreen> createState() => _VideoProcessingScreenState();
}

class _VideoProcessingScreenState extends State<VideoProcessingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  String _currentStep = 'Preparing video...';
  double _progress = 0.0;
  bool _isProcessing = false;
  bool _isDisposed = false;
  String? _error;

  final Set<String> _supportedFormats = {
    'mp4', 'mpeg', 'mpga', 'webm', 'm4a', 'wav'
  };

  bool _isFormatSupported(String filePath) {
    final extension = path.extension(filePath).toLowerCase().replaceAll('.', '');
    debugPrint('Checking file extension: $extension');
    return _supportedFormats.contains(extension);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.repeat(reverse: true);
    _processVideo();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.dispose();
    super.dispose();
  }

  Future<void> _processVideo() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      if (_isDisposed) return;

      // Check video format first
      if (!_isFormatSupported(widget.videoPath)) {
        throw FormatException(
          'Unsupported video format. Please use one of the following formats: ${_supportedFormats.join(", ")}'
        );
      }

      final aiService = AIService();
      final videoId = const Uuid().v4();
      final videoFile = File(widget.videoPath);

      // Check video duration
      final videoInfo = await aiService.getVideoInfo(videoFile);
      if (videoInfo.duration > const Duration(minutes: 2)) {
        throw Exception('Video duration cannot exceed 2 minutes');
      }

      // Step 1: Compress video
      setState(() {
        _currentStep = 'Compressing video...';
        _progress = 0.1;
      });

      debugPrint('Starting video compression...');
      final MediaInfo? compressedVideoInfo = await VideoCompress.compressVideo(
        widget.videoPath,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (compressedVideoInfo?.file == null) {
        throw Exception('Failed to compress video');
      }

      final compressedVideoFile = compressedVideoInfo!.file!;
      final compressedSize = await compressedVideoFile.length();
      final originalSize = await videoFile.length();
      debugPrint('Original size: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');
      debugPrint('Compressed size: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // If compression resulted in a larger file, use the original
      final fileToUpload = compressedSize > originalSize ? videoFile : compressedVideoFile;
      debugPrint('Using ${compressedSize > originalSize ? 'original' : 'compressed'} file for upload');

      // Step 2: Upload video to Firebase Storage
      setState(() {
        _currentStep = 'Uploading video...';
        _progress = 0.2;
      });

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('videos/${widget.userId}/$videoId.mp4');
          
      final uploadTask = storageRef.putFile(
        fileToUpload,
        SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {
            'userId': widget.userId,
            'uploadedAt': DateTime.now().toIso8601String(),
            'compressed': 'true',
          },
        ),
      );

      // Track upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.totalBytes == 0) return; // Prevent division by zero
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        if (progress.isFinite) { // Only update if progress is a valid number
          setState(() {
            _progress = 0.2 + (progress * 0.3).clamp(0.0, 0.3); // Progress from 20% to 50%, clamped to valid range
            _currentStep = 'Uploading video: ${(progress * 100).toStringAsFixed(1)}%';
          });
        }
      });

      await uploadTask;
      final videoUrl = await storageRef.getDownloadURL();

      // Step 3: Transcribe video
      setState(() {
        _currentStep = 'Transcribing video...';
        _progress = 0.6;
      });

      final transcriptSegments = await aiService.transcribeVideo(fileToUpload);
      final transcriptData = transcriptSegments.map((segment) => segment.toMap()).toList();

      // Step 4: Generate recipe data
      setState(() {
        _currentStep = 'Analyzing recipe...';
        _progress = 0.8;
      });

      final recipeData = await aiService.generateRecipeData(
        transcriptSegments.map((s) => s.text).join(' ')
      );

      // Step 5: Create draft
      setState(() {
        _currentStep = 'Preparing results...';
        _progress = 0.9;
      });

      final draft = VideoDraft(
        userId: widget.userId,
        videoPath: widget.videoPath,
        videoUrl: videoUrl,
        title: recipeData['title'],
        description: recipeData['description'],
        ingredients: List<String>.from(recipeData['ingredients']),
        instructions: List<String>.from(recipeData['instructions']),
        calories: recipeData['calories'],
        cookTimeMinutes: recipeData['cookTimeMinutes'],
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
      );

      // Create the video document with proper data types
      final videoDoc = await FirebaseFirestore.instance.collection('videos').add({
        'userId': widget.userId,
        'videoPath': widget.videoPath,
        'videoUrl': videoUrl,
        'title': recipeData['title'],
        'description': recipeData['description'],
        'ingredients': List<String>.from(recipeData['ingredients']),
        'instructions': List<String>.from(recipeData['instructions']),
        'calories': recipeData['calories'],
        'cookTimeMinutes': recipeData['cookTimeMinutes'],
        'likes': 0,
        'likedBy': [],
        'views': 0,
        'commentCount': 0,
        'isPinned': false,
        'createdAt': FieldValue.serverTimestamp(),
        'thumbnailUrl': '',
        'username': '',
        'userImage': '',
        'transcriptSegments': transcriptData,
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VideoProcessingWizard(
              draft: draft,
            ),
          ),
        );
      }

      // Clean up
      if (fileToUpload.path != videoFile.path) {
        try {
          await fileToUpload.delete();
        } catch (e) {
          debugPrint('Error deleting compressed video: $e');
        }
      }
      await VideoCompress.deleteAllCache();

      if (mounted) {
        Navigator.of(context).pop(videoDoc.id);
      }
    } catch (e) {
      if (_isDisposed) return;
      
      debugPrint('Error processing video: $e');
      setState(() {
        _error = e.toString();
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                if (mounted) {
                  _processVideo();
                }
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                    width: 8,
                  ),
                ),
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _ProcessingPainter(
                        progress: _progress,
                        animationValue: _progressAnimation.value,
                        color: Theme.of(context).primaryColor,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _currentStep,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey[200],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProcessingPainter extends CustomPainter {
  final double progress;
  final double animationValue;
  final Color color;

  _ProcessingPainter({
    required this.progress,
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - paint.strokeWidth) / 2;

    // Draw progress arc
    final progressRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      progressRect,
      -1.5708, // Start from top (90° = pi/2 = 1.5708 rad)
      progress * 2 * 3.14159,
      false,
      paint,
    );

    // Draw animated dot
    final dotAngle = 2 * 3.14159 * animationValue - 1.5708;
    final dotX = center.dx + radius * cos(dotAngle);
    final dotY = center.dy + radius * sin(dotAngle);

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(dotX, dotY), 6, dotPaint);
  }

  @override
  bool shouldRepaint(_ProcessingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.animationValue != animationValue;
  }
} 