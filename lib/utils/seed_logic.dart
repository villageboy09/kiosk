import 'dart:math' as math;

import 'package:cropsync/models/product.dart' show formatShopPrice;
import 'package:cropsync/models/seed_variety.dart';
import 'package:cropsync/utils/commodity_translator.dart';

enum SeedSort { defaultOrder, newest, yieldHigh, durationShort, priceLow }

/// Minimum average yield (quintals/acre) counted as "high yield".
const double kHighYieldThreshold = 20;

/// Maximum growth duration (days) counted as "short duration".
const int kShortDurationDays = 110;

class SeedFilters {
  final SeedSort sort;
  final bool bookableOnly;
  final bool highYield;
  final bool shortDuration;

  const SeedFilters({
    this.sort = SeedSort.defaultOrder,
    this.bookableOnly = false,
    this.highYield = false,
    this.shortDuration = false,
  });

  bool get isActive =>
      sort != SeedSort.defaultOrder ||
      bookableOnly ||
      highYield ||
      shortDuration;

  SeedFilters copyWith({
    SeedSort? sort,
    bool? bookableOnly,
    bool? highYield,
    bool? shortDuration,
  }) =>
      SeedFilters(
        sort: sort ?? this.sort,
        bookableOnly: bookableOnly ?? this.bookableOnly,
        highYield: highYield ?? this.highYield,
        shortDuration: shortDuration ?? this.shortDuration,
      );

  SeedFilters reset() => const SeedFilters();

  @override
  bool operator ==(Object other) =>
      other is SeedFilters &&
      other.sort == sort &&
      other.bookableOnly == bookableOnly &&
      other.highYield == highYield &&
      other.shortDuration == shortDuration;

  @override
  int get hashCode => Object.hash(sort, bookableOnly, highYield, shortDuration);
}

bool _matchesQuery(SeedVariety v, String q) {
  if (v.searchHaystack.contains(q)) return true;
  for (final lang in const ['en', 'te', 'hi']) {
    final c = CommodityTranslator.getLocalizedName(v.cropName, lang);
    if (c.toLowerCase().contains(q)) return true;
  }
  return false;
}

/// Filters, searches and sorts [items]. Sorting is stable (ties keep the input
/// order); items lacking the sort metric go last.
/// [crop] null/''/'all' means all crops; compared case-insensitively on the raw
/// crop name.
List<SeedVariety> applySeedFilters(
  List<SeedVariety> items, {
  required SeedFilters filters,
  required String query,
  String? crop,
  bool wishlistOnly = false,
  Set<int>? wishlist,
}) {
  final q = query.trim().toLowerCase();
  final c = (crop ?? '').trim().toLowerCase();
  final wl = wishlist ?? const <int>{};

  final indexed = <MapEntry<int, SeedVariety>>[];
  for (var i = 0; i < items.length; i++) {
    final v = items[i];
    if (c.isNotEmpty && c != 'all' && v.cropName.trim().toLowerCase() != c) {
      continue;
    }
    if (wishlistOnly && !wl.contains(v.id)) continue;
    if (filters.bookableOnly && !v.isBookable) continue;
    if (filters.highYield && (v.averageYield ?? 0) < kHighYieldThreshold) {
      continue;
    }
    if (filters.shortDuration) {
      final d = v.growthDuration;
      if (d == null || d <= 0 || d > kShortDurationDays) continue;
    }
    if (q.isNotEmpty && !_matchesQuery(v, q)) continue;
    indexed.add(MapEntry(i, v));
  }

  int cmpNullsLast<T extends Comparable>(T? a, T? b, {bool desc = false}) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return desc ? b.compareTo(a) : a.compareTo(b);
  }

  int Function(SeedVariety, SeedVariety)? cmp;
  switch (filters.sort) {
    case SeedSort.defaultOrder:
      cmp = null;
    case SeedSort.newest:
      cmp = _newestCompare;
    case SeedSort.yieldHigh:
      cmp = (a, b) => cmpNullsLast(a.averageYield, b.averageYield, desc: true);
    case SeedSort.durationShort:
      cmp = (a, b) => cmpNullsLast(
          (a.growthDuration ?? 0) > 0 ? a.growthDuration : null,
          (b.growthDuration ?? 0) > 0 ? b.growthDuration : null);
    case SeedSort.priceLow:
      cmp = (a, b) => cmpNullsLast(a.isBookable ? a.priceValue : null,
          b.isBookable ? b.priceValue : null);
  }
  if (cmp != null) {
    final f = cmp;
    indexed.sort((a, b) {
      final r = f(a.value, b.value);
      return r != 0 ? r : a.key.compareTo(b.key);
    });
  }
  return indexed.map((e) => e.value).toList();
}

int _newestCompare(SeedVariety a, SeedVariety b) {
  final ad = a.createdAt, bd = b.createdAt;
  if (ad != null && bd != null) {
    final r = bd.compareTo(ad);
    if (r != 0) return r;
  } else if (ad != null) {
    return -1;
  } else if (bd != null) {
    return 1;
  }
  return b.id.compareTo(a.id);
}

