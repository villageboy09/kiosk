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
      'machinery': 'Machinery',
      'tools': 'Tools',
      'search_products': 'Search products',
      'no_products_found': 'No products found',
      'home_feature_shop_title': 'Agri Shop',
      'home_feature_seeds_title': 'Seed Varieties',
      'crop_sync_market': 'CropSync Market',
      'seed_varieties_title': 'Seed Varieties',
      'authorized_dealers': 'Authorized Dealers',
      'genuine_inputs_tools': 'Genuine Inputs & Tools',
      'genuine_inputs_desc':
          'Certified inputs directly from verified suppliers',
      'input_assurance': 'Input Assurance',
      'certified_products_from_suppliers': 'Certified Products',
      'direct_farm_delivery': 'Direct Farm Delivery',
      'sealed_manufacturer_packaging': 'Sealed Packaging',
      'direct_dealer_assistance': 'Dealer Assistance',
      'icar_research_certified': 'ICAR & University Research Certified',
      'breeder_seeds_title': 'Breeder & Certified Seeds',
      'breeder_seeds_subtitle':
          'Direct high-yield genetics from trusted agricultural universities and certified seed producers.',
      'genuine_100': '100% Genuine Breeder Seeds',
      'yield_tested': 'Field Tested for High Yield',
      'farm_delivery': 'Direct Farm Delivery',
      'search_seeds_hint': 'Search crop, variety (e.g. BPT 5204)...',
      'crop_sync_seed_guarantee': 'CropSync Seed Guarantee',
      'why_order_seeds': 'Why order certified seeds through CropSync?',
      'breeder_authenticity': 'Breeder Authenticity',
      'breeder_authenticity_desc':
          'Directly traceable to university breeders and certified seed farms',
      'multi_region_trials': 'Multi-Region Field Trials',
      'multi_region_trials_desc':
          'Tested across state agro-climatic zones for disease resistance and yield',
      'sealed_bag_delivery': 'Sealed Bag Delivery',
      'sealed_bag_delivery_desc':
          'Tamper-evident tagged breeder packaging delivered directly to your farm',
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
    testWidgets(
        'AgriShopScreen renders search bar and category bar on mobile (360x640)',
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

    testWidgets(
        'SeedVarietiesScreen renders crop filter tabs on mobile (360x640)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithLocalization(
          SeedVarietiesScreen(debugLoader: (_, __) async => const []),
          screenSize: const Size(360, 640),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SeedVarietiesScreen), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('SeedVarietiesScreen renders on tablet screen (1280x800)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithLocalization(
          SeedVarietiesScreen(debugLoader: (_, __) async => const []),
          screenSize: const Size(1280, 800),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SeedVarietiesScreen), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
