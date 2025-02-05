import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:async' show unawaited;

class VideoUploadScreen extends StatefulWidget {
  const VideoUploadScreen({super.key});

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _videoFile;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _isPickingVideo = false;

  Future<void> _pickVideo() async {
    if (_isPickingVideo) return;
    
    setState(() => _isPickingVideo = true);
    
    try {
      final picker = ImagePicker();
      final video = await picker.pickVideo(source: ImageSource.gallery);
      
      if (video != null) {
        setState(() {
          _videoFile = File(video.path);
        });
      }
    } finally {
      setState(() => _isPickingVideo = false);
    }
  }

  Future<void> _uploadVideo() async {
    if (_videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a video first')),
      );
      return;
    }

    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Upload video to Firebase Storage
      final videoFileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('videos')
          .child(user.uid)
          .child(videoFileName);

      final uploadTask = storageRef.putFile(_videoFile!);

      // Track upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      await uploadTask;
      final videoUrl = await storageRef.getDownloadURL();

      // Save video metadata to Firestore
      await FirebaseFirestore.instance.collection('videos').add({
        'userId': user.uid,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'videoUrl': videoUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'views': 0,
      });

      // Update user's video count
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'videoCount': FieldValue.increment(1),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video uploaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading video: $e')),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Video'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _isUploading ? null : _pickVideo,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _videoFile != null
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.video_file, size: 64),
                          Text(
                            'Video Selected',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_upload, size: 64),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to select video',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            if (_isUploading) ...[
              LinearProgressIndicator(value: _uploadProgress),
              const SizedBox(height: 16),
              Text(
                'Uploading... ${(_uploadProgress * 100).toStringAsFixed(1)}%',
                textAlign: TextAlign.center,
              ),
            ] else
              ElevatedButton(
                onPressed: _uploadVideo,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Upload Video'),
              ),
          ],
        ),
      ),
    );
  }
} 