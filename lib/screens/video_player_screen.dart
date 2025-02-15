import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/video_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/video.dart';

class VideoPlayerScreen extends StatelessWidget {
  final Video video;

  const VideoPlayerScreen({
    super.key,
    required this.video,
  });

  Future<void> _incrementViewCount() async {
    try {
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(video.id)
          .update({
        'views': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing view count: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: VideoCard(
        video: video,
        autoplay: true,
      ),
    );
  }
} 