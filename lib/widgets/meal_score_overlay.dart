import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MealScoreOverlay extends StatelessWidget {
  final double score;
  final double size;
  final bool showLabel;

  const MealScoreOverlay({
    super.key,
    required this.score,
    this.size = 60.0,
    this.showLabel = true,
  });

  Color _getScoreColor(double score) {
    if (score >= 8) return Colors.green;
    if (score >= 6) return Colors.blue;
    if (score >= 4) return Colors.orange;
    return Colors.red;
  }

  String _getScoreLabel(double score) {
    if (score >= 8) return '🌟';
    if (score >= 6) return '👍';
    if (score >= 4) return '😊';
    return '🤔';
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _getScoreColor(score);
    final scoreLabel = _getScoreLabel(score);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.7),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: SizedBox(
              width: size * 0.8,
              height: size * 0.8,
              child: CircularProgressIndicator(
                value: score / 10,
                strokeWidth: 3,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  score.toStringAsFixed(1),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.25,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                if (showLabel) ...[
                  const SizedBox(height: 2),
                  Text(
                    scoreLabel,
                    style: TextStyle(
                      fontSize: size * 0.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate()
      .scale(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
      )
      .fadeIn();
  }
} 