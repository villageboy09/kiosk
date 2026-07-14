import 'package:flutter/material.dart';

class AppViewport extends StatelessWidget {
  final Widget child;

  const AppViewport({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    // Clamp the text scaling to prevent extreme text size variations from breaking layout
    final clampedData = mediaQuery.copyWith(
      textScaler: mediaQuery.textScaler.clamp(
        minScaleFactor: 0.85,
        maxScaleFactor: 1.15,
      ),
    );

    // Keep mobile completely native and fluid, only constrain huge tablet/web screens
    return MediaQuery(
      data: clampedData,
      child: Container(
        color: const Color(0xFFF3F4F6), // subtle background for web/tablet
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Container(
              color: Colors.white, // App background color
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
