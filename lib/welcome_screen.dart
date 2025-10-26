import 'dart:async';

import 'package:cropsync/auth/login_screen.dart';
import 'package:cropsync/main.dart';
import 'package:cropsync/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart'; // Import for translations

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  StreamSubscription<AuthState>? _authSubscription;

  late final AnimationController _controller;
  late final Animation<double> _logoScaleAnimation;
  late final Animation<double> _taglineFadeAnimation;
  late final Animation<double> _indicatorFadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoScaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _taglineFadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    );

    // UPDATED: Animation for the new indicator
    _indicatorFadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeIn), // Fades in last
    );

    _controller.forward();
    _redirect();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _redirect() async {
    await Future.delayed(const Duration(seconds: 2));

    final delayFuture = Future.delayed(const Duration(seconds: 3));
    final sessionFuture = Future(() => supabase.auth.currentSession);

    final results = await Future.wait([sessionFuture, delayFuture]);
    final session = results[0] as Session?;

    if (!mounted) return;

    if (session != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }

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
    // UPDATED: White background
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _logoScaleAnimation,
                  child: Image.asset(
                    'assets/images/logo.png',
                    // UPDATED: Made logo even bigger
                    width: 240,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.agriculture,
                        // UPDATED: Matched icon size to new logo size
                        size: 240,
                        // UPDATED: Darker color for white background
                        color: Colors.grey[800],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                FadeTransition(
                  opacity: _taglineFadeAnimation,
                  child: Text(
                    // UPDATED: Using translation key
                    'splash_tagline'.tr(),
                    style: GoogleFonts.poppins(
                      fontSize: 18.0,
                      // UPDATED: Darker color for white background
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // UPDATED: New "Connecting..." indicator instead of CircularProgressIndicator
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 80.0),
              child: FadeTransition(
                opacity: _indicatorFadeAnimation,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    // UPDATED: Using translation key
                    "splash_connecting".tr(),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
