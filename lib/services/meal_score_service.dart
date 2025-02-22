import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meal_score.dart';
import '../services/ai_service.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class MealScoreService {
  static const double _maxScore = 10.0;
  final AIService _aiService = AIService();
  
  // Weights for different scoring components
  static const Map<String, double> _weights = {
    'presentation': 0.25,
    'photoQuality': 0.15,
    'nutrition': 0.20,
    'creativity': 0.20,
    'technical': 0.20,
  };

  Future<MealScore> analyzeMeal(String imageUrl, Map<String, dynamic> mealData) async {
    File? tempFile;
    try {
      // Download the image to a temporary file for analysis
      final response = await http.get(Uri.parse(imageUrl));
      final bytes = response.bodyBytes;
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      tempFile = File('${tempDir.path}/temp_image_$timestamp.jpg');
      await tempFile.writeAsBytes(bytes);

      // Use existing AIService to analyze the image
      final analysis = await _aiService.analyzeFoodImages([tempFile]);
      
      // Ensure analysis is a Map
      final Map<String, dynamic> safeAnalysis = analysis is Map<String, dynamic> 
          ? analysis 
          : {'ingredients': [], 'colors': [], 'objects': [], 'imageQuality': {}};

      return _calculateScore(mealData, safeAnalysis);
    } catch (e) {
      print('Error in analyzeMeal: $e');
      // If AI analysis fails, use basic scoring with empty analysis
      return _calculateScore(mealData, {});
    } finally {
      // Clean up temp file
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        print('Error cleaning up temp file: $e');
      }
    }
  }

  MealScore _calculateScore(Map<String, dynamic> mealData, Map<String, dynamic> aiAnalysis) {
    // Ensure lists exist with proper types, handling both String and List types for ingredients
    final List<String> detectedColors = (aiAnalysis['colors'] as List?)?.cast<String>() ?? [];
    final List<String> detectedObjects = (aiAnalysis['objects'] as List?)?.cast<String>() ?? [];
    
    // Handle ingredients that could be either a String or a List
    List<String> detectedIngredients = [];
    if (aiAnalysis['ingredients'] is List) {
      detectedIngredients = (aiAnalysis['ingredients'] as List).map((e) => e.toString()).toList();
    } else if (aiAnalysis['ingredients'] is String) {
      detectedIngredients = (aiAnalysis['ingredients'] as String)
          .split('\n')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    
    final Map<String, dynamic> imageQuality = (aiAnalysis['imageQuality'] as Map<String, dynamic>?) ?? {};
    final List<String> cookingMethods = (aiAnalysis['cookingMethods'] as List?)?.cast<String>() ?? [];
    final List<String> cookingTechniques = (aiAnalysis['cookingTechniques'] as List?)?.cast<String>() ?? [];

    final presentationScore = _calculatePresentationScore(mealData, {
      'colors': detectedColors,
      'objects': detectedObjects,
    });
    final photoQualityScore = _calculatePhotoQualityScore(mealData, {'imageQuality': imageQuality});
    final nutritionScore = _calculateNutritionScore(mealData, {'ingredients': detectedIngredients});
    final creativityScore = _calculateCreativityScore(mealData, {
      'ingredients': detectedIngredients,
      'cookingMethods': cookingMethods,
    });
    final technicalScore = _calculateTechnicalScore(mealData, {
      'cookingTechniques': cookingTechniques,
    });

    final overallScore = (
      presentationScore * _weights['presentation']! +
      photoQualityScore * _weights['photoQuality']! +
      nutritionScore * _weights['nutrition']! +
      creativityScore * _weights['creativity']! +
      technicalScore * _weights['technical']!
    );

    return MealScore(
      overallScore: overallScore,
      presentationScore: presentationScore,
      photoQualityScore: photoQualityScore,
      nutritionScore: nutritionScore,
      creativityScore: creativityScore,
      technicalScore: technicalScore,
      aiCritique: _generateCritique(mealData, {
        'ingredients': detectedIngredients,
        'cookingMethods': cookingMethods,
        'colors': detectedColors,
      }),
      strengths: _identifyStrengths(mealData, {
        'ingredients': detectedIngredients,
        'imageQuality': imageQuality,
      }),
      improvements: _identifyImprovements(mealData, {
        'ingredients': detectedIngredients,
        'imageQuality': imageQuality,
      }),
    );
  }

  double _calculatePresentationScore(Map<String, dynamic> mealData, Map<String, dynamic> aiAnalysis) {
    double score = 7.0; // Base score
    
    final detectedColors = aiAnalysis['colors'] as List<String>? ?? [];
    final detectedObjects = aiAnalysis['objects'] as List<String>? ?? [];
    
    // Adjust based on color variety
    if (detectedColors.length >= 5) score += 1.0;
    else if (detectedColors.length >= 3) score += 0.5;
    
    // Adjust based on plating detection
    if (detectedObjects.contains('plate')) score += 0.5;
    if (detectedObjects.contains('garnish')) score += 0.5;
    
    return _clampScore(score);
  }

  double _calculatePhotoQualityScore(Map<String, dynamic> mealData, Map<String, dynamic> aiAnalysis) {
    double score = 7.0; // Base score
    
    final imageQuality = aiAnalysis['imageQuality'] as Map<String, dynamic>? ?? {};
    
    // Adjust based on image quality metrics
    if (imageQuality['brightness'] == 'good') score += 1.0;
    if (imageQuality['focus'] == 'good') score += 1.0;
    if (imageQuality['resolution'] == 'high') score += 1.0;
    
    return _clampScore(score);
  }

  double _calculateNutritionScore(Map<String, dynamic> mealData, Map<String, dynamic> aiAnalysis) {
    double score = 6.0; // Base score
    
    final detectedIngredients = aiAnalysis['ingredients'] as List<String>? ?? [];
    final protein = (mealData['protein'] as num?)?.toDouble() ?? 0;
    
    // Score based on protein content
    if (protein >= 20) score += 1.0;
    else if (protein >= 15) score += 0.5;
    
    // Score based on vegetable content
    final vegetableCount = detectedIngredients.where((i) => 
      i.toString().toLowerCase().contains('vegetable') ||
      i.toString().toLowerCase().contains('salad')
    ).length;
    
    if (vegetableCount >= 2) score += 1.5;
    else if (vegetableCount >= 1) score += 0.75;
    
    return _clampScore(score);
  }

  double _calculateCreativityScore(Map<String, dynamic> mealData, Map<String, dynamic> aiAnalysis) {
    double score = 6.5; // Base score
    
    final detectedIngredients = aiAnalysis['ingredients'] as List<String>? ?? [];
    final uniqueIngredients = detectedIngredients.length;
    
    // Score based on ingredient variety
    if (uniqueIngredients >= 6) score += 1.5;
    else if (uniqueIngredients >= 4) score += 1.0;
    
    // Score based on cooking method detection
    final cookingMethods = aiAnalysis['cookingMethods'] as List<String>? ?? [];
    if (cookingMethods.length >= 2) score += 1.0;
    
    return _clampScore(score);
  }

  double _calculateTechnicalScore(Map<String, dynamic> mealData, Map<String, dynamic> aiAnalysis) {
    double score = 7.0; // Base score
    
    final cookingTime = mealData['cookTime'] as String? ?? '';
    final detectedTechniques = aiAnalysis['cookingTechniques'] as List<String>? ?? [];
    
    // Score based on cooking time
    if (cookingTime.contains('hour')) score += 0.5;
    
    // Score based on detected techniques
    if (detectedTechniques.length >= 2) score += 1.5;
    else if (detectedTechniques.length >= 1) score += 1.0;
    
    return _clampScore(score);
  }

  String _generateCritique(Map<String, dynamic> mealData, Map<String, dynamic> aiAnalysis) {
    final detectedIngredients = aiAnalysis['ingredients'] as List<String>? ?? [];
    final cookingMethods = aiAnalysis['cookingMethods'] as List<String>? ?? [];
    final colors = aiAnalysis['colors'] as List? ?? [];
    
    List<String> critiques = [];
    
    // Add ingredient-based critique
    if (detectedIngredients.isNotEmpty) {
      critiques.add("The dish showcases a nice combination of ${detectedIngredients.take(3).join(', ')}.");
    }
    
    // Add cooking method critique
    if (cookingMethods.isNotEmpty) {
      critiques.add("The ${cookingMethods.first} technique was well executed.");
    }
    
    // Add presentation critique
    if (colors.length >= 3) {
      critiques.add("The plating demonstrates good color balance and visual appeal.");
    }
    
    // Add nutrition critique
    if (mealData['protein'] != null) {
      critiques.add("The protein content is well-considered at ${mealData['protein']}g.");
    }
    
    return critiques.join(' ');
  }

  List<String> _identifyStrengths(Map<String, dynamic> mealData, Map<String, dynamic> aiAnalysis) {
    List<String> strengths = [];
    
    final imageQuality = aiAnalysis['imageQuality'] as Map<String, dynamic>? ?? {};
    final detectedIngredients = aiAnalysis['ingredients'] as List<String>? ?? [];
    final colors = aiAnalysis['colors'] as List? ?? [];
    
    if (imageQuality['brightness'] == 'good') {
      strengths.add("Well-lit presentation");
    }
    
    if (detectedIngredients.length >= 4) {
      strengths.add("Good variety of ingredients");
    }
    
    if (mealData['protein'] != null && mealData['protein'] >= 20) {
      strengths.add("Excellent protein content");
    }
    
    if (colors.length >= 3) {
      strengths.add("Strong visual composition");
    }
    
    return strengths;
  }

  List<String> _identifyImprovements(Map<String, dynamic> mealData, Map<String, dynamic> aiAnalysis) {
    List<String> improvements = [];
    
    final imageQuality = aiAnalysis['imageQuality'] as Map<String, dynamic>? ?? {};
    final detectedIngredients = aiAnalysis['ingredients'] as List<String>? ?? [];
    final objects = aiAnalysis['objects'] as List? ?? [];
    
    if (imageQuality['brightness'] != 'good') {
      improvements.add("Consider better lighting for the photo");
    }
    
    if (detectedIngredients.length < 3) {
      improvements.add("Could incorporate more ingredient variety");
    }
    
    if (!objects.contains('garnish')) {
      improvements.add("Consider adding garnish for visual appeal");
    }
    
    if (mealData['protein'] != null && mealData['protein'] < 15) {
      improvements.add("Could increase protein content");
    }
    
    return improvements;
  }

  double _clampScore(double score) {
    return score.clamp(0.0, _maxScore);
  }
} 