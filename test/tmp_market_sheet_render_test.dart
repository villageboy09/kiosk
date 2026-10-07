import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cropsync/models/market_location.dart';
import 'package:cropsync/screens/market_prices.dart';
import 'package:cropsync/services/market_prices_service.dart';
import 'package:cropsync/widgets/market/market_location_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/market_list_fakes.dart';

const _out =
    '/private/tmp/claude-501/-Users-rdhanunjayreddy-development-Projects-kiosk/8f90c636-c117-492b-ae10-ac85a540a389/scratchpad';

Future<void> _font(String family, String path) async {
  final bytes = await File(path).readAsBytes();
  final l = FontLoader(family)
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await l.load();
}

Future<void> _loadFonts() async {
  final names = <String>[];
  runZonedGuarded(() {
    for (final w in FontWeight.values) {
      names.add(GoogleFonts.googleSans(fontWeight: w).fontFamily!);
    }
    names.add(GoogleFonts.tiroTelugu().fontFamily!);
    names.add(GoogleFonts.notoSansDevanagari().fontFamily!);
  }, (e, s) {});
  await Future<void>.delayed(const Duration(milliseconds: 50));
  await _loadFonts2(names);
}

Future<void> _loadFonts2(List<String> names) async {
  const reg = '/System/Library/Fonts/Supplemental/Arial.ttf';
  const bold = '/System/Library/Fonts/Supplemental/Arial Bold.ttf';
  for (var i = 0; i < FontWeight.values.length; i++) {
    await _font(names[i], i >= 5 ? bold : reg);
  }
  await _font('Roboto', reg);
  await _font('MaterialIcons',
      '${Platform.environment['FL']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  await _font(names[9], '/System/Library/Fonts/KohinoorTelugu.ttc');
  await _font(
      names[10], '/System/Library/Fonts/Supplemental/Arial Unicode.ttf');
}

const _locs = MarketLocationsResult(states: [
  MarketStateInfo(
      state: 'Andhra Pradesh',
      districts: [
        'Guntur',
        'Krishna',
        'Kurnool',
        'Nellore',
        'Prakasam',
        'Chittoor',
        'Anantapur'
      ],
      commodityCount: 40),
  MarketStateInfo(
      state: 'Telangana',
      districts: ['Hyderabad', 'Warangal', 'Karimnagar', 'Nizamabad'],
      commodityCount: 33),
  MarketStateInfo(
      state: 'Karnataka',
      districts: ['Bengaluru', 'Mysuru'],
      commodityCount: 20),
  MarketStateInfo(
      state: 'Maharashtra',
      districts: ['Pune', 'Nashik', 'Nagpur'],
      commodityCount: 25),
  MarketStateInfo(
      state: 'Tamil Nadu',
      districts: ['Chennai', 'Madurai'],
      commodityCount: 18),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await _loadFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({
        'market_last_location':
            '{"state":"Andhra Pradesh","district":"Guntur","source":"gps"}'
      }));

  void ignoreFontErrors() {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exception.toString().contains('google_fonts')) return;
      prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
  }

  Future<void> shot(WidgetTester t, GlobalKey k, String name) async {
    await t.runAsync(() async {
      final b = k.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 2);
      final d = await img.toByteData(format: ui.ImageByteFormat.png);
      await File('$_out/market_loc_$name.png')
          .writeAsBytes(d!.buffer.asUint8List());
    });
  }

  Future<GlobalKey> pump(WidgetTester t, Size size,
      {double scale = 1,
      String lang = 'en',
      MarketLocationsResult? locations,
      Future<MarketLocationResult> Function()? gps}) async {
    ignoreFontErrors();
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    final k = GlobalKey();
    await t.pumpWidget(RepaintBoundary(
      key: k,
      child: marketTestApp(
        MarketPricesScreen(
          service:
              FakeMarketService(mixed: true, locations: locations ?? _locs),
          locationResolver: gps ?? () async => gpsGuntur(),
        ),
        scale: scale,
        lang: lang,
      ),
    ));
    await t.pumpAndSettle();
    return k;
  }

  Future<void> open(WidgetTester t) async {
    await t.tap(find.byType(MarketLocationChip));
    await t.pumpAndSettle();
  }

  final sizes = {
    '360': (const Size(360, 800), 1.0, 'en'),
    '320': (const Size(320, 568), 1.3, 'te'),
    '1280': (const Size(1280, 800), 1.0, 'en'),
  };
  for (final e in sizes.entries) {
    testWidgets('screen ${e.key}', (t) async {
      final (size, scale, lang) = e.value;
      final k = await pump(t, size, scale: scale, lang: lang);
      await shot(t, k, 'screen_${e.key}');
    });
    testWidgets('sheet ${e.key}', (t) async {
      final (size, scale, lang) = e.value;
      final k = await pump(t, size, scale: scale, lang: lang);
      await open(t);
      await shot(t, k, 'sheet_${e.key}');
      await t.drag(find.byType(ListView).last, const Offset(0, -700));
      await t.pumpAndSettle();
      await shot(t, k, 'sheet_${e.key}_scrolled');
    });
  }
  testWidgets('sheet offline', (t) async {
    final k = await pump(t, const Size(360, 800),
        locations:
            const MarketLocationsResult(error: MarketFetchError.network));
    await open(t);
    await shot(t, k, 'sheet_offline');
  });
  testWidgets('screen banner', (t) async {
    final k = await pump(t, const Size(360, 800),
        gps: () async =>
            gpsFailure(MarketLocationFailure.permissionDeniedForever));
    await shot(t, k, 'screen_banner');
  });
}
