import 'dart:async';

import 'package:cropsync/screens/home_screen.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/operator_auth_service.dart';
import 'package:cropsync/screens/operator/operator_dashboard.dart';
import 'package:cropsync/screens/onboarding/language_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cropsync/auth/signup_screen.dart';
import 'package:cropsync/screens/retailer/retailer_dashboard.dart';
import 'package:cropsync/screens/officer/extension_officer_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
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

    _indicatorFadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
    );

    _controller.forward();
    _redirect();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _redirect() async {
    await Future.delayed(const Duration(seconds: 2));

    // Check sessions
    final sessions = await Future.wait([
      AuthService.isLoggedIn(),
      OperatorAuthService.isLoggedIn(),
    ]);
    final isFarmer = sessions[0];
    final isOperator = sessions[1];

    // Add a small delay for splash screen animation
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    final currentContext = context;
    if (isOperator) {
      await OperatorAuthService.loadSession();
      if (!currentContext.mounted) return;
      Navigator.of(currentContext).pushReplacement(
        MaterialPageRoute(builder: (context) => const OperatorDashboard()),
      );
    } else if (isFarmer) {
      await AuthService.loadUserSession();
      if (!currentContext.mounted) return;
      final user = AuthService.currentUser;
      if (user?.membershipType == 'Retailer') {
        Navigator.of(currentContext).pushReplacement(
          MaterialPageRoute(builder: (context) => const RetailerDashboard()),
        );
      } else if (user?.membershipType == 'Officer') {
        Navigator.of(currentContext).pushReplacement(
          MaterialPageRoute(builder: (context) => const ExtensionOfficerDashboard()),
        );
      } else {
        Navigator.of(currentContext).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final hasSelectedLanguage = prefs.getBool('language_selected') ?? false;

      if (!currentContext.mounted) return;
      if (hasSelectedLanguage) {
        Navigator.of(currentContext).pushReplacement(
          MaterialPageRoute(builder: (context) => const SignupScreen()),
        );
      } else {
        Navigator.of(currentContext).pushReplacement(
          MaterialPageRoute(
              builder: (context) => const LanguageSelectionScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    width: 240,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.agriculture,
                        size: 240,
                        color: Colors.grey[800],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                FadeTransition(
                  opacity: _taglineFadeAnimation,
                  child: Text(
                    'splash_tagline'.tr(),
                    style: const TextStyle(
                      
                      fontSize: 18.0,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                    "splash_connecting".tr(),
                    style: TextStyle(
                      
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

