import 'package:flutter/material.dart';
import '../../models/meal_post.dart';
import 'expandable_meal_post.dart';

class MealPostWrapper extends StatefulWidget {
  final MealPost post;

  const MealPostWrapper({
    super.key,
    required this.post,
  });

  @override
  State<MealPostWrapper> createState() => _MealPostWrapperState();
}

class _MealPostWrapperState extends State<MealPostWrapper> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return ExpandableMealPost(
      post: widget.post,
      isExpanded: _isExpanded,
      onToggle: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
    );
  }
} 