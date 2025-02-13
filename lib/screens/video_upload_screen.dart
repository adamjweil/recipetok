import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:camera/camera.dart';
import 'package:video_editor/video_editor.dart';
import 'dart:io';
import 'dart:async' show unawaited;
import 'package:recipetok/screens/video_gallery_screen.dart';
import 'package:recipetok/screens/video_processing_screen.dart';

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
  CameraController? _cameraController;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: $e')),
        );
      }
    }
  }

  Future<void> _browseVideos() async {
    if (_isPickingVideo) return;
    
    setState(() => _isPickingVideo = true);
    
    try {
      final video = await Navigator.push<File>(
        context,
        MaterialPageRoute(
          builder: (context) => const VideoGalleryScreen(),
        ),
      );
      
      if (video != null) {
        setState(() {
          _videoFile = video;
        });
        _processVideo();
      }
    } finally {
      setState(() => _isPickingVideo = false);
    }
  }

  Future<void> _recordVideo() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_isRecording) {
      final file = await _cameraController!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _videoFile = File(file.path);
      });
      _processVideo();
    } else {
      try {
        await _cameraController!.startVideoRecording();
        setState(() {
          _isRecording = true;
        });

        // Auto-stop after 60 seconds
        Future.delayed(const Duration(seconds: 60), () {
          if (_isRecording) {
            _cameraController!.stopVideoRecording().then((file) {
              setState(() {
                _isRecording = false;
                _videoFile = File(file.path);
              });
              _processVideo();
            });
          }
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error recording video: $e')),
          );
        }
      }
    }
  }

  void _processVideo() {
    if (_videoFile == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to upload videos')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoProcessingScreen(
          videoPath: _videoFile!.path,
          userId: user.uid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Video'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _cameraController != null &&
                    _cameraController!.value.isInitialized
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      CameraPreview(_cameraController!),
                      if (_isRecording)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Recording',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  )
                : const Center(
                    child: Text('Initializing camera...'),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOptionButton(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: _browseVideos,
                  ),
                  _buildRecordButton(),
                  _buildOptionButton(
                    icon: Icons.switch_camera,
                    label: 'Flip',
                    onTap: () async {
                      if (_cameraController == null) return;
                      final cameras = await availableCameras();
                      final newCamera = cameras.firstWhere(
                        (camera) =>
                            camera.lensDirection !=
                            _cameraController!.description.lensDirection,
                        orElse: () => cameras.first,
                      );
                      await _cameraController!.dispose();
                      _cameraController = CameraController(
                        newCamera,
                        ResolutionPreset.high,
                        enableAudio: true,
                      );
                      await _cameraController!.initialize();
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black87,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: _recordVideo,
      child: Container(
        width: 72,
        height: 72,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: _isRecording ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: _isRecording ? BorderRadius.circular(8) : null,
            color: Colors.red,
          ),
        ),
      ),
    );
  }
} 