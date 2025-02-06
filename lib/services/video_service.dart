import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../utils/custom_cache_manager.dart';

class Video {
  final String id;
  final String videoUrl;
  final String thumbnailUrl;
  final String title;
  final int views;
  final String userId;
  final DateTime createdAt;

  Video({
    required this.id,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.title,
    required this.views,
    required this.userId,
    required this.createdAt,
  });

  // Add factory constructor to create Video from Firestore document
  factory Video.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Video(
      id: doc.id,
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      title: data['title'] ?? 'Untitled',
      views: data['views'] ?? 0,
      userId: data['userId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'title': title,
      'views': views,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class VideoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Video>> getMostViewedVideos() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('videos')
          .orderBy('views', descending: true)
          .limit(15)
          .get();

      return snapshot.docs
          .map((doc) => Video.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching most viewed videos: $e');
      return [];
    }
  }
} 