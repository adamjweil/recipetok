import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

class FoodLoadingAnimation extends StatefulWidget {
  final double size;
  
  const FoodLoadingAnimation({
    super.key,
    this.size = 120,
  });

  @override
  State<FoodLoadingAnimation> createState() => _FoodLoadingAnimationState();
}

class _FoodLoadingAnimationState extends State<FoodLoadingAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RotationTransition(
          turns: _animation,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.restaurant,
                size: widget.size,
                color: Colors.grey[300],
              ),
              ScaleTransition(
                scale: _animation,
                child: Icon(
                  Icons.auto_awesome,
                  size: widget.size * 0.5,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Creating artistic interpretation...',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class ImageEnhancementPreview extends StatelessWidget {
  final File originalImage;
  final String? enhancedImageUrl;
  final bool isLoading;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onRetry;
  final String? error;

  const ImageEnhancementPreview({
    super.key,
    required this.originalImage,
    this.enhancedImageUrl,
    required this.isLoading,
    required this.onAccept,
    required this.onReject,
    required this.onRetry,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Artistic Interpretation'),
        actions: [
          if (enhancedImageUrl != null && !isLoading && error == null)
            TextButton(
              onPressed: onAccept,
              child: const Text('Use Artwork'),
            ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onReject,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Enhanced Image Section
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Artistic Version',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          color: Colors.grey[200],
                          child: isLoading
                              ? const Center(
                                  child: FoodLoadingAnimation(size: 60),
                                )
                              : error != null
                                  ? SingleChildScrollView(
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.error_outline,
                                              color: Colors.red,
                                              size: 32,
                                            ),
                                            const SizedBox(height: 8),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16),
                                              child: Text(
                                                error!,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: onRetry,
                                              child: const Text('Retry'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : enhancedImageUrl != null
                                      ? CachedNetworkImage(
                                          imageUrl: enhancedImageUrl!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                          placeholder: (context, url) => const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                          errorWidget: (context, url, error) =>
                                              const Icon(Icons.error),
                                        )
                                      : const Center(
                                          child: Text('Processing...'),
                                        ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Original Photo',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),
            ),

            // Original Image Section
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    originalImage,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            // Bottom Buttons
            if (enhancedImageUrl != null && !isLoading && error == null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onReject,
                        child: const Text('Keep Original'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onAccept,
                        child: const Text('Use Artwork'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
} 