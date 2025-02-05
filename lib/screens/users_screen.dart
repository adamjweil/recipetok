import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/story.dart';
import '../services/story_service.dart';
import '../widgets/story_viewer.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Users'),
            Tab(text: 'Following'),
            Tab(text: 'Followers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersList(type: 'all'),
          _buildUsersList(type: 'following'),
          _buildUsersList(type: 'followers'),
        ],
      ),
    );
  }

  Widget _buildUsersList({required String type}) {
    Query query;
    
    switch (type) {
      case 'following':
        query = _firestore
            .collection('users')
            .where('followers', arrayContains: currentUserId);
        break;
      case 'followers':
        query = _firestore
            .collection('users')
            .where('following', arrayContains: currentUserId);
        break;
      default:
        query = _firestore.collection('users');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data?.docs ?? [];

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.group_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  type == 'all' 
                      ? 'No users found'
                      : type == 'following' 
                          ? 'You are not following anyone yet'
                          : 'No followers yet',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userData = users[index].data() as Map<String, dynamic>;
            return _UserListTile(
              userData: userData,
              currentUserId: currentUserId,
              onFollow: () => _toggleFollow(users[index].id),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleFollow(String targetUserId) async {
    final userRef = _firestore.collection('users').doc(currentUserId);
    final targetUserRef = _firestore.collection('users').doc(targetUserId);

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
}

class _UserListTile extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String currentUserId;
  final VoidCallback onFollow;

  const _UserListTile({
    required this.userData,
    required this.currentUserId,
    required this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCurrentUser = userData['uid'] == currentUserId;
    final dynamic followersData = userData['followers'];
    final List followers = followersData is List ? followersData : [];
    final bool isFollowing = followers.contains(currentUserId);

    // Add these debug prints here
    print('User data fields: ${userData.keys.toList()}');
    print('User ID value: ${userData['id']}');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: StreamBuilder<List<Story>>(
          stream: StoryService().getUserActiveStories(userData['id'] ?? ''),
          builder: (context, snapshot) {
            // Add this debug print here
            print('Stories for user ${userData['id']}: ${snapshot.data?.length ?? 0}');
            
            final hasActiveStory = snapshot.hasData && snapshot.data!.isNotEmpty;
            
            return GestureDetector(
              onTap: () {
                if (hasActiveStory) {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.black,
                    builder: (context) => StoryViewer(story: snapshot.data!.first),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(2),
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
                child: CircleAvatar(
                  radius: hasActiveStory ? 24 : 25,
                  backgroundImage: CachedNetworkImageProvider(
                    userData['avatarUrl'] ?? 'https://placeholder.com/150',
                  ),
                ),
              ),
            );
          },
        ),
        title: Text(
          userData['displayName'] ?? 'Unknown User',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('@${userData['username'] ?? ''}'),
            const SizedBox(height: 4),
            Text(
              userData['bio'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: !isCurrentUser
            ? TextButton(
                onPressed: onFollow,
                style: TextButton.styleFrom(
                  backgroundColor: isFollowing ? Colors.grey[200] : Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: TextStyle(
                    color: isFollowing ? Colors.black87 : Colors.white,
                  ),
                ),
              )
            : null,
        onTap: () {
          // Navigate to user profile
          // TODO: Implement navigation to user profile
        },
      ),
    );
  }
} 