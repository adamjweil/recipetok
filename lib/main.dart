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
import 'services/deep_link_service.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';

Future<void> main() async {
  try {
    // Ensure Flutter is initialized
    WidgetsFlutterBinding.ensureInitialized();
    
    // Load environment variables
    await dotenv.load(fileName: ".env");
    
    // Initialize Firebase first
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Clear and reinitialize cache
    await CustomCacheManager.clearCache();
    await CustomCacheManager.initialize();
    
    print('Firebase initialized successfully');
    runApp(const MyApp());
  } catch (e) {
    print('Error during initialization: $e');
    rethrow;
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final DeepLinkService _deepLinkService = DeepLinkService();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Wait for widget to be built before initializing dynamic links
      await Future.delayed(Duration.zero);
      if (!mounted) return;

      // Initialize dynamic links
      final initialLink = await FirebaseDynamicLinks.instance.getInitialLink();
      print('Initial dynamic link: ${initialLink?.link}');

      if (mounted) {
        setState(() {
          _initialized = true;
        });
        _deepLinkService.initDynamicLinks(context);
      }
    } catch (e) {
      print('Error initializing dynamic links: $e');
      // Continue with app initialization even if dynamic links fail
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

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
