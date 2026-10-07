import 'package:cropsync/theme/app_text.dart';
import 'package:cropsync/utils/seed_logic.dart';
import 'package:cropsync/widgets/shop/shop_filters.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

String seedSortLabel(BuildContext context, SeedSort s) {
  switch (s) {
    case SeedSort.defaultOrder:
      return context.tr('shop_sort_default');
    case SeedSort.newest:
      return context.tr('shop_sort_newest');
    case SeedSort.yieldHigh:
      return context.tr('seedui_sort_yield_high');
    case SeedSort.durationShort:
      return context.tr('seedui_sort_duration_short');
    case SeedSort.priceLow:
      return context.tr('price_low_to_high');
  }
}

/// Bottom sheet with sort + quick toggles. Returns the applied filters, or
/// null when dismissed.
Future<SeedFilters?> showSeedFiltersSheet(
  BuildContext context,
  SeedFilters current,
) {
  return showModalBottomSheet<SeedFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SeedFiltersSheet(initial: current),
  );
}

class SeedFiltersSheet extends StatefulWidget {
  final SeedFilters initial;
  const SeedFiltersSheet({super.key, required this.initial});

  @override
  State<SeedFiltersSheet> createState() => _SeedFiltersSheetState();
}

class _SeedFiltersSheetState extends State<SeedFiltersSheet> {
  late SeedFilters _f = widget.initial;

  Widget _chip(String label, SeedSort value) {
    final selected = value == _f.sort;
    return ChoiceChip(
      label: Text(
        label,
        style: appStyle(
          context,
          text: label,
          size: 13,
          weight: FontWeight.w600,
          color: selected ? Colors.white : kShopInk,
          height: 1.3,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: kShopGreen,
      backgroundColor: kShopGrey,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) => setState(() => _f = _f.copyWith(sort: value)),
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Text(
          text,
          style: appStyle(
            context,
            text: text,
            size: 14,
            weight: FontWeight.w700,
            color: kShopInk,
            height: 1.3,
          ),
        ),
      );

  Widget _toggle(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: value,
      activeThumbColor: Colors.white,
      activeTrackColor: kShopGreen,
      onChanged: onChanged,
      title: Text(
        title,
        style: appStyle(
          context,
          text: title,
          size: 14,
          weight: FontWeight.w600,
          color: kShopInk,
          height: 1.3,
        ),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              style: appStyle(
                context,
                text: subtitle,
                size: 12,
                color: const Color(0xFF64748B),
                height: 1.3,
              ),
            ),
    );
  }

  ButtonStyle _btn(bool primary) {
    final label = appStyle(
      context,
      size: 15,
      weight: FontWeight.w700,
      color: primary ? Colors.white : kShopInk,
    );
    return (primary
            ? ElevatedButton.styleFrom(
                backgroundColor: kShopGreen,
                foregroundColor: Colors.white,
                elevation: 0,
              )
            : OutlinedButton.styleFrom(
                foregroundColor: kShopInk,
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ))
        .copyWith(
      textStyle: WidgetStatePropertyAll(label),
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = context.tr('shop_filters');
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: appStyle(
                context,
                text: title,
                size: 18,
                weight: FontWeight.w800,
                color: kShopInk,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            _heading(context.tr('sort_by')),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final s in SeedSort.values)
                  _chip(seedSortLabel(context, s), s),
              ],
            ),
            const SizedBox(height: 12),
            _heading(context.tr('seedui_show_only')),
            _toggle(
              context.tr('seedui_bookable_only'),
              '',
              _f.bookableOnly,
              (v) => setState(() => _f = _f.copyWith(bookableOnly: v)),
            ),
            _toggle(
              context.tr('seedui_high_yield'),
              context.tr('seedui_high_yield_hint',
                  namedArgs: {'q': '${kHighYieldThreshold.round()}'}),
              _f.highYield,
              (v) => setState(() => _f = _f.copyWith(highYield: v)),
            ),
            _toggle(
              context.tr('seedui_short_duration'),
              context.tr('seedui_short_duration_hint',
                  namedArgs: {'d': '$kShortDurationDays'}),
              _f.shortDuration,
              (v) => setState(() => _f = _f.copyWith(shortDuration: v)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: _btn(false),
                    onPressed: () =>
                        Navigator.pop(context, const SeedFilters()),
                    child: Text(context.tr('shop_reset')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: _btn(true),
                    onPressed: () => Navigator.pop(context, _f),
                    child: Text(context.tr('apply_filters')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
