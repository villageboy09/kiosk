import 'package:cropsync/theme/app_text.dart';
import 'package:cropsync/widgets/market/market_cards.dart';
import 'package:cropsync/widgets/market/market_logic.dart';
import 'package:cropsync/widgets/shop/shop_filters.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

String marketSortLabel(BuildContext context, MarketSort s) {
  switch (s) {
    case MarketSort.district:
      return context.tr('mktui_sort_district');
    case MarketSort.highest:
      return context.tr('mktui_sort_highest');
    case MarketSort.lowest:
      return context.tr('mktui_sort_lowest');
    case MarketSort.az:
      return context.tr('mktui_sort_az');
  }
}

/// Sort / category / "only with prices". Returns the applied filters, or null
/// when dismissed.
Future<MarketFilters?> showMarketFiltersSheet(
  BuildContext context,
  MarketFilters current, {
  required List<String> categories,
}) {
  return showModalBottomSheet<MarketFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) =>
        _MarketFiltersSheet(initial: current, categories: categories),
  );
}

class _MarketFiltersSheet extends StatefulWidget {
  final MarketFilters initial;
  final List<String> categories;
  const _MarketFiltersSheet({required this.initial, required this.categories});

  @override
  State<_MarketFiltersSheet> createState() => _MarketFiltersSheetState();
}

class _MarketFiltersSheetState extends State<_MarketFiltersSheet> {
  late MarketFilters _f = widget.initial;

  Widget _chip<T>(String label, T value, T group, ValueChanged<T> onTap) {
    final selected = value == group;
    return ChoiceChip(
      label: Text(
        label,
        style: appStyle(context,
            text: label,
            size: 13,
            weight: FontWeight.w600,
            color: selected ? Colors.white : kShopInk,
            height: 1.3),
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: kShopGreen,
      backgroundColor: kShopGrey,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) => onTap(value),
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Text(
          text,
          style: appStyle(context,
              text: text,
              size: 14,
              weight: FontWeight.w700,
              color: kShopInk,
              height: 1.3),
        ),
      );

  ButtonStyle _btn(bool primary) {
    final label = appStyle(context,
        size: 15,
        weight: FontWeight.w700,
        color: primary ? Colors.white : kShopInk);
    return (primary
            ? ElevatedButton.styleFrom(
                backgroundColor: kShopGreen,
                foregroundColor: Colors.white,
                elevation: 0)
            : OutlinedButton.styleFrom(
                foregroundColor: kShopInk,
                side: const BorderSide(color: Color(0xFFE2E8F0))))
        .copyWith(
      textStyle: WidgetStatePropertyAll(label),
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = context.tr('shop_filters');
    final onlyPriced = context.tr('mktui_only_priced');
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: appStyle(context,
                  text: title,
                  size: 18,
                  weight: FontWeight.w800,
                  color: kShopInk,
                  height: 1.3),
            ),
            const SizedBox(height: 8),
            _heading(context.tr('sort_by')),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final s in MarketSort.values)
                  _chip<MarketSort>(
                    marketSortLabel(context, s),
                    s,
                    _f.sort,
                    (v) => setState(() => _f = _f.copyWith(sort: v)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _heading(context.tr('mktui_category')),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in [kMarketAll, ...widget.categories])
                  _chip<String>(
                    marketCategoryLabel(context, c),
                    c,
                    _f.category,
                    (v) => setState(() => _f = _f.copyWith(category: v)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _f.onlyPriced,
              activeThumbColor: Colors.white,
              activeTrackColor: kShopGreen,
              onChanged: (v) => setState(() => _f = _f.copyWith(onlyPriced: v)),
              title: Text(
                onlyPriced,
                style: appStyle(context,
                    text: onlyPriced,
                    size: 14,
                    weight: FontWeight.w600,
                    color: kShopInk,
                    height: 1.3),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: _btn(false),
                    onPressed: () =>
                        Navigator.pop(context, const MarketFilters()),
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
