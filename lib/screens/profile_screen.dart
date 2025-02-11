import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/home_screen.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../screens/edit_profile_screen.dart';
import '../utils/custom_cache_manager.dart';
import '../widgets/video_groups_section.dart';
import './video_player_screen.dart';
import '../models/story.dart';
import '../services/story_service.dart';
import 'package:video_compress/video_compress.dart';
import '../widgets/story_viewer.dart';
import 'package:share_plus/share_plus.dart';
import '../screens/messages_screen.dart';
import '../services/message_service.dart';
import '../screens/chat_screen.dart';
import '../models/meal_post.dart';
import '../widgets/meal_post_card.dart';
import '../widgets/profile/user_list_modal.dart';
import '../widgets/meal_post/expandable_meal_post.dart';
import '../widgets/meal_post/meal_post_wrapper.dart';
import '../widgets/profile_tabs/videos_grid.dart';
import '../widgets/profile_tabs/bookmarked_videos_grid.dart';
import '../widgets/profile_tabs/try_later_grid.dart';
import '../utils/time_formatter.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({
    super.key,
    this.userId,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isUploading = false;
  late final String profileUserId;
  bool get isCurrentUserProfile => profileUserId == FirebaseAuth.instance.currentUser?.uid;
  bool _isLikeAnimating = false;
  AnimationController? _likeAnimationController;
  final _tabKey = PageStorageKey('profile_tab');
  late Stream<List<Story>> _storiesStream;

  void _initializeAnimationController() {
    _likeAnimationController?.dispose();
    _likeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void initState() {
    super.initState();
    
    // Initialize profileUserId
    profileUserId = widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    
    if (profileUserId.isEmpty) {
      debugPrint('❌ No valid user ID found for profile');
      return;
    }

    _tabController = TabController(
      length: isCurrentUserProfile ? 4 : 2,
      vsync: this,
      initialIndex: 0,
    );
    _initializeAnimationController();
    _storiesStream = StoryService().getUserActiveStories(profileUserId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _likeAnimationController?.dispose();
    super.dispose();
  }

  Stream<DocumentSnapshot> _getUserData() {
    if (profileUserId.isEmpty) {
      debugPrint('❌ Attempted to get user data with empty ID');
      return Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(profileUserId)
        .snapshots()
        .where((snapshot) => snapshot.exists && snapshot.data() != null)
        .map((snapshot) {
          final data = snapshot.data() as Map<String, dynamic>? ?? {};
          debugPrint('👤 User data loaded for $profileUserId: ${data.isNotEmpty}');
          return snapshot;
        });
  }

  Widget _buildProfileStats(Map<String, dynamic> userData) {
    final videoCount = userData['videoCount'] ?? 0;
    final followers = userData['followers'] ?? [];
    final following = userData['following'] ?? [];
    final followersCount = followers is List ? followers.length : 0;
    final followingCount = following is List ? following.length : 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStat(videoCount.toString(), 'Posts'),
        GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) => SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: UserListModal(
                  title: 'Followers',
                  userIds: followers.cast<String>().toList(),
                  isFollowers: true,
                ),
              ),
            );
          },
          child: _buildStat(followersCount.toString(), 'Followers'),
        ),
        GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) => SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: UserListModal(
                  title: 'Following',
                  userIds: following.cast<String>().toList(),
                  isFollowers: false,
                ),
              ),
            );
          },
          child: _buildStat(followingCount.toString(), 'Following'),
        ),
      ],
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEditProfileButton(Map<String, dynamic> userData) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditProfileScreen(userData: userData),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[100],
            foregroundColor: Colors.black,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            minimumSize: const Size(0, 36),
          ),
          child: const Text(
            'Edit Profile',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateProfilePhoto() async {
    final ImagePicker picker = ImagePicker();
    
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      final user = FirebaseAuth.instance.currentUser;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_avatars')
          .child('${user?.uid ?? 'unknown'}.jpg');

      await storageRef.putFile(File(image.path));
      final downloadUrl = await storageRef.getDownloadURL();

      await user?.updatePhotoURL(downloadUrl);

      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated successfully')),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile photo: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await GoogleSignIn().signOut(); // Sign out of Google first if using Google Sign In
      await FirebaseAuth.instance.signOut(); // Then sign out of Firebase
      
      if (mounted) {
        // Clear navigation stack and return to welcome screen
        Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
      }
    } catch (e) {
      print('Error during sign out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleVideoLongPress(BuildContext context, Map<String, dynamic> video, String videoId, Offset tapPosition) async {
    final isPinned = video['isPinned'] ?? false;
    
    // Get count of currently pinned videos
    final pinnedVideosSnapshot = await FirebaseFirestore.instance
        .collection('videos')
        .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
        .where('isPinned', isEqualTo: true)
        .get();
    
    final pinnedCount = pinnedVideosSnapshot.docs.length;

    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromLTWH(
        tapPosition.dx,
        tapPosition.dy,
        0,
        0,
      ),
      Offset.zero & overlay.size,
    );

    await showMenu(
      context: context,
      position: position,
      items: [
        if (!isPinned && pinnedCount < 3)
          PopupMenuItem(
            child: Row(
              children: const [
                Icon(Icons.push_pin),
                SizedBox(width: 8),
                Text('Pin to profile'),
              ],
            ),
            onTap: () async {
              await FirebaseFirestore.instance
                  .collection('videos')
                  .doc(videoId)
                  .update({'isPinned': true});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Video pinned to profile'),
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.only(
                      top: 20,
                      right: 20,
                      left: 20,
                    ),
                  ),
                );
              }
            },
          ),
        if (isPinned)
          PopupMenuItem(
            child: Row(
              children: const [
                Icon(Icons.push_pin_outlined),
                SizedBox(width: 8),
                Text('Unpin from profile'),
              ],
            ),
            onTap: () async {
              await FirebaseFirestore.instance
                  .collection('videos')
                  .doc(videoId)
                  .update({'isPinned': false});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Video unpinned from profile'),
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.only(
                      top: 20,
                      right: 20,
                      left: 20,
                    ),
                  ),
                );
              }
            },
          ),
        PopupMenuItem(
          child: Row(
            children: const [
              Icon(Icons.share),
              SizedBox(width: 8),
              Text('Share'),
            ],
          ),
          onTap: () {
            Share.share('Check out this video: ${video['videoUrl']}');
          },
        ),
        PopupMenuItem(
          child: Row(
            children: const [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
          onTap: () async {
            // Show confirmation dialog
            if (mounted) {
              bool? confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Video'),
                  content: const Text('Are you sure you want to delete this video? This action cannot be undone.'),
                  actions: [
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    TextButton(
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await FirebaseFirestore.instance
                    .collection('videos')
                    .doc(videoId)
                    .delete();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Video deleted'),
                      behavior: SnackBarBehavior.floating,
                      margin: EdgeInsets.only(
                        top: 20,
                        right: 20,
                        left: 20,
                      ),
                    ),
                  );
                }
              }
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (profileUserId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Invalid user profile')),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: StreamBuilder<DocumentSnapshot>(
          stream: _getUserData(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
              );
            }

            final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
            
            return AppBar(
              leading: isCurrentUserProfile
                  ? IconButton(
                      icon: const Icon(Icons.menu, color: Colors.black),
                      onPressed: () => _showLogoutDialog(context, userData),
                    )
                  : IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
              title: Text(
                userData['displayName'] ?? '',
                style: const TextStyle(color: Colors.black),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                if (isCurrentUserProfile) _buildMessagesButton(),
              ],
            );
          },
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _getUserData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          if (userData.isEmpty) {
            return const Center(child: Text('User data not found'));
          }

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildAvatarWithStory(userData),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _buildProfileStats(userData),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildProfileInfo(userData),
                        const SizedBox(height: 12),
                        _buildProfileActions(userData),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  delegate: _StickyTabBarDelegate(
                    tabBar: TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.black,
                      unselectedLabelColor: Colors.grey,
                      labelColor: Colors.black,
                      tabs: [
                        const Tab(icon: Icon(Icons.restaurant)),
                        const Tab(icon: Icon(Icons.grid_on)),
                        if (isCurrentUserProfile) ...[
                          const Tab(icon: Icon(Icons.collections_bookmark)),
                          const Tab(icon: Icon(Icons.watch_later_outlined)),
                        ],
                      ],
                    ),
                  ),
                  pinned: true,
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildMealPostsTab(),
                _buildVideosGrid(),
                if (isCurrentUserProfile) ...[
                  _buildBookmarkedVideosGrid(),
                  _buildTryLaterGrid(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessagesButton() {
    return Stack(
      children: [
        Transform.rotate(
          angle: -35 * (3.14159 / 180),
          child: IconButton(
            icon: const Icon(Icons.send_outlined, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MessagesScreen()),
              );
            },
          ),
        ),
        StreamBuilder<int>(
          stream: MessageService().getTotalUnreadCount(),
          builder: (context, snapshot) {
            final unreadCount = snapshot.data ?? 0;
            if (unreadCount == 0) return const SizedBox.shrink();
            
            return Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 14,
                  minHeight: 14,
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAvatarWithStory(Map<String, dynamic> userData) {
    final avatarUrl = userData['avatarUrl'] as String?;
    debugPrint('👤 Building avatar with URL: "$avatarUrl"');
    
    Widget buildAvatarWidget() {
      return CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey[200],
        child: avatarUrl != null && avatarUrl.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: avatarUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                cacheManager: CustomCacheManager.instance,
                placeholder: (context, url) => const Icon(Icons.person, size: 40, color: Colors.grey),
                errorWidget: (context, url, error) => const Icon(Icons.person, size: 40, color: Colors.grey),
              ),
            )
          : const Icon(Icons.person, size: 40, color: Colors.grey),
      );
    }

    return StreamBuilder<List<Story>>(
      stream: _storiesStream,
      builder: (context, snapshot) {
        final hasActiveStory = snapshot.hasData && snapshot.data!.isNotEmpty;
        final timeRemaining = hasActiveStory 
            ? _formatTimeRemaining(snapshot.data!.first.expiresAt)
            : '';
        
        return Column(
          children: [
            if (hasActiveStory)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  timeRemaining,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    if (hasActiveStory) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StoryViewer(
                            story: snapshot.data!.first,
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: hasActiveStory ? BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Colors.purple, Colors.pink, Colors.orange],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ) : null,
                    child: buildAvatarWidget(),
                  ),
                ),
                if (!hasActiveStory && isCurrentUserProfile)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _addStory,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _addStory() async {
    final ImagePicker picker = ImagePicker();
    
    try {
      final XFile? media = await showDialog<XFile>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add Story'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take Photo'),
                onTap: () async {
                  Navigator.pop(
                    context,
                    await picker.pickImage(source: ImageSource.camera),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_camera_back),
                title: const Text('Record Video'),
                onTap: () async {
                  Navigator.pop(
                    context,
                    await picker.pickVideo(
                      source: ImageSource.camera,
                      maxDuration: const Duration(seconds: 10),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(
                    context,
                    await picker.pickImage(source: ImageSource.gallery),
                  );
                },
              ),
            ],
          ),
        ),
      );

      if (media == null) return;

      setState(() => _isUploading = true);
      
      final mediaType = media.name.endsWith('.mp4') ? 'video' : 'image';
      debugPrint('Selected media type: $mediaType');
      debugPrint('File path: ${media.path}');
      
      try {
        await StoryService().uploadStory(File(media.path), mediaType);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Story uploaded successfully'),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(
                top: 20,
                right: 20,
                left: 20,
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error uploading story: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading story: $e'),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(
                top: 20,
                right: 20,
                left: 20,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error in _addStory: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showStoryModal(BuildContext context, Story story) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => StoryViewer(story: story),
    );
  }

  // Add this helper method to format the remaining time
  String _formatTimeRemaining(DateTime expiresAt) {
    final now = DateTime.now();
    final difference = expiresAt.difference(now);
    
    if (difference.inMinutes < 1) {
      return '(<1m)';
    } else {
      return '(${difference.inMinutes}m)';
    }
  }

  // Update the profile section where the name is displayed
  Widget _buildProfileInfo(Map<String, dynamic> userData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (userData['bio'] != null && userData['bio'].toString().isNotEmpty)
          Text(
            userData['bio'],
            style: const TextStyle(fontSize: 14),
          ),
      ],
    );
  }

  Widget _buildProfileActions(Map<String, dynamic> userData) {
    if (!isCurrentUserProfile) {  // Only show actions for other users' profiles
      final List followers = userData['followers'] ?? [];
      final bool isFollowing = followers.contains(FirebaseAuth.instance.currentUser?.uid);

      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Follow/Unfollow Button
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton(
                onPressed: () {
                  _toggleFollow(userData['uid']);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowing ? Colors.grey[100] : Theme.of(context).primaryColor,
                  foregroundColor: isFollowing ? Colors.black : Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: isFollowing 
                        ? BorderSide(color: Colors.grey[300]!)
                        : BorderSide.none,
                  ),
                  minimumSize: const Size(0, 36),
                ),
                child: Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          // Message Button
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton(
                onPressed: () => _openChat(userData),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[100],
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  minimumSize: const Size(0, 36),
                ),
                child: const Text(
                  'Message',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    // Return empty container for current user's profile
    return const SizedBox.shrink();
  }

  Future<void> _toggleFollow(String targetUserId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);
    final targetUserRef = FirebaseFirestore.instance.collection('users').doc(targetUserId);

    final userDoc = await userRef.get();
    final List following = userDoc.data()?['following'] ?? [];

    if (following.contains(targetUserId)) {
      // Unfollow
      await userRef.update({
        'following': FieldValue.arrayRemove([targetUserId])
      });
      await targetUserRef.update({
        'followers': FieldValue.arrayRemove([currentUserId])
      });
    } else {
      // Follow
      await userRef.update({
        'following': FieldValue.arrayUnion([targetUserId])
      });
      await targetUserRef.update({
        'followers': FieldValue.arrayUnion([currentUserId])
      });
    }
  }

  Future<void> _openChat(Map<String, dynamic> otherUserData) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Create conversation ID by sorting user IDs and joining them
      final userIds = [currentUser.uid, otherUserData['uid']];
      userIds.sort(); // Sort the IDs
      final conversationId = userIds.join('_'); // Join them with underscore

      // Check if conversation exists
      final conversationDoc = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .get();

      // If conversation doesn't exist, create it
      if (!conversationDoc.exists) {
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(conversationId)
            .set({
          'participants': [currentUser.uid, otherUserData['uid']],
          'lastMessage': '',
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'lastMessageSenderId': '',
        });
      }

      if (!mounted) return;

      // Navigate to chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conversationId,
            otherUser: {
              'userId': otherUserData['uid'],
              'displayName': otherUserData['displayName'],
              'username': otherUserData['username'],
              'avatarUrl': otherUserData['avatarUrl'],
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening chat: $e')),
      );
    }
  }

  Widget _buildMealPostsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('meal_posts')
          .where('userId', isEqualTo: profileUserId)
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
                Icon(Icons.restaurant, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No meal posts yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final postData = posts[index].data() as Map<String, dynamic>;
            final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
            
            // Convert string to MealType enum
            MealType getMealType(String? type) {
              switch (type?.toLowerCase()) {
                case 'breakfast':
                  return MealType.breakfast;
                case 'lunch':
                  return MealType.lunch;
                case 'dinner':
                  return MealType.dinner;
                case 'snack':
                  return MealType.snack;
                default:
                  return MealType.breakfast;
              }
            }
            
            // Safely get likes array
            final likes = postData['likes'];
            List<String> likesList = [];
            if (likes != null) {
              if (likes is List) {
                likesList = List<String>.from(likes);
              } else if (likes is int) {
                // If likes is stored as a count instead of a list
                likesList = List.generate(likes, (index) => '');
              }
            }
            
            final mealPost = MealPost(
              userId: postData['userId'] ?? '',
              userName: postData['userName'] ?? '',
              title: postData['title'] ?? '',
              description: postData['description'] ?? '',
              imageUrl: postData['imageUrl'] ?? '',
              createdAt: (postData['createdAt'] as Timestamp).toDate(),
              likes: likesList.length,
              id: posts[index].id,
              photoUrls: List<String>.from(postData['photoUrls'] ?? []),
              mealType: getMealType(postData['mealType'] as String?),
              cookTime: postData['cookTime'] ?? '',
              calories: int.parse(postData['calories']?.toString() ?? '0'),
              protein: int.parse(postData['protein']?.toString() ?? '0'),
              isVegetarian: postData['isVegetarian'] ?? false,
              carbonSaved: double.parse(postData['carbonSaved']?.toString() ?? '0'),
              comments: 0,
              isLiked: likesList.contains(currentUserId),
              isPublic: postData['isPublic'] ?? true,
            );
            
            return MealPostWrapper(
              post: mealPost,
            );
          },
        );
      },
    );
  }

  Widget _buildVideosGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: profileUserId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('❌ Error loading videos: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final videos = snapshot.data?.docs ?? [];
        debugPrint('📊 Loaded ${videos.length} videos');

        if (videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No videos yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // Sort videos to show pinned ones first
        final sortedVideos = [...videos];
        sortedVideos.sort((a, b) {
          final isPinnedA = (a.data() as Map<String, dynamic>)['isPinned'] ?? false;
          final isPinnedB = (b.data() as Map<String, dynamic>)['isPinned'] ?? false;
          if (isPinnedA && !isPinnedB) return -1;
          if (!isPinnedA && isPinnedB) return 1;
          return 0;
        });

        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
            childAspectRatio: 0.8,
          ),
          itemCount: sortedVideos.length,
          itemBuilder: (context, index) {
            final videoData = sortedVideos[index].data() as Map<String, dynamic>;
            final videoId = sortedVideos[index].id;
            final thumbnailUrl = videoData['thumbnailUrl'] as String?;
            
            if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
              return Container(
                color: Colors.grey[200],
                child: const Center(child: Icon(Icons.video_library)),
              );
            }

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoPlayerScreen(
                      videoData: videoData,
                      videoId: videoId,
                    ),
                  ),
                );
              },
              onLongPressStart: (LongPressStartDetails details) {
                // This provides the correct tap position for the menu
                _handleVideoLongPress(
                  context,
                  videoData,
                  videoId,
                  details.globalPosition,
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    fit: BoxFit.cover,
                    cacheManager: CustomCacheManager.instance,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) {
                      debugPrint('❌ Image loading error for video $videoId: $error');
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(child: Icon(Icons.error)),
                      );
                    },
                  ),
                  // Show pin indicator if video is pinned
                  if (videoData['isPinned'] == true)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(
                        Icons.push_pin,
                        color: Colors.white,
                        size: 20,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBookmarkedVideosGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('videos')
          .where('bookmarkedBy', arrayContains: FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final videos = snapshot.data?.docs ?? [];
        
        return CustomScrollView(
          slivers: [
            // Add VideoGroupsSection at the top
            SliverToBoxAdapter(
              child: VideoGroupsSection(),
            ),
            
            // Only show video grid if there are videos
            if (videos.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildVideoGrid(videos),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTryLaterGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('videos')
          .where('tryLaterBy', arrayContains: FirebaseAuth.instance.currentUser?.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('❌ Error loading Try Later videos: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final videos = snapshot.data?.docs ?? [];
        debugPrint('📊 Loaded ${videos.length} Try Later videos');

        if (videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.watch_later_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No videos saved for later',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // Use a SingleChildScrollView to allow scrolling within the tab
        return SingleChildScrollView(
          child: Column(
            children: [
              GridView.builder(
                shrinkWrap: true, // Important!
                physics: const NeverScrollableScrollPhysics(), // Important!
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 1,
                  mainAxisSpacing: 1,
                  childAspectRatio: 0.8,
                ),
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  final videoData = videos[index].data() as Map<String, dynamic>;
                  final videoId = videos[index].id;
                  final thumbnailUrl = videoData['thumbnailUrl'] as String?;

                  if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.video_library)),
                    );
                  }

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoPlayerScreen(
                            videoData: videoData,
                            videoId: videoId,
                          ),
                        ),
                      );
                    },
                    child: CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: Icon(Icons.error)),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper method to build video grid
  Widget _buildVideoGrid(List<QueryDocumentSnapshot> videos) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
        childAspectRatio: 0.8,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final videoData = videos[index].data() as Map<String, dynamic>;
        final videoId = videos[index].id;
        final thumbnailUrl = videoData['thumbnailUrl'] as String?;

        if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
          return Container(
            color: Colors.grey[200],
            child: const Center(child: Icon(Icons.video_library)),
          );
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerScreen(
                  videoData: videoData,
                  videoId: videoId,
                ),
              ),
            );
          },
          child: CachedNetworkImage(
            imageUrl: thumbnailUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[200],
              child: const Center(child: Icon(Icons.error)),
            ),
          ),
        );
      },
    );
  }

  String _getTimeAgo(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else {
      return '${(difference.inDays / 365).floor()}y ago';
    }
  }

  Widget _buildAvatar(String? avatarUrl) {
    return CustomCacheManager.buildProfileAvatar(
      url: avatarUrl,
      radius: 40,
    );
  }

  bool _isValidUrl(String? url, {String debugContext = ''}) {
    if (url == null || url.trim().isEmpty) {
      debugPrint('⚠️ Empty URL detected in: $debugContext');
      debugPrint('Stack trace:');
      debugPrint(StackTrace.current.toString());
      return false;
    }

    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || !uri.hasAuthority) {
        debugPrint('⚠️ Invalid URL format in $debugContext: $url');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ URL parsing error in $debugContext: $e');
      return false;
    }
  }

  Future<void> _showLogoutDialog(BuildContext context, Map<String, dynamic> userData) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Menu'),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditProfileScreen(
                      userData: userData,
                    ),
                  ),
                );
              },
              child: const Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 12),
                  Text('Edit Profile'),
                ],
              ),
            ),
            const Divider(),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _signOut(context);
              },
              child: Row(
                children: [
                  const Icon(Icons.logout, color: Colors.red),
                  const SizedBox(width: 12),
                  Text('Logout', style: TextStyle(color: Colors.red[700])),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// First, create a delegate class for the persistent header
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _StickyTabBarDelegate({required this.tabBar});

  @override
  double get minExtent => tabBar.preferredSize.height;
  
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor, // Match background color
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return false;
  }
} 