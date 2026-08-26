import 'package:cropsync/screens/crop_advisory_grid_screen.dart';
import 'package:cropsync/screens/crop_problems_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdvisoryTestAssetLoader extends AssetLoader {
  const AdvisoryTestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'home_feature_advisory_title': 'Crop Advisory',
      'home_feature_advisory_subtitle': 'Expert Tips',
      'advisory_grid_subtitle': 'Select a crop to explore complete growth stages, care guides, and disease protection',
      'advisory_search_crop_hint': 'Search crops (e.g. Rice, Cotton, Chilli)...',
      'advisory_sowing_to_harvest': 'Complete Guide from Sowing to Harvest',
      'advisory_search_problems_hint': 'Search problem by name, symptoms...',
      'advisory_filter_all': 'All Problems',
      'advisory_filter_disease': 'Diseases',
      'advisory_filter_pest': 'Pests & Insects',
      'advisory_filter_deficiency': 'Deficiencies',
      'advisory_filter_other': 'Other',
      'no_problems_found': 'No problems found',
      'problems_your_crop_is_healthy': 'Your crop is healthy',
      'problems_category_other': 'Other',
      'problems_view_treatments': 'View Control Remedies',
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
        assetLoader: const AdvisoryTestAssetLoader(),
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

  group('Crop Advisory Flow Responsive Widget Tests', () {
    testWidgets('CropAdvisoryGridScreen renders search bar and title on mobile (360x640)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithLocalization(
          const CropAdvisoryGridScreen(),
          screenSize: const Size(360, 640),
        ),
      );
      await tester.pump();

      expect(find.text('Crop Advisory'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search crops (e.g. Rice, Cotton, Chilli)...'), findsOneWidget);
    });

    testWidgets('CropAdvisoryGridScreen renders on tablet screen (1280x800)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithLocalization(
          const CropAdvisoryGridScreen(),
          screenSize: const Size(1280, 800),
        ),
      );
      await tester.pump();

      expect(find.text('Crop Advisory'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('CropProblemsScreen renders category filter chips and search on mobile (360x640)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithLocalization(
          CropProblemsScreen(
            cropId: 1,
            cropName: 'Paddy / వరి',
          ),
          screenSize: const Size(360, 640),
        ),
      );
      await tester.pump();

      expect(find.text('Paddy / వరి'), findsOneWidget);
      expect(find.text('All Problems'), findsOneWidget);
      expect(find.text('🦠 Diseases'), findsOneWidget);
      expect(find.text('🐛 Pests & Insects'), findsOneWidget);
      expect(find.text('🌿 Deficiencies'), findsOneWidget);
      expect(find.text('🌱 Other'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('CropProblemsScreen renders on tablet screen (1280x800)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithLocalization(
          CropProblemsScreen(
            cropId: 1,
            cropName: 'Paddy / వరి',
          ),
          screenSize: const Size(1280, 800),
        ),
      );
      await tester.pump();

      expect(find.text('Paddy / వరి'), findsOneWidget);
      expect(find.text('All Problems'), findsOneWidget);
      expect(find.text('🦠 Diseases'), findsOneWidget);
    });
  });
}
