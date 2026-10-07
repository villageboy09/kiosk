import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cropsync/models/seed_variety.dart';
import 'package:cropsync/models/user.dart';
import 'package:cropsync/screens/seed_variety_detail_screen.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'seed_booking_sheet_test.dart' show seedDetailEn;

class _Loader extends AssetLoader {
  const _Loader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final base =
        jsonDecode(File('assets/translations/en.json').readAsStringSync())
            as Map<String, dynamic>;
    return {...base, ...seedDetailEn};
  }
}

// 1x1 transparent PNG.
final Uint8List _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

SeedVariety _full({
  String name = 'Hybrid Cotton RCH 659',
  String? price = '145',
  String? details,
  bool video = false,
}) =>
    SeedVariety(
      id: 7,
      cropName: 'Cotton',
      varietyName: name,
      varietyNameSecondary: 'RCH-659 BG II',
      price: price,
      priceUnit: 'per_kg',
      averageYield: 22.5,
      growthDuration: 150,
      region: 'Telangana, Andhra Pradesh, Karnataka, Maharashtra',
      sowingPeriod: 'June - July',
      testimonialVideoUrl: video ? 'https://example.com/v.mp4' : null,
      details: details ??
          'A high yielding hybrid.\r\n\r\nBoll size: Medium. Plant height: 110 cm. '
              'Suitable for black soils with good drainage.',
    );

