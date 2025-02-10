import 'package:flutter/material.dart';
import 'package:recipetok/screens/profile_screen.dart';
import 'package:recipetok/screens/video_screen.dart';
import 'package:recipetok/screens/home_screen.dart';
import 'package:recipetok/screens/users_screen.dart';
import 'package:recipetok/screens/video_upload_screen.dart';
import 'package:recipetok/screens/meal_post_create_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  // Placeholder screens - adjust order to match navigation items
  final List<Widget> _screens = [
    const HomeScreen(),      // index 0
    const VideoScreen(),     // index 1
    Container(),            // index 2 (placeholder for center button)
    const UsersScreen(),     // index 3
    const ProfileScreen(),   // index 4
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      _showCreateOptions();
    } else {
      setState(() {
        _selectedIndex = index;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: SizedBox(
        height: 120,
        child: BottomNavigationBar(
          items: <BottomNavigationBarItem>[
            const BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.play_circle_outline),
              label: 'Videos',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(12),
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
                      spreadRadius: 2,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              label: '',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Users',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          iconSize: 24,
          selectedIconTheme: const IconThemeData(size: 24),
          unselectedIconTheme: const IconThemeData(size: 24),
          backgroundColor: Colors.white,
          elevation: 0,
          landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
          onTap: (index) {
            if (index == 2) {
              _showCreateOptions();
            } else {
              _onItemTapped(index);
            }
          },
        ),
      ),
    );
  }
} 