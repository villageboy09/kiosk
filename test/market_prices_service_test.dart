import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cropsync/models/market_price.dart';
import 'package:cropsync/services/market_prices_service.dart';

Map<String, dynamic> rec(String c, dynamic modal,
        {String d = 'Guntur', String date = '2026-10-06'}) =>
    {
      'commodity': c,
      'variety': 'X',
      'market': '$d Market',
      'district': d,
      'state': 'Andhra Pradesh',
      'min_price': '1,000',
      'max_price': 2000,
      'modal_price': modal,
      'arrival_date': date,
    };

http.Response json(Object o, [int code = 200]) =>
    http.Response(jsonEncode(o), code,
        headers: {'content-type': 'application/json'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('MarketPrice parsing', () {
    test('strings, numbers, nulls, casing, commas', () {
      final p = MarketPrice.fromJson({
        'Commodity': 'Tomato',
        'Min_Price': '1,200',
        'Max_Price': 1800.5,
        'Modal_Price': null,
        'Arrival_Date': '05/10/2026',
        'District': 'Guntur',
      });
      expect(p.commodity, 'Tomato');
      expect(p.minPrice, 1200);
      expect(p.maxPrice, 1800.5);
      expect(p.modalPrice, isNull);
      expect(p.hasPrice, isFalse);
      expect(p.arrivalDate, DateTime(2026, 10, 5));
    });

    test('zero and N/A are null; spread', () {
      final p = MarketPrice.fromJson({
        'commodity': 'a',
        'min_price': 'N/A',
        'max_price': '0',
        'modal_price': '100'
      });
      expect(p.minPrice, isNull);
      expect(p.maxPrice, isNull);
      expect(p.spreadPct, isNull);
      final q = MarketPrice.fromJson({
        'commodity': 'a',
        'min_price': 80,
        'max_price': 120,
        'modal_price': 100
      });
      expect(q.spreadPct, 40);
    });

    test('formatRupees Indian grouping', () {
      expect(MarketPrice.formatRupees(850), '₹850');
      expect(MarketPrice.formatRupees(6850), '₹6,850');
      expect(MarketPrice.formatRupees(125000), '₹1,25,000');
      expect(MarketPrice.formatRupees(12345678), '₹1,23,45,678');
      expect(MarketPrice.formatRupees(125000, compact: true), '₹1.25L');
      expect(MarketPrice.formatRupees(20000000, compact: true), '₹2Cr');
      expect(MarketPrice.formatRupees(6850.4, compact: true), '₹6,850');
    });
  });

  group('grouping and categories', () {
    test('alias merging, no drops, best/lowest/user row', () {
      final rows = [
        const MarketPrice(
            commodity: 'Paddy(Common)', modalPrice: 2000, district: 'A'),
        const MarketPrice(
            commodity: 'Paddy(Dhan)(Common)',
            modalPrice: 2200,
            district: 'Chittor'),
        const MarketPrice(
            commodity: 'Paddy(Dhan)(Common)', modalPrice: 2100, district: 'B'),
        const MarketPrice(commodity: 'Red Gram (Arhar/Tur)', modalPrice: 7000),
        const MarketPrice(
            commodity: 'Arhar (Tur/Red Gram)(Whole)', modalPrice: 7200),
        const MarketPrice(commodity: 'Weird Thing', modalPrice: null),
      ];
      final g = groupByCommodity(rows, userDistrict: 'Chittoor');
      expect(g.length, 3);
      expect(g.fold<int>(0, (s, e) => s + e.count), rows.length);
      final paddy = g.firstWhere((e) => e.key == 'paddy');
      expect(paddy.name, 'Paddy(Dhan)(Common)');
      expect(paddy.best!.modalPrice, 2200);
      expect(paddy.lowest!.modalPrice, 2000);
      expect(paddy.averageModal, closeTo(2100, 0.001));
      expect(paddy.userDistrictRow!.district, 'Chittor');
      final tur = g.firstWhere((e) => e.key.contains('tur'));
      expect(tur.count, 2);
      final weird = g.firstWhere((e) => e.name == 'Weird Thing');
      expect(weird.best, isNull);
      expect(weird.hasPrice, isFalse);
    });

    test('marketCategoryOf', () {
      expect(marketCategoryOf('Turmeric'), 'spices');
      expect(marketCategoryOf('Red Gram (Arhar/Tur)'), 'pulses');
      expect(marketCategoryOf('Bengal Gram(Gram)(Whole)'), 'pulses');
      expect(marketCategoryOf('Green Gram (Moong)'), 'pulses');
      expect(marketCategoryOf('Black Gram (Urad)'), 'pulses');
      expect(marketCategoryOf('Paddy(Dhan)(Common)'), 'cereals');
      expect(marketCategoryOf('Maize'), 'cereals');
      expect(marketCategoryOf('Cotton'), 'cash_crops');
      expect(marketCategoryOf('Groundnut'), 'oilseeds');
      expect(marketCategoryOf('Soyabean'), 'oilseeds');
      expect(marketCategoryOf('Chilli Red'), 'spices');
      expect(marketCategoryOf('Green Chilli'), 'vegetables');
      expect(marketCategoryOf('Tomato'), 'vegetables');
      expect(marketCategoryOf('Banana'), 'fruits');
      expect(marketCategoryOf('Quantum Widget'), 'other');
    });

    test('changePct needs two real points', () {
      final c = groupByCommodity(
          [const MarketPrice(commodity: 'Tomato', modalPrice: 100)]).first;
      expect(c.changePct(const []), isNull);
      expect(c.changePct([const TrendPoint(avgPrice: 100)]), isNull);
      expect(
          c.changePct([
            TrendPoint(date: DateTime(2026, 1, 2), avgPrice: 110),
            TrendPoint(date: DateTime(2026, 1, 1), avgPrice: 100),
          ]),
          closeTo(10, 0.001));
    });
  });

  group('MarketPricesService', () {
    test('pages through all records', () async {
      final offsets = <String>[];
      final client = MockClient((req) async {
        final off = int.parse(req.url.queryParameters['offset']!);
        offsets.add('$off');
        final recs = [
          for (var i = 0; i < 2 && off + i < 5; i++) rec('C${off + i}', '100')
        ];
        return json({
          'success': true,
          'state': 'Andhra Pradesh',
          'as_of': '2026-10-06',
          'matched_level': 'district',
          'resolved': {'state': 'Andhra Pradesh', 'district': 'Guntur'},
          'total': 5,
          'records': recs,
          if (off == 0)
            'commodities': [
              {'commodity': 'C0', 'count': 1, 'min_modal': '1', 'max_modal': 2}
            ],
          if (off == 0)
            'districts': [
              {'district': 'Guntur', 'count': 5}
            ],
        });
      });
      final s = MarketPricesService(client: client);
      final r = await s.fetchPrices(
          state: 'Andhra Pradesh', district: 'Guntur', limit: 2);
      expect(r.records.length, 5);
      expect(offsets, ['0', '2', '4']);
      expect(r.error, isNull);
      expect(r.matchedLevel, MatchedLevel.district);
      expect(r.resolvedDistrict, 'Guntur');
      expect(r.asOf, DateTime(2026, 10, 6));
      expect(r.commodities.single.maxModal, 2);
      expect(r.districts.single.count, 5);
    });

    test('error mapping', () async {
      Future<MarketFetchError?> run(http.Response Function() f) async {
        final s = MarketPricesService(client: MockClient((_) async => f()));
        return (await s.fetchPrices(state: 'X')).error;
      }

      expect(
          await run(
              () => json({'success': false, 'error': 'upstream_unavailable'})),
          MarketFetchError.upstreamUnavailable);
      expect(
          await run(() => json({'success': false, 'error': 'missing_api_key'})),
          MarketFetchError.missingApiKey);
      expect(await run(() => json({'success': false, 'error': 'boom'})),
          MarketFetchError.server);
      expect(
          await run(() => json({
                'success': true,
                'total': 0,
                'records': [],
                'error_hint': 'no_data_for_state'
              })),
          MarketFetchError.noData);
      expect(
          await run(() => http.Response('oops', 500)), MarketFetchError.server);
      expect(await run(() => http.Response('<html>', 200)),
          MarketFetchError.parse);

      final net = MarketPricesService(
          client: MockClient((_) async => throw http.ClientException('x')));
      expect(
          (await net.fetchPrices(state: 'X')).error, MarketFetchError.network);
      final to = MarketPricesService(
          client: MockClient((_) async => throw TimeoutException('t')));
      expect(
          (await to.fetchPrices(state: 'X')).error, MarketFetchError.timeout);
      final r = await to.fetchPrices(state: 'X');
      expect(r.records, isEmpty);
    });

    test('cache: TTL, stale-on-error, never caches errors', () async {
      var now = DateTime(2026, 10, 7, 8);
      var calls = 0;
      var fail = false;
      final client = MockClient((_) async {
        calls++;
        if (fail) throw http.ClientException('offline');
        return json({
          'success': true,
          'as_of': '2026-10-06',
          'total': 1,
          'matched_level': 'state',
          'resolved': {'state': 'Telangana'},
          'records': [rec('Tomato', '1500')],
        });
      });
      final s = MarketPricesService(client: client, now: () => now);

      final a = await s.fetchPrices(
          state: 'Orissa'.replaceAll('Orissa', 'Telangana'),
          district: 'Hyderabad');
      expect(a.fromCache, isFalse);
      expect(calls, 1);

      now = now.add(const Duration(hours: 1));
      final b = await s.fetchPrices(state: 'telangana', district: 'Hyderabad');
      expect(b.fromCache, isTrue);
      expect(b.stale, isFalse);
      expect(calls, 1);

      now = now.add(const Duration(hours: 6));
      fail = true;
      final c = await s.fetchPrices(state: 'Telangana', district: 'Hyderabad');
      expect(calls, 2);
      expect(c.fromCache, isTrue);
      expect(c.stale, isTrue);
      expect(c.error, MarketFetchError.network);
      expect(c.records.length, 1);
      expect(c.asOf, DateTime(2026, 10, 6));

      // different location has no cache -> plain error, nothing fabricated
      final d = await s.fetchPrices(state: 'Kerala');
      expect(d.records, isEmpty);
      expect(d.error, MarketFetchError.network);

      fail = false;
      now = now.add(const Duration(hours: 7));
      final e = await s.fetchPrices(state: 'Telangana', district: 'Hyderabad');
      expect(e.fromCache, isFalse);
      await s.pendingWrites;
      final prefs = await SharedPreferences.getInstance();
      expect(
          prefs
              .getKeys()
              .where((k) => k.startsWith(MarketPricesService.cachePrefix))
              .length,
          1);
    });

    test('empty results are not cached', () async {
      final s = MarketPricesService(
          client: MockClient(
              (_) async => json({'success': true, 'total': 0, 'records': []})));
      final r = await s.fetchPrices(state: 'Goa');
      expect(r.error, MarketFetchError.noData);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });

    test('fetchLocations and fetchTrends', () async {
      final client = MockClient((req) async {
        if (req.url.queryParameters['action'] == 'get_market_locations') {
          return json({
            'success': true,
            'states': [
              {
                'state': 'Orissa',
                'districts': ['Puri'],
                'latest_date': '2026-10-06',
                'commodity_count': 4
              }
            ]
          });
        }
        if (req.url.queryParameters['commodity'] == 'thin') {
          return json(
              {'success': true, 'insufficient_data': true, 'trends': []});
        }
        return json({
          'success': true,
          'trends': [
            {'arrival_date': '2026-10-02', 'avg_price': '120'},
            {'arrival_date': '2026-10-01', 'avg_price': 100},
          ]
        });
      });
      final s = MarketPricesService(client: client);
      final l = await s.fetchLocations();
      expect(l.states.single.state, 'Odisha');
      expect(l.states.single.districts, ['Puri']);
      final t = await s.fetchTrends(state: 'Telangana', commodity: 'Tomato');
      expect(t.length, 2);
      expect(t.first.avgPrice, 100);
      expect(
          await s.fetchTrends(state: 'Telangana', commodity: 'thin'), isEmpty);
    });
  });
}
