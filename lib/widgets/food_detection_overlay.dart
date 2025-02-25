import 'package:flutter/material.dart';
import '../models/food_detection.dart';

class FoodDetectionOverlay extends StatelessWidget {
  final List<FoodDetection> detections;
  final Size imageSize;

  const FoodDetectionOverlay({
    super.key,
    required this.detections,
    required this.imageSize,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: imageSize,
      painter: DetectionPainter(
        detections: detections,
        imageSize: imageSize,
      ),
    );
  }
}

class DetectionPainter extends CustomPainter {
  final List<FoodDetection> detections;
  final Size imageSize;

  DetectionPainter({
    required this.detections,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.green;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    for (final detection in detections) {
      // Convert normalized coordinates to actual pixels
      final rect = Rect.fromLTWH(
        detection.bbox.x * size.width,
        detection.bbox.y * size.height,
        detection.bbox.width * size.width,
        detection.bbox.height * size.height,
      );

      // Draw bounding box
      canvas.drawRect(rect, paint);

      // Draw label
      textPainter.text = TextSpan(
        text: '${detection.label} ${(detection.confidence * 100).toStringAsFixed(0)}%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          backgroundColor: Colors.green,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(rect.left, rect.top - textPainter.height),
      );
    }
  }

  @override
  bool shouldRepaint(DetectionPainter oldDelegate) => true;
} 