import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum MealType {
  breakfast,
  lunch,
  dinner,
  snack;

  IconData get icon {
    switch (this) {
      case MealType.breakfast:
        return Icons.breakfast_dining;
      case MealType.lunch:
        return Icons.lunch_dining;
      case MealType.dinner:
        return Icons.dinner_dining;
      case MealType.snack:
        return Icons.restaurant_menu;
    }
  }
}

class MealPost {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String? imageUrl;
  final String? caption;
  final String title;
  final String? description;
  final List<String> photoUrls;
  final String? ingredients;
  final String? instructions;
  final MealType mealType;
  final int cookTime;
  final int calories;
  final int protein;
  final bool isVegetarian;
  final double carbonSaved;
  final int likes;
  final int comments;
  final bool isLiked;
  final bool isPublic;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final List<String> likedBy;

  MealPost({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    this.imageUrl,
    this.caption,
    required this.title,
    this.description,
    required this.photoUrls,
    this.ingredients,
    this.instructions,
    required this.mealType,
    required this.cookTime,
    required this.calories,
    required this.protein,
    required this.isVegetarian,
    required this.carbonSaved,
    required this.likes,
    required this.comments,
    required this.isLiked,
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
      userName: data['userName'] ?? '',
      userAvatarUrl: data['userAvatarUrl'],
      imageUrl: data['imageUrl'],
      caption: data['caption'],
      title: data['title'] ?? '',
      description: data['description'],
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      ingredients: data['ingredients'],
      instructions: data['instructions'],
      mealType: MealType.values.firstWhere(
        (e) => e.toString() == data['mealType'],
        orElse: () => MealType.snack,
      ),
      cookTime: data['cookTime']?.toInt() ?? 0,
      calories: data['calories']?.toInt() ?? 0,
      protein: data['protein']?.toInt() ?? 0,
      isVegetarian: data['isVegetarian'] ?? false,
      carbonSaved: (data['carbonSaved'] ?? 0).toDouble(),
      likes: data['likes']?.toInt() ?? 0,
      comments: data['comments']?.toInt() ?? 0,
      isLiked: data['isLiked'] ?? false,
      isPublic: data['isPublic'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      likesCount: data['likesCount']?.toInt() ?? 0,
      commentsCount: data['commentsCount']?.toInt() ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userAvatarUrl': userAvatarUrl,
      'imageUrl': imageUrl,
      'caption': caption,
      'title': title,
      'description': description,
      'photoUrls': photoUrls,
      'ingredients': ingredients,
      'instructions': instructions,
      'mealType': mealType.toString(),
      'cookTime': cookTime,
      'calories': calories,
      'protein': protein,
      'isVegetarian': isVegetarian,
      'carbonSaved': carbonSaved,
      'likes': likes,
      'comments': comments,
      'isLiked': isLiked,
      'isPublic': isPublic,
      'createdAt': Timestamp.fromDate(createdAt),
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'likedBy': likedBy,
    };
  }
} 