import 'package:flutter/material.dart';

class MealScore {
  final double overallScore;
  final double presentationScore;
  final double photoQualityScore;
  final double nutritionScore;
  final double creativityScore;
  final double technicalScore;
  final String aiCritique;
  final List<String> strengths;
  final List<String> improvements;

  const MealScore({
    required this.overallScore,
    required this.presentationScore,
    required this.photoQualityScore,
    required this.nutritionScore,
    required this.creativityScore,
    required this.technicalScore,
    required this.aiCritique,
    required this.strengths,
    required this.improvements,
  });

  factory MealScore.fromMap(Map<String, dynamic> map) {
    return MealScore(
      overallScore: (map['overallScore'] ?? 0.0).toDouble(),
      presentationScore: (map['presentationScore'] ?? 0.0).toDouble(),
      photoQualityScore: (map['photoQualityScore'] ?? 0.0).toDouble(),
      nutritionScore: (map['nutritionScore'] ?? 0.0).toDouble(),
      creativityScore: (map['creativityScore'] ?? 0.0).toDouble(),
      technicalScore: (map['technicalScore'] ?? 0.0).toDouble(),
      aiCritique: map['aiCritique'] ?? '',
      strengths: List<String>.from(map['strengths'] ?? []),
      improvements: List<String>.from(map['improvements'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'overallScore': overallScore,
      'presentationScore': presentationScore,
      'photoQualityScore': photoQualityScore,
      'nutritionScore': nutritionScore,
      'creativityScore': creativityScore,
      'technicalScore': technicalScore,
      'aiCritique': aiCritique,
      'strengths': strengths,
      'improvements': improvements,
    };
  }

  String getScoreDescription(double score) {
    if (score >= 9.0) return 'Exceptional';
    if (score >= 8.0) return 'Excellent';
    if (score >= 7.0) return 'Very Good';
    if (score >= 6.0) return 'Good';
    if (score >= 5.0) return 'Average';
    if (score >= 4.0) return 'Fair';
    if (score >= 3.0) return 'Poor';
    return 'Needs Improvement';
  }

  Color getScoreColor(double score) {
    if (score >= 9.0) return Colors.purple;
    if (score >= 8.0) return Colors.blue;
    if (score >= 7.0) return Colors.green;
    if (score >= 6.0) return Colors.lightGreen;
    if (score >= 5.0) return Colors.yellow;
    if (score >= 4.0) return Colors.orange;
    return Colors.red;
  }
} 