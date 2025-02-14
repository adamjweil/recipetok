import 'package:flutter/material.dart';
import 'package:recipetok/screens/profile_screen.dart';
import 'package:recipetok/screens/video_screen.dart';
import 'package:recipetok/screens/home_screen.dart';
import 'package:recipetok/screens/discover_screen.dart';
import 'package:recipetok/screens/video_upload_screen.dart';
import 'package:recipetok/screens/meal_post_create_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  final String? userId;
  
  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
    this.userId,
  });

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _selectedIndex;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _currentUserId = widget.userId;
  }

  List<Widget> get _screens => [
    const HomeScreen(),      // index 0
    const VideoScreen(),     // index 1
    Container(),            // index 2 (placeholder for center button)
    const DiscoverScreen(),  // index 3 - replaced UsersScreen
    ProfileScreen(
      userId: _currentUserId,
      showBackButton: false,  // Set showBackButton to false
    ),   // index 4
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      _showCreateOptions();
    } else {
      setState(() {
        _selectedIndex = index;
        if (index == 4) {
          _currentUserId = null; // Reset to current user's profile when profile tab is tapped
        }
      });
    }
  }

  void _showCreateOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.video_library,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              title: const Text('Upload Video'),
              subtitle: const Text('Share your cooking process'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VideoUploadScreen(),
                  ),
                );
              },
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
                  Icons.restaurant,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              title: const Text('Create Meal Post'),
              subtitle: const Text('Share photos of your meal'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MealPostCreateScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void navigateToUserProfile(String userId) {
    setState(() {
      _selectedIndex = 4;  // Switch to profile tab
      _currentUserId = userId;  // Set the user ID
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 17, left: 16, right: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home, 'Home'),
              _buildNavItem(1, Icons.play_circle_outline, 'Videos'),
              _buildAddButton(),
              _buildNavItem(3, Icons.search, 'Discover'),
              _buildNavItem(4, Icons.person, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            size: 24, // Increased from 20
          ),
          const SizedBox(height: 2), // Increased from 1
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
              fontSize: 11, // Increased from 9
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return InkWell(
      onTap: _showCreateOptions,
      child: Container(
        padding: const EdgeInsets.all(8), // Increased from 6
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.8),
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: Colors.white,
            width: 1.5,
          ),
        ),
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 26, // Increased from 22
        ),
      ),
    );
  }
} 