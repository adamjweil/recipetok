import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:ui' as ui;
import '../models/meal_post.dart';
import '../utils/custom_cache_manager.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path/path.dart' as path;

class MealSharingService {
  static const String APP_SCHEME = 'recipetok';
  static const String APP_HOST = 'recipetok.app';
  static const String APP_NAME = 'RecipeTok';
  static const String APP_PACKAGE_NAME = 'com.recipetok.app';

  /// Creates a dynamic link for sharing a meal post
  Future<String> createMealShareLink(MealPost post) async {
    final dynamicLinkParams = DynamicLinkParameters(
      uriPrefix: 'https://recipetok.page.link',
      link: Uri.parse('https://$APP_HOST/meal/${post.id}'),
      androidParameters: AndroidParameters(
        packageName: APP_PACKAGE_NAME,
        minimumVersion: 1,
      ),
      iosParameters: IOSParameters(
        bundleId: APP_PACKAGE_NAME,
        minimumVersion: '1.0.0',
        appStoreId: '6475357667', // Replace if you have a different App Store ID
      ),
      socialMetaTagParameters: SocialMetaTagParameters(
        title: post.title,
        description: post.description ?? 'Check out this recipe on RecipeTok!',
        imageUrl: Uri.parse(post.photoUrls.first),
      ),
      navigationInfoParameters: NavigationInfoParameters(
        forcedRedirectEnabled: true,
      ),
    );

    final dynamicLink = await FirebaseDynamicLinks.instance.buildShortLink(
      dynamicLinkParams,
      shortLinkType: ShortDynamicLinkType.unguessable,
    );

    return dynamicLink.shortUrl.toString();
  }

  /// Generates a visual preview card for the meal post
  Future<File> generateMealPreviewCard(MealPost post, BuildContext context) async {
    // Download and cache the meal image
    final File imageFile = await _downloadAndCacheImage(post.photoUrls.first);
    
    // Create a custom painter to draw the preview card
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = const Size(1200, 630); // Standard social sharing card size
    
    // Draw the background
    final paint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Load and draw the meal image
    final image = await _loadImage(imageFile);
    _drawOptimizedImage(canvas, image, size);

    // Add gradient overlay for better text visibility
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        Colors.black.withOpacity(0.7),
      ],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5),
      Paint()..shader = gradient.createShader(
        Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5),
      ),
    );

    // Draw text elements
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 48,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          offset: const Offset(2, 2),
          blurRadius: 3,
          color: Colors.black.withOpacity(0.5),
        ),
      ],
    );

    // Draw title
    _drawText(
      canvas,
      post.title,
      const Offset(60, 480),
      textStyle,
      maxWidth: size.width - 120,
    );

    // Draw description snippet
    if (post.description != null) {
      final descriptionStyle = textStyle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.normal,
      );
      final description = post.description!.length > 60 
          ? '${post.description!.substring(0, 57)}...'
          : post.description!;
      _drawText(
        canvas,
        description,
        const Offset(60, 540),
        descriptionStyle,
        maxWidth: size.width - 120,
      );
    }

    // Draw meal score badge
    _drawMealScoreBadge(
      canvas,
      post.mealScore,
      Offset(size.width - 120, 60),
    );

    // Draw app logo and name
    await _drawAppBranding(canvas, const Offset(60, 60));

    // Convert to image
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    // Save to temporary file
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/meal_preview_${post.id}.png');
    await tempFile.writeAsBytes(buffer);

    return tempFile;
  }

  /// Share a meal post with rich preview
  Future<void> shareMealPost(BuildContext context, MealPost post) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Generate preview card and sharing link in parallel
      final Future<File> previewCardFuture = generateMealPreviewCard(post, context);
      final Future<String> shareLinkFuture = createMealShareLink(post);

      final results = await Future.wait([previewCardFuture, shareLinkFuture]);
      final previewCard = results[0] as File;
      final shareLink = results[1] as String;

      // Dismiss loading indicator
      Navigator.pop(context);

      // Share with native share sheet
      await Share.shareXFiles(
        [XFile(previewCard.path)],
        text: 'Check out this amazing recipe on RecipeTok!\n\n${post.title}\n\n$shareLink',
        subject: post.title,
      );

      // Track share event (implement your analytics here)
      // analyticsService.trackShare(post.id);

    } catch (e) {
      // Dismiss loading indicator if showing
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing post: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper methods
  Future<File> _downloadAndCacheImage(String imageUrl) async {
    final cache = CustomCacheManager.instance;
    final file = await cache.getSingleFile(imageUrl);
    return file;
  }

  Future<ui.Image> _loadImage(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  void _drawOptimizedImage(Canvas canvas, ui.Image image, Size size) {
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final fitSize = _calculateFitSize(imageSize, size);
    final src = Rect.fromLTWH(0, 0, imageSize.width, imageSize.height);
    final dst = Rect.fromLTWH(
      (size.width - fitSize.width) / 2,
      (size.height - fitSize.height) / 2,
      fitSize.width,
      fitSize.height,
    );
    canvas.drawImageRect(image, src, dst, Paint());
  }

  Size _calculateFitSize(Size imageSize, Size boundingBox) {
    final double aspectRatio = imageSize.width / imageSize.height;
    double width = boundingBox.width;
    double height = boundingBox.height;

    if (width / height > aspectRatio) {
      width = height * aspectRatio;
    } else {
      height = width / aspectRatio;
    }

    return Size(width, height);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position,
    TextStyle style, {
    double maxWidth = double.infinity,
  }) {
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    );
    textPainter.layout(maxWidth: maxWidth);
    textPainter.paint(canvas, position);
  }

  void _drawMealScoreBadge(Canvas canvas, double score, Offset position) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw circle background
    canvas.drawCircle(position, 40, paint);

    // Draw score text
    final textStyle = TextStyle(
      color: Colors.black,
      fontSize: 32,
      fontWeight: FontWeight.bold,
    );
    
    final textSpan = TextSpan(text: score.round().toString(), style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    final textOffset = Offset(
      position.dx - textPainter.width / 2,
      position.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, textOffset);
  }

  Future<void> _drawAppBranding(Canvas canvas, Offset position) async {
    try {
      // Load app icon instead of logo
      final ByteData data = await rootBundle.load('assets/icon/icon.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final logo = frame.image;

      // Draw logo
      final logoSize = const Size(40, 40);
      canvas.drawImageRect(
        logo,
        Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
        Rect.fromLTWH(position.dx, position.dy, logoSize.width, logoSize.height),
        Paint(),
      );

      // Draw app name
      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            offset: const Offset(1, 1),
            blurRadius: 2,
            color: Colors.black.withOpacity(0.5),
          ),
        ],
      );

      _drawText(
        canvas,
        APP_NAME,
        Offset(position.dx + logoSize.width + 10, position.dy + 8),
        textStyle,
      );
    } catch (e) {
      print('Error drawing app branding: $e');
      // If logo loading fails, just draw the app name
      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            offset: const Offset(1, 1),
            blurRadius: 2,
            color: Colors.black.withOpacity(0.5),
          ),
        ],
      );

      _drawText(
        canvas,
        APP_NAME,
        Offset(position.dx, position.dy + 8),
        textStyle,
      );
    }
  }
} 