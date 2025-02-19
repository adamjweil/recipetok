import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:recipetok/services/vision_service.dart';

class FoodImagePicker extends StatefulWidget {
  final Function(File file, Map<String, double> detectionResults) onImageSelected;
  
  const FoodImagePicker({
    super.key,
    required this.onImageSelected,
  });

  static Future<Map<String, dynamic>?> show(BuildContext context) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => FoodImagePicker(
        onImageSelected: (file, results) {
          Navigator.pop(context, {
            'file': file,
            'results': results,
          });
        },
      ),
    );
    return result;
  }

  @override
  State<FoodImagePicker> createState() => _FoodImagePickerState();
}

class _FoodImagePickerState extends State<FoodImagePicker> {
  final _visionService = VisionService.instance;
  final _imagePicker = ImagePicker();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeVisionService();
  }

  Future<void> _initializeVisionService() async {
    try {
      await _visionService.initialize();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize Vision API: $e')),
        );
      }
    }
  }

  Future<void> _handleImageSelection(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() => _isProcessing = true);
        
        final file = File(pickedFile.path);
        final results = await _visionService.detectFood(file);
        
        widget.onImageSelected(file, results);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyzing food in image...'),
                ],
              ),
            )
          else
            Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  title: const Text('Take Photo'),
                  onTap: () => _handleImageSelection(ImageSource.camera),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.photo_library,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () => _handleImageSelection(ImageSource.gallery),
                ),
              ],
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
} 