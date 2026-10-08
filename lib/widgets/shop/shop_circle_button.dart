import 'package:cropsync/theme/app_text.dart';
import 'package:flutter/material.dart';

/// White 46px circular icon button with a hairline border and shadow, so it
/// stays visible on photos, mint app bars and white surfaces alike.
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
          color: Colors.white,
          shape: const CircleBorder(
            side: BorderSide(color: Color(0x1F0F172A), width: 1),
          ),
          elevation: 4,
          shadowColor: Colors.black38,
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
