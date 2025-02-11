import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  image,
  postLike,  // New type for like notifications
}

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String? text;
  final String? imageUrl;
  final DateTime timestamp;
  final MessageType type;
  // New fields for post like messages
  final String? postId;
  final String? postThumbnailUrl;
  final String? postTitle;
  final String? postDescription;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.text,
    this.imageUrl,
    required this.timestamp,
    required this.type,
    this.postId,
    this.postThumbnailUrl,
    this.postTitle,
    this.postDescription,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': timestamp,
      'type': type.toString(),
      'postId': postId,
      'postThumbnailUrl': postThumbnailUrl,
      'postTitle': postTitle,
      'postDescription': postDescription,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map, String id) {
    return ChatMessage(
      id: id,
      senderId: map['senderId'] as String? ?? '',
      receiverId: map['receiverId'] as String? ?? '',
      text: map['text'] as String?,
      imageUrl: map['imageUrl'] as String?,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: MessageType.values.firstWhere(
        (e) => e.toString() == (map['type'] as String? ?? 'MessageType.text'),
        orElse: () => MessageType.text,
      ),
      postId: map['postId'] as String?,
      postThumbnailUrl: map['postThumbnailUrl'] as String?,
      postTitle: map['postTitle'] as String?,
      postDescription: map['postDescription'] as String?,
    );
  }
} 