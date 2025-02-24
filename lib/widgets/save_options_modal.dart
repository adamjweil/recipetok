import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/custom_cache_manager.dart';
import '../widgets/create_group_modal.dart';

class SaveOptionsModal extends StatelessWidget {
  final String videoId;
  final Map<String, dynamic> videoData;
  final String currentUserId;

  const SaveOptionsModal({
    super.key,
    required this.videoId,
    required this.videoData,
    required this.currentUserId,
  });

  void _showTopSnackBar(BuildContext context, String message, {bool isError = false}) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(10),
          color: isError ? Colors.red : Colors.black87,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  Future<void> _saveToTryLater(BuildContext context) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final videoRef = FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId);

      final videoDoc = await videoRef.get();
      final List<dynamic> tryLaterBy = videoDoc.data()?['tryLaterBy'] ?? [];
      final bool isInTryLater = tryLaterBy.contains(userId);
      
      if (isInTryLater) {
        await videoRef.update({
          'tryLaterBy': FieldValue.arrayRemove([userId])
        });
        if (context.mounted) {
          Navigator.pop(context);
          _showTopSnackBar(context, 'Removed from Try Later');
        }
      } else {
        await videoRef.update({
          'tryLaterBy': FieldValue.arrayUnion([userId])
        });

        if (context.mounted) {
          Navigator.pop(context);
          _showTopSnackBar(context, 'Added to Try Later');
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showTopSnackBar(context, 'Error: ${e.toString()}', isError: true);
      }
    }
  }

  Future<void> _toggleGroup(BuildContext context, String groupId, bool isInGroup) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final groupRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('groups')
          .doc(groupId);

      if (isInGroup) {
        // Remove from group
        await groupRef.update({
          'videos.$videoId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Force a refresh of the groups collection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('groups')
            .get();

        if (context.mounted) {
          Navigator.pop(context);
          _showTopSnackBar(context, 'Removed from collection');
        }
      } else {
        // Add to group
        await groupRef.update({
          'videos.$videoId': {
            'addedAt': FieldValue.serverTimestamp(),
            'videoId': videoId,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Force a refresh of the groups collection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('groups')
            .get();

        if (context.mounted) {
          Navigator.pop(context);
          _showTopSnackBar(context, 'Added to collection');
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showTopSnackBar(context, 'Error: ${e.toString()}', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Save to',
                  style: TextStyle(
                    fontSize: 20,
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
          // Add Try Later option
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('videos')
                .doc(videoId)
                .snapshots(),
            builder: (context, tryLaterSnapshot) {
              final videoData = tryLaterSnapshot.data?.data() as Map<String, dynamic>?;
              final List<dynamic> tryLaterBy = videoData?['tryLaterBy'] ?? [];
              final bool isTryLater = tryLaterBy.contains(userId);
              
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.watch_later_outlined, color: Colors.white),
                ),
                title: const Text('Try Later'),
                trailing: Icon(
                  isTryLater ? Icons.check_circle : Icons.add_circle_outline,
                  color: isTryLater ? Colors.green : Colors.grey,
                ),
                onTap: () => _saveToTryLater(context),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(),
          ),
          // Collections header
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Collections',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const CreateGroupModal(),
                    );
                  },
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Create'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
          ),
          // Groups list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('groups')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final groups = snapshot.data?.docs ?? [];

                if (groups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.collections, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No collections yet',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index].data() as Map<String, dynamic>;
                    final groupId = groups[index].id;
                    final videos = (group['videos'] as Map<String, dynamic>?) ?? {};
                    final bool isVideoInGroup = videos.containsKey(videoId);

                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
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
                      title: Text(group['name'] ?? ''),
                      subtitle: Text('${videos.length} videos'),
                      trailing: Icon(
                        isVideoInGroup ? Icons.check_circle : Icons.add_circle_outline,
                        color: isVideoInGroup ? Colors.green : Colors.grey,
                      ),
                      onTap: () => _toggleGroup(context, groupId, isVideoInGroup),
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