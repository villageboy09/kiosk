import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cropsync/models/market_location.dart';
import 'package:cropsync/models/market_price.dart';
import 'package:cropsync/screens/commodity_detail_screen.dart';
import 'package:cropsync/services/market_prices_service.dart';
import 'package:cropsync/widgets/market/commodity_trend_chart.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// English strings of the `mktd_` keys (merged into assets separately).
const Map<String, String> mktdEn = {
  "mktd_in_place": "In {place}",
  "mktd_best_at": "Best price at {place}",
  "mktd_min_max": "Min {min} · Max {max}",
  "mktd_as_of": "As of {date}",
  "mktd_no_price": "Price not reported yet",
  "mktd_vs_prev": "vs last price",
  "mktd_market_one": "1 market",
  "mktd_markets_n": "{} markets",
  "mktd_varieties_n": "{} varieties",
  "mktd_all_varieties": "All varieties",
  "mktd_stats_title": "Across all markets",
  "mktd_stat_highest": "Highest",
  "mktd_stat_average": "Average",
  "mktd_stat_lowest": "Lowest",
  "mktd_trend_title": "Price trend",
  "mktd_days_n": "{} days",
  "mktd_trend_empty": "Not enough price history yet",
  "mktd_trend_empty_hint":
      "The chart appears once we have prices from a few different days.",
  "mktd_retry": "Check again",
  "mktd_markets_title": "Markets",
  "mktd_your_district": "Your district",
  "mktd_show_all": "Show all {} markets",
  "mktd_show_less": "Show less",
  "mktd_share_text": "{name}: {price}/qtl at {place} - CropSync",
  "mktd_share_text_noprice": "{name} market prices - CropSync",
  "mktd_cat_cereals": "Cereals",
  "mktd_cat_pulses": "Pulses",
  "mktd_cat_oilseeds": "Oilseeds",
  "mktd_cat_vegetables": "Vegetables",
  "mktd_cat_fruits": "Fruits",
  "mktd_cat_spices": "Spices",
  "mktd_cat_cash_crops": "Cash crops",
  "mktd_cat_other": "Other",
};

class _Loader extends AssetLoader {
  final Map<String, String> extra;
  const _Loader(this.extra);
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final base =
        jsonDecode(File('assets/translations/en.json').readAsStringSync())
            as Map<String, dynamic>;
    return {...base, ...extra};
  }
}

/// Fake trends source: returns [points] or throws when [fail].
class FakeTrendsService extends MarketPricesService {
  final List<TrendPoint> points;
  final bool fail;
  int calls = 0;
  FakeTrendsService({this.points = const [], this.fail = false});

  @override
  Future<List<TrendPoint>> fetchTrends({
    required String state,
    String? district,
    required String commodity,
    int days = 30,
  }) async {
    calls++;
    if (fail) throw Exception('boom');
    return points;
  }
}

/// District-level trends are empty; state-level ones have points.
class DistrictlessTrendsService extends MarketPricesService {
  final List<String?> districts = [];
  @override
  Future<List<TrendPoint>> fetchTrends({
    required String state,
    String? district,
    required String commodity,
    int days = 30,
  }) async {
    districts.add(district);
    return (district ?? '').isEmpty ? realPoints() : const [];
  }
}

final Uint8List kTestPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

List<TrendPoint> realPoints([int n = 10]) => [
      for (var i = 0; i < n; i++)
        TrendPoint(
          date: DateTime(2026, 9, 20).add(Duration(days: i)),
          avgPrice: 6400 + (i * 37) % 300 + i * 20.0,
        ),
    ];

MarketPrice _row(String market, String district, double? modal,
        {String variety = '',
        String grade = '',
        double? min,
        double? max,
        DateTime? date,
        String commodity = 'Paddy(Common)'}) =>
    MarketPrice(
      commodity: commodity,
      variety: variety,
      grade: grade,
      market: market,
      district: district,
      state: 'Telangana',
      modalPrice: modal,
      minPrice: min ?? (modal == null ? null : modal - 250),
      maxPrice: max ?? (modal == null ? null : modal + 300),
      arrivalDate: date ?? DateTime(2026, 10, 6),
    );

