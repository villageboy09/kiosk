import 'package:flutter/material.dart';
import 'package:cropsync/theme/app_theme.dart';

class AuthLogoHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final double logoHeight;
  final TextAlign textAlign;
  final EdgeInsetsGeometry padding;

  const AuthLogoHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.logoHeight = 80,
    this.textAlign = TextAlign.center,
    this.padding = const EdgeInsets.only(bottom: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/logo_t.png',
              height: logoHeight,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.agriculture_rounded,
                size: 64,
                color: Color(0xFF1B5E20),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: textAlign,
            style: const TextStyle(
              
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
              letterSpacing: -1,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: textAlign,
            style: const TextStyle(
              
              fontSize: 16,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.5,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

