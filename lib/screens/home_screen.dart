import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import '../utils/custom_cache_manager.dart';
import '../widgets/video_card.dart';
import './video_player_screen.dart';
import 'dart:async' show unawaited;
import '../widgets/meal_post_card.dart';
import '../models/meal_post.dart';
import 'package:intl/intl.dart';
import '../widgets/meal_post/meal_post_wrapper.dart';
import 'package:google_sign_in/google_sign_in.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  VideoCardState? _currentlyPlayingVideo;
  List<QueryDocumentSnapshot>? _cachedVideos;
  final Map<String, GlobalKey<VideoCardState>> _videoKeys = {};

  @override
  void initState() {
    super.initState();
    // Add this to initialize the first video
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playInitialVideo();
    });
  }

  // Add this method to play the first video
  void _playInitialVideo() {
    if (_cachedVideos != null && _cachedVideos!.isNotEmpty) {
      final firstVideoKey = _videoKeys[_cachedVideos!.first.id];
      if (firstVideoKey?.currentState != null) {
        firstVideoKey!.currentState!.playVideo();
        setState(() {
          _currentlyPlayingVideo = firstVideoKey.currentState;
        });
      }
    }
  }

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

  Future<void> _toggleVideoLike(String videoId) async {
    try {
      final videoRef = _firestore.collection('videos').doc(videoId);
      final userLikeRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('videoLikes')
          .doc(videoId);

      final likeDoc = await userLikeRef.get();
      final isLiked = likeDoc.exists;

      // Use a batch to perform both operations atomically
      final batch = _firestore.batch();

      if (isLiked) {
        batch.update(videoRef, {
          'likes': FieldValue.increment(-1),
        });
        batch.delete(userLikeRef);
      } else {
        batch.update(videoRef, {
          'likes': FieldValue.increment(1),
        });
        batch.set(userLikeRef, {
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // Commit the batch in the background
      unawaited(batch.commit().catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _toggleBookmark(String videoId, Map<String, dynamic> videoData) async {
    try {
      final userBookmarkRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('bookmarks')
          .doc(videoId);

      final bookmarkDoc = await userBookmarkRef.get();
      final isBookmarked = bookmarkDoc.exists;

      if (isBookmarked) {
        await userBookmarkRef.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video removed from bookmarks')),
          );
        }
      } else {
        await userBookmarkRef.set({
          'videoId': videoId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video added to bookmarks')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    // Add this to cleanup videos
    _currentlyPlayingVideo?.pauseVideo();
    _videoKeys.values.forEach((key) {
      key.currentState?.pauseVideo();
    });
    _videoKeys.clear();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Feed'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () async {
              try {
                await GoogleSignIn().signOut();
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error signing out: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<String>>(
        stream: _getFollowingUsers(),
        builder: (context, followingSnapshot) {
          if (followingSnapshot.hasError) {
            return Center(child: Text('Error: ${followingSnapshot.error}'));
          }

          if (!followingSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final followingUsers = followingSnapshot.data!;

          // If user isn't following anyone, show recommendations
          if (followingUsers.length <= 1) {  // <= 1 because it includes the user themselves
            return SingleChildScrollView(
              child: _buildRecommendedUsers(),
            );
          }

          // Rest of the existing code for showing the feed
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('meal_posts')
                .where('userId', whereIn: followingUsers)
                .where('isPublic', isEqualTo: true)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final posts = snapshot.data?.docs ?? [];

              if (posts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_menu, 
                        size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No meal posts yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Follow more users or create a post!',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = MealPost.fromFirestore(posts[index]);
                  return MealPostWrapper(
                    post: post,
                    showUserInfo: true,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Stream<List<String>> _getFollowingUsers() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .snapshots()
        .map((doc) {
      final following = List<String>.from(doc.data()?['following'] ?? []);
      following.add(currentUserId); // Include user's own posts
      return following;
    });
  }

  // Update the method to get recommended users with better metrics
  Future<List<Map<String, dynamic>>> _getRecommendedUsers() async {
    try {
      // Get current user's food preferences
      final currentUser = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      final userPreferences = List<String>.from(currentUser.data()?['foodPreferences'] ?? []);

      // Query all potential users to recommend
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isNotEqualTo: currentUserId)
          .get();

      // Calculate activity score for each user
      List<Map<String, dynamic>> rankedUsers = [];
      
      for (var userDoc in usersQuery.docs) {
        final userData = userDoc.data();
        final userFoodPrefs = List<String>.from(userData['foodPreferences'] ?? []);
        
        // Calculate matching preferences score
        final matchingPreferences = userPreferences.where((pref) => userFoodPrefs.contains(pref)).length;
        
        // Get user's posts for activity metrics
        final posts = await FirebaseFirestore.instance
            .collection('meal_posts')
            .where('userId', isEqualTo: userDoc.id)
            .orderBy('createdAt', descending: true)
            .get();

        // Calculate activity metrics
        double totalLikes = 0;
        double totalComments = 0;
        final recentPosts = posts.docs.take(3).toList();  // Get 3 most recent posts
        
        for (var post in posts.docs) {
          final postData = post.data();
          totalLikes += (postData['likes'] as num?)?.toDouble() ?? 0;
          // Get comment count
          final comments = await post.reference.collection('comments').count().get();
          totalComments += comments.count?.toDouble() ?? 0;
        }

        // Calculate activity score (convert to int for final score)
        final activityScore = (posts.docs.length * 10) +  // Each post worth 10 points
            (totalLikes * 2).toInt() +                    // Each like worth 2 points
            (totalComments * 3).toInt() +                 // Each comment worth 3 points
            (matchingPreferences * 15);                   // Each matching preference worth 15 points

        rankedUsers.add({
          'userData': userData,
          'activityScore': activityScore,
          'matchingPreferences': matchingPreferences,
          'recentPosts': recentPosts,
          'stats': {
            'posts': posts.docs.length,
            'avgLikes': posts.docs.isEmpty ? 0.0 : totalLikes / posts.docs.length,
            'avgComments': posts.docs.isEmpty ? 0.0 : totalComments / posts.docs.length,
          },
          'userId': userDoc.id,
        });
      }

      // Sort by activity score and take top 3
      rankedUsers.sort((a, b) => b['activityScore'].compareTo(a['activityScore']));
      return rankedUsers.take(3).toList();
    } catch (e) {
      debugPrint('Error getting recommended users: $e');
      return [];
    }
  }

  // Update the UI building method
  Widget _buildRecommendedUsers() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getRecommendedUsers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final recommendedUsers = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome to RecipeTok! 👋',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Based on your food preferences, we recommend following these amazing chefs:',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recommendedUsers.length,
              itemBuilder: (context, index) {
                final recommendation = recommendedUsers[index];
                final userData = recommendation['userData'] as Map<String, dynamic>;
                final stats = recommendation['stats'] as Map<String, dynamic>;
                final recentPosts = recommendation['recentPosts'] as List<QueryDocumentSnapshot>;
                final matchingPreferences = recommendation['matchingPreferences'] as int;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User info section
                      ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundImage: userData['avatarUrl'] != null
                              ? NetworkImage(userData['avatarUrl'])
                              : null,
                          child: userData['avatarUrl'] == null
                              ? const Icon(Icons.person, size: 20)
                              : null,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                userData['displayName'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _followUser(userData['uid']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                              child: const Text(
                                'Follow',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (userData['bio'] != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                userData['bio'],
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 11,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 6),
                            // Stats row
                            Row(
                              children: [
                                _buildStat(stats['posts'].toString(), 'posts'),
                                const SizedBox(width: 12),
                                _buildStat(
                                  stats['avgLikes'].toStringAsFixed(1),
                                  'avg likes',
                                ),
                                const SizedBox(width: 12),
                                _buildStat(
                                  stats['avgComments'].toStringAsFixed(1),
                                  'avg comments',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Recent posts preview
                      if (recentPosts.isNotEmpty)
                        Container(
                          height: 90,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: recentPosts.map((post) {
                              final postData = post.data() as Map<String, dynamic>;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      postData['photoUrls'][0],
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      // Recommendation reason
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.recommend, color: Colors.grey[600], size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Matches ${matchingPreferences} of your food preferences and posts regularly with high engagement',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // Add this method to follow a user
  Future<void> _followUser(String userId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // Update current user's following array
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(currentUserId),
        {
          'following': FieldValue.arrayUnion([userId])
        }
      );

      // Update target user's followers array
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(userId),
        {
          'followers': FieldValue.arrayUnion([currentUserId])
        }
      );

      await batch.commit();
    } catch (e) {
      debugPrint('Error following user: $e');
    }
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

  Stream<DocumentSnapshot> _getUserDataStream() {
    final userId = widget.videoData['userId'] as String?;
    if (userId == null || userId.isEmpty) {
      return Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots();
  }

  Future<DocumentSnapshot> _getUserDataFuture() {
    final userId = widget.videoData['userId'] as String?;
    if (userId == null || userId.isEmpty) {
      return Future.error('Invalid user ID');
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
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

                    return StreamBuilder<DocumentSnapshot>(
                      stream: _getUserDataStream(),
                      builder: (context, userSnapshot) {
                        final userData = userSnapshot.data?.data() 
                            as Map<String, dynamic>? ?? {};
                        
                        return FutureBuilder<DocumentSnapshot>(
                          future: _getUserDataFuture(),
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
                                      backgroundImage: userData['avatarUrl'] != null && 
                                                     userData['avatarUrl'].toString().isNotEmpty && 
                                                     userData['avatarUrl'].toString().startsWith('http')
                                                  ? NetworkImage(userData['avatarUrl']) as ImageProvider
                                                  : null,
                                      child: (userData['avatarUrl'] == null || 
                                             userData['avatarUrl'].toString().isEmpty || 
                                             !userData['avatarUrl'].toString().startsWith('http'))
                                          ? const Icon(Icons.person, color: Colors.grey)
                                          : null,
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
            child: StreamBuilder<DocumentSnapshot>(
              stream: _getUserDataStream(),
              builder: (context, snapshot) {
                final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                final avatarUrl = userData['avatarUrl'] as String?;
                final hasValidAvatar = avatarUrl != null && 
                                     avatarUrl.isNotEmpty && 
                                     avatarUrl.startsWith('http');

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: hasValidAvatar ? NetworkImage(avatarUrl) : null,
                      child: !hasValidAvatar
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 