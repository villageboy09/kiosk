import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/notification_service.dart';

/// A language the app can be switched to.
class AppLanguage {
  final Locale locale;

  /// Label shown in the sheet (native name, plus English name when helpful).
  final String label;

  /// Compact label for pills (e.g. EN / తె / हि).
  final String shortLabel;

  /// Native name only.
  final String nativeName;

  const AppLanguage(this.locale, this.label, this.shortLabel, this.nativeName);

  String get code => locale.languageCode;
}

const List<AppLanguage> kAppLanguages = [
  AppLanguage(Locale('en'), 'English', 'EN', 'English'),
  AppLanguage(Locale('te'), 'తెలుగు (Telugu)', 'తె', 'తెలుగు'),
  AppLanguage(Locale('hi'), 'हिन्दी (Hindi)', 'हि', 'हिन्दी'),
];

AppLanguage appLanguageFor(Locale locale) => kAppLanguages.firstWhere(
      (l) => l.code == locale.languageCode,
      orElse: () => kAppLanguages.first,
    );

final RegExp _teluguScript = RegExp(r'[ఀ-౿]');
final RegExp _devanagariScript = RegExp(r'[ऀ-ॿ]');

/// Script-appropriate text style: Tiro Telugu for Telugu, Noto Sans
/// Devanagari for Hindi, the app font otherwise; always with fallbacks.
TextStyle _scriptStyle(
  BuildContext context,
  String text, {
  required double fontSize,
  required FontWeight fontWeight,
  required Color color,
  double? height,
}) {
  TextStyle base;
  if (_teluguScript.hasMatch(text)) {
    base = GoogleFonts.tiroTelugu(
        fontSize: fontSize, fontWeight: fontWeight, color: color);
  } else if (_devanagariScript.hasMatch(text)) {
    base = GoogleFonts.notoSansDevanagari(
        fontSize: fontSize, fontWeight: fontWeight, color: color);
  } else if (AppTheme.isTeluguLocale(context)) {
    base = GoogleFonts.tiroTelugu(
        fontSize: fontSize, fontWeight: fontWeight, color: color);
  } else {
    base = AppTheme.getTextStyle(context,
        fontSize: fontSize, fontWeight: fontWeight, color: color);
  }
  return base.copyWith(
    height: height,
    fontFamilyFallback: AppTheme.fontFallbacks,
  );
}

class LanguageSelector {
  static void show(BuildContext context) {
    HapticFeedback.lightImpact();
    final currentCode = context.locale.languageCode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.surface,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => _LanguageSheet(
        currentCode: currentCode,
        onSelect: (locale) => _updateLanguage(sheetContext, locale),
      ),
    );
  }

  static Future<void> _updateLanguage(
      BuildContext sheetContext, Locale locale) async {
    HapticFeedback.mediumImpact();
    final navigator = Navigator.of(sheetContext);
    await sheetContext.setLocale(locale);

    // Store that language has been selected
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('language_selected', true);

    // Immediately update push notification topic to the newly selected language
    final user = AuthService.currentUser;
    if (user != null) {
      NotificationService.subscribeToDistrictTopic(user,
          lang: locale.languageCode);
    }

    if (sheetContext.mounted) {
      navigator.pop();
    }
  }
}

class _LanguageSheet extends StatefulWidget {
  final String currentCode;
  final Future<void> Function(Locale) onSelect;

  const _LanguageSheet({required this.currentCode, required this.onSelect});

  @override
  State<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<_LanguageSheet> {
  late String _selected = widget.currentCode;
  bool _busy = false;

  Future<void> _onTap(AppLanguage lang) async {
    if (_busy) return;
    _busy = true;
    setState(() => _selected = lang.code);
    try {
      await widget.onSelect(lang.locale);
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = 'language_select_title'.tr();
    final bottom = MediaQuery.of(context).padding.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(
              title,
              style: _scriptStyle(
                context,
                title,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final lang in kAppLanguages) ...[
            _LanguageOption(
              language: lang,
              isSelected: _selected == lang.code,
              onTap: () => _onTap(lang),
            ),
            if (lang != kAppLanguages.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final AppLanguage language;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.language,
    required this.isSelected,
    required this.onTap,
  });

  static const _duration = Duration(milliseconds: 160);

  @override
  Widget build(BuildContext context) {
    const accent = AppTheme.primary;
    final showEnglish = language.code != 'en';
    final englishName = language.label.contains('(')
        ? language.label
            .substring(language.label.indexOf('(') + 1)
            .replaceAll(')', '')
        : language.label;

    return Semantics(
      button: true,
      selected: isSelected,
      label: language.label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: _duration,
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? accent.withValues(alpha: 0.06)
                  : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? accent : AppTheme.divider,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: _duration,
                  curve: Curves.easeOut,
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? accent : Colors.white,
                    border: Border.all(
                        color: isSelected ? accent : AppTheme.border),
                  ),
                  child: Text(
                    language.code == 'en' ? 'A' : language.shortLabel,
                    style: _scriptStyle(
                      context,
                      language.shortLabel,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppTheme.textOnPrimary
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        language.nativeName,
                        style: _scriptStyle(
                          context,
                          language.nativeName,
                          fontSize: 18,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: AppTheme.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      if (showEnglish)
                        Text(
                          englishName,
                          style: _scriptStyle(
                            context,
                            englishName,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                            height: 1.3,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedOpacity(
                  duration: _duration,
                  opacity: isSelected ? 1 : 0,
                  child: const Icon(Icons.check_circle_rounded,
                      color: accent, size: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
