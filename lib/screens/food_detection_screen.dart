import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:recipetok/services/vision_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

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
  bool get _isSimulator => !kIsWeb && Platform.isIOS && !Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    _initializeVisionService();
    if (_isSimulator) {
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
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _detectionResults = null;
          _error = null;
        });
        await _detectFood();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Detection'),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedImage != null) ...[
              Container(
                height: 300,
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
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover,
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
                      if (!_isSimulator)
                        ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  if (_isSimulator) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadSampleImage,
                      icon: const Icon(Icons.image),
                      label: const Text('Use Sample Image'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
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

            if (_detectionResults != null && _detectionResults!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detection Results:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...(_detectionResults!.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value)))
                            .map((entry) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                  Text(
                                    '${(entry.value * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
              ),

            if (_detectionResults != null && _detectionResults!.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No food detected in the image.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
} 