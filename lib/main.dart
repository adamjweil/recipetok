import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:recipetok/screens/welcome_screen.dart';
import 'package:recipetok/screens/login_screen.dart';
import 'package:recipetok/screens/register_screen.dart';
import 'package:recipetok/screens/profile_screen.dart';
import 'package:recipetok/screens/main_navigation_screen.dart';
import 'package:recipetok/screens/onboarding_screen.dart';
import 'package:recipetok/screens/food_preferences_screen.dart';
import 'package:recipetok/firebase_options.dart';
import 'package:recipetok/screens/auth_wrapper.dart';
import 'package:recipetok/utils/custom_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Clear and reinitialize cache
  await CustomCacheManager.clearCache();
  await CustomCacheManager.initialize();
  
  print('Firebase initialized successfully');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Munchster',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/main': (context) => const MainNavigationScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/food-preferences': (context) => const FoodPreferencesScreen(),
      },
    );
  }
}
