import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:meal_post/utils/custom_cache_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpandableMealPost extends StatefulWidget {
  final Post post;

  const ExpandableMealPost({Key? key, required this.post}) : super(key: key);

  @override
  _ExpandableMealPostState createState() => _ExpandableMealPostState();
}

class _ExpandableMealPostState extends State<ExpandableMealPost> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildPostImage(widget.post.photoUrls.first),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: () => _handleImageTap(),
            child: Stack(
              children: [
                if (widget.post.photoUrls.length > 1)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 50,
                      color: Colors.black.withOpacity(0.5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_left, color: Colors.white),
                            onPressed: _handlePreviousImage,
                          ),
                          IconButton(
                            icon: Icon(Icons.arrow_right, color: Colors.white),
                            onPressed: _handleNextImage,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostImage(String? imageUrl) {
    return Stack(
      children: [
        if (widget.post.photoUrls.isEmpty)
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              color: Colors.grey[200],
              child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
            ),
          )
        else
          AspectRatio(
            aspectRatio: 1,
            child: PageView.builder(
              itemCount: widget.post.photoUrls.length,
              itemBuilder: (context, index) {
                final url = widget.post.photoUrls[index];
                if (!CustomCacheManager.isValidImageUrl(url)) {
                  return Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
                  );
                }

                return CachedNetworkImage(
                  imageUrl: url,
                  cacheManager: CustomCacheManager.instance,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.error_outline, color: Colors.grey[400]),
                  ),
                );
              },
            ),
          ),
        // Add page indicator dots if there are multiple photos
        if (widget.post.photoUrls.length > 1)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '1/${widget.post.photoUrls.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _handleImageTap() {
    // Handle image tap
  }

  void _handlePreviousImage() {
    // Handle previous image
  }

  void _handleNextImage() {
    // Handle next image
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