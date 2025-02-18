import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../services/image_service.dart';

class RecipeModal extends StatefulWidget {
  final String cuisine;
  final Function(Recipe) onSave;

  const RecipeModal({
    super.key,
    required this.cuisine,
    required this.onSave,
  });

  @override
  State<RecipeModal> createState() => _RecipeModalState();
}

class _RecipeModalState extends State<RecipeModal> {
  bool _isLoading = true;
  Recipe? _recipe;
  String? _imageUrl;
  final _recipeService = RecipeService();
  final _imageService = ImageService();

  @override
  void initState() {
    super.initState();
    _generateRecipe();
  }

  Future<void> _generateRecipe() async {
    debugPrint('🔄 Generating recipe for cuisine: ${widget.cuisine}');
    
    try {
      final recipeJsonString = await _recipeService.generateRecipe(widget.cuisine);
      debugPrint('📥 Received recipe data: $recipeJsonString');
      
      if (!mounted) return;

      // Parse the JSON string into a Map
      final recipeJson = json.decode(recipeJsonString) as Map<String, dynamic>;
      
      // Fetch an image for the recipe
      final imageUrl = await _imageService.getFoodImage(
        recipeJson['title'] ?? widget.cuisine,
        cuisine: widget.cuisine,
      );
      
      // Create recipe data using the parsed JSON
      final Map<String, dynamic> recipeData = {
        'id': DateTime.now().toIso8601String(),
        'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
        'title': recipeJson['title'] ?? 'Delicious ${widget.cuisine} Recipe',
        'description': recipeJson['description'] ?? 'A wonderful ${widget.cuisine} dish that will delight your taste buds.',
        'ingredients': recipeJson['ingredients'] ?? [],
        'instructions': recipeJson['instructions'] ?? [],
        'cuisine': widget.cuisine,
        'servings': recipeJson['servings'] ?? 4,
        'prepTimeMinutes': recipeJson['prepTimeMinutes'] ?? 15,
        'cookTimeMinutes': recipeJson['cookTimeMinutes'] ?? 30,
        'createdAt': DateTime.now(),
        'imageUrl': imageUrl,
      };

      debugPrint('✨ Created recipe data: $recipeData');

      if (!mounted) return;
      
      setState(() {
        _recipe = Recipe(
          id: recipeData['id'],
          userId: recipeData['userId'],
          title: recipeData['title'],
          description: recipeData['description'],
          ingredients: List<String>.from(recipeData['ingredients']),
          instructions: List<String>.from(recipeData['instructions']),
          cuisine: recipeData['cuisine'],
          servings: recipeData['servings'],
          prepTimeMinutes: recipeData['prepTimeMinutes'],
          cookTimeMinutes: recipeData['cookTimeMinutes'],
          createdAt: recipeData['createdAt'],
          imageUrl: recipeData['imageUrl'],
        );
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error generating recipe: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating recipe: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  void _copyRecipe() {
    if (_recipe == null) return;

    final recipeText = '''
${_recipe!.title}

Description:
${_recipe!.description}

Ingredients:
${_recipe!.ingredients.map((i) => '• $i').join('\n')}

Instructions:
${_recipe!.instructions.map((i) => '• $i').join('\n')}

Prep Time: ${_recipe!.prepTimeMinutes} mins
Cook Time: ${_recipe!.cookTimeMinutes} mins
Servings: ${_recipe!.servings}
''';

    Clipboard.setData(ClipboardData(text: recipeText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recipe copied to clipboard')),
    );
  }

  void _shareRecipe() {
    if (_recipe == null) return;

    final recipeText = '''
Check out this ${_recipe!.cuisine} recipe!

${_recipe!.title}

${_recipe!.description}

Ingredients:
${_recipe!.ingredients.map((i) => '• $i').join('\n')}

Instructions:
${_recipe!.instructions.map((i) => '• $i').join('\n')}

Prep Time: ${_recipe!.prepTimeMinutes} mins
Cook Time: ${_recipe!.cookTimeMinutes} mins
Servings: ${_recipe!.servings}
''';

    Share.share(recipeText);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: MediaQuery.of(context).size.width * 0.95,
        ),
        child: _isLoading
            ? _buildLoadingState()
            : _buildRecipeContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: 100,
            width: 100,
            child: CircularProgressIndicator(),
          ),
          const SizedBox(height: 24),
          Text(
            'Generating ${widget.cuisine} recipe...',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeContent() {
    if (_recipe == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.cuisine,
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _recipe!.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _recipe!.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          if (_recipe!.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: _recipe!.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.restaurant),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoCard(
                icon: Icons.timer,
                label: 'Prep Time',
                value: '${_recipe!.prepTimeMinutes}m',
              ),
              _buildInfoCard(
                icon: Icons.local_fire_department,
                label: 'Cook Time',
                value: '${_recipe!.cookTimeMinutes}m',
              ),
              _buildInfoCard(
                icon: Icons.people,
                label: 'Servings',
                value: _recipe!.servings.toString(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Ingredients',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ..._recipe!.ingredients.map((ingredient) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(Icons.fiber_manual_record, size: 6, color: Colors.grey[400]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ingredient,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 16),
          const Text(
            'Instructions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ..._recipe!.instructions.asMap().entries.map((entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${entry.key + 1}',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyRecipe,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareRecipe,
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                widget.onSave(_recipe!);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.bookmark, size: 18),
              label: const Text('Save Recipe', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).primaryColor),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
} 