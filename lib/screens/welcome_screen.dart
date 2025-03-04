import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.restaurant,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Neon Red M
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF1744).withOpacity(0.6),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          'M',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 96,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            color: const Color(0xFFFF1744), // Neon Red
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Neon Green N
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF39FF14).withOpacity(0.5),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          'N',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 96,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            color: const Color(0xFF39FF14), // Neon Green
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Neon Orange C
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B08).withOpacity(0.5),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          'C',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 96,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            color: const Color(0xFFFF6B08), // Neon Orange
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Neon Blue H
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00FFFF).withOpacity(0.5),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          'H',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 96,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            color: const Color(0xFF00FFFF), // Neon Blue
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Share your culinary creations\nwith the world',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.cake, color: Colors.white70),
                      SizedBox(width: 16),
                      Icon(Icons.local_pizza, color: Colors.white70),
                      SizedBox(width: 16),
                      Icon(Icons.coffee, color: Colors.white70),
                      SizedBox(width: 16),
                      Icon(Icons.restaurant_menu, color: Colors.white70),
                    ],
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Login'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Register'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Join our community of food lovers',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 