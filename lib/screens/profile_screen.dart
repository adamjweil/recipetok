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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Add stream for user data
  Stream<DocumentSnapshot> _getUserData() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
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
        GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => UserListModal(
                title: 'Following',
                userIds: following.cast<String>().toList(),
                isFollowers: false,
              ),
            );
          },
          child: _buildStatColumn(followingCount.toString(), 'Following'),
        ),
        GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => UserListModal(
                title: 'Followers',
                userIds: followers.cast<String>().toList(),
                isFollowers: true,
              ),
            );
          },
          child: _buildStatColumn(followersCount.toString(), 'Followers'),
        ),
        _buildStatColumn(videoCount.toString(), 'Dishes'),
      ],
    );
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildEditProfileButton(Map<String, dynamic> userData) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditProfileScreen(
                userData: userData,
              ),
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          side: const BorderSide(color: Colors.grey),
        ),
        child: const Text(
          'Edit profile',
          style: TextStyle(
            color: Colors.black,
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

  Widget _buildVideoGrid() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final videos = snapshot.data?.docs ?? [];

        if (videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No posts yet',
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
            final thumbnailUrl = video['thumbnailUrl'] as String?;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoPlayerScreen(
                      videoData: video,
                      videoId: videos[index].id,
                    ),
                  ),
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  thumbnailUrl != null
                      ? CachedNetworkImage(
                          imageUrl: thumbnailUrl,
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
                      : Container(color: Colors.grey[200]),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.center,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.5),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Views (left)
                          Row(
                            children: [
                              const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                              const SizedBox(width: 2),
                              Text(
                                _formatViewCount(video['views'] ?? 0),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          // Comments (right)
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('videos')
                                .doc(videos[index].id)
                                .collection('comments')
                                .snapshots(),
                            builder: (context, snapshot) {
                              final commentCount = snapshot.data?.docs.length ?? 0;
                              return Row(
                                children: [
                                  const Icon(Icons.chat_bubble, color: Colors.white, size: 14),
                                  const SizedBox(width: 2),
                                  Text(
                                    _formatCount(commentCount),
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_border, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No saved dishes yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait(
            bookmarks.map((bookmark) {
              final bookmarkData = bookmark.data() as Map<String, dynamic>;
              final videoId = bookmarkData['videoId'] as String;
              return FirebaseFirestore.instance
                  .collection('videos')
                  .doc(videoId)
                  .get();
            }),
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      thumbnailUrl != null
                          ? CachedNetworkImage(
                              imageUrl: thumbnailUrl,
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
                          : Container(color: Colors.grey[200]),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.center,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.5),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Views (left)
                              Row(
                                children: [
                                  const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                                  const SizedBox(width: 2),
                                  Text(
                                    _formatViewCount(videoData['views'] ?? 0),
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              // Comments (right)
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('videos')
                                    .doc(videos[index].id)
                                    .collection('comments')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  final commentCount = snapshot.data?.docs.length ?? 0;
                                  return Row(
                                    children: [
                                      const Icon(Icons.chat_bubble, color: Colors.white, size: 14),
                                      const SizedBox(width: 2),
                                      Text(
                                        _formatCount(commentCount),
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          FirebaseAuth.instance.currentUser?.displayName ?? '',
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
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

          return SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                      Text(
                        userData['bio'] ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      _buildEditProfileButton(userData),
                      const SizedBox(height: 12),
                      const VideoGroupsSection(),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_on)),
                    Tab(icon: Icon(Icons.bookmark_border)),
                  ],
                  indicatorColor: Colors.black,
                  unselectedLabelColor: Colors.grey,
                  labelColor: Colors.black,
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildVideoGrid(),
                      _buildBookmarkedVideosGrid(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Logout'),
              onPressed: () {
                Navigator.of(context).pop();
                _signOut(context);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildAvatarWithStory(Map<String, dynamic> userData) {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    
    return StreamBuilder<List<Story>>(
      stream: StoryService().getUserActiveStories(userId),
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
                      backgroundImage: FirebaseAuth.instance.currentUser?.photoURL != null
                          ? CachedNetworkImageProvider(
                              FirebaseAuth.instance.currentUser!.photoURL!,
                              cacheManager: CustomCacheManager.instance,
                            )
                          : null,
                      child: FirebaseAuth.instance.currentUser?.photoURL == null
                          ? const Icon(Icons.person, size: 40)
                          : null,
                    ),
                  ),
                ),
                if (!hasActiveStory)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _addStory,
                      child: Container(
                        padding: const EdgeInsets.all(4),
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
                          size: 20,
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
    this.isFollowers = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          // User List
          Expanded(
            child: userIds.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isFollowers ? Icons.people_outline : Icons.person_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isFollowers
                              ? 'No followers yet'
                              : 'Not following anyone yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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

  Future<void> _toggleFollow(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
    final otherUserRef = FirebaseFirestore.instance.collection('users').doc(userId);

    // Get current user's following list
    final userDoc = await userRef.get();
    final following = List<String>.from(userDoc.data()?['following'] ?? []);
    
    final isFollowing = following.contains(userId);

    if (isFollowing) {
      // Unfollow
      await userRef.update({
        'following': FieldValue.arrayRemove([userId]),
      });
      await otherUserRef.update({
        'followers': FieldValue.arrayRemove([currentUser.uid]),
      });
    } else {
      // Follow
      await userRef.update({
        'following': FieldValue.arrayUnion([userId]),
      });
      await otherUserRef.update({
        'followers': FieldValue.arrayUnion([currentUser.uid]),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const UserListItemSkeleton();

        final currentUserData = snapshot.data!.data() as Map<String, dynamic>;
        final following = List<String>.from(currentUserData['following'] ?? []);
        final isFollowing = following.contains(userId);
        final isCurrentUser = userId == FirebaseAuth.instance.currentUser?.uid;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[200],
            backgroundImage: userData['avatarUrl'] != null
                ? CachedNetworkImageProvider(
                    userData['avatarUrl'],
                    cacheManager: CustomCacheManager.instance,
                    errorListener: (error) => print('Error loading user avatar: $error'),
                  )
                : null,
            child: userData['avatarUrl'] == null
                ? const Icon(Icons.person, color: Colors.grey)
                : null,
          ),
          title: Text(
            userData['displayName'] ?? 'User',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            '@${userData['username'] ?? ''}',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          trailing: isCurrentUser
              ? null
              : OutlinedButton(
                  onPressed: () => _toggleFollow(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    side: BorderSide(
                      color: isFollowing
                          ? Colors.red
                          : Theme.of(context).primaryColor,
                    ),
                    backgroundColor: isFollowing
                        ? Colors.red.withOpacity(0.1)
                        : Colors.transparent,
                  ),
                  child: Text(
                    isFollowing ? 'Unfollow' : 'Follow',
                    style: TextStyle(
                      color: isFollowing
                          ? Colors.red
                          : Theme.of(context).primaryColor,
                    ),
                  ),
                ),
        );
      },
    );
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