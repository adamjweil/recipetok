import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as path;
import 'package:recipetok/models/video_draft.dart';
import 'package:recipetok/services/ai_service.dart';
import 'package:recipetok/screens/video_processing_wizard.dart';

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

  final Set<String> _supportedFormats = {
    'flac', 'm4a', 'mp3', 'mp4', 'mpeg', 'mpga', 'oga', 'ogg', 'wav', 'webm'
  };

  bool _isFormatSupported(String filePath) {
    final extension = path.extension(filePath).toLowerCase().replaceAll('.', '');
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
    _controller.dispose();
    super.dispose();
  }

  Future<void> _processVideo() async {
    try {
      // Check video format first
      if (!_isFormatSupported(widget.videoPath)) {
        throw FormatException(
          'Unsupported video format. Please use one of the following formats: ${_supportedFormats.join(", ")}'
        );
      }

      final aiService = AIService();

      // Step 1: Transcribe video
      setState(() {
        _currentStep = 'Transcribing video...';
        _progress = 0.2;
      });

      final transcript = await aiService.transcribeVideo(File(widget.videoPath));

      // Step 2: Generate recipe data
      setState(() {
        _currentStep = 'Analyzing recipe...';
        _progress = 0.6;
      });

      final recipeData = await aiService.generateRecipeData(transcript);

      // Step 3: Create draft
      setState(() {
        _currentStep = 'Preparing results...';
        _progress = 0.9;
      });

      final draft = VideoDraft(
        userId: widget.userId,
        videoPath: widget.videoPath,
        title: recipeData['title'],
        description: recipeData['description'],
        ingredients: List<String>.from(recipeData['ingredients']),
        instructions: List<String>.from(recipeData['instructions']),
        calories: recipeData['calories'],
        cookTimeMinutes: recipeData['cookTimeMinutes'],
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
      );

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is FormatException 
                ? e.message 
                : 'Error processing video: $e'
            ),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
        // Add a slight delay before popping to ensure the user sees the message
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
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