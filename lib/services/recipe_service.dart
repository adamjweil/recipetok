import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/recipe.dart';
import 'dart:convert';

class RecipeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  static const String _baseUrl = 'https://api.openai.com/v1';

  Future<void> saveRecipe(Recipe recipe) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    debugPrint('💾 Saving recipe: ${recipe.title}');
    await _firestore.collection('recipes').add(recipe.toFirestore());
    debugPrint('✅ Recipe saved successfully');
  }

  Future<void> addRecipeToCollection(String recipeId, String collectionId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    debugPrint('📂 Adding recipe $recipeId to collection $collectionId');
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('groups')
        .doc(collectionId)
        .update({
      'recipes.$recipeId': {
        'addedAt': FieldValue.serverTimestamp(),
        'recipeId': recipeId,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('✅ Recipe added to collection successfully');
  }

  Future<void> removeRecipeFromCollection(String recipeId, String collectionId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    // Remove the recipe from the specified collection
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('groups')
        .doc(collectionId)
        .update({
      'recipes.$recipeId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Recipe>> getUserRecipes() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    return _firestore
        .collection('recipes')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Recipe.fromFirestore(doc))
            .toList());
  }

  Future<Recipe?> getRecipe(String recipeId) async {
    final doc = await _firestore.collection('recipes').doc(recipeId).get();
    if (!doc.exists) return null;
    return Recipe.fromFirestore(doc);
  }

  Future<List<Recipe>> getCollectionRecipes(String collectionId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    // Get the collection document
    final collectionDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('groups')
        .doc(collectionId)
        .get();

    if (!collectionDoc.exists) return [];

    // Get the recipes map from the collection
    final recipesMap = (collectionDoc.data()?['recipes'] as Map<String, dynamic>?) ?? {};

    // Get all recipe documents
    final recipeDocs = await Future.wait(
      recipesMap.keys.map((recipeId) =>
          _firestore.collection('recipes').doc(recipeId).get()),
    );

    // Convert documents to Recipe objects
    return recipeDocs
        .where((doc) => doc.exists)
        .map((doc) => Recipe.fromFirestore(doc))
        .toList();
  }

  Future<String> generateRecipe(String cuisine) async {
    debugPrint('🔄 Starting recipe generation for cuisine: $cuisine');
    
    try {
      final url = Uri.parse('$_baseUrl/chat/completions');
      final prompt = '''
Generate a recipe for a delicious $cuisine dish. Return ONLY a valid JSON object with this exact structure:
{
  "title": "Name of a specific $cuisine dish",
  "description": "Brief, appetizing description of the dish",
  "ingredients": ["List of ingredients with quantities"],
  "instructions": ["Step by step cooking instructions"],
  "servings": 4,
  "prepTimeMinutes": 20,
  "cookTimeMinutes": 30
}

Important:
1. Choose a specific, authentic $cuisine dish
2. Include precise measurements in ingredients
3. Write clear, detailed cooking steps
4. Keep instructions practical and easy to follow
5. Use realistic prep and cook times
6. Use only ASCII characters (no special characters)
7. Ensure the response is a SINGLE, valid JSON object
8. Do not include any additional text, comments, or formatting

The response must be a single, valid JSON object that can be parsed directly.
''';

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a professional chef specializing in $cuisine cuisine. You create clear, authentic recipes that are easy to follow. Always return only valid JSON with no additional text or formatting.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('❌ API Error: ${response.body}');
        throw Exception('Failed to generate recipe: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      var content = data['choices'][0]['message']['content'];
      
      // Clean and normalize the content
      content = content
          .replaceAll(RegExp(r'```json\s*'), '')  // Remove JSON code block markers
          .replaceAll(RegExp(r'```\s*'), '')      // Remove any remaining code block markers
          .replaceAll('°', ' degrees ')
          .replaceAll(RegExp(r'[éèêë]'), 'e')
          .replaceAll(RegExp(r'[àâäã]'), 'a')
          .replaceAll(RegExp(r'[ïî]'), 'i')
          .replaceAll(RegExp(r'[ôöõ]'), 'o')
          .replaceAll(RegExp(r'[ûüù]'), 'u')
          .replaceAll('ñ', 'n')
          .replaceAll('ç', 'c')
          .trim();

      // Try to parse the JSON to validate it
      try {
        final jsonData = json.decode(content) as Map<String, dynamic>;
        
        // Validate required fields
        final requiredFields = ['title', 'description', 'ingredients', 'instructions', 'servings', 'prepTimeMinutes', 'cookTimeMinutes'];
        for (final field in requiredFields) {
          if (!jsonData.containsKey(field)) {
            throw FormatException('Missing required field: $field');
          }
        }
        
        // Validate types
        if (!(jsonData['ingredients'] is List) || !(jsonData['instructions'] is List)) {
          throw FormatException('ingredients and instructions must be arrays');
        }
        
        if (!(jsonData['servings'] is num) || 
            !(jsonData['prepTimeMinutes'] is num) || 
            !(jsonData['cookTimeMinutes'] is num)) {
          throw FormatException('Time and serving values must be numbers');
        }

        debugPrint('✅ Generated valid recipe JSON');
        return content;
      } catch (e) {
        debugPrint('❌ Invalid JSON structure: $e');
        debugPrint('📝 Received content: $content');
        throw FormatException('Invalid recipe format: $e');
      }
    } catch (e) {
      debugPrint('❌ Error generating recipe: $e');
      rethrow;
    }
  }
} 