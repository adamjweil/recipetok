import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'dart:io' show InternetAddress;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        print('Starting user registration...');
        
        // Add the test calls here
        print('Running Firebase connection tests...');
        await _checkFirebaseConnection();
        await _testFirestore();
        
        // Create user with email and password
        final userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        print('Firebase Auth account created successfully');
        
        // Verify user is authenticated
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          print('Error: User is not authenticated after registration');
          throw Exception('User authentication failed');
        }
        print('Current user ID: ${user.uid}');
        
        // Update user profile with username
        await user.updateDisplayName(_usernameController.text);
        print('Display name updated successfully');

        try {
          // Create user document in Firestore
          print('Attempting to create Firestore document...');
          print('User ID: ${user.uid}');
          print('Is user authenticated? ${user != null}');
          print('User email verified? ${user.emailVerified}');
          print('User email: ${user.email}');
          
          // Wait a moment to ensure auth state is fully propagated
          await Future.delayed(const Duration(seconds: 1));
          
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'username': _usernameController.text,
            'email': _emailController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            'followers': 0,
            'following': 0,
            'videoCount': 0,
            'bio': '',
            'profileImageUrl': user.photoURL ?? '',
          });
          print('Firestore document created successfully');
          
          // Navigate to main screen and remove all previous routes
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/main',
              (route) => false,
            );
          }
        } catch (firestoreError) {
          print('Error creating Firestore document: $firestoreError');
          print('Error details: ${firestoreError.toString()}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating user profile: $firestoreError')),
          );
        }
      } catch (e) {
        print('Error in registration process: $e');
        print('Error details: ${e.toString()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize Google Sign In
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      // Obtain auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with Firebase
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      // Create or update user document in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'username': userCredential.user!.displayName ?? 'User',
        'email': userCredential.user!.email,
        'createdAt': FieldValue.serverTimestamp(),
        'followers': 0,
        'following': 0,
        'videoCount': 0,
        'bio': '',
        'profileImageUrl': userCredential.user!.photoURL ?? '',
      });

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/main',
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

  Future<void> _testFirestore() async {
    try {
      print('Testing Firestore access...');
      final testDoc = await FirebaseFirestore.instance
          .collection('test')
          .doc('test')
          .set({
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('Firestore test successful');
    } catch (e) {
      print('Firestore test failed: $e');
    }
  }

  Future<void> _checkFirebaseConnection() async {
    try {
      final result = await InternetAddress.lookup('firestore.googleapis.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        print('Network connection to Firebase available');
      }
    } catch (e) {
      print('Network connection to Firebase failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Account',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please fill in the form to continue',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Register'),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text('OR', style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: Icon(
                      Icons.g_mobiledata,
                      size: 24,
                      color: Colors.blue,
                    ),
                    label: const Text('Continue with Google'),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    child: const Text('Already have an account? Login'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
} 