import 'dart:io';

import 'package:cropsync/screens/agri_shop.dart';
import 'package:cropsync/widgets/shop/shop_product_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
                    height: (size.width - 44) / 2 + shopCardInfoHeight(1.3),
                    child: ShopProductCard(
                      product: p,
                      displayName: p.name,
                      isWishlisted: true,
                      isNew: true,
                      memCacheWidth: 200,
                      onTap: () {},
                      onToggleWishlist: () {},
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
}
