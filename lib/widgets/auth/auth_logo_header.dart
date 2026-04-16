import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
          Image.asset(
            'assets/images/logo_t.png',
            height: logoHeight,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.agriculture_rounded,
              size: 64,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: textAlign,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: textAlign,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFF4B5563),
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
