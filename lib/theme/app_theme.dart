import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  static const Color background = Color(0xFFFAFAFA);
  static const Color card = Color(0xFFFFFFFF);

  /// Text colors
  static const Color textPrimary = Color(0xFF1A1A1A);
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

  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusFull = 100.0;

  // ============ SHADOWS ============

  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get shadowLg => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get shadowPrimary => [
        BoxShadow(
          color: primary.withValues(alpha: 0.3),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
      ];

  // ============ TYPOGRAPHY ============
  // All styles now include letter spacing for better readability

  /// Headline 1 - Large titles
  static TextStyle get h1 => GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.3,
        letterSpacing: 0.2,
      );

  /// Headline 2 - Section titles
  static TextStyle get h2 => GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.3,
        letterSpacing: 0.2,
      );

  /// Headline 3 - Card titles
  static TextStyle get h3 => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.4,
        letterSpacing: 0.2,
      );

  /// Body text
  static TextStyle get body => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        height: 1.5,
        letterSpacing: 0.2,
      );

  /// Body medium
  static TextStyle get bodyMedium => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        height: 1.5,
        letterSpacing: 0.2,
      );

  /// Caption text
  static TextStyle get caption => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.4,
        letterSpacing: 0.3,
      );

  /// Small text
  static TextStyle get small => GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.4,
        letterSpacing: 0.3,
      );

  /// Button text
  static TextStyle get button => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textOnPrimary,
        height: 1.4,
        letterSpacing: 0.3,
      );

  /// AppBar title
  static TextStyle get appBarTitle => GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textOnPrimary,
        letterSpacing: 0.2,
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

  // ============ DECORATIONS ============

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(radiusLg),
        boxShadow: shadowMd,
      );

  static BoxDecoration get primaryCardDecoration => BoxDecoration(
        gradient: headerGradient,
        borderRadius: BorderRadius.circular(radiusXl),
        boxShadow: shadowPrimary,
      );

  // ============ COMMON WIDGETS ============

  /// Standard back button for app bars
  static Widget backButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radiusMd),
        child: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(radiusMd),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radiusMd),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Color(0xFF1A1A1A),
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
    return GoogleFonts.poppinsTextTheme();
  }
}
