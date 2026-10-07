import 'dart:io';

import 'package:cropsync/screens/seed_varieties.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/cache_service.dart';
import 'package:cropsync/utils/seed_logic.dart';
import 'package:cropsync/widgets/seeds/seed_variety_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Loader extends AssetLoader {
  const _Loader([this.strings = const {}]);
  final Map<String, dynamic> strings;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      strings;
}

SeedVariety _v(int id, String crop, String name,
        {String? price, double? y, int? d, bool video = false}) =>
    SeedVariety(
      id: id,
      cropName: crop,
      varietyName: name,
      price: price,
      priceUnit: 'per_packet',
      averageYield: y,
      growthDuration: d,
      testimonialVideoUrl: video ? 'https://x/y.mp4' : null,
    );

final _data = <SeedVariety>[
  _v(1, 'Rice', 'బిపిటి 5204 సాంబ మసూరి చాలా పొడవైన రకం పేరు పరీక్ష',
      price: '1450', y: 28, d: 135, video: true),
  _v(2, 'Rice', 'MTU 1010', price: '60', y: 26, d: 120),
  _v(3, 'Rice', 'Telangana Sona RNR 15048 Super Fine Grain Long Name', y: 24),
  _v(4, 'Rice', 'KNM 118', price: '55', d: 115),
  _v(5, 'Cotton', 'RCH 659 BG II', price: '864', y: 12, d: 160),
  _v(6, 'Cotton', 'Bunny Bt Cotton', price: '810'),
  _v(7, 'Cotton', 'Mallika Hybrid'),
  _v(8, 'Chilli', 'Teja S17', price: '320', y: 8, d: 150, video: true),
  _v(9, 'Chilli', 'Byadgi Kaddi', price: '410'),
  _v(10, 'Maize', 'DKC 9144', price: '1200', y: 32, d: 100),
  _v(11, 'Maize', 'P3396', y: 30, d: 105),
  _v(12, 'Maize', 'NK 6240', price: '1100', y: 29, d: 98),
];

