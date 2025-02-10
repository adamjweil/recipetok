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
    profileUserId = widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    _tabController = TabController(
      length: isCurrentUserProfile ? 4 : 2,
      vsync: this,
      initialIndex: 0,
    );
    _initializeAnimationController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _likeAnimationController?.dispose();
    super.dispose();
  }

  // Add stream for user data
  Stream<DocumentSnapshot> _getUserData() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(profileUserId)
        .snapshots();
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
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: StreamBuilder<DocumentSnapshot>(
          stream: _getUserData(),
          builder: (context, snapshot) {
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
                if (isCurrentUserProfile)
                  Stack(
                    children: [
                      Transform.rotate(
                        angle: -35 * (3.14159 / 180),
                        child: IconButton(
                          icon: const Icon(
                            Icons.send_outlined,
                            color: Colors.black,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MessagesScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      StreamBuilder<int>(
                        stream: MessageService().getTotalUnreadCount(),
                        builder: (context, snapshot) {
                          final unreadCount = snapshot.data ?? 0;
                          if (unreadCount == 0) {
                            return const SizedBox.shrink();
                          }
                          
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
                  ),
              ],
            );
          },
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _getUserData(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      Padding(
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
                      VideoGroupsSection(
                        showAddButton: isCurrentUserProfile,
                        userId: profileUserId,
                      ),
                      TabBar(
                        controller: _tabController,
                        tabs: [
                          const Tab(icon: Icon(Icons.restaurant)),
                          const Tab(icon: Icon(Icons.grid_on)),
                          if (isCurrentUserProfile) ...[
                            const Tab(icon: Icon(Icons.bookmark_border)),
                            const Tab(icon: Icon(Icons.watch_later_outlined)),
                          ],
                        ],
                        indicatorColor: Colors.black,
                        unselectedLabelColor: Colors.grey,
                        labelColor: Colors.black,
                      ),
                    ],
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                // Meal Posts Tab
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('meal_posts')
                      .where('userId', isEqualTo: profileUserId)
                      .where('isPublic', isEqualTo: true)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final posts = snapshot.data!.docs;
                    
                    if (posts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
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
                      padding: const EdgeInsets.all(12),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = MealPost.fromFirestore(posts[index]);
                        return MealPostWrapper(post: post);
                      },
                    );
                  },
                ),

                // Videos Tab
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('videos')
                      .where('userId', isEqualTo: profileUserId)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, videoSnapshot) {
                    if (videoSnapshot.hasError) {
                      return Center(child: Text('Error: ${videoSnapshot.error}'));
                    }

                    if (videoSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final videos = videoSnapshot.data?.docs ?? [];

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

                    return GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 1,
                        mainAxisSpacing: 1,
                      ),
                      itemCount: videos.length,
                      itemBuilder: (context, index) {
                        final video = videos[index].data() as Map<String, dynamic>;
                        return GestureDetector(
                          onTap: () {
                            // Handle video tap
                          },
                          child: CachedNetworkImage(
                            imageUrl: video['thumbnailUrl'] ?? '',
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.error),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

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

  Widget _buildAvatarWithStory(Map<String, dynamic> userData) {
    return StreamBuilder<List<Story>>(
      stream: StoryService().getUserActiveStories(profileUserId),
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
                    color: Colors.grey[500],
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: hasActiveStory ? BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: const [
                        Colors.purple,
                        Colors.pink,
                        Colors.orange,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ) : null,
                  child: GestureDetector(
                    onTap: () {
                      if (hasActiveStory) {
                        _showStoryModal(context, snapshot.data!.first);
                      }
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: CustomCacheManager.isValidImageUrl(userData['avatarUrl'])
                          ? CachedNetworkImageProvider(
                              userData['avatarUrl'],
                              cacheManager: CustomCacheManager.instance,
                            )
                          : null,
                      child: !CustomCacheManager.isValidImageUrl(userData['avatarUrl'])
                          ? const Icon(Icons.person, size: 40)
                          : null,
                    ),
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
      print('Selected media type: $mediaType'); // Debug log
      print('File path: ${media.path}'); // Debug log
      
      try {
        await StoryService().uploadStory(File(media.path), mediaType);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Story uploaded successfully'),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(
                top: 20,
                right: 20,
                left: 20,
              ),
            ),
          );
        }
      } catch (e) {
        print('Error uploading story: $e'); // Debug log
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
      print('Error in _addStory: $e'); // Debug log
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
    return StreamBuilder<List<Story>>(
      stream: StoryService().getUserActiveStories(FirebaseAuth.instance.currentUser!.uid),
      builder: (context, snapshot) {
        final hasActiveStory = snapshot.hasData && snapshot.data!.isNotEmpty;
        final timeRemaining = hasActiveStory 
            ? _formatTimeRemaining(snapshot.data!.first.expiresAt)
            : '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  userData['displayName'] ?? 'User',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (hasActiveStory) 
                  Text(
                    ' $timeRemaining',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.normal,
                    ),
                  ),
              ],
            ),
            if (userData['bio'] != null && userData['bio'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(userData['bio']),
              ),
          ],
        );
      },
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

  Widget _buildBookmarkedVideosGrid() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('bookmarks')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, bookmarkSnapshot) {
        if (bookmarkSnapshot.hasError) {
          return Center(child: Text('Error: ${bookmarkSnapshot.error}'));
        }

        if (bookmarkSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final bookmarks = bookmarkSnapshot.data?.docs ?? [];

        if (bookmarks.isEmpty) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.3,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No favorite dishes yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        return StreamBuilder<List<DocumentSnapshot>>(
          stream: Stream.fromFuture(
            Future.wait(
              bookmarks.map((bookmark) {
                final bookmarkData = bookmark.data() as Map<String, dynamic>;
                final videoId = bookmarkData['videoId'] as String;
                return FirebaseFirestore.instance
                    .collection('videos')
                    .doc(videoId)
                    .get();
              }),
            ),
          ),
          builder: (context, videoSnapshot) {
            if (!videoSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final videos = videoSnapshot.data ?? [];

            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 1,
                mainAxisSpacing: 1,
              ),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final videoData = videos[index].data() as Map<String, dynamic>?;
                if (videoData == null) return const SizedBox();

                final thumbnailUrl = videoData['thumbnailUrl'] as String?;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerScreen(
                          videoData: videoData,
                          videoId: videos[index].id,
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
    );
  }

  Widget _buildTryLaterGrid() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('tryLater')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, tryLaterSnapshot) {
        if (tryLaterSnapshot.hasError) {
          return Center(child: Text('Error: ${tryLaterSnapshot.error}'));
        }

        if (tryLaterSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final tryLater = tryLaterSnapshot.data?.docs ?? [];

        if (tryLater.isEmpty) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.3,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.watch_later_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No dishes to try later',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        return FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait(
            tryLater.map((item) {
              final itemData = item.data() as Map<String, dynamic>;
              final videoId = itemData['videoId'] as String;
              return FirebaseFirestore.instance
                  .collection('videos')
                  .doc(videoId)
                  .get();
            }).toList(),
          ),
          builder: (context, videoSnapshot) {
            if (!videoSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final videos = videoSnapshot.data ?? [];

            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 1,
                mainAxisSpacing: 1,
                childAspectRatio: 0.8,
              ),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final videoData = videos[index].data() as Map<String, dynamic>?;
                if (videoData == null) return const SizedBox();

                final thumbnailUrl = videoData['thumbnailUrl'] as String?;
                final likes = videoData['likesCount'] as int? ?? 0;
                final comments = videoData['commentCount'] as int? ?? 0;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerScreen(
                          videoData: videoData,
                          videoId: videos[index].id,
                        ),
                      ),
                    );
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomCacheManager.isValidImageUrl(thumbnailUrl)
                          ? CachedNetworkImage(
                              imageUrl: thumbnailUrl!,
                              fit: BoxFit.cover,
                              cacheManager: CustomCacheManager.instance,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.error),
                              ),
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported),
                            ),
                    ],
                  ),
                );
              },
            );
          },
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
}

