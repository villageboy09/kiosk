import 'package:flutter/material.dart';

/// Intercepts system back: while not [atHome] it calls [onBackToHome] instead
/// of leaving the route; at home the pop proceeds to the previous screen.
class ShopBackGate extends StatelessWidget {
  final bool atHome;
  final VoidCallback onBackToHome;
  final Widget child;

  const ShopBackGate({
    super.key,
    required this.atHome,
    required this.onBackToHome,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: atHome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !atHome) onBackToHome();
      },
      child: child,
    );
  }
}
