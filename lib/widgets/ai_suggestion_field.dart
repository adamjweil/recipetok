import 'package:flutter/material.dart';

class AISuggestionField extends StatelessWidget {
  final Widget child;
  final double confidence;
  final VoidCallback? onReset;

  const AISuggestionField({
    super.key,
    required this.child,
    required this.confidence,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (confidence > 0)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getConfidenceColor(confidence),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: confidence > 0.7 ? Colors.white : Colors.black87,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${(confidence * 100).round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: confidence > 0.7 ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (onReset != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onReset,
                      child: Icon(
                        Icons.refresh,
                        size: 14,
                        color: confidence > 0.7 ? Colors.white : Colors.black87,
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