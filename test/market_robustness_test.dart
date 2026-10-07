import 'dart:convert';

import 'package:cropsync/models/market_price.dart';
import 'package:cropsync/services/market_prices_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

MarketPrice _p(String c, String market, String district, double? modal,
        {String date = '2026-10-06', String variety = ''}) =>
    MarketPrice(
      commodity: c,
      market: market,
      district: district,
      variety: variety,
      state: 'Andhra Pradesh',
      modalPrice: modal,
      arrivalDate: parseMarketDate(date),
    );

Map<String, dynamic> _rec(String c, int i, {String date = '2026-10-06'}) => {
      'commodity': c,
      'variety': 'v',
      'market': 'M$i',
      'district': 'D$i',
      'state': 'Andhra Pradesh',
      'min_price': 100,
      'max_price': 300,
      'modal_price': 200 + i,
      'arrival_date': date,
    };

http.Response _json(Object o) => http.Response(jsonEncode(o), 200,
    headers: {'content-type': 'application/json'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('marketCategoryOf', () {
    test('pulses win over the word beans', () {
      expect(marketCategoryOf('Black Gram (Urd Beans)(Whole)'), 'pulses');
      expect(marketCategoryOf('Green Gram (Moong)(Whole)'), 'pulses');
      expect(marketCategoryOf('Horse Gram (Kulthi)'), 'pulses');
      expect(marketCategoryOf('Arhar (Tur/Red Gram)(Whole)'), 'pulses');
      expect(marketCategoryOf('Masoor Dal'), 'pulses');
      expect(marketCategoryOf('Lentil (Masur)(Whole)'), 'pulses');
      expect(marketCategoryOf('Cowpea (Lobia/Karamani)'), 'pulses');
    });

    test('fresh beans stay vegetables', () {
      expect(marketCategoryOf('French Beans (Frasbean)'), 'vegetables');
      expect(marketCategoryOf('Cluster Beans'), 'vegetables');
      expect(marketCategoryOf('Broad Beans'), 'vegetables');
      expect(marketCategoryOf('Beans'), 'vegetables');
      expect(marketCategoryOf('Turmeric'), 'spices');
    });
  });

  group('newest-date statistics', () {
    test('best / lowest / average ignore rows older than the newest date', () {
      final c = groupByCommodity([
        _p('Cotton', 'A', 'Guntur', 7000),
        _p('Cotton', 'B', 'Krishna', 7200),
        _p('Cotton', 'C', 'Kurnool', 9999, date: '2026-10-04'),
        _p('Cotton', 'D', 'Nellore', 100, date: '2026-10-03'),
      ]).single;
      expect(c.best!.modalPrice, 7200);
      expect(c.lowest!.modalPrice, 7000);
      expect(c.averageModal, 7100);
      // Older rows are still available for the detail table.
      expect(c.rows.length, 4);
    });

    test('unpriced newest rows do not hide older prices', () {
      final c = groupByCommodity([
        _p('Cotton', 'A', 'Guntur', null),
        _p('Cotton', 'C', 'Kurnool', 6900, date: '2026-10-04'),
      ]).single;
      expect(c.best!.modalPrice, 6900);
    });

    test('newestPricedRows without dates keeps every priced row', () {
      final rows = newestPricedRows([
        const MarketPrice(commodity: 'x', modalPrice: 1),
        const MarketPrice(commodity: 'x', modalPrice: 2),
        const MarketPrice(commodity: 'x'),
      ]);
      expect(rows.length, 2);
    });
  });

  group('cache keys', () {
    test('never empty and never shared by different unknown states', () {
      final a = MarketPricesService.stateCacheKey('ఒకటి');
      final b = MarketPricesService.stateCacheKey('రెండు');
      expect(a, isNotEmpty);
      expect(b, isNotEmpty);
      expect(a, isNot(b));
      expect(MarketPricesService.stateCacheKey(''), 'none');
      expect(MarketPricesService.stateCacheKey('తెలంగాణ'), 'telangana');
      expect(MarketPricesService.stateCacheKey('Telangana'), 'telangana');
    });

    test('two different Telugu states keep separate cache entries', () async {
      final seen = <String>[];
      final client = MockClient((req) async {
        seen.add(req.url.queryParameters['state']!);
        final st = req.url.queryParameters['state']!;
        return _json({
          'success': true,
          'total': 1,
          'as_of': '2026-10-06',
          'matched_level': 'state',
          'records': [
            {..._rec(st == 'ఒకటి' ? 'Alpha' : 'Beta', 1), 'state': st},
          ],
        });
      });
      final s = MarketPricesService(client: client);
      final a = await s.fetchPrices(state: 'ఒకటి');
      final b = await s.fetchPrices(state: 'రెండు');
      await s.pendingWrites;
      expect(a.records.single.commodity, 'Alpha');
      expect(b.records.single.commodity, 'Beta');
      expect(seen.length, 2);
      // Second visit is served from each state's own cache.
      final a2 = await s.fetchPrices(state: 'ఒకటి');
      final b2 = await s.fetchPrices(state: 'రెండు');
      expect(a2.fromCache && b2.fromCache, isTrue);
      expect(a2.records.single.commodity, 'Alpha');
      expect(b2.records.single.commodity, 'Beta');
      expect(seen.length, 2);
    });

    test('days are part of the key', () async {
      var calls = 0;
      final s = MarketPricesService(client: MockClient((_) async {
        calls++;
        return _json({
          'success': true,
          'total': 1,
          'records': [_rec('Tomato', 1)],
        });
      }));
      await s.fetchPrices(state: 'Goa', days: 1);
      await s.fetchPrices(state: 'Goa', days: 3);
      await s.pendingWrites;
      expect(calls, 2);
      final again = await s.fetchPrices(state: 'Goa', days: 1);
      expect(again.fromCache, isTrue);
      expect(calls, 2);
    });
  });

  group('paging and partial results', () {
    test('uses 1000 per page and flags partial after the page cap', () async {
      final limits = <String>[];
      final client = MockClient((req) async {
        limits.add(req.url.queryParameters['limit']!);
        final off = int.parse(req.url.queryParameters['offset']!);
        return _json({
          'success': true,
          'total': 100000,
          'records': [_rec('C$off', off)],
        });
      });
      final s = MarketPricesService(client: client);
      final r = await s.fetchPrices(state: 'Goa', days: 1);
      expect(limits.first, '1000');
      expect(limits.length, MarketPricesService.maxPages);
      expect(MarketPricesService.maxPages, 12);
      expect(r.partial, isTrue);
      expect(r.records, isNotEmpty);
    });

    test('partial results are cached but only for 30 minutes', () async {
      var now = DateTime(2026, 10, 7, 8);
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        final off = int.parse(req.url.queryParameters['offset']!);
        return _json({
          'success': true,
          'total': 100000,
          'records': [_rec('C$off', off)],
        });
      });
      final s = MarketPricesService(client: client, now: () => now);
      final first = await s.fetchPrices(state: 'Goa', days: 1);
      expect(first.partial, isTrue);
      final afterFirst = calls;
      await s.pendingWrites;

      now = now.add(const Duration(minutes: 10));
      final hit = await s.fetchPrices(state: 'Goa', days: 1);
      expect(hit.fromCache, isTrue);
      expect(hit.partial, isTrue);
      expect(calls, afterFirst);

      now = now.add(const Duration(minutes: 30));
      final miss = await s.fetchPrices(state: 'Goa', days: 1);
      expect(miss.fromCache, isFalse);
      expect(calls, greaterThan(afterFirst));
    });

    test('the cache write does not block the result', () async {
      final s = MarketPricesService(
          client: MockClient((_) async => _json({
                'success': true,
                'total': 1,
                'records': [_rec('Tomato', 1)],
              })));
      final r = await s.fetchPrices(state: 'Goa');
      expect(r.records.length, 1);
      await s.pendingWrites;
      final prefs = await SharedPreferences.getInstance();
      expect(
          prefs
              .getKeys()
              .where((k) => k.startsWith(MarketPricesService.cachePrefix)),
          hasLength(1));
    });
  });

  group('cache trimming', () {
    test('keeps at most 2000 rows with the newest rows of each commodity', () {
      final rows = <MarketPrice>[
        for (var c = 0; c < 150; c++)
          for (var d = 0; d < 30; d++)
            _p('Crop$c', 'M$d', 'D$d', 100.0 + d,
                date: '2026-09-${(d + 1).toString().padLeft(2, '0')}'),
      ];
      final trimmed = MarketPricesService.trimForCache(
          MarketPricesResult(records: rows, total: rows.length));
      expect(trimmed.records.length, lessThanOrEqualTo(2000));
      expect(trimmed.partial, isTrue);
      // Every commodity survives, with its newest rows first.
      final keys = {for (final r in trimmed.records) r.commodity};
      expect(keys.length, 150);
      final c0 = trimmed.records.where((r) => r.commodity == 'Crop0').toList();
      expect(c0.first.arrivalDate, DateTime(2026, 9, 30));
      expect(c0.length, lessThanOrEqualTo(20));
    });

    test('small results are untouched', () {
      final r = MarketPricesResult(records: [_p('A', 'm', 'd', 1)], total: 1);
      expect(identical(MarketPricesService.trimForCache(r), r), isTrue);
    });
  });
}
