import 'package:flutter/material.dart';

class StepProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final Function(int) onStepTapped;

  const StepProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.onStepTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalSteps, (index) {
          final isActive = index <= currentStep;
          final isCurrentStep = index == currentStep;

          return Expanded(
            child: GestureDetector(
              onTap: () => onStepTapped(index),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isActive
                            ? Theme.of(context).primaryColor
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getStepTitle(index),
                      style: TextStyle(
                        fontSize: 12,
                        color: isCurrentStep
                            ? Theme.of(context).primaryColor
                            : Colors.grey[600],
                        fontWeight:
                            isCurrentStep ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Photos';
      case 1:
        return 'Type';
      case 2:
        return 'Details';
      case 3:
        return 'Options';
      default:
        return '';
    }
  }
} 