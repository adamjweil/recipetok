import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';
import 'dart:typed_data';
import '../models/meal_post.dart';
import '../widgets/foodie_filters.dart';
import '../widgets/media_preview.dart';
import '../widgets/step_progress_indicator.dart';
import '../widgets/ai_analysis_loading.dart';
import '../widgets/ai_suggestion_field.dart';
import '../services/ai_service.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class MealPostCreateScreen extends StatefulWidget {
  const MealPostCreateScreen({super.key});

  @override
  State<MealPostCreateScreen> createState() => _MealPostCreateScreenState();
}

class _MealPostCreateScreenState extends State<MealPostCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _cookTimeController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _expandableController = ExpandableController();
  final _aiService = AIService();
  
  List<File> _selectedPhotos = [];
  List<File> _originalPhotos = []; // Store original photos before editing
  MealType _selectedMealType = MealType.snack;
  bool _isPublic = true;
  bool _isVegetarian = false;
  bool _isLoading = false;
  bool _isAnalyzing = false;
  int _currentStep = 0;
  static const int MAX_PHOTOS = 10;

  // Store AI confidence levels
  Map<String, double> _confidenceLevels = {};

  @override
  void initState() {
    super.initState();
    _expandableController.expanded = false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _ingredientsController.dispose();
    _instructionsController.dispose();
    _cookTimeController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _expandableController.dispose();
    super.dispose();
  }

  Future<void> _analyzePhotos() async {
    if (_originalPhotos.isEmpty) return;

    setState(() => _isAnalyzing = true);

    try {
      final suggestions = await _aiService.analyzeFoodImages(_originalPhotos);
      
      if (suggestions.isNotEmpty) {
        setState(() {
          // Update form fields with AI suggestions
          if (suggestions['title'] != null) {
            _titleController.text = suggestions['title'];
          }
          if (suggestions['description'] != null) {
            _descriptionController.text = suggestions['description'];
          }
          if (suggestions['ingredients'] != null) {
            _ingredientsController.text = suggestions['ingredients'];
          }
          if (suggestions['instructions'] != null) {
            _instructionsController.text = suggestions['instructions'];
          }
          if (suggestions['cookTime'] != null) {
            _cookTimeController.text = suggestions['cookTime'].toString();
          }
          if (suggestions['calories'] != null) {
            _caloriesController.text = suggestions['calories'].toString();
          }
          if (suggestions['protein'] != null) {
            _proteinController.text = suggestions['protein'].toString();
          }
          if (suggestions['mealType'] != null) {
            _selectedMealType = suggestions['mealType'];
          }
          if (suggestions['isVegetarian'] != null) {
            _isVegetarian = suggestions['isVegetarian'];
          }

          // Update confidence levels
          _confidenceLevels = Map<String, double>.from(suggestions['confidence'] ?? {});
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error analyzing photos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  Future<void> _showMediaPicker() async {
    HapticFeedback.mediumImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 200,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ListTile(
                    leading: const Icon(Icons.camera_alt, color: Colors.blue),
                    title: const Text('Take Photo'),
                    onTap: () {
                      Navigator.pop(context);
                      _captureImage();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library, color: Colors.green),
                    title: const Text('Choose from Gallery'),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _captureImage() async {
    final ImagePicker picker = ImagePicker();
    
    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );

      if (photo == null) return;

      // Store original photo
      final originalFile = File(photo.path);
      setState(() => _originalPhotos.add(originalFile));

      final Uint8List? editedImage = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageEditor(
            image: originalFile.readAsBytesSync(),
          ),
        ),
      );

      if (editedImage != null && mounted) {
        // Create a temporary file to store the edited image
        final tempDir = await Directory.systemTemp.createTemp();
        final tempFile = File('${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(editedImage);
        
        setState(() => _selectedPhotos.add(tempFile));
        HapticFeedback.lightImpact();

        // Analyze photos if this is the first one
        if (_selectedPhotos.length == 1) {
          await _analyzePhotos();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing image: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    
    try {
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );

      if (images.isEmpty) return;

      for (var image in images) {
        if (_selectedPhotos.length >= MAX_PHOTOS) break;
        
        // Store original photo
        final originalFile = File(image.path);
        setState(() => _originalPhotos.add(originalFile));

        final Uint8List? editedImage = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageEditor(
              image: originalFile.readAsBytesSync(),
            ),
          ),
        );

        if (editedImage != null && mounted) {
          // Create a temporary file to store the edited image
          final tempDir = await Directory.systemTemp.createTemp();
          final tempFile = File('${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await tempFile.writeAsBytes(editedImage);
          
          setState(() => _selectedPhotos.add(tempFile));
          HapticFeedback.lightImpact();
        }
      }

      // Analyze photos if we have new ones
      if (_selectedPhotos.isNotEmpty) {
        await _analyzePhotos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
  }

  Widget _buildMediaSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Photos (${_selectedPhotos.length}/$MAX_PHOTOS)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_selectedPhotos.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add More'),
                  onPressed: _selectedPhotos.length < MAX_PHOTOS ? _showMediaPicker : null,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_selectedPhotos.isEmpty)
            InkWell(
              onTap: _showMediaPicker,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: 48,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Add Photos',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to choose from gallery or take a photo',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            MediaPreview(
              photos: _selectedPhotos,
              onDelete: (index) {
                setState(() => _selectedPhotos.removeAt(index));
                HapticFeedback.lightImpact();
              },
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final item = _selectedPhotos.removeAt(oldIndex);
                  _selectedPhotos.insert(newIndex, item);
                });
                HapticFeedback.mediumImpact();
              },
            ),
        ],
      ),
    ).animate().fadeIn().slideX();
  }

  Widget _buildMealTypeSelector() {
    return Container(
      height: 70,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: MealType.values.map((mealType) {
          final isSelected = mealType == _selectedMealType;
          
          return GestureDetector(
            onTap: () {
              setState(() => _selectedMealType = mealType);
              HapticFeedback.lightImpact();
            },
            child: Container(
              width: 70,
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey[300]!,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    mealType.icon,
                    size: 24,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mealType.toString().split('.').last,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white : Colors.grey[600],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn().slideX();
  }

  Widget _buildRequiredFields() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AISuggestionField(
            confidence: _confidenceLevels['title'] ?? 0,
            onReset: () {
              setState(() {
                _titleController.clear();
                _confidenceLevels['title'] = 0;
              });
            },
            child: TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Meal Title',
                hintText: 'Classic Homemade Lasagna',
                prefixIcon: const Icon(Icons.restaurant_menu),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) => value?.isEmpty ?? true
                  ? 'Please enter a title'
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          AISuggestionField(
            confidence: _confidenceLevels['description'] ?? 0,
            onReset: () {
              setState(() {
                _descriptionController.clear();
                _confidenceLevels['description'] = 0;
              });
            },
            child: TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Share the story behind this dish...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX();
  }

  Widget _buildOptionalFields() {
    return ExpandablePanel(
      controller: _expandableController,
      theme: const ExpandableThemeData(
        headerAlignment: ExpandablePanelHeaderAlignment.center,
        tapBodyToExpand: true,
        tapBodyToCollapse: true,
        hasIcon: true,
      ),
      header: Container(
        padding: const EdgeInsets.all(16),
        child: const Row(
          children: [
            Icon(Icons.add_circle_outline),
            SizedBox(width: 8),
            Text(
              'Additional Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      collapsed: const SizedBox.shrink(),
      expanded: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AISuggestionField(
              confidence: _confidenceLevels['ingredients'] ?? 0,
              onReset: () {
                setState(() {
                  _ingredientsController.clear();
                  _confidenceLevels['ingredients'] = 0;
                });
              },
              child: TextFormField(
                controller: _ingredientsController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Ingredients',
                  hintText: '- 2 cups flour\n- 1 cup sugar\n- 3 eggs',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
            ),
            const SizedBox(height: 16),

            AISuggestionField(
              confidence: _confidenceLevels['instructions'] ?? 0,
              onReset: () {
                setState(() {
                  _instructionsController.clear();
                  _confidenceLevels['instructions'] = 0;
                });
              },
              child: TextFormField(
                controller: _instructionsController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Instructions',
                  hintText: '1. Preheat oven\n2. Mix ingredients\n3. Bake for 30 minutes',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nutritional Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: AISuggestionField(
                          confidence: _confidenceLevels['cookTime'] ?? 0,
                          onReset: () {
                            setState(() {
                              _cookTimeController.clear();
                              _confidenceLevels['cookTime'] = 0;
                            });
                          },
                          child: TextFormField(
                            controller: _cookTimeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cook Time (min)',
                              prefixIcon: Icon(Icons.timer),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: AISuggestionField(
                          confidence: _confidenceLevels['calories'] ?? 0,
                          onReset: () {
                            setState(() {
                              _caloriesController.clear();
                              _confidenceLevels['calories'] = 0;
                            });
                          },
                          child: TextFormField(
                            controller: _caloriesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Calories',
                              prefixIcon: Icon(Icons.local_fire_department),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AISuggestionField(
                    confidence: _confidenceLevels['protein'] ?? 0,
                    onReset: () {
                      setState(() {
                        _proteinController.clear();
                        _confidenceLevels['protein'] = 0;
                      });
                    },
                    child: TextFormField(
                      controller: _proteinController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Protein (g)',
                        prefixIcon: Icon(Icons.fitness_center),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideX();
  }

  Widget _buildToggleSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Vegetarian Recipe'),
            subtitle: const Text('Mark this recipe as vegetarian'),
            value: _isVegetarian,
            onChanged: (bool value) {
              setState(() => _isVegetarian = value);
              HapticFeedback.lightImpact();
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Public Recipe'),
            subtitle: const Text(
              'Make this recipe visible to everyone. Private recipes are only visible to you.',
            ),
            value: _isPublic,
            onChanged: (bool value) {
              setState(() => _isPublic = value);
              HapticFeedback.lightImpact();
            },
          ),
        ],
      ),
    ).animate().fadeIn().slideX();
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate() || _selectedPhotos.isEmpty) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields and add at least one photo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.heavyImpact();

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      // Get user data with better error handling
      String userName = 'Anonymous';
      String? userAvatarUrl = 'assets/images/default_avatar.png';

      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
            
        if (userDoc.exists) {
          final userData = userDoc.data() ?? {};
          userName = userData['displayName'] ?? currentUser.displayName ?? 'Anonymous';
          userAvatarUrl = userData['avatarUrl'] ?? userAvatarUrl;
        } else {
          // If user document doesn't exist, create it with default values
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .set({
                'displayName': currentUser.displayName ?? 'Anonymous',
                'email': currentUser.email,
                'avatarUrl': userAvatarUrl,
                'createdAt': FieldValue.serverTimestamp(),
              });
        }
      } catch (e) {
        debugPrint('Error fetching user data: $e');
        // Continue with default values if user data fetch fails
      }

      // Upload photos with progress tracking
      final List<String> photoUrls = [];
      for (var i = 0; i < _selectedPhotos.length; i++) {
        final photo = _selectedPhotos[i];
        
        // Update loading state with progress
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Uploading photo ${i + 1} of ${_selectedPhotos.length}...'),
              duration: const Duration(seconds: 1),
            ),
          );
        }

        final ref = FirebaseStorage.instance
            .ref()
            .child('meal_posts/${currentUser.uid}')
            .child('${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        
        // Compress image before uploading
        final compressedImage = await _compressImage(photo);
        
        // Upload with metadata
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'uploaded_by': currentUser.uid},
        );
        await ref.putFile(compressedImage, metadata);
        final url = await ref.getDownloadURL();
        photoUrls.add(url);
      }

      // Calculate carbon saved
      final carbonSaved = _isVegetarian ? 1.2 : 0.0;

      // Create meal post with verified user data
      final mealPost = MealPost(
        id: '',
        userId: currentUser.uid,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
        title: _titleController.text,
        photoUrls: photoUrls,
        mealType: _selectedMealType,
        cookTime: int.tryParse(_cookTimeController.text) ?? 0,
        calories: int.tryParse(_caloriesController.text) ?? 0,
        protein: int.tryParse(_proteinController.text) ?? 0,
        isVegetarian: _isVegetarian,
        carbonSaved: carbonSaved,
        isPublic: _isPublic,
        createdAt: DateTime.now(),
        caption: '',
        description: _descriptionController.text,
        ingredients: _ingredientsController.text,
        instructions: _instructionsController.text,
        likes: 0,
        comments: 0,
        isLiked: false,
        likesCount: 0,
        commentsCount: 0,
        likedBy: [],
      );

      // Create the post document
      await FirebaseFirestore.instance
          .collection('meal_posts')
          .add(mealPost.toFirestore());

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<File> _compressImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final image = await decodeImageFromList(bytes);
      
      // If image is already small enough, return original
      if (image.width <= 1920 && image.height <= 1920) {
        return file;
      }

      // Compress image
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 1920,
        minHeight: 1920,
        quality: 85,
      );

      if (result == null) return file;

      // Save compressed image
      final dir = await Directory.systemTemp.createTemp();
      final compressedFile = File('${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await compressedFile.writeAsBytes(result);
      
      return compressedFile;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return file; // Return original if compression fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Recipe'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                StepProgressIndicator(
                  currentStep: _currentStep,
                  totalSteps: 4,
                  onStepTapped: (step) {
                    setState(() => _currentStep = step);
                    HapticFeedback.lightImpact();
                  },
                ),
                Expanded(
                  child: ListView(
                    children: [
                      _buildMediaSection(),
                      _buildMealTypeSelector(),
                      _buildRequiredFields(),
                      _buildOptionalFields(),
                      _buildToggleSection(),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.close),
                                label: const Text('Discard'),
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Discard Recipe?'),
                                      content: const Text(
                                        'Are you sure you want to discard this recipe? All your progress will be lost.'
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context); // Close dialog
                                            Navigator.pop(context); // Close create screen
                                          },
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                          child: const Text('Discard'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check),
                                label: const Text('Share Recipe'),
                                onPressed: _isLoading ? null : _createPost,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isAnalyzing)
            const AIAnalysisLoading(),
        ],
      ),
    );
  }
}

// Extension to get icon for meal type
extension MealTypeIcon on MealType {
  IconData get icon {
    switch (this) {
      case MealType.breakfast:
        return Icons.breakfast_dining;
      case MealType.lunch:
        return Icons.lunch_dining;
      case MealType.dinner:
        return Icons.dinner_dining;
      case MealType.snack:
        return Icons.restaurant_menu;
    }
  }
} 