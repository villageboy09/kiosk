import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/models/market_price.dart';
import 'package:cropsync/theme/app_text.dart';
import 'package:cropsync/widgets/market/market_logic.dart';
import 'package:cropsync/widgets/shop/shop_category_style.dart';
import 'package:cropsync/widgets/shop/shop_filters.dart';
import 'package:cropsync/widgets/shop/shop_product_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

const Color _kMuted = Color(0xFF64748B);

// --------------------------------------------------------------- styles

/// Icon + pastel tint for a market category key.
ShopCategoryStyle marketCategoryStyle(String category) {
  switch (category) {
    case 'cereals':
      return const ShopCategoryStyle(
          Icons.grain_rounded, Color(0xFFFFF4D6), Color(0xFFB45309));
    case 'pulses':
      return const ShopCategoryStyle(
          Icons.blur_circular_rounded, Color(0xFFEFE9FB), Color(0xFF6D28D9));
    case 'oilseeds':
      return const ShopCategoryStyle(
          Icons.spa_rounded, Color(0xFFF6EBDD), Color(0xFF92400E));
    case 'vegetables':
      return const ShopCategoryStyle(
          Icons.park_rounded, Color(0xFFE3F4EC), Color(0xFF047857));
    case 'fruits':
      return const ShopCategoryStyle(
          Icons.apple_rounded, Color(0xFFFCE8F1), Color(0xFFBE185D));
    case 'spices':
      return const ShopCategoryStyle(Icons.local_fire_department_rounded,
          Color(0xFFFDEBEC), Color(0xFFB91C1C));
    case 'cash_crops':
      return const ShopCategoryStyle(
          Icons.cloud_rounded, Color(0xFFE6F0FD), Color(0xFF1D4ED8));
    case 'other':
      return const ShopCategoryStyle(
          Icons.category_rounded, Color(0xFFEFF3F7), Color(0xFF475569));
    default:
      return shopCategoryStyle(kMarketAll);
  }
}

/// Style for a chip entry: "all" or a category key.
ShopCategoryStyle marketChipStyle(String raw) => raw == kMarketAll
    ? shopCategoryStyle(kMarketAll)
    : marketCategoryStyle(raw);

String marketCategoryLabel(BuildContext context, String key) =>
    key == kMarketAll
        ? context.tr('all_category')
        : context.tr('mktui_cat_$key');

/// Icon style of one commodity: crop-specific when the name is recognised,
/// else the category style.
ShopCategoryStyle commodityStyle(CommodityPrices c) {
  final s = cropStyle(c.name);
  return identical(s, cropStyle('')) ? marketCategoryStyle(c.category) : s;
}

// -------------------------------------------------------------- helpers

String _rupees(num v) => MarketPrice.formatRupees(v);

/// "d MMM" in the app language (falls back to ISO when locale data is
/// missing).
String marketDateLabel(BuildContext context, DateTime d) {
  try {
    return DateFormat('d MMM', context.locale.toString()).format(d);
  } catch (_) {
    return DateFormat('d MMM').format(d);
  }
}

/// Which market row a rail card shows.
enum RailRowMode { auto, near, best }

class CommodityRailEntry {
  final CommodityPrices commodity;
  final RailRowMode mode;
  final int id;
  const CommodityRailEntry(this.commodity, this.mode, this.id);

  MarketPrice? get row {
    switch (mode) {
      case RailRowMode.near:
        return commodity.userDistrictRow ?? commodity.best;
      case RailRowMode.best:
        return commodity.best;
      case RailRowMode.auto:
        return representativeRow(commodity);
    }
  }

  /// True when [row] is the user's district row and the card should show its
  /// plain market name instead of "Best: ...".
  bool get isDistrictRow =>
      mode != RailRowMode.best &&
      commodity.userDistrictRow != null &&
      identical(row, commodity.userDistrictRow);
}

// ------------------------------------------------------------ rail card

const double kMarketRailImageAspect = 1.25;

