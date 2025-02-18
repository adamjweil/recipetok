import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/custom_cache_manager.dart';
import '../screens/video_player_screen.dart';
import '../widgets/edit_group_modal.dart';
import '../models/video.dart';
import '../models/recipe.dart';

class GroupDetailsModal extends StatefulWidget {
  final Map<String, dynamic> group;
  final String groupId;

  const GroupDetailsModal({
    super.key,
    required this.group,
    required this.groupId,
  });

  @override
  State<GroupDetailsModal> createState() => _GroupDetailsModalState();
}

class _GroupDetailsModalState extends State<GroupDetailsModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _removeVideo(BuildContext context, String videoId) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('groups')
          .doc(widget.groupId)
          .update({
        'videos.$videoId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video removed from collection')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing video: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _removeRecipe(BuildContext context, String recipeId) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('groups')
          .doc(widget.groupId)
          .update({
        'recipes.$recipeId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe removed from collection')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing recipe: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.group['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.group['description'] != null)
                        Text(
                          widget.group['description'],
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
          // Tab Bar
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.video_library,
                      color: _currentIndex == 0
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Videos',
                      style: TextStyle(
                        color: _currentIndex == 0
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      color: _currentIndex == 1
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recipes',
                      style: TextStyle(
                        color: _currentIndex == 1
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Tab Bar View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVideosGrid(),
                _buildRecipesGrid(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideosGrid() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('groups')
          .doc(widget.groupId)
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
            : <String, dynamic>{};

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
                          video: Video.fromMap(
                            videoList[index].id,
                            videoData,
                          ),
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
    );
  }

  Widget _buildRecipesGrid() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('groups')
          .doc(widget.groupId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final groupData = snapshot.data?.data() as Map<String, dynamic>?;
        final recipes = (groupData?['recipes'] is Map)
            ? (groupData?['recipes'] as Map<String, dynamic>?) ?? {}
            : <String, dynamic>{};

        if (recipes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No recipes in this collection',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait(
            recipes.keys.map((recipeId) => FirebaseFirestore.instance
                .collection('recipes')
                .doc(recipeId)
                .get()),
          ),
          builder: (context, recipeSnapshot) {
            if (!recipeSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final recipeList = recipeSnapshot.data ?? [];

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: recipeList.length,
              itemBuilder: (context, index) {
                final recipeData =
                    recipeList[index].data() as Map<String, dynamic>?;
                if (recipeData == null) return const SizedBox();

                final recipe = Recipe.fromFirestore(recipeList[index]);

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Recipe Image or Placeholder
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: AspectRatio(
                          aspectRatio: 1.2,
                          child: recipe.imageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: recipe.imageUrl!,
                                  fit: BoxFit.cover,
                                  cacheManager: CustomCacheManager.instance,
                                )
                              : Container(
                                  color: Colors.grey[200],
                                  child: Icon(
                                    Icons.restaurant,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                ),
                        ),
                      ),
                      // Recipe Info
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                recipe.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                recipe.cuisine,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const Spacer(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${recipe.cookTimeMinutes}m',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.bookmark),
                                    onPressed: () => _removeRecipe(
                                      context,
                                      recipeList[index].id,
                                    ),
                                    color: Theme.of(context).primaryColor,
                                    iconSize: 20,
                                  ),
                                ],
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
                  groupId: widget.groupId,
                  group: widget.group,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete Collection',
                style: TextStyle(color: Colors.red)),
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
          'This action cannot be undone. Videos and recipes in this collection will not be deleted.',
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

  Future<void> _deleteGroup(BuildContext context) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('groups')
          .doc(widget.groupId)
          .delete();

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Collection deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting collection: ${e.toString()}')),
        );
      }
    }
  }
} 