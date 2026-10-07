import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cropsync/models/seed_variety.dart';
import 'package:cropsync/models/user.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/widgets/seeds/seed_booking_sheet.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real English strings plus the new seedd_ keys (kept in the keys handoff
/// file until merged into assets/translations).
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

const seedDetailEn = <String, String>{
  'seedd_book_now': 'Book now',
  'seedd_confirm_title': 'Confirm your booking',
  'seedd_confirm_btn': 'Confirm booking',
  'seedd_quantity': 'Quantity',
  'seedd_total': 'Total',
  'seedd_unit_kg': 'kg',
  'seedd_unit_packet': 'packets',
  'seedd_unit_bag': 'bags',
  'seedd_unit_quintal': 'quintals',
  'seedd_decrease': 'Decrease quantity',
  'seedd_increase': 'Increase quantity',
  'seedd_err_login': 'Please log in to book seeds',
  'seedd_err_unknown':
      'We could not confirm your booking. Please check before trying again.',
  'seedd_err_no_vendor': "This variety can't be booked right now",
  'seedd_success_title': 'Booking request sent!',
  'seedd_price_na': 'Price not available right now',
  'seedd_sowing': 'Sowing time',
  'seedd_duration': 'Duration',
  'seedd_yield': 'Average yield',
  'seedd_region': 'Suited regions',
  'seedd_about': 'About this variety',
  'seedd_traits': 'Key traits',
  'seedd_note': 'Details are shared by the seed supplier.',
};

SeedVariety _variety({
  String name = 'Hybrid Cotton RCH 659',
  String? price = '145',
  String? unit = 'per_kg',
}) =>
    SeedVariety(
      id: 42,
      cropName: 'Cotton',
      varietyName: name,
      price: price,
      priceUnit: unit,
    );

User _user() =>
    User(userId: '9704423653', name: 'Ravi', phoneNumber: '9704423653');

class _Host extends StatelessWidget {
  const _Host({required this.variety, required this.place, required this.out});
  final SeedVariety variety;
  final SeedBookingFn? place;
  final List<bool> out;

  @override
  Widget build(BuildContext context) => Center(
        child: ElevatedButton(
          key: const Key('open'),
          onPressed: () async => out.add(await showSeedBookingSheet(
              context, variety,
              placeBooking: place)),
          child: const Text('open'),
        ),
      );
}

