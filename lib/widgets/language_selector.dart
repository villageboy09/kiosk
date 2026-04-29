import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageSelector {
  static void show(BuildContext context) {
    HapticFeedback.lightImpact();
    final currentLocale = context.locale;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'language_select_title'.tr(),
                style: AppTheme.h2.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 16),
              _LanguageOption(
                title: 'English',
                isSelected: currentLocale.languageCode == 'en',
                onTap: () => _updateLanguage(context, const Locale('en')),
              ),
              const SizedBox(height: 12),
              _LanguageOption(
                title: 'తెలుగు (Telugu)',
                isSelected: currentLocale.languageCode == 'te',
                onTap: () => _updateLanguage(context, const Locale('te')),
              ),
              const SizedBox(height: 12),
              _LanguageOption(
                title: 'हिन्दी (Hindi)',
                isSelected: currentLocale.languageCode == 'hi',
                onTap: () => _updateLanguage(context, const Locale('hi')),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _updateLanguage(BuildContext context, Locale locale) async {
    HapticFeedback.mediumImpact();
    await context.setLocale(locale);
    
    // Store that language has been selected
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('language_selected', true);
    
    if (context.mounted) {
      Navigator.pop(context);
    }
  }
}

class _LanguageOption extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.textPrimary.withValues(alpha: 0.05)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.textPrimary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(
              title,
              style: AppTheme.getTextStyle(
                context,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppTheme.textPrimary : const Color(0xFF4B5563),
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.textPrimary, size: 22)
          ],
        ),
      ),
    );
  }
}
