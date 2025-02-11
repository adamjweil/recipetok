import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/chat_message.dart';
import '../../utils/custom_cache_manager.dart';

class PostLikeMessage extends StatelessWidget {
  final ChatMessage message;
  final bool isCurrentUser;

  const PostLikeMessage({
    super.key,
    required this.message,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = message.postThumbnailUrl;
    debugPrint('Debug: Rendering PostLikeMessage with URL: $thumbnailUrl');
    
    final hasValidImage = thumbnailUrl != null && 
                         thumbnailUrl.isNotEmpty && 
                         CustomCacheManager.isValidImageUrl(thumbnailUrl);
    
    debugPrint('Debug: URL validation result: $hasValidImage');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Post thumbnail with validation
          if (hasValidImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: thumbnailUrl,
                cacheManager: CustomCacheManager.instance,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) {
                  debugPrint('Debug: Image error: $error for URL: $url');
                  return _buildPlaceholder();
                },
                placeholder: (context, url) => _buildPlaceholder(),
              ),
            ),
          ] else
            _buildPlaceholder(),
          const SizedBox(width: 8),
          // Like notification content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Liked your post',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.postTitle ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (message.postDescription != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      message.postDescription!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  // View post button
                  TextButton(
                    onPressed: () {
                      // Navigate to post
                      Navigator.pushNamed(
                        context,
                        '/post/${message.postId}',
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('View Post'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: 20),
    );
  }
} 