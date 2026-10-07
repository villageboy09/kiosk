import 'package:cropsync/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final RegExp _teluguScript = RegExp(r'[ఀ-౿]');

/// True when [text] contains Telugu script.
bool appHasTelugu(String text) => _teluguScript.hasMatch(text);

TextStyle _tiro(TextStyle base) => GoogleFonts.tiroTelugu(
      textStyle: base,
    ).copyWith(fontFamilyFallback: AppTheme.fontFallbacks);

/// Style for backend/dynamic text. Tiro Telugu is primary when [text]
/// contains Telugu script OR the app locale is Telugu; fallbacks always set.
TextStyle appTextStyle(BuildContext context, String text, TextStyle base) {
  if (appHasTelugu(text) || AppTheme.isTeluguLocale(context)) {
    return _tiro(base);
  }
  return base.copyWith(fontFamilyFallback: AppTheme.fontFallbacks);
}

/// Style for static UI strings. Tiro Telugu when the locale is Telugu;
/// fallbacks always set.
TextStyle appUiStyle(BuildContext context, [TextStyle? base]) {
  final b = base ?? const TextStyle();
  if (AppTheme.isTeluguLocale(context)) return _tiro(b);
  return b.copyWith(fontFamilyFallback: AppTheme.fontFallbacks);
}

/// Convenience builder on the app's Latin font (Google Sans). When [text] is
/// given the style is treated as dynamic content, otherwise as static UI.
TextStyle appStyle(
  BuildContext context, {
  String? text,
  double? size,
  FontWeight? weight,
  Color? color,
  double? height,
  double? letterSpacing,
  TextDecoration? decoration,
}) {
  final base = GoogleFonts.googleSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    decoration: decoration,
  );
  return text != null
      ? appTextStyle(context, text, base)
      : appUiStyle(context, base);
}
