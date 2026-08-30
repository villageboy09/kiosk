import 'package:flutter/material.dart';
import 'package:cropsync/theme/app_theme.dart';

class AuthLogoHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final double logoHeight;
  final EdgeInsetsGeometry padding;

  const AuthLogoHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.logoHeight = 54,
    this.padding = const EdgeInsets.only(bottom: 8),
    TextAlign textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE5E7EB),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/logo_t.png',
              height: logoHeight,
              width: logoHeight,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.agriculture_rounded,
                size: logoHeight * 0.8,
                color: const Color(0xFF1B5E20),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    letterSpacing: 0.05,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


