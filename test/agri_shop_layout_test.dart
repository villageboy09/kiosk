import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cropsync/screens/agri_shop.dart';
import 'package:cropsync/widgets/shop/shop_discover.dart';
import 'package:cropsync/widgets/shop/shop_product_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Uint8List _png1x1 = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

class _Loader extends AssetLoader {
  const _Loader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      {'crop_sync_market': 'Market', 'all_category': 'All'};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    HttpOverrides.global = null;
  });

  final sizes = [
    const Size(320, 568),
    const Size(360, 640),
    const Size(411, 731),
    const Size(1280, 800),
  ];

  for (final size in sizes) {
    for (final name in [
      'English product',
      'ఎరువులు మరియు పురుగుమందుల పొడవైన పేరు'
    ]) {
      testWidgets('card layout ${size.width}x${size.height} $name',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final p = Product(
          id: 1,
          advertiserId: 1,
          name: name * 3,
          category: 'c',
          price: '12000',
          description: '',
          advertiserName: 's',
          mrp: 15000,
        );
        await tester.pumpWidget(EasyLocalization(
          supportedLocales: const [Locale('te')],
          path: 'x',
          startLocale: const Locale('te'),
          assetLoader: const _Loader(),
          child: Builder(
            builder: (context) => MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: (size.width - 44) / 2,
                    height: shopCardExtent((size.width - 44) / 2, 1.3),
                    child: ShopProductCard(
                      product: p,
                      displayName: p.name,
                      isWishlisted: true,
                      isNew: true,
                      memCacheWidth: 200,
                      onTap: () {},
                      onToggleWishlist: () {},
                      onBuyNow: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('screen builds at 320x568 with text scale 1.3', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('te')],
      path: 'x',
      startLocale: const Locale('te'),
      assetLoader: const _Loader(),
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const AgriShopScreen(),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 20));
  });

  for (final size in sizes) {
    testWidgets('discover home ${size.width}x${size.height} te 1.3',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      final cats = ['Seeds', 'Fertilizers', 'Odd'];
      final products = [
        for (var i = 1; i <= 14; i++)
          Product(
            id: i,
            advertiserId: 1,
            name: 'ఎరువులు మరియు పురుగుమందుల పొడవైన పేరు $i' * 2,
            category: i == 14 ? 'Odd' : cats[i % 2],
            price: '${100 * i}',
            description: '',
            advertiserName: 's',
            mrp: i.isEven ? 200.0 * i : null,
            inStock: i != 3,
          ),
      ];
      await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('te')],
        path: 'x',
        startLocale: const Locale('te'),
        assetLoader: const _Loader(),
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ShopDiscoverHome(
                  products: products,
                  categories: cats,
                  wishlist: const {1},
                  isNew: (p) => p.id > 10,
                  categoryLabel: (c, r) => r,
                  productName: (c, n) => n,
                  onOpen: (_) {},
                  onBuyNow: (_) {},
                  onToggleWishlist: (_) {},
                  onSeeAll: (_) {},
                  onViewAll: () {},
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
    });
  }

  test('buildShopRails groups and skips single-item categories', () {
    Product p(int id, String c) => Product(
        id: id,
        advertiserId: 1,
        name: 'n',
        category: c,
        price: '1',
        description: '',
        advertiserName: 's');
    final r = buildShopRails(
        [p(1, 'A'), p(2, 'A'), p(3, 'B'), p(4, 'C'), p(5, 'C')],
        ['C', 'A', 'B']);
    expect(r.rails.map((e) => e.category), ['C', 'A']);
    // Everything is already in "New arrivals", so "More" is empty.
    expect(r.more, isEmpty);
    expect(r.fresh.first.id, 5);
  });

  test('buildShopRails more rail excludes fresh and rail products', () {
    Product p(int id, String c) => Product(
        id: id,
        advertiserId: 1,
        name: 'n',
        category: c,
        price: '1',
        description: '',
        advertiserName: 's');
    final list = [for (var i = 1; i <= 10; i++) p(i, 'X$i')];
    final r = buildShopRails(list, const []);
    final shown = {...r.fresh.map((e) => e.id)};
    expect(r.more.map((e) => e.id), [1, 2]);
    expect(r.more.any((e) => shown.contains(e.id)), isFalse);
  });

  testWidgets('ShopBackGate: not home -> back resets, stays mounted',
      (tester) async {
    var atHome = false;
    var resets = 0;
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Text('root')),
    ));
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute(
      builder: (_) => StatefulBuilder(builder: (c, setState) {
        return ShopBackGate(
          atHome: atHome,
          onBackToHome: () {
            resets++;
            setState(() => atHome = true);
          },
          child: const Scaffold(body: Text('shop')),
        );
      }),
    ));
    await tester.pumpAndSettle();
    expect(find.text('shop'), findsOneWidget);

    // Grid mode: first back stays on the shop and resets to home.
    await nav.maybePop();
    await tester.pumpAndSettle();
    expect(resets, 1);
    expect(find.text('shop'), findsOneWidget);

    // Home: back leaves the shop.
    await nav.maybePop();
    await tester.pumpAndSettle();
    expect(resets, 1);
    expect(find.text('shop'), findsNothing);
    expect(find.text('root'), findsOneWidget);
  });

  testWidgets('card image fills tile with BoxFit.contain, no overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final p = Product(
      id: 1,
      advertiserId: 1,
      name: 'P',
      category: 'c',
      price: '100',
      description: '',
      advertiserName: 's',
      inStock: false,
    );
    const w = 148.0;
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en')],
      path: 'x',
      startLocale: const Locale('en'),
      assetLoader: const _Loader(),
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          home: Scaffold(
            body: SizedBox(
              width: w,
              height: shopCardExtent(w, 1.0),
              child: ShopProductCard(
                product: p,
                displayName: 'P',
                isWishlisted: false,
                isNew: false,
                memCacheWidth: 200,
                onTap: () {},
                onToggleWishlist: () {},
                onBuyNow: () {},
                debugImageProvider: MemoryImage(_png1x1),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    final img = tester.widget<Image>(find.byType(Image));
    expect(img.fit, BoxFit.contain);
    // Image tile is square and inset by at most 4px on each side.
    final tile = tester.getSize(find.byType(Image));
    expect(tile.width, closeTo(w - 2 * kShopCardImageInset, 0.5));
    expect(tile.height, closeTo(tile.width, 1));
    expect(kShopCardImageInset, lessThanOrEqualTo(4));
    final op = tester.widget<Opacity>(find
        .ancestor(of: find.byType(Image), matching: find.byType(Opacity))
        .first);
    expect(op.opacity, closeTo(0.55, 0.001));
  });

  test('card button is a 40px tap target', () {
    expect(
        shopCardInfoHeight(1) >=
            8 +
                2 * 13.5 * 1.4 +
                4 +
                15 * 1.3 +
                2 +
                (10.5 * 1.3 + 4) +
                8 +
                40 +
                10,
        isTrue);
  });

  testWidgets('card has no overflow at OS text scale 2.0 (clamped to 1.5)',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final p = Product(
      id: 1,
      advertiserId: 1,
      name: 'ఎరువులు మరియు పురుగుమందుల పొడవైన పేరు',
      category: 'c',
      price: '12000',
      description: '',
      advertiserName: 's',
      mrp: 15000,
    );
    const w = (320 - 44) / 2;
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('te')],
      path: 'x',
      startLocale: const Locale('te'),
      assetLoader: const _Loader(),
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: w,
                height: shopCardExtent(w, 2.0),
                child: ShopProductCard(
                  product: p,
                  displayName: p.name,
                  isWishlisted: false,
                  isNew: false,
                  memCacheWidth: 200,
                  onTap: () {},
                  onToggleWishlist: () {},
                  onBuyNow: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
