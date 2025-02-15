import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_firestore/firebase_firestore.dart';
import 'package:custom_cache_manager/custom_cache_manager.dart';

class MealPostWrapper extends StatefulWidget {
  // ... (existing code)
  @override
  _MealPostWrapperState createState() => _MealPostWrapperState();
}

class _MealPostWrapperState extends State<MealPostWrapper> {
  // ... (existing code)

  static final Map<String, Map<String, dynamic>> _globalUserCache = {};

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    if (_globalUserCache.containsKey(userId)) {
      return _globalUserCache[userId];
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      final data = doc.data();
      if (data != null) {
        _globalUserCache[userId] = data;
      }
      return data;
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      return null;
    }
  }

  Future<void> _prefetchUserData(List<String> userIds) async {
    final uncachedIds = userIds.where((id) => !_globalUserCache.containsKey(id)).toList();
    
    if (uncachedIds.isEmpty) return;

    try {
      final snapshots = await Future.wait(
        uncachedIds.map((id) => 
          FirebaseFirestore.instance.collection('users').doc(id).get()
        )
      );

      for (final doc in snapshots) {
        if (doc.exists && doc.data() != null) {
          _globalUserCache[doc.id] = doc.data()!;
        }
      }
    } catch (e) {
      debugPrint('Error batch fetching user data: $e');
    }
  }

  Widget _buildLikedByAvatars(List<String> likedBy) {
    if (likedBy.isEmpty) return const SizedBox();

    _prefetchUserData(likedBy);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 60),
      child: SizedBox(
        width: likedBy.take(3).length * 20.0 - (likedBy.take(3).length - 1) * 12.0,
        height: 24,
        child: Stack(
          children: likedBy.take(3).map((userId) {
            final index = likedBy.indexOf(userId);
            return Positioned(
              left: index * 12.0,
              child: FutureBuilder<Map<String, dynamic>?>(
                future: _getUserData(userId),
                builder: (context, snapshot) {
                  final userData = snapshot.data;
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: (userData?['avatarUrl'] != null && 
                          userData!['avatarUrl'].toString().isNotEmpty &&
                          CustomCacheManager.isValidImageUrl(userData['avatarUrl']))
                          ? CachedNetworkImageProvider(userData['avatarUrl'])
                          : null,
                      child: (userData?['avatarUrl'] == null || 
                          userData!['avatarUrl'].toString().isEmpty ||
                          !CustomCacheManager.isValidImageUrl(userData['avatarUrl']))
                          ? Icon(Icons.person, size: 11, color: Colors.grey[400])
                          : null,
                    ),
                  );
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... (rest of the existing code)
  }
} 