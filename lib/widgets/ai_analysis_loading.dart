import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AIAnalysisLoading extends StatelessWidget {
  const AIAnalysisLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Analyzing your food...',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Our AI chef is cooking up some suggestions',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              _buildLoadingStep(
                icon: Icons.restaurant_menu,
                text: 'Identifying ingredients',
                delay: 0,
              ),
              _buildLoadingStep(
                icon: Icons.title,
                text: 'Crafting the perfect title',
                delay: 400,
              ),
              _buildLoadingStep(
                icon: Icons.description,
                text: 'Writing a witty description',
                delay: 800,
              ),
              _buildLoadingStep(
                icon: Icons.timer,
                text: 'Estimating preparation time',
                delay: 1200,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingStep({
    required IconData icon,
    required String text,
    required int delay,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.grey)
              .animate(delay: Duration(milliseconds: delay))
              .fadeIn()
              .scale(),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: Colors.grey),
          ).animate(delay: Duration(milliseconds: delay))
              .fadeIn()
              .slideX(),
        ],
      ),
    );
  }
} 