Future<List<bool>> _open(
  WidgetTester tester, {
  required SeedVariety variety,
  SeedBookingFn? place,
  Size size = const Size(360, 640),
  double scale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
  final out = <bool>[];
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
        home: Scaffold(body: _Host(variety: variety, place: place, out: out)),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  return out;
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
    AuthService.currentUser = _user();
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

  group('SeedBookingResult.fromMap', () {
    test('maps success and the known error strings', () {
      expect(SeedBookingResult.fromMap({'success': true}).ok, isTrue);
      expect(
          SeedBookingResult.fromMap({
            'success': false,
            'error': 'No active vendor listing found for this variety'
          }).failure,
          SeedBookingFailure.noVendor);
      expect(
          SeedBookingResult.fromMap(
              {'success': false, 'error': 'Network error: boom'}).failure,
          SeedBookingFailure.network);
      expect(
          SeedBookingResult.fromMap(
              {'success': false, 'error': 'Server error: 500'}).failure,
          SeedBookingFailure.server);
      expect(
          SeedBookingResult.fromMap(null).failure, SeedBookingFailure.server);
    });
  });

  test('seedQuantityUnit follows the price unit', () {
    expect(seedQuantityUnit('per_kg'), 'kg');
    expect(seedQuantityUnit(null), 'kg');
    expect(seedQuantityUnit('per_450g_packet'), 'packet');
    expect(seedQuantityUnit('per_packet'), 'packet');
    expect(seedQuantityUnit('per_bag'), 'bag');
    expect(seedQuantityUnit('per_quintal'), 'quintal');
  });

  test('seedQuantityUnit maps bare gram/ml packs to packet, not kg', () {
    expect(seedQuantityUnit('per_450g'), 'packet');
    expect(seedQuantityUnit('per_500ml'), 'packet');
    expect(seedQuantityUnit('per_100 g'), 'packet');
    expect(seedQuantityUnit('per_1kg_pack'), 'packet');
    expect(seedQuantityUnit('per_kg'), 'kg');
    expect(seedQuantityUnit('kg'), 'kg');
    expect(seedQuantityUnit('per_5kg'), 'kg');
  });

  test('unknown-outcome map is neither network nor server', () {
    expect(
        SeedBookingResult.fromMap({
          'success': false,
          'error': 'Unreadable response: FormatException',
          'unknown': true,
        }).failure,
        SeedBookingFailure.unknown);
  });

  testWidgets('retry reuses the same booking id; unknown shows neutral text',
      (tester) async {
    ignoreFontErrors();
    final ids = <String>[];
    var calls = 0;
    await _open(tester, variety: _variety(), place: ({
      required bookingId,
      required userId,
      required seedVarietyId,
      required quantity,
      required totalPrice,
    }) async {
      ids.add(bookingId);
      calls++;
      return calls == 1
          ? const SeedBookingResult.failed(SeedBookingFailure.unknown)
          : const SeedBookingResult.success();
    });
    await tester.tap(find.byKey(const ValueKey('seed_primary')));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'We could not confirm your booking. Please check before trying again.'),
        findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('seed_primary')));
    await tester.tap(find.byKey(const ValueKey('seed_primary')));
    await tester.pumpAndSettle();
    expect(ids.length, 2);
    expect(ids[0], ids[1]);
    expect(ids[0], startsWith('SB'));
  });

  const sizes = [Size(320, 640), Size(360, 800), Size(1280, 800)];
  for (final size in sizes) {
    testWidgets('no overflow at $size, scale 1.3, long Telugu name',
        (tester) async {
      ignoreFontErrors();
      await _open(
        tester,
        variety: _variety(
            name:
                'అత్యుత్తమ దిగుబడినిచ్చే హైబ్రిడ్ పత్తి విత్తనాలు రకం ఆర్సిహెచ్ 659'),
        size: size,
        scale: 1.3,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Confirm your booking'), findsOneWidget);
      expect(find.text('Confirm booking'), findsOneWidget);
      expect(find.text('₹145'), findsWidgets);
    });
  }

  testWidgets('stepper bounds, label unit and live total', (tester) async {
    ignoreFontErrors();
    await _open(tester,
        variety: _variety(price: '60', unit: 'per_450g_packet'));
    expect(find.text('1 packets'), findsOneWidget);
    expect(find.text('₹60'), findsWidgets);

    // Min is 1: minus does nothing.
    await tester.tap(find.byKey(const ValueKey('seed_minus')));
    await tester.pump();
    expect(find.text('1 packets'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('seed_plus')));
    await tester.tap(find.byKey(const ValueKey('seed_plus')));
    await tester.pump();
    expect(find.text('3 packets'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('seed_total'))).data,
        '₹180');

    await tester.tap(find.byKey(const ValueKey('seed_minus')));
    await tester.pump();
    expect(find.text('2 packets'), findsOneWidget);
  });

  testWidgets('quantity stops at the maximum', (tester) async {
    ignoreFontErrors();
    await _open(tester, variety: _variety(price: '10'));
    final plus = find.byKey(const ValueKey('seed_plus'));
    for (var i = 0; i < kSeedMaxQuantity + 5; i++) {
      await tester.tap(plus, warnIfMissed: false);
    }
    await tester.pump();
    expect(find.text('$kSeedMaxQuantity kg'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('seed_total'))).data,
        '₹9,990'.replaceAll(',', ''));
  });

  testWidgets('success sends the right payload and returns true',
      (tester) async {
    ignoreFontErrors();
    Map<String, Object?>? sent;
    final out = await _open(tester, variety: _variety(), place: ({
      required bookingId,
      required userId,
      required seedVarietyId,
      required quantity,
      required totalPrice,
    }) async {
      sent = {
        'id': bookingId,
        'user': userId,
        'seed': seedVarietyId,
        'qty': quantity,
        'total': totalPrice,
      };
      return const SeedBookingResult.success();
    });
    await tester.tap(find.byKey(const ValueKey('seed_plus')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('seed_primary')));
    await tester.pumpAndSettle();
    expect(sent!['user'], '9704423653');
    expect(sent!['seed'], 42);
    expect(sent!['qty'], 2.0);
    expect(sent!['total'], 290.0);
    expect(sent!['id'], startsWith('SB'));
    expect(find.text('Booking request sent!'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('seed_done')));
    await tester.pumpAndSettle();
    expect(find.text('Booking request sent!'), findsNothing);
    expect(out, [true]);
  });

  testWidgets('guest gets the login message and no API call', (tester) async {
    ignoreFontErrors();
    AuthService.currentUser = null;
    var calls = 0;
    await _open(tester, variety: _variety(), place: ({
      required bookingId,
      required userId,
      required seedVarietyId,
      required quantity,
      required totalPrice,
    }) async {
      calls++;
      return const SeedBookingResult.success();
    });
    await tester.tap(find.byKey(const ValueKey('seed_primary')));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Please log in to book seeds'), findsOneWidget);
    expect(
        tester
            .widget<ElevatedButton>(find.byKey(const ValueKey('seed_primary')))
            .onPressed,
        isNull);
  });

  Future<void> failWith(
      WidgetTester tester, SeedBookingFailure f, String message,
      {required bool retry}) async {
    ignoreFontErrors();
    final out = await _open(tester,
        variety: _variety(),
        place: ({
          required bookingId,
          required userId,
          required seedVarietyId,
          required quantity,
          required totalPrice,
        }) async =>
            SeedBookingResult.failed(f));
    await tester.tap(find.byKey(const ValueKey('seed_primary')));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
    expect(find.text('Try again'), retry ? findsOneWidget : findsNothing);
    // The tall sheet scrolls on a small phone.
    await tester.ensureVisible(find.byKey(const ValueKey('seed_cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('seed_cancel')));
    await tester.pumpAndSettle();
    expect(out, [false]);
  }

  testWidgets('network error shows retry', (tester) async {
    await failWith(tester, SeedBookingFailure.network,
        'No internet connection, please try again',
        retry: true);
  });

  testWidgets('server error shows retry', (tester) async {
    await failWith(tester, SeedBookingFailure.server,
        'Something went wrong. Please try again.',
        retry: true);
  });

  testWidgets('no active vendor listing is not retryable', (tester) async {
    await failWith(tester, SeedBookingFailure.noVendor,
        "This variety can't be booked right now",
        retry: false);
  });

  testWidgets('a thrown exception becomes a server error', (tester) async {
    ignoreFontErrors();
    await _open(tester,
        variety: _variety(),
        place: ({
          required bookingId,
          required userId,
          required seedVarietyId,
          required quantity,
          required totalPrice,
        }) async =>
            throw StateError('boom'));
    await tester.tap(find.byKey(const ValueKey('seed_primary')));
    await tester.pumpAndSettle();
    expect(
        find.text('Something went wrong. Please try again.'), findsOneWidget);
  });

  testWidgets('double tap submits once; submitting blocks dismissal',
      (tester) async {
    ignoreFontErrors();
    final completer = Completer<SeedBookingResult>();
    var calls = 0;
    final out = await _open(tester, variety: _variety(), place: ({
      required bookingId,
      required userId,
      required seedVarietyId,
      required quantity,
      required totalPrice,
    }) {
      calls++;
      return completer.future;
    });
    final primary = find.byKey(const ValueKey('seed_primary'));
    await tester.tap(primary);
    await tester.tap(primary, warnIfMissed: false);
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Back / barrier cannot dismiss while submitting.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Confirm your booking'), findsOneWidget);
    // Stepper is locked.
    await tester.tap(find.byKey(const ValueKey('seed_plus')),
        warnIfMissed: false);
    await tester.pump();
    expect(find.text('1 kg'), findsOneWidget);

    completer.complete(const SeedBookingResult.success());
    await tester.pumpAndSettle();
    expect(find.text('Booking request sent!'), findsOneWidget);
    expect(calls, 1);
    await tester.tap(find.byKey(const ValueKey('seed_done')));
    await tester.pumpAndSettle();
    expect(out, [true]);
  });

  testWidgets('cancel returns false', (tester) async {
    ignoreFontErrors();
    final out = await _open(tester, variety: _variety());
    // The tall sheet scrolls on a small phone.
    await tester.ensureVisible(find.byKey(const ValueKey('seed_cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('seed_cancel')));
    await tester.pumpAndSettle();
    expect(out, [false]);
  });

  testWidgets('non-bookable variety cannot be submitted', (tester) async {
    ignoreFontErrors();
    var calls = 0;
    await _open(tester, variety: _variety(price: null), place: ({
      required bookingId,
      required userId,
      required seedVarietyId,
      required quantity,
      required totalPrice,
    }) async {
      calls++;
      return const SeedBookingResult.success();
    });
    expect(
        tester
            .widget<ElevatedButton>(find.byKey(const ValueKey('seed_primary')))
            .onPressed,
        isNull);
    expect(calls, 0);
  });
}
