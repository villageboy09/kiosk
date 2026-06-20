import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized design system for CropSync
/// Provides consistent colors, typography, and spacing across the app
class AppTheme {
  AppTheme._();

  // ============ COLORS ============

  /// Primary brand colors
  static const Color primary = Color(0xFF111827); // Dark Monochrome
  static const Color primaryLight = Color(0xFF374151);
  static const Color primaryDark = Color(0xFF000000);

  /// Surface colors
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background =
      Color(0xFFF9FAFB); // Slightly cooler, modern grey
  static const Color bg = background; // Alias for backward compatibility
  static const Color card = Color(0xFFFFFFFF);

  /// Text colors
  static const Color textPrimary =
      Color(0xFF111827); // Darker, crisper contrast
  static const Color text = textPrimary; // Alias for backward compatibility
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  /// Semantic colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color errorText = Color(0xFF991B1B);
  static const Color info = Color(0xFF3B82F6);
  static const Color slotBooked =
      Color(0xFF3B82F6); // Using info blue for booked slots

  /// Dividers and borders
  static const Color divider = Color(0xFFE5E7EB);
  static const Color border = Color(0xFFD1D5DB);

  /// Feature card accent colors
  static const Color accentOrange = Color(0xFFE65100);
  static const Color accentBrown = Color(0xFF5D4037);
  static const Color accentBlue = Color(0xFF1565C0);
  static const Color accentPurple = Color(0xFF6A1B9A);
  static const Color accentTeal = Color(0xFF00695C);

  // App Bar Colors
  static const Color appBarBg = Color(0xFFE8F4EC); // Premium sage/mint light green
  static const Color appBarText = Color(0xFF1E3A2F); // Contrast dark green/charcoal

  // ============ GRADIENTS ============

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF111827), Color(0xFF374151)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF111827), Color(0xFF1F2937)],
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

  static List<String> get _fallbacks => [
        GoogleFonts.notoSansTelugu().fontFamily ?? 'Noto Sans Telugu',
        GoogleFonts.notoSansDevanagari().fontFamily ?? 'Noto Sans Devanagari',
      ];

  /// Headline 1 - Large titles
  static TextStyle get h1 => GoogleFonts.googleSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.1,
        letterSpacing: 0.1,
      ).copyWith(fontFamilyFallback: _fallbacks);

  /// Headline 2 - Section titles
  static TextStyle get h2 => GoogleFonts.googleSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.2,
        letterSpacing: 0.1,
      ).copyWith(fontFamilyFallback: _fallbacks);

  /// Headline 3 - Card titles
  static TextStyle get h3 => GoogleFonts.googleSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.3,
        letterSpacing: 0.1,
      ).copyWith(fontFamilyFallback: _fallbacks);

  /// Body text
  static TextStyle get body => GoogleFonts.googleSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.6,
        letterSpacing: 0,
      ).copyWith(fontFamilyFallback: _fallbacks);

  /// Body medium
  static TextStyle get bodyMedium => GoogleFonts.googleSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.5,
        letterSpacing: 0,
      ).copyWith(fontFamilyFallback: _fallbacks);

  /// Caption text
  static TextStyle get caption => GoogleFonts.googleSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textSecondary,
        height: 1.4,
        letterSpacing: 0.1,
      ).copyWith(fontFamilyFallback: _fallbacks);

  /// Small text
  static TextStyle get small => GoogleFonts.googleSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textHint,
        height: 1.4,
        letterSpacing: 0.3,
      ).copyWith(fontFamilyFallback: _fallbacks);

  /// Button text
  static TextStyle get button => GoogleFonts.googleSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textOnPrimary,
        height: 1.2,
        letterSpacing: 0.1,
      ).copyWith(fontFamilyFallback: _fallbacks);

  /// AppBar title
  static TextStyle get appBarTitle => GoogleFonts.googleSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: appBarText,
        letterSpacing: -1,
      ).copyWith(fontFamilyFallback: _fallbacks);

  /// Telugu text style helper — uses GoogleFonts.notoSansTelugu directly
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

  /// Compute a responsive font size based on the layout context.
  /// Uses a baseline width of 375 (logical pixels) with a dampening factor
  /// to ensure safe scaling ranges (0.85 to 1.25 multiplier) across phone/tablet viewports.
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    final double width = MediaQuery.of(context).size.width;
    double scaleFactor = width / 375.0;
    // Apply dampening (0.35 weight) to slow down scaling on tablets/desktops
    double scale = 1.0 + (scaleFactor - 1.0) * 0.35;
    // Clamp to ensure it doesn't shrink or grow too excessively
    scale = scale.clamp(0.85, 1.25);
    return baseSize * scale;
  }

  /// Dynamic locale-aware text style
  static TextStyle getTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    final double? responsiveSize = fontSize != null ? getResponsiveFontSize(context, fontSize) : null;
    TextStyle baseStyle = GoogleFonts.googleSans(
      fontSize: responsiveSize,
      fontWeight: fontWeight,
      color: color ?? textPrimary,
      height: height,
      letterSpacing: letterSpacing,
    );
    
    return baseStyle.copyWith(fontFamilyFallback: _fallbacks);
  }

  // ============ DECORATIONS ============

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: border.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      );

  static BoxDecoration get primaryCardDecoration => BoxDecoration(
        color: textPrimary,
        borderRadius: BorderRadius.circular(radiusXl),
        boxShadow: shadowMd,
      );

  // ============ COMMON WIDGETS ============

  /// Standard back button for app bars
  static Widget backButton(BuildContext context, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (color ?? textPrimary).withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: color ?? textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  /// Modern ThemeData for the entire app
  static ThemeData lightTheme(BuildContext context) {
    // Base text theme driven by Google Fonts
    final baseTextTheme = GoogleFonts.googleSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      textTheme: baseTextTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
        fontFamilyFallback: _fallbacks,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: appBarText,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: getTextStyle(
          context,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: appBarText,
          letterSpacing: -1,
        ),
        iconTheme: const IconThemeData(color: appBarText, size: 22),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: textPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusFull)),
          textStyle: getTextStyle(
            context,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: getTextStyle(
            context,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusFull)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: getTextStyle(
          context,
          color: textHint,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide:
              BorderSide(color: border.withValues(alpha: 0.5), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: textPrimary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: border.withValues(alpha: 0.3)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
      ),
    );
  }
}
