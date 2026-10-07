import 'package:cropsync/models/market_location.dart';
import 'package:cropsync/models/market_price.dart';
import 'package:cropsync/services/market_prices_service.dart';
import 'package:cropsync/utils/commodity_translator.dart';
import 'package:cropsync/utils/market_aliases.dart';

/// Pure logic behind the market prices list (no widgets, easy to test).

const String kMarketAll = 'all_category';

/// Category keys in display order (see [marketCategoryOf]).
const List<String> kMarketCategories = [
  'cereals',
  'pulses',
  'oilseeds',
  'vegetables',
  'fruits',
  'spices',
  'cash_crops',
  'other',
];

enum MarketSort { district, highest, lowest, az }

/// Sort + category + "only with prices". Immutable.
class MarketFilters {
  final MarketSort sort;
  final String category;
  final bool onlyPriced;

  const MarketFilters({
    this.sort = MarketSort.district,
    this.category = kMarketAll,
    this.onlyPriced = false,
  });

  /// Sort / toggle changed from the default (the category is shown by the
  /// chips and does not light the filter dot).
  bool get isActive => sort != MarketSort.district || onlyPriced;

  bool get isDefault => !isActive && category == kMarketAll;

  MarketFilters copyWith({
    MarketSort? sort,
    String? category,
    bool? onlyPriced,
  }) =>
      MarketFilters(
        sort: sort ?? this.sort,
        category: category ?? this.category,
        onlyPriced: onlyPriced ?? this.onlyPriced,
      );
}

/// For each commodity + variety + market keeps only the newest arrival date
/// (rows without a date lose against dated ones; ties keep the first row).
List<MarketPrice> dedupeLatestRows(List<MarketPrice> rows) {
  final best = <String, MarketPrice>{};
  final order = <String>[];
  for (final r in rows) {
    final k = '${commodityKey(r.commodity)}|${r.variety.trim().toLowerCase()}|'
        '${r.market.trim().toLowerCase()}|${r.district.trim().toLowerCase()}';
    final cur = best[k];
    if (cur == null) {
      best[k] = r;
      order.add(k);
      continue;
    }
    final a = cur.arrivalDate, b = r.arrivalDate;
    if (b != null && (a == null || b.isAfter(a))) best[k] = r;
  }
  return [for (final k in order) best[k]!];
}

/// The row a card/row shows: the user's district row, else the best market.
MarketPrice? representativeRow(CommodityPrices c) =>
    c.userDistrictRow ?? c.best;

/// Localised commodity name (raw name when unknown or English).
String commodityDisplayName(String raw, String lang) =>
    lang == 'en' ? raw : CommodityTranslator.getLocalizedName(raw, lang);

/// Deep-link text -> search text. Share titles ("Tomato: Rs 1,500/qtl at
/// X - CropSync") keep only the part before the first colon.
String cleanInitialCommodity(String? raw) {
  var t = (raw ?? '').trim();
  if (t.contains(' - CropSync') || t.length > 40) {
    final i = t.indexOf(':');
    if (i > 0) t = t.substring(0, i).trim();
  }
  return t;
}

String normalizeQuery(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

/// Lower-case search haystack per commodity key: raw + Telugu + Hindi names,
/// varieties, markets and districts.
Map<String, String> buildSearchIndex(List<CommodityPrices> all) {
  final out = <String, String>{};
  for (final c in all) {
    final b = StringBuffer()
      ..write(c.name)
      ..write(' ')
      ..write(CommodityTranslator.getLocalizedName(c.name, 'te'))
      ..write(' ')
      ..write(CommodityTranslator.getLocalizedName(c.name, 'hi'));
    for (final r in c.rows) {
      b
        ..write(' ')
        ..write(r.commodity)
        ..write(' ')
        ..write(r.variety)
        ..write(' ')
        ..write(r.market)
        ..write(' ')
        ..write(r.district);
    }
    out[c.key] = normalizeQuery(b.toString());
  }
  return out;
}

/// Categories (in [kMarketCategories] order) that exist in [all].
List<String> categoriesPresent(List<CommodityPrices> all) {
  final have = {for (final c in all) c.category};
  return [
    for (final k in kMarketCategories)
      if (have.contains(k)) k,
  ];
}

/// Search, category, "only priced" and sort. Stable for equal keys.
List<CommodityPrices> applyMarketFilters(
  List<CommodityPrices> all, {
  required MarketFilters filters,
  required String query,
  required Map<String, String> index,
  required String lang,
}) {
  final q = normalizeQuery(query);
  var list = <CommodityPrices>[];
  for (final c in all) {
    if (filters.category != kMarketAll && c.category != filters.category) {
      continue;
    }
    if (filters.onlyPriced && !c.hasPrice) continue;
    if (q.isNotEmpty) {
      final hay = index[c.key] ??
          normalizeQuery('${c.name} ${commodityDisplayName(c.name, lang)}');
      if (!hay.contains(q)) continue;
    }
    list.add(c);
  }

  final pos = {for (var i = 0; i < list.length; i++) list[i].key: i};
  double? price(CommodityPrices c) => representativeRow(c)?.modalPrice;

  int nullsLast(double? a, double? b, {required bool desc}) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return desc ? b.compareTo(a) : a.compareTo(b);
  }

  int cmp(CommodityPrices a, CommodityPrices b) {
    var r = 0;
    switch (filters.sort) {
      case MarketSort.district:
        final ha = a.userDistrictRow != null, hb = b.userDistrictRow != null;
        r = ha == hb ? 0 : (ha ? -1 : 1);
      case MarketSort.highest:
        r = nullsLast(price(a), price(b), desc: true);
      case MarketSort.lowest:
        r = nullsLast(price(a), price(b), desc: false);
      case MarketSort.az:
        r = commodityDisplayName(a.name, lang)
            .toLowerCase()
            .compareTo(commodityDisplayName(b.name, lang).toLowerCase());
    }
    return r != 0 ? r : pos[a.key]!.compareTo(pos[b.key]!);
  }

  list = [...list]..sort(cmp);
  return list;
}

