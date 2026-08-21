import 'package:cropsync/screens/onboarding/language_selection_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestAssetLoader extends AssetLoader {
  const TestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'choose_language': locale.languageCode == 'te'
          ? 'మీ భాషను ఎంచుకోండి'
          : (locale.languageCode == 'hi'
              ? 'अपनी भाषा चुनें'
              : 'Choose Your Language'),
      'change_later_settings': 'You can change this later in Settings.',
      'continue': locale.languageCode == 'te'
          ? 'కొనసాగించు'
          : (locale.languageCode == 'hi' ? 'जारी रखें' : 'Continue'),
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget createTestWidget({required Size screenSize}) {
    return MediaQuery(
      data: MediaQueryData(size: screenSize),
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('hi'), Locale('te')],
        path: 'assets/translations',
        startLocale: const Locale('te'),
        fallbackLocale: const Locale('te'),
        assetLoader: const TestAssetLoader(),
        child: Builder(
          builder: (context) {
            return MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: const LanguageSelectionScreen(),
            );
          },
        ),
      ),
    );
  }

  testWidgets('Renders all languages on small phone screen without overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget(screenSize: const Size(360, 640)));
    await tester.pumpAndSettle();

    expect(find.text('తెలుగు'), findsOneWidget);
    expect(find.text('हिन्दी'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('Renders properly on tablet landscape screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget(screenSize: const Size(1280, 800)));
    await tester.pumpAndSettle();

    expect(find.text('తెలుగు'), findsOneWidget);
    expect(find.text('हिन्दी'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('Tapping Hindi switches active language and continues',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget(screenSize: const Size(390, 844)));
    await tester.pumpAndSettle();

    // Tap on Hindi card
    final hindiCard = find.text('हिन्दी');
    expect(hindiCard, findsOneWidget);
    await tester.tap(hindiCard);
    await tester.pumpAndSettle();

    // Tap continue button
    final continueBtn = find.byType(ElevatedButton);
    expect(continueBtn, findsOneWidget);
    await tester.tap(continueBtn);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('language_selected'), isTrue);
  });
}



