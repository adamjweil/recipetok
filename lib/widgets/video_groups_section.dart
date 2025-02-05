import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/custom_cache_manager.dart';
import './create_group_modal.dart';
import './group_details_modal.dart';

class VideoGroupsSection extends StatelessWidget {
  final bool showAddButton;
  final String? userId;

  const VideoGroupsSection({
    super.key,
    this.showAddButton = true,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final String profileUserId = userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(profileUserId)
          .collection('groups')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink(); // Hide on error
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final groups = snapshot.data?.docs ?? [];

        // If there are no groups and this isn't the current user's profile, hide the section
        if (groups.isEmpty && !showAddButton) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Collections',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (showAddButton)
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      _showCreateGroupModal(context);
                    },
                  ),
              ],
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: groups.length + (showAddButton ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == groups.length && showAddButton) {
                    return _buildCreateGroupButton(context);
                  }

                  final group = groups[index].data() as Map<String, dynamic>;
                  return _buildGroupItem(context, group, groups[index].id);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGroupItem(BuildContext context, Map<String, dynamic> group, String groupId) {
    return GestureDetector(
      onTap: () => _showGroupModal(context, group, groupId),
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
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
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.collections, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.collections, color: Colors.grey),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              group['name'] ?? '',
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateGroupButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCreateGroupModal(context),
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Icon(Icons.add, size: 30, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text(
              'New',
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateGroupModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateGroupModal(),
    );
  }

  void _showGroupModal(BuildContext context, Map<String, dynamic> group, String groupId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GroupDetailsModal(
        group: group,
        groupId: groupId,
      ),
    );
  }
} 