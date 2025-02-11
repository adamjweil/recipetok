import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/chat_message.dart';
import '../../utils/custom_cache_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('meal_posts')
            .doc(message.postId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _buildPlaceholder(context);
          }

          final postData = snapshot.data?.data() as Map<String, dynamic>?;
          if (postData == null) {
            return _buildPlaceholder(context);
          }

          final photoUrl = postData['photoUrls']?[0] as String?;
          final description = postData['description'] as String?;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Post thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: photoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: photoUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _buildImagePlaceholder(),
                        placeholder: (_, __) => _buildImagePlaceholder(),
                      )
                    : _buildImagePlaceholder(),
              ),
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
                      if (description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () {
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
          );
        },
      ),
    );
  }

  Widget _buildImagePlaceholder() {
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

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('Post no longer available'),
    );
  }
} 