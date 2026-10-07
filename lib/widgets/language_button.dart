import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:cropsync/widgets/language_selector.dart';

enum LanguageButtonVariant {
  /// Icon-only button for app bars.
  compact,

  /// Pill with the translate icon and current language label.
  pill,
}

/// Single, shared trigger for the app-language bottom sheet.
class LanguageButton extends StatelessWidget {
  final LanguageButtonVariant variant;
  final Color? color;

  /// Pill only: show the full native name instead of the short code.
  final bool fullName;

  /// Pill only: background/border colours (defaults to a neutral tint).
  final Color? pillBackground;
  final Color? pillBorder;

  const LanguageButton({
    super.key,
    this.variant = LanguageButtonVariant.compact,
    this.color,
    this.fullName = false,
    this.pillBackground,
    this.pillBorder,
  });

  const LanguageButton.pill({
    super.key,
    this.color,
    this.fullName = false,
    this.pillBackground,
    this.pillBorder,
  }) : variant = LanguageButtonVariant.pill;

  static const double iconSize = 24;

  static String get tooltipText => 'language_select_title'.tr();

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppTheme.appBarText;
    final tooltip = tooltipText;

    if (variant == LanguageButtonVariant.compact) {
      return IconButton(
        icon: Icon(Icons.translate_rounded, color: fg, size: iconSize),
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        splashRadius: 24,
        onPressed: () => LanguageSelector.show(context),
      );
    }

    final lang = appLanguageFor(context.locale);
    final label = fullName ? lang.nativeName : lang.shortLabel;
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      onTap: () => LanguageSelector.show(context),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => LanguageSelector.show(context),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: pillBackground == null
                ? null
                : BoxDecoration(
                    color: pillBackground,
                    borderRadius: BorderRadius.circular(24),
                    border: pillBorder == null
                        ? null
                        : Border.all(color: pillBorder!, width: 1),
                  ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.translate_rounded, color: fg, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTheme.getTextStyle(
                    context,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Menu-row variant for settings lists (officer / retailer dashboards).
class LanguageListTile extends StatelessWidget {
  final String? title;
  const LanguageListTile({super.key, this.title});

  @override
  Widget build(BuildContext context) {
    final lang = appLanguageFor(context.locale);
    return ListTile(
      leading: const Icon(Icons.translate_rounded),
      title: Text(title ?? LanguageButton.tooltipText),
      trailing: Text(lang.nativeName,
          style: AppTheme.getTextStyle(context,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary)),
      onTap: () => LanguageSelector.show(context),
    );
  }
}
