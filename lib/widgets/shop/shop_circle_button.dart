import 'package:cropsync/theme/app_text.dart';
import 'package:flutter/material.dart';

/// Translucent white 46px circular icon button used on hero top bars.
class ShopCircleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ShopCircleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        textStyle: appStyle(context, size: 12, color: Colors.white),
        child: Material(
          color: Colors.white.withValues(alpha: 0.82),
          shape: const CircleBorder(),
          elevation: 1.5,
          shadowColor: Colors.black26,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(icon, size: 22, color: const Color(0xFF0F172A)),
            ),
          ),
        ),
      ),
    );
  }
}
