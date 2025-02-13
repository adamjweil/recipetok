import 'package:flutter/material.dart';
import 'package:recipetok/models/video_draft.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import '../screens/main_navigation_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';

class VideoProcessingWizard extends StatefulWidget {
  final VideoDraft draft;

  const VideoProcessingWizard({
    super.key,
    required this.draft,
  });

  @override
  State<VideoProcessingWizard> createState() => _VideoProcessingWizardState();
}

class _VideoProcessingWizardState extends State<VideoProcessingWizard> {
  late PageController _pageController;
  late VideoDraft _currentDraft;
  int _currentStep = 0;
  bool _isLoading = false;
  String _uploadStatus = '';
  double _uploadProgress = 0;

  final List<String> _stepTitles = [
    'Title & Description',
    'Ingredients',
    'Instructions',
    'Additional Details',
    'Review',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _currentDraft = widget.draft;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<File?> _compressVideo(File videoFile) async {
    try {
      setState(() {
        _uploadStatus = 'Compressing video...';
      });
      debugPrint('🎬 Starting video compression...');

      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (mediaInfo?.file == null) {
        debugPrint('⚠️ Video compression failed, using original file');
        return videoFile;
      }

      final compressedSize = await mediaInfo!.file!.length();
      final originalSize = await videoFile.length();
      debugPrint('📊 Original size: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');
      debugPrint('📊 Compressed size: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB');
      
      return mediaInfo.file;
    } catch (e) {
      debugPrint('⚠️ Error during compression: $e');
      return videoFile;
    }
  }

  Future<String?> _generateOptimizedThumbnail(String videoPath) async {
    try {
      setState(() {
        _uploadStatus = 'Generating thumbnail...';
      });
      debugPrint('🖼️ Generating thumbnail...');

      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 300,
        maxWidth: 300,
        quality: 60,
      );

      return thumbnailPath;
    } catch (e) {
      debugPrint('⚠️ Error generating thumbnail: $e');
      return null;
    }
  }

  Future<void> _saveVideoAndNavigate() async {
    try {
      setState(() {
        _isLoading = true;
        _uploadStatus = 'Preparing video...';
        _uploadProgress = 0;
      });
      debugPrint('🎬 Starting video upload process...');

      // Compress video
      final videoFile = File(_currentDraft.videoPath!);
      final compressedVideo = await _compressVideo(videoFile);
      if (compressedVideo == null) {
        throw Exception('Failed to prepare video');
      }

      // Start thumbnail generation early
      final thumbnailFuture = _generateOptimizedThumbnail(_currentDraft.videoPath!);

      // Upload video
      setState(() {
        _uploadStatus = 'Uploading video...';
      });

      final videoRef = FirebaseStorage.instance
          .ref()
          .child('videos')
          .child(_currentDraft.userId)
          .child('${DateTime.now().millisecondsSinceEpoch}.mp4');
      
      final uploadTask = videoRef.putFile(
        compressedVideo,
        SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {'compressed': 'true'}
        ),
      );
      
      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        debugPrint('📤 Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
        setState(() {
          _uploadProgress = progress;
          _uploadStatus = 'Uploading video: ${(progress * 100).toStringAsFixed(1)}%';
        });
      });

      // Wait for video upload and thumbnail generation in parallel
      final results = await Future.wait([
        uploadTask.then((snapshot) => snapshot.ref.getDownloadURL()),
        thumbnailFuture,
      ]);

      final videoUrl = results[0] as String;
      final thumbnailPath = results[1] as String?;

      debugPrint('✅ Video uploaded successfully');

      // Upload thumbnail if available
      String? thumbnailUrl;
      if (thumbnailPath != null) {
        setState(() {
          _uploadStatus = 'Uploading thumbnail...';
        });

        final thumbnailRef = FirebaseStorage.instance
            .ref()
            .child('thumbnails')
            .child(_currentDraft.userId)
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
        
        await thumbnailRef.putFile(
          File(thumbnailPath),
          SettableMetadata(
            contentType: 'image/jpeg',
            cacheControl: 'public, max-age=31536000',
          ),
        );
        thumbnailUrl = await thumbnailRef.getDownloadURL();
        debugPrint('✅ Thumbnail uploaded successfully');
      }

      // Save to Firestore
      setState(() {
        _uploadStatus = 'Saving recipe details...';
      });
      debugPrint('💾 Saving recipe data to Firestore...');

      await FirebaseFirestore.instance.collection('videos').add({
        'userId': _currentDraft.userId,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'title': _currentDraft.title,
        'description': _currentDraft.description,
        'ingredients': _currentDraft.ingredients,
        'instructions': _currentDraft.instructions,
        'calories': _currentDraft.calories,
        'cookTimeMinutes': _currentDraft.cookTimeMinutes,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
        'comments': [],
        'views': 0,
        'isPublic': true,
      });

      // Clean up
      if (compressedVideo.path != videoFile.path) {
        await compressedVideo.delete().catchError((e) => debugPrint('⚠️ Error deleting compressed video: $e'));
      }
      if (thumbnailPath != null) {
        await File(thumbnailPath).delete().catchError((e) => debugPrint('⚠️ Error deleting thumbnail: $e'));
      }
      await VideoCompress.deleteAllCache();

      debugPrint('✅ Recipe data saved successfully');

