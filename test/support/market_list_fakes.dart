import 'dart:convert';
import 'dart:io';

import 'package:cropsync/models/market_location.dart';
import 'package:cropsync/models/market_price.dart';
import 'package:cropsync/services/market_prices_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

const Map<String, Map<String, String>> kPendingLocationKeys = {
  'en': {
    'mktui_sec_your_state': 'Your state',
    'mktui_sec_with_prices': 'States with prices',
    'mktui_sec_more': 'More states',
  },
  'hi': {
    'mktui_sec_your_state': 'आपका राज्य',
    'mktui_sec_with_prices': 'भाव उपलब्ध वाले राज्य',
    'mktui_sec_more': 'अन्य राज्य',
  },
  'te': {
    'mktui_sec_your_state': 'మీ రాష్ట్రం',
    'mktui_sec_with_prices': 'ధరలు ఉన్న రాష్ట్రాలు',
    'mktui_sec_more': 'మరిన్ని రాష్ట్రాలు',
  },
};

/// Loads the real translation assets so tests catch missing keys.
class MarketTestLoader extends AssetLoader {
  const MarketTestLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final file = File('assets/translations/${locale.languageCode}.json');
    final m = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    // Keys of the location sheet that may not be merged into the assets yet.
    (kPendingLocationKeys[locale.languageCode] ?? const {}).forEach((k, v) {
      m.putIfAbsent(k, () => v);
    });
    return m;
  }
}

/// Wraps [home] in EasyLocalization + MaterialApp at text [scale].
Widget marketTestApp(
  Widget home, {
  double scale = 1,
  String lang = 'en',
}) =>
    EasyLocalization(
      key: UniqueKey(),
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('te')],
      path: 'x',
      startLocale: Locale(lang),
      saveLocale: false,
      assetLoader: const MarketTestLoader(),
      child: Builder(
        builder: (context) => MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          builder: (c, w) => MediaQuery(
            data:
                MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
            child: w!,
          ),
          home: home,
        ),
      ),
    );

MarketPrice mp(
  String commodity,
  String market,
  String district, {
  String variety = '',
  double? min,
  double? max,
  double? modal,
  String date = '2026-10-06',
  String state = 'Andhra Pradesh',
}) =>
    MarketPrice(
      commodity: commodity,
      variety: variety,
      market: market,
      district: district,
      state: state,
      minPrice: min,
      maxPrice: max,
      modalPrice: modal,
      arrivalDate: parseMarketDate(date),
    );

/// ~30 realistic rows: 9 commodities, alias spellings, 3 districts, Telugu
/// and English names, some rows without prices and one older duplicate.
List<MarketPrice> sampleRows() => [
      mp('Paddy(Dhan)(Common)', 'Guntur', 'Guntur',
          variety: 'Sona Masuri', min: 2200, max: 2450, modal: 2320),
      mp('Paddy(Dhan)(Common)', 'Guntur', 'Guntur',
          variety: 'Sona Masuri',
          min: 2100,
          max: 2300,
          modal: 2200,
          date: '2026-10-05'),
      mp('Paddy(Common)', 'Vijayawada', 'Krishna',
          min: 2180, max: 2400, modal: 2300),
      mp('Paddy(Dhan)(Common)', 'Kurnool', 'Kurnool',
          min: 2250, max: 2500, modal: 2380),
      mp('Paddy(Common)', 'Machilipatnam', 'Krishna',
          variety: 'BPT 5204', min: 2900, max: 3200, modal: 3050),
      mp('Cotton', 'Guntur', 'Guntur',
          variety: 'H-4', min: 6800, max: 7600, modal: 7250),
      mp('Cotton', 'Adoni', 'Kurnool', min: 6500, max: 7400, modal: 7000),
      mp('Cotton', 'Vijayawada', 'Krishna'),
      mp('Tomato', 'Guntur', 'Guntur',
          variety: 'Local', min: 1200, max: 2400, modal: 1800),
      mp('Tomato', 'Vijayawada', 'Krishna', min: 1500, max: 2600, modal: 2000),
      mp('Tomato', 'Kurnool', 'Kurnool'),
      mp('Maize', 'Guntur', 'Guntur', min: 1900, max: 2250, modal: 2100),
      mp('Maize', 'Kurnool', 'Kurnool', min: 1850, max: 2150, modal: 2000),
      mp('Maize', 'Vijayawada', 'Krishna', min: 1950, max: 2200, modal: 2050),
      mp('Groundnut', 'Kurnool', 'Kurnool',
          variety: 'Bold', min: 5800, max: 6900, modal: 6350),
      mp('Groundnut', 'Guntur', 'Guntur', min: 5600, max: 6700, modal: 6200),
      mp('Groundnut', 'Vijayawada', 'Krishna'),
      mp('Turmeric', 'Guntur', 'Guntur',
          variety: 'Finger', min: 12000, max: 14500, modal: 13200),
      mp('Turmeric', 'Vijayawada', 'Krishna',
          min: 11800, max: 14000, modal: 12900),
      mp('Chilli Red', 'Guntur', 'Guntur',
          variety: 'Teja', min: 14000, max: 19000, modal: 16500),
      mp('Chilli Red', 'Vijayawada', 'Krishna',
          min: 13500, max: 18500, modal: 16000),
      mp('Chilli Red', 'Kurnool', 'Kurnool',
          min: 13000, max: 17800, modal: 15500),
      mp('Banana', 'Vijayawada', 'Krishna',
          variety: 'Robusta', min: 2200, max: 3200, modal: 2800),
      mp('Banana', 'Kurnool', 'Kurnool', min: 2100, max: 3000, modal: 2600),
      mp('Banana', 'Guntur', 'Guntur'),
      mp('మామిడి', 'Guntur', 'Guntur', min: 5000, max: 9000, modal: 7000),
      mp('మామిడి', 'Vijayawada', 'Krishna', min: 5200, max: 8800, modal: 6900),
      mp('Onion', 'Kurnool', 'Kurnool',
          variety: 'Red', min: 900, max: 2100, modal: 1500),
      mp('Onion', 'Guntur', 'Guntur', min: 1000, max: 2000, modal: 1600),
      mp('Red Gram (Tur/Arhar)', 'Guntur', 'Guntur',
          min: 7200, max: 8000, modal: 7650),
    ];

