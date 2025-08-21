// ignore_for_file: avoid_print

import 'package:cropsync/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToLogin();
  }

  // Navigate to the login screen after a 3-second delay.
  void _navigateToLogin() {
    Future.delayed(const Duration(seconds: 3), () {
      // Use pushReplacement to prevent the user from navigating back to the splash screen.
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Display the logo.
            // Ensure you have 'logo.png' in 'assets/images/'.
            Image.asset(
              'assets/images/logo.png',
              width: 150,
              // Add a fallback in case the image fails to load.
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.agriculture,
                  size: 150,
                  color: Colors.black,
                );
              },
            ),
            const SizedBox(height: 40),
            // The animated text kit for the typewriter effect.
            DefaultTextStyle(
              // Use GoogleFonts.lexend() to apply the font.
              style: GoogleFonts.lexend(
                fontSize: 24.0,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
              child: AnimatedTextKit(
                isRepeatingAnimation: false,
                animatedTexts: [
                  TypewriterAnimatedText(
                    'Welcome to Cropsync...',
                    speed: const Duration(milliseconds: 100),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