// Add this new widget at the bottom of the file
class UserListModal extends StatelessWidget {
  final String title;
  final List<String> userIds;
  final bool isFollowers;

  const UserListModal({
    super.key,
    required this.title,
    required this.userIds,
    required this.isFollowers,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),

          // User List
          Expanded(
            child: userIds.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isFollowers ? Icons.people_outline : Icons.person_outline,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isFollowers ? 'No followers yet' : 'Not following anyone',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: userIds.length,
                    itemBuilder: (context, index) {
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(userIds[index])
                            .get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const UserListItemSkeleton();
                          }

                          final userData = snapshot.data!.data() as Map<String, dynamic>;
                          return UserListItem(
                            userData: userData,
                            userId: userIds[index],
                            isFollowers: isFollowers,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Add these supporting widgets
class UserListItem extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String userId;
  final bool isFollowers;

  const UserListItem({
    super.key,
    required this.userData,
    required this.userId,
    required this.isFollowers,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isCurrentUser = currentUserId == userId;

    return ListTile(
      onTap: () {
        // Close the modal first
        Navigator.pop(context);
        // Then navigate to the profile
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(userId: userId),
          ),
        );
      },
      leading: CircleAvatar(
        backgroundImage: userData['avatarUrl'] != null
            ? CachedNetworkImageProvider(userData['avatarUrl'])
            : null,
        child: userData['avatarUrl'] == null ? const Icon(Icons.person) : null,
      ),
      title: Text(
        userData['displayName'] ?? 'Unknown User',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('@${userData['username'] ?? ''}'),
      trailing: !isCurrentUser ? StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();

          final following = (snapshot.data?.get('following') as List<dynamic>?) ?? [];
          final isFollowing = following.contains(userId);

          return TextButton(
            onPressed: () => _toggleFollow(context),
            style: TextButton.styleFrom(
              backgroundColor: isFollowing ? Colors.grey[200] : Theme.of(context).primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              isFollowing ? 'Unfollow' : 'Follow',
              style: TextStyle(
                color: isFollowing ? Colors.black87 : Colors.white,
                fontSize: 13,
              ),
            ),
          );
        },
      ) : null,
    );
  }

  Future<void> _toggleFollow(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final currentUserRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
      final otherUserRef = FirebaseFirestore.instance.collection('users').doc(userId);

      // Get current user data to check if already following
      final currentUserDoc = await currentUserRef.get();
      final following = (currentUserDoc.data()?['following'] as List<dynamic>?) ?? [];
      final isFollowing = following.contains(userId);

      if (isFollowing) {
        // Unfollow
        batch.update(currentUserRef, {
          'following': FieldValue.arrayRemove([userId])
        });
        batch.update(otherUserRef, {
          'followers': FieldValue.arrayRemove([currentUser.uid])
        });
      } else {
        // Follow
        batch.update(currentUserRef, {
          'following': FieldValue.arrayUnion([userId])
        });
        batch.update(otherUserRef, {
          'followers': FieldValue.arrayUnion([currentUser.uid])
        });
      }

      await batch.commit();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class UserListItemSkeleton extends StatelessWidget {
  const UserListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      contentPadding: EdgeInsets.symmetric(vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.black12,
      ),
      title: LinearProgressIndicator(),
      subtitle: LinearProgressIndicator(),
    );
  }
}

String _formatViewCount(int viewCount) {
  if (viewCount >= 1000000) {
    return '${(viewCount / 1000000).toStringAsFixed(1)}M';
  } else if (viewCount >= 1000) {
    return '${(viewCount / 1000).toStringAsFixed(1)}K';
  } else {
    return viewCount.toString();
  }
}

String _formatCount(int count) {
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  } else if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}K';
  } else {
    return count.toString();
  }
}

