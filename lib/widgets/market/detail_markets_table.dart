import 'package:cropsync/models/market_price.dart';
import 'package:cropsync/theme/app_text.dart';
import 'package:cropsync/widgets/market/detail_text.dart';
import 'package:cropsync/utils/market_aliases.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Two-column markets table: market (left, 58%) | price (left-aligned in its
/// own 42% column so every price starts at the same x). Rows are rendered in
/// the given order; the caller sorts them.
class DetailMarketsTable extends StatelessWidget {
  final List<MarketPrice> rows;
  final String? userDistrict;

  /// Show the variety / grade line under the market name.
  final bool showVariety;

  /// Newest arrival date of the commodity: rows from an earlier day are
  /// marked "As of <date>" so they are not mistaken for today's price.
  final DateTime? currentDate;

  const DetailMarketsTable({
    super.key,
    required this.rows,
    this.userDistrict,
    this.showVariety = false,
    this.currentDate,
  });

  String? _olderLabel(BuildContext context, MarketPrice r) {
    final d = r.arrivalDate, cur = currentDate;
    if (d == null || cur == null || d == cur) return null;
    String f;
    try {
      f = DateFormat('d MMM', context.locale.toString()).format(d);
    } catch (_) {
      f = '${d.day}/${d.month}';
    }
    return context.tr('mktd_as_of', namedArgs: {'date': f});
  }

  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _brand = Color(0xFF15803D);

  bool _isMine(MarketPrice r) =>
      userDistrict != null &&
      userDistrict!.trim().isNotEmpty &&
      r.district.isNotEmpty &&
      sameDistrict(r.district, userDistrict!);

  @override
  Widget build(BuildContext context) {
    const divider = BorderSide(color: Color(0xFFE2E8F0));
    // Outer border is a foreground decoration so it paints above the row
    // fills and stays visible with rounded corners.
    return Container(
      key: const ValueKey('markets_table'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(58),
          1: FlexColumnWidth(42),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        border: const TableBorder(horizontalInside: divider),
        children: [
          for (var i = 0; i < rows.length; i++) _row(context, i, rows[i]),
        ],
      ),
    );
  }

  TableRow _row(BuildContext context, int i, MarketPrice r) {
    final mine = _isMine(r);
    final bg = mine
        ? const Color(0xFFF0FDF4)
        : (i.isOdd ? const Color(0xFFF8FAFC) : Colors.white);
    final market = r.market.isEmpty ? r.district : r.market;
    final sub = (r.district.isNotEmpty &&
            r.district.toLowerCase() != market.toLowerCase())
        ? r.district
        : '';
    final older = _olderLabel(context, r);
    final varietyLine = showVariety
        ? [r.variety, r.grade]
            .where((s) => s.trim().isNotEmpty)
            .toSet()
            .join(' · ')
        : '';

    return TableRow(
      key: ValueKey('market_row_$i'),
      decoration: BoxDecoration(color: bg),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                market,
                key: ValueKey('market_name_$i'),
                style: appStyle(context,
                    text: market,
                    size: 14,
                    weight: FontWeight.w600,
                    color: _ink,
                    height: 1.4),
              ),
              if (sub.isNotEmpty)
                Text(
                  sub,
                  style: appStyle(context,
                      text: sub, size: 12, color: _muted, height: 1.4),
                ),
              if (older != null)
                Text(
                  older,
                  key: ValueKey('market_older_$i'),
                  style: appStyle(context,
                      text: older,
                      size: 11.5,
                      weight: FontWeight.w600,
                      color: const Color(0xFFB45309),
                      height: 1.4),
                ),
              if (varietyLine.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    varietyLine,
                    key: ValueKey('market_variety_$i'),
                    style: appStyle(context,
                        text: varietyLine,
                        size: 11.5,
                        color: const Color(0xFF475569),
                        height: 1.4),
                  ),
                ),
              if (mine)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    key: ValueKey('market_mine_$i'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _brand,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      context.tr('mktd_your_district'),
                      style: detailUi(
                        context,
                        const TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
          child: _value(context, i, r),
        ),
      ],
    );
  }

  Widget _value(BuildContext context, int i, MarketPrice r) {
    final modal = r.modalPrice;
    if (modal == null) {
      return Text(
        '—',
        key: ValueKey('market_value_$i'),
        style: detailUi(
            context,
            const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _muted,
                height: 1.4)),
      );
    }
    final lo = r.minPrice, hi = r.maxPrice;
    final range = (lo != null && hi != null)
        ? '${MarketPrice.formatRupees(lo)} - ${MarketPrice.formatRupees(hi)}'
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(
              text: MarketPrice.formatRupees(modal),
              style: detailUi(
                  context,
                  const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                      height: 1.4)),
            ),
            TextSpan(
              text: context.tr('market_per_quintal'),
              style: detailUi(context,
                  const TextStyle(fontSize: 11.5, color: _muted, height: 1.4)),
            ),
          ]),
          key: ValueKey('market_value_$i'),
        ),
        if (range.isNotEmpty)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              range,
              key: ValueKey('market_range_$i'),
              maxLines: 1,
              softWrap: false,
              style: detailUi(context,
                  const TextStyle(fontSize: 11.5, color: _muted, height: 1.4)),
            ),
          ),
      ],
    );
  }
}
