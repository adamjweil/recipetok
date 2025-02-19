import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:recipetok/services/vision_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';

class FoodDetectionScreen extends StatefulWidget {
  const FoodDetectionScreen({super.key});

  @override
  State<FoodDetectionScreen> createState() => _FoodDetectionScreenState();
}

class _FoodDetectionScreenState extends State<FoodDetectionScreen> {
  final _visionService = VisionService.instance;
  final _imagePicker = ImagePicker();
  File? _selectedImage;
  Map<String, double>? _detectionResults;
  bool _isProcessing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeVisionService();
    if (!kIsWeb && Platform.isIOS) {
      _loadSampleImage();
    }
  }

  Future<void> _loadSampleImage() async {
    try {
      // Load the sample image from assets
      final byteData = await rootBundle.load('assets/images/sample_salad.jpg');
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/sample_salad.jpg');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());
      
      setState(() {
        _selectedImage = tempFile;
      });
      
      // Analyze the sample image
      await _detectFood();
    } catch (e) {
      setState(() {
        _error = 'Failed to load sample image: $e';
      });
    }
  }

  Future<void> _initializeVisionService() async {
    try {
      await _visionService.initialize();
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize Vision API: $e';
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        // First, let them edit the image
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9
          ],
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Edit Photo',
              toolbarColor: Theme.of(context).primaryColor,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
            IOSUiSettings(
              title: 'Edit Photo',
              aspectRatioLockEnabled: false,
            ),
          ],
        );

        if (croppedFile != null) {
          // After editing, analyze the image
          setState(() {
            _selectedImage = File(croppedFile.path);
            _detectionResults = null;
            _error = null;
            _isProcessing = true;
          });

          try {
            final results = await _visionService.detectFood(_selectedImage!);
            
            setState(() {
              _detectionResults = results;
              _isProcessing = false;
            });

            if (mounted) {
              // Show preview dialog with labels
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Dialog(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.9,
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Image
                              Image.file(
                                _selectedImage!,
                                fit: BoxFit.contain,
                              ),
                              // Labels overlay with gradient background
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.7),
                                      Colors.transparent,
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.7),
                                    ],
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Detected Items:',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            offset: Offset(0, 1),
                                            blurRadius: 3.0,
                                            color: Colors.black,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: () {
                                        final sortedEntries = results.entries
                                            .where((entry) => entry.value > 0)
                                            .toList()
                                          ..sort((a, b) => b.value.compareTo(a.value));

                                        final topFiveEntries = sortedEntries.take(5).toList();
                                        
                                        return topFiveEntries.map<Widget>((e) => Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.6),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(0.2),
                                                width: 0.5,
                                              ),
                                            ),
                                            child: Text(
                                              '${e.key} (${(e.value * 100).toStringAsFixed(1)}%)',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                shadows: [
                                                  Shadow(
                                                    offset: Offset(0, 1),
                                                    blurRadius: 3.0,
                                                    color: Colors.black,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        )).toList();
                                      }(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedImage = null;
                                    _detectionResults = null;
                                  });
                                  Navigator.pop(context);
                                },
                                child: const Text('Retake'),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: const Text('Use This Image'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          } catch (e) {
            setState(() {
              _error = 'Failed to detect food: $e';
              _isProcessing = false;
            });
          }
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to pick image: $e';
      });
    }
  }

  Future<void> _detectFood() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final results = await _visionService.detectFood(_selectedImage!);
      setState(() {
        _detectionResults = results;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to detect food: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final previewHeight = screenHeight * 0.7; // 70% of screen height

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Detection Preview'),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedImage != null) ...[
              Container(
                height: previewHeight,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image
                      Image.file(
                        _selectedImage!,
                        fit: BoxFit.cover,
                      ),
                      // Labels overlay with gradient background
                      if (_detectionResults != null && _detectionResults!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.7),
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Detected Items:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0, 1),
                                      blurRadius: 3.0,
                                      color: Colors.black,
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: () {
                                  final sortedEntries = _detectionResults!.entries
                                      .where((entry) => entry.value > 0)
                                      .toList()
                                    ..sort((a, b) => b.value.compareTo(a.value));

                                  final topFiveEntries = sortedEntries.take(5).toList();
                                  
                                  return topFiveEntries.map<Widget>((e) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.2),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Text(
                                        '${e.key} (${(e.value * 100).toStringAsFixed(1)}%)',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          shadows: [
                                            Shadow(
                                              offset: Offset(0, 1),
                                              blurRadius: 3.0,
                                              color: Colors.black,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )).toList();
                                }(),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Take Photo'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loadSampleImage,
                      icon: const Icon(Icons.image),
                      label: const Text('Use Sample Image'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
} 