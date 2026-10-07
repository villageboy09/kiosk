import 'dart:convert';
import 'dart:io';

import 'package:cropsync/screens/agri_shop.dart';
import 'package:cropsync/screens/product_details_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Loader extends AssetLoader {
  const _Loader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
        ...Map<String, dynamic>.from(
            jsonDecode(File('assets/translations/en.json').readAsStringSync())),
        'pd_read_more': 'Read more',
        'pd_show_less': 'Show less',
      };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    HttpOverrides.global = null;
  });

  const desc = 'A long description paragraph that keeps going and going. '
      'It should exceed six lines at narrow widths so Read more shows.';

  Product mk({String name = 'Neem Oil', double? mrp, bool stock = true}) =>
      Product(
        id: 9,
        advertiserId: 1,
        name: name,
        category: 'Pesticides',
        price: '499',
        description: '$desc\n\n$desc\n\n$desc',
        advertiserName: 'Green Agro Traders',
        mrp: mrp,
        inStock: stock,
        unit: 'bottle',
      );

  Future<void> pump(WidgetTester t, Size size, Product p,
      {double scale = 1.3}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en')],
      path: 'x',
      startLocale: const Locale('en'),
      assetLoader: const _Loader(),
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          builder: (c, child) => MediaQuery(
            data:
                MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: ProductDetailsScreen(product: p),
        ),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
  }

  for (final size in const [Size(320, 568), Size(360, 800), Size(1280, 800)]) {
    for (final name in [
      'Neem Oil',
      'ఎరువులు మరియు పురుగుమందుల పొడవైన పేరు ' * 3
    ]) {
      for (final mrp in [null, 650.0]) {
        testWidgets('no overflow ${size.width}x${size.height} mrp=$mrp',
            (t) async {
          await pump(t, size, mk(name: name, mrp: mrp));
          expect(t.takeException(), isNull);
          // Buy bar stays visible.
          expect(find.byType(ElevatedButton), findsOneWidget);
        });
      }
    }
  }

  testWidgets('no overflow at 320px and text scale 2.0', (t) async {
    await pump(t, const Size(320, 568), mk(mrp: 650), scale: 2.0);
    expect(t.takeException(), isNull);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('out of stock disables buy button', (t) async {
    await pump(t, const Size(360, 800), mk(stock: false));
    final btn = t.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(btn.onPressed, isNull);
    expect(t.takeException(), isNull);
  });

  testWidgets('read more toggles', (t) async {
    await pump(t, const Size(320, 568), mk());
    final more = find.text('Read more');
    await t.scrollUntilVisible(more, 200,
        scrollable: find.byType(Scrollable).first);
    await t.tap(more);
    await t.pumpAndSettle();
    expect(find.text('Show less'), findsOneWidget);
  });
}
