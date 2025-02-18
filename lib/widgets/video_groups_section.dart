import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/custom_cache_manager.dart';
import './create_group_modal.dart';
import './group_details_modal.dart';

class VideoGroupsSection extends StatefulWidget {
  final bool showAddButton;
  final String? userId;

  const VideoGroupsSection({
    super.key,
    this.showAddButton = true,
    this.userId,
  });

  @override
  State<VideoGroupsSection> createState() => _VideoGroupsSectionState();
}

class _VideoGroupsSectionState extends State<VideoGroupsSection> {
  bool _isExpanded = true;

  void _showInfoModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.folder_special,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'About Collections',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Organize Your Recipe Videos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create collections to categorize and easily find your favorite recipe videos. Perfect for organizing by cuisine, meal type, or cooking technique.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String profileUserId = widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    
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

        if (groups.isEmpty && !widget.showAddButton) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverMainAxisGroup(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Collections',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.help_outline,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      onPressed: () => _showInfoModal(context),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ],
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
                    if (index == groups.length && widget.showAddButton) {
                      return _buildCreateGroupButton(context);
                    }

                    final group = groups[index].data() as Map<String, dynamic>;
                    return _buildGroupItem(context, group, groups[index].id);
                  },
                  childCount: groups.length + (widget.showAddButton ? 1 : 0),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGroupItem(BuildContext context, Map<String, dynamic> group, String groupId) {
    final videos = (group['videos'] as Map<String, dynamic>?) ?? {};
    final recipes = (group['recipes'] as Map<String, dynamic>?) ?? {};
    final totalItems = videos.length + recipes.length;

    return GestureDetector(
      onTap: () => _showGroupModal(context, group, groupId),
      child: Column(
        children: [
          Expanded(
            child: FractionallySizedBox(
              widthFactor: 0.5625,
              heightFactor: 0.5625,
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
          Text(
            '$totalItems items',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
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
              widthFactor: 0.5625,
              heightFactor: 0.5625,
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