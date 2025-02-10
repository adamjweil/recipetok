import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_compress/video_compress.dart';
import 'package:image/image.dart' as img;
import '../models/story.dart';

class StoryService {
  final _storage = FirebaseStorage.instance;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<Story> uploadStory(File file, String mediaType) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    try {
      // Compress and process media
      String mediaUrl;
      String thumbnailUrl = '';
      
      if (mediaType == 'video') {
        print('Attempting to upload video story for user: $userId'); // Debug log
        try {
          // Compress video
          final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
            file.path,
            quality: VideoQuality.MediumQuality,
            duration: 10000,
          );
          
          if (mediaInfo == null) throw Exception('Failed to compress video');
          
          // Generate thumbnail
          final thumbnailFile = await VideoCompress.getFileThumbnail(file.path);
          final thumbnailRef = _storage.ref()
              .child('stories')
              .child(userId)
              .child('thumbnails')
              .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
          
          print('Uploading thumbnail to: ${thumbnailRef.fullPath}'); // Debug log
          await thumbnailRef.putFile(thumbnailFile);
          thumbnailUrl = await thumbnailRef.getDownloadURL();
          
          // Upload video
          final videoRef = _storage.ref()
              .child('stories')
              .child(userId)
              .child('videos')
              .child('${DateTime.now().millisecondsSinceEpoch}.mp4');
          
          print('Uploading video to: ${videoRef.fullPath}'); // Debug log
          await videoRef.putFile(File(mediaInfo.path!));
          mediaUrl = await videoRef.getDownloadURL();
        } catch (e) {
          print('Error in video processing: $e'); // Debug log
          rethrow;
        }
      } else {
        print('Attempting to upload image story for user: $userId'); // Debug log
        try {
          // Process image
          final image = img.decodeImage(file.readAsBytesSync());
          if (image == null) throw Exception('Failed to process image');
          
          // Crop to standard size
          final processedImage = img.copyResize(
            image,
            width: 1080,
            height: 1920,
          );
          
          final processedFile = File('${file.path}_processed.jpg')
            ..writeAsBytesSync(img.encodeJpg(processedImage));
          
          final ref = _storage.ref()
              .child('stories')
              .child(userId)
              .child('images')
              .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
          
          print('Uploading image to: ${ref.fullPath}'); // Debug log
          await ref.putFile(processedFile);
          mediaUrl = await ref.getDownloadURL();
        } catch (e) {
          print('Error in image processing: $e'); // Debug log
          rethrow;
        }
      }

      // Create story document
      final storyRef = _firestore.collection('stories').doc();
      final story = Story(
        id: storyRef.id,
        userId: userId,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        thumbnailUrl: thumbnailUrl,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        isActive: true,
      );

      print('Creating story with data: ${story.toFirestore()}'); // Debug log
      await storyRef.set(story.toFirestore());
      return story;
    } catch (e) {
      print('Error in uploadStory: $e'); // Debug log
      throw Exception('Failed to upload story: $e');
    }
  }

  Future<void> extendStoryDuration(String storyId) async {
    final storyRef = _firestore.collection('stories').doc(storyId);
    final story = await storyRef.get();
    
    if (!story.exists) throw Exception('Story not found');
    
    final storyData = Story.fromFirestore(story);
    if (storyData.userId != _auth.currentUser?.uid) {
      throw Exception('Unauthorized');
    }

    await storyRef.update({
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(minutes: 10)),
      ),
      'extensionCount': FieldValue.increment(1),
    });
  }

  Future<void> deleteStory(String storyId) async {
    final storyRef = _firestore.collection('stories').doc(storyId);
    final story = await storyRef.get();
    
    if (!story.exists) throw Exception('Story not found');
    
    final storyData = Story.fromFirestore(story);
    if (storyData.userId != _auth.currentUser?.uid) {
      throw Exception('Unauthorized');
    }

    // Delete media files
    final mediaRef = _storage.refFromURL(storyData.mediaUrl);
    await mediaRef.delete();

    if (storyData.thumbnailUrl.isNotEmpty) {
      final thumbnailRef = _storage.refFromURL(storyData.thumbnailUrl);
      await thumbnailRef.delete();
    }

    // Update story document
    await storyRef.update({
      'isActive': false,
    });
  }

  Future<void> markStoryAsViewed(String storyId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore.collection('stories').doc(storyId).update({
      'viewedBy': FieldValue.arrayUnion([userId]),
    });
  }

  Stream<List<Story>> getUserActiveStories(String userId) {
    final now = DateTime.now();
    print('Querying stories for user: $userId at time: $now');  // Debug print
    
    return FirebaseFirestore.instance
        .collection('stories')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)  // Add this condition back
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('expiresAt', descending: true)
        .snapshots()
        .map((snapshot) {
          print('Found ${snapshot.docs.length} active stories');  // Debug print
          return snapshot.docs.map((doc) => Story.fromFirestore(doc)).toList();
        });
  }

  Future<void> deactivateStory(String storyId) async {
    final storyRef = _firestore.collection('stories').doc(storyId);
    final story = await storyRef.get();
    
    if (!story.exists) throw Exception('Story not found');
    
    final storyData = Story.fromFirestore(story);
    if (storyData.userId != _auth.currentUser?.uid) {
      throw Exception('Unauthorized');
    }

    // Update story document to set it as inactive
    await storyRef.update({
      'isActive': false,
    });
  }
} 