      if (mounted) {
        debugPrint('🏁 Upload process completed successfully');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const MainNavigationScreen(
              initialIndex: 4,
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('❌ Error during save process: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving video: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadStatus = '';
          _uploadProgress = 0;
        });
      }
    }
  }

  void _nextStep() {
    if (_currentStep < _stepTitles.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep++;
      });
    } else {
      _saveVideoAndNavigate();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep--;
      });
    }
  }

  Widget _buildTitleDescriptionStep() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recipe Title',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _currentDraft.title,
            decoration: const InputDecoration(
              hintText: 'Enter recipe title',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              _currentDraft = _currentDraft.copyWith(title: value);
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Description',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _currentDraft.description,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Enter recipe description',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              _currentDraft = _currentDraft.copyWith(description: value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsStep() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ingredients',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  setState(() {
                    final ingredients = List<String>.from(_currentDraft.ingredients);
                    ingredients.add('');
                    _currentDraft = _currentDraft.copyWith(ingredients: ingredients);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _currentDraft.ingredients.length,
              itemBuilder: (context, index) {
                return Dismissible(
                  key: ValueKey('ingredient_$index'),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) {
                    setState(() {
                      final ingredients = List<String>.from(_currentDraft.ingredients);
                      ingredients.removeAt(index);
                      _currentDraft = _currentDraft.copyWith(ingredients: ingredients);
                    });
                  },
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.drag_handle),
                      title: TextFormField(
                        initialValue: _currentDraft.ingredients[index],
                        decoration: InputDecoration(
                          hintText: 'Ingredient ${index + 1}',
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          setState(() {
                            final ingredients = List<String>.from(_currentDraft.ingredients);
                            ingredients[index] = value;
                            _currentDraft = _currentDraft.copyWith(ingredients: ingredients);
                          });
                        },
                      ),
                    ),
                  ),
                );
              },
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final ingredients = List<String>.from(_currentDraft.ingredients);
                  final item = ingredients.removeAt(oldIndex);
                  ingredients.insert(newIndex, item);
                  _currentDraft = _currentDraft.copyWith(ingredients: ingredients);
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsStep() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Instructions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  setState(() {
                    final instructions = List<String>.from(_currentDraft.instructions);
                    instructions.add('');
                    _currentDraft = _currentDraft.copyWith(instructions: instructions);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _currentDraft.instructions.length,
              itemBuilder: (context, index) {
                return Dismissible(
                  key: ValueKey('instruction_$index'),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) {
                    setState(() {
                      final instructions = List<String>.from(_currentDraft.instructions);
                      instructions.removeAt(index);
                      _currentDraft = _currentDraft.copyWith(instructions: instructions);
                    });
                  },
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.drag_handle),
                      title: TextFormField(
                        initialValue: _currentDraft.instructions[index],
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: 'Step ${index + 1}',
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          setState(() {
                            final instructions = List<String>.from(_currentDraft.instructions);
                            instructions[index] = value;
                            _currentDraft = _currentDraft.copyWith(instructions: instructions);
                          });
                        },
                      ),
                    ),
                  ),
                );
              },
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final instructions = List<String>.from(_currentDraft.instructions);
                  final item = instructions.removeAt(oldIndex);
                  instructions.insert(newIndex, item);
                  _currentDraft = _currentDraft.copyWith(instructions: instructions);
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalDetailsStep() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional Details',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Calories per serving'),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: _currentDraft.calories?.toString() ?? '',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Enter calories',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final calories = int.tryParse(value);
                        _currentDraft = _currentDraft.copyWith(calories: calories);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cook time (minutes)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: _currentDraft.cookTimeMinutes?.toString() ?? '',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Enter cook time',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final time = int.tryParse(value);
                        _currentDraft = _currentDraft.copyWith(cookTimeMinutes: time);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Your Recipe',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          _buildReviewSection('Title', _currentDraft.title ?? ''),
          _buildReviewSection('Description', _currentDraft.description ?? ''),
          _buildReviewSection(
            'Ingredients',
            _currentDraft.ingredients.map((e) => '• $e').join('\n'),
          ),
          _buildReviewSection(
            'Instructions',
            _currentDraft.instructions
                .asMap()
                .entries
                .map((e) => '${e.key + 1}. ${e.value}')
                .join('\n'),
          ),
          _buildReviewSection(
            'Additional Details',
            'Calories: ${_currentDraft.calories ?? "N/A"}\n'
            'Cook Time: ${_currentDraft.cookTimeMinutes ?? "N/A"} minutes',
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(content),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_stepTitles[_currentStep]),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousStep,
              )
            : null,
      ),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildTitleDescriptionStep(),
              _buildIngredientsStep(),
              _buildInstructionsStep(),
              _buildAdditionalDetailsStep(),
              _buildReviewStep(),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _uploadStatus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_uploadProgress > 0 && _uploadProgress < 1)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: LinearProgressIndicator(
                          value: _uploadProgress,
                          backgroundColor: Colors.grey[700],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentStep > 0)
                TextButton(
                  onPressed: _previousStep,
                  child: const Text('Previous'),
                )
              else
                const SizedBox.shrink(),
              ElevatedButton(
                onPressed: _isLoading ? null : _nextStep,
                child: Text(_currentStep < _stepTitles.length - 1 ? 'Next' : 'Finish'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 