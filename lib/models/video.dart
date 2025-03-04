import 'package:cloud_firestore/cloud_firestore.dart';

class Video {
  final String id;
  final String userId;
  final String username;
  final String userImage;
  final String videoUrl;
  final String thumbnailUrl;
  final String title;
  final String description;
  final List<String> ingredients;
  final List<String> instructions;
  final int likes;
  final List<String> likedBy;
  final int views;
  final int commentCount;
  final bool isPinned;
  final DateTime createdAt;

  Video({
    required this.id,
    required this.userId,
    required this.username,
    required this.userImage,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.title,
    required this.description,
    required this.ingredients,
    required this.instructions,
    required this.likes,
    required this.likedBy,
    required this.views,
    required this.commentCount,
    required this.isPinned,
    required this.createdAt,
  });

  factory Video.fromMap(String id, Map<String, dynamic> data) {
    // Helper function to safely convert to int
    int safeInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is List) return value.length;  // Handle case where value is a list
      return 0;
    }

    return Video(
      id: id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      userImage: data['userImage'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      ingredients: List<String>.from(data['ingredients'] ?? []),
      instructions: List<String>.from(data['instructions'] ?? []),
      likes: safeInt(data['likes']),
      likedBy: List<String>.from(data['likedBy'] ?? []),
      views: safeInt(data['views']),
      commentCount: safeInt(data['commentCount']),
      isPinned: data['isPinned'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'userImage': userImage,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'title': title,
      'description': description,
      'ingredients': ingredients,
      'instructions': instructions,
      'likes': likes,
      'likedBy': likedBy,
      'views': views,
      'commentCount': commentCount,
      'isPinned': isPinned,
      'createdAt': createdAt,
    };
  }
} 