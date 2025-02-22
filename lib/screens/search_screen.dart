import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/profile_screen.dart';
import 'dart:async';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _updateExistingUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _updateExistingUsers() async {
    try {
      final QuerySnapshot users = await FirebaseFirestore.instance
          .collection('users')
          .get();

      for (var doc in users.docs) {
        final userData = doc.data() as Map<String, dynamic>;
        final firstName = (userData['firstName'] ?? '').toString().toLowerCase();
        final lastName = (userData['lastName'] ?? '').toString().toLowerCase();
        final username = (userData['username'] ?? '').toString().toLowerCase();

        // Create searchName field that combines all searchable fields
        final searchName = '$firstName $lastName $username'.trim();

        // Only update if searchName field is different or doesn't exist
        if (userData['searchName'] != searchName) {
          await doc.reference.update({
            'searchName': searchName,
          });
        }
      }
    } catch (e) {
      print('Error updating users with search fields: $e');
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Search by first name, last name, or username
      final queryLower = query.toLowerCase();
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('searchName', isGreaterThanOrEqualTo: queryLower)
          .where('searchName', isLessThan: '${queryLower}z')
          .limit(20)
          .get();

      setState(() {
        _searchResults = querySnapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error searching users: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    // Debounce the search to avoid too many Firestore queries
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchUsers(query);
    });
  }

  Future<void> _toggleFollow(String userId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);
    final targetUserRef = FirebaseFirestore.instance.collection('users').doc(userId);

    final userDoc = await userRef.get();
    final List following = userDoc.data()?['following'] ?? [];

    if (following.contains(userId)) {
      // Unfollow
      await userRef.update({
        'following': FieldValue.arrayRemove([userId])
      });
      await targetUserRef.update({
        'followers': FieldValue.arrayRemove([currentUserId])
      });
    } else {
      // Follow
      await userRef.update({
        'following': FieldValue.arrayUnion([userId])
      });
      await targetUserRef.update({
        'followers': FieldValue.arrayUnion([currentUserId])
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search users...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey[400]),
          ),
          style: const TextStyle(color: Colors.black),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _searchResults.isEmpty && _searchController.text.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final userData = _searchResults[index].data() as Map<String, dynamic>;
                    final userId = _searchResults[index].id;
                    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                    final List followers = userData['followers'] ?? [];
                    final bool isFollowing = followers.contains(currentUserId);
                    final bool isCurrentUser = userId == currentUserId;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        backgroundImage: userData['avatarUrl'] != null && 
                                       userData['avatarUrl'].toString().isNotEmpty && 
                                       Uri.tryParse(userData['avatarUrl'])?.hasScheme == true
                            ? CachedNetworkImageProvider(userData['avatarUrl'])
                            : null,
                        child: userData['avatarUrl'] == null || 
                               userData['avatarUrl'].toString().isEmpty ||
                               Uri.tryParse(userData['avatarUrl'])?.hasScheme != true
                            ? Icon(Icons.person, color: Colors.grey[600])
                            : null,
                      ),
                      title: Text(
                        '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(userData['username'] ?? ''),
                      trailing: !isCurrentUser
                          ? TextButton(
                              onPressed: () => _toggleFollow(userId),
                              style: TextButton.styleFrom(
                                backgroundColor: isFollowing ? Colors.grey[100] : Theme.of(context).primaryColor,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                isFollowing ? 'Following' : 'Follow',
                                style: TextStyle(
                                  color: isFollowing ? Colors.black : Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileScreen(
                              userId: userId,
                              showBackButton: true,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
} 