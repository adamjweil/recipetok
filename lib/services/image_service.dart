import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class ImageService {
  static final String _accessKey = dotenv.env['UNSPLASH_ACCESS_KEY'] ?? '';
  static const String _baseUrl = 'https://api.unsplash.com';

  Future<String?> getFoodImage(String query, {String? cuisine}) async {
    try {
      // Clean up the query to remove any non-food related words
      final cleanQuery = query
          .toLowerCase()
          .replaceAll(RegExp(r'recipe|dish|meal|delicious|tasty|homemade'), '')
          .trim();
      
      debugPrint('🔍 Original query: $query');
      debugPrint('🔍 Cleaned query: $cleanQuery');
      
      // Split query into keywords for better matching
      final keywords = cleanQuery.split(' ').where((word) => word.length > 2).toList();
      debugPrint('🔑 Keywords: $keywords');

      // Build search queries in order of specificity
      final searchQueries = [
        // Most specific: exact dish name + cuisine
        {
          'query': Uri.encodeComponent('$cleanQuery ${cuisine ?? ''} food dish'),
          'topics': 'food-drink',
        },
        // Fallback: just the dish name
        {
          'query': Uri.encodeComponent('$cleanQuery food'),
          'topics': 'food-drink',
        },
        // Last resort: cuisine type
        if (cuisine != null) {
          'query': Uri.encodeComponent('$cuisine food dish'),
          'topics': 'food-drink',
        },
      ];

      for (final searchConfig in searchQueries) {
        debugPrint('🔎 Trying search query: ${searchConfig['query']}');
        
        final url = Uri.parse(
          '$_baseUrl/search/photos'
          '?query=${searchConfig['query']}'
          '&topics=${searchConfig['topics']}'
          '&orientation=landscape'
          '&per_page=20'
          '&content_filter=high'
          '&order_by=relevant'
        );

        final response = await http.get(
          url,
          headers: {
            'Authorization': 'Client-ID $_accessKey',
            'Accept-Version': 'v1',
          },
        );

        if (response.statusCode != 200) {
          debugPrint('❌ Error fetching image: ${response.body}');
          continue;
        }

        final data = json.decode(response.body);
        final results = data['results'] as List;
        
        if (results.isEmpty) {
          debugPrint('⚠️ No images found for query: ${searchConfig['query']}');
          continue;
        }

        debugPrint('📸 Found ${results.length} potential images');

        // Score the results to find the most relevant image
        var bestScore = -1.0;
        String? bestImageUrl;
        int bestIndex = 0;

        for (var i = 0; i < results.length; i++) {
          final result = results[i];
          final description = (result['description'] ?? '').toLowerCase();
          final altDescription = (result['alt_description'] ?? '').toLowerCase();
          final title = (result['title'] ?? '').toLowerCase();
          final tags = (result['tags'] as List?)?.map((tag) => 
              (tag['title'] ?? '').toString().toLowerCase()
          ).toList() ?? [];
          
          var score = 0.0;
          var matchDetails = <String>[];

          // Start with a base score for being in the food-drink topic
          score += 2.0;
          matchDetails.add('food-drink topic');

          // Check for exact dish name match
          if (description.contains(cleanQuery) || 
              altDescription.contains(cleanQuery) ||
              title.contains(cleanQuery)) {
            score += 10.0;
            matchDetails.add('exact dish match');
          }

          // Check for keyword matches
          for (final keyword in keywords) {
            if (description.contains(keyword) || 
                altDescription.contains(keyword) ||
                title.contains(keyword)) {
              score += 3.0;
              matchDetails.add('keyword "$keyword" found');
            }
          }

          // Check for cuisine match
          if (cuisine != null) {
            final cuisinePattern = RegExp(r'\b' + cuisine.toLowerCase() + r'\b');
            if (cuisinePattern.hasMatch(description) || 
                cuisinePattern.hasMatch(altDescription) ||
                cuisinePattern.hasMatch(title) ||
                tags.any((tag) => cuisinePattern.hasMatch(tag))) {
              score += 5.0;
              matchDetails.add('cuisine match');
            }
          }

          // Penalize unwanted content
          final unwantedTerms = [
            'raw', 'ingredient', 'menu', 'restaurant', 'table',
            'fruit', 'drink', 'beverage', 'person', 'people',
            'hand', 'kitchen', 'grocery', 'cooking', 'preparation'
          ];
          
          for (final term in unwantedTerms) {
            if (description.contains(term) || 
                altDescription.contains(term) ||
                tags.any((tag) => tag.contains(term))) {
              score -= 5.0;
              matchDetails.add('unwanted term penalty: $term');
            }
          }

          debugPrint('🏆 Image $i Score: $score - ${matchDetails.join(', ')}');
          debugPrint('📝 Description: $description');
          debugPrint('🔄 Alt Description: $altDescription');
          debugPrint('🏷️ Tags: ${tags.join(', ')}');

          // Update best match if this score is higher
          if (score > bestScore) {
            bestScore = score;
            bestImageUrl = result['urls']['regular'] as String;
            bestIndex = i;
          }
        }

        // If we found a good match, return it
        if (bestScore > 5.0) {
          debugPrint('✨ Using best match (Image $bestIndex) with score $bestScore: $bestImageUrl');
          return bestImageUrl;
        }

        // If no good match, try next search query
        debugPrint('⚠️ No good matches found, trying next search query');
      }

      // If all searches failed, return null
      debugPrint('❌ No suitable images found after trying all search queries');
      return null;
    } catch (e) {
      debugPrint('❌ Error in getFoodImage: $e');
      return null;
    }
  }
} 