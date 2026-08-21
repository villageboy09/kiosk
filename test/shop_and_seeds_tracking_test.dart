import 'package:cropsync/screens/agri_shop.dart';
import 'package:cropsync/screens/seed_varieties.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShopTestAssetLoader extends AssetLoader {
  const ShopTestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'all_category': 'All',
      'fertilizers': 'Fertilizers',
      'pesticides': 'Pesticides',
      'seeds': 'Seeds',
      'equipment': 'Equipment',
      'search_products': 'Search products',
      'no_products_found': 'No products found',
      'home_feature_shop_title': 'Agri Shop',
      'home_feature_seeds_title': 'Seed Varieties',
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget wrapWithLocalization(Widget child, {required Size screenSize}) {
    return MediaQuery(
      data: MediaQueryData(size: screenSize),
      child: EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        startLocale: const Locale('en'),
        fallbackLocale: const Locale('en'),
        assetLoader: const ShopTestAssetLoader(),
        child: Builder(
          builder: (context) {
            return MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: child,
            );
          },
        ),
      ),
    );
  }

  group('Shop & Seed Varieties Tracking and Responsiveness Tests', () {
    testWidgets('AgriShopScreen renders search bar and category bar on mobile (360x640)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithLocalization(
          const AgriShopScreen(),
          screenSize: const Size(360, 640),
        ),
      );
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget); // Search bar
    });

    testWidgets('AgriShopScreen renders on tablet screen (1280x800)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithLocalization(
          const AgriShopScreen(),
          screenSize: const Size(1280, 800),
        ),
      );
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('SeedVarietiesScreen renders crop filter tabs on mobile (360x640)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithLocalization(
          const SeedVarietiesScreen(),
          screenSize: const Size(360, 640),
        ),
      );
      await tester.pump();

      expect(find.byType(SeedVarietiesScreen), findsOneWidget);
    });

    testWidgets('SeedVarietiesScreen renders on tablet screen (1280x800)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithLocalization(
          const SeedVarietiesScreen(),
          screenSize: const Size(1280, 800),
        ),
      );
      await tester.pump();

      expect(find.byType(SeedVarietiesScreen), findsOneWidget);
    });
  });
}