/// Distinct raw crop names ordered by variety count desc, then name (A-Z).
List<String> cropsByCount(List<SeedVariety> items) {
  final counts = <String, int>{};
  for (final v in items) {
    final n = v.cropName.trim();
    if (n.isEmpty) continue;
    counts[n] = (counts[n] ?? 0) + 1;
  }
  final names = counts.keys.toList()
    ..sort((a, b) {
      final r = counts[b]!.compareTo(counts[a]!);
      return r != 0 ? r : a.toLowerCase().compareTo(b.toLowerCase());
    });
  return names;
}

/// created_at desc when available, else id desc. Returns a new list.
List<SeedVariety> newestFirst(List<SeedVariety> items) {
  final indexed = items.asMap().entries.toList()
    ..sort((a, b) {
      final r = _newestCompare(a.value, b.value);
      return r != 0 ? r : a.key.compareTo(b.key);
    });
  return indexed.map((e) => e.value).toList();
}

/// Natural-language price unit, e.g. 'per_kg' -> 'per kg' / 'प्रति किलो' /
/// 'కిలోకు'; 'per_450g_packet' -> '450 g packet'. Unknown strings are
/// humanised (underscores to spaces, 'per_' stripped).
String localizedPriceUnit(String? rawUnit, String lang) {
  final raw = (rawUnit ?? '').trim();
  if (raw.isEmpty) return '';
  final key = raw.toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');

  const simple = {
    'per_kg': {'en': 'per kg', 'hi': 'प्रति किलो', 'te': 'కిలోకు'},
    'kg': {'en': 'per kg', 'hi': 'प्रति किलो', 'te': 'కిలోకు'},
    'per_packet': {
      'en': 'per packet',
      'hi': 'प्रति पैकेट',
      'te': 'ప్యాకెట్‌కు'
    },
    'packet': {'en': 'per packet', 'hi': 'प्रति पैकेट', 'te': 'ప్యాకెట్‌కు'},
    'per_quintal': {
      'en': 'per quintal',
      'hi': 'प्रति क्विंटल',
      'te': 'క్వింటాలుకు'
    },
    'quintal': {
      'en': 'per quintal',
      'hi': 'प्रति क्विंटल',
      'te': 'క్వింటాలుకు'
    },
    'per_bag': {'en': 'per bag', 'hi': 'प्रति बैग', 'te': 'సంచికి'},
  };
  final hit = simple[key];
  if (hit != null) return hit[lang] ?? hit['en']!;

  final m = RegExp(
          r'^(?:per_)?(\d+(?:\.\d+)?)_?(kg|g|gm|gms|gram|grams|ml|l)(?:_(packet|pack|bag|pouch))?$')
      .firstMatch(key);
  if (m != null) {
    final qty = m.group(1)!;
    var unit = m.group(2)!;
    if (unit.startsWith('gm') || unit.startsWith('gram')) unit = 'g';
    final kind = m.group(3);
    final word = {
      'en': {
        'packet': 'packet',
        'pack': 'pack',
        'bag': 'bag',
        'pouch': 'pouch'
      },
      'hi': {'packet': 'पैकेट', 'pack': 'पैक', 'bag': 'बैग', 'pouch': 'पाउच'},
      'te': {
        'packet': 'ప్యాకెట్',
        'pack': 'ప్యాక్',
        'bag': 'సంచి',
        'pouch': 'పౌచ్'
      },
    };
    final k = kind == null ? '' : ' ${word[lang]?[kind] ?? word['en']![kind]!}';
    return '$qty $unit$k';
  }

  final human =
      key.replaceFirst(RegExp(r'^per_'), '').replaceAll('_', ' ').trim();
  if (human.isEmpty) return '';
  return raw.toLowerCase().startsWith('per') ? 'per $human' : human;
}

/// e.g. '₹145 / kg'. Packet-style units render as '₹60 / 450 g packet'.
/// Returns '' when the variety has no positive price.
String seedPriceLabel(SeedVariety v, String lang) {
  if (!v.isBookable) return '';
  final base = formatShopPrice(v.priceValue);
  final unit = localizedPriceUnit(v.priceUnit, lang);
  if (unit.isEmpty) return base;
  final short = unit
      .replaceFirst(RegExp(r'^per '), '')
      .replaceFirst(RegExp(r'^प्रति '), '');
  // Telugu uses a suffix form ("కిలోకు"); keep it as is.
  return '$base / ${lang == 'en' || lang == 'hi' ? short : unit}';
}

final math.Random _bookingRandom = math.Random();

/// Booking id: 'SB<millis since epoch><3 random digits>' (18 chars, within
/// the `bookings.booking_id` varchar(20) column).
String generateSeedBookingId([DateTime? now, math.Random? random]) {
  final suffix = (random ?? _bookingRandom).nextInt(1000);
  return 'SB${(now ?? DateTime.now()).millisecondsSinceEpoch}'
      '${suffix.toString().padLeft(3, '0')}';
}

/// Total price rounded to 2 decimals; 0 for non-positive/invalid inputs.
double seedBookingTotal(num? price, num? qty) {
  final p = price?.toDouble() ?? 0;
  final q = qty?.toDouble() ?? 0;
  if (!p.isFinite || !q.isFinite || p <= 0 || q <= 0) return 0;
  return (p * q * 100).round() / 100;
}
