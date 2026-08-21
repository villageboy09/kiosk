import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cropsync/widgets/home_tab.dart';

class HomeTestAssetLoader extends AssetLoader {
  const HomeTestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'home_feature_advisory_title': 'Crop Advisory',
      'home_feature_advisory_subtitle': 'Expert Tips',
      'home_feature_weather_title': 'Weather',
      'home_feature_weather_subtitle': 'Live Updates',
      'home_feature_market_title': 'Market Prices',
      'home_feature_market_subtitle': 'Real-time',
      'home_feature_shop_title': 'Agri Shop',
      'home_feature_shop_subtitle': 'Equipment',
      'home_feature_seeds_title': 'Seed Varieties',
      'home_feature_seeds_subtitle': 'Catalog',
      'home_feature_news_title': 'Agri News',
      'home_feature_news_subtitle': 'Latest Updates',
      'chc_title': 'CropSync CHC',
      'chc_book_now': 'Book Now',
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget buildTestableHomeTab({
    String? clientCode,
    required void Function(int) onTabSelected,
  }) {
    return EasyLocalization(
      supportedLocales: const [Locale('en')],
      path: 'assets/translations',
      startLocale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      assetLoader: const HomeTestAssetLoader(),
      child: Builder(
        builder: (context) {
          return MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: Scaffold(
              body: HomeTab(
                greeting: 'Good Morning',
                farmerName: 'Ramesh',
                clientCode: clientCode,
                onTabSelected: onTabSelected,
              ),
            ),
          );
        },
      ),
    );
  }

  group('HomeTab News / CHC Card Conditional Display Tests', () {
    testWidgets('Shows News Card when clientCode is null', (tester) async {
      int selectedTab = -1;

      await tester.pumpWidget(
        buildTestableHomeTab(
          clientCode: null,
          onTabSelected: (index) => selectedTab = index,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should display Agri News card
      expect(find.text('Agri News'), findsOneWidget);
      expect(find.text('CropSync CHC'), findsNothing);

      // Tapping Agri News card triggers onTabSelected(2)
      await tester.tap(find.text('Agri News'));
      await tester.pump();
      expect(selectedTab, 2);
    });

    testWidgets('Shows News Card when clientCode is HYD001', (tester) async {
      int selectedTab = -1;

      await tester.pumpWidget(
        buildTestableHomeTab(
          clientCode: 'HYD001',
          onTabSelected: (index) => selectedTab = index,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should display Agri News card
      expect(find.text('Agri News'), findsOneWidget);
      expect(find.text('CropSync CHC'), findsNothing);

      // Tapping Agri News card triggers onTabSelected(2)
      await tester.tap(find.text('Agri News'));
      await tester.pump();
      expect(selectedTab, 2);
    });

    testWidgets('Shows News Card when clientCode is lowercase or padded hyd001', (tester) async {
      await tester.pumpWidget(
        buildTestableHomeTab(
          clientCode: '  hyd001  ',
          onTabSelected: (_) {},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Agri News'), findsOneWidget);
      expect(find.text('CropSync CHC'), findsNothing);
    });

    testWidgets('Shows CHC Card when user has a specific regional clientCode (e.g. KHM001)', (tester) async {
      await tester.pumpWidget(
        buildTestableHomeTab(
          clientCode: 'KHM001',
          onTabSelected: (_) {},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should display CHC card instead of News card
      expect(find.text('CropSync CHC'), findsOneWidget);
      expect(find.text('Agri News'), findsNothing);
    });
  });
}
