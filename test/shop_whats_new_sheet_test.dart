import 'package:cropsync/models/shop_updates.dart';
import 'package:cropsync/services/shop_visit_tracker.dart';
import 'package:cropsync/widgets/shop_whats_new_sheet.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Loader extends AssetLoader {
  const _Loader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
        'shopnew_title': 'Fresh in the shop',
        'shopnew_products_one': '{} new product',
        'shopnew_products_other': '{} new products',
        'shopnew_offers_one': '{} new offer',
        'shopnew_offers_other': '{} new offers',
        'shopnew_explore': 'Explore now',
        'shopnew_later': 'Maybe later',
        'shopnew_new_pill': 'NEW',
        'shopnew_more': '+{} more',
      };
}

ShopUpdates _sample({int products = 6, bool banner = true}) => ShopUpdates(
      latestProductId: 50,
      latestBannerId: 9,
      newProductsCount: products,
      newProducts: [
        for (var i = 0; i < products.clamp(0, 5); i++)
          ShopUpdateProduct(
            id: 40 + i,
            name: i == 0
                ? 'సేంద్రియ ఎరువు ప్రీమియం నాణ్యత 50 కిలోలు'
                : 'Very Long Product Name Number $i For Overflow',
            price: '${100 + i}',
          ),
      ],
      newBannersCount: banner ? 1 : 0,
      newBanners: banner
          ? const [
              ShopUpdateBanner(
                  id: 9, title: 'Monsoon offer', subtitle: 'Save 20% today'),
            ]
          : const [],
    );

Widget _app(Widget home) => EasyLocalization(
      supportedLocales: const [Locale('en')],
      path: 'assets/translations',
      startLocale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      assetLoader: const _Loader(),
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          home: Scaffold(body: home),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ShopVisitTracker.resetSession();
  });

  const sizes = [Size(320, 568), Size(360, 640), Size(1280, 800)];
  for (final size in sizes) {
    testWidgets('sheet renders without overflow at $size, scale 1.3',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearAllTestValues();
      });
      var explored = 0, dismissed = 0;
      await tester.pumpWidget(_app(ShopWhatsNewSheet(
        updates: _sample(),
        onShopNow: () => explored++,
        onDismiss: () => dismissed++,
      )));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Fresh in the shop'), findsOneWidget);
      expect(find.text('6 new products · 1 new offer'), findsOneWidget);
      expect(find.textContaining('Very Long Product Name Number 1'),
          findsOneWidget);
      expect(find.textContaining('సేంద్రియ'), findsOneWidget);
      expect(find.text('+2 more'), findsOneWidget);
      expect(find.text('Monsoon offer'), findsOneWidget);
      expect(find.byKey(const Key('shop_whats_new_explore')), findsOneWidget);
      expect(find.byKey(const Key('shop_whats_new_later')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('shop_whats_new_later')));
      await tester.tap(find.byKey(const Key('shop_whats_new_explore')));
      await tester.tap(find.byKey(const Key('shop_whats_new_later')));
      expect(explored, 1);
      expect(dismissed, 1);
    });
  }

  testWidgets('no +N more when products fit', (tester) async {
    await tester.pumpWidget(_app(ShopWhatsNewSheet(
      updates: _sample(products: 3, banner: false),
      onShopNow: () {},
      onDismiss: () {},
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('more'), findsNothing);
    expect(find.text('3 new products'), findsOneWidget);
  });

  group('maybeShowShopWhatsNew flow', () {
    Future<BuildContext> pumpHost(WidgetTester tester) async {
      await tester.pumpWidget(_app(const SizedBox()));
      await tester.pumpAndSettle();
      return tester.element(find.byType(Scaffold));
    }

    testWidgets('first run shows nothing and marks ids seen', (tester) async {
      final ctx = await pumpHost(tester);
      await tester
          .runAsync(() => maybeShowShopWhatsNew(ctx, debugOverride: _sample()));
      await tester.pumpAndSettle();
      expect(find.byType(ShopWhatsNewSheet), findsNothing);
      expect(ShopVisitTracker.shownThisSession, isFalse);
      final seen = await tester.runAsync(
          () => ShopVisitTracker.load(ShopVisitTracker.currentUserKey()));
      expect(seen!.productId, 50);
      expect(seen.bannerId, 9);
    });

    testWidgets('second run shows once and marks seen when shown',
        (tester) async {
      final key = ShopVisitTracker.currentUserKey();
      await tester.runAsync(
          () => ShopVisitTracker.markSeen(key, productId: 30, bannerId: 5));
      final ctx = await pumpHost(tester);

      Future<void>? done;
      await tester.runAsync(() async {
        done = maybeShowShopWhatsNew(ctx, debugOverride: _sample());
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(find.byType(ShopWhatsNewSheet), findsOneWidget);
      expect(ShopVisitTracker.shownThisSession, isTrue);

      // Marked as soon as the sheet is shown (survives app kill).
      var seen = await tester.runAsync(() => ShopVisitTracker.load(key));
      expect(seen!.productId, 50);
      expect(seen.bannerId, 9);

      await tester.ensureVisible(find.byKey(const Key('shop_whats_new_later')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('shop_whats_new_later')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async => await done);
      expect(find.byType(ShopWhatsNewSheet), findsNothing);
      seen = await tester.runAsync(() => ShopVisitTracker.load(key));
      expect(seen!.productId, 50);
      expect(seen.bannerId, 9);

      // Same session: no second sheet.
      await tester
          .runAsync(() => maybeShowShopWhatsNew(ctx, debugOverride: _sample()));
      await tester.pumpAndSettle();
      expect(find.byType(ShopWhatsNewSheet), findsNothing);
    });
  });
}
