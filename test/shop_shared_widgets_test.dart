import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cropsync/widgets/shop/shop_category_style.dart';
import 'package:cropsync/widgets/shop/shop_chrome.dart';
import 'package:cropsync/widgets/shop/shop_discover.dart';
import 'package:cropsync/widgets/shop/shop_product_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Uint8List _png1x1 = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

class _Loader extends AssetLoader {
  const _Loader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {};
}

class _Item {
  final int id;
  final String cat;
  final DateTime? at;
  const _Item(this.id, this.cat, [this.at]);
}

Widget _app(Widget child, {double scale = 1.0}) => EasyLocalization(
      supportedLocales: const [Locale('en')],
      path: 'x',
      startLocale: const Locale('en'),
      assetLoader: const _Loader(),
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          builder: (c, w) => MediaQuery(
            data:
                MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
            child: w!,
          ),
          home: Scaffold(body: child),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    HttpOverrides.global = null;
  });

  group('buildRails', () {
    test('fresh by createdAt desc, rails >=2, more deduped', () {
      final items = [
        for (var i = 1; i <= 12; i++)
          _Item(i, i <= 6 ? 'a' : (i == 7 ? 'b' : 'c'),
              DateTime(2024, 1, 1).add(Duration(days: i))),
      ];
      final d = buildRails<_Item>(
        items: items,
        categoryOf: (e) => e.cat,
        idOf: (e) => e.id,
        createdAtOf: (e) => e.at,
        categoryOrder: ['c', 'a'],
        railItems: 4,
      );
      expect(d.fresh.map((e) => e.id), [12, 11, 10, 9]);
      expect(d.rails.map((r) => r.category), ['c', 'a']); // 'b' has 1 item
      final shown = {
        ...d.fresh.map((e) => e.id),
        for (final r in d.rails) ...r.items.map((e) => e.id),
      };
      expect(d.more.every((e) => !shown.contains(e.id)), isTrue);
      expect(d.more.map((e) => e.id), [5, 6, 7]);
    });

    test('falls back to id desc and respects maxRails', () {
      final items = [
        for (var i = 1; i <= 8; i++) _Item(i, 'c${i % 4}'),
      ];
      final d = buildRails<_Item>(
        items: items,
        categoryOf: (e) => e.cat,
        idOf: (e) => e.id,
        maxRails: 2,
      );
      expect(d.fresh.first.id, 8);
      expect(d.rails.length, 2);
    });
  });

  group('cropStyle', () {
    test('keywords in en/hi/te', () {
      final paddy = cropStyle('Paddy');
      expect(cropStyle('వరి').icon, paddy.icon);
      expect(cropStyle('धान').icon, paddy.icon);
      expect(cropStyle('Cotton').icon, isNot(paddy.icon));
      expect(cropStyle('పత్తి').icon, cropStyle('कपास').icon);
      expect(cropStyle('మిర్చి').icon, cropStyle('Chilli').icon);
      expect(cropStyle('Maize').icon, cropStyle('मक्का').icon);
      expect(cropStyle('Groundnut').icon, cropStyle('వేరుశనగ').icon);
      expect(cropStyle('Wheat').icon, cropStyle('गेहूं').icon);
      expect(cropStyle('Tomato').icon, cropStyle('టమాట').icon);
      expect(cropStyle('Red gram dal').icon, cropStyle('కంది').icon);
      expect(cropStyle('Zzz').icon, Icons.eco_rounded);
      expect(cropStyle('').icon, Icons.eco_rounded);
    });
  });

  for (final size in const [Size(320, 640), Size(360, 640), Size(1280, 800)]) {
    testWidgets('DiscoverHome<T> renders at ${size.width} scale 1.3',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      final items = [
        for (var i = 1; i <= 6; i++) _Item(i, i.isEven ? 'a' : 'b')
      ];
      final data = buildRails<_Item>(
          items: items, categoryOf: (e) => e.cat, idOf: (e) => e.id);
      String? seeAll;
      await tester.pumpWidget(_app(
        SingleChildScrollView(
          child: DiscoverHome<_Item>(
            data: data,
            idOf: (e) => e.id,
            freshTitle: 'Fresh',
            moreTitle: 'More',
            railTitleFor: (_, c) => 'Cat $c',
            onSeeAll: (c) => seeAll = c,
            onViewAllMore: () {},
            railHeight: (w, s) => cardExtent(w, s.clamp(1, 1.5),
                infoHeight: 80 * s.clamp(1, 1.5)),
            itemBuilder: (_, e, w) => Container(
              key: ValueKey('card${e.id}'),
              color: Colors.green,
            ),
          ),
        ),
        scale: 1.3,
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(find.text('Fresh'), findsOneWidget);
      expect(find.text('Cat a'), findsOneWidget);
      await tester.ensureVisible(find.byType(TextButton).at(1));
      await tester.tap(find.byType(TextButton).at(1));
      expect(seeAll, isNotNull);
    });
  }

  testWidgets('ShopSearchRow has exactly one TextField', (tester) async {
    final c = TextEditingController(text: 'x');
    var cleared = false, filtered = false;
    await tester.pumpWidget(_app(ShopSearchRow(
      controller: c,
      hint: 'Search',
      onFilterTap: () => filtered = true,
      onClear: () => cleared = true,
      filterActive: true,
    )));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.tap(find.byIcon(Icons.tune_rounded));
    expect(cleared && filtered, isTrue);
  });

  testWidgets('ShopImageTile: contain fit, inset, heart tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(Center(
      child: SizedBox(
        width: 160,
        child: ShopImageTile(
          imageUrl: null,
          placeholderStyle: cropStyle('x'),
          debugImageProvider: MemoryImage(_png1x1),
          isNew: true,
          showVideoBadge: true,
          onToggleWishlist: () => taps++,
        ),
      ),
    )));
    await tester.pump();
    final img = tester.widget<Image>(find.byType(Image));
    expect(img.fit, BoxFit.contain);
    final tile = tester.getRect(find.byType(ShopImageTile));
    final imgRect = tester.getRect(find.byType(Image));
    expect(imgRect.left - tile.left, kShopCardImageInset);
    expect(tile.width, tile.height);
    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    expect(taps, 1);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  test('cardExtent', () {
    expect(cardExtent(100, 1, infoHeight: 50), 150);
    expect(cardExtent(100, 1, infoHeight: 50, imageAspect: 2), 100);
  });

  testWidgets('back button is the 46px round shop button and taps', (t) async {
    var taps = 0;
    await t.pumpWidget(_app(Center(
      child: ShopCircleBackButton(onPressed: () => taps++),
    )));
    await t.pumpAndSettle();
    final box = t.getSize(find.byType(InkWell));
    expect(box, const Size(46, 46));
    await t.tap(find.byType(ShopCircleBackButton));
    expect(taps, 1);
  });

  testWidgets('category chips scroll the selected chip into view', (t) async {
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final cats = ['all', for (var i = 0; i < 20; i++) 'Category number $i'];
    Widget chips(String sel) => _app(ShopCategoryChips(
          categories: cats,
          selected: sel,
          labelOf: (_, r) => r,
          onSelected: (_) {},
        ));
    await t.pumpWidget(chips('Category number 15'));
    await t.pumpAndSettle();
    final r = t.getRect(find.text('Category number 15'));
    expect(r.left, greaterThanOrEqualTo(0));
    expect(r.right, lessThanOrEqualTo(400));
    await t.pumpWidget(chips('all'));
    await t.pumpAndSettle();
    expect(t.getRect(find.text('all')).left, greaterThanOrEqualTo(0));
  });
}
