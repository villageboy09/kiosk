import 'package:cropsync/widgets/language_button.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Loader extends AssetLoader {
  const _Loader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      {'language_select_title': 'Select Language'};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('sheet lists 3 languages, tapping one sets locale and pops',
      (tester) async {
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('te')],
      path: 'assets/translations',
      startLocale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      assetLoader: const _Loader(),
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          home: const Scaffold(body: Center(child: LanguageButton())),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(LanguageButton));
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
    expect(find.text('తెలుగు'), findsOneWidget);
    expect(find.text('Telugu'), findsOneWidget);
    expect(find.text('हिन्दी'), findsOneWidget);
    expect(find.text('Hindi'), findsOneWidget);
    expect(find.text('Select Language'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));
    final visible = tester
        .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
        .where((o) => o.opacity == 1);
    expect(visible.length, 1);

    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();

    expect(find.text('हिन्दी'), findsNothing);
    final ctx = tester.element(find.byType(LanguageButton));
    expect(ctx.locale.languageCode, 'hi');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('language_selected'), isTrue);
  });
}
