import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cropsync/widgets/home_tab.dart';
import 'package:cropsync/services/global_notifiers.dart';
import 'package:cropsync/services/farmer_analytics_service.dart';

class AdvisoryTestAssetLoader extends AssetLoader {
  const AdvisoryTestAssetLoader();

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
    required void Function(int) onTabSelected,
  }) {
    return EasyLocalization(
      supportedLocales: const [Locale('en')],
      path: 'assets/translations',
      startLocale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      assetLoader: const AdvisoryTestAssetLoader(),
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
                onTabSelected: onTabSelected,
              ),
            ),
          );
        },
      ),
    );
  }

  group('HomeTab Crop Advisory Card Last Tapped Crop Tests', () {
    testWidgets('Shows default subtitle "Expert Tips" when no crop has been tapped', (tester) async {
      SharedPreferences.setMockInitialValues({});
      GlobalNotifiers.lastTappedCrop.value = null;

      int selectedTab = -1;
      await tester.pumpWidget(
        buildTestableHomeTab(onTabSelected: (index) => selectedTab = index),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Crop Advisory'), findsOneWidget);
      expect(find.text('Expert Tips'), findsOneWidget);

      await tester.tap(find.text('Crop Advisory'));
      await tester.pump();
      expect(selectedTab, 1);
    });

    testWidgets('Shows cached last tapped crop on Crop Advisory card', (tester) async {
      SharedPreferences.setMockInitialValues({
        'last_tapped_crop_name': 'Chilli (మిరప)',
        'last_tapped_crop_id': 5,
      });
      GlobalNotifiers.lastTappedCrop.value = 'Chilli (మిరప)';

      await tester.pumpWidget(
        buildTestableHomeTab(onTabSelected: (_) {}),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Crop Advisory'), findsOneWidget);
      expect(find.text('Chilli (మిరప)'), findsOneWidget);
    });

    testWidgets('Updates Crop Advisory subtitle when GlobalNotifiers emits new tapped crop', (tester) async {
      SharedPreferences.setMockInitialValues({});
      GlobalNotifiers.lastTappedCrop.value = null;

      await tester.pumpWidget(
        buildTestableHomeTab(onTabSelected: (_) {}),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Expert Tips'), findsOneWidget);

      // Simulate farmer tapping "Cotton / పత్తి" in advisory catalog
      FarmerAnalyticsService.logCropView(
        cropId: 2,
        cropName: 'Cotton / పత్తి',
        language: 'en',
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Cotton / పత్తి'), findsOneWidget);
      expect(find.text('Expert Tips'), findsNothing);
    });
  });
}
