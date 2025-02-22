import 'package:flutter/material.dart';
import '../models/meal_score.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MealScoreScreen extends StatelessWidget {
  final MealScore mealScore;
  final String imageUrl;

  const MealScoreScreen({
    super.key,
    required this.mealScore,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(
                'Meal Score: ${mealScore.overallScore.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOverallScore(),
                  const SizedBox(height: 24),
                  _buildScoreBreakdown(),
                  const SizedBox(height: 24),
                  _buildAICritique(),
                  const SizedBox(height: 24),
                  _buildStrengthsAndImprovements(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallScore() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: mealScore.getScoreColor(mealScore.overallScore).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: mealScore.getScoreColor(mealScore.overallScore).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: mealScore.getScoreColor(mealScore.overallScore),
              shape: BoxShape.circle,
            ),
            child: Text(
              mealScore.overallScore.toStringAsFixed(1),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ).animate().scale(delay: 300.ms),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mealScore.getScoreDescription(mealScore.overallScore),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: mealScore.getScoreColor(mealScore.overallScore),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Overall Score',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX();
  }

  Widget _buildScoreBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Score Breakdown',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildScoreItem('Presentation', mealScore.presentationScore, 0),
        _buildScoreItem('Photo Quality', mealScore.photoQualityScore, 100),
        _buildScoreItem('Nutrition', mealScore.nutritionScore, 200),
        _buildScoreItem('Creativity', mealScore.creativityScore, 300),
        _buildScoreItem('Technical Execution', mealScore.technicalScore, 400),
      ],
    );
  }

  Widget _buildScoreItem(String label, double score, int delay) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                score.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: mealScore.getScoreColor(score),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                height: 4,
                width: (score / 10) * 100,
                decoration: BoxDecoration(
                  color: mealScore.getScoreColor(score),
                  borderRadius: BorderRadius.circular(2),
                ),
              ).animate().slideX(delay: delay.ms, duration: 600.ms),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAICritique() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chef\'s Critique',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            mealScore.aiCritique,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildStrengthsAndImprovements() {
    return Row(
      children: [
        Expanded(
          child: _buildList(
            'Strengths',
            mealScore.strengths,
            Icons.star,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildList(
            'Areas for Improvement',
            mealScore.improvements,
            Icons.trending_up,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildList(String title, List<String> items, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle, color: color, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2);
  }
} 