/// A [MarketPricesService] that never touches the network.
class FakeMarketService extends MarketPricesService {
  FakeMarketService({
    this.rows,
    this.error,
    this.stale = false,
    this.fromCache = false,
    this.mixed = false,
    this.locations,
    this.noDataForDistrict = false,
    this.delay = Duration.zero,
    this.partial = false,
    this.extraRows,
    this.noDataForState = false,
    this.noDataFirstCalls = 0,
  });

  /// Answer `no_data_for_state` (the server may sync the state on demand).
  bool noDataForState;

  /// Only the first [noDataFirstCalls] distinct load rounds fail (0 = all
  /// while [noDataForState] is set).
  int noDataFirstCalls;
  int _noDataServed = 0;

  /// Flag every result as paged-out (some commodities may be missing).
  bool partial;

  /// Rows only returned by requests for more than one day.
  List<MarketPrice>? extraRows;

  List<MarketPrice>? rows;
  MarketFetchError? error;
  bool stale;
  bool fromCache;

  /// Return the whole state even when a district matched (so only some
  /// commodities have a row in the user's district).
  bool mixed;
  MarketLocationsResult? locations;

  /// First call with a district answers noData; state-wide calls succeed.
  bool noDataForDistrict;
  Duration delay;

  final List<({String state, String? district, bool force, int days})> calls =
      [];

  @override
  Future<MarketPricesResult> fetchPrices({
    required String state,
    String? district,
    String? commodity,
    String lang = 'en',
    int limit = MarketPricesService.pageSize,
    int offset = 0,
    bool fetchAll = true,
    bool forceRefresh = false,
    int days = MarketPricesService.defaultDays,
  }) async {
    calls.add((
      state: state,
      district: district,
      force: forceRefresh,
      days: days,
    ));
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final hasDistrict = (district ?? '').isNotEmpty;
    if (noDataForState &&
        (noDataFirstCalls == 0 || _noDataServed < noDataFirstCalls)) {
      _noDataServed++;
      return const MarketPricesResult(
        error: MarketFetchError.noData,
        errorHint: 'no_data_for_state',
      );
    }
    if (noDataForDistrict && hasDistrict) {
      return const MarketPricesResult(error: MarketFetchError.noData);
    }
    final e = error;
    final list = [
      ...(rows ?? sampleRows()),
      if (days > 1) ...?extraRows,
    ];
    if (e != null && !(stale || fromCache)) {
      return MarketPricesResult(error: e);
    }
    var out = list.where((r) => r.state == state).toList();
    var level = MatchedLevel.state;
    if (hasDistrict) {
      final d = out
          .where((r) => r.district.toLowerCase() == district!.toLowerCase())
          .toList();
      if (d.isNotEmpty) {
        level = MatchedLevel.district;
        if (!mixed) out = d;
      }
    }
    return MarketPricesResult(
      records: out,
      resolvedState: state,
      resolvedDistrict: level == MatchedLevel.district ? district : null,
      matchedLevel: level,
      asOf: DateTime(2026, 10, 6),
      stale: stale,
      fromCache: fromCache,
      partial: partial,
      error: stale || fromCache ? e : null,
      fetchedAt: DateTime(2026, 10, 6, 8),
    );
  }

  @override
  Future<MarketLocationsResult> fetchLocations() async =>
      locations ??
      const MarketLocationsResult(states: [
        MarketStateInfo(
            state: 'Andhra Pradesh',
            districts: ['Guntur', 'Krishna', 'Kurnool']),
        MarketStateInfo(
            state: 'Telangana', districts: ['Hyderabad', 'Warangal']),
        MarketStateInfo(state: 'Karnataka', districts: ['Bengaluru']),
      ]);

  @override
  void dispose() {}
}

MarketLocationResult gpsGuntur() => const MarketLocationResult(
      location: MarketLocation(
          state: 'Andhra Pradesh',
          district: 'Guntur',
          source: MarketLocationSource.gps),
    );

MarketLocationResult gpsFailure(MarketLocationFailure f) =>
    MarketLocationResult(failure: f);

/// Calls that fetch the newest day (the first paint); one per data load.
List<({String state, String? district, bool force, int days})> firstPaintCalls(
        FakeMarketService s) =>
    s.calls.where((c) => c.days == 1).toList();
