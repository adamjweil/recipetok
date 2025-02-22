import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../utils/custom_cache_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/meal_post.dart';
import '../../models/meal_score.dart';
import '../../services/meal_score_service.dart';
import '../meal_score_screen.dart';

class ExpandableMealPost extends StatefulWidget {
  final MealPost post;

  const ExpandableMealPost({
    super.key,
    required this.post,
  });

  @override
  State<ExpandableMealPost> createState() => _ExpandableMealPostState();
}

class _ExpandableMealPostState extends State<ExpandableMealPost> {
  final MealScoreService _scoreService = MealScoreService();

  void _showMealScore() async {
    try {
      final mealScore = await _scoreService.analyzeMeal(
        widget.post.photoUrls.first,
        {
          'protein': widget.post.protein,
          'cookTime': widget.post.cookTime.toString(),
          'calories': widget.post.calories,
          'isVegetarian': widget.post.isVegetarian,
          'ingredients': widget.post.ingredients,
          'instructions': widget.post.instructions,
        },
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MealScoreScreen(
            mealScore: mealScore,
            imageUrl: widget.post.photoUrls.first,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading meal score: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildPostImage(),
        Positioned(
          top: 16,
          right: 16,
          child: GestureDetector(
            onTap: _showMealScore,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.post.mealScore.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostImage() {
    return AspectRatio(
      aspectRatio: 1,
      child: widget.post.photoUrls.isEmpty
          ? Container(
              color: Colors.grey[200],
              child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
            )
          : CachedNetworkImage(
              imageUrl: widget.post.photoUrls.first,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                child: Icon(Icons.error_outline, color: Colors.grey[400]),
              ),
            ),
    );
  }

  Future<void> _deletePost(BuildContext context) async {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    bool hasError = false;
    String? errorMessage;
    
    try {
      // Close the confirmation dialog
      rootNavigator.pop();
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );

      // Delete the post and all its subcollections
      final batch = FirebaseFirestore.instance.batch();
      final postRef = FirebaseFirestore.instance.collection('meal_posts').doc(widget.post.id);
      
      // Delete likes subcollection
      final likesSnapshot = await postRef.collection('likes').get();
      for (var doc in likesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete comments subcollection
      final commentsSnapshot = await postRef.collection('comments').get();
      for (var doc in commentsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete the main post document
      batch.delete(postRef);
      
      // Commit all deletions
      await batch.commit();
    } catch (e) {
      hasError = true;
      errorMessage = e.toString();
      debugPrint('Error deleting post: $e');
    }

    // Ensure we're still mounted before proceeding
    if (!mounted) return;

    // Close loading dialog
    rootNavigator.pop();

    if (hasError) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting post: $errorMessage'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post deleted successfully'),
        duration: Duration(seconds: 2),
      ),
    );

    // Pop back to the main feed
    rootNavigator.popUntil((route) => route.isFirst);
  }
} 