double marketRailInfoHeight(double textScale) {
  final s = textScale.clamp(1.0, kShopCardMaxTextScale);
  return 8 +
      2 * 13.5 * 1.4 * s +
      4 +
      17 * 1.3 * s +
      2 +
      11.5 * 1.3 * s +
      2 +
      10.5 * 1.3 * s +
      10 +
      4;
}

double marketRailHeight(double cardWidth, double textScale) =>
    cardExtent(cardWidth, textScale,
        infoHeight: marketRailInfoHeight(textScale),
        imageAspect: kMarketRailImageAspect);

/// Price with a small unit: "₹6,850 /qtl", scaled down to fit.
class PriceText extends StatelessWidget {
  final double price;
  final double size;
  final Alignment alignment;
  const PriceText({
    super.key,
    required this.price,
    this.size = 17,
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    final priceText = _rupees(price);
    final unit = context.tr('market_per_quintal');
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: priceText,
            style: appStyle(context,
                text: priceText,
                size: size,
                weight: FontWeight.w800,
                color: kShopInk,
                height: 1.3),
          ),
          TextSpan(
            text: ' $unit',
            style: appStyle(context,
                text: unit,
                size: size * 0.66,
                weight: FontWeight.w600,
                color: _kMuted,
                height: 1.3),
          ),
        ]),
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}

class CommodityRailCard extends StatelessWidget {
  final CommodityRailEntry entry;
  final String displayName;
  final int memCacheWidth;
  final VoidCallback onTap;

  @visibleForTesting
  final ImageProvider? debugImageProvider;

  const CommodityRailCard({
    super.key,
    required this.entry,
    required this.displayName,
    required this.memCacheWidth,
    required this.onTap,
    this.debugImageProvider,
  });

  @override
  Widget build(BuildContext context) {
    final c = entry.commodity;
    final row = entry.row;
    final price = row?.modalPrice;
    final style = commodityStyle(c);
    final market = row?.market.trim() ?? '';
    final marketLine = market.isEmpty
        ? ''
        : (entry.isDistrictRow
            ? '${context.tr('mktd_your_district')} · $market'
            : context.tr('mktui_best_at', namedArgs: {'market': market}));
    final lo = row?.minPrice, hi = row?.maxPrice;
    final thirdLine = (lo != null && hi != null)
        ? '${_rupees(lo)} – ${_rupees(hi)}'
        : (c.count > 1
            ? context
                .tr('mktui_markets_count', namedArgs: {'count': '${c.count}'})
            : '');
    final noPrice = context.tr('mktui_no_price');
    final semantics = [
      displayName,
      if (price != null)
        '${_rupees(price)} ${context.tr('market_per_quintal')}',
      if (marketLine.isNotEmpty) marketLine,
    ].join(', ');

    return ShopCardShell(
      onTap: onTap,
      semanticsLabel: semantics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShopImageTile(
            imageUrl: c.imageUrl,
            aspect: kMarketRailImageAspect,
            memCacheWidth: memCacheWidth,
            placeholderStyle: style,
            debugImageProvider: debugImageProvider,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: appStyle(context,
                        text: displayName,
                        size: 13.5,
                        weight: FontWeight.w500,
                        color: kShopInk,
                        height: 1.4),
                  ),
                  const SizedBox(height: 4),
                  if (price != null)
                    PriceText(price: price)
                  else
                    SizedBox(
                      height: 17 * 1.3,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          noPrice,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appStyle(context,
                              text: noPrice,
                              size: 12,
                              weight: FontWeight.w600,
                              color: _kMuted,
                              height: 1.3),
                        ),
                      ),
                    ),
                  const SizedBox(height: 2),
                  _line(context, marketLine, 11.5, FontWeight.w500, _kMuted),
                  const SizedBox(height: 2),
                  _line(context, thirdLine, 10.5, FontWeight.w600,
                      const Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String text, double size,
      FontWeight weight, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: appStyle(context,
          text: text, size: size, weight: weight, color: color, height: 1.3),
    );
  }
}

