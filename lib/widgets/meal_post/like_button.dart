import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/chat_message.dart';
import '../../utils/custom_cache_manager.dart';

class LikeButton extends StatefulWidget {
  final String postId;
  final String userId;
  final Function(String, String) onLikeToggle;

  const LikeButton({
    super.key,
    required this.postId,
    required this.userId,
    required this.onLikeToggle,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.2),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleLikeAnimation(bool isLiked) {
    if (isLiked) {
      _controller.forward().then((_) => _controller.reset());
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(widget.postId)
          .collection('likes')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        final isLiked = snapshot.data?.exists ?? false;
        
        // Update _isLiked if it changed
        if (isLiked != _isLiked) {
          _isLiked = isLiked;
          _handleLikeAnimation(isLiked);
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => widget.onLikeToggle(widget.postId, widget.userId),
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Icon(
                  isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  color: isLiked ? Theme.of(context).primaryColor : Colors.grey[600],
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 4),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('meal_posts')
                  .doc(widget.postId)
                  .collection('likes')
                  .snapshots(),
              builder: (context, snapshot) {
                final likeCount = snapshot.data?.docs.length ?? 0;
                return Text(
                  '$likeCount',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
} 