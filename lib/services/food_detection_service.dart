import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class FoodDetectionService {
  static bool _isInitialized = false;
  final String _apiKey;
  final String _modelEndpoint = 'https://detect.roboflow.com/food-imgae-yolo/2';
  
  FoodDetectionService() : _apiKey = dotenv.env['ROBOFLOW_API_KEY'] ?? '' {
    if (_apiKey.isEmpty) {
      throw Exception('ROBOFLOW_API_KEY not found in environment variables');
    }
  }
  
  Future<List<DetectedFood>> detectFood(File imageFile) async {
    try {
      // Convert image to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // Make API request
      final response = await http.post(
        Uri.parse('$_modelEndpoint?api_key=$_apiKey'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: base64Image,
      );
      
      if (response.statusCode != 200) {
        throw Exception('API request failed with status ${response.statusCode}: ${response.body}');
      }
      
      // Parse response
      final data = jsonDecode(response.body);
      final predictions = data['predictions'] as List;
      
      return predictions.map((pred) => DetectedFood(
        label: pred['class'],
        confidence: pred['confidence'].toDouble(),
        boundingBox: Rect.fromLTWH(
          pred['x'].toDouble(),
          pred['y'].toDouble(),
          pred['width'].toDouble(),
          pred['height'].toDouble(),
        ),
      )).toList();
      
    } catch (e) {
      throw Exception('Food detection failed: $e');
    }
  }
}

class DetectedFood {
  final String label;
  final double confidence;
  final Rect boundingBox;
  
  DetectedFood({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });
} 