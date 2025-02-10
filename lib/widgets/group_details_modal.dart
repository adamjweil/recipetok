import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/custom_cache_manager.dart';
import '../screens/video_player_screen.dart';
import '../widgets/edit_group_modal.dart';

class GroupDetailsModal extends StatelessWidget {
  final Map<String, dynamic> group;
  final String groupId;

  const GroupDetailsModal({
    super.key,
    required this.group,
    required this.groupId,
  });

  Future<void> _removeVideo(BuildContext context, String videoId) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Get the current group data
      final groupDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('groups')
          .doc(groupId)
          .get();

      final groupData = groupDoc.data() ?? {};
      final videos = Map<String, dynamic>.from(groupData['videos'] ?? {});
      
      // Remove the video
      videos.remove(videoId);

      // Update the document with the new videos map
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('groups')
          .doc(groupId)
          .update({
        'videos': videos,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video removed from collection')),
        );
      }
    } catch (e) {
      print('Error removing video: $e'); // Debug log
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing video: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteGroup(BuildContext context) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('groups')
          .doc(groupId)
          .delete();

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Collection deleted')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting collection: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
          // Header with group info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipOval(
                    child: group['imageUrl'] != null
                        ? CachedNetworkImage(
                            imageUrl: group['imageUrl'],
                            fit: BoxFit.cover,
                            cacheManager: CustomCacheManager.instance,
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.collections, color: Colors.grey),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (group['description'] != null)
                        Text(
                          group['description'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showOptionsMenu(context),
                ),
              ],
            ),
          ),
          // Videos grid
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .collection('groups')
                  .doc(groupId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final groupData = snapshot.data?.data() as Map<String, dynamic>?;
                final videos = (groupData?['videos'] is Map) 
                    ? (groupData?['videos'] as Map<String, dynamic>?) ?? {}
                    : <String, dynamic>{};  // Convert List to empty Map if needed

                if (videos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_library, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No videos in this collection',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return FutureBuilder<List<DocumentSnapshot>>(
                  future: Future.wait(
                    videos.keys.map((videoId) => FirebaseFirestore.instance
                        .collection('videos')
                        .doc(videoId)
                        .get()),
                  ),
                  builder: (context, videoSnapshot) {
                    if (!videoSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final videoList = videoSnapshot.data ?? [];

                    return GridView.builder(
                      padding: const EdgeInsets.all(1),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 1,
                        mainAxisSpacing: 1,
                      ),
                      itemCount: videoList.length,
                      itemBuilder: (context, index) {
                        final videoData =
                            videoList[index].data() as Map<String, dynamic>?;
                        if (videoData == null) return const SizedBox();

                        final thumbnailUrl = videoData['thumbnailUrl'] as String?;

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VideoPlayerScreen(
                                  videoData: videoData,
                                  videoId: videoList[index].id,
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
                                    )
                                  : Container(color: Colors.grey[200]),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.bookmark,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => _removeVideo(
                                    context,
                                    videoList[index].id,
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
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Collection'),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => EditGroupModal(
                  groupId: groupId,
                  group: group,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete Collection', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _showDeleteConfirmation(context);
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection?'),
        content: const Text(
          'This action cannot be undone. Videos in this collection will not be deleted.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(context);
              _deleteGroup(context);
            },
          ),
        ],
      ),
    );
  }
} 