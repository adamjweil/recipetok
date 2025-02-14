export 'user_list_modal.dart';
export 'user_list_item.dart';
export 'user_list_item_skeleton.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_list_item.dart';
import 'user_list_item_skeleton.dart';

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
            child: userIds.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isFollowers ? Icons.people_outline : Icons.person_outline,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isFollowers ? 'No followers yet' : 'Not following anyone',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: userIds.length,
                    itemBuilder: (context, index) {
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(userIds[index])
                            .get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return const UserListItemSkeleton();
                          }

                          final userData = snapshot.data!.data();
                          if (userData == null) {
                            return const SizedBox.shrink(); // Or some error state widget
                          }

                          return UserListItem(
                            userData: userData as Map<String, dynamic>,
                            userId: userIds[index],
                            isFollowers: isFollowers,
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