import 'package:cloud_firestore/cloud_firestore.dart';

class VideoDraft {
  final String? id;
  final String userId;
  final String? videoPath;
  final String? videoUrl;
  final String? title;
  final String? description;
  final List<String> ingredients;
  final List<String> instructions;
  final int? calories;
  final int? cookTimeMinutes;
  final DateTime? createdAt;
  final DateTime? lastModified;
  final bool isProcessed;
  final Map<String, dynamic>? aiGeneratedData;
  
  VideoDraft({
    this.id,
    required this.userId,
    this.videoPath,
    this.videoUrl,
    this.title,
    this.description,
    this.ingredients = const [],
    this.instructions = const [],
    this.calories,
    this.cookTimeMinutes,
    this.createdAt,
    this.lastModified,
    this.isProcessed = false,
    this.aiGeneratedData,
  });

  factory VideoDraft.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VideoDraft(
      id: doc.id,
      userId: data['userId'],
      videoPath: data['videoPath'],
      videoUrl: data['videoUrl'],
      title: data['title'],
      description: data['description'],
      ingredients: List<String>.from(data['ingredients'] ?? []),
      instructions: List<String>.from(data['instructions'] ?? []),
      calories: data['calories'],
      cookTimeMinutes: data['cookTimeMinutes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastModified: (data['lastModified'] as Timestamp?)?.toDate(),
      isProcessed: data['isProcessed'] ?? false,
      aiGeneratedData: data['aiGeneratedData'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'videoPath': videoPath,
      'videoUrl': videoUrl,
      'title': title,
      'description': description,
      'ingredients': ingredients,
      'instructions': instructions,
      'calories': calories,
      'cookTimeMinutes': cookTimeMinutes,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'lastModified': FieldValue.serverTimestamp(),
      'isProcessed': isProcessed,
      'aiGeneratedData': aiGeneratedData,
    };
  }

  VideoDraft copyWith({
    String? id,
    String? userId,
    String? videoPath,
    String? videoUrl,
    String? title,
    String? description,
    List<String>? ingredients,
    List<String>? instructions,
    int? calories,
    int? cookTimeMinutes,
    DateTime? createdAt,
    DateTime? lastModified,
    bool? isProcessed,
    Map<String, dynamic>? aiGeneratedData,
  }) {
    return VideoDraft(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      videoPath: videoPath ?? this.videoPath,
      videoUrl: videoUrl ?? this.videoUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      calories: calories ?? this.calories,
      cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
      isProcessed: isProcessed ?? this.isProcessed,
      aiGeneratedData: aiGeneratedData ?? this.aiGeneratedData,
    );
  }
} 