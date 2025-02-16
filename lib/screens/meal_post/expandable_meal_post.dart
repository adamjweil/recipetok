import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:meal_post/utils/custom_cache_manager.dart';

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
} 