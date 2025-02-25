import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
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
import '../services/vision_service.dart';
import '../screens/home_screen.dart';
import '../services/replicate_service.dart';
import '../widgets/image_enhancement_preview.dart';
import 'package:image/image.dart' as img;
import '../models/food_detection.dart';
import 'package:http/http.dart' as http;

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

  // Add these new variables
  final List<String> _foodPuns = [
    // Monday puns
    "Manic Mondae Sundae 🍨",
    "Monday Blues-berry Pie 🫐",
    "Mondaze Glazed Donuts 🍩",
    // Tuesday puns
    "Taco Boozeday 🌮",
    "Two's Day Double Decker 🥪",
    "Total Tueslay Parfait 🍮",
    // Wednesday puns
    "Wok This Way Wednesday 🥢",
    "Wings-day Buffalo Special 🍗",
    "What The Fork Wednesday 🍴",
    // Thursday puns
    "Thirstday Smoothie 🥤",
    "Thicc Thursday Milkshake 🥛",
    "Thunder Thighs Thursday 🍗",
    // Friday puns
    "Fry-day Feast 🍟",
    "Feast Mode Friday 🍽️",
    "Fork Yeah Friday 🔥",
    // Saturday puns
    "Slay-turday Snacks ✨",
    "Sauce Boss Saturday 💫",
    "Snack That Saturday 💅",
    // Sunday puns
    "Sun-dae Funday 🍦",
    "Slay & Filet Sunday 🔪",
    "Sweet & Savage Sunday 😈"
  ];

  final _replicateService = ReplicateService.instance;

  String _generateFoodPun() {
    final dayOfWeek = DateTime.now().weekday;
    final startIndex = (dayOfWeek - 1) * 3;
    final endIndex = startIndex + 3;
    final dayPuns = _foodPuns.sublist(startIndex, endIndex);
    return dayPuns[DateTime.now().millisecond % 3];
  }

  String _generateCleverDescription(Map<String, dynamic> suggestions) {
    final detectedIngredients = suggestions['detectedIngredients'] as List<String>? ?? [];
    if (detectedIngredients.isEmpty) {
      return suggestions['description'] ?? '';
    }

    String ingredientsList = '';
    if (detectedIngredients.length == 1) {
      ingredientsList = detectedIngredients[0];
    } else if (detectedIngredients.length == 2) {
      ingredientsList = '${detectedIngredients[0]} and ${detectedIngredients[1]}';
    } else {
      final lastIngredient = detectedIngredients.last;
      final otherIngredients = detectedIngredients.sublist(0, detectedIngredients.length - 1);
      ingredientsList = '${otherIngredients.join(', ')}, and $lastIngredient';
    }

    final templates = [
      "Dancing on your taste buds: a symphony of $ingredientsList 🎵",
      "Warning: This combo of $ingredientsList might cause extreme happiness 🚀",
      "Living my best life with $ingredientsList ✨",
      "Plot twist: $ingredientsList just became besties on this plate 🤝",
      "When $ingredientsList had a party and everyone showed up 🎉",
      "Caught in the act: $ingredientsList being absolutely delicious 📸",
      "Breaking news: $ingredientsList just broke the internet 🌟",
      "The collab we didn't know we needed: $ingredientsList 🔥",
      "Main character energy: $ingredientsList stealing the show ⭐",
      "POV: You're about to devour $ingredientsList like nobody's watching 👀",
    ];

    return templates[DateTime.now().millisecond % templates.length];
  }

  String _generateDynamicTitle(Map<String, dynamic> suggestions) {
    debugPrint('🔍 AI Suggestions for title: ${suggestions.toString()}');
    
    final List<String> detectedIngredients = 
        List<String>.from(suggestions['detectedIngredients'] ?? []);
    final List<String> foodItems = 
        List<String>.from(suggestions['foodItems'] ?? []);
    final String? dishType = suggestions['dishType'] as String?;
    final String? dishName = suggestions['dishName'] as String?;
    
    if (detectedIngredients.isEmpty && foodItems.isEmpty && 
        dishType == null && dishName == null) {
      return 'Tasty Creation ✨';
    }

    String mainSubject = '';
    if (dishName != null && dishName.isNotEmpty) {
      mainSubject = dishName.toLowerCase();
    } else if (dishType != null && dishType.isNotEmpty) {
      mainSubject = dishType.toLowerCase();
    } else if (detectedIngredients.isNotEmpty) {
      mainSubject = detectedIngredients[0].toLowerCase();
    } else if (foodItems.isNotEmpty) {
      mainSubject = foodItems[0].toLowerCase();
    }

    String? additionalIngredient = detectedIngredients
        .where((i) => i.toLowerCase() != mainSubject.toLowerCase())
        .firstOrNull;

    final dayOfWeek = DateTime.now().weekday;
    final dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final currentDay = dayNames[dayOfWeek];

    final templates = {
      RegExp(r'salad|lettuce|vegetable|greens'): [
        "Green Goddess $mainSubject${additionalIngredient != null ? ' with $additionalIngredient' : ''} 🥗",
        "That Fresh $mainSubject Energy${additionalIngredient != null ? ' (ft. $additionalIngredient)' : ''} 🌱",
        "Living My Best $mainSubject Life${additionalIngredient != null ? ' with $additionalIngredient' : ''} ✨",
      ],
      RegExp(r'chicken|beef|fish|salmon|tuna|shrimp|meat|steak'): [
        "Epic $mainSubject${additionalIngredient != null ? ' with $additionalIngredient' : ''} 💪",
        "Main Character $mainSubject Moment${additionalIngredient != null ? ' (ft. $additionalIngredient)' : ''} 🔥",
        "That $mainSubject Energy${additionalIngredient != null ? ' with $additionalIngredient' : ''} ⚡",
      ],
      RegExp(r'pasta|noodle|spaghetti|ramen'): [
        "Pasta La Vista: $mainSubject${additionalIngredient != null ? ' with $additionalIngredient' : ''} 🍝",
        "Noodle Goals: $mainSubject${additionalIngredient != null ? ' (ft. $additionalIngredient)' : ''} 🍜",
        "Slurp & Serve: $mainSubject${additionalIngredient != null ? ' with $additionalIngredient' : ''} 🌟",
      ],
    };

    String title = '';
    for (var category in templates.entries) {
      if (category.key.hasMatch(mainSubject)) {
        final options = category.value;
        title = options[DateTime.now().millisecond % options.length];
        break;
      }
    }

    if (title.isEmpty) {
      final genericTemplates = [
        "$currentDay $mainSubject Magic${additionalIngredient != null ? ' with $additionalIngredient' : ''} ✨",
        "Serving $mainSubject Realness${additionalIngredient != null ? ' (ft. $additionalIngredient)' : ''} 💅",
        "That $mainSubject Energy${additionalIngredient != null ? ' with $additionalIngredient' : ''} 🔥",
        "$mainSubject But Make It Fashion${additionalIngredient != null ? ' (ft. $additionalIngredient)' : ''} 💫",
      ];
      title = genericTemplates[DateTime.now().millisecond % genericTemplates.length];
    }

    return title.substring(0, 1).toUpperCase() + title.substring(1);
  }

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
    if (_selectedPhotos.isEmpty) return;

    setState(() => _isAnalyzing = true);

    try {
      final suggestions = await _aiService.analyzeFoodImages(_selectedPhotos);
      debugPrint('📸 AI Analysis Results: ${suggestions.toString()}');
      
      if (suggestions.isNotEmpty) {
        setState(() {
          // Generate dynamic title based on detected ingredients
          _titleController.text = _generateDynamicTitle(suggestions);
          _confidenceLevels['title'] = 1.0;

          // Generate clever description based on detected ingredients
          final detectedIngredients = suggestions['detectedIngredients'];
          List<String> topItems = [];
          
          if (detectedIngredients != null) {
            if (detectedIngredients is List) {
              topItems = List<String>.from(detectedIngredients);
            } else if (detectedIngredients is Map) {
              final sortedEntries = detectedIngredients.entries
                  .where((entry) => entry.value > 0)
                  .toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              final topFiveEntries = sortedEntries.take(5).toList();
              topItems = topFiveEntries.map((e) => e.key.toString()).toList();
            }
          }
          
          _descriptionController.text = _generateCleverDescription({
            'detectedIngredients': topItems,
          });
          _confidenceLevels['description'] = 1.0;

          // Update other form fields with AI suggestions
          if (suggestions['ingredients'] != null) {
            _ingredientsController.text = suggestions['ingredients'].toString();
          }
          if (suggestions['instructions'] != null) {
            _instructionsController.text = suggestions['instructions'].toString();
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

          // Update confidence levels for other fields
          _confidenceLevels = Map<String, double>.from(suggestions['confidence'] ?? {});
          // Ensure title and description confidence stay at 100%
          _confidenceLevels['title'] = 1.0;
          _confidenceLevels['description'] = 1.0;
        });
      }
    } catch (e) {
      debugPrint('❌ Error analyzing photos: $e');
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

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final _visionService = VisionService.instance;
    
    try {
      await _visionService.initialize();
      
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
        
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: originalFile.path,
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

        if (croppedFile != null && mounted) {
          final croppedImage = File(croppedFile.path);
          
          // Detect food in the image
          final detectionResults = await _visionService.detectFood(croppedImage);
          
          if (mounted) {
            // Show preview dialog with labels
            final shouldUseImage = await _showPreviewDialog(croppedImage, detectionResults) ?? false;

            if (shouldUseImage) {
              setState(() {
                _selectedPhotos.add(croppedImage);
                _originalPhotos.add(originalFile);
                
                // Auto-fill description with detected items
                final sortedEntries = detectionResults.entries
                    .where((entry) => entry.value > 0)
                    .toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                final topFiveEntries = sortedEntries.take(5).toList();
                final topItems = topFiveEntries.map((e) => e.key).toList();
                
                _descriptionController.text = _generateCleverDescription({
                  'detectedIngredients': topItems,
                });
              });
              
              HapticFeedback.lightImpact();
            }
          }
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

  Future<bool?> _showPreviewDialog(File imageFile, Map<String, double> detectionResults) async {
    // Replace Roboflow detection with Replicate enhancement
    String? enhancedImageUrl;
    String? error;
    
    try {
      enhancedImageUrl = await _replicateService.enhanceFoodImage(imageFile);
    } catch (e) {
      error = e.toString();
      debugPrint('Error enhancing image: $e');
    }

    if (!mounted) return false;

    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ImageEnhancementPreview(
          originalImage: imageFile,
          enhancedImageUrl: enhancedImageUrl,
          isLoading: enhancedImageUrl == null && error == null,
          error: error,
          onAccept: () => Navigator.pop(context, true),
          onReject: () => Navigator.pop(context, false),
          onRetry: () async {
            Navigator.pop(context);
            await _showPreviewDialog(imageFile, detectionResults);
          },
        ),
      ),
    );
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
              Flexible(
                child: Text(
                  'Photos (${_selectedPhotos.length}/$MAX_PHOTOS)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedPhotos.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.auto_awesome),
                      onPressed: () => _enhanceSelectedPhoto(),
                      tooltip: 'Enhance',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.add_photo_alternate),
                      onPressed: _selectedPhotos.length < MAX_PHOTOS ? _pickImage : null,
                      tooltip: 'Add More',
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_selectedPhotos.isEmpty)
            InkWell(
              onTap: _pickImage,
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
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedPhotos.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _selectedPhotos[index],
                            height: 200,
                            width: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            color: Colors.white,
                            onPressed: () => _removePhoto(index),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.auto_awesome),
                            color: Colors.white,
                            onPressed: () => _enhanceSelectedPhoto(index),
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
    ).animate().fadeIn().slideX();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Post'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isLoading ? null : _createPost,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.share, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        'Share',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
            ),
          ),
        ],
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
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _createPost,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: _isLoading
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Theme.of(context).colorScheme.onPrimary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Sharing...',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onPrimary,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.share),
                                        SizedBox(width: 8),
                                        Text('Share'),
                                      ],
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
                hintText: 'Your edgy title will appear here...',
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
    if (!_formKey.currentState!.validate()) {
      debugPrint('❌ Form validation failed');
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedPhotos.isEmpty) {
      debugPrint('❌ No photos selected');
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one photo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.heavyImpact();

    try {
      debugPrint('🚀 Starting meal post creation...');
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }
      debugPrint('👤 Current user ID: ${currentUser.uid}');

      // Get user data with better error handling
      String userName = 'Anonymous';
      String? userAvatarUrl;
      
      try {
        debugPrint('📝 Fetching user data...');
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
            
        if (userDoc.exists) {
          final userData = userDoc.data() ?? {};
          userName = userData['displayName'] ?? currentUser.displayName ?? 'Anonymous';
          userAvatarUrl = userData['avatarUrl'];
          debugPrint('✅ User data fetched: $userName');
        } else {
          debugPrint('⚠️ User document not found, creating new one...');
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .set({
                'displayName': currentUser.displayName ?? 'Anonymous',
                'email': currentUser.email,
                'createdAt': FieldValue.serverTimestamp(),
              });
        }
      } catch (e) {
        debugPrint('❌ Error fetching user data: $e');
        // Continue with default values if user data fetch fails
      }

      // Upload photos with progress tracking
      debugPrint('📸 Starting photo upload...');
      final List<String> photoUrls = [];
      
      for (var i = 0; i < _selectedPhotos.length; i++) {
        final photo = _selectedPhotos[i];
        
        debugPrint('📤 Uploading photo ${i + 1} of ${_selectedPhotos.length}...');
        
        try {
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
          debugPrint('✅ Photo ${i + 1} uploaded successfully: $url');
        } catch (e) {
          debugPrint('❌ Error uploading photo ${i + 1}: $e');
          throw Exception('Failed to upload photo ${i + 1}');
        }
      }

      if (photoUrls.isEmpty) {
        throw Exception('No photos were successfully uploaded');
      }

      // Calculate carbon saved
      final carbonSaved = _isVegetarian ? 1.2 : 0.0;

      debugPrint('📋 Creating meal post document...');
      // Safely parse numeric values
      final cookTime = int.tryParse(_cookTimeController.text.trim()) ?? 0;
      final calories = int.tryParse(_caloriesController.text.trim()) ?? 0;
      final protein = int.tryParse(_proteinController.text.trim()) ?? 0;

      // Calculate meal score
      debugPrint('🎯 Calculating meal score...');
      final mealScore = await _aiService.calculateMealScore(
        detectedIngredients: _confidenceLevels,
        calories: calories,
        protein: protein,
        isVegetarian: _isVegetarian,
        cookTime: cookTime,
        ingredients: _ingredientsController.text.trim(),
        instructions: _instructionsController.text.trim(),
      );
      debugPrint('✅ Meal score calculated: $mealScore');

      // Create meal post with verified user data
      final mealPost = MealPost(
        id: '',  // This will be set by Firestore
        userId: currentUser.uid,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
        title: _titleController.text.trim(),
        photoUrls: photoUrls,
        mealType: _selectedMealType,
        cookTime: cookTime,
        calories: calories,
        protein: protein,
        isVegetarian: _isVegetarian,
        carbonSaved: carbonSaved,
        isPublic: _isPublic,
        createdAt: DateTime.now(),
        description: _descriptionController.text.trim(),
        ingredients: _ingredientsController.text.trim(),
        instructions: _instructionsController.text.trim(),
        likes: 0,
        comments: 0,
        isLiked: false,
        likesCount: 0,
        commentsCount: 0,
        likedBy: const [],
        mealScore: mealScore, // Add meal score to the post
      );

      debugPrint('📤 Uploading meal post to Firestore...');
      // Create the post document
      await FirebaseFirestore.instance
          .collection('meal_posts')
          .add(mealPost.toMap());
      
      debugPrint('✅ Meal post created successfully');

      if (mounted) {
        Navigator.pop(context);
        // Clear feed caches to force a refresh
        final homeScreenState = context.findAncestorStateOfType<HomeScreenState>();
        if (homeScreenState != null) {
          homeScreenState.setState(() {
            homeScreenState.feedCache['friends'] = [];
            homeScreenState.feedCache['global'] = [];
            homeScreenState.lastFriendsDocument = null;
            homeScreenState.lastGlobalDocument = null;
          });
          // Reload both feeds
          homeScreenState.loadFriendsFeed();
          homeScreenState.loadGlobalFeed();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error creating post: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating post: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _captureImage() async {
    final ImagePicker picker = ImagePicker();
    final _visionService = VisionService.instance;
    
    try {
      await _visionService.initialize();
      
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

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: originalFile.path,
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

      if (croppedFile != null && mounted) {
        final croppedImage = File(croppedFile.path);
        
        // Detect food in the image
        final detectionResults = await _visionService.detectFood(croppedImage);
        
        if (mounted) {
          // Show preview dialog with labels
          final shouldUseImage = await _showPreviewDialog(croppedImage, detectionResults) ?? false;

          if (shouldUseImage) {
            setState(() {
              _selectedPhotos.add(croppedImage);
              _originalPhotos.add(originalFile);
              
              // Auto-fill description with detected items
              final sortedEntries = detectionResults.entries
                  .where((entry) => entry.value > 0)
                  .toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              final topFiveEntries = sortedEntries.take(5).toList();
              final topItems = topFiveEntries.map((e) => e.key).toList();
              
              _descriptionController.text = _generateCleverDescription({
                'detectedIngredients': topItems,
              });
            });
            
            HapticFeedback.lightImpact();

            // Analyze photos if this is the first one
            if (_selectedPhotos.length == 1) {
              await _analyzePhotos();
            }
          }
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

  Future<File> _compressImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      
      // Handle null case
      if (image == null) {
        debugPrint('Warning: Could not decode image, returning original file');
        return file;
      }

      // Now we can safely access width and height since we've checked for null
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

  Future<void> _enhanceSelectedPhoto([int? index]) async {
    if (_selectedPhotos.isEmpty) return;
    
    final photoIndex = index ?? 0;
    if (photoIndex >= _selectedPhotos.length) return;

    final imageFile = _selectedPhotos[photoIndex];
    
    try {
      setState(() => _isLoading = true);
      
      // Show preview dialog with enhancement
      final shouldUseEnhanced = await _showPreviewDialog(
        imageFile,
        {}, // Empty detection results since we're not using them
      );

      if (shouldUseEnhanced == true && mounted) {
        // Download enhanced image
        final enhancedUrl = await _replicateService.enhanceFoodImage(imageFile);
        if (enhancedUrl != null) {
          final response = await http.get(Uri.parse(enhancedUrl));
          final bytes = response.bodyBytes;
          
          // Save enhanced image
          final tempDir = await getTemporaryDirectory();
          final enhancedFile = File(
            '${tempDir.path}/enhanced_${DateTime.now().millisecondsSinceEpoch}.jpg'
          );
          await enhancedFile.writeAsBytes(bytes);

          // Replace original with enhanced
          setState(() {
            _selectedPhotos[photoIndex] = enhancedFile;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Photo enhanced successfully!')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error enhancing photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error enhancing photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
      _originalPhotos.removeAt(index);
    });
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