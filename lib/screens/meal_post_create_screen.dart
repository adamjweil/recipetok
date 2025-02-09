import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../models/meal_post.dart';
import 'package:image_cropper/image_cropper.dart';
import '../screens/profile_screen.dart';

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
  
  List<File> _selectedPhotos = [];
  MealType _selectedMealType = MealType.snack;
  bool _isPublic = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _ingredientsController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );

      if (image == null) return;

      // Crop image
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatioPresets: [
          CropAspectRatioPreset.square,
          CropAspectRatioPreset.ratio3x2,
          CropAspectRatioPreset.original,
        ],
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Theme.of(context).primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Image',
          ),
        ],
      );

      if (croppedFile == null) return;

      setState(() {
        _selectedPhotos.add(File(croppedFile.path));
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate() || _selectedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields and add at least one photo')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userData = userDoc.data() ?? {};

      // Upload photos
      final List<String> photoUrls = [];
      for (var photo in _selectedPhotos) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('meal_posts/${currentUser.uid}')
            .child('${DateTime.now().millisecondsSinceEpoch}_${photoUrls.length}.jpg');
        
        await ref.putFile(photo);
        final url = await ref.getDownloadURL();
        photoUrls.add(url);
      }

      // Create meal post
      final mealPost = MealPost(
        id: '', // This will be set by Firestore
        userId: currentUser.uid,
        userName: userData['displayName'] ?? 'Anonymous',
        title: _titleController.text,
        photoUrls: photoUrls,
        mealType: _selectedMealType,
        cookTime: 0, // Assuming cookTime is not provided in the original code
        calories: 0, // Assuming calories is not provided in the original code
        protein: 0, // Assuming protein is not provided in the original code
        isVegetarian: false, // Assuming isVegetarian is not provided in the original code
        carbonSaved: 0.0, // Assuming carbonSaved is not provided in the original code
        likes: 0,
        comments: 0,
        isLiked: false,
        isPublic: _isPublic,
        createdAt: DateTime.now(),
        userAvatarUrl: userData['avatarUrl'],
        caption: '', // Assuming caption is not provided in the original code
        description: _descriptionController.text,
        ingredients: _ingredientsController.text,
        instructions: _instructionsController.text,
      );

      await FirebaseFirestore.instance
          .collection('meal_posts')
          .add(mealPost.toFirestore());

      if (mounted) {
        // Replace current screen with profile screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfileScreen(),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal post created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Meal Post'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createPost,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Selection
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Add Photo Button
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add_photo_alternate, size: 40),
                      ),
                    ),
                    // Selected Photos
                    ..._selectedPhotos.map((photo) => Stack(
                      children: [
                        Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(photo),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedPhotos.remove(photo);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )).toList(),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  hintText: 'Give your meal a name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Meal Type
              DropdownButtonFormField<MealType>(
                value: _selectedMealType,
                decoration: const InputDecoration(
                  labelText: 'Meal Type',
                ),
                items: MealType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.toString().split('.').last.toUpperCase()),
                  );
                }).toList(),
                onChanged: (MealType? value) {
                  if (value != null) {
                    setState(() {
                      _selectedMealType = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Tell us about your meal',
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 16),

              // Ingredients
              TextFormField(
                controller: _ingredientsController,
                decoration: const InputDecoration(
                  labelText: 'Ingredients',
                  hintText: 'Example:\n- 2 cups flour\n- 1 cup sugar\n- 3 eggs',
                ),
                maxLines: 5,
              ),

              const SizedBox(height: 16),

              // Instructions
              TextFormField(
                controller: _instructionsController,
                decoration: const InputDecoration(
                  labelText: 'Instructions',
                  hintText: 'Example:\n1. Preheat oven to 350°F\n2. Mix dry ingredients\n3. Add wet ingredients',
                ),
                maxLines: 5,
              ),

              const SizedBox(height: 16),

              // Privacy Toggle
              SwitchListTile(
                title: const Text('Public Post'),
                subtitle: const Text('Anyone can see this post'),
                value: _isPublic,
                onChanged: (bool value) {
                  setState(() {
                    _isPublic = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
} 