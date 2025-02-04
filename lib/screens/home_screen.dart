import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<QuerySnapshot> _getVideosStream() {
    return _firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<Map<String, dynamic>> _getUserData(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data() ?? {};
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _getVideosStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final videos = snapshot.data?.docs ?? [];

          if (videos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_library, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No videos yet',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Videos will appear here once users start sharing',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final videoData = videos[index].data() as Map<String, dynamic>;
              final videoId = videos[index].id;
              return VideoCard(
                videoData: videoData,
                videoId: videoId,
                onUserTap: () {
                  // TODO: Navigate to user profile
                },
              );
            },
          );
        },
      ),
    );
  }
}

class VideoCard extends StatelessWidget {
  final Map<String, dynamic> videoData;
  final VoidCallback onUserTap;
  final String videoId;

  const VideoCard({
    super.key,
    required this.videoData,
    required this.onUserTap,
    required this.videoId,
  });

  Future<void> _handleLike(BuildContext context) async {
    try {
      final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (currentUserId.isEmpty) return;

      final videoRef = FirebaseFirestore.instance.collection('videos').doc(videoId);
      final userLikesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('likes')
          .doc(videoId);

      final likeDoc = await userLikesRef.get();
      final bool isLiked = likeDoc.exists;

      if (isLiked) {
        await videoRef.update({
          'likes': FieldValue.increment(-1),
        });
        await userLikesRef.delete();
      } else {
        await videoRef.update({
          'likes': FieldValue.increment(1),
        });
        await userLikesRef.set({
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(videoId: videoId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String thumbnailUrl = videoData['thumbnailUrl'] ?? '';
    final bool hasValidThumbnail = thumbnailUrl.startsWith('http');

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseAuth.instance.currentUser != null
          ? FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .collection('likes')
              .doc(videoId)
              .snapshots()
          : const Stream.empty(),
      builder: (context, snapshot) {
        final bool isLiked = snapshot.data?.exists ?? false;

        return Stack(
          fit: StackFit.expand,
          children: [
            if (hasValidThumbnail)
              CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.black12,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => _buildPlaceholder(),
              )
            else
              _buildPlaceholder(),

            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    videoData['title'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    videoData['description'] ?? '',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ingredients:',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (videoData['ingredients'] as List?)
                              ?.join(', ') ?? '',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Instructions:',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (videoData['instructions'] as List?)
                              ?.join('\n') ?? '',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              right: 16,
              bottom: 100,
              child: Column(
                children: [
                  _buildActionButton(
                    icon: isLiked ? Icons.favorite : Icons.favorite_border,
                    label: '${videoData['likes'] ?? 0}',
                    onTap: () => _handleLike(context),
                    color: isLiked ? Colors.red : Colors.white,
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    icon: Icons.remove_red_eye,
                    label: '${videoData['views'] ?? 0}',
                    onTap: () {},
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('videos')
                        .doc(videoId)
                        .collection('comments')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final commentCount = snapshot.data?.docs.length ?? 0;
                      return _buildActionButton(
                        icon: Icons.comment,
                        label: '$commentCount',
                        onTap: () => _showComments(context),
                        color: Colors.white,
                      );
                    },
                  ),
                ],
              ),
            ),

            Center(
              child: IconButton(
                icon: const Icon(
                  Icons.play_circle_outline,
                  size: 64,
                  color: Colors.white70,
                ),
                onPressed: () {
                  // TODO: Implement video playback
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'Video thumbnail not available',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: color),
          onPressed: onTap,
        ),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class CommentsSheet extends StatefulWidget {
  final String videoId;

  const CommentsSheet({
    super.key,
    required this.videoId,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  String _getTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';
    final difference = DateTime.now().difference(dateTime);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  Future<void> _toggleCommentLike(String commentId) async {
    try {
      final commentRef = _firestore
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .doc(commentId);

      final userLikeRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('commentLikes')
          .doc(commentId);

      final likeDoc = await userLikeRef.get();
      final isLiked = likeDoc.exists;

      if (isLiked) {
        await commentRef.update({
          'likes': FieldValue.increment(-1),
        });
        await userLikeRef.delete();
      } else {
        await commentRef.update({
          'likes': FieldValue.increment(1),
        });
        await userLikeRef.set({
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      final commentRef = _firestore
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .doc();

      await commentRef.set({
        'userId': currentUserId,
        'text': _commentController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,  // Initialize likes count
      });

      // Update comment count in the video document
      await _firestore.collection('videos').doc(widget.videoId).update({
        'comments': FieldValue.increment(1),
      });

      if (mounted) {
        _commentController.clear();
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error posting comment: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Enhanced Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                const Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('videos')
                      .doc(widget.videoId)
                      .collection('comments')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.docs.length ?? 0;
                    return Text(
                      '($count)',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    );
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Enhanced Comments List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('videos')
                  .doc(widget.videoId)
                  .collection('comments')
                  .orderBy('timestamp', descending: true)
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, 
                          size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No comments yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to comment!',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index].data() as Map<String, dynamic>;
                    final commentId = comments[index].id;
                    final timestamp = (comment['timestamp'] as Timestamp?)?.toDate();

                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore
                          .collection('users')
                          .doc(comment['userId'])
                          .get(),
                      builder: (context, userSnapshot) {
                        final userData = userSnapshot.data?.data() 
                            as Map<String, dynamic>? ?? {};
                        
                        return StreamBuilder<DocumentSnapshot>(
                          stream: _firestore
                              .collection('users')
                              .doc(currentUserId)
                              .collection('commentLikes')
                              .doc(commentId)
                              .snapshots(),
                          builder: (context, likeSnapshot) {
                            final isLiked = likeSnapshot.data?.exists ?? false;

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.grey[200],
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                userData['displayName'] ??
                                                    'Unknown User',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _getTimeAgo(timestamp),
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            comment['text'] ?? '',
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () => _toggleCommentLike(
                                                    commentId),
                                                child: Icon(
                                                  isLiked
                                                      ? Icons.favorite
                                                      : Icons.favorite_border,
                                                  size: 16,
                                                  color: isLiked
                                                      ? Colors.red
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${comment['likes'] ?? 0}',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          // Enhanced Comment Input
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  offset: const Offset(0, -1),
                  spreadRadius: 1,
                  blurRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[200],
                  child: const Icon(Icons.person, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded),
                  onPressed: _postComment,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 