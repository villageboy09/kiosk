import 'dart:async';

import 'package:cropsync/models/market_location.dart';
import 'package:cropsync/models/market_price.dart';
import 'package:cropsync/services/market_prices_service.dart';
import 'package:cropsync/services/share_service.dart';
import 'package:cropsync/theme/app_text.dart';
import 'package:cropsync/widgets/market/detail_text.dart';
import 'package:cropsync/utils/market_aliases.dart';
import 'package:cropsync/widgets/market/commodity_trend_chart.dart';
import 'package:cropsync/widgets/market/detail_markets_table.dart';
import 'package:cropsync/widgets/market/detail_range_bar.dart';
import 'package:cropsync/widgets/market/market_logic.dart';
import 'package:cropsync/widgets/safe_network_image.dart';
import 'package:cropsync/widgets/shop/shop_category_style.dart';
import 'package:cropsync/widgets/shop/shop_circle_button.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Detail page of one commodity: best/local price, real min-max, summary of
/// all markets, real price trend and a markets table. Every number comes from
/// the given rows or the trends endpoint; nothing is estimated.
class CommodityDetailScreen extends StatefulWidget {
  final CommodityPrices commodity;
  final MarketLocation? location;

  @visibleForTesting
  final MarketPricesService? service;

  @visibleForTesting
  final ImageProvider? debugImageProvider;

  const CommodityDetailScreen({
    super.key,
    required this.commodity,
    this.location,
    @visibleForTesting this.service,
    @visibleForTesting this.debugImageProvider,
  });

  @override
  State<CommodityDetailScreen> createState() => _CommodityDetailScreenState();
}

class _CommodityDetailScreenState extends State<CommodityDetailScreen> {
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _brand = Color(0xFF15803D);
  static const double _gutter = 20;
  static const double _overlap = 28;
  static const double _maxContentWidth = 640;
  static const int _collapsedRows = 8;

  MarketPricesService? _ownedService;
  int _days = 30;
  final Map<int, List<TrendPoint>> _trends = {};
  bool _trendLoading = true;
  int _trendToken = 0;

