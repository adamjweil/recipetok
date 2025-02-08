import 'package:cloud_firestore/cloud_firestore.dart';

enum MealType {
  breakfast,
  lunch,
  dinner,
  snack
}

class MealPost {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final List<String> photoUrls;
  final String? ingredients;
  final String? instructions;
  final MealType mealType;
  final bool isPublic;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final List<String> likedBy;

  MealPost({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.photoUrls,
    this.ingredients,
    this.instructions,
    required this.mealType,
    required this.isPublic,
    required this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.likedBy = const [],
  });

  factory MealPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MealPost(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      ingredients: data['ingredients'],
      instructions: data['instructions'],
      mealType: MealType.values.firstWhere(
        (e) => e.toString() == data['mealType'],
        orElse: () => MealType.snack,
      ),
      isPublic: data['isPublic'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      likesCount: data['likesCount'] ?? 0,
      commentsCount: data['commentsCount'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'photoUrls': photoUrls,
      'ingredients': ingredients,
      'instructions': instructions,
      'mealType': mealType.toString(),
      'isPublic': isPublic,
      'createdAt': Timestamp.fromDate(createdAt),
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'likedBy': likedBy,
    };
  }
} 