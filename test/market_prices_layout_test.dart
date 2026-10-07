import 'dart:async';
import 'dart:convert';

import 'package:cropsync/models/market_location.dart';
import 'package:cropsync/models/market_price.dart';
import 'package:cropsync/models/user.dart';
import 'package:cropsync/screens/market_prices.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/market_prices_service.dart';
import 'package:cropsync/utils/market_aliases.dart';
import 'package:cropsync/widgets/market/market_cards.dart';
import 'package:cropsync/widgets/market/market_location_sheet.dart';
import 'package:cropsync/widgets/market/market_location_ui.dart';
import 'package:cropsync/widgets/market/market_logic.dart';
import 'package:cropsync/widgets/shop/shop_discover.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/market_list_fakes.dart';

const _lastGuntur =
    '{"state":"Andhra Pradesh","district":"Guntur","source":"gps"}';

Widget _screen(
  FakeMarketService service, {
  Future<MarketLocationResult> Function()? resolver,
  double scale = 1,
  String lang = 'en',
  String? initial,
}) =>
    marketTestApp(
      MarketPricesScreen(
        service: service,
        locationResolver: resolver ?? () async => gpsGuntur(),
        initialCommodity: initial,
      ),
      scale: scale,
      lang: lang,
    );

Future<void> _pump(WidgetTester t, Widget w,
    {Size size = const Size(360, 800)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await t.pumpWidget(w);
  await t.pumpAndSettle();
}

/// Like [_pump] but only advances a few frames (skeletons animate forever).
Future<void> _pumpFrames(WidgetTester t, Widget w,
    {Size size = const Size(360, 800)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await t.pumpWidget(w);
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues(
        {'market_last_location': _lastGuntur});
    AuthService.currentUser = null;
  });
  tearDown(() => AuthService.currentUser = null);

  group('logic', () {
    test('dedupeLatestRows keeps the newest arrival per commodity+market', () {
      final rows = dedupeLatestRows(sampleRows());
      final guntur = rows.where(
          (r) => r.commodity == 'Paddy(Dhan)(Common)' && r.market == 'Guntur');
      expect(guntur.length, 1);
      expect(guntur.single.modalPrice, 2320);
      expect(rows.length, sampleRows().length - 1);
    });

    test('error mapping', () {
      MarketErrorView v(MarketFetchError e, [bool d = true]) =>
          marketErrorView(e, districtRequested: d);
      expect(v(MarketFetchError.network).titleKey, 'mktui_err_offline_title');
      expect(v(MarketFetchError.upstreamUnavailable).titleKey,
          'mktui_err_unavailable_title');
      expect(v(MarketFetchError.missingApiKey).titleKey,
          'mktui_err_unavailable_title');
      expect(v(MarketFetchError.noData).actions, [
        MarketErrorAction.showStateWide,
        MarketErrorAction.chooseAnother,
      ]);
      expect(v(MarketFetchError.noData, false).actions,
          [MarketErrorAction.chooseAnother]);
      expect(v(MarketFetchError.parse).titleKey, 'mktui_err_generic_title');
      expect(v(MarketFetchError.server).bodyKey, 'mkt_err_server');
    });

    test('sort highest puts unpriced last; search matches Telugu names', () {
      final all = groupByCommodityForTest();
      final idx = buildSearchIndex(all);
      final sorted = applyMarketFilters(all,
          filters: const MarketFilters(sort: MarketSort.highest),
          query: '',
          index: idx,
          lang: 'en');
      final prices = [for (final c in sorted) representativeRow(c)?.modalPrice];
      for (var i = 1; i < prices.length; i++) {
        if (prices[i] != null) {
          expect(prices[i - 1], greaterThanOrEqualTo(prices[i]!));
        }
      }
      final te = applyMarketFilters(all,
          filters: const MarketFilters(),
          query: 'పత్తి',
          index: idx,
          lang: 'en');
      expect(te.single.name, 'Cotton');
    });
  });

  for (final size in const [
    Size(320, 640),
    Size(360, 800),
    Size(411, 731),
    Size(1280, 800),
  ]) {
    testWidgets(
        'discover and grid do not overflow at ${size.width}x${size.height}, '
        'Telugu, text scale 1.3', (t) async {
      await _pump(
          t, _screen(FakeMarketService(mixed: true), scale: 1.3, lang: 'te'),
          size: size);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(CommodityRailCard), findsWidgets);
      await t.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await t.pumpAndSettle();
      await t.drag(find.byType(CustomScrollView), const Offset(0, 3000));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.chevron_right_rounded).first);
      await t.pumpAndSettle();
      expect(find.byType(CommodityRow), findsWidgets);
      expect(find.byType(TextField), findsOneWidget);
      await t.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('no N/A, no fake trends, exactly one TextField, unit is /qtl',
      (t) async {
    await _pump(
        t,
        _screen(FakeMarketService(
            mixed: true,
            rows: [...sampleRows(), mp('Jowar', 'Guntur', 'Guntur')])));
    expect(find.textContaining('N/A'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    expect(find.byIcon(Icons.trending_up), findsNothing);
    expect(find.byIcon(Icons.trending_down), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('/kg'), findsNothing);
    await t.enterText(find.byType(TextField), 'jowar');
    await t.pumpAndSettle();
    expect(find.textContaining('N/A'), findsNothing);
    expect(find.textContaining('Price not reported'), findsWidgets);
  });

  testWidgets('requests a recent window, always for the whole state',
      (t) async {
    final s = FakeMarketService(mixed: true);
    await _pump(t, _screen(s));
    // Newest day first, the earlier days follow without blocking.
    expect(s.calls.first.days, 1);
    expect(s.calls.last.days, MarketPricesService.defaultDays);
    expect(s.calls.first.state, 'Andhra Pradesh');
    // The district is only an ordering hint, never a request parameter.
    expect(s.calls.every((c) => (c.district ?? '').isEmpty), isTrue);
    expect(find.textContaining('Near you · Guntur, Andhra Pradesh'),
        findsOneWidget);
  });

  testWidgets('state-wide fetch is used even when the district matched',
      (t) async {
    final s = FakeMarketService(); // not mixed: used to narrow to Guntur
    await _pump(t, _screen(s));
    expect(s.calls.every((c) => c.state == 'Andhra Pradesh'), isTrue);
    expect(s.calls.every((c) => (c.district ?? '').isEmpty), isTrue);
    // Rows outside Guntur (Vijayawada banana) are still listed.
    await t.enterText(find.byType(TextField), 'banana');
    await t.pumpAndSettle();
    expect(find.textContaining('Best: Vijayawada'), findsOneWidget);
  });

  testWidgets('the district only reorders: Near you rows come first',
      (t) async {
    final s = FakeMarketService();
    await _pump(t, _screen(s));
    expect(find.text('Near you'), findsWidgets);
    expect(find.textContaining('Your district · Guntur'), findsWidgets);
  });

  testWidgets('back goes to discover first, then leaves', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(marketTestApp(Builder(
      builder: (c) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.push(
            c,
            MaterialPageRoute(
              builder: (_) => MarketPricesScreen(
                service: FakeMarketService(mixed: true),
                locationResolver: () async => gpsGuntur(),
              ),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    )));
    await t.pumpAndSettle();
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byType(CommodityRailCard), findsWidgets);

    await t.enterText(find.byType(TextField), 'cotton');
    await t.pumpAndSettle();
    expect(find.byType(CommodityRow), findsOneWidget);
    await t.tap(find.byIcon(Icons.arrow_back_ios_new));
    await t.pumpAndSettle();
    expect(find.byType(CommodityRailCard), findsWidgets);
    expect(find.byType(MarketPricesScreen), findsOneWidget);

    await t.tap(find.byIcon(Icons.chevron_right_rounded).first);
    await t.pumpAndSettle();
    expect(find.byType(CommodityRow), findsWidgets);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(MarketPricesScreen), findsOneWidget);
    expect(find.byType(CommodityRailCard), findsWidgets);

    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(MarketPricesScreen), findsNothing);
  });

  testWidgets('deep link pre-fills search', (t) async {
    await _pump(t, _screen(FakeMarketService(mixed: true), initial: 'Tomato'));
    expect(find.byType(CommodityRow), findsOneWidget);
    expect(find.text('Tomato'), findsWidgets);
  });

  group('location flow', () {
    testWidgets('profile first, then GPS moves the district hint only',
        (t) async {
      SharedPreferences.setMockInitialValues({});
      AuthService.currentUser = User(
          userId: '1',
          name: 'F',
          district: 'Kurnool',
          region: 'Andhra Pradesh');
      final gps = Completer<MarketLocationResult>();
      final s = FakeMarketService(mixed: true);
      await _pump(t, _screen(s, resolver: () => gps.future));
      expect(firstPaintCalls(s).length, 1);
      expect(s.calls.first.district, isNull);
      expect(find.textContaining('Your district · Kurnool, Andhra Pradesh'),
          findsOneWidget);

      gps.complete(gpsGuntur());
      await t.pumpAndSettle();
      // Same state: the rows are re-sorted, nothing is fetched again.
      expect(firstPaintCalls(s).length, 1);
      expect(s.calls.every((c) => (c.district ?? '').isEmpty), isTrue);
      expect(find.textContaining('Near you · Guntur'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('market_last_location')!)['district'],
          'Guntur');
    });

    testWidgets('same place from GPS does not refetch', (t) async {
      final s = FakeMarketService(mixed: true);
      await _pump(t, _screen(s));
      expect(firstPaintCalls(s).length, 1);
    });

    testWidgets('GPS denied shows a banner and the screen keeps working',
        (t) async {
      final s = FakeMarketService(mixed: true);
      await _pump(
          t,
          _screen(s,
              resolver: () async =>
                  gpsFailure(MarketLocationFailure.permissionDeniedForever)));
      expect(find.textContaining('Location permission is blocked'),
          findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
      expect(find.byType(CommodityRailCard), findsWidgets);
      await t.tap(find.byIcon(Icons.close_rounded));
      await t.pumpAndSettle();
      expect(
          find.textContaining('Location permission is blocked'), findsNothing);
    });

    testWidgets('timeout offers manual choice', (t) async {
      await _pump(
          t,
          _screen(FakeMarketService(mixed: true),
              resolver: () async => gpsFailure(MarketLocationFailure.timeout)));
      expect(find.text("Couldn't detect your location"), findsOneWidget);
      expect(find.text('Choose manually'), findsOneWidget);
    });

    testWidgets('no state anywhere shows Choose your state, no fetch',
        (t) async {
      SharedPreferences.setMockInitialValues({});
      final s = FakeMarketService(mixed: true);
      await _pump(
          t,
          _screen(s,
              resolver: () async =>
                  gpsFailure(MarketLocationFailure.permissionDenied)));
      expect(find.text('Choose your state'), findsOneWidget);
      expect(s.calls, isEmpty);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('a state tap applies state-wide at once, a district refines',
        (t) async {
      final s = FakeMarketService(mixed: true);
      await _pump(t, _screen(s), size: const Size(360, 1400));
      await t.tap(find.textContaining('Near you · Guntur'));
      await t.pumpAndSettle();
      expect(find.text('Use my location'), findsOneWidget);
      await t.tap(find.text('Telangana'));
      await t.pumpAndSettle();
      // Applied while the sheet is still open.
      expect(find.byType(MarketLocationSheet), findsOneWidget);
      expect(find.text('Whole state'), findsOneWidget);
      expect(find.text('Warangal'), findsOneWidget);
      expect(s.calls.last.state, 'Telangana');
      expect(s.calls.last.district, isNull);
      expect(find.textContaining('Prices for · Telangana'), findsOneWidget);
      var prefs = await SharedPreferences.getInstance();
      var m = jsonDecode(prefs.getString('market_manual_location')!);
      expect(m['state'], 'Telangana');
      expect(m['district'], '');
      expect(m['source'], 'manual');

      await t.tap(find.text('Warangal'));
      await t.pumpAndSettle();
      expect(find.byType(MarketLocationSheet), findsNothing);
      expect(find.textContaining('Prices for · Warangal, Telangana'),
          findsOneWidget);
      expect(s.calls.every((c) => (c.district ?? '').isEmpty), isTrue);
      prefs = await SharedPreferences.getInstance();
      m = jsonDecode(prefs.getString('market_manual_location')!);
      expect(m['district'], 'Warangal');
    });

    testWidgets('a saved manual choice wins and GPS is not run', (t) async {
      SharedPreferences.setMockInitialValues({
        'market_manual_location':
            '{"state":"Telangana","district":"Warangal","source":"manual"}',
      });
      var gpsCalls = 0;
      final s = FakeMarketService(rows: [
        mp('Cotton', 'Warangal', 'Warangal',
            state: 'Telangana', min: 6000, max: 7000, modal: 6500),
      ]);
      await _pump(
          t,
          _screen(s, resolver: () async {
            gpsCalls++;
            return gpsGuntur();
          }));
      expect(gpsCalls, 0);
      expect(firstPaintCalls(s).single.state, 'Telangana');
    });
  });

  group('round 2', () {
    Future<void> bgThenResume(WidgetTester t) async {
      final b = t.binding;
      b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      b.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
    }

    testWidgets('plain permission denied never retries on resume', (t) async {
      var gps = 0;
      await _pump(
          t,
          _screen(FakeMarketService(mixed: true), resolver: () async {
            gps++;
            return gpsFailure(MarketLocationFailure.permissionDenied);
          }));
      expect(gps, 1);
      await bgThenResume(t);
      await bgThenResume(t);
      expect(gps, 1);
      // The explicit tap still asks.
      await t.tap(find.text('Enable location'));
      await t.pumpAndSettle();
      expect(gps, 2);
    });

    testWidgets('denied forever retries once after the settings trip',
        (t) async {
      var gps = 0;
      await _pump(
          t,
          _screen(FakeMarketService(mixed: true), resolver: () async {
            gps++;
            return gpsFailure(MarketLocationFailure.permissionDeniedForever);
          }));
      expect(gps, 1);
      // A resume that did not come from the settings screen does nothing.
      await bgThenResume(t);
      expect(gps, 1);
      await t.tap(find.text('Open settings'));
      await t.pumpAndSettle();
      await bgThenResume(t);
      expect(gps, 2);
      // ... and only that once.
      await bgThenResume(t);
      expect(gps, 2);
    });

    testWidgets('service disabled retries after the settings trip', (t) async {
      var gps = 0;
      await _pump(
          t,
          _screen(FakeMarketService(mixed: true), resolver: () async {
            gps++;
            return gpsFailure(MarketLocationFailure.serviceDisabled);
          }));
      await t.tap(find.text('Turn on location'));
      await t.pumpAndSettle();
      await bgThenResume(t);
      expect(gps, 2);
    });

    testWidgets('partial results show a banner', (t) async {
      await _pump(t, _screen(FakeMarketService(mixed: true, partial: true)));
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
      expect(find.byType(CommodityRailCard), findsWidgets);
    });

    testWidgets('earlier days are merged in after the first paint', (t) async {
      final s = FakeMarketService(mixed: true, extraRows: [
        mp('Sesame', 'Guntur', 'Guntur',
            min: 9000, max: 11000, modal: 10000, date: '2026-10-05'),
      ]);
      await _pump(t, _screen(s));
      await t.enterText(find.byType(TextField), 'sesame');
      await t.pumpAndSettle();
      expect(find.byType(CommodityRow), findsOneWidget);
    });

    testWidgets('retry from the error panel shows the loading state first',
        (t) async {
      final s = FakeMarketService(
          error: MarketFetchError.network,
          delay: const Duration(milliseconds: 300));
      await _pump(t, _screen(s));
      expect(find.text('No internet'), findsOneWidget);
      await t.tap(find.text('Try again'));
      await t.pump();
      expect(find.text('No internet'), findsNothing);
      expect(find.byType(DiscoverSkeleton), findsOneWidget);
      await t.pumpAndSettle();
      expect(find.text('No internet'), findsOneWidget);
    });

    testWidgets('a share title deep link is cut at the colon', (t) async {
      await _pump(
          t,
          _screen(FakeMarketService(mixed: true),
              initial: 'Tomato: ₹1,800/qtl at Guntur - CropSync'));
      expect(find.byType(CommodityRow), findsOneWidget);
      expect(cleanInitialCommodity('Cotton'), 'Cotton');
      expect(cleanInitialCommodity('Cotton: 7250/qtl at Guntur - CropSync'),
          'Cotton');
    });

    testWidgets('a deep link that matches nothing leaves the search empty',
        (t) async {
      await _pump(
          t, _screen(FakeMarketService(mixed: true), initial: 'Unobtainium'));
      expect(find.byType(CommodityRailCard), findsWidgets);
      expect(find.text('No commodities match your search'), findsNothing);
      final field = t.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('rows say whose price they show', (t) async {
      await _pump(t, _screen(FakeMarketService(mixed: true)));
      await t.enterText(find.byType(TextField), 'tomato');
      await t.pumpAndSettle();
      expect(find.textContaining('Your district · Guntur'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'banana');
      await t.pumpAndSettle();
      expect(find.textContaining('Best: Vijayawada'), findsOneWidget);
    });

    testWidgets('rail cards say whose price they show', (t) async {
      await _pump(t, _screen(FakeMarketService(mixed: true)));
      expect(find.textContaining('Your district · Guntur'), findsWidgets);
      expect(find.textContaining('Best: '), findsWidgets);
    });
  });

  group('states', () {
    testWidgets('network error', (t) async {
      await _pump(
          t, _screen(FakeMarketService(error: MarketFetchError.network)));
      expect(find.text('No internet'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(CommodityRailCard), findsNothing);
    });

    testWidgets('upstream unavailable', (t) async {
      await _pump(
          t,
          _screen(
              FakeMarketService(error: MarketFetchError.upstreamUnavailable)));
      expect(find.text('Prices are temporarily unavailable'), findsOneWidget);
    });

    testWidgets('no data for a state retries once after 8 seconds', (t) async {
      final s = FakeMarketService(
          mixed: true, noDataForState: true, noDataFirstCalls: 1);
      await _pumpFrames(t, _screen(s));
      expect(s.calls.length, 1);
      expect(find.byType(DiscoverSkeleton), findsOneWidget);
      expect(find.textContaining('No prices for'), findsNothing);
      await t.pump(const Duration(seconds: 6));
      expect(s.calls.length, 1);
      await t.pump(const Duration(seconds: 2));
      await t.pump(const Duration(milliseconds: 100));
      expect(s.calls.first.force, isFalse);
      expect(s.calls[1].force, isTrue);
      await t.pump(const Duration(seconds: 1));
      expect(find.byType(CommodityRailCard), findsWidgets);
    });

    testWidgets('a second no_data answer shows the panel, no more retries',
        (t) async {
      final s = FakeMarketService(mixed: true, noDataForState: true);
      await _pumpFrames(t, _screen(s));
      await t.pump(const Duration(seconds: 9));
      await t.pump(const Duration(milliseconds: 100));
      expect(s.calls.length, 2);
      expect(find.text('No prices for Guntur, Andhra Pradesh yet'),
          findsOneWidget);
      expect(find.text('Choose another place'), findsOneWidget);
      await t.pump(const Duration(seconds: 30));
      expect(s.calls.length, 2);
    });

    testWidgets('the auto retry is cancelled on dispose', (t) async {
      final s = FakeMarketService(mixed: true, noDataForState: true);
      await _pumpFrames(t, _screen(s));
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 20));
      expect(s.calls.length, 1);
      expect(t.takeException(), isNull);
    });

    testWidgets('picking another state cancels the pending retry', (t) async {
      final s = FakeMarketService(
          mixed: true, noDataForState: true, noDataFirstCalls: 1);
      await _pumpFrames(t, _screen(s), size: const Size(360, 1400));
      await t.tap(find.byType(MarketLocationChip));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      await t.tap(find.text('Telangana'));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(s.calls.last.state, 'Telangana');
      await t.pump(const Duration(seconds: 9));
      // The old Andhra Pradesh request was never retried.
      expect(s.calls.where((c) => c.state == 'Andhra Pradesh').length, 1);
    });

    testWidgets('stale cache shows a banner with the date', (t) async {
      await _pump(
          t,
          _screen(FakeMarketService(
              mixed: true,
              stale: true,
              fromCache: true,
              error: MarketFetchError.network)));
      expect(find.textContaining('Showing saved prices from'), findsOneWidget);
      expect(find.byType(CommodityRailCard), findsWidgets);
    });

    testWidgets('a district without rows shows state-wide data and the note',
        (t) async {
      SharedPreferences.setMockInitialValues({
        'market_last_location':
            '{"state":"Andhra Pradesh","district":"Nellore","source":"gps"}',
      });
      await _pump(
          t,
          _screen(FakeMarketService(mixed: true),
              resolver: () async => const MarketLocationResult(
                  location: MarketLocation(
                      state: 'Andhra Pradesh',
                      district: 'Nellore',
                      source: MarketLocationSource.gps))));
      expect(find.text('No prices in Nellore; showing Andhra Pradesh'),
          findsOneWidget);
      expect(find.byType(CommodityRailCard), findsWidgets);
    });
  });

  group('location sheet and chip', () {
    Future<void> openSheet(WidgetTester t) async {
      await t.tap(find.byType(MarketLocationChip));
      await t.pumpAndSettle();
    }

    test('36 states / UTs with Telugu and Hindi display names', () {
      expect(kAllIndianStates.length, 36);
      expect(kAllIndianStates.toSet().length, 36);
      for (final n in kAllIndianStates) {
        expect(canonicalState(n), n);
        expect(stateDisplayName(n, 'en'), n);
      }
      expect(stateDisplayName('Telangana', 'te'), 'తెలంగాణ');
      expect(stateDisplayName('Telangana', 'hi'), 'तेलंगाना');
      expect(stateDisplayName('Goa', 'fr'), 'Goa');
    });

    for (final size in const [
      Size(320, 568),
      Size(360, 800),
      Size(1280, 800),
    ]) {
      testWidgets(
          'sheet does not overflow at ${size.width}x${size.height}, Telugu, '
          'scale 1.3', (t) async {
        await _pump(
            t, _screen(FakeMarketService(mixed: true), scale: 1.3, lang: 'te'),
            size: size);
        await openSheet(t);
        expect(find.byType(MarketLocationSheet), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        await t.drag(find.byType(ListView).last, const Offset(0, -2500));
        await t.pumpAndSettle();
        await t.drag(find.byType(ListView).last, const Offset(0, 2500));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('lists all 36 states, with-prices first, current pinned',
        (t) async {
      await _pump(t, _screen(FakeMarketService(mixed: true)),
          size: const Size(360, 5000));
      await openSheet(t);
      for (final n in kAllIndianStates) {
        expect(find.text(n), findsWidgets, reason: n);
      }
      expect(find.text('Your state'), findsOneWidget);
      expect(find.text('States with prices'), findsOneWidget);
      expect(find.text('More states'), findsOneWidget);
      double y(String name) => t.getTopLeft(find.text(name).first).dy;
      // Andhra Pradesh is the current state: pinned above everything.
      expect(y('Andhra Pradesh'), lessThan(y('Telangana')));
      // Karnataka has prices, Goa does not: Karnataka comes first.
      expect(y('Karnataka'), lessThan(y('Goa')));
      expect(y('Telangana'), lessThan(y('Goa')));
      expect(find.text('2 districts'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('offline: every state is still listed, no error panel',
        (t) async {
      final s = FakeMarketService(
          mixed: true,
          locations:
              const MarketLocationsResult(error: MarketFetchError.network));
      await _pump(t, _screen(s), size: const Size(360, 5000));
      await openSheet(t);
      for (final n in kAllIndianStates) {
        expect(find.text(n), findsWidgets, reason: n);
      }
      expect(find.text('Try again'), findsNothing);
      // The current state offers only "Whole state" plus the small hint.
      await t.tap(find.text('Andhra Pradesh'));
      await t.pumpAndSettle();
      expect(find.text('Whole state'), findsOneWidget);
      expect(find.text("Couldn't load the list of places"), findsOneWidget);
      // Choosing another state applies it state-wide at once.
      await t.tap(find.text('Goa'));
      await t.pumpAndSettle();
      expect(s.calls.last.state, 'Goa');
      expect(s.calls.last.district, isNull);
    });

    for (final size in const [Size(360, 800), Size(1280, 800)]) {
      testWidgets('the chip is centered at ${size.width}', (t) async {
        final s = FakeMarketService(
            mixed: true, delay: const Duration(milliseconds: 300));
        await _pumpFrames(t, _screen(s), size: size);
        double dx() => t
            .getRect(find.descendant(
                of: find.byType(MarketLocationChip),
                matching: find.byType(Material)))
            .center
            .dx;

        // Loading.
        expect(dx(), closeTo(size.width / 2, 0.5));
        expect(
            find.descendant(
                of: find.byType(MarketLocationChip),
                matching: find.byType(Center)),
            findsWidgets);
        await t.pumpAndSettle();
        // Loaded.
        expect(dx(), closeTo(size.width / 2, 0.5));
      });
    }

    testWidgets('the chip stays centered with a banner and a long place',
        (t) async {
      await _pump(
          t,
          _screen(FakeMarketService(mixed: true),
              scale: 1.3,
              resolver: () async =>
                  gpsFailure(MarketLocationFailure.permissionDeniedForever)),
          size: const Size(320, 640));
      final r = t.getRect(find.descendant(
          of: find.byType(MarketLocationChip),
          matching: find.byType(Material)));
      expect(r.center.dx, closeTo(160, 0.5));
      expect(r.width, lessThanOrEqualTo(320 * 0.9 + 0.5));
      expect(t.takeException(), isNull);
    });
  });
}

List<CommodityPrices> groupByCommodityForTest() =>
    groupByCommodity(dedupeLatestRows(sampleRows()), userDistrict: 'Guntur');