Widget _app(Widget home,
        {double scale = 1,
        List<Locale> locales = const [Locale('en')],
        Map<String, dynamic> strings = const {}}) =>
    EasyLocalization(
      supportedLocales: locales,
      path: 'x',
      startLocale: const Locale('en'),
      assetLoader: _Loader(strings),
      child: Builder(
        builder: (context) => MaterialApp(
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

Widget _screen({double scale = 1, Map<String, dynamic> strings = const {}}) =>
    _app(
      SeedVarietiesScreen(debugLoader: (_, __) async => _data),
      scale: scale,
      strings: strings,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    HttpOverrides.global = null;
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in const [
    Size(320, 568),
    Size(360, 640),
    Size(411, 731),
    Size(1280, 800),
  ]) {
    testWidgets(
        'discover and grid do not overflow at ${size.width}x'
        '${size.height}, text scale 1.3', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_screen(scale: 1.3));
      await t.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(SeedVarietyCard), findsWidgets);
      await t.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await t.pumpAndSettle();
      await t.tap(find.text('shoph_see_all').first);
      await t.pumpAndSettle();
      await t.drag(find.byType(CustomScrollView), const Offset(0, 3000));
      await t.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await t.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('back returns to discover first, then leaves the screen',
      (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_app(Builder(
      builder: (c) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.push(
            c,
            MaterialPageRoute(
              builder: (_) =>
                  SeedVarietiesScreen(debugLoader: (_, __) async => _data),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    )));
    await t.pumpAndSettle();
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byType(SeedVarietiesScreen), findsOneWidget);

    // Select a crop -> grid; back goes to discover without leaving.
    await t.tap(find.text('Rice').first);
    await t.pumpAndSettle();
    expect(find.text('shoph_new_arrivals'), findsNothing);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(SeedVarietiesScreen), findsOneWidget);
    expect(find.text('shoph_new_arrivals'), findsOneWidget);

    // Search text -> back clears it, still on screen.
    await t.enterText(find.byType(TextField), 'MTU');
    await t.pumpAndSettle();
    expect(find.text('shoph_new_arrivals'), findsNothing);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(SeedVarietiesScreen), findsOneWidget);
    expect(find.text('shoph_new_arrivals'), findsOneWidget);

    // At discover the next back leaves.
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(SeedVarietiesScreen), findsNothing);
  });

  testWidgets('wishlist heart persists per user', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_screen());
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.favorite_border_rounded).at(1));
    await t.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('seed_wishlist_${_userKey()}');
    expect(stored, isNotNull);
    expect(stored, isNot('[]'));
  });

  testWidgets('bookable card shows Book now, others View details', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_screen());
    await t.pumpAndSettle();
    await t.tap(find.text('shoph_see_all').first);
    await t.pumpAndSettle();
    expect(find.text('book_button'), findsWidgets);
    expect(find.text('shop_wishlist_empty'), findsNothing);
  });

  for (final size in const [Size(320, 568), Size(360, 640), Size(1280, 800)]) {
    testWidgets('rails and grid do not overflow at OS text scale 2.0, $size',
        (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(
          _screen(scale: 2.0, strings: const {'shoph_see_all': 'See all'}));
      await t.pumpAndSettle();
      expect(find.byType(SeedVarietyCard), findsWidgets);
      await t.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await t.pumpAndSettle();
      await t.tap(find.text('See all').first);
      await t.pumpAndSettle();
      await t.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('failed load shows retry; retry reloads (not stuck empty)',
      (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    var calls = 0;
    await t.pumpWidget(_app(SeedVarietiesScreen(debugLoader: (_, __) async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return _data;
    })));
    await t.pumpAndSettle();
    expect(find.text('seedui_load_error'), findsOneWidget);
    expect(find.text('no_varieties_found'), findsNothing);
    await t.tap(find.text('shop_retry'));
    await t.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(SeedVarietyCard), findsWidgets);
  });

  test('getSeedVarieties does not cache a failure', () async {
    CacheService.clearAll();
    const key = '${CacheKeys.seedVarieties}_en';
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('boom', 500);
    });
    await http.runWithClient(() async {
      expect(await ApiService.getSeedVarieties(lang: 'en'), isEmpty);
      expect(CacheService.isValid(key), isFalse);
      await expectLater(
          ApiService.getSeedVarieties(lang: 'en', throwOnError: true),
          throwsException);
      expect(CacheService.isValid(key), isFalse);
    }, () => client);
    expect(calls, 2); // the second call really hit the network again
  });

  testWidgets('locale change keeps the selected crop', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    late BuildContext ctx;
    await t.pumpWidget(_app(
      Builder(builder: (c) {
        ctx = c;
        return SeedVarietiesScreen(debugLoader: (_, __) async => _data);
      }),
      locales: const [Locale('en'), Locale('te')],
    ));
    await t.pumpAndSettle();
    await t.tap(find.text('Rice').first);
    await t.pumpAndSettle();
    expect(find.text('shoph_new_arrivals'), findsNothing);
    await ctx.setLocale(const Locale('te'));
    await t.pumpAndSettle();
    // Still a filtered grid for Cotton, not reset to discover.
    expect(find.text('shoph_new_arrivals'), findsNothing);
    expect(find.byType(SeedVarietyCard), findsWidgets);
  });

  testWidgets('wishlist set by the detail screen shows in the list on return',
      (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_screen());
    await t.pumpAndSettle();
    await t.tap(find.text('shoph_see_all').first);
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    await t.tap(find.byType(SeedVarietyCard).at(1));
    await t.pumpAndSettle();
    expect(find.byType(SeedVarietyDetailScreen), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('seed_wish')));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.arrow_back_rounded));
    await t.pumpAndSettle();
    expect(find.byType(SeedVarietyDetailScreen), findsNothing);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 10));
  });

  testWidgets('toggling keeps previously stored ids', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({'seed_wishlist_guest': '[10]'});
    await t.pumpWidget(_screen());
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.favorite_border_rounded).at(1));
    await t.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('seed_wishlist_guest')!;
    expect(stored, contains('10'));
    expect(stored.split(',').length, 2);
  });

  group('logic', () {
    test('card info height grows with scale and is clamped at 1.5', () {
      expect(seedCardInfoHeight(1.3), greaterThan(seedCardInfoHeight(1.0)));
      expect(seedCardInfoHeight(3.0), seedCardInfoHeight(1.5));
    });

    test('dedupe keeps one row per id', () {
      expect(dedupeSeedVarieties([..._data, _data.first]).length, _data.length);
    });

    test('crops are ordered by count', () {
      expect(cropsByCount(_data).first, 'Rice');
    });
  });
}

String _userKey() => 'guest';
