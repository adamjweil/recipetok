import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis/vision/v1.dart' as vision;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/meal_post.dart';

class GoogleVisionService {
  static const String _credentialsPath = 'assets/credentials/google_cloud_credentials.json';
  vision.VisionApi? _visionApi;

  Future<void> initialize() async {
    try {
      final credentialsJson = await rootBundle.loadString(_credentialsPath);
      final credentials = ServiceAccountCredentials.fromJson(
        json.decode(credentialsJson) as Map<String, dynamic>
      );
      
      final scopes = [vision.VisionApi.cloudVisionScope];
      final client = await clientViaServiceAccount(credentials, scopes);
      
      _visionApi = vision.VisionApi(client);
      debugPrint('Google Vision API initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Google Vision API: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> analyzeFoodImage(List<File> images) async {
    if (_visionApi == null) {
      await initialize();
    }

    try {
      final List<vision.AnnotateImageRequest> requests = [];
      
      for (var image in images) {
        final bytes = await image.readAsBytes();
        final content = base64Encode(bytes);

        final request = vision.AnnotateImageRequest(
          image: vision.Image(content: content),
          features: [
            vision.Feature(
              type: 'LABEL_DETECTION',
              maxResults: 10,
            ),
            vision.Feature(
              type: 'OBJECT_LOCALIZATION',
              maxResults: 10,
            ),
            vision.Feature(
              type: 'TEXT_DETECTION',
            ),
          ],
        );

        requests.add(request);
      }

      final batchRequest = vision.BatchAnnotateImagesRequest(requests: requests);
      final response = await _visionApi!.images.annotate(batchRequest);

      if (response.responses == null || response.responses!.isEmpty) {
        throw Exception('No response from Vision API');
      }

      // Process the results
      final results = _processVisionResults(response.responses!);
      return results;
    } catch (e) {
      debugPrint('Error analyzing images with Google Vision: $e');
      return {};
    }
  }

  Map<String, dynamic> _processVisionResults(List<vision.AnnotateImageResponse> responses) {
    final Set<String> foodItems = {};
    final Set<String> ingredients = {};
    final Set<String> detectedIngredients = {};
    bool isVegetarian = true;
    String? dishType;
    String? dishName;
    
    // Common non-vegetarian ingredients to check for
    final nonVegKeywords = {'meat', 'chicken', 'beef', 'pork', 'fish', 'seafood'};

    // Food category keywords to help identify dish types
    final foodCategories = {
      'salad': ['salad', 'lettuce', 'greens', 'vegetable dish'],
      'pasta': ['pasta', 'noodle', 'spaghetti', 'macaroni'],
      'sandwich': ['sandwich', 'burger', 'sub', 'wrap'],
      'soup': ['soup', 'stew', 'broth', 'chowder'],
      'dessert': ['cake', 'pie', 'ice cream', 'dessert', 'sweet'],
      'breakfast': ['eggs', 'pancake', 'waffle', 'breakfast', 'toast'],
      'protein': ['chicken', 'beef', 'fish', 'meat', 'steak', 'salmon'],
      'appetizer': ['appetizer', 'snack', 'finger food', 'starter'],
    };

    for (var response in responses) {
      // Process label annotations
      if (response.labelAnnotations != null) {
        for (var label in response.labelAnnotations!) {
          final description = label.description?.toLowerCase() ?? '';
          final confidence = label.score ?? 0.0;

          if (confidence > 0.7) {
            // Check for food items and categorize them
            if (description.contains('food') || 
                description.contains('dish') || 
                description.contains('meal') ||
                description.contains('cuisine')) {
              foodItems.add(label.description ?? '');
            }

            // Identify dish type based on categories
            for (var category in foodCategories.entries) {
              if (category.value.any((keyword) => description.contains(keyword))) {
                dishType = category.key;
                break;
              }
            }

            // Check for non-vegetarian ingredients
            if (nonVegKeywords.any((keyword) => description.contains(keyword))) {
              isVegetarian = false;
            }

            // Add as potential ingredient if it's a food item
            if (!description.contains('food') && 
                !description.contains('dish') && 
                !description.contains('meal') &&
                !description.contains('cuisine')) {
              ingredients.add(label.description ?? '');
              detectedIngredients.add(label.description ?? '');
            }
          }
        }
      }

      // Process object annotations for more specific food items
      if (response.localizedObjectAnnotations != null) {
        for (var object in response.localizedObjectAnnotations!) {
          final name = object.name?.toLowerCase() ?? '';
          final confidence = object.score ?? 0.0;

          if (confidence > 0.7 && (
              name.contains('food') || 
              foodCategories.values.any((keywords) => keywords.any((k) => name.contains(k))))) {
            detectedIngredients.add(object.name ?? '');
            if (dishName == null) {
              dishName = object.name;
            }
          }
        }
      }
    }

    // Determine the most specific dish name from detected items
    if (dishName == null && foodItems.isNotEmpty) {
      dishName = foodItems.first;
    }

    return {
      'foodItems': foodItems.toList(),
      'detectedIngredients': detectedIngredients.toList(),
      'ingredients': ingredients.join('\n'),
      'dishType': dishType,
      'dishName': dishName,
      'isVegetarian': isVegetarian,
      'confidence': {
        'title': 0.8,
        'description': 0.8,
        'mealType': 0.7,
        'ingredients': 0.7,
        'isVegetarian': 0.8,
      }
    };
  }

  String _generateTitle(Set<String> foodItems) {
    if (foodItems.isEmpty) {
      final defaultTitles = [
        'Mystery Meal Masterpiece 🎭',
        'Chef\'s Secret Creation ✨',
        'Culinary Plot Twist 🌟',
        'Kitchen Adventure Unveiled 🚀',
        'Foodie\'s Fantasy Dish 🌈'
      ];
      return defaultTitles[DateTime.now().microsecond % defaultTitles.length];
    }

    final items = foodItems.map((item) => item.toLowerCase()).toList();
    
    // Check for specific food combinations and return themed titles
    if (items.any((item) => item.contains('pizza'))) {
      return 'Slice of Heaven 🍕';
    }
    
    if (items.any((item) => item.contains('burger'))) {
      return 'Burger Bliss Beyond Words 🍔';
    }
    
    if (items.any((item) => item.contains('pasta'))) {
      return 'Pasta La Vista, Baby! 🍝';
    }
    
    if (items.any((item) => item.contains('sushi'))) {
      return 'Roll With It! 🍱';
    }
    
    if (items.any((item) => item.contains('salad'))) {
      return 'Lettuce Entertain You 🥗';
    }
    
    if (items.any((item) => item.contains('soup'))) {
      return 'Soup-er Duper Comfort 🥣';
    }
    
    if (items.any((item) => item.contains('cake'))) {
      return 'Having My Cake & Eating It Too 🎂';
    }
    
    if (items.any((item) => item.contains('ice cream'))) {
      return 'I Scream for Ice Cream! 🍨';
    }

    // For breakfast items
    if (items.any((item) => 
        item.contains('eggs') || 
        item.contains('bacon') || 
        item.contains('pancake') ||
        item.contains('waffle'))) {
      final breakfastTitles = [
        'Rise & Dine ☀️',
        'Morning Magic on a Plate 🌅',
        'Breakfast of Champions 🏆',
        'Dawn\'s Delicious Delight ⭐️'
      ];
      return breakfastTitles[DateTime.now().microsecond % breakfastTitles.length];
    }

    // For desserts and sweet items
    if (items.any((item) => 
        item.contains('cookie') || 
        item.contains('dessert') || 
        item.contains('sweet') ||
        item.contains('chocolate'))) {
      final dessertTitles = [
        'Sweet Dreams Are Made of This 🍪',
        'Sugar, Spice & Everything Nice ✨',
        'Dessert First, Questions Later 🍫',
        'Life Is Sweet 🧁'
      ];
      return dessertTitles[DateTime.now().microsecond % dessertTitles.length];
    }

    // For healthy foods
    if (items.any((item) => 
        item.contains('vegetable') || 
        item.contains('healthy') || 
        item.contains('organic'))) {
      final healthyTitles = [
        'Green & Clean Machine 🥬',
        'Wellness on a Plate 🌱',
        'Garden of Eatin\' 🥗',
        'Nature\'s Finest Feast 🌿'
      ];
      return healthyTitles[DateTime.now().microsecond % healthyTitles.length];
    }

    // If we have multiple items, create a fun combination title
    if (foodItems.length >= 2) {
      final mainItems = foodItems.take(2).map((item) => item.trim()).toList();
      final combos = [
        '${mainItems[0]} Meets ${mainItems[1]} ✨',
        'The Perfect Pair: ${mainItems[0]} & ${mainItems[1]} 🤝',
        '${mainItems[0]} Magic with ${mainItems[1]} Twist 🌟',
        'Dynamic Duo: ${mainItems[0]} + ${mainItems[1]} 💫'
      ];
      return combos[DateTime.now().microsecond % combos.length];
    }

    // For single items, add some flair
    final item = foodItems.first;
    final singleItemTitles = [
      '$item Perfection 💫',
      'The Ultimate $item Experience ✨',
      '$item Like Never Before 🌟',
      'Simply $item, Simply Amazing ⭐️'
    ];
    return singleItemTitles[DateTime.now().microsecond % singleItemTitles.length];
  }

  String _generateDescription(Set<String> foodItems) {
    if (foodItems.isEmpty) return 'A delightful culinary creation';
    
    final items = foodItems.take(3).join(', ');
    return 'A delicious dish featuring $items, prepared with care and attention to detail.';
  }

  MealType _determineMealType(Set<String> foodItems) {
    final items = foodItems.join(' ').toLowerCase();
    
    if (items.contains('breakfast') || 
        items.contains('eggs') || 
        items.contains('pancake') || 
        items.contains('toast')) {
      return MealType.breakfast;
    }
    
    if (items.contains('sandwich') || 
        items.contains('salad') || 
        items.contains('soup')) {
      return MealType.lunch;
    }
    
    if (items.contains('dinner') || 
        items.contains('steak') || 
        items.contains('pasta') || 
        items.contains('rice')) {
      return MealType.dinner;
    }
    
    return MealType.snack;
  }
} 