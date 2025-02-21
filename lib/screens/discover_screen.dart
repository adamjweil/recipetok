import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/video_card.dart';
import '../screens/main_navigation_screen.dart';
import '../models/video.dart';
import '../screens/profile_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showTrendingSearches = false;
  String? _searchQuery;
  bool _isSearching = false;

  final ScrollController _scrollController = ScrollController();
  List<DocumentSnapshot> _videos = [];
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _loadInitialVideos();
    _setupScrollListener();
    _searchFocusNode.addListener(_onSearchFocusChange);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchFocusChange() {
    setState(() {
      _showTrendingSearches = _searchFocusNode.hasFocus;
    });
  }

  Future<void> _loadInitialVideos() async {
    try {
      // Check if user is signed in
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User is not signed in');
        setState(() {
          _videos = [];
          _lastDocument = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to view videos'),
          ),
        );
        return;
      }

      print('Current user ID: ${user.uid}');
      print('Fetching initial videos...');

      // First, let's check if the videos collection exists and has documents
      final collectionRef = FirebaseFirestore.instance.collection('videos');
      final checkSnapshot = await collectionRef.limit(1).get();
      print('Collection exists: ${checkSnapshot.docs.isNotEmpty}');

      // Simplified query without composite indexes first
      final QuerySnapshot snapshot = await collectionRef
          .orderBy('createdAt', descending: true)  // Simple single-field index
          .limit(_pageSize)
          .get();

      print('Query completed');
      print('Fetched ${snapshot.docs.length} videos');
      
      if (snapshot.docs.isNotEmpty) {
        final firstVideo = snapshot.docs.first.data() as Map<String, dynamic>;
        print('Sample video data: $firstVideo');
      }

      if (!mounted) return;

      setState(() {
        _videos = snapshot.docs;
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      });
    } catch (e, stackTrace) {
      print('Error loading videos: $e');
      print('Stack trace: $stackTrace');
      
      if (!mounted) return;
      
      setState(() {
        _videos = [];
        _lastDocument = null;
      });
      
      // More specific error message
      String errorMessage = 'Failed to load videos: ';
      if (e is FirebaseException) {
        errorMessage += '${e.code} - ${e.message}';
      } else {
        errorMessage += e.toString();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      final loadThreshold = maxScroll * 0.8; // Start loading when 80% scrolled
      
      if (currentScroll >= loadThreshold &&
          !_isLoadingMore &&
          _lastDocument != null) {
        _loadMoreVideos();
      }
    });
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || _lastDocument == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Increase page size for smoother infinite scroll
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('videos')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize + 5) // Load a few extra items
          .get();

      if (!mounted) return;

      setState(() {
        _videos.addAll(snapshot.docs);
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoadingMore = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load more videos'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _onSearch(String query) async {
    setState(() {
      _searchQuery = query;
      _isSearching = true;
      _showTrendingSearches = false;
    });

    // Search functionality will be implemented in _buildUserSearchResults
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            if (_showTrendingSearches)
              _buildTrendingSearches()
            else if (_isSearching)
              _buildSearchResults()
            else
              Expanded(
                child: _buildVideoGrid(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search videos and users...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = null;
                      _isSearching = false;
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onChanged: _onSearch,
      ),
    );
  }

  Widget _buildTrendingSearches() {
    return Expanded(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Trending Searches',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Add trending searches here
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Expanded(
      child: DefaultTabController(
        length: 2,
        initialIndex: 0, // Start with Users tab
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: const TabBar(
                tabs: [
                  Tab(text: 'Users'),  // Swapped order
                  Tab(text: 'Videos'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildUserSearchResults(),  // Swapped order
                  _buildVideoSearchResults(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSearchResults() {
    // Implement video search results
    return const Center(child: Text('Video results'));
  }

  Widget _buildUserSearchResults() {
    if (_searchQuery == null || _searchQuery!.isEmpty) {
      return Center(
        child: Text(
          'Enter a name to search for users',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
      );
    }

    print('\n--- Search Debug Info ---');
    print('Search query: $_searchQuery');
    print('Attempting to fetch users...');

    // Let's just get ALL users first and filter client-side to debug
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Error fetching users: ${snapshot.error}');
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          print('Loading users...');
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final allUsers = snapshot.data?.docs ?? [];
        print('\nTotal users in database: ${allUsers.length}');
        
        // Print all users for debugging
        allUsers.forEach((doc) {
          final userData = doc.data() as Map<String, dynamic>;
          print('User ${doc.id}:');
          print('  displayName: ${userData['displayName']}');
          print('  firstName: ${userData['firstName']}');
          print('  lastName: ${userData['lastName']}');
        });

        // Client-side filtering
        final filteredUsers = allUsers.where((doc) {
          final userData = doc.data() as Map<String, dynamic>;
          final displayName = (userData['displayName'] ?? '').toString().toLowerCase();
          final firstName = (userData['firstName'] ?? '').toString().toLowerCase();
          final lastName = (userData['lastName'] ?? '').toString().toLowerCase();
          final query = _searchQuery!.toLowerCase();

          return displayName.contains(query) || 
                 firstName.contains(query) || 
                 lastName.contains(query);
        }).toList();

        print('\nFiltered users count: ${filteredUsers.length}');
        filteredUsers.forEach((doc) {
          final userData = doc.data() as Map<String, dynamic>;
          print('Matched user: ${userData['displayName']}');
        });

        if (filteredUsers.isEmpty) {
          return Center(
            child: Text(
              'No users found matching "$_searchQuery"',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final userData = filteredUsers[index].data() as Map<String, dynamic>;
            final displayName = userData['displayName'] ?? 'Unknown User';
            final userImage = userData['avatarUrl'] ?? '';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey[300],
                backgroundImage: userImage.isNotEmpty
                    ? CachedNetworkImageProvider(userImage)
                    : null,
                child: userImage.isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              title: Text(displayName),
              subtitle: Text('${userData['firstName']} ${userData['lastName']}'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(userId: filteredUsers[index].id),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildVideoGrid() {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Please sign in to view videos',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // TODO: Navigate to sign in screen
              },
              child: const Text('Sign In'),
            ),
          ],
        ),
      );
    }

    // Filter out videos without valid thumbnails
    print('Total videos before filtering: ${_videos.length}');
    
    final validVideos = _videos.where((video) {
      final videoData = video.data() as Map<String, dynamic>;
      final thumbnailUrl = videoData['thumbnailUrl'] as String?;
      final isValid = thumbnailUrl != null && thumbnailUrl.isNotEmpty;
      
      if (!isValid) {
        print('Invalid video thumbnail: ${video.id}');
        print('Thumbnail URL: $thumbnailUrl');
      }
      
      return isValid;
    }).toList();

    print('Valid videos after filtering: ${validVideos.length}');

    if (validVideos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No videos found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return MasonryGridView.count(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      crossAxisCount: 3,
      mainAxisSpacing: 1,
      crossAxisSpacing: 1,
      itemCount: validVideos.length + (_isLoadingMore ? 1 : 0),
      cacheExtent: 2000,
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        if (index >= validVideos.length) {
          return Container(
            height: 120,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                ),
              ),
            ),
          );
        }

        final video = validVideos[index];
        // Double height videos should alternate between right and left columns
        final bool isDoubleHeight = index == 2 || // First one - right column (row 1-2)
                                   index == 5 || // Second one - left column (row 2-3)
                                   index == 13;  // Third one - right column (row 5-6)
        
        final bool shouldAutoplay = isDoubleHeight;
        
        return RepaintBoundary(
          child: Container(
            height: isDoubleHeight ? 241 : 120, // Adjusted from 241.5 to 241 for perfect alignment
            decoration: BoxDecoration(
              color: Colors.black,
            ),
            child: ClipRRect(
              child: _VideoPreviewCard(
                key: ValueKey('video-${video.id}'),
                video: video,
                shouldAutoplay: shouldAutoplay,
                index: index,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VideoPreviewCard extends StatefulWidget {
  final DocumentSnapshot video;
  final bool shouldAutoplay;
  final int index;

  const _VideoPreviewCard({
    super.key,
    required this.video,
    required this.shouldAutoplay,
    required this.index,
  });

  @override
  State<_VideoPreviewCard> createState() => _VideoPreviewCardState();
}

class _VideoPreviewCardState extends State<_VideoPreviewCard> {
  VideoPlayerController? _controller;
  bool _isVisible = false;
  bool _isDisposed = false;
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    // Pre-calculate aspect ratio from video metadata if available
    final videoData = widget.video.data() as Map<String, dynamic>;
    if (videoData.containsKey('aspectRatio')) {
      _aspectRatio = videoData['aspectRatio'].toDouble();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller?.dispose();
    super.dispose();
  }

  void _initializeController() {
    if (_controller != null || _isDisposed) return;

    final videoData = widget.video.data() as Map<String, dynamic>;
    _controller = VideoPlayerController.network(
      videoData['videoUrl'],
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )..initialize().then((_) {
      if (!mounted || _isDisposed) {
        _controller?.dispose();
        return;
      }
      
      if (_controller != null) {
        _aspectRatio = _controller!.value.aspectRatio;
        _controller!
          ..setLooping(true)
          ..setVolume(0.0)
          ..setPlaybackSpeed(1.0);
        
        if (_isVisible && widget.shouldAutoplay && !_isDisposed) {
          _controller!.play();
        }
      }
      
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _cleanupController() {
    if (!_isDisposed) {
      _controller?.pause();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!_isDisposed) {
          _controller?.dispose();
          _controller = null;
          if (mounted) {
            setState(() {});
          }
        }
      });
    }
  }

  @override
  void didUpdateWidget(_VideoPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shouldAutoplay != widget.shouldAutoplay) {
      if (!widget.shouldAutoplay) {
        _cleanupController();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoData = widget.video.data() as Map<String, dynamic>;
    final double containerHeight = widget.shouldAutoplay ? 241 : 120; // Adjusted here too

    return VisibilityDetector(
      key: Key('video-${widget.video.id}'),
      onVisibilityChanged: (info) {
        if (_isDisposed) return;
        
        final bool wasVisible = _isVisible;
        _isVisible = info.visibleFraction > 0.5;

        if (_isVisible && !wasVisible && widget.shouldAutoplay) {
          _initializeController();
          _controller?.play();
        } else if (!_isVisible && wasVisible) {
          _cleanupController();
        }
      },
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                body: VideoCard(
                  video: Video.fromMap(
                    widget.video.id,
                    widget.video.data() as Map<String, dynamic>
                  ),
                  autoplay: true,
                ),
              ),
            ),
          );
        },
        child: Container(
          height: containerHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.shouldAutoplay && _controller?.value.isInitialized == true)
                FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                )
              else
                CachedNetworkImage(
                  imageUrl: videoData['thumbnailUrl'],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.error, color: Colors.grey[400]),
                  ),
                ),
              // Add video icon for regular-sized videos only
              if (!widget.shouldAutoplay)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    Icons.video_collection_rounded,
                    color: Colors.white.withOpacity(0.85),
                    size: 14,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 