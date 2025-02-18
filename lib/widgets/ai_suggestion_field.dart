import 'package:flutter/material.dart';

class AISuggestionField extends StatelessWidget {
  final Widget child;
  final double confidence;
  final VoidCallback? onReset;
  final bool isPunGenerator;
  final VoidCallback? onGeneratePun;

  const AISuggestionField({
    super.key,
    required this.child,
    required this.confidence,
    this.onReset,
    this.isPunGenerator = false,
    this.onGeneratePun,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (confidence > 0 || isPunGenerator)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPunGenerator ? Colors.purple.withOpacity(0.9) : _getConfidenceColor(confidence),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPunGenerator ? Icons.auto_fix_high : Icons.auto_awesome,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  if (!isPunGenerator) Text(
                    '${(confidence * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (isPunGenerator || onReset != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: isPunGenerator ? onGeneratePun : onReset,
                      child: Icon(
                        isPunGenerator ? Icons.casino : Icons.refresh,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.9) return Colors.green;
    if (confidence >= 0.7) return Colors.blue;
    if (confidence >= 0.5) return Colors.orange;
    return Colors.grey;
  }
} 