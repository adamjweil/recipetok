import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/meal_post.dart';
import '../utils/custom_cache_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class MealPostDetailScreen extends StatefulWidget {
  final MealPost post;

  const MealPostDetailScreen({
    super.key,
    required this.post,
  });

  @override
  State<MealPostDetailScreen> createState() => _MealPostDetailScreenState();
}

class _MealPostDetailScreenState extends State<MealPostDetailScreen> {
  final _commentController = TextEditingController();
  final PageController _pageController = PageController();
  int _currentPhotoIndex = 0;

  @override
  void dispose() {
    _commentController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(widget.post.id)
          .collection('comments')
          .add({
        'userId': user.uid,
        'text': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(widget.post.id)
          .update({
        'commentsCount': FieldValue.increment(1),
      });

      if (mounted) {
        _commentController.clear();
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding comment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.post.userId)
              .snapshots(),
          builder: (context, snapshot) {
            final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
            return Text(userData['displayName'] ?? 'User');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Share.share('Check out this meal post!'); // TODO: Add proper sharing URL
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photos with page indicator
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                SizedBox(
                  height: 300,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPhotoIndex = index);
                    },
                    itemCount: widget.post.photoUrls.length,
                    itemBuilder: (context, index) {
                      return CachedNetworkImage(
                        imageUrl: widget.post.photoUrls[index],
                        fit: BoxFit.cover,
                        cacheManager: CustomCacheManager.instance,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.error),
                        ),
                      );
                    },
                  ),
                ),
                if (widget.post.photoUrls.length > 1)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        widget.post.photoUrls.length,
                        (index) => Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPhotoIndex == index
                                ? Theme.of(context).primaryColor
                                : Colors.grey[300],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and meal type
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.post.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.post.mealType.toString().split('.').last.toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (widget.post.description != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      widget.post.description!,
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 16,
                      ),
                    ),
                  ],

                  if (widget.post.ingredients != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Ingredients',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.post.ingredients!,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],

                  if (widget.post.instructions != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Instructions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.post.instructions!,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Text(
                    'Comments',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildComments(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildCommentInput(),
    );
  }

  Widget _buildComments() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('meal_posts')
          .doc(widget.post.id)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final comments = snapshot.data?.docs ?? [];

        if (comments.isEmpty) {
          return const Center(
            child: Text('No comments yet'),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index].data() as Map<String, dynamic>;
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(comment['userId'])
                  .get(),
              builder: (context, userSnapshot) {
                final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                
                // Add debug logging
                final avatarUrl = userData['avatarUrl']?.toString() ?? '';
                if (avatarUrl.isEmpty) {
                  debugPrint('⚠️ Empty avatar URL found for user: ${userData['displayName'] ?? 'Unknown'}');
                  debugPrint('User data: $userData');
                }
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: (userData['avatarUrl'] != null && userData['avatarUrl'].toString().isNotEmpty)
                        ? CachedNetworkImageProvider(
                            userData['avatarUrl'],
                            cacheManager: CustomCacheManager.instance,
                          )
                        : null,
                    child: (userData['avatarUrl'] == null || userData['avatarUrl'].toString().isEmpty)
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Row(
                    children: [
                      Text(
                        userData['displayName'] ?? 'User',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (comment['createdAt'] != null)
                        Text(
                          DateFormat.yMMMd().format((comment['createdAt'] as Timestamp).toDate()),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(comment['text']),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  hintText: 'Add a comment...',
                  border: InputBorder.none,
                ),
                maxLines: null,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _addComment,
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }
} 