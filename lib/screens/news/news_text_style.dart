import 'package:cropsync/theme/app_text.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Returns [base] with Telugu/Devanagari font fallbacks. Tiro Telugu becomes
/// primary when [text] contains Telugu script. Delegates to app_text.dart.
TextStyle newsContentStyle(String text, TextStyle base) {
  if (appHasTelugu(text)) {
    return GoogleFonts.tiroTelugu(
      textStyle: base,
    ).copyWith(fontFamilyFallback: AppTheme.fontFallbacks);
  }
  return base.copyWith(fontFamilyFallback: AppTheme.fontFallbacks);
}

/// Style for dynamic text; see [appTextStyle].
TextStyle newsTextStyle(BuildContext context, String text, TextStyle base) =>
    appTextStyle(context, text, base);

/// Style for static UI strings; see [appUiStyle].
TextStyle newsUiStyle(BuildContext context,
        [TextStyle base = const TextStyle()]) =>
    appUiStyle(context, base);

/// True when [text] contains Telugu script.
bool newsHasTelugu(String text) => appHasTelugu(text);

final RegExp _bulletPrefix = RegExp(r'^[-*•–—‣▪●]\s+');

/// One normalized paragraph of an article.
class NewsParagraph {
  final String text;
  final bool isBullet;
  const NewsParagraph(this.text, {this.isBullet = false});
}

/// Splits article [content] into trimmed, non-empty paragraphs. Handles
/// \r\n, repeated blank lines, stray whitespace and bullet-like lines.
List<NewsParagraph> splitNewsParagraphs(String content) {
  final normalized = content
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(' ', ' ')
      .replaceAll(RegExp(r'[  ]'), '\n');
  final result = <NewsParagraph>[];
  for (final raw in normalized.split('\n')) {
    final line = raw.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
    if (line.isEmpty) continue;
    final m = _bulletPrefix.firstMatch(line);
    if (m != null && line.length > m.end) {
      result.add(NewsParagraph(line.substring(m.end).trim(), isBullet: true));
    } else {
      result.add(NewsParagraph(line));
    }
  }
  return result;
}