// Add this class at the bottom of the file
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

// Add this helper widget at the bottom of the file
class GestureDetectorWithPosition extends StatelessWidget {
  final Widget child;
  final Function(BuildContext, Offset)? onLongPressWithPosition;
  final VoidCallback onTap;

  const GestureDetectorWithPosition({
    super.key,
    required this.child,
    this.onLongPressWithPosition,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPressStart: onLongPressWithPosition != null
          ? (details) {
              onLongPressWithPosition!(context, details.globalPosition);
            }
          : null,
      child: child,
    );
  }
}

// First, create a new StatefulWidget for the like button
class LikeButton extends StatefulWidget {
  final String postId;
  final String userId;

  const LikeButton({
    super.key,
    required this.postId,
    required this.userId,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isLikeAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    try {
      final postRef = FirebaseFirestore.instance.collection('meal_posts').doc(widget.postId);
      final userLikeRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('mealPostLikes')
          .doc(widget.postId);

      final likeDoc = await userLikeRef.get();
      final isLiked = likeDoc.exists;

      final batch = FirebaseFirestore.instance.batch();

      if (isLiked) {
        batch.update(postRef, {
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([widget.userId])
        });
        batch.delete(userLikeRef);
      } else {
        setState(() => _isLikeAnimating = true);
        _controller.forward(from: 0).then((_) {
          setState(() => _isLikeAnimating = false);
        });
        
        batch.update(postRef, {
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([widget.userId])
        });
        batch.set(userLikeRef, {
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('mealPostLikes')
          .doc(widget.postId)
          .snapshots(),
      builder: (context, snapshot) {
        final isLiked = snapshot.data?.exists ?? false;
        
        return Row(
          children: [
            GestureDetector(
              onTap: _toggleLike,
              child: Row(
                children: [
                  AnimatedCrossFade(
                    firstChild: Icon(
                      Icons.thumb_up,
                      color: Theme.of(context).primaryColor,
                      size: 22,
                    ),
                    secondChild: Icon(
                      Icons.thumb_up_outlined,
                      color: Colors.grey[600],
                      size: 22,
                    ),
                    crossFadeState: isLiked
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    duration: const Duration(milliseconds: 200),
                  ),
                  const SizedBox(width: 4),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('meal_posts')
                        .doc(widget.postId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final likes = (snapshot.data?.data() 
                        as Map<String, dynamic>?)?['likes'] ?? 0;
                      return Text(
                        '$likes',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            if (_isLikeAnimating)
              ScaleTransition(
                scale: Tween<double>(begin: 0, end: 1).animate(
                  CurvedAnimation(
                    parent: _controller,
                    curve: Curves.elasticOut,
                  ),
                ),
                child: Icon(
                  Icons.thumb_up,
                  color: Theme.of(context).primaryColor,
                  size: 30,
                ),
              ),
          ],
        );
      },
    );
  }
}

// First, create a new StatefulWidget for the expandable meal post
class ExpandableMealPost extends StatefulWidget {
  final MealPost post;
  final bool isExpanded;
  final VoidCallback onToggle;
  final bool showUserInfo;

  const ExpandableMealPost({
    super.key,
    required this.post,
    required this.isExpanded,
    required this.onToggle,
    this.showUserInfo = true,
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
              _getTimeAgo(widget.post.createdAt),
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
                // Image
                if (widget.post.photoUrls.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 120,  // Fixed width for image
                      height: 120,  // Square aspect ratio
                      child: CachedNetworkImage(
                        imageUrl: widget.post.photoUrls.first,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.error, size: 20),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(width: 12),  // Spacing between image and description

                // Description
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
                    // Implement share functionality
                  },
                ),
              ],
            ),
          ),

          // Comments section
          if (widget.isExpanded) ...[
            const Divider(),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('meal_posts')
                  .doc(widget.post.id)
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

                return Column(
                  children: [
                    // Comment input
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              decoration: InputDecoration(
                                hintText: 'Add a comment...',
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
                            icon: _isPostingComment
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send_rounded),
                            onPressed: _isPostingComment ? null : _postComment,
                            color: Theme.of(context).primaryColor,
                          ),
                        ],
                      ),
                    ),

                    // Comments list
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index].data() as Map<String, dynamic>;
                        final userId = comment['userId'] as String?;
                        final timestamp = (comment['timestamp'] as Timestamp?)?.toDate();

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .get(),
                          builder: (context, userSnapshot) {
                            final userData = userSnapshot.data?.data() 
                                as Map<String, dynamic>? ?? {};

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: userData['avatarUrl'] != null
                                    ? CachedNetworkImageProvider(userData['avatarUrl'])
                                    : null,
                                child: userData['avatarUrl'] == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    userData['displayName'] ?? 'Unknown User',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (timestamp != null)
                                    Text(
                                      _getTimeAgo(timestamp),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(comment['text'] ?? ''),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
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
}

// Add this new widget
class MealPostWrapper extends StatefulWidget {
  final MealPost post;

  const MealPostWrapper({
    super.key,
    required this.post,
  });

  @override
  State<MealPostWrapper> createState() => _MealPostWrapperState();
}

class _MealPostWrapperState extends State<MealPostWrapper> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return ExpandableMealPost(
      post: widget.post,
      isExpanded: _isExpanded,
      showUserInfo: false,
      onToggle: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
    );
  }
} 