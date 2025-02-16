import 'package:flutter/material.dart';
import 'package:recipetok/screens/profile_screen.dart';
import 'package:recipetok/screens/video_screen.dart';
import 'package:recipetok/screens/home_screen.dart';
import 'package:recipetok/screens/discover_screen.dart';
import 'package:recipetok/screens/video_upload_screen.dart';
import 'package:recipetok/screens/meal_post_create_screen.dart';
import 'package:recipetok/models/video.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  final String? userId;
  final Video? initialVideo;
  final bool showBackButton;
  
  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
    this.userId,
    this.initialVideo,
    this.showBackButton = false,
  });

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();

  static Widget buildNavigationBar(BuildContext context, int selectedIndex, Function(int) onTap) {
    return Container(
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
            _buildNavItem(context, 0, Icons.home, 'Home', selectedIndex == 0, onTap),
            _buildNavItem(context, 1, Icons.play_circle_outline, 'Videos', selectedIndex == 1, onTap),
            _buildAddButton(context, onTap),
            _buildNavItem(context, 3, Icons.search, 'Discover', selectedIndex == 3, onTap),
            _buildNavItem(context, 4, Icons.person, 'Profile', selectedIndex == 4, onTap),
          ],
        ),
      ),
    );
  }

  static Widget _buildNavItem(BuildContext context, int index, IconData icon, String label, bool isSelected, Function(int) onTap) {
    return InkWell(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? _getFilledIcon(icon) : icon,
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            size: isSelected ? 28 : 24,
            weight: isSelected ? 700 : 400,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static IconData _getFilledIcon(IconData icon) {
    if (icon == Icons.home) return Icons.home_filled;
    if (icon == Icons.play_circle_outline) return Icons.play_circle_filled;
    if (icon == Icons.search) return Icons.search;
    if (icon == Icons.person) return Icons.person;
    return icon;
  }

  static Widget _buildAddButton(BuildContext context, Function(int) onTap) {
    return InkWell(
      onTap: () => onTap(2),
      child: Container(
        padding: const EdgeInsets.all(8),
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
          size: 26,
        ),
      ),
    );
  }
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
    VideoScreen(
      initialVideo: widget.initialVideo,
      showBackButton: widget.showBackButton,
    ),     // index 1
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
      bottomNavigationBar: MainNavigationScreen.buildNavigationBar(context, _selectedIndex, _onItemTapped),
    );
  }
} 