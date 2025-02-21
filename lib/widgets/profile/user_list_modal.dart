export 'user_list_modal.dart';
export 'user_list_item.dart';
export 'user_list_item_skeleton.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_list_item.dart';
import 'user_list_item_skeleton.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../screens/profile_screen.dart';

class UserListModal extends StatelessWidget {
  final String title;
  final List<String> userIds;
  final bool isFollowers;

  const UserListModal({
    super.key,
    required this.title,
    required this.userIds,
    required this.isFollowers,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<DocumentSnapshot>>(
              stream: _getValidUsers(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final validUsers = snapshot.data!;
                
                if (validUsers.isEmpty) {
                  return Center(
                    child: Text(
                      isFollowers ? 'No followers yet' : 'Not following anyone',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: validUsers.length,
                  itemBuilder: (context, index) {
                    final userData = validUsers[index].data() as Map<String, dynamic>;
                    final userId = validUsers[index].id;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        backgroundImage: userData['avatarUrl'] != null && userData['avatarUrl'].toString().isNotEmpty
                            ? CachedNetworkImageProvider(userData['avatarUrl'])
                            : null,
                        child: userData['avatarUrl'] == null || userData['avatarUrl'].toString().isEmpty
                            ? const Icon(Icons.person, color: Colors.grey)
                            : null,
                      ),
                      title: Text(
                        '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(userData['displayName'] ?? ''),
                      onTap: () {
                        Navigator.pop(context); // Close modal
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileScreen(userId: userId),
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

  Stream<List<DocumentSnapshot>> _getValidUsers() {
    return FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: userIds)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }
} 