/// 11 rows across districts and varieties, Telugu names and unpriced rows.
List<MarketPrice> sampleRows() => [
      _row('Warangal', 'Warangal', 6850, variety: 'Sona Masuri', grade: 'FAQ'),
      _row('Nizamabad', 'Nizamabad', 7020, variety: 'Sona Masuri'),
      _row('Karimnagar', 'Karimnagar', 6600, variety: 'BPT 5204'),
      _row('Khammam', 'Khammam', 6710, variety: 'BPT 5204', grade: 'Medium'),
      _row('గుంటూరు', 'గుంటూరు', 6900, variety: 'Sona Masuri'),
      _row('Mahabubnagar', 'Mahabubnagar', 6480, variety: 'HMT'),
      _row('Adilabad', 'Adilabad', null, variety: 'Sona Masuri'),
      _row('Medak', 'Medak', 6390, variety: 'HMT'),
      _row('Siddipet', 'Siddipet', 6555, variety: 'BPT 5204'),
      _row('Nalgonda', 'Nalgonda', 6620, variety: 'Sona Masuri'),
      _row('Suryapet', 'Suryapet', null, variety: 'HMT'),
    ];

CommodityPrices sampleCommodity({List<MarketPrice>? rows, String? district}) =>
    groupByCommodity(rows ?? sampleRows(), userDistrict: district).first;

const kLocation = MarketLocation(
    state: 'Telangana',
    district: 'Karimnagar',
    source: MarketLocationSource.manual);

