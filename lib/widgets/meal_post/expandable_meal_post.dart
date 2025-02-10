import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/meal_post.dart';
import '../../utils/time_formatter.dart';
import 'like_button.dart';
import 'package:share_plus/share_plus.dart';

class ExpandableMealPost extends StatefulWidget {
  final MealPost post;
  final bool isExpanded;
  final VoidCallback onToggle;

  const ExpandableMealPost({
    super.key,
    required this.post,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  State<ExpandableMealPost> createState() => _ExpandableMealPostState();
}

class _ExpandableMealPostState extends State<ExpandableMealPost> {
  final TextEditingController _commentController = TextEditingController();
  bool _isPostingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;
    setState(() => _isPostingComment = true);

    try {
      final commentRef = FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(widget.post.id)
          .collection('comments')
          .doc();

      await commentRef.set({
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'text': _commentController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(widget.post.id)
          .update({
        'comments': FieldValue.increment(1),
      });

      if (mounted) {
        _commentController.clear();
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting comment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPostingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 12, left: 12),
            child: Text(
              getTimeAgo(widget.post.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ),

          // Image and Description Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.post.photoUrls.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: CachedNetworkImage(
                        imageUrl: widget.post.photoUrls.first,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.error),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(width: 12),

                if (widget.post.description != null)
                  Expanded(
                    child: Text(
                      widget.post.description!,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),

          // Interaction buttons
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: Row(
              children: [
                LikeButton(
                  postId: widget.post.id,
                  userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: widget.onToggle,
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.grey[600],
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('meal_posts')
                            .doc(widget.post.id)
                            .collection('comments')
                            .snapshots(),
                        builder: (context, snapshot) {
                          final commentCount = snapshot.data?.docs.length ?? 0;
                          return Text(
                            '$commentCount',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.share_outlined,
                    color: Colors.grey[600],
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Share.share(
                      'Check out this meal post: ${widget.post.description}',
                      subject: 'Check out this meal post!',
                    );
                  },
                ),
              ],
            ),
          ),

          // Comments section
          if (widget.isExpanded) ...[
            const Divider(),
            // Comments list and input field implementation...
            // Add your existing comments section code here
          ],
        ],
      ),
    );
  }
} 