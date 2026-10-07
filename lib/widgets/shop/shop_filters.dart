import 'package:cropsync/theme/app_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

const Color kShopGreen = Color(0xFF047857);
const Color kShopGrey = Color(0xFFF1F5F9);
const Color kShopInk = Color(0xFF0F172A);

enum ShopSort { defaultOrder, priceAsc, priceDesc, newest }

enum ShopPrice { all, under500, mid, above2000 }

/// Sort + price range selection. Immutable.
class ShopFilters {
  final ShopSort sort;
  final ShopPrice price;
  const ShopFilters({
    this.sort = ShopSort.defaultOrder,
    this.price = ShopPrice.all,
  });

  bool get isActive => sort != ShopSort.defaultOrder || price != ShopPrice.all;

  ShopFilters copyWith({ShopSort? sort, ShopPrice? price}) =>
      ShopFilters(sort: sort ?? this.sort, price: price ?? this.price);
}

String shopSortLabel(BuildContext context, ShopSort s) {
  switch (s) {
    case ShopSort.defaultOrder:
      return context.tr('shop_sort_default');
    case ShopSort.priceAsc:
      return context.tr('price_low_to_high');
    case ShopSort.priceDesc:
      return context.tr('price_high_to_low');
    case ShopSort.newest:
      return context.tr('shop_sort_newest');
  }
}

String shopPriceLabel(BuildContext context, ShopPrice p) {
  switch (p) {
    case ShopPrice.all:
      return context.tr('shop_price_all');
    case ShopPrice.under500:
      return context.tr('shop_price_under_500');
    case ShopPrice.mid:
      return context.tr('shop_price_500_2000');
    case ShopPrice.above2000:
      return context.tr('shop_price_above_2000');
  }
}

/// Bottom sheet with sort + price range. Returns the applied filters, or null
/// when dismissed.
Future<ShopFilters?> showShopFilterSheet(
  BuildContext context,
  ShopFilters current,
) {
  return showModalBottomSheet<ShopFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ShopFilterSheet(initial: current),
  );
}

class _ShopFilterSheet extends StatefulWidget {
  final ShopFilters initial;
  const _ShopFilterSheet({required this.initial});

  @override
  State<_ShopFilterSheet> createState() => _ShopFilterSheetState();
}

class _ShopFilterSheetState extends State<_ShopFilterSheet> {
  late ShopFilters _f = widget.initial;

  Widget _chip<T>(String label, T value, T group, ValueChanged<T> onTap) {
    final selected = value == group;
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
      onSelected: (_) => onTap(value),
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
                for (final s in ShopSort.values)
                  _chip<ShopSort>(
                    shopSortLabel(context, s),
                    s,
                    _f.sort,
                    (v) => setState(() => _f = _f.copyWith(sort: v)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _heading(context.tr('shop_price_range')),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final p in ShopPrice.values)
                  _chip<ShopPrice>(
                    shopPriceLabel(context, p),
                    p,
                    _f.price,
                    (v) => setState(() => _f = _f.copyWith(price: v)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: _btn(false),
                    onPressed: () =>
                        Navigator.pop(context, const ShopFilters()),
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
