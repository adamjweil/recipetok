import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

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
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 500 &&
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
      print('Loading more videos...');
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('videos')
          .orderBy('createdAt', descending: true)  // Match the initial query
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize)
          .get();

      print('Fetched ${snapshot.docs.length} more videos');

      if (!mounted) return;

      setState(() {
        _videos.addAll(snapshot.docs);
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _isLoadingMore = false;
      });
    } catch (e, stackTrace) {
      print('Error loading more videos: $e');
      print('Stack trace: $stackTrace');
      
      if (!mounted) return;
      
      setState(() {
        _isLoadingMore = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load more videos: ${e.toString()}'),
          duration: const Duration(seconds: 5),
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

    // Implement search logic here
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
        onSubmitted: _onSearch,
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
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: const TabBar(
                tabs: [
                  Tab(text: 'Videos'),
                  Tab(text: 'Users'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildVideoSearchResults(),
                  _buildUserSearchResults(),
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
    // Implement user search results
    return const Center(child: Text('User results'));
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

    if (_videos.isEmpty) {
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

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemCount: _videos.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _videos.length) {
          return const Center(child: CircularProgressIndicator());
        }

        final video = _videos[index];
        // Calculate row number (0-based) and position in row
        final int row = index ~/ 3;  // Integer division by 3
        final int positionInRow = index % 3;  // 0 = left, 1 = middle, 2 = right
        
        // Alternate between right (even rows) and left (odd rows) videos
        final bool shouldAutoplay = row % 2 == 0 
            ? positionInRow == 2  // Right video for even rows (0, 2, 4...)
            : positionInRow == 0; // Left video for odd rows (1, 3, 5...)
        
        return ClipRRect(
          child: _VideoPreviewCard(
            video: video,
            shouldAutoplay: shouldAutoplay,
            index: index,
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
    )..initialize().then((_) {
      if (!mounted || _isDisposed) {
        _controller?.dispose();
        return;
      }
      setState(() {});
      if (_controller == null || _isDisposed) return;
      _controller?.setLooping(true);
      _controller?.setVolume(0.0);
      if (_isVisible && widget.shouldAutoplay && !_isDisposed) {
        _controller?.play();
      }
    });
  }

  void _cleanupController() {
    if (!_isDisposed) {
      _controller?.pause();
      _controller?.dispose();
      _controller = null;
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
          // Navigate to video detail screen
        },
        child: Container(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.shouldAutoplay && _controller?.value.isInitialized == true)
                AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                )
              else
                Image.network(
                  videoData['thumbnailUrl'],
                  fit: BoxFit.cover,
                ),
              if (!widget.shouldAutoplay || _controller?.value.isInitialized != true)
                const Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      videoData['title'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,  // Smaller font size
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 14,  // Smaller icon
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${videoData['likeCount'] ?? 0}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,  // Smaller font size
                            shadows: [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black54,
                              ),
                            ],
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
      ),
    );
  }
} 