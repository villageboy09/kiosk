import 'dart:async';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:cropsync/auth/login_screen.dart';
import 'package:cropsync/main.dart';
import 'package:cropsync/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _redirect();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _redirect() async {
    // Wait for the widget to be fully built before proceeding.
    await Future.delayed(Duration.zero);

    // Create two futures: one for the minimum 2-second delay, and one
    // to get the initial session state.
    final delayFuture = Future.delayed(const Duration(seconds: 2));
    final sessionFuture = Future(() => supabase.auth.currentSession);

    // Wait for both the delay and the session check to complete.
    final results = await Future.wait([sessionFuture, delayFuture]);
    final session = results[0] as Session?;

    if (!mounted) return;

    // Navigate based on whether a session was found.
    if (session != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }

    // After the initial check, listen for any future auth changes (like logout).
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      }
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
            Image.asset(
              'assets/images/logo.png',
              width: 150,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.agriculture,
                  size: 150,
                  color: Colors.black,
                );
              },
            ),
            const SizedBox(height: 40),
            DefaultTextStyle(
              style: GoogleFonts.lexend(
                fontSize: 24.0,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
              child: AnimatedTextKit(
                isRepeatingAnimation: false,
                totalRepeatCount: 1,
                animatedTexts: [
                  TypewriterAnimatedText(
                    'Cropsync Kiosk',
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
