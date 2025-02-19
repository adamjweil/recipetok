import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/vision/v1.dart' as vision;

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
              type: 'LABEL_DETECTION',
              maxResults: 20,
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
      if (annotations == null) return {};

      // Filter and process food-related labels
      final foodLabels = annotations
          .where((label) => _isFoodRelated(label.description ?? ''))
          .map((label) => MapEntry(
                label.description ?? '',
                label.score ?? 0.0,
              ));

      return Map.fromEntries(foodLabels);
    } catch (e) {
      throw Exception('Failed to detect food in image: $e');
    }
  }

  bool _isFoodRelated(String label) {
    final foodKeywords = [
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
    ];

    final label_lower = label.toLowerCase();
    return foodKeywords.any((keyword) => label_lower.contains(keyword));
  }
} 