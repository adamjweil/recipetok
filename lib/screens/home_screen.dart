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
import 'package:flutter/rendering.dart';
import 'dart:math';
import '../widgets/notification_dropdown.dart';
import './profile_screen.dart';
import './main_navigation_screen.dart';
import 'dart:async';
import './search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  VideoCardState? _currentlyPlayingVideo;
  List<QueryDocumentSnapshot>? _cachedVideos;
  final Map<String, GlobalKey<VideoCardState>> _videoKeys = {};
  final Map<String, MealPost> _postsCache = {};
  static const int _postsPerBatch = 10;
  DocumentSnapshot? _lastDocument;
  bool _hasMorePosts = true;
  bool _isLoadingMore = false;
  final ScrollController _friendsScrollController = ScrollController();
  final ScrollController _globalScrollController = ScrollController();
  List<String> followingUsers = [];
  final Map<String, bool> _followedUsers = {};
  final Map<String, double> _countdownValues = {};
  final Map<String, DateTime> _countdownStartTimes = {};
  final Set<String> _usersToFollow = {};
  DateTime? _firstCountdownStartTime;

  // Add new variables for feed filtering
  bool isGlobalFeed = false;
  Map<String, List<MealPost>> feedCache = {};
  bool isLoadingGlobal = false;
  bool isLoadingFriends = false;
  DocumentSnapshot? lastGlobalDocument;
  DocumentSnapshot? lastFriendsDocument;

  // Add this variable at the top of the class with other instance variables
  DateTime animationStartTime = DateTime.now();
  Timer? animationTimer;

  // Add these new variables
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  bool _isRefreshing = false;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  // Add this variable at the top of the class with other instance variables
  Future<List<Map<String, dynamic>>>? _recommendedUsersFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    
    // Initialize feed cache
    feedCache['friends'] = [];
    feedCache['global'] = [];
    
    // Add scroll listeners for both controllers
    _friendsScrollController.addListener(() {
      if (_friendsScrollController.position.pixels >= 
          _friendsScrollController.position.maxScrollExtent * 0.8 && 
          !_isLoadingMore &&
          _hasMorePosts && 
          !isGlobalFeed) {
        _loadMorePosts();
      }
    });

    _globalScrollController.addListener(() {
      if (_globalScrollController.position.pixels >= 
          _globalScrollController.position.maxScrollExtent * 0.8 && 
          !_isLoadingMore &&
          _hasMorePosts && 
          isGlobalFeed) {
        _loadMorePosts();
      }
    });
    
    // First initialize following users
    _initializeFollowingUsers().then((_) {
      // Then load feeds only after we have the following users list
      if (mounted) {
        loadFriendsFeed();
        loadGlobalFeed();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playInitialVideo();
    });
  }

  Future<void> _initializeFollowingUsers() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();
    
    if (mounted) {
      setState(() {
        followingUsers = List<String>.from(userDoc.data()?['following'] ?? []);
        followingUsers.add(currentUserId); // Include user's own posts
      });
    }
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
    _friendsScrollController.dispose();
    _globalScrollController.dispose();
    animationTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(36),
        child: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.search, size: 20),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchScreen(),
                ),
              );
            },
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 32,
                margin: const EdgeInsets.only(bottom: 3),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFeedToggleButton(
                      icon: Icons.group,
                      label: 'Friends',
                      isSelected: !isGlobalFeed,
                    ),
                    _buildFeedToggleButton(
                      icon: Icons.public,
                      label: 'Global',
                      isSelected: isGlobalFeed,
                    ),
                  ],
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            NotificationDropdown(),
          ],
          elevation: 1,
          toolbarHeight: 36,
        ),
      ),
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _refreshFeed,
        displacement: 20,
        strokeWidth: 3,
        color: Theme.of(context).primaryColor,
        backgroundColor: Colors.white,
        child: CustomScrollView(
          controller: !isGlobalFeed ? _friendsScrollController : _globalScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFadeTransition(
              opacity: _fadeAnimation,
              sliver: _buildFeedContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedContent() {
    final posts = feedCache[isGlobalFeed ? 'global' : 'friends'] ?? [];
    final isLoading = isGlobalFeed ? isLoadingGlobal : isLoadingFriends;

    if (posts.isEmpty && !isLoading) {
      if (!isGlobalFeed) {
        // Show recommended users in friends tab when empty
        return SliverToBoxAdapter(
          key: const ValueKey('empty_friends_feed'),
          child: _buildRecommendedUsers(),
        );
      }
      
      return SliverToBoxAdapter(
        key: ValueKey('empty_${isGlobalFeed ? 'global' : 'friends'}_feed'),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isGlobalFeed ? Icons.public_off : Icons.group_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                isGlobalFeed
                    ? 'No posts in the global feed yet'
                    : 'No posts from friends yet',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isGlobalFeed
                    ? 'Be the first to share something!'
                    : 'Follow more users or create a post!',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      key: ValueKey('feed_${isGlobalFeed ? 'global' : 'friends'}'),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == posts.length) {
            if (isLoading) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return const SizedBox.shrink();
          }

          final post = posts[index];
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 5, 16, 0),
            child: KeyedSubtree(
              key: ValueKey(post.id),
              child: RepaintBoundary(
                child: MealPostWrapper(
                  post: post,
                  showUserInfo: true,
                ),
              ),
            ),
          );
        },
        childCount: posts.length + (isLoading ? 1 : 0),
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: true,
      ),
    );
  }

  // Add this method to optimize following users stream
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

  // Update the posts stream to be more efficient
  Stream<QuerySnapshot> _getPostsStream() {
    // If followingUsers is empty, return an empty stream
    if (followingUsers.isEmpty) {
      return Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('meal_posts')
        .where('userId', whereIn: followingUsers)
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isNotEmpty) {
            _lastDocument = snapshot.docs.last;
            
            // Pre-cache all images from all posts immediately
            for (var doc in snapshot.docs) {
              final post = MealPost.fromFirestore(doc);
              // Pre-cache user avatar
              if (post.userAvatarUrl != null) {
                unawaited(CustomCacheManager.instance.getSingleFile(post.userAvatarUrl!));
              }
              // Pre-cache all post photos
              for (var url in post.photoUrls) {
                unawaited(CustomCacheManager.instance.getSingleFile(url));
              }
              // Cache the post data
              _postsCache[post.id] = post;
            }
          }
          return snapshot;
        });
  }

  // Update the method to get recommended users with better metrics
  Future<List<Map<String, dynamic>>> _getRecommendedUsers() async {
    try {
      final adamDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: 'adamjweil@gmail.com')
          .limit(1)
          .get();

      if (adamDoc.docs.isEmpty) {
        debugPrint('Adam\'s account not found');
        return [];
      }

      final adamData = adamDoc.docs.first.data();
      final adamId = adamDoc.docs.first.id;

      // Get Adam's recent posts
      final recentPosts = await FirebaseFirestore.instance
          .collection('meal_posts')
          .where('userId', isEqualTo: adamId)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();

      // Calculate basic stats
      double totalLikes = 0;
      double totalComments = 0;
      for (var post in recentPosts.docs) {
        totalLikes += (post.data()['likes'] as num?)?.toDouble() ?? 0;
        totalComments += (post.data()['commentCount'] as num?)?.toDouble() ?? 0;
      }

      return [{
        'userData': adamData,
        'activityScore': 100, // High score to ensure prominence
        'matchingPreferences': 3, // Assuming good match
        'recentPosts': recentPosts.docs,
        'stats': {
          'posts': recentPosts.docs.length,
          'avgLikes': recentPosts.docs.isEmpty ? 0.0 : totalLikes / recentPosts.docs.length,
          'avgComments': recentPosts.docs.isEmpty ? 0.0 : totalComments / recentPosts.docs.length,
        },
        'userId': adamId,
      }];
    } catch (e) {
      debugPrint('Error getting recommended user: $e');
      return [];
    }
  }

  // Update the UI building method
  Widget _buildRecommendedUsers() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getRecommendedUsers(),
      builder: (context, snapshot) {
        // Add error handling
        if (snapshot.hasError) {
          animationTimer?.cancel();
          debugPrint('Error loading recommendations: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Error loading recommendations',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      animationStartTime = DateTime.now();
                      _startAnimationTimer();
                    });
                  },
                  child: const Text('Tap to retry'),
                ),
              ],
            ),
          );
        }

        // Show loading state with animation
        if (!snapshot.hasData) {
          if (animationTimer == null) {
            animationStartTime = DateTime.now();
            _startAnimationTimer();
          }
          
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Welcome text
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUserId)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.hasData) {
                    final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                    final firstName = userData['firstName'] as String? ?? 'there';
                    return Text(
                      'Welcome, $firstName! 👋',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    );
                  }
                  return const Text(
                    'Welcome! 👋',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const SizedBox(height: 40),
              // Loading animation steps
              ..._buildLoadingSteps(context),
            ],
          );
        }

        // Cancel timer when data is loaded
        animationTimer?.cancel();
        animationTimer = null;

        final recommendedUsers = snapshot.data!;
        
        // Handle empty recommendations
        if (recommendedUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No recommendations available yet',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check back later for personalized recommendations',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        // Show recommendations
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUserId)
                        .snapshots(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.hasData) {
                        final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                        final firstName = userData['firstName'] as String? ?? 'there';
                        return Text(
                          'Welcome, $firstName! 👋',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }
                      return const Text(
                        'Welcome! 👋',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
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
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: recommendedUsers.length,
              itemBuilder: (context, index) {
                final recommendation = recommendedUsers[index];
                final userData = recommendation['userData'] as Map<String, dynamic>;
                final stats = recommendation['stats'] as Map<String, dynamic>;
                final recentPosts = recommendation['recentPosts'] as List<QueryDocumentSnapshot>;
                final matchingPreferences = recommendation['matchingPreferences'] as int;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).primaryColor.withOpacity(0.05),
                              Colors.white,
                            ],
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 32,
                                backgroundColor: Colors.white,
                                backgroundImage: userData['avatarUrl'] != null && 
                                               userData['avatarUrl'].toString().isNotEmpty && 
                                               Uri.tryParse(userData['avatarUrl'])?.hasScheme == true
                                    ? NetworkImage(userData['avatarUrl'])
                                    : null,
                                child: userData['avatarUrl'] == null || 
                                       userData['avatarUrl'].toString().isEmpty ||
                                       Uri.tryParse(userData['avatarUrl'])?.hasScheme != true
                                    ? Icon(Icons.person, 
                                        size: 32, 
                                        color: Theme.of(context).primaryColor)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              userData['displayName'] ?? 'Unknown',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (userData['bio'] != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                userData['bio'],
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                  height: 1.2,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildFollowButton(userData['uid']),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: MediaQuery.of(context).size.width * 0.5, // Reduce to 70% of previous width
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.03),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _buildStat(stats['posts'].toString(), 'posts'),
                                          Container(
                                            height: 16,
                                            width: 1,
                                            color: Colors.grey[300],
                                          ),
                                          _buildStat(
                                            stats['avgLikes'].toStringAsFixed(1),
                                            'avg likes',
                                          ),
                                          Container(
                                            height: 16,
                                            width: 1,
                                            color: Colors.grey[300],
                                          ),
                                          _buildStat(
                                            stats['avgComments'].toStringAsFixed(1),
                                            'avg comments',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (recentPosts.isNotEmpty)
                        Container(
                          height: 100,
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: recentPosts.map((post) {
                              final postData = post.data() as Map<String, dynamic>;
                              final photoUrl = postData['photoUrls']?[0] as String?;
                              
                              // Validate the photo URL
                              final isValidUrl = photoUrl != null && 
                                               photoUrl.isNotEmpty && 
                                               Uri.tryParse(photoUrl)?.hasScheme == true;
                              
                              return Expanded(
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: isValidUrl
                                      ? Image.network(
                                          photoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[200],
                                              child: Icon(
                                                Icons.image_not_supported,
                                                color: Colors.grey[400],
                                              ),
                                            );
                                          },
                                        )
                                      : Container(
                                          color: Colors.grey[200],
                                          child: Icon(
                                            Icons.image_not_supported,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.recommend,
                                color: Theme.of(context).primaryColor,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Matches ${matchingPreferences} of your food preferences and posts regularly with high engagement',
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontSize: 12,
                                    height: 1.3,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _followUser(String userId) async {
    try {
      setState(() {
        _followedUsers[userId] = true;
        _usersToFollow.add(userId);
        if (_firstCountdownStartTime == null) {
          _firstCountdownStartTime = DateTime.now();
        }
        _countdownStartTimes[userId] = _firstCountdownStartTime!;
      });
    } catch (e) {
      setState(() {
        _followedUsers[userId] = false;
        _usersToFollow.remove(userId);
        _countdownStartTimes.remove(userId);
      });
      debugPrint('Error following user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error following user: $e')),
        );
      }
    }
  }

  Widget _buildFollowButton(String userId) {
    if (_followedUsers[userId] == true) {
      final startTime = _countdownStartTimes[userId] ?? DateTime.now();
      final elapsed = DateTime.now().difference(startTime).inSeconds;
      final initialValue = max(3.0 - elapsed, 0.0);

      return TweenAnimationBuilder<double>(
        tween: Tween(begin: initialValue, end: 0.0),
        duration: Duration(seconds: initialValue.toInt()),
        onEnd: () async {
          try {
            if (_countdownStartTimes[userId] == _firstCountdownStartTime) {
              final batch = FirebaseFirestore.instance.batch();

              for (final userToFollow in _usersToFollow) {
                batch.update(
                  FirebaseFirestore.instance.collection('users').doc(currentUserId),
                  {
                    'following': FieldValue.arrayUnion([userToFollow])
                  }
                );

                batch.update(
                  FirebaseFirestore.instance.collection('users').doc(userToFollow),
                  {
                    'followers': FieldValue.arrayUnion([currentUserId])
                  }
                );
              }

              await batch.commit();
              
              if (mounted) {
                setState(() {
                  for (final userToFollow in _usersToFollow) {
                    _followedUsers[userToFollow] = false;
                    _countdownValues.remove(userToFollow);
                    _countdownStartTimes.remove(userToFollow);
                  }
                  _usersToFollow.clear();
                  _firstCountdownStartTime = null;
                });

                await _initializeFollowingUsers();
                // Clear and reload friends feed after following users
                if (mounted) {
                  setState(() {
                    feedCache['friends'] = [];
                    lastFriendsDocument = null;
                  });
                  loadFriendsFeed();
                }
              }
            } else {
              if (mounted) {
                setState(() {
                  _followedUsers[userId] = false;
                  _countdownValues.remove(userId);
                  _countdownStartTimes.remove(userId);
                  _usersToFollow.remove(userId);
                  
                  if (_countdownStartTimes.isEmpty) {
                    _firstCountdownStartTime = null;
                  }
                });
              }
            }
          } catch (e) {
            debugPrint('Error following users after countdown: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error following users: $e')),
              );
            }
          }
        },
        builder: (context, value, child) {
          _countdownValues[userId] = value;
          return Container(
            height: 36,
            width: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                '${value.ceil()}s',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      );
    }

    return ElevatedButton(
      onPressed: () => _followUser(userId),
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
    );
  }

  // Add method to load more posts
  Future<void> _loadMorePosts() async {
    if (!_hasMorePosts || _isLoadingMore || _lastDocument == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final query = FirebaseFirestore.instance
          .collection('meal_posts')
          .where('userId', whereIn: followingUsers)
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_postsPerBatch);

      final snapshot = await query.get();
      if (snapshot.docs.length < _postsPerBatch) {
        _hasMorePosts = false;
      }
      
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
    } catch (e) {
      debugPrint('Error loading more posts: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  // Update the _buildLoadingSteps method
  List<Widget> _buildLoadingSteps(BuildContext context) {
    final steps = [
      {'icon': Icons.restaurant_menu, 'text': 'Analyzing food preferences'},
      {'icon': Icons.people_outline, 'text': 'Finding top chefs'},
      {'icon': Icons.thumb_up_outlined, 'text': 'Calculating engagement scores'},
    ];

    final totalDuration = 3500; // Total animation duration in milliseconds
    final stepDuration = (totalDuration / steps.length).round();
    final elapsed = DateTime.now().difference(animationStartTime).inMilliseconds;
    
    // Stop animation if we've exceeded total duration
    if (elapsed >= totalDuration) {
      animationTimer?.cancel();
      animationTimer = null;
    }

    return List.generate(steps.length, (index) {
      final step = steps[index];
      final stepStartTime = index * stepDuration;
      final shouldShow = elapsed > stepStartTime;
      final stepProgress = shouldShow ? 
          min(1.0, (elapsed - stepStartTime) / stepDuration) : 0.0;
      
      return AnimatedOpacity(
        opacity: shouldShow ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  step['icon'] as IconData,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step['text'] as String,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (shouldShow) LinearProgressIndicator(
                      value: stepProgress,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _prefetchFeeds() async {
    // Prefetch both feeds in the background
    loadFriendsFeed();
    loadGlobalFeed();
  }

  Future<void> loadFriendsFeed() async {
    if (isLoadingFriends) return;
    setState(() => isLoadingFriends = true);

    try {
      final querySnapshot = await _firestore
          .collection('meal_posts')
          .where('userId', whereIn: followingUsers)
          .orderBy('createdAt', descending: true)
          .limit(_postsPerBatch)
          .get();

      final posts = querySnapshot.docs
          .map((doc) => MealPost.fromFirestore(doc))
          .toList();

      setState(() {
        feedCache['friends'] = posts;
        lastFriendsDocument = querySnapshot.docs.last;
        isLoadingFriends = false;
      });
    } catch (e) {
      setState(() => isLoadingFriends = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading feed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> loadGlobalFeed() async {
    if (isLoadingGlobal) return;
    setState(() => isLoadingGlobal = true);

    try {
      final querySnapshot = await _firestore
          .collection('meal_posts')
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(_postsPerBatch)
          .get();

      final posts = querySnapshot.docs
          .map((doc) => MealPost.fromFirestore(doc))
          .toList();

      setState(() {
        feedCache['global'] = posts;
        lastGlobalDocument = querySnapshot.docs.last;
        isLoadingGlobal = false;
      });
    } catch (e) {
      setState(() => isLoadingGlobal = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading feed: ${e.toString()}')),
        );
      }
    }
  }

  void _toggleFeedType() {
    setState(() {
      isGlobalFeed = !isGlobalFeed;
      _animationController.reset();
      _animationController.forward();
      // Load more posts if needed
      if (isGlobalFeed && (feedCache['global'] == null || feedCache['global']!.isEmpty)) {
        loadGlobalFeed();
      } else if (!isGlobalFeed && (feedCache['friends'] == null || feedCache['friends']!.isEmpty)) {
        loadFriendsFeed();
      }
    });
  }

  Widget _buildFeedToggleButton({
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: _toggleFeedType,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this method to start the animation timer
  void _startAnimationTimer() {
    animationTimer?.cancel();
    animationTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          // This empty setState will trigger a rebuild to update the animation
        });
      }
    });
  }

  Future<void> _refreshFeed() async {
    setState(() {
      feedCache['friends'] = [];
      feedCache['global'] = [];
      lastFriendsDocument = null;
      lastGlobalDocument = null;
      isLoadingFriends = false;
      isLoadingGlobal = false;
    });

    // Reload both feeds
    await Future.wait([
      loadFriendsFeed(),
      loadGlobalFeed(),
    ]);
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