// ------------------------------------------------------------- locations

/// Place label: "District, State" or just the state.
String placeLabel(MarketLocation loc) {
  final d = loc.district.trim();
  if (d.isEmpty) return loc.state;
  if (loc.state.isEmpty) return d;
  return '$d, ${loc.state}';
}

bool sameLocation(MarketLocation a, MarketLocation b) {
  if (a.state.toLowerCase() != b.state.toLowerCase()) return false;
  final da = a.district.trim(), db = b.district.trim();
  if (da.isEmpty || db.isEmpty) return da.isEmpty && db.isEmpty;
  return sameDistrict(da, db);
}

// ---------------------------------------------------------------- errors

enum MarketErrorAction { retry, showStateWide, chooseAnother }

class MarketErrorView {
  final String titleKey;
  final String bodyKey;
  final List<MarketErrorAction> actions;
  const MarketErrorView(this.titleKey, this.bodyKey, this.actions);
}

/// Which message and actions to show for a failed fetch.
MarketErrorView marketErrorView(MarketFetchError e,
    {required bool districtRequested}) {
  switch (e) {
    case MarketFetchError.network:
      return const MarketErrorView('mktui_err_offline_title', 'mkt_err_network',
          [MarketErrorAction.retry]);
    case MarketFetchError.timeout:
      return const MarketErrorView(
          'mktui_err_slow_title', 'mkt_err_timeout', [MarketErrorAction.retry]);
    case MarketFetchError.upstreamUnavailable:
    case MarketFetchError.missingApiKey:
      return const MarketErrorView('mktui_err_unavailable_title',
          'mkt_err_upstream', [MarketErrorAction.retry]);
    case MarketFetchError.noData:
      return MarketErrorView('mktui_err_nodata_title', 'mkt_err_no_data', [
        if (districtRequested) MarketErrorAction.showStateWide,
        MarketErrorAction.chooseAnother,
      ]);
    case MarketFetchError.parse:
      return const MarketErrorView('mktui_err_generic_title', 'mkt_err_parse',
          [MarketErrorAction.retry]);
    case MarketFetchError.server:
      return const MarketErrorView('mktui_err_generic_title', 'mkt_err_server',
          [MarketErrorAction.retry]);
  }
}

/// Banner message / action keys for a GPS failure.
class GpsIssueView {
  final String messageKey;
  final String actionKey;
  const GpsIssueView(this.messageKey, this.actionKey);
}

GpsIssueView gpsIssueView(MarketLocationFailure f) {
  switch (f) {
    case MarketLocationFailure.permissionDenied:
      return const GpsIssueView(
          'mkt_loc_permission_denied', 'mktui_enable_location');
    case MarketLocationFailure.permissionDeniedForever:
      return const GpsIssueView(
          'mkt_loc_permission_forever', 'mkt_open_settings');
    case MarketLocationFailure.serviceDisabled:
      return const GpsIssueView(
          'mkt_loc_service_disabled', 'mkt_enable_location');
    case MarketLocationFailure.timeout:
    case MarketLocationFailure.geocodeFailed:
    case MarketLocationFailure.unsupported:
      return const GpsIssueView('mktui_cant_detect', 'mktui_choose_manually');
  }
}
