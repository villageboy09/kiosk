import 'package:cropsync/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Custom Deep Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B5E20), // Deep Green (800)
                  Color(0xFF000000), // Black
                ],
                stops: [0.2, 0.9],
              ),
            ),
          ),

          // 2. Content Overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title
                  Text(
                    'Choose your language',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 60),

                  // Pyramid Layout
                  // Top Row: English (Centered)
                  const Center(
                    child: SizedBox(
                      width: 140, // Square width
                      height: 140, // Square height
                      child: _LanguageCard(
                        character: 'A',
                        label: 'English',
                        locale: Locale('en'),
                        color: Colors.white,
                        textColor: Colors.black,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24), // Spacing between rows

                  // Bottom Row: Hindi & Telugu (Side-by-Side)
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: _LanguageCard(
                          character: 'अ',
                          label: 'हिंदी',
                          locale: Locale('hi'),
                          color: Colors.white,
                          textColor: Colors.black,
                        ),
                      ),
                      SizedBox(width: 24), // Spacing between cards
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: _LanguageCard(
                          character: 'అ',
                          label: 'తెలుగు',
                          locale: Locale('te'),
                          color: Colors.white,
                          textColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// A reusable SQUARE card widget for language selection
class _LanguageCard extends StatelessWidget {
  final String character;
  final String label;
  final Locale locale;
  final Color color;
  final Color textColor;

  const _LanguageCard({
    required this.character,
    required this.label,
    required this.locale,
    required this.color,
    required this.textColor,
  });

  void _onLanguageSelected(BuildContext context) async {
    await context.setLocale(locale);

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SplashScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      child: InkWell(
        onTap: () => _onLanguageSelected(context),
        borderRadius: BorderRadius.circular(20),
        splashColor: Colors.green.withValues(alpha: 0.2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              character,
              style: GoogleFonts.poppins(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
