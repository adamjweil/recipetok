import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/meal_post/meal_post_wrapper.dart';
import '../models/meal_post.dart';

class MealPostScreen extends StatelessWidget {
  final String mealId;

  const MealPostScreen({
    super.key,
    required this.mealId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Details'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('meal_posts')
            .doc(mealId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('Recipe not found'),
            );
          }

          final postData = snapshot.data!.data() as Map<String, dynamic>;
          final post = MealPost.fromMap(postData, mealId);

          return SingleChildScrollView(
            child: MealPostWrapper(
              post: post,
              showUserInfo: true,
            ),
          );
        },
      ),
    );
  }
} 