  String? _variety; // null = all varieties
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _loadTrend();
  }

  @override
  void dispose() {
    _ownedService?.dispose();
    super.dispose();
  }

  // ------------------------------- data ----------------------------------

  MarketPricesService get _service =>
      widget.service ?? (_ownedService ??= MarketPricesService());

  String get _rawName {
    final freq = <String, int>{};
    for (final r in widget.commodity.rows) {
      if (r.commodity.trim().isEmpty) continue;
      freq[r.commodity] = (freq[r.commodity] ?? 0) + 1;
    }
    if (freq.isEmpty) return widget.commodity.name;
    return (freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }

  String get _lang {
    final code = context.locale.languageCode;
    return (code == 'hi' || code == 'te') ? code : 'en';
  }

  /// Name shown to the user (Telugu / Hindi when known), same as the list.
  String get _displayName => commodityDisplayName(widget.commodity.name, _lang);

  String get _stateName {
    final s = widget.location?.state ?? '';
    if (s.isNotEmpty) return s;
    for (final r in widget.commodity.rows) {
      if (r.state.isNotEmpty) return r.state;
    }
    return '';
  }

  Future<void> _loadTrend({bool force = false}) async {
    final days = _days;
    if (!force && _trends.containsKey(days)) {
      setState(() => _trendLoading = false);
      return;
    }
    final token = ++_trendToken;
    setState(() => _trendLoading = true);
    List<TrendPoint> pts;
    final district = (widget.location?.district ?? '').trim();
    Future<List<TrendPoint>> load(String? d) async {
      try {
        return await _service.fetchTrends(
          state: _stateName,
          district: d,
          commodity: _rawName,
          days: days,
        );
      } catch (_) {
        return const [];
      }
    }

    pts = await load(district.isEmpty ? null : district);
    // A district with too little history: retry once state-wide.
    if (pts.length < 2 &&
        district.isNotEmpty &&
        mounted &&
        token == _trendToken) {
      pts = await load(null);
    }
    if (!mounted || token != _trendToken) return;
    setState(() {
      if (pts.length >= 2) {
        _trends[days] = pts;
      } else {
        _trends.remove(days);
      }
      _trendLoading = false;
    });
  }

  List<TrendPoint> get _points => _trends[_days] ?? const [];

  /// Distinct non-empty varieties, in first-seen order.
  List<String> get _varieties {
    final seen = <String>{};
    final out = <String>[];
    for (final r in widget.commodity.rows) {
      final v = r.variety.trim();
      if (v.isEmpty) continue;
      if (seen.add(v.toLowerCase())) out.add(v);
    }
    return out;
  }

  List<MarketPrice> get _rows {
    final v = _variety;
    if (v == null) return widget.commodity.rows;
    return widget.commodity.rows
        .where((r) => r.variety.trim().toLowerCase() == v.toLowerCase())
        .toList();
  }

  bool _isMine(MarketPrice r) {
    final d = widget.location?.district ?? '';
    return d.trim().isNotEmpty &&
        r.district.isNotEmpty &&
        sameDistrict(r.district, d);
  }

  /// Newest arrival date among the priced [rows] (null when undated).
  DateTime? _currentDate(List<MarketPrice> rows) {
    DateTime? d;
    for (final r in newestPricedRows(rows)) {
      final a = r.arrivalDate;
      if (a != null && (d == null || a.isAfter(d))) d = a;
    }
    return d;
  }

  List<MarketPrice> _sorted(List<MarketPrice> rows) {
    final list = [...rows];
    final cur = _currentDate(rows);
    bool older(MarketPrice r) =>
        cur != null && r.arrivalDate != null && r.arrivalDate != cur;
    // Today's rows first; earlier days (marked in the table) after them.
    int rank(MarketPrice r) =>
        !r.hasPrice ? 3 : (older(r) ? 2 : (_isMine(r) ? 0 : 1));
    list.sort((a, b) {
      final c = rank(a).compareTo(rank(b));
      if (c != 0) return c;
      if (a.hasPrice && b.hasPrice) {
        final m = b.modalPrice!.compareTo(a.modalPrice!);
        if (m != 0) return m;
      }
      return a.market.compareTo(b.market);
    });
    return list;
  }

  MarketPrice? _mine(List<MarketPrice> priced) {
    MarketPrice? mine;
    for (final r in priced) {
      if (!_isMine(r)) continue;
      if (mine == null) {
        mine = r;
        continue;
      }
      final da = mine.arrivalDate, db = r.arrivalDate;
      if (db != null && (da == null || db.isAfter(da))) {
        mine = r;
      } else if (da == db && r.modalPrice! > mine.modalPrice!) {
        mine = r;
      }
    }
    return mine;
  }

  // ------------------------------ helpers --------------------------------

  String _date(DateTime d) {
    try {
      return DateFormat('d MMM yyyy', context.locale.toString()).format(d);
    } catch (_) {
      return '${d.day}/${d.month}/${d.year}';
    }
  }

  String _categoryLabel(String cat) => context.tr(switch (cat) {
        'cereals' => 'mktd_cat_cereals',
        'pulses' => 'mktd_cat_pulses',
        'oilseeds' => 'mktd_cat_oilseeds',
        'vegetables' => 'mktd_cat_vegetables',
        'fruits' => 'mktd_cat_fruits',
        'spices' => 'mktd_cat_spices',
        'cash_crops' => 'mktd_cat_cash_crops',
        _ => 'mktd_cat_other',
      });

  String _rupees(double? v) => v == null ? '—' : MarketPrice.formatRupees(v);

  void _share() {
    HapticFeedback.lightImpact();
    final c = widget.commodity;
    final priced = c.rows.where((r) => r.hasPrice).toList();
    final mine = _mine(priced);
    final top = mine ?? c.best;
    String title;
    if (top == null) {
      title = context
          .tr('mktd_share_text_noprice', namedArgs: {'name': _displayName});
    } else {
      final place = [top.market, top.district]
          .where((s) => s.trim().isNotEmpty)
          .toSet()
          .join(', ');
      title = context.tr('mktd_share_text', namedArgs: {
        'name': _displayName,
        'price': MarketPrice.formatRupees(top.modalPrice!),
        'place': place,
      });
    }
    ShareService.shareItem(
      context: context,
      type: 'market',
      commodity: _rawName,
      title: title,
      imageUrl: c.imageUrl.isEmpty ? null : c.imageUrl,
    );
  }

  // ------------------------------- build ---------------------------------

  ShopCategoryStyle get _style => cropStyle(widget.commodity.name);

  BoxDecoration get _heroBackdrop {
    final st = _style;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(Colors.white, st.tint, 0.7)!,
          Color.lerp(st.tint, st.accent, 0.14)!,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final heroH = (media.size.height * 0.36).clamp(250.0, 380.0);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(bottom: media.padding.bottom + 24),
              child: Stack(
                children: [
                  _buildHero(heroH),
                  Column(
                    children: [
                      SizedBox(height: heroH - _overlap),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, child) => Opacity(
                          opacity: v,
                          child: Transform.translate(
                            offset: Offset(0, 24 * (1 - v)),
                            child: child,
                          ),
                        ),
                        child: _buildContentCard(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final top = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, top + 8, 12, 6),
      child: Row(
        children: [
          ShopCircleButton(
            icon: Icons.arrow_back_rounded,
            label: context.tr('shopd_back'),
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          ShopCircleButton(
            icon: Icons.ios_share_rounded,
            label: context.tr('shopd_share'),
            onTap: _share,
          ),
        ],
      ),
    );
  }

  Widget _buildHero(double heroH) {
    final media = MediaQuery.of(context);
    final st = _style;
    final placeholder = Center(
      child: Icon(st.icon,
          size: heroH * 0.32, color: st.accent.withValues(alpha: 0.35)),
    );
    final url = widget.commodity.imageUrl;
    final debug = widget.debugImageProvider;
    return Container(
      height: heroH,
      width: double.infinity,
      decoration: _heroBackdrop,
      child: LayoutBuilder(builder: (context, c) {
        final h = (c.maxHeight - media.padding.top - 20 - _overlap - 8)
            .clamp(100.0, 420.0);
        final w = (c.maxWidth - 128).clamp(100.0, 520.0);
        Widget image;
        if (debug != null) {
          image = Image(
            image: debug,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => placeholder,
          );
        } else if (url.isEmpty) {
          image = placeholder;
        } else {
          image = SafeNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: placeholder,
          );
        }
        return Padding(
          padding: EdgeInsets.only(
              top: media.padding.top + 20, bottom: _overlap + 8),
          child: Center(
            // Photo sits directly on the hero; white backgrounds multiply
            // into the tint instead of showing as a rectangle.
            child: _MultiplyBlend(
              child: SizedBox(
                key: const ValueKey('market_hero_image'),
                width: w,
                height: h,
                child: image,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildContentCard() {
    final varieties = _varieties;
    final rows = _rows;
    final priced = rows.where((r) => r.hasPrice).toList();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(_gutter, 22, _gutter, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(varieties.length),
              const SizedBox(height: 18),
              _buildPriceBlock(priced),
              if (varieties.length >= 2) ...[
                const SizedBox(height: 20),
                _buildVarietyChips(varieties),
              ],
              const SizedBox(height: 20),
              _buildStats(priced),
              const SizedBox(height: 26),
              _buildTrend(),
              const SizedBox(height: 26),
              _buildMarkets(rows, varieties.length >= 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int varietyCount) {
    final c = widget.commodity;
    final st = _style;
    final markets = c.rows
        .map((r) => '${r.market}|${r.district}'.toLowerCase())
        .toSet()
        .length;
    final parts = <String>[
      context.tr(markets == 1 ? 'mktd_market_one' : 'mktd_markets_n',
          args: ['$markets']),
      if (varietyCount >= 2)
        context.tr('mktd_varieties_n', args: ['$varietyCount']),
    ];
    final line = parts.join(' · ');
    final cat = _categoryLabel(c.category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: const ValueKey('market_category_chip'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: st.tint,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            cat,
            style: appStyle(context,
                text: cat,
                size: 12,
                weight: FontWeight.w600,
                color: st.accent,
                height: 1.4),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _displayName,
          key: const ValueKey('market_title'),
          style: appStyle(context,
              text: _displayName,
              size: 23,
              weight: FontWeight.w700,
              color: _ink,
              height: 1.35),
        ),
        const SizedBox(height: 2),
        Text(
          line,
          style: appStyle(context,
              text: line, size: 13.5, color: _muted, height: 1.45),
        ),
      ],
    );
  }

  Widget _buildPriceBlock(List<MarketPrice> priced) {
    final mine = _mine(priced);
    final MarketPrice? primary;
    if (mine != null) {
      primary = mine;
    } else if (priced.isEmpty) {
      primary = null;
    } else {
      final cur = newestPricedRows(priced);
      primary = cur.reduce((a, b) => b.modalPrice! > a.modalPrice! ? b : a);
    }

    if (primary == null) {
      final msg = context.tr('mktd_no_price');
      return Container(
        key: const ValueKey('market_price_block'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: _blockDecoration,
        child: Text(msg,
            style: detailUi(context,
                const TextStyle(fontSize: 14, color: _muted, height: 1.45))),
      );
    }

    final place = mine != null
        ? (mine.district.isNotEmpty
            ? mine.district
            : (widget.location?.district ?? ''))
        : (primary.market.isNotEmpty ? primary.market : primary.district);
    final label = context.tr(mine != null ? 'mktd_in_place' : 'mktd_best_at',
        namedArgs: {'place': place});
    final lo = primary.minPrice,
        hi = primary.maxPrice,
        modal = primary.modalPrice!;
    final hasRange = lo != null && hi != null && hi >= lo;
    final date = primary.arrivalDate ?? widget.commodity.latestDate;
    // The trend series covers all varieties, so the chip only goes with the
    // all-varieties price.
    final change = _variety == null && _points.length >= 2
        ? widget.commodity.changePct(_points)
        : null;

    return Container(
      key: const ValueKey('market_price_block'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: _blockDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: appStyle(context,
                  text: label,
                  size: 13,
                  weight: FontWeight.w600,
                  color: _brand,
                  height: 1.4)),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: MarketPrice.formatRupees(modal),
                    style: detailUi(
                        context,
                        const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                            height: 1.2)),
                  ),
                  TextSpan(
                    text: ' ${context.tr('market_per_quintal')}',
                    style: detailUi(
                        context,
                        const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _muted)),
                  ),
                ]),
                key: const ValueKey('market_primary_price'),
              ),
              if (change != null) _changeChip(change),
            ],
          ),
          if (hasRange) ...[
            const SizedBox(height: 12),
            DetailRangeBar(min: lo, max: hi, modal: modal, color: _brand),
            const SizedBox(height: 6),
            Text(
              context.tr('mktd_min_max', namedArgs: {
                'min': MarketPrice.formatRupees(lo),
                'max': MarketPrice.formatRupees(hi),
              }),
              key: const ValueKey('market_min_max'),
              style: detailUi(context,
                  const TextStyle(fontSize: 12.5, color: _muted, height: 1.4)),
            ),
          ],
          if (date != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 14, color: _muted),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    context.tr('mktd_as_of', namedArgs: {'date': _date(date)}),
                    style: detailUi(
                        context,
                        const TextStyle(
                            fontSize: 12.5, color: _muted, height: 1.4)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  BoxDecoration get _blockDecoration => BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      );

  Widget _changeChip(double pct) {
    final up = pct > 0.05, down = pct < -0.05;
    final color = up
        ? _brand
        : down
            ? const Color(0xFFB91C1C)
            : _muted;
    final bg = up
        ? const Color(0xFFDCFCE7)
        : down
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFE2E8F0);
    final text =
        '${up ? '▲' : (down ? '▼' : '')} ${pct.abs().toStringAsFixed(1)}%'
            .trim();
    return Container(
      key: const ValueKey('market_change_chip'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(
        '$text ${context.tr('mktd_vs_prev')}',
        style: detailUi(
            context,
            TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.4)),
      ),
    );
  }

  Widget _buildVarietyChips(List<String> varieties) {
    Widget chip(String? v, String label) {
      final selected = _variety == v;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: selected ? _brand : Colors.white,
          shape: StadiumBorder(
              side: BorderSide(
                  color: selected ? _brand : const Color(0xFFCBD5E1))),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => setState(() {
              _variety = v;
              _showAll = false;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                label,
                style: appStyle(context,
                    text: label,
                    size: 13,
                    weight: FontWeight.w600,
                    color: selected ? Colors.white : _ink,
                    height: 1.4),
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      key: const ValueKey('market_variety_chips'),
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          chip(null, context.tr('mktd_all_varieties')),
          for (final v in varieties) chip(v, v),
        ],
      ),
    );
  }

  Widget _statCell(String label, MarketPrice? row, double? value,
      {String? sub}) {
    final v = _rupees(value);
    final subText = sub ?? '';
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: detailUi(context,
                    const TextStyle(fontSize: 12, color: _muted, height: 1.4))),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(v,
                  style: detailUi(
                      context,
                      const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                          height: 1.3))),
            ),
            if (subText.isNotEmpty)
              Text(subText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appStyle(context,
                      text: subText, size: 11, color: _muted, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(List<MarketPrice> priced) {
    MarketPrice? hi, lo;
    double? avg;
    final cur = newestPricedRows(priced);
    if (cur.isNotEmpty) {
      hi = cur.reduce((a, b) => b.modalPrice! > a.modalPrice! ? b : a);
      lo = cur.reduce((a, b) => b.modalPrice! < a.modalPrice! ? b : a);
      avg = cur.fold<double>(0, (s, r) => s + r.modalPrice!) / cur.length;
    }
    String place(MarketPrice? r) =>
        r == null ? '' : (r.market.isNotEmpty ? r.market : r.district);
    return Column(
      key: const ValueKey('market_stats'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context.tr('mktd_stats_title')),
        const SizedBox(height: 10),
        IntrinsicHeight(
            child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statCell(context.tr('mktd_stat_highest'), hi, hi?.modalPrice,
                sub: place(hi)),
            const SizedBox(width: 8),
            _statCell(context.tr('mktd_stat_average'), null, avg,
                sub: cur.isEmpty
                    ? null
                    : context.tr(
                        cur.length == 1 ? 'mktd_market_one' : 'mktd_markets_n',
                        args: ['${cur.length}'])),
            const SizedBox(width: 8),
            _statCell(context.tr('mktd_stat_lowest'), lo, lo?.modalPrice,
                sub: place(lo)),
          ],
        )),
      ],
    );
  }

  Widget _sectionTitle(String t) => Text(
        t,
        style: appStyle(context,
            text: t,
            size: 17,
            weight: FontWeight.w700,
            color: _ink,
            height: 1.4),
      );

  // ------------------------------- trend ---------------------------------

  Widget _buildTrend() {
    return Column(
      key: const ValueKey('market_trend'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context.tr('mktd_trend_title')),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final d in const [7, 15, 30]) ...[
              Expanded(child: _dayPill(d)),
              if (d != 30) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 14),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.topCenter,
          child: _trendBody(),
        ),
      ],
    );
  }

  Widget _dayPill(int d) {
    final selected = _days == d;
    return Material(
      color: selected ? _brand : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        key: ValueKey('market_days_$d'),
        borderRadius: BorderRadius.circular(100),
        onTap: () {
          if (_days == d) return;
          setState(() => _days = d);
          _loadTrend();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          child: Center(
            child: Text(
              context.tr('mktd_days_n', args: ['$d']),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: detailUi(
                  context,
                  TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: selected ? Colors.white : _ink)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _trendBody() {
    if (_trendLoading) {
      return const _Skeleton(
          key: ValueKey('market_trend_loading'), height: 180);
    }
    final pts = _points;
    if (pts.length >= 2) {
      final chart =
          CommodityTrendChart(points: pts, height: 180, color: _brand);
      if (_variety == null) return chart;
      // The history is not split by variety: say so.
      final cap = context.tr('mktd_all_varieties');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          chart,
          const SizedBox(height: 6),
          Text(cap,
              key: const ValueKey('market_trend_caption'),
              style: appStyle(context,
                  text: cap, size: 12, color: _muted, height: 1.4)),
        ],
      );
    }
    return Container(
      key: const ValueKey('market_trend_empty'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: _blockDecoration,
      child: Column(
        children: [
          const Icon(Icons.show_chart_rounded,
              size: 30, color: Color(0xFF94A3B8)),
          const SizedBox(height: 8),
          Text(
            context.tr('mktd_trend_empty'),
            textAlign: TextAlign.center,
            style: detailUi(
                context,
                const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                    height: 1.45)),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('mktd_trend_empty_hint'),
            textAlign: TextAlign.center,
            style: detailUi(context,
                const TextStyle(fontSize: 12.5, color: _muted, height: 1.45)),
          ),
          const SizedBox(height: 6),
          TextButton(
            key: const ValueKey('market_trend_retry'),
            onPressed: () => _loadTrend(force: true),
            child: Text(
              context.tr('mktd_retry'),
              style: detailUi(
                  context,
                  const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _brand)),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------- markets -------------------------------

  Widget _buildMarkets(List<MarketPrice> rows, bool multiVariety) {
    final sorted = _sorted(rows);
    final canCollapse = sorted.length > _collapsedRows;
    final shown =
        canCollapse && !_showAll ? sorted.sublist(0, _collapsedRows) : sorted;
    final title = context.tr('mktd_markets_title');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        const SizedBox(height: 10),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          alignment: Alignment.topCenter,
          curve: Curves.easeOutCubic,
          child: DetailMarketsTable(
            rows: shown,
            userDistrict: widget.location?.district,
            showVariety: multiVariety,
            currentDate: _currentDate(rows),
          ),
        ),
        if (canCollapse)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Center(
              child: TextButton.icon(
                key: const ValueKey('market_show_all'),
                onPressed: () => setState(() => _showAll = !_showAll),
                icon: Icon(
                    _showAll
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: _brand),
                label: Text(
                  _showAll
                      ? context.tr('mktd_show_less')
                      : context.tr('mktd_show_all', args: ['${sorted.length}']),
                  style: detailUi(
                      context,
                      const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _brand)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Pulsing placeholder block shown while the trend loads. The animation only
/// runs while this widget is in the tree.
class _Skeleton extends StatefulWidget {
  final double height;
  const _Skeleton({super.key, required this.height});

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Color.lerp(
              const Color(0xFFF1F5F9), const Color(0xFFE2E8F0), _c.value),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

/// Paints [child] with BlendMode.multiply onto what is already painted
/// beneath it, so white photo backgrounds take on the backdrop colour.
class _MultiplyBlend extends SingleChildRenderObjectWidget {
  const _MultiplyBlend({required Widget child}) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMultiplyBlend();
}

class _RenderMultiplyBlend extends RenderProxyBox {
  @override
  void paint(PaintingContext context, Offset offset) {
    final rect = offset & size;
    context.canvas.saveLayer(rect, Paint()..blendMode = BlendMode.multiply);
    super.paint(context, offset);
    context.canvas.restore();
  }
}
