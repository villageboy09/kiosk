import 'package:cropsync/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title Text
                Text(
                  'Choose your language',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 40),

                // Language Cards
                const LanguageCard(
                  language: 'English',
                  locale: Locale('en'),
                ),
                const SizedBox(height: 16),
                const LanguageCard(
                  language: 'हिंदी', // Hindi
                  locale: Locale('hi'),
                ),
                const SizedBox(height: 16),
                const LanguageCard(
                  language: 'తెలుగు', // Telugu
                  locale: Locale('te'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// A reusable card widget for language selection
class LanguageCard extends StatelessWidget {
  final String language;
  final Locale locale;

  const LanguageCard({
    super.key,
    required this.language,
    required this.locale,
  });

  // UPDATED: Made this method 'async'
  void _onLanguageSelected(BuildContext context) async {
    // UPDATED: 'await' the locale change to complete
    await context.setLocale(locale);

    // Add a check to ensure the widget is still on screen
    if (context.mounted) {
      // Navigate to the SplashScreen and remove this page from the stack
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SplashScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _onLanguageSelected(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            // Minimalistic shadow
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Center(
          child: Text(
            language,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
