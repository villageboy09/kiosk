import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';

/// Centralized design system for CropSync
/// Provides consistent colors, typography, and spacing across the app
class AppTheme {
  AppTheme._();

  // ============ COLORS ============

  /// Primary brand colors
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF4CAF50);
  static const Color primaryDark = Color(0xFF1B5E20);

  /// Surface colors
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF9FAFB); // Slightly cooler, modern grey
  static const Color card = Color(0xFFFFFFFF);

  /// Text colors
  static const Color textPrimary = Color(0xFF111827); // Darker, crisper contrast
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  /// Semantic colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  /// Dividers and borders
  static const Color divider = Color(0xFFE5E7EB);
  static const Color border = Color(0xFFD1D5DB);

  /// Feature card accent colors
  static const Color accentOrange = Color(0xFFE65100);
  static const Color accentBrown = Color(0xFF5D4037);
  static const Color accentBlue = Color(0xFF1565C0);
  static const Color accentPurple = Color(0xFF6A1B9A);
  static const Color accentTeal = Color(0xFF00695C);

  // ============ GRADIENTS ============

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ============ SPACING ============

  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 20.0;
  static const double spacingXxl = 24.0;
  static const double spacingXxxl = 32.0;

  // ============ BORDER RADIUS ============

  static const double radiusSm = 12.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 24.0;
  static const double radiusXl = 32.0;
  static const double radiusFull = 100.0;

  // ============ SHADOWS ============

  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: const Color(0xFF111827).withValues(alpha: 0.05),
          blurRadius: 16,
          spreadRadius: -4,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get shadowLg => [
        BoxShadow(
          color: const Color(0xFF111827).withValues(alpha: 0.08),
          blurRadius: 24,
          spreadRadius: -4,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> get shadowPrimary => [
        BoxShadow(
          color: primary.withValues(alpha: 0.25),
          blurRadius: 20,
          spreadRadius: -2,
          offset: const Offset(0, 10),
        ),
      ];

  // ============ TYPOGRAPHY ============
  // Using Google Sans as the primary font and Noto Sans Telugu for regional text

  /// Headline 1 - Large titles
  static TextStyle get h1 => const TextStyle(
        fontFamily: 'Google Sans',
        fontSize: 32, // larger
        fontWeight: FontWeight.w800, // bolder
        color: textPrimary,
        height: 1.1, // tighter 
        letterSpacing: -0.5, // tighter
      );

  /// Headline 2 - Section titles
  static TextStyle get h2 => const TextStyle(
        fontFamily: 'Google Sans',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.2,
        letterSpacing: -0.3,
      );

  /// Headline 3 - Card titles
  static TextStyle get h3 => const TextStyle(
        fontFamily: 'Google Sans',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.3,
        letterSpacing: -0.2,
      );

  /// Body text
  static TextStyle get body => const TextStyle(
        fontFamily: 'Google Sans',
        fontSize: 16, // slightly larger base
        fontWeight: FontWeight.w400,
        color: textSecondary, // Subtler default body color
        height: 1.6,
        letterSpacing: 0,
      );

  /// Body medium
  static TextStyle get bodyMedium => const TextStyle(
        fontFamily: 'Google Sans',
        fontSize: 15,
        fontWeight: FontWeight.w600, // Punchier labels
        color: textPrimary, // Stronger
        height: 1.5,
        letterSpacing: 0,
      );

  /// Caption text
  static TextStyle get caption => const TextStyle(
        fontFamily: 'Google Sans',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textSecondary,
        height: 1.4,
        letterSpacing: 0.1,
      );

  /// Small text
  static TextStyle get small => const TextStyle(
        fontFamily: 'Google Sans',
        fontSize: 12,
        fontWeight: FontWeight.w600, // Bolder tiny text for legibility
        color: textHint,
        height: 1.4,
        letterSpacing: 0.3,
      );

  /// Button text
  static TextStyle get button => const TextStyle(
        fontFamily: 'Google Sans',
        fontSize: 16, // larger button text
        fontWeight: FontWeight.w700,
        color: textOnPrimary,
        height: 1.2,
        letterSpacing: 0.1,
      );

  /// AppBar title
  static TextStyle get appBarTitle => const TextStyle(
        fontFamily: 'Google Sans',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimary, // Changed to dark text
        letterSpacing: -0.2,
      );

  /// Telugu text style helper
  static TextStyle teluguText({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = textPrimary,
  }) =>
      GoogleFonts.notoSansTelugu(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: 0.3,
      );

  /// Dynamic locale-aware text style
  static TextStyle getTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    if (EasyLocalization.of(context)?.locale.languageCode == 'te') {
      return GoogleFonts.notoSansTelugu(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? textPrimary,
        height: height,
        letterSpacing: letterSpacing ?? 0.3,
      );
    }
    return TextStyle(
      fontFamily: 'Google Sans',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? textPrimary,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // ============ DECORATIONS ============

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: border.withValues(alpha: 0.3)), // Subtle edge
        boxShadow: [
           BoxShadow(
             color: Colors.black.withValues(alpha: 0.02),
             blurRadius: 10,
             offset: const Offset(0, 4)
           )
        ], // Lighter shadow
      );

  static BoxDecoration get primaryCardDecoration => BoxDecoration(
        color: textPrimary, // Dark contrast instead of green gradient
        borderRadius: BorderRadius.circular(radiusXl),
        boxShadow: shadowMd,
      );

  // ============ COMMON WIDGETS ============

  /// Standard back button for app bars
  static Widget backButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.transparent, // transparent background
        shape: const CircleBorder(), // Circular touch effect
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(50),
          child: Container(
             padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.03), // very subtle backgrround
              // No border
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 20, // slightly larger
              color: textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  /// Get text theme based on locale
  static TextTheme getTextTheme(String languageCode) {
    if (languageCode == 'te') {
      return GoogleFonts.notoSansTeluguTextTheme();
    }
    return GoogleFonts.openSansTextTheme(); // Fallback to Open Sans if Google Sans is unavailable via font family
  }
}