Future<void> pumpDetail(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(360, 800),
  double scale = 1.0,
  Locale locale = const Locale('en'),
  Map<String, String>? strings,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
  await tester.pumpWidget(EasyLocalization(
    supportedLocales: [locale],
    path: 'assets/translations',
    startLocale: locale,
    fallbackLocale: locale,
    assetLoader: _Loader(strings ?? mktdEn),
    child: Builder(
      builder: (context) => MaterialApp(
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        home: screen,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Widget detailScreen({
  CommodityPrices? commodity,
  MarketPricesService? service,
  MarketLocation? location = kLocation,
  ImageProvider? image,
}) =>
    CommodityDetailScreen(
      commodity: commodity ?? sampleCommodity(district: location?.district),
      location: location,
      service: service ?? FakeTrendsService(points: realPoints()),
      debugImageProvider: image ?? MemoryImage(kTestPng),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void ignoreFontErrors() {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exception.toString().contains('google_fonts')) return;
      prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
  }

  group('layout', () {
    for (final size in const [
      Size(320, 640),
      Size(360, 800),
      Size(1280, 800)
    ]) {
      for (final scale in const [1.0, 2.0]) {
        testWidgets('no overflow ${size.width}x${size.height} @$scale',
            (tester) async {
          ignoreFontErrors();
          await pumpDetail(tester, detailScreen(), size: size, scale: scale);
          expect(tester.takeException(), isNull);
          // Expand the table and make sure it still lays out.
          final toggle = find.byKey(const ValueKey('market_show_all'));
          await tester.scrollUntilVisible(toggle, 300,
              scrollable: find.byType(Scrollable).first);
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('Telugu locale lays out at 320 wide', (tester) async {
      ignoreFontErrors();
      await pumpDetail(tester, detailScreen(),
          size: const Size(320, 640), scale: 1.3, locale: const Locale('te'));
      expect(tester.takeException(), isNull);
    });
  });

  group('markets table', () {
    testWidgets('user district row first, value column aligned',
        (tester) async {
      ignoreFontErrors();
      await pumpDetail(tester, detailScreen());
      final first =
          tester.widget<Text>(find.byKey(const ValueKey('market_name_0')));
      expect(first.data, 'Karimnagar');
      expect(find.byKey(const ValueKey('market_mine_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('market_mine_1')), findsNothing);
      // Second row is the highest modal price overall.
      final second =
          tester.widget<Text>(find.byKey(const ValueKey('market_name_1')));
      expect(second.data, 'Nizamabad');

      final xs = <double>{};
      final nameXs = <double>{};
      for (var i = 0; i < 8; i++) {
        final v = find.byKey(ValueKey('market_value_$i'));
        expect(v, findsOneWidget);
        xs.add(tester.getTopLeft(v).dx);
        nameXs
            .add(tester.getTopLeft(find.byKey(ValueKey('market_name_$i'))).dx);
      }
      expect(xs, hasLength(1));
      expect(nameXs, hasLength(1));
    });

    testWidgets('collapses beyond 8 rows and expands', (tester) async {
      ignoreFontErrors();
      await pumpDetail(tester, detailScreen());
      expect(find.byKey(const ValueKey('market_name_7')), findsOneWidget);
      expect(find.byKey(const ValueKey('market_name_8')), findsNothing);
      final toggle = find.byKey(const ValueKey('market_show_all'));
      await tester.scrollUntilVisible(toggle, 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('market_name_10')), findsOneWidget);
      // Unpriced rows are last and show a dash, never 'N/A'.
      for (final i in [9, 10]) {
        final v = tester.widget<Text>(find.byKey(ValueKey('market_value_$i')));
        expect(v.data, '—');
      }
      expect(find.textContaining('N/A'), findsNothing);
    });

    testWidgets('variety chips filter the table', (tester) async {
      ignoreFontErrors();
      await pumpDetail(tester, detailScreen());
      expect(
          find.byKey(const ValueKey('market_variety_chips')), findsOneWidget);
      final hmt = find.descendant(
          of: find.byKey(const ValueKey('market_variety_chips')),
          matching: find.text('HMT'));
      await tester.ensureVisible(hmt);
      await tester.pumpAndSettle();
      await tester.tap(hmt);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('market_name_2')), findsOneWidget);
      expect(find.byKey(const ValueKey('market_name_3')), findsNothing);
    });
  });

  group('trend', () {
    testWidgets('chart present with >= 2 real points', (tester) async {
      ignoreFontErrors();
      await pumpDetail(tester, detailScreen());
      expect(find.byType(CommodityTrendChart), findsOneWidget);
      expect(find.byKey(const ValueKey('market_trend_empty')), findsNothing);
      expect(find.byKey(const ValueKey('market_change_chip')), findsOneWidget);
    });

    testWidgets('placeholder, no chart and no change chip when insufficient',
        (tester) async {
      ignoreFontErrors();
      await pumpDetail(
          tester,
          detailScreen(
              service: FakeTrendsService(points: [realPoints(1).first])));
      expect(find.byType(CommodityTrendChart), findsNothing);
      expect(find.byKey(const ValueKey('market_trend_empty')), findsOneWidget);
      expect(find.text('Not enough price history yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('market_change_chip')), findsNothing);
    });

    testWidgets('failure shows placeholder and retry refetches',
        (tester) async {
      ignoreFontErrors();
      final svc = FakeTrendsService(fail: true);
      await pumpDetail(tester, detailScreen(service: svc));
      expect(find.byType(CommodityTrendChart), findsNothing);
      final before = svc.calls;
      await tester
          .ensureVisible(find.byKey(const ValueKey('market_trend_retry')));
      await tester.tap(find.byKey(const ValueKey('market_trend_retry')));
      await tester.pumpAndSettle();
      // The district request is retried state-wide once, so a retry is two
      // calls.
      expect(svc.calls, before + 2);
    });

    testWidgets('changing range refetches with that many days', (tester) async {
      ignoreFontErrors();
      final svc = FakeTrendsService(points: realPoints());
      await pumpDetail(tester, detailScreen(service: svc));
      expect(svc.calls, 1);
      await tester.ensureVisible(find.byKey(const ValueKey('market_days_7')));
      await tester.tap(find.byKey(const ValueKey('market_days_7')));
      await tester.pumpAndSettle();
      expect(svc.calls, 2);
    });
  });

  group('round 2', () {
    testWidgets('older rows are marked and left out of the statistics',
        (tester) async {
      ignoreFontErrors();
      final c = sampleCommodity(rows: [
        _row('Warangal', 'Warangal', 6850),
        _row('Nizamabad', 'Nizamabad', 7020),
        _row('Hyderabad', 'Hyderabad', 9999, date: DateTime(2026, 10, 3)),
      ]);
      await pumpDetail(
          tester,
          detailScreen(
              commodity: c,
              location: const MarketLocation(
                  state: 'Telangana',
                  district: 'Adilabad',
                  source: MarketLocationSource.manual)));
      expect(find.text('Best price at Nizamabad'), findsOneWidget);
      final stats = find.byKey(const ValueKey('market_stats'));
      expect(find.descendant(of: stats, matching: find.text('₹7,020')),
          findsOneWidget);
      expect(find.descendant(of: stats, matching: find.text('₹9,999')),
          findsNothing);
      // The older row is last among priced rows and carries its date.
      expect(find.byKey(const ValueKey('market_older_2')), findsOneWidget);
      expect(find.byKey(const ValueKey('market_older_0')), findsNothing);
      expect(find.text('As of 3 Oct'), findsOneWidget);
    });

    testWidgets('a variety filter labels the trend and hides the change chip',
        (tester) async {
      ignoreFontErrors();
      await pumpDetail(tester, detailScreen());
      expect(find.byKey(const ValueKey('market_change_chip')), findsOneWidget);
      expect(find.byKey(const ValueKey('market_trend_caption')), findsNothing);
      final hmt = find.descendant(
          of: find.byKey(const ValueKey('market_variety_chips')),
          matching: find.text('HMT'));
      await tester.ensureVisible(hmt);
      await tester.pumpAndSettle();
      await tester.tap(hmt);
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('market_trend_caption')), findsOneWidget);
      expect(find.byKey(const ValueKey('market_change_chip')), findsNothing);
    });

    testWidgets('title uses the localized commodity name', (tester) async {
      ignoreFontErrors();
      final c = sampleCommodity(rows: [
        _row('Warangal', 'Warangal', 1800, commodity: 'Tomato'),
        _row('Nizamabad', 'Nizamabad', 2000, commodity: 'Tomato'),
      ]);
      await pumpDetail(tester, detailScreen(commodity: c),
          locale: const Locale('te'));
      final title =
          tester.widget<Text>(find.byKey(const ValueKey('market_title')));
      expect(title.data, 'టమోటా');
    });

    testWidgets('no district history retries state-wide once', (tester) async {
      ignoreFontErrors();
      final svc = DistrictlessTrendsService();
      await pumpDetail(tester, detailScreen(service: svc));
      expect(svc.districts, ['Karimnagar', null]);
      expect(find.byType(CommodityTrendChart), findsOneWidget);
    });
  });

  group('content', () {
    testWidgets('price block uses the user district, never N/A',
        (tester) async {
      ignoreFontErrors();
      await pumpDetail(tester, detailScreen());
      expect(find.text('In Karimnagar'), findsOneWidget);
      expect(find.textContaining('N/A'), findsNothing);
      expect(find.text('Min ₹6,350 · Max ₹6,900'), findsOneWidget);
    });

    testWidgets('falls back to the best market without a local row',
        (tester) async {
      ignoreFontErrors();
      await pumpDetail(
          tester,
          detailScreen(
              location: const MarketLocation(
                  state: 'Telangana',
                  district: 'Hyderabad',
                  source: MarketLocationSource.manual)));
      expect(find.text('Best price at Nizamabad'), findsOneWidget);
      expect(find.byKey(const ValueKey('market_mine_0')), findsNothing);
    });

    testWidgets('no priced rows shows dashes and a calm message',
        (tester) async {
      ignoreFontErrors();
      final c = sampleCommodity(rows: [
        _row('Adilabad', 'Adilabad', null),
        _row('Medak', 'Medak', null),
      ]);
      await pumpDetail(tester, detailScreen(commodity: c));
      expect(tester.takeException(), isNull);
      expect(find.text('Price not reported yet'), findsOneWidget);
      expect(find.textContaining('N/A'), findsNothing);
    });
  });
}
