import 'dart:async';
import 'dart:convert';

import 'package:cropsync/models/product.dart';
import 'package:cropsync/models/user.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/widgets/shop/buy_now_sheet.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Loader extends AssetLoader {
  const _Loader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
        'buy_title': 'Confirm your order',
        'buy_sold_by': 'Sold by {}',
        'buy_off': '{}% off',
        'buy_call_you': 'The dealer will call you on {}',
        'buy_call_you_generic': 'The dealer will call you to confirm',
        'buy_pay_note': 'No online payment.',
        'buy_place_order': 'Place order request',
        'buy_out_of_stock': 'Out of stock',
        'buy_cancel': 'Cancel',
        'buy_try_again': 'Try again',
        'buy_success_title': 'Order request sent!',
        'buy_success_msg': 'The dealer will contact you soon.',
        'buy_done': 'Done',
        'buy_err_login': 'Please log in to place an order',
        'buy_err_seller': "This product can't be ordered right now",
        'buy_err_network': 'No internet connection, please try again',
        'buy_err_server': 'Something went wrong. Please try again.',
      };
}

Product _product({
  String name = 'Premium Organic Fertilizer 50kg',
  bool inStock = true,
  int advertiserId = 7,
  double? mrp = 600,
}) =>
    Product(
      id: 11,
      advertiserId: advertiserId,
      name: name,
      category: 'Fertilizer',
      price: '450',
      description: 'd',
      advertiserName: 'Green Agro Traders',
      mrp: mrp,
      inStock: inStock,
    );

User _user() =>
    User(userId: '9704423653', name: 'Ravi', phoneNumber: '9704423653');

/// Opens the sheet through a button and returns the future of its result.
class _Host extends StatelessWidget {
  const _Host({required this.product, required this.place, required this.out});
  final Product product;
  final PlaceEnquiryFn? place;
  final List<bool> out;

  @override
  Widget build(BuildContext context) => Center(
        child: ElevatedButton(
          key: const Key('open'),
          onPressed: () async => out.add(
              await showBuyNowSheet(context, product, placeEnquiry: place)),
          child: const Text('open'),
        ),
      );
}

