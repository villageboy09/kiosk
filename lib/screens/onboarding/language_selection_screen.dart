import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cropsync/auth/signup_screen.dart';
import 'package:cropsync/navigation/app_routes.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String _selectedLocale = 'te'; // Default to Telugu as per main.dart

  final List<Map<String, String>> _languages = [
    {'name': 'Telugu', 'code': 'te', 'native': 'తెలుగు'},
    {'name': 'Hindi', 'code': 'hi', 'native': 'हिन्दी'},
    {'name': 'English', 'code': 'en', 'native': 'English'},
  ];

  @override
  void initState() {
    super.initState();
    // Use a small delay to ensure context is ready if needed,
    // but here we just want to sync with current locale if already set.
    Future.microtask(() {
      if (mounted) {
        setState(() {
          _selectedLocale = context.locale.languageCode;
        });
      }
    });
  }

  void _onLanguageTap(String code) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedLocale = code;
    });
    context.setLocale(Locale(code));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Image.asset(
                  'assets/images/logo_t.png',
                  height: 80,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.agriculture_rounded,
                    size: 64,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'choose_language'.tr(),
                style: const TextStyle(
                  
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'change_later_settings'.tr(),
                style: const TextStyle(
                  
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: _languages.length,
                  itemBuilder: (context, index) {
                    final lang = _languages[index];
                    final isSelected = _selectedLocale == lang['code'];

                    return GestureDetector(
                      onTap: () => _onLanguageTap(lang['code']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected
                                ? Colors.black
                                : const Color(0xFFE5E7EB),
                            width: isSelected ? 2.5 : 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : [],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              lang['native']!,
                              style: TextStyle(
                                
                                fontSize: 22,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? Colors.black
                                    : const Color(0xFF374151),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  final currentContext = context;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('language_selected', true);
                  if (!currentContext.mounted) return;
                  Navigator.of(currentContext).pushReplacement(
                    AppRoutes.fade(const SignupScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 64),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'continue'.tr(),
                  style: const TextStyle(
                    
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

