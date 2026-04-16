import 'package:flutter/material.dart';

class AppViewport extends StatelessWidget {
  final Widget child;

  const AppViewport({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final maxWidth = width >= 1200
            ? 1200.0
            : width >= 900
                ? 900.0
                : double.infinity;
        final horizontalPadding = width >= 900 ? 24.0 : 0.0;

        final mediaQuery = MediaQuery.of(context);

        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
