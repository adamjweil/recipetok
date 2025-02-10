import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../screens/profile_screen.dart';

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

    try {
      final batch = FirebaseFirestore.instance.batch();
      final currentUserRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
      final otherUserRef = FirebaseFirestore.instance.collection('users').doc(userId);

      final currentUserDoc = await currentUserRef.get();
      final following = (currentUserDoc.data()?['following'] as List<dynamic>?) ?? [];
      final isFollowing = following.contains(userId);

      if (isFollowing) {
        batch.update(currentUserRef, {
          'following': FieldValue.arrayRemove([userId])
        });
        batch.update(otherUserRef, {
          'followers': FieldValue.arrayRemove([currentUser.uid])
        });
      } else {
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

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isCurrentUser = currentUserId == userId;

    return ListTile(
      onTap: () {
        Navigator.pop(context);
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
} 