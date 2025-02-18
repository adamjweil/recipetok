import 'package:cloud_firestore/cloud_firestore.dart';

class Recipe {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String? imageUrl;
  final List<String> ingredients;
  final List<String> instructions;
  final String cuisine;
  final int servings;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final DateTime createdAt;
  final bool isSaved;

  Recipe({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.ingredients,
    required this.instructions,
    required this.cuisine,
    required this.servings,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.createdAt,
    this.isSaved = false,
  });

  factory Recipe.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Recipe(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'],
      ingredients: List<String>.from(data['ingredients'] ?? []),
      instructions: List<String>.from(data['instructions'] ?? []),
      cuisine: data['cuisine'] ?? '',
      servings: data['servings']?.toInt() ?? 4,
      prepTimeMinutes: data['prepTimeMinutes']?.toInt() ?? 0,
      cookTimeMinutes: data['cookTimeMinutes']?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isSaved: data['isSaved'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'ingredients': ingredients,
      'instructions': instructions,
      'cuisine': cuisine,
      'servings': servings,
      'prepTimeMinutes': prepTimeMinutes,
      'cookTimeMinutes': cookTimeMinutes,
      'createdAt': Timestamp.fromDate(createdAt),
      'isSaved': isSaved,
    };
  }

  Recipe copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? imageUrl,
    List<String>? ingredients,
    List<String>? instructions,
    String? cuisine,
    int? servings,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    DateTime? createdAt,
    bool? isSaved,
  }) {
    return Recipe(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      cuisine: cuisine ?? this.cuisine,
      servings: servings ?? this.servings,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
      createdAt: createdAt ?? this.createdAt,
      isSaved: isSaved ?? this.isSaved,
    );
  }
} 