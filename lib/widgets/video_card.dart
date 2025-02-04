import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/custom_cache_manager.dart';
import './save_options_modal.dart';
import 'package:rxdart/rxdart.dart';

class VideoCard extends StatefulWidget {
  final Map<String, dynamic> videoData;
  final VoidCallback onUserTap;
  final String videoId;
  final VoidCallback? onVideoPlay;
  final VoidCallback? onLike;
  final VoidCallback? onBookmark;
  final String? currentUserId;

  const VideoCard({
    super.key,
    required this.videoData,
    required this.onUserTap,
    required this.videoId,
    this.onVideoPlay,
    this.onLike,
    this.onBookmark,
    this.currentUserId,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _hasRecordedView = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    if (!mounted) return;
    
    final videoUrl = widget.videoData['videoUrl'] as String?;
    if (videoUrl == null || videoUrl.isEmpty) return;

    try {
      _videoController = VideoPlayerController.network(videoUrl);
      await _videoController?.initialize();
      
      if (mounted) {
        _videoController?.setLooping(true);
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  void _togglePlay() {
    if (!_isInitialized || !mounted) return;

    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
        if (!_hasRecordedView) {
          _recordView();
        }
      }
    });
  }

  Future<void> _recordView() async {
    try {
      final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (currentUserId.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoId)
          .update({
        'views': FieldValue.increment(1),
      });

      setState(() => _hasRecordedView = true);
      widget.onVideoPlay?.call();
    } catch (e) {
      print('Error recording view: $e');
    }
  }

  Future<void> _handleLike(BuildContext context) async {
    try {
      final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (currentUserId.isEmpty) return;

      final videoRef = FirebaseFirestore.instance.collection('videos').doc(widget.videoId);
      final userLikesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('likes')
          .doc(widget.videoId);

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

  void _toggleBookmark(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SaveOptionsModal(
        videoId: widget.videoId,
        videoData: widget.videoData,
        currentUserId: widget.currentUserId ?? '',
      ),
    );
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(
        videoId: widget.videoId,
        videoData: widget.videoData,
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_isInitialized)
          GestureDetector(
            onTap: _togglePlay,
            child: VideoPlayer(_videoController!),
          )
        else
          _buildPlaceholder(),

        // Video Info Overlay
        Positioned(
          left: 16,
          right: 100,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.videoData['title'] ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.videoData['description'] ?? '',
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                (widget.videoData['ingredients'] as List?)?.join(', ') ?? '',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),

        // Action Buttons
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.currentUserId)
                    .collection('videoLikes')
                    .doc(widget.videoId)
                    .snapshots(),
                builder: (context, snapshot) {
                  final isLiked = snapshot.data?.exists ?? false;
                  return Column(
                    children: [
                      IconButton(
                        icon: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.white,
                        ),
                        onPressed: widget.onLike,
                      ),
                      Text(
                        '${widget.videoData['likes'] ?? 0}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              StreamBuilder<bool>(
                stream: Rx.combineLatest2(
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.currentUserId)
                      .collection('bookmarks')
                      .doc(widget.videoId)
                      .snapshots(),
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.currentUserId)
                      .collection('groups')
                      .snapshots(),
                  (DocumentSnapshot bookmarkDoc, QuerySnapshot groupsSnapshot) {
                    final isBookmarked = bookmarkDoc.exists;
                    
                    // Check if video exists in any group
                    final isInGroup = groupsSnapshot.docs.any((groupDoc) {
                      final videos = (groupDoc.data() as Map<String, dynamic>)['videos'] as Map<String, dynamic>?;
                      return videos?.containsKey(widget.videoId) ?? false;
                    });
                    
                    return isBookmarked || isInGroup;
                  },
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Icon(Icons.error, color: Colors.red);
                  }

                  final isSaved = snapshot.data ?? false;
                  
                  return IconButton(
                    icon: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: isSaved ? Colors.yellow : Colors.white,
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => SaveOptionsModal(
                          videoId: widget.videoId,
                          videoData: widget.videoData,
                          currentUserId: widget.currentUserId ?? '',
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildActionButton(
                icon: Icons.remove_red_eye,
                label: '${widget.videoData['views'] ?? 0}',
                onTap: () {},
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('videos')
                    .doc(widget.videoId)
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

        if (!_isInitialized || !_videoController!.value.isPlaying)
          Center(
            child: IconButton(
              icon: Icon(
                _isInitialized ? Icons.play_circle_outline : Icons.error_outline,
                size: 64,
                color: Colors.white70,
              ),
              onPressed: _isInitialized ? _togglePlay : null,
            ),
          ),
      ],
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
}

class CommentsSheet extends StatefulWidget {
  final String videoId;
  final Map<String, dynamic> videoData;

  const CommentsSheet({
    super.key,
    required this.videoId,
    required this.videoData,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _firestore
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments')
          .add({
        'text': _commentController.text.trim(),
        'userId': user.uid,
        'username': user.displayName ?? 'User',
        'userImage': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
      });

      _commentController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting comment: ${e.toString()}')),
        );
      }
    }
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
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Comments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('videos')
                  .doc(widget.videoId)
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No comments yet',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to comment!',
                          style: TextStyle(color: Colors.grey[500]),
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
                    final timestamp = comment['createdAt'] as Timestamp?;
                    final dateTime = timestamp?.toDate();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: comment['userImage'] != null
                                ? NetworkImage(comment['userImage'])
                                : null,
                            child: comment['userImage'] == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comment['username'] ?? 'User',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(comment['text'] ?? ''),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      _getTimeAgo(dateTime),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      '${comment['likes'] ?? 0} likes',
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
                          IconButton(
                            icon: const Icon(Icons.favorite_border),
                            onPressed: () {},
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              top: 16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.send),
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
} 