// ------------------------------------------------------------ range bar

/// Thin min-max bar with a tick at the modal price (real values only).
class PriceRangeBar extends StatelessWidget {
  final double min;
  final double max;
  final double? modal;
  const PriceRangeBar(
      {super.key, required this.min, required this.max, this.modal});

  static bool canShow(MarketPrice r) {
    final lo = r.minPrice, hi = r.maxPrice;
    return lo != null && hi != null && hi > lo;
  }

  @override
  Widget build(BuildContext context) {
    final lo = _rupees(min), hi = _rupees(max);
    TextStyle label(String t) => appStyle(context,
        text: t,
        size: 10.5,
        weight: FontWeight.w600,
        color: _kMuted,
        height: 1.3);
    return Semantics(
      label: context.tr('mktui_price_range'),
      value: '$lo - $hi',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 12,
            width: double.infinity,
            child: CustomPaint(
              painter: _RangePainter(
                  fraction: modal == null
                      ? null
                      : ((modal! - min) / (max - min)).clamp(0.0, 1.0)),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                  child: Text(lo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: label(lo))),
              const SizedBox(width: 8),
              Flexible(
                  child: Text(hi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: label(hi))),
            ],
          ),
        ],
      ),
    );
  }
}

class _RangePainter extends CustomPainter {
  final double? fraction;
  const _RangePainter({this.fraction});

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final track = RRect.fromLTRBR(
        0, cy - 2.5, size.width, cy + 2.5, const Radius.circular(3));
    canvas.drawRRect(
        track,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFD1FAE5), Color(0xFF6EE7B7)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    final f = fraction;
    if (f != null) {
      final x = 5 + f * (size.width - 10);
      canvas.drawCircle(Offset(x, cy), 6, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(x, cy), 4.5, Paint()..color = kShopGreen);
    }
  }

  @override
  bool shouldRepaint(_RangePainter old) => old.fraction != fraction;
}

// ----------------------------------------------------------- thumbnail

class CommodityThumb extends StatelessWidget {
  final CommodityPrices commodity;
  final double size;
  final int memCacheWidth;

  @visibleForTesting
  final ImageProvider? debugImageProvider;

  const CommodityThumb({
    super.key,
    required this.commodity,
    this.size = 44,
    this.memCacheWidth = 120,
    this.debugImageProvider,
  });

  @override
  Widget build(BuildContext context) {
    final style = commodityStyle(commodity);
    final bubble = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: style.tint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(style.icon, size: size * 0.5, color: style.accent),
    );
    final url = commodity.imageUrl;
    if (debugImageProvider == null && url.isEmpty) return bubble;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDF1F5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: debugImageProvider != null
            ? Image(
                image: debugImageProvider!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => bubble,
              )
            : CachedNetworkImage(
                imageUrl: _absolute(url),
                fit: BoxFit.contain,
                memCacheWidth: memCacheWidth,
                placeholder: (_, __) => bubble,
                errorWidget: (_, __, ___) => bubble,
              ),
      ),
    );
  }

  static String _absolute(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return 'https://kiosk.cropsync.in${url.startsWith('/') ? '' : '/'}$url';
  }
}

// ------------------------------------------------------------------ row

/// Max text scale used inside list rows.
const double kMarketRowMaxScale = kShopCardMaxTextScale;

/// Height of one row for grid layouts with a fixed extent.
double marketRowExtent(double textScale) {
  final s = textScale.clamp(1.0, kMarketRowMaxScale);
  final header = (14.5 * 1.35 * 2 + 12 * 1.4) * s;
  return 12 +
      (header < 44 ? 44 : header) +
      8 +
      (12 + 2 + 10.5 * 1.3 * s) +
      6 +
      11.5 * 1.4 * s +
      12 +
      4;
}

class CommodityRow extends StatelessWidget {
  final CommodityPrices commodity;
  final String displayName;
  final VoidCallback onTap;
  final int memCacheWidth;

