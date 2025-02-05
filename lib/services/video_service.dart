import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../utils/custom_cache_manager.dart';

class Video {
  final String id;
  final String thumbnailUrl;
  final String videoUrl;
  final int views;
  final String userId;

  Video({
    required this.id,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.views,
    required this.userId,
  });

  // Add factory constructor to create Video from Firestore document
  factory Video.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Video(
      id: doc.id,
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      views: data['views'] ?? 0,
      userId: data['userId'] ?? '',
    );
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