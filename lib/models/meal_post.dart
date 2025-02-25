import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/custom_cache_manager.dart';

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

extension MealTypeExtension on MealType {
  String toUpperCase() {
    return toString().split('.').last.toUpperCase();
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
  final DateTime createdAt;
  final int likes;
  final int comments;
  final List<String> likedBy;
  final bool isVegetarian;
  final String? ingredients;
  final String? instructions;
  final int cookTime;
  final int calories;
  final int protein;
  final MealType mealType;
  final double mealScore;
  final double carbonSaved;
  final bool isLiked;
  final bool isPublic;
  final int likesCount;
  final int commentsCount;

  const MealPost({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    this.imageUrl,
    this.caption,
    required this.title,
    this.description,
    required this.photoUrls,
    required this.createdAt,
    required this.likes,
    required this.comments,
    required this.likedBy,
    required this.isVegetarian,
    this.ingredients,
    this.instructions,
    required this.cookTime,
    required this.calories,
    required this.protein,
    required this.mealType,
    required this.mealScore,
    required this.carbonSaved,
    required this.isLiked,
    required this.isPublic,
    required this.likesCount,
    required this.commentsCount,
  });

  factory MealPost.fromMap(Map<String, dynamic> map, String id) {
    List<String> photoUrls = [];
    if (map['photoUrls'] != null) {
      photoUrls = (map['photoUrls'] as List)
          .map((url) => url.toString())
          .where((url) => CustomCacheManager.isValidImageUrl(url))
          .toList();
    }

    return MealPost(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userAvatarUrl: map['userAvatarUrl'],
      imageUrl: map['imageUrl'],
      caption: map['caption'],
      title: map['title'] ?? '',
      description: map['description'],
      photoUrls: photoUrls,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      likes: map['likes']?.toInt() ?? 0,
      comments: map['comments']?.toInt() ?? 0,
      likedBy: List<String>.from(map['likedBy'] ?? []),
      isVegetarian: map['isVegetarian'] ?? false,
      ingredients: map['ingredients'],
      instructions: map['instructions'],
      cookTime: map['cookTime']?.toInt() ?? 0,
      calories: map['calories']?.toInt() ?? 0,
      protein: map['protein']?.toInt() ?? 0,
      mealType: _parseMealType(map['mealType'] ?? 'breakfast'),
      mealScore: (map['mealScore'] ?? 0.0).toDouble(),
      carbonSaved: (map['carbonSaved'] ?? 0.0).toDouble(),
      isLiked: map['isLiked'] ?? false,
      isPublic: map['isPublic'] ?? true,
      likesCount: map['likesCount']?.toInt() ?? 0,
      commentsCount: map['commentsCount']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userAvatarUrl': userAvatarUrl,
      'imageUrl': imageUrl,
      'caption': caption,
      'title': title,
      'description': description,
      'photoUrls': photoUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
      'comments': comments,
      'likedBy': likedBy,
      'isVegetarian': isVegetarian,
      'ingredients': ingredients,
      'instructions': instructions,
      'cookTime': cookTime,
      'calories': calories,
      'protein': protein,
      'mealType': mealType.toString().split('.').last,
      'mealScore': mealScore,
      'carbonSaved': carbonSaved,
      'isLiked': isLiked,
      'isPublic': isPublic,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
    };
  }

  static MealType _parseMealType(String type) {
    switch (type.toLowerCase()) {
      case 'breakfast':
        return MealType.breakfast;
      case 'lunch':
        return MealType.lunch;
      case 'dinner':
        return MealType.dinner;
      case 'snack':
        return MealType.snack;
      default:
        return MealType.breakfast;
    }
  }

  MealPost copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatarUrl,
    String? imageUrl,
    String? caption,
    String? title,
    String? description,
    List<String>? photoUrls,
    DateTime? createdAt,
    int? likes,
    int? comments,
    List<String>? likedBy,
    bool? isVegetarian,
    String? ingredients,
    String? instructions,
    int? cookTime,
    int? calories,
    int? protein,
    MealType? mealType,
    double? mealScore,
    double? carbonSaved,
    bool? isLiked,
    bool? isPublic,
    int? likesCount,
    int? commentsCount,
  }) {
    return MealPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      caption: caption ?? this.caption,
      title: title ?? this.title,
      description: description ?? this.description,
      photoUrls: photoUrls ?? this.photoUrls,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      likedBy: likedBy ?? this.likedBy,
      isVegetarian: isVegetarian ?? this.isVegetarian,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      cookTime: cookTime ?? this.cookTime,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      mealType: mealType ?? this.mealType,
      mealScore: mealScore ?? this.mealScore,
      carbonSaved: carbonSaved ?? this.carbonSaved,
      isLiked: isLiked ?? this.isLiked,
      isPublic: isPublic ?? this.isPublic,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
    );
  }

  factory MealPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MealPost.fromMap(data, doc.id);
  }

  Map<String, dynamic> toFirestore() {
    return toMap();
  }
} 