  @visibleForTesting
  final ImageProvider? debugImageProvider;

  const CommodityRow({
    super.key,
    required this.commodity,
    required this.displayName,
    required this.onTap,
    this.memCacheWidth = 120,
    this.debugImageProvider,
  });

  @override
  Widget build(BuildContext context) {
    final c = commodity;
    final row = representativeRow(c);
    final price = row?.modalPrice;

    final subParts = <String>[
      if (row != null && row.variety.trim().isNotEmpty) row.variety.trim(),
      if (c.count > 1)
        context.tr('mktui_markets_count', namedArgs: {'count': '${c.count}'}),
    ];
    final sub = subParts.join(' · ');

    final mkt = row?.market.trim() ?? '';
    final dst = row?.district.trim() ?? '';
    final place = [
      if (mkt.isNotEmpty) mkt,
      if (dst.isNotEmpty && dst.toLowerCase() != mkt.toLowerCase()) dst,
    ].join(', ');
    final date = row?.arrivalDate;
    // Say whose price this is: the user's district, else the highest market.
    final isMine = row != null && identical(row, c.userDistrictRow);
    final String head;
    if (place.isEmpty) {
      head = '';
    } else if (isMine) {
      head = '${context.tr('mktd_your_district')} · $place';
    } else if (price != null && c.pricedCount > 1) {
      head = context.tr('mktui_best_at',
          namedArgs: {'market': mkt.isNotEmpty ? mkt : dst});
    } else {
      head = place;
    }
    final footer = [
      if (head.isNotEmpty) head,
      if (date != null) marketDateLabel(context, date),
    ].join(' · ');
    final noPrice = context.tr('mktui_no_price');

    final semantics = [
      displayName,
      if (price != null)
        '${_rupees(price)} ${context.tr('market_per_quintal')}',
      if (footer.isNotEmpty) footer,
    ].join(', ');

    return ShopCardShell(
      onTap: onTap,
      semanticsLabel: semantics,
      child: LayoutBuilder(builder: (context, box) {
        final inner = box.maxWidth - 24 - 56;
        final scale = MediaQuery.textScalerOf(context)
            .scale(1)
            .clamp(1.0, kShopCardMaxTextScale);
        // Name and price no longer fit side by side: put the price below.
        final stacked = inner < 190 * (scale > 1.15 ? 1.25 : 1.0);
        Widget priceWidget(Alignment al, TextAlign ta) => price != null
            ? PriceText(price: price, size: 17, alignment: al)
            : Text(
                noPrice,
                textAlign: ta,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: appStyle(context,
                    text: noPrice,
                    size: 12,
                    weight: FontWeight.w600,
                    color: _kMuted,
                    height: 1.3),
              );
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CommodityThumb(
                    commodity: c,
                    memCacheWidth: memCacheWidth,
                    debugImageProvider: debugImageProvider,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: appStyle(context,
                              text: displayName,
                              size: 14.5,
                              weight: FontWeight.w700,
                              color: kShopInk,
                              height: 1.35),
                        ),
                        if (sub.isNotEmpty)
                          Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: appStyle(context,
                                text: sub,
                                size: 12,
                                color: _kMuted,
                                height: 1.4),
                          ),
                      ],
                    ),
                  ),
                  if (!stacked) ...[
                    const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: (inner * 0.4).clamp(96.0, 180.0),
                      ),
                      child: priceWidget(Alignment.centerRight, TextAlign.end),
                    ),
                  ],
                ],
              ),
              if (stacked) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: priceWidget(Alignment.centerLeft, TextAlign.start),
                ),
              ],
              if (row != null && PriceRangeBar.canShow(row)) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: PriceRangeBar(
                    min: row.minPrice!,
                    max: row.maxPrice!,
                    modal: row.modalPrice,
                  ),
                ),
              ],
              if (footer.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: Text(
                    footer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appStyle(context,
                        text: footer,
                        size: 11.5,
                        color: const Color(0xFF94A3B8),
                        height: 1.4),
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}