Future<void> _pump(
  WidgetTester tester,
  SeedVariety v, {
  Size size = const Size(360, 800),
  double scale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
  await tester.pumpWidget(EasyLocalization(
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
        home: SeedVarietyDetailScreen(
          variety: v,
          debugSkipVideo: true,
          debugImageProvider: MemoryImage(_png),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser =
        User(userId: '9704423653', name: 'Ravi', phoneNumber: '9704423653');
  });
  tearDown(() => AuthService.currentUser = null);

  void ignoreFontErrors() {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exception.toString().contains('google_fonts')) return;
      prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
  }

  group('parseSeedDetails', () {
    test('handles CRLF, blank lines, traits and sentences', () {
      final p = parseSeedDetails(
          'Great seed.\r\n\r\nBoll size: Medium. Height: 110 cm. Needs care.\n');
      expect(p.paragraphs, ['Great seed.', 'Needs care.']);
      expect(p.traits.map((e) => '${e.key}=${e.value}'),
          ['Boll size=Medium', 'Height=110 cm']);
    });

    test('empty / null input and urls are not traits', () {
      expect(parseSeedDetails(null).paragraphs, isEmpty);
      expect(parseSeedDetails('  \n ').traits, isEmpty);
      final p = parseSeedDetails('See https://example.com for more');
      expect(p.traits, isEmpty);
      expect(p.paragraphs, hasLength(1));
    });
  });

  group('parseSeedDetails traits', () {
    test('newline separated and single-line Key: value forms', () {
      final p = parseSeedDetails(
          'Duration: 140 days. Yield: 25 q/acre\nకాయ పరిమాణం : మధ్యస్థం\nPlain note here');
      expect(p.traits.map((e) => '${e.key}=${e.value}'),
          ['Duration=140 days', 'Yield=25 q/acre', 'కాయ పరిమాణం=మధ్యస్థం']);
      expect(p.paragraphs, ['Plain note here']);
    });

    test('colons and whitespace are trimmed, empty values hidden', () {
      final p = parseSeedDetails('Height::  110 cm\nSpacing:\nNotes:   ');
      expect(p.traits.map((e) => '${e.key}=${e.value}'), ['Height=110 cm']);
      expect(p.paragraphs, isEmpty);
    });
  });

  const sizes = [Size(320, 640), Size(360, 800), Size(1280, 800)];
  for (final size in sizes) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('no overflow at $size scale $scale (long Telugu name)',
          (tester) async {
        ignoreFontErrors();
        await _pump(
            tester,
            _full(
                name:
                    'అత్యుత్తమ దిగుబడినిచ్చే హైబ్రిడ్ పత్తి విత్తనాలు రకం ఆర్సిహెచ్ 659 ప్రత్యేక'),
            size: size,
            scale: scale);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('seed_book_now')), findsOneWidget);
        expect(find.byKey(const ValueKey('seed_facts')), findsOneWidget);
        // Scroll to the very bottom: no exception, content reachable.
        await tester.drag(
            find.byType(SingleChildScrollView).first, const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('bookable: price, facts and Book now opens the sheet',
      (tester) async {
    ignoreFontErrors();
    await _pump(tester, _full());
    expect(find.byKey(const ValueKey('seed_price')), findsOneWidget);
    expect(find.text('₹145 / kg'), findsOneWidget);
    expect(find.text('150 Days'), findsOneWidget);
    expect(find.text('22.5 Q/Acre'), findsOneWidget);
    expect(find.text('June - July'), findsOneWidget);
    expect(find.text('About this variety'), findsOneWidget);
    expect(find.text('Key traits'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.byKey(const ValueKey('seed_no_price')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('seed_book_now')));
    await tester.pumpAndSettle();
    expect(find.text('Confirm your booking'), findsOneWidget);
  });

  testWidgets('hero image has no card, border or shadow around it',
      (tester) async {
    ignoreFontErrors();
    await _pump(tester, _full());
    final img = find.byKey(const ValueKey('seed_hero_image'));
    expect(img, findsOneWidget);
    final ancestors =
        find.ancestor(of: img, matching: find.byType(DecoratedBox));
    for (final e in ancestors.evaluate()) {
      final d = (e.widget as DecoratedBox).decoration as BoxDecoration;
      expect(d.borderRadius, isNull);
      expect(d.boxShadow, isNull);
      expect(d.border, isNull);
      expect(d.color, isNull); // only the gradient backdrop
    }
    for (final t in [ClipRRect, ClipPath, PhysicalShape, Card]) {
      expect(find.ancestor(of: img, matching: find.byType(t)), findsNothing,
          reason: '$t around hero image');
    }
    // Image fits within the hero (contain, not cover).
    final image = tester
        .widget<Image>(find.descendant(of: img, matching: find.byType(Image)));
    expect(image.fit, BoxFit.contain);
  });

  testWidgets('traits table: labels and values align in two columns',
      (tester) async {
    ignoreFontErrors();
    await _pump(
        tester,
        _full(
            details: 'Boll size: Medium\n'
                'Disease tolerance: Tolerant to bollworm and moderately '
                'tolerant to leaf curl virus\n'
                'కాయ పరిమాణం: మధ్యస్థం, బాగా పెద్దది కూడా\n'
                'Spacing: 90 x 60 cm'),
        size: const Size(360, 1400));
    final table = find.byKey(const ValueKey('seed_traits'));
    expect(table, findsOneWidget);
    expect(find.byType(Table), findsNWidgets(2)); // facts + traits
    double? labelX, valueX;
    final tableRect = tester.getRect(table);
    for (var i = 0; i < 4; i++) {
      final l = tester.getTopLeft(find.descendant(
          of: table, matching: find.byKey(ValueKey('seed_kv_label_$i'))));
      final v = tester.getTopLeft(find.descendant(
          of: table, matching: find.byKey(ValueKey('seed_kv_value_$i'))));
      labelX ??= l.dx;
      valueX ??= v.dx;
      expect(l.dx, labelX, reason: 'label x row $i');
      expect(v.dx, valueX, reason: 'value x row $i');
      expect(v.dx - l.dx, greaterThan(tableRect.width * 0.38));
    }
    // Same columns as the facts table.
    final factsLabelX = tester
        .getTopLeft(find.byKey(const ValueKey('seed_kv_label_0')).first)
        .dx;
    expect(factsLabelX, closeTo(labelX! + 0, 25)); // icon indents facts labels
    // Value column starts at ~42% of the table width.
    expect((valueX! - tableRect.left) / tableRect.width, closeTo(0.42, 0.04));
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-bookable: no bar, muted price note', (tester) async {
    ignoreFontErrors();
    await _pump(tester, _full(price: null));
    expect(find.byKey(const ValueKey('seed_book_now')), findsNothing);
    expect(find.byKey(const ValueKey('seed_bar_price')), findsNothing);
    expect(find.byKey(const ValueKey('seed_no_price')), findsOneWidget);
    expect(find.text('Price not available right now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero price is treated as not bookable', (tester) async {
    ignoreFontErrors();
    await _pump(tester, _full(price: '0'));
    expect(find.byKey(const ValueKey('seed_book_now')), findsNothing);
  });

  testWidgets('missing optional data hides facts and about', (tester) async {
    ignoreFontErrors();
    await _pump(
        tester,
        SeedVariety(
            id: 1, cropName: 'Paddy', varietyName: 'Plain', price: '50'));
    expect(find.byKey(const ValueKey('seed_facts')), findsNothing);
    expect(find.text('About this variety'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wishlist heart persists', (tester) async {
    ignoreFontErrors();
    await _pump(tester, _full());
    await tester.tap(find.byKey(const ValueKey('seed_wish')));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('seed_wishlist_9704423653'), '[7]');
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('seed_wish')));
    await tester.pumpAndSettle();
    expect(prefs.getString('seed_wishlist_9704423653') ?? '[7]', '[]');
  });
}
