import 'package:cropsync/theme/app_text.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(
      WidgetTester t, Locale locale, void Function(BuildContext) f) async {
    await t.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('te')],
      path: 'assets/translations',
      startLocale: locale,
      useOnlyLangCode: true,
      assetLoader: const _EmptyLoader(),
      child: Builder(builder: (context) {
        return MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          home: Builder(builder: (c) {
            f(c);
            return const SizedBox();
          }),
        );
      }),
    ));
    await t.pumpAndSettle();
  }

  test('appHasTelugu', () {
    expect(appHasTelugu('విత్తనాలు'), isTrue);
    expect(appHasTelugu('Seeds 100'), isFalse);
  });

  testWidgets('English locale: telugu text -> Tiro, latin text -> not Tiro',
      (t) async {
    await pump(t, const Locale('en'), (c) {
      final te = appTextStyle(c, 'విత్తనాలు', const TextStyle());
      expect(te.fontFamily, contains('TiroTelugu'));
      expect(te.fontFamilyFallback, AppTheme.fontFallbacks);
      final en = appTextStyle(c, 'Seeds', const TextStyle());
      expect(en.fontFamily, isNot(contains('TiroTelugu')));
      expect(en.fontFamilyFallback, AppTheme.fontFallbacks);
      final ui = appUiStyle(c);
      expect(ui.fontFamily ?? '', isNot(contains('TiroTelugu')));
      expect(ui.fontFamilyFallback, AppTheme.fontFallbacks);
      final st = appStyle(c, text: 'Seeds', size: 12);
      expect(st.fontFamily, isNot(contains('TiroTelugu')));
      expect(st.fontSize, 12);
    });
  });

  testWidgets('Telugu locale: everything Tiro', (t) async {
    await pump(t, const Locale('te'), (c) {
      expect(appTextStyle(c, 'Seeds', const TextStyle()).fontFamily,
          contains('TiroTelugu'));
      expect(appUiStyle(c).fontFamily, contains('TiroTelugu'));
      expect(appStyle(c).fontFamilyFallback, AppTheme.fontFallbacks);
    });
  });
}

class _EmptyLoader extends AssetLoader {
  const _EmptyLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {};
}
