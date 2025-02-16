import 'package:image_editor_plus/image_editor_plus.dart';

final List<ImageFilterOption> foodiePresetFilters = [
  ImageFilterOption(name: 'Original'),
  ImageFilterOption(name: 'Vibrant', brightness: 0.3, contrast: 1.3, saturation: 1.3),
  ImageFilterOption(name: 'Warm', brightness: 0.2, warmth: 0.3, saturation: 1.1),
  ImageFilterOption(name: 'Fresh', brightness: 0.1, contrast: 1.2, saturation: 1.1),
  ImageFilterOption(name: 'Crisp', brightness: 0.1, contrast: 1.5, saturation: 1.2),
  ImageFilterOption(name: 'Gourmet', brightness: 0.1, contrast: 1.1, saturation: 1.1),
  ImageFilterOption(name: 'Rustic', brightness: -0.1, contrast: 1.1, saturation: 0.9),
  ImageFilterOption(name: 'Dramatic', brightness: -0.2, contrast: 1.5, saturation: 1.2),
];

class ImageFilterOption {
  final String name;
  final double brightness;
  final double contrast;
  final double saturation;
  final double warmth;

  ImageFilterOption({
    required this.name,
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
    this.warmth = 0.0,
  });
} 