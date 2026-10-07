import 'package:cropsync/models/seed_variety.dart';
import 'package:cropsync/utils/seed_logic.dart';
import 'package:flutter_test/flutter_test.dart';

SeedVariety v(
  int id,
  String crop,
  String name, {
  String? price,
  String? unit,
  double? yieldQ,
  int? days,
  String? region,
  String? nameHi,
  String? nameTe,
  DateTime? created,
}) =>
    SeedVariety(
      id: id,
      cropName: crop,
      varietyName: name,
      price: price,
      priceUnit: unit,
      averageYield: yieldQ,
      growthDuration: days,
      region: region,
      varietyNameHi: nameHi,
      varietyNameTe: nameTe,
      createdAt: created,
    );

void main() {
  group('SeedVariety', () {
    test('fromJson tolerant parsing', () {
      final s = SeedVariety.fromJson({
        'id': '7',
        'crop_name': 'Rice',
        'variety_name': 'Sona',
        'variety_name_en': 'Sona En',
        'price': '145.50',
        'price_unit': 'per_kg',
        'average_yield': '22',
        'growth_duration': '120',
        'created_at': '2026-01-02T00:00:00Z',
      });
      expect(s.id, 7);
      expect(s.varietyNameSecondary, 'Sona En');
      expect(s.priceValue, 145.5);
      expect(s.isBookable, isTrue);
      expect(s.averageYield, 22);
      expect(s.growthDuration, 120);
      expect(s.createdAt, isNotNull);
      final e = SeedVariety.fromJson({});
      expect(e.id, 0);
      expect(e.cropName, '');
      expect(e.priceValue, isNull);
      expect(e.isBookable, isFalse);
      expect(e.createdAt, isNull);
    });
    test('isBookable / hasVideo / primaryImage', () {
      expect(v(1, 'a', 'b', price: '0').isBookable, isFalse);
      expect(v(1, 'a', 'b', price: 'abc').isBookable, isFalse);
      expect(v(1, 'a', 'b', price: '-5').isBookable, isFalse);
      expect(v(1, 'a', 'b', price: ' 10 ').isBookable, isTrue);
      final s = SeedVariety(
          id: 1,
          cropName: 'a',
          varietyName: 'b',
          imageUrl: ' http://x/i.png ',
          testimonialVideoUrl: ' ');
      expect(s.primaryImage, 'http://x/i.png');
      expect(s.hasVideo, isFalse);
      expect(v(1, 'a', 'b').primaryImage, '');
    });
    test('displayName picks best localised name', () {
      final s = v(1, 'Rice', 'Server', nameHi: 'सोना', nameTe: 'సోనా');
      expect(s.displayName('hi'), 'सोना');
      expect(s.displayName('te'), 'సోనా');
      expect(s.displayName('en'), 'Server');
      expect(s.displayName('xx'), 'Server');
      final t = SeedVariety(
          id: 1, cropName: 'c', varietyName: ' ', varietyNameHi: 'हि');
      expect(t.displayName('en'), 'हि');
    });
    test('dedupe drops unparseable (id 0) rows instead of merging them', () {
      final out = dedupeSeedVarieties([
        v(0, 'a', 'x'),
        v(0, 'b', 'y'),
        v(3, 'c', 'z'),
      ]);
      expect(out.map((e) => e.id), [3]);
    });
    test('dedupe keeps first priced, preserves order', () {
      final out = dedupeSeedVarieties([
        v(1, 'Rice', 'A'),
        v(2, 'Rice', 'B', price: '10'),
        v(1, 'Rice', 'A', price: '50'),
        v(2, 'Rice', 'B', price: '99'),
        v(3, 'Rice', 'C'),
        v(3, 'Rice', 'C'),
      ]);
      expect(out.map((e) => e.id), [1, 2, 3]);
      expect(out[0].price, '50');
      expect(out[1].price, '10');
    });
  });

  group('applySeedFilters', () {
    final items = [
      v(1, 'Rice', 'Sona',
          price: '100', yieldQ: 25, days: 120, region: 'Telangana'),
      v(2, 'Cotton', 'Bunny',
          price: '450', yieldQ: 10, days: 160, nameHi: 'बनी'),
      v(3, 'Rice', 'Fast', yieldQ: 30, days: 100),
      v(4, 'Maize', 'Corn',
          price: '60', yieldQ: 20, days: 110, nameTe: 'మొక్కజొన్న'),
    ];
    List<int> ids(List<SeedVariety> l) => l.map((e) => e.id).toList();
    const none = SeedFilters();

    test('default keeps input order', () {
      expect(
          ids(applySeedFilters(items, filters: none, query: '')), [1, 2, 3, 4]);
    });
    test('crop filter case-insensitive; all ignored', () {
      expect(
          ids(applySeedFilters(items, filters: none, query: '', crop: 'rice')),
          [1, 3]);
      expect(
          ids(applySeedFilters(items, filters: none, query: '', crop: 'all')),
          [1, 2, 3, 4]);
      expect(ids(applySeedFilters(items, filters: none, query: '', crop: '')),
          [1, 2, 3, 4]);
    });
    test('bookable/highYield/shortDuration thresholds inclusive', () {
      expect(
          ids(applySeedFilters(items,
              filters: const SeedFilters(bookableOnly: true), query: '')),
          [1, 2, 4]);
      expect(
          ids(applySeedFilters(items,
              filters: const SeedFilters(highYield: true), query: '')),
          [1, 3, 4]);
      expect(
          ids(applySeedFilters(items,
              filters: const SeedFilters(shortDuration: true), query: '')),
          [3, 4]);
    });
    test('search trims, lowercases, multilingual, crop, region', () {
      expect(
          ids(applySeedFilters(items, filters: none, query: '  SONA ')), [1]);
      expect(ids(applySeedFilters(items, filters: none, query: 'बनी')), [2]);
      expect(ids(applySeedFilters(items, filters: none, query: 'మొక్కజొన్న')),
          [4]);
      expect(ids(applySeedFilters(items, filters: none, query: 'cotton')), [2]);
      expect(
          ids(applySeedFilters(items, filters: none, query: 'telangana')), [1]);
      expect(applySeedFilters(items, filters: none, query: 'zzz'), isEmpty);
    });
    test('search matches translated crop names', () {
      final tr = [v(9, 'Rice', 'X')];
      final hiRice = tr.first.cropName; // sanity
      expect(hiRice, 'Rice');
      expect(applySeedFilters(tr, filters: none, query: 'चावल').length, 1);
    });
    test('wishlist only', () {
      expect(
          ids(applySeedFilters(items,
              filters: none, query: '', wishlistOnly: true, wishlist: {2, 4})),
          [2, 4]);
      expect(
          applySeedFilters(items, filters: none, query: '', wishlistOnly: true),
          isEmpty);
    });
    test('sorts', () {
      expect(
          ids(applySeedFilters(items,
              filters: const SeedFilters(sort: SeedSort.yieldHigh), query: '')),
          [3, 1, 4, 2]);
      expect(
          ids(applySeedFilters(items,
              filters: const SeedFilters(sort: SeedSort.durationShort),
              query: '')),
          [3, 4, 1, 2]);
      // price low: unpriced (3) last
      expect(
          ids(applySeedFilters(items,
              filters: const SeedFilters(sort: SeedSort.priceLow), query: '')),
          [4, 1, 2, 3]);
      // newest without created_at: id desc
      expect(
          ids(applySeedFilters(items,
              filters: const SeedFilters(sort: SeedSort.newest), query: '')),
          [4, 3, 2, 1]);
    });
    test('sort is stable on ties', () {
      final t = [
        v(1, 'a', 'a', yieldQ: 5),
        v(2, 'a', 'b', yieldQ: 5),
        v(3, 'a', 'c', yieldQ: 9)
      ];
      expect(
          ids(applySeedFilters(t,
              filters: const SeedFilters(sort: SeedSort.yieldHigh), query: '')),
          [3, 1, 2]);
    });
    test('does not mutate input', () {
      final copy = List.of(items);
      applySeedFilters(items,
          filters: const SeedFilters(sort: SeedSort.priceLow), query: '');
      expect(ids(items), ids(copy));
    });
  });

  group('SeedFilters', () {
    test('isActive / copyWith / reset', () {
      expect(const SeedFilters().isActive, isFalse);
      final f = const SeedFilters().copyWith(highYield: true);
      expect(f.isActive, isTrue);
      expect(
          const SeedFilters().copyWith(sort: SeedSort.newest).isActive, isTrue);
      expect(f.reset(), const SeedFilters());
      expect(f.copyWith(bookableOnly: true).highYield, isTrue);
    });
  });

  group('rails helpers', () {
    test('cropsByCount orders by count desc then name', () {
      final l = [
        v(1, 'Rice', 'a'),
        v(2, 'Cotton', 'b'),
        v(3, 'Rice', 'c'),
        v(4, 'Bajra', 'd')
      ];
      expect(cropsByCount(l), ['Rice', 'Bajra', 'Cotton']);
    });
    test('newestFirst uses created_at then id', () {
      final l = [
        v(1, 'a', 'a', created: DateTime(2026, 1, 1)),
        v(2, 'a', 'b', created: DateTime(2026, 3, 1)),
        v(9, 'a', 'c'),
      ];
      expect(newestFirst(l).map((e) => e.id), [2, 1, 9]);
      final m = [v(1, 'a', 'a'), v(5, 'a', 'b'), v(3, 'a', 'c')];
      expect(newestFirst(m).map((e) => e.id), [5, 3, 1]);
    });
  });

  group('price helpers', () {
    test('localizedPriceUnit', () {
      expect(localizedPriceUnit('per_kg', 'en'), 'per kg');
      expect(localizedPriceUnit('per_kg', 'hi'), 'प्रति किलो');
      expect(localizedPriceUnit('per_kg', 'te'), 'కిలోకు');
      expect(localizedPriceUnit('per_450g_packet', 'en'), '450 g packet');
      expect(localizedPriceUnit('per_450g_packet', 'hi'), '450 g पैकेट');
      expect(localizedPriceUnit('per_packet', 'en'), 'per packet');
      expect(localizedPriceUnit('per_quintal', 'hi'), 'प्रति क्विंटल');
      expect(localizedPriceUnit('per_weird_thing', 'en'), 'per weird thing');
      expect(localizedPriceUnit('bundle_x', 'en'), 'bundle x');
      expect(localizedPriceUnit(null, 'en'), '');
      expect(localizedPriceUnit('  ', 'te'), '');
    });
    test('seedPriceLabel', () {
      expect(seedPriceLabel(v(1, 'a', 'b', price: '145', unit: 'per_kg'), 'en'),
          '₹145 / kg');
      expect(
          seedPriceLabel(v(1, 'a', 'b', price: '145.5', unit: 'per_kg'), 'en'),
          '₹145.50 / kg');
      expect(
          seedPriceLabel(
              v(1, 'a', 'b', price: '60', unit: 'per_450g_packet'), 'en'),
          '₹60 / 450 g packet');
      expect(seedPriceLabel(v(1, 'a', 'b', price: '145', unit: 'per_kg'), 'hi'),
          '₹145 / किलो');
      expect(seedPriceLabel(v(1, 'a', 'b', price: '145', unit: 'per_kg'), 'te'),
          '₹145 / కిలోకు');
      expect(seedPriceLabel(v(1, 'a', 'b', price: '145'), 'en'), '₹145');
      expect(seedPriceLabel(v(1, 'a', 'b'), 'en'), '');
      expect(seedPriceLabel(v(1, 'a', 'b', price: '0'), 'en'), '');
    });
  });

  group('booking', () {
    test('generateSeedBookingId format', () {
      final id =
          generateSeedBookingId(DateTime.fromMillisecondsSinceEpoch(12345));
      expect(RegExp(r'^SB12345\d{3}$').hasMatch(id), isTrue);
      final now = generateSeedBookingId();
      expect(RegExp(r'^SB\d{16}$').hasMatch(now), isTrue);
      // fits bookings.booking_id varchar(20)
      expect(now.length, lessThanOrEqualTo(20));
    });
    test('generateSeedBookingId differs within the same millisecond', () {
      final t = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final ids = {for (var i = 0; i < 50; i++) generateSeedBookingId(t)};
      expect(ids.length, greaterThan(1));
    });
    test('seedBookingTotal', () {
      expect(seedBookingTotal(145.5, 2), 291);
      expect(seedBookingTotal(10.333, 3), 31);
      expect(seedBookingTotal(0, 5), 0);
      expect(seedBookingTotal(null, 5), 0);
      expect(seedBookingTotal(10, -1), 0);
      expect(seedBookingTotal(99.99, 0.5), 50);
    });
  });
}
