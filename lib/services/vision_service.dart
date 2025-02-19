import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/vision/v1.dart' as vision;
import 'package:flutter/foundation.dart';

class VisionService {
  static final VisionService _instance = VisionService._internal();
  static VisionService get instance => _instance;
  
  AutoRefreshingAuthClient? _client;
  bool _isInitialized = false;
  static const _scope = [vision.VisionApi.cloudVisionScope];

  VisionService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load service account credentials
      final credentialsFile = await rootBundle.loadString('assets/credentials/google_cloud_credentials.json');
      final credentials = ServiceAccountCredentials.fromJson(credentialsFile);
      
      // Create an authenticated client
      _client = await clientViaServiceAccount(credentials, _scope);
      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize Vision API: $e');
    }
  }

  Future<Map<String, double>> detectFood(File imageFile) async {
    if (!_isInitialized || _client == null) {
      throw Exception('Vision API not initialized. Call initialize() first.');
    }

    try {
      // Read the image file as bytes and convert to base64
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      
      // Create Vision API instance
      final visionApi = vision.VisionApi(_client!);
      
      // Create the request
      final request = vision.BatchAnnotateImagesRequest(requests: [
        vision.AnnotateImageRequest(
          image: vision.Image(content: base64Image),
          features: [
            vision.Feature(
              maxResults: 20,
              type: 'LABEL_DETECTION',
            ),
          ],
        ),
      ]);

      // Make the API call
      final response = await visionApi.images.annotate(request);

      if (response.responses == null || response.responses!.isEmpty) {
        throw Exception('No response from Vision API');
      }

      // Parse the response
      final annotations = response.responses!.first.labelAnnotations;
      debugPrint('🔍 Raw annotations: $annotations');
      if (annotations == null) return {};

      // Log the type and structure of the first annotation
      if (annotations.isNotEmpty) {
        final firstAnnotation = annotations.first;
        debugPrint('📝 First annotation type: ${firstAnnotation.runtimeType}');
        debugPrint('📝 First annotation data: description=${firstAnnotation.description}, score=${firstAnnotation.score}');
      }

      // Filter and process food-related labels
      debugPrint('🔄 Starting food label processing...');
      final foodLabels = annotations
          .where((vision.EntityAnnotation label) {
            final description = label.description;
            debugPrint('👉 Processing label description: $description');
            if (description == null) return false;
            return _isFoodRelated(description);
          })
          .map((vision.EntityAnnotation label) {
            debugPrint('✨ Creating MapEntry for: ${label.description} with score: ${label.score}');
            return MapEntry(
              label.description ?? '',
              (label.score ?? 0.0).toDouble(),
            );
          });

      final result = Map.fromEntries(foodLabels);
      debugPrint('✅ Final result: $result');
      return result;
    } catch (e, stackTrace) {
      debugPrint('❌ Error in detectFood: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      return {};
    }
  }

  bool _isFoodRelated(String label) {
    final foodKeywords = <String>[
      'food',
      'dish',
      'meal',
      'cuisine',
      'ingredient',
      'vegetable',
      'fruit',
      'meat',
      'dessert',
      'snack',
      'breakfast',
      'lunch',
      'dinner',
      'drink',
      'beverage',
    ];

    final label_lower = label.toLowerCase();
    debugPrint('🔍 Checking if "$label_lower" is food related');
    return foodKeywords.any((String keyword) {
      final bool contains = label_lower.contains(keyword);
      debugPrint('  - Testing keyword "$keyword": $contains');
      return contains;
    });
  }
} 