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
  final _cookTimeController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  
  List<File> _selectedPhotos = [];
  MealType _selectedMealType = MealType.snack;
  bool _isPublic = true;
  bool _isVegetarian = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _ingredientsController.dispose();
    _instructionsController.dispose();
    _cookTimeController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
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

      // Calculate carbon saved (example calculation)
      final carbonSaved = _isVegetarian ? 1.2 : 0.0;

      // Create meal post
      final mealPost = MealPost(
        id: '', // This will be set by Firestore
        userId: currentUser.uid,
        userName: userData['displayName'] ?? 'Anonymous',
        title: _titleController.text,
        photoUrls: photoUrls,
        mealType: _selectedMealType,
        cookTime: int.parse(_cookTimeController.text),
        calories: int.parse(_caloriesController.text),
        protein: int.parse(_proteinController.text),
        isVegetarian: _isVegetarian,
        carbonSaved: carbonSaved,
        isPublic: _isPublic,
        createdAt: DateTime.now(),
        userAvatarUrl: userData['avatarUrl'],
        caption: '', // Assuming caption is not provided in the original code
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

      await FirebaseFirestore.instance
          .collection('meal_posts')
          .add(mealPost.toFirestore());

      if (mounted) {
        // Pop back to previous screen
        Navigator.pop(context);
        
        // Show success message
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

  Widget _buildPhotoSection() {
    return Container(
      height: 120,
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          // Add Photo Button
          InkWell(
            onTap: _pickImage,
            child: Container(
              width: 100,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate, size: 32, color: Colors.grey[600]),
                  const SizedBox(height: 8),
                  Text(
                    'Add Photo',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Selected Photos
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedPhotos.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedPhotos[index],
                          width: 100,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: const Icon(Icons.remove_circle),
                          color: Colors.red,
                          onPressed: () {
                            setState(() {
                              _selectedPhotos.removeAt(index);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? suffix,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          suffixText: suffix,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          if (int.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Recipe'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildPhotoSection(),

                  // Title Field
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Recipe Title',
                        hintText: 'Give your recipe a name',
                        prefixIcon: const Icon(Icons.restaurant_menu),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Please enter a title' : null,
                    ),
                  ),

                  // Meal Type Selector
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<MealType>(
                        value: _selectedMealType,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down),
                        items: MealType.values.map((MealType type) {
                          return DropdownMenuItem<MealType>(
                            value: type,
                            child: Row(
                              children: [
                                Icon(type.icon, size: 20),
                                const SizedBox(width: 8),
                                Text(type.toString().split('.').last.toUpperCase()),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (MealType? newValue) {
                          if (newValue != null) {
                            setState(() => _selectedMealType = newValue);
                          }
                        },
                      ),
                    ),
                  ),

                  // Metrics Section
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recipe Metrics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildMetricField(
                          controller: _cookTimeController,
                          label: 'Cook Time',
                          hint: 'How long to prepare?',
                          icon: Icons.timer,
                          suffix: 'min',
                        ),
                        _buildMetricField(
                          controller: _caloriesController,
                          label: 'Calories',
                          hint: 'Calories per serving',
                          icon: Icons.local_fire_department,
                          suffix: 'kcal',
                        ),
                        _buildMetricField(
                          controller: _proteinController,
                          label: 'Protein',
                          hint: 'Protein content',
                          icon: Icons.fitness_center,
                          suffix: 'g',
                        ),
                      ],
                    ),
                  ),

                  // Recipe Details Section
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recipe Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            hintText: 'Brief description of your recipe',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _ingredientsController,
                          decoration: InputDecoration(
                            labelText: 'Ingredients',
                            hintText: '- 2 cups flour\n- 1 cup sugar\n- 3 eggs',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          maxLines: 5,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _instructionsController,
                          decoration: InputDecoration(
                            labelText: 'Instructions',
                            hintText: '1. Preheat oven\n2. Mix ingredients\n3. Bake for 30 minutes',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          maxLines: 5,
                        ),
                      ],
                    ),
                  ),

                  // Options Section
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Vegetarian'),
                          subtitle: const Text('Is this a vegetarian recipe?'),
                          value: _isVegetarian,
                          onChanged: (bool value) {
                            setState(() => _isVegetarian = value);
                          },
                        ),
                        const Divider(),
                        SwitchListTile(
                          title: const Text('Public Recipe'),
                          subtitle: const Text('Make this recipe visible to everyone'),
                          value: _isPublic,
                          onChanged: (bool value) {
                            setState(() => _isPublic = value);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Submit Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _createPost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Share Recipe',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 