Future<List<bool>> _open(
  WidgetTester tester, {
  required Product product,
  PlaceEnquiryFn? place,
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
        home: Scaffold(body: _Host(product: product, place: place, out: out)),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  return out;
}

Future<EnquiryResult> _ok({
  required int productId,
  required String farmerId,
  required int advertiserId,
}) async =>
    const EnquiryResult.success(id: 5);

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

  // GoogleFonts load failures surface as async errors in tests; ignore them.
  void ignoreFontErrors() {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exception.toString().contains('google_fonts')) return;
      prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
  }

  const sizes = [Size(320, 568), Size(360, 640), Size(1280, 800)];
  for (final size in sizes) {
    testWidgets('no overflow at $size, scale 1.3, Telugu name', (tester) async {
      ignoreFontErrors();
      await _open(
        tester,
        product: _product(
            name: 'సేంద్రియ ఎరువు ప్రీమియం నాణ్యత 50 కిలోలు అత్యుత్తమ నాణ్యత'),
        size: size,
        scale: 1.3,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Confirm your order'), findsOneWidget);
      expect(
          find.text('The dealer will call you on 9704423653'), findsOneWidget);
      expect(find.text('25% off'), findsOneWidget);
      expect(find.text('Place order request'), findsOneWidget);
    });
  }

  testWidgets('idle -> success flow returns true', (tester) async {
    ignoreFontErrors();
    var calls = 0;
    int? sentAdvertiser;
    String? sentFarmer;
    final out = await _open(tester, product: _product(), place: ({
      required productId,
      required farmerId,
      required advertiserId,
    }) async {
      calls++;
      sentAdvertiser = advertiserId;
      sentFarmer = farmerId;
      return const EnquiryResult.success(id: 1);
    });
    await tester.tap(find.byKey(const Key('buy_primary')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(sentAdvertiser, 7);
    expect(sentFarmer, '9704423653');
    expect(find.text('Order request sent!'), findsOneWidget);
    expect(find.text('The dealer will contact you soon.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('buy_done')));
    await tester.pumpAndSettle();
    expect(find.text('Order request sent!'), findsNothing);
    expect(out, [true]);
  });

  testWidgets('cancel returns false', (tester) async {
    ignoreFontErrors();
    final out = await _open(tester, product: _product(), place: _ok);
    await tester.tap(find.byKey(const Key('buy_cancel')));
    await tester.pumpAndSettle();
    expect(out, [false]);
  });

  testWidgets('guest sees login message, no API call', (tester) async {
    ignoreFontErrors();
    AuthService.currentUser = null;
    var calls = 0;
    await _open(tester, product: _product(), place: ({
      required productId,
      required farmerId,
      required advertiserId,
    }) async {
      calls++;
      return const EnquiryResult.success();
    });
    await tester.tap(find.byKey(const Key('buy_primary')));
    await tester.pumpAndSettle();
    expect(find.text('Please log in to place an order'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    expect(calls, 0);
  });

  testWidgets('missing seller shows friendly error', (tester) async {
    ignoreFontErrors();
    await _open(tester, product: _product(advertiserId: 0), place: _ok);
    await tester.tap(find.byKey(const Key('buy_primary')));
    await tester.pumpAndSettle();
    expect(
        find.text("This product can't be ordered right now"), findsOneWidget);
  });

  testWidgets('network error then Try again succeeds', (tester) async {
    ignoreFontErrors();
    var n = 0;
    final out = await _open(tester, product: _product(), place: ({
      required productId,
      required farmerId,
      required advertiserId,
    }) async {
      n++;
      return n == 1
          ? const EnquiryResult.failed(EnquiryFailure.network)
          : const EnquiryResult.success();
    });
    await tester.tap(find.byKey(const Key('buy_primary')));
    await tester.pumpAndSettle();
    expect(
        find.text('No internet connection, please try again'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.byKey(const Key('buy_primary')));
    await tester.pumpAndSettle();
    expect(find.text('Order request sent!'), findsOneWidget);
    await tester.tap(find.byKey(const Key('buy_done')));
    await tester.pumpAndSettle();
    expect(out, [true]);
  });

  testWidgets('out of stock disables the button', (tester) async {
    ignoreFontErrors();
    var calls = 0;
    await _open(tester, product: _product(inStock: false), place: ({
      required productId,
      required farmerId,
      required advertiserId,
    }) async {
      calls++;
      return const EnquiryResult.success();
    });
    expect(find.text('Out of stock'), findsOneWidget);
    final btn =
        tester.widget<ElevatedButton>(find.byKey(const Key('buy_primary')));
    expect(btn.onPressed, isNull);
    await tester.tap(find.byKey(const Key('buy_primary')), warnIfMissed: false);
    await tester.pump();
    expect(calls, 0);
  });

  testWidgets('double tap places only one request', (tester) async {
    ignoreFontErrors();
    final c = Completer<EnquiryResult>();
    var calls = 0;
    await _open(tester, product: _product(), place: ({
      required productId,
      required farmerId,
      required advertiserId,
    }) {
      calls++;
      return c.future;
    });
    final finder = find.byKey(const Key('buy_primary'));
    await tester.tap(finder);
    await tester.tap(finder, warnIfMissed: false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(calls, 1);
    c.complete(const EnquiryResult.success());
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Order request sent!'), findsOneWidget);
  });

  group('ApiService.placeEnquiry', () {
    Future<EnquiryResult> run(http.Client c) => ApiService.placeEnquiry(
        productId: 1, farmerId: 'f', advertiserId: 2, client: c);

    test('success', () async {
      final r = await run(MockClient((_) async =>
          http.Response(jsonEncode({'success': true, 'id': 9}), 200)));
      expect(r.ok, isTrue);
      expect(r.id, 9);
    });
    test('non-200 is server failure', () async {
      final r = await run(MockClient((_) async => http.Response('x', 500)));
      expect(r.failure, EnquiryFailure.server);
    });
    test('bad JSON is server failure', () async {
      final r =
          await run(MockClient((_) async => http.Response('<html>', 200)));
      expect(r.ok, isFalse);
      expect(r.failure, EnquiryFailure.server);
    });
    test('success:false keeps server message', () async {
      final r = await run(MockClient((_) async =>
          http.Response(jsonEncode({'success': false, 'error': 'nope'}), 200)));
      expect(r.failure, EnquiryFailure.server);
      expect(r.message, 'nope');
    });
    test('client exception is network failure', () async {
      final r = await run(
          MockClient((_) async => throw http.ClientException('offline')));
      expect(r.failure, EnquiryFailure.network);
    });
    test('legacy createEnquiry still returns a map', () async {
      final m = await ApiService.createEnquiry(
        productId: 1,
        farmerId: 'f',
        advertiserId: 2,
        client: MockClient((_) async =>
            http.Response(jsonEncode({'success': true, 'id': 3}), 200)),
      );
      expect(m['success'], true);
      expect(m['id'], 3);
    });
  });
}
