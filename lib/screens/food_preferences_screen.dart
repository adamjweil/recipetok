import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recipetok/screens/main_navigation_screen.dart';

class FoodPreferencesScreen extends StatefulWidget {
  const FoodPreferencesScreen({super.key});

  @override
  State<FoodPreferencesScreen> createState() => _FoodPreferencesScreenState();
}

class _FoodPreferencesScreenState extends State<FoodPreferencesScreen> {
  final Set<String> _selectedPreferences = {};
  bool _isLoading = false;

  // List of food types with their respective icons
  final List<Map<String, dynamic>> _foodTypes = [
    {'name': 'Italian', 'icon': Icons.local_pizza},
    {'name': 'Japanese', 'icon': Icons.ramen_dining},
    {'name': 'Mexican', 'icon': Icons.local_dining},
    {'name': 'Chinese', 'icon': Icons.rice_bowl},
    {'name': 'Indian', 'icon': Icons.restaurant},
    {'name': 'Thai', 'icon': Icons.soup_kitchen},
    {'name': 'Mediterranean', 'icon': Icons.kebab_dining},
    {'name': 'American', 'icon': Icons.lunch_dining},
    {'name': 'Korean', 'icon': Icons.dining},
    {'name': 'Vietnamese', 'icon': Icons.ramen_dining},
    {'name': 'French', 'icon': Icons.bakery_dining},
    {'name': 'Greek', 'icon': Icons.local_dining},
  ];

  Future<void> _continue() async {
    if (_selectedPreferences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one food type')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user found');

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'foodPreferences': _selectedPreferences.toList(),
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const MainNavigationScreen(initialIndex: 0),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What are your favorite types of food?',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Here is a peek at what Munchster has to offer (select at least one).',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: _foodTypes.length,
                  itemBuilder: (context, index) {
                    final foodType = _foodTypes[index];
                    final isSelected = _selectedPreferences.contains(foodType['name']);
                    
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedPreferences.remove(foodType['name']);
                          } else {
                            _selectedPreferences.add(foodType['name']);
                          }
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              foodType['icon'],
                              color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              foodType['name'],
                              style: TextStyle(
                                color: isSelected ? Theme.of(context).primaryColor : Colors.grey[800],
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedPreferences.isNotEmpty && !_isLoading ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedPreferences.isNotEmpty ? Theme.of(context).primaryColor : Colors.grey[200],
                    foregroundColor: _selectedPreferences.isNotEmpty ? Colors.white : Colors.grey[600],
                    disabledBackgroundColor: Colors.grey[200],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 