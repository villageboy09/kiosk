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

    // Provide safe text scaling while allowing the app to fluidly adapt to actual screen sizes
    return MediaQuery(
      data: clampedData,
      child: child,
    );
  }
}
