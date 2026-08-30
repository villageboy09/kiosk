import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cropsync/auth/signup_screen.dart';
import 'package:cropsync/navigation/app_routes.dart';
import 'package:cropsync/theme/app_theme.dart';

class LanguageItem {
  final String name;
  final String code;
  final String native;
  final String greeting;
  final String token;
  final Color accentColor;
  final Color lightAccentColor;

  const LanguageItem({
    required this.name,
    required this.code,
    required this.native,
    required this.greeting,
    required this.token,
    required this.accentColor,
    required this.lightAccentColor,
  });
}

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen>
    with SingleTickerProviderStateMixin {
  String _selectedLocale = 'te'; // Default to Telugu

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  static const List<LanguageItem> _languages = [
    LanguageItem(
      name: 'Telugu',
      code: 'te',
      native: 'తెలుగు',
      greeting: 'నమస్కారం • Namaskaram',
      token: 'తె',
      accentColor: Color(0xFF1B5E20),
      lightAccentColor: Color(0xFFE8F5E9),
    ),
    LanguageItem(
      name: 'Hindi',
      code: 'hi',
      native: 'हिन्दी',
      greeting: 'नमस्ते • Namaste',
      token: 'अ',
      accentColor: Color(0xFFC2410C),
      lightAccentColor: Color(0xFFFFF7ED),
    ),
    LanguageItem(
      name: 'English',
      code: 'en',
      native: 'English',
      greeting: 'Welcome • Hello',
      token: 'Aa',
      accentColor: Color(0xFF1E3A8A),
      lightAccentColor: Color(0xFFEEF2FF),
    ),
  ];

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0.0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward();

    // Sync state with active locale if already set
    Future.microtask(() {
      if (mounted) {
        setState(() {
          _selectedLocale = context.locale.languageCode;
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onLanguageTap(String code) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedLocale = code;
    });
    context.setLocale(Locale(code));
  }

  Future<void> _onContinue() async {
    HapticFeedback.mediumImpact();
    final currentContext = context;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('language_selected', true);
    if (!currentContext.mounted) return;
    Navigator.of(currentContext).pushReplacement(
      AppRoutes.fade(const SignupScreen()),
    );
  }

  TextStyle _getNativeFontStyle(String code, {required bool isSelected, double fontSize = 21}) {
    switch (code) {
      case 'te':
        return GoogleFonts.notoSansTelugu(
          fontSize: fontSize,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
          color: isSelected ? AppTheme.textPrimary : const Color(0xFF1F2937),
          height: 1.2,
        );
      case 'hi':
        return GoogleFonts.notoSansDevanagari(
          fontSize: fontSize,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
          color: isSelected ? AppTheme.textPrimary : const Color(0xFF1F2937),
          height: 1.2,
        );
      case 'en':
      default:
        return GoogleFonts.googleSans(
          fontSize: fontSize - 1,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
          color: isSelected ? AppTheme.textPrimary : const Color(0xFF1F2937),
          height: 1.2,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final clampedData = mediaQuery.copyWith(
      textScaler: mediaQuery.textScaler.clamp(
        minScaleFactor: 0.85,
        maxScaleFactor: 1.25,
      ),
    );

    return MediaQuery(
      data: clampedData,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              final isShortScreen = constraints.maxHeight < 680;

              final verticalPadding = isShortScreen ? 20.0 : 36.0;
              final horizontalPadding = isWide ? 32.0 : 20.0;
              final contentMaxWidth = isWide
                  ? min(1140.0, constraints.maxWidth - (horizontalPadding * 2))
                  : 480.0;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: isShortScreen ? 12.0 : 24.0,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - verticalPadding,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: contentMaxWidth,
                      ),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Clean Top Branding Header without smart krishi tag
                                  _buildHeader(isShortScreen, isWide),

                                  SizedBox(
                                    height: isShortScreen
                                        ? 16.0
                                        : (isWide ? 36.0 : 24.0),
                                  ),

                                  // Language Cards: Adaptive Row on Wide Screen/Tab, Stack on Phone
                                  if (isWide)
                                    _buildWideCardsGrid(isShortScreen)
                                  else
                                    _buildPhoneCardsList(isShortScreen),
                                ],
                              ),

                              Padding(
                                padding: EdgeInsets.only(
                                  top: isShortScreen ? 16.0 : 32.0,
                                  bottom: 12.0,
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: isWide ? 460.0 : double.infinity,
                                    ),
                                    child: _buildContinueButton(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isShortScreen, bool isWide) {
    return Column(
      children: [
        SizedBox(height: isShortScreen ? 8 : (isWide ? 20 : 14)),

        // Brand Logo
        Hero(
          tag: 'app_logo_hero',
          child: Image.asset(
            'assets/images/logo_t.png',
            height: isShortScreen ? 58 : (isWide ? 92 : 72),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.agriculture_rounded,
                size: 48,
                color: Color(0xFF1B5E20),
              ),
            ),
          ),
        ),

        SizedBox(height: isShortScreen ? 14 : (isWide ? 24 : 18)),

        // Title
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            'choose_language'.tr(),
            key: ValueKey('title_$_selectedLocale'),
            style: GoogleFonts.googleSans(
              fontSize: isShortScreen ? 24 : (isWide ? 32 : 28),
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 8),

        // Subtitle
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            'change_later_settings'.tr(),
            key: ValueKey('sub_$_selectedLocale'),
            style: GoogleFonts.googleSans(
              fontSize: isShortScreen ? 14 : (isWide ? 16 : 15),
              color: const Color(0xFF4B5563),
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneCardsList(bool isShortScreen) {
    return Column(
      children: _languages.map((lang) {
        final isSelected = _selectedLocale == lang.code;
        return Padding(
          padding: EdgeInsets.only(bottom: isShortScreen ? 10.0 : 14.0),
          child: _buildPhoneLanguageCard(lang, isSelected: isSelected),
        );
      }).toList(),
    );
  }

  Widget _buildWideCardsGrid(bool isShortScreen) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: _languages.map((lang) {
        final isSelected = _selectedLocale == lang.code;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: _buildWideLanguageCard(lang, isSelected: isSelected, isShortScreen: isShortScreen),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPhoneLanguageCard(
    LanguageItem lang, {
    required bool isSelected,
  }) {
    final nativeStyle = _getNativeFontStyle(lang.code, isSelected: isSelected, fontSize: 21);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onLanguageTap(lang.code),
        borderRadius: BorderRadius.circular(20),
        splashColor: lang.accentColor.withValues(alpha: 0.1),
        highlightColor: lang.accentColor.withValues(alpha: 0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFAFAFA) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppTheme.textPrimary
                  : const Color(0xFFE5E7EB),
              width: isSelected ? 2.2 : 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.textPrimary.withValues(alpha: 0.08),
                      blurRadius: 16,
                      spreadRadius: -2,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Language Script Token Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected ? lang.accentColor : lang.lightAccentColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  lang.token,
                  style: GoogleFonts.notoSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : lang.accentColor,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Text Info (Native Name, English Name & Greeting)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            lang.native,
                            style: nativeStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${lang.name})',
                          style: GoogleFonts.googleSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFF374151)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lang.greeting,
                      style: GoogleFonts.googleSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF4B5563)
                            : const Color(0xFF9CA3AF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Modern Selection Indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppTheme.textPrimary : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.textPrimary
                        : const Color(0xFFD1D5DB),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideLanguageCard(
    LanguageItem lang, {
    required bool isSelected,
    required bool isShortScreen,
  }) {
    final nativeStyle = _getNativeFontStyle(lang.code, isSelected: isSelected, fontSize: 24);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onLanguageTap(lang.code),
        borderRadius: BorderRadius.circular(24),
        splashColor: lang.accentColor.withValues(alpha: 0.1),
        highlightColor: lang.accentColor.withValues(alpha: 0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: isShortScreen ? 20 : 32,
          ),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFAFAFA) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? AppTheme.textPrimary
                  : const Color(0xFFE5E7EB),
              width: isSelected ? 2.4 : 1.4,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.textPrimary.withValues(alpha: 0.08),
                      blurRadius: 20,
                      spreadRadius: -2,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Token Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isSelected ? lang.accentColor : lang.lightAccentColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  lang.token,
                  style: GoogleFonts.notoSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : lang.accentColor,
                  ),
                ),
              ),

              SizedBox(height: isShortScreen ? 14 : 20),

              // Native Name
              Text(
                lang.native,
                style: nativeStyle,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 4),

              // English Name / Subtitle
              Text(
                lang.code == 'en' ? 'International' : lang.name,
                style: GoogleFonts.googleSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF374151)
                      : const Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Greeting
              Text(
                lang.greeting,
                style: GoogleFonts.googleSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF9CA3AF),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              SizedBox(height: isShortScreen ? 14 : 22),

              // Selection Radio Circle
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppTheme.textPrimary : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.textPrimary
                        : const Color(0xFFD1D5DB),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return ElevatedButton(
      onPressed: _onContinue,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.textPrimary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 60),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              'continue'.tr(),
              key: ValueKey('continue_$_selectedLocale'),
              style: GoogleFonts.googleSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 20,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}




