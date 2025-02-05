import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String username;
  final String profileImageUrl;
  final int followers;
  final int videoCount;
  final String bio;

  User({
    required this.id,
    required this.username,
    required this.profileImageUrl,
    required this.followers,
    required this.videoCount,
    required this.bio,
  });

  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Helper function to safely convert to int
    int toInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is double) return value.toInt();
      if (value is List) return value.length;
      return 0;
    }

    // Helper function to validate URL
    String validateUrl(dynamic value) {
      if (value == null || value.toString().isEmpty || value.toString() == 'null') {
        return '';
      }
      final url = value.toString();
      // Basic URL validation
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return url;
      }
      return '';
    }

    return User(
      id: doc.id,
      username: data['username']?.toString() ?? '',
      profileImageUrl: validateUrl(data['profileImageUrl']),
      followers: toInt(data['followers']),
      videoCount: toInt(data['videoCount']),
      bio: data['bio']?.toString() ?? '',
    );
  }
}

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<User>> getMostFollowedUsers() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .orderBy('followers', descending: true)
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => User.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching most followed users: $e');
      return [];
    }
  }
} 