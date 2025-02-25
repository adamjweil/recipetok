class BoundingBox {
  final double x;
  final double y;
  final double width;
  final double height;

  BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class FoodDetection {
  final String label;
  final double confidence;
  final BoundingBox bbox;

  FoodDetection({
    required this.label,
    required this.confidence,
    required this.bbox,
  });
} 