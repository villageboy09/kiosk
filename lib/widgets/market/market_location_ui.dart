import 'package:cropsync/models/market_location.dart';
import 'package:cropsync/theme/app_text.dart';
import 'package:cropsync/widgets/market/market_logic.dart';
import 'package:cropsync/widgets/shop/shop_filters.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

const Color _kMuted = Color(0xFF64748B);

// ------------------------------------------------------------------ chip

/// Tappable "Near you · District, State" pill under the app bar.
class MarketLocationChip extends StatelessWidget {
  final MarketLocation? location;
  final bool detecting;
  final VoidCallback onTap;

  const MarketLocationChip({
    super.key,
    required this.location,
    required this.detecting,
    required this.onTap,
  });

  static String labelFor(BuildContext context, MarketLocation loc) {
    final place = placeLabel(loc);
    switch (loc.source) {
      case MarketLocationSource.gps:
      case MarketLocationSource.cached:
        return context.tr('mktui_loc_gps', namedArgs: {'place': place});
      case MarketLocationSource.profile:
        return context.tr('mktui_loc_profile', namedArgs: {'place': place});
      case MarketLocationSource.manual:
        return context.tr('mktui_loc_manual', namedArgs: {'place': place});
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = location;
    final label = loc != null && loc.state.isNotEmpty
        ? labelFor(context, loc)
        : (detecting
            ? context.tr('detecting_location')
            : context.tr('mktui_loc_pick'));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: LayoutBuilder(
        builder: (context, box) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: box.maxWidth * 0.9),
            child: Semantics(
              button: true,
              label: label,
              excludeSemantics: true,
              onTap: onTap,
              child: Material(
                color: const Color(0xFFE7F5EE),
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: onTap,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          detecting && (loc == null || loc.state.isEmpty)
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: kShopGreen),
                                )
                              : const Icon(Icons.place_rounded,
                                  size: 18, color: kShopGreen),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: appStyle(context,
                                  text: label,
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: kShopGreen,
                                  height: 1.3),
                            ),
                          ),
                          const Icon(Icons.expand_more_rounded,
                              size: 20, color: kShopGreen),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- banner

enum MarketBannerTone { warning, info }

/// Inline, non-blocking message with an optional action and dismiss button.
class MarketBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final MarketBannerTone tone;

  const MarketBanner({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.tone = MarketBannerTone.warning,
  });

  @override
  Widget build(BuildContext context) {
    final warn = tone == MarketBannerTone.warning;
    final bg = warn ? const Color(0xFFFFF7E6) : const Color(0xFFEFF6FF);
    final fg = warn ? const Color(0xFF92400E) : const Color(0xFF1E40AF);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              12, 10, onDismiss == null ? 12 : 4, actionLabel == null ? 10 : 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 18, color: fg),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: appStyle(context,
                          text: message,
                          size: 12.5,
                          weight: FontWeight.w500,
                          color: fg,
                          height: 1.4),
                    ),
                    if (actionLabel != null)
                      TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: fg,
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                          minimumSize: const Size(48, 44),
                          alignment: AlignmentDirectional.centerStart,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          actionLabel!,
                          style: appStyle(context,
                              text: actionLabel!,
                              size: 13,
                              weight: FontWeight.w800,
                              color: fg,
                              height: 1.3),
                        ),
                      ),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  tooltip: context.tr('mktui_dismiss'),
                  constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.close_rounded, size: 18, color: fg),
                  onPressed: onDismiss,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- state panel

/// Centered message used for errors and the "choose your state" state.
class MarketStatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final List<({String label, VoidCallback onTap, bool primary})> actions;

  const MarketStatePanel({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actions = const [],
  });

  ButtonStyle _style(BuildContext context, bool primary) {
    final text = appStyle(context,
        size: 14,
        weight: FontWeight.w700,
        color: primary ? Colors.white : kShopInk);
    final base = primary
        ? ElevatedButton.styleFrom(
            backgroundColor: kShopGreen,
            foregroundColor: Colors.white,
            elevation: 0)
        : OutlinedButton.styleFrom(
            foregroundColor: kShopInk,
            side: const BorderSide(color: Color(0xFFE2E8F0)));
    return base.copyWith(
      textStyle: WidgetStatePropertyAll(text),
      minimumSize: const WidgetStatePropertyAll(Size(160, 44)),
      shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
                color: Color(0xFFEFF3F7), shape: BoxShape.circle),
            child: Icon(icon, size: 34, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: appStyle(context,
                text: title,
                size: 16,
                weight: FontWeight.w800,
                color: kShopInk,
                height: 1.4),
          ),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: appStyle(context,
                  text: body!, size: 13.5, color: _kMuted, height: 1.45),
            ),
          ],
          for (final a in actions) ...[
            const SizedBox(height: 12),
            a.primary
                ? ElevatedButton(
                    style: _style(context, true),
                    onPressed: a.onTap,
                    child: Text(a.label, textAlign: TextAlign.center),
                  )
                : OutlinedButton(
                    style: _style(context, false),
                    onPressed: a.onTap,
                    child: Text(a.label, textAlign: TextAlign.center),
                  ),
          ],
        ],
      ),
    );
  }
}
