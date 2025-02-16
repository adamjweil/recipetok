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
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final groups = snapshot.data?.docs ?? [];

        if (groups.isEmpty && !showAddButton) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverMainAxisGroup(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Collections',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == groups.length && showAddButton) {
                      return _buildCreateGroupButton(context);
                    }

                    final group = groups[index].data() as Map<String, dynamic>;
                    return _buildGroupItem(context, group, groups[index].id);
                  },
                  childCount: groups.length + (showAddButton ? 1 : 0),
                ),
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
      child: Column(
        children: [
          Expanded(
            child: FractionallySizedBox(
              widthFactor: 0.75,
              heightFactor: 0.75,
              child: Container(
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
            ),
          ),
          const SizedBox(height: 8),
          Text(
            group['name'] ?? '',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCreateGroupButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCreateGroupModal(context),
      child: Column(
        children: [
          Expanded(
            child: FractionallySizedBox(
              widthFactor: 0.75,
              heightFactor: 0.75,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[300]!),
                  color: Colors.grey[100],
                ),
                child: Center(
                  child: Icon(Icons.add, color: Colors.grey[600], size: 32),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'New Collection',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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