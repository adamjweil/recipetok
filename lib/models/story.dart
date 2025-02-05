import 'package:cloud_firestore/cloud_firestore.dart';

class Story {
  final String id;
  final String userId;
  final String mediaUrl;
  final String mediaType; // 'image' or 'video'
  final String thumbnailUrl; // for videos
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isActive;
  final List<String> viewedBy;
  final int extensionCount;

  Story({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    required this.mediaType,
    this.thumbnailUrl = '',
    required this.createdAt,
    required this.expiresAt,
    this.isActive = true,
    this.viewedBy = const [],
    this.extensionCount = 0,
  });

  factory Story.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Story(
      id: doc.id,
      userId: data['userId'] ?? '',
      mediaUrl: data['mediaUrl'] ?? '',
      mediaType: data['mediaType'] ?? 'image',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      viewedBy: List<String>.from(data['viewedBy'] ?? []),
      extensionCount: data['extensionCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'thumbnailUrl': thumbnailUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isActive': isActive,
      'viewedBy': viewedBy,
      'extensionCount': extensionCount,
    };
  }
} 