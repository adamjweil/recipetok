import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/video_card.dart';  // We'll need to create this too

class VideoPlayerScreen extends StatelessWidget {
  final Map<String, dynamic> videoData;
  final String videoId;

  const VideoPlayerScreen({
    super.key,
    required this.videoData,
    required this.videoId,
  });

  Future<void> _incrementViewCount() async {
    try {
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
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
        videoData: videoData,
        videoId: videoId,
        onUserTap: () {},
        onVideoPlay: _incrementViewCount,
      ),
    );
  }
} 