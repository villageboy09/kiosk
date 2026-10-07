import 'package:cropsync/utils/market_aliases.dart';

/// Prices are always quoted per quintal (100 kg).
const String kMarketUnit = 'qtl';

/// Parses a number that may arrive as num, String (with commas / currency
/// symbols) or null. Returns null for missing, non-numeric or non-positive
/// values (a 0 price means "not available").
double? parsePrice(dynamic v) {
  final d = parseNumber(v);
  if (d == null || d <= 0) return null;
  return d;
}

double? parseNumber(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.isFinite ? v.toDouble() : null;
  var s = v.toString().trim();
  if (s.isEmpty) return null;
  s = s.replaceAll(RegExp(r'[,\s₹]|Rs\.?', caseSensitive: false), '');
  final d = double.tryParse(s);
  if (d == null || !d.isFinite) return null;
  return d;
}

/// Parses Y-m-d, d/m/Y, d-m-Y or ISO strings. Null when unparseable.
DateTime? parseMarketDate(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  final ymd = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
  if (ymd != null) {
    return _safeDate(
        int.parse(ymd[1]!), int.parse(ymd[2]!), int.parse(ymd[3]!));
  }
  final dmy = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})$').firstMatch(s);
  if (dmy != null) {
    return _safeDate(
        int.parse(dmy[3]!), int.parse(dmy[2]!), int.parse(dmy[1]!));
  }
  return DateTime.tryParse(s);
}

DateTime? _safeDate(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  return DateTime(y, m, d);
}

String? _str(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
  }
  return null;
}

/// Lower-cases keys and strips '_', '-', ' ' so key-casing variants collapse.
Map<String, dynamic> _flatKeys(Map<dynamic, dynamic> raw) {
  final out = <String, dynamic>{};
  raw.forEach((k, v) {
    out[k.toString().toLowerCase().replaceAll(RegExp(r'[_\- ]'), '')] = v;
  });
  return out;
}

class MarketPrice {
  final String commodity;
  final String variety;
  final String grade;
  final String market;
  final String district;
  final String state;
  final double? minPrice;
  final double? maxPrice;
  final double? modalPrice;
  final DateTime? arrivalDate;
  final String imageUrl;

  const MarketPrice({
    required this.commodity,
    this.variety = '',
    this.grade = '',
    this.market = '',
    this.district = '',
    this.state = '',
    this.minPrice,
    this.maxPrice,
    this.modalPrice,
    this.arrivalDate,
    this.imageUrl = '',
  });

  factory MarketPrice.fromJson(Map<dynamic, dynamic> raw) {
    final m = _flatKeys(raw);
    return MarketPrice(
      commodity: _str(m, ['commodity', 'commodityname', 'name']) ?? '',
      variety: _str(m, ['variety']) ?? '',
      grade: _str(m, ['grade']) ?? '',
      market: _str(m, ['market', 'marketname']) ?? '',
      district: _str(m, ['district', 'districtname']) ?? '',
      state: _str(m, ['state', 'statename']) ?? '',
      minPrice: parsePrice(m['minprice'] ?? m['min'] ?? m['minx0020price']),
      maxPrice: parsePrice(m['maxprice'] ?? m['max'] ?? m['maxx0020price']),
      modalPrice:
          parsePrice(m['modalprice'] ?? m['modal'] ?? m['modalx0020price']),
      arrivalDate: parseMarketDate(
          m['arrivaldate'] ?? m['date'] ?? m['arrivalx0020date']),
      imageUrl: _str(m, ['imageurl', 'image']) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'commodity': commodity,
        'variety': variety,
        'grade': grade,
        'market': market,
        'district': district,
        'state': state,
        'min_price': minPrice,
        'max_price': maxPrice,
        'modal_price': modalPrice,
        'arrival_date': arrivalDate == null ? null : _ymd(arrivalDate!),
        'image_url': imageUrl,
      };

  bool get hasPrice => modalPrice != null;

  /// (max - min) / modal * 100 when all three are known.
  double? get spreadPct {
    final lo = minPrice, hi = maxPrice, mid = modalPrice;
    if (lo == null || hi == null || mid == null || mid <= 0) return null;
    return (hi - lo) / mid * 100;
  }

  /// Indian-grouped rupees: 6850 -> ₹6,850, 125000 -> ₹1,25,000.
  /// [compact] gives ₹1.25L / ₹2.5Cr for >= 1 lakh.
  static String formatRupees(num value, {bool compact = false}) {
    final neg = value < 0;
    final v = value.abs();
    if (compact && v >= 100000) {
      String trim(double d) {
        final s = d.toStringAsFixed(2);
        return s.replaceFirst(RegExp(r'\.?0+$'), '');
      }

      final body =
          v >= 10000000 ? '${trim(v / 10000000)}Cr' : '${trim(v / 100000)}L';
      return '${neg ? '-' : ''}₹$body';
    }
    final rounded = v.round();
    return '${neg ? '-' : ''}₹${_indianGroup(rounded.toString())}';
  }
}

String _indianGroup(String digits) {
  if (digits.length <= 3) return digits;
  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last3';
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// One real historical data point (from get_commodity_trends).
class TrendPoint {
  final DateTime? date;
  final double avgPrice;
  final double? minPrice;
  final double? maxPrice;

  const TrendPoint(
      {this.date, required this.avgPrice, this.minPrice, this.maxPrice});

  static TrendPoint? tryParse(Map<dynamic, dynamic> raw) {
    final m = _flatKeys(raw);
    final avg =
        parsePrice(m['avgprice'] ?? m['modalprice'] ?? m['price'] ?? m['avg']);
    if (avg == null) return null;
    return TrendPoint(
      date: parseMarketDate(m['arrivaldate'] ?? m['date']),
      avgPrice: avg,
      minPrice: parsePrice(m['minprice']),
      maxPrice: parsePrice(m['maxprice']),
    );
  }
}

// ---------------------------------------------------------------------------
// Commodity normalisation, categories and grouping
// ---------------------------------------------------------------------------

const Set<String> _noiseTokens = {
  'common',
  'whole',
  'dhan',
  'and',
  'of',
  'the',
  'pearl',
  'millet',
  'local',
  'faq',
  'other',
  'dry',
  'sorghum',
  'finger',
};

const Map<String, String> _tokenSynonyms = {
  'cumbu': 'bajra',
  'soyabean': 'soybean',
  'soyabeen': 'soybean',
  'soya': 'soybean',
  'chillies': 'chilli',
  'chili': 'chilli',
  'chillis': 'chilli',
  'chilies': 'chilli',
  'groundnuts': 'groundnut',
};

List<String> _tokens(String s) {
  final cleaned = s
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true), ' ')
      .trim();
  if (cleaned.isEmpty) return const [];
  return cleaned
      .split(' ')
      .where((t) => t.isNotEmpty)
      .map((t) => _tokenSynonyms[t] ?? t)
      .toList();
}

/// Normalised key merging aliases: 'Paddy(Common)' and 'Paddy(Dhan)(Common)'
/// both give 'paddy'; word order is ignored. Never empty for a non-empty
/// name (falls back to all tokens when only noise remains).
String commodityKey(String name) {
  final all = _tokens(name);
  if (all.isEmpty) return name.trim().toLowerCase();
  var kept =
      all.where((t) => !_noiseTokens.contains(t) && t.length > 1).toSet();
  if (kept.isEmpty) kept = all.toSet();
  final list = kept.toList()..sort();
  return list.join(' ');
}

const Map<String, List<String>> _categoryKeywords = {
  'spices': [
    'turmeric',
    'coriander',
    'cumin',
    'jeera',
    'pepper',
    'chilli',
    'cardamom',
    'clove',
    'cloves',
    'ginger',
    'garlic',
    'fenugreek',
    'methi',
    'ajwain',
    'fennel',
    'saunf',
    'cinnamon',
    'nutmeg',
    'tamarind',
    'mace',
    'poppy',
    'haldi',
    'dhaniya',
  ],
  'cash_crops': [
    'cotton',
    'kapas',
    'sugarcane',
    'jute',
    'tobacco',
    'rubber',
    'tea',
    'coffee',
    'mesta',
    'cashewnut',
    'cashew',
    'arecanut',
    'betelnut',
  ],
  'oilseeds': [
    'groundnut',
    'ground nut',
    'soybean',
    'sunflower',
    'mustard',
    'rapeseed',
    'sesame',
    'sesamum',
    'gingelly',
    'til',
    'castor',
    'linseed',
    'niger',
    'safflower',
    'copra',
    'coconut',
    'cotton seed',
    'rai',
    'taramira',
  ],
  'pulses': [
    'gram',
    'dal',
    'dhal',
    'arhar',
    'tur',
    'moong',
    'urad',
    'masoor',
    'lentil',
    'lentils',
    'moth',
    'cowpea',
    'lobia',
    'rajma',
    'kulthi',
    'horsegram',
    'pulses',
    'beans dry',
    'pigeon pea',
    'tur dal',
  ],
  'cereals': [
    'paddy',
    'rice',
    'wheat',
    'maize',
    'corn',
    'jowar',
    'bajra',
    'ragi',
    'barley',
    'millet',
    'millets',
    'sorghum',
    'oats',
    'kodo',
    'foxtail',
    'bhat',
    'dhan',
    'sama',
    'jau',
  ],
  'fruits': [
    'apple',
    'banana',
    'mango',
    'orange',
    'grapes',
    'grape',
    'papaya',
    'pomegranate',
    'guava',
    'lemon',
    'lime',
    'pineapple',
    'watermelon',
    'melon',
    'sapota',
    'chikoo',
    'custard apple',
    'pear',
    'peach',
    'plum',
    'litchi',
    'lychee',
    'mousambi',
    'mosambi',
    'kinnow',
    'jackfruit',
    'fig',
    'strawberry',
    'avocado',
    'kiwi',
    'dates',
    'amla',
    'ber',
    'cherry',
    'dragon fruit',
  ],
  'vegetables': [
    'tomato',
    'onion',
    'potato',
    'brinjal',
    'cabbage',
    'cauliflower',
    'carrot',
    'beetroot',
    'radish',
    'okra',
    'bhindi',
    'lady finger',
    'ladies finger',
    'cucumber',
    'pumpkin',
    'gourd',
    'bottle gourd',
    'bitter gourd',
    'ridge gourd',
    'snake gourd',
    'capsicum',
    'beans',
    'cluster beans',
    'peas',
    'spinach',
    'drumstick',
    'cabbage',
    'sweet potato',
    'tapioca',
    'yam',
    'elephant yam',
    'colocasia',
    'leafy vegetable',
    'knool khol',
    'raddish',
    'turnip',
    'lettuce',
    'broccoli',
    'brinjal',
    'ash gourd',
    'pointed gourd',
    'tinda',
    'karela',
    'lauki',
    'green chilli',
    'coriander leaves',
    'mint',
    'curry leaves',
    'spring onion',
    'mushroom',
    'beet root',
  ],
};

const List<String> _categoryOrder = [
  'spices',
  'cash_crops',
  'oilseeds',
  'pulses',
  'cereals',
  'fruits',
  'vegetables',
];

const List<String> _pulseWords = [
  'gram',
  'urd',
  'urad',
  'moong',
  'mung',
  'masoor',
  'arhar',
  'tur',
  'dal',
  'dhal',
  'lentil',
  'lentils',
  'cowpea',
  'lobia',
  'rajma',
  'kulthi',
  'horsegram',
  'pulses',
];

/// One of: cereals, pulses, oilseeds, vegetables, fruits, spices,
/// cash_crops, other. Whole-word keyword matching (turmeric is a spice, not
/// 'tur').
String marketCategoryOf(String commodity) {
  final toks = _tokens(commodity);
  if (toks.isEmpty) return 'other';
  final s = ' ${toks.join(' ')} ';
  bool has(String kw) => s.contains(' $kw ');

  // Fresh/green items are vegetables even when the dry form is a spice.
  if (has('green') && (has('chilli') || has('ginger'))) return 'vegetables';
  if (has('coriander') && (has('leaves') || has('leaf'))) return 'vegetables';
  if (has('garlic') && has('green')) return 'vegetables';
  // Pulses first: 'Black Gram (Urd Beans)' is a pulse although it says beans.
  if (_pulseWords.any(has)) {
    if (has('cowpea') && (has('veg') || has('vegetable'))) {
      return 'vegetables';
    }
    return 'pulses';
  }
  if (has('peas') && !has('dry')) return 'vegetables';
  if (has('beans') && !has('dry')) return 'vegetables';
  if (has('sweet') && has('potato')) return 'vegetables';
  if (has('coconut') && has('fresh')) return 'fruits';

  for (final cat in _categoryOrder) {
    for (final kw in _categoryKeywords[cat]!) {
      if (has(kw)) return cat;
    }
  }
  return 'other';
}

/// Priced rows of the newest arrival date among [rows]: statistics (best,
/// lowest, average) must not mix prices from different days. Rows without a
/// date only count when no row has one.
List<MarketPrice> newestPricedRows(Iterable<MarketPrice> rows) {
  final priced = rows.where((r) => r.hasPrice).toList();
  DateTime? newest;
  for (final r in priced) {
    final a = r.arrivalDate;
    if (a != null && (newest == null || a.isAfter(newest))) newest = a;
  }
  if (newest == null) return priced;
  return priced.where((r) => r.arrivalDate == newest).toList();
}

class CommodityPrices {
  /// Most frequent spelling among merged rows.
  final String name;
  final String key;
  final List<MarketPrice> rows;

  /// Row with the highest modal price among the newest-date rows (null when
  /// no row has a price).
  final MarketPrice? best;

  /// Row with the lowest modal price.
  final MarketPrice? lowest;

  /// Mean of modal prices over priced rows.
  final double? averageModal;

  /// Row in the user's district, if any (latest date, then highest modal).
  final MarketPrice? userDistrictRow;

  const CommodityPrices({
    required this.name,
    required this.key,
    required this.rows,
    this.best,
    this.lowest,
    this.averageModal,
    this.userDistrictRow,
  });

  int get count => rows.length;
  int get pricedCount => rows.where((r) => r.hasPrice).length;
  String get category => marketCategoryOf(name);
  bool get hasPrice => best != null;

  String get imageUrl {
    for (final r in rows) {
      if (r.imageUrl.isNotEmpty) return r.imageUrl;
    }
    return '';
  }

  DateTime? get latestDate {
    DateTime? d;
    for (final r in rows) {
      final a = r.arrivalDate;
      if (a != null && (d == null || a.isAfter(d))) d = a;
    }
    return d;
  }

  /// Percent change of the current representative price (user-district row,
  /// else average) versus the previous real data point. Null unless at
  /// least two real points with a positive previous price exist.
  double? changePct(List<TrendPoint> points) {
    if (points.length < 2) return null;
    final sorted = [...points];
    if (sorted.every((p) => p.date != null)) {
      sorted.sort((a, b) => a.date!.compareTo(b.date!));
    }
    final prev = sorted[sorted.length - 2].avgPrice;
    final latest = sorted.last.avgPrice;
    if (prev <= 0) return null;
    return (latest - prev) / prev * 100;
  }
}

/// Groups rows by normalised commodity. Never drops a row or a commodity.
/// Sorted by number of rows (desc) then name.
List<CommodityPrices> groupByCommodity(
  List<MarketPrice> rows, {
  String? userDistrict,
}) {
  final buckets = <String, List<MarketPrice>>{};
  for (final r in rows) {
    final k = commodityKey(r.commodity);
    buckets.putIfAbsent(k, () => []).add(r);
  }

  final out = <CommodityPrices>[];
  buckets.forEach((key, list) {
    final freq = <String, int>{};
    for (final r in list) {
      freq[r.commodity] = (freq[r.commodity] ?? 0) + 1;
    }
    var name = list.first.commodity;
    var bestN = 0;
    freq.forEach((n, c) {
      if (c > bestN || (c == bestN && n.length < name.length)) {
        bestN = c;
        name = n;
      }
    });

    final priced = list.where((r) => r.hasPrice).toList();
    // Stats over the newest arrival date only (older rows stay in `rows`).
    final current = newestPricedRows(priced);
    MarketPrice? best, lowest;
    double? avg;
    if (current.isNotEmpty) {
      best = current.reduce((a, b) => b.modalPrice! > a.modalPrice! ? b : a);
      lowest = current.reduce((a, b) => b.modalPrice! < a.modalPrice! ? b : a);
      avg =
          current.fold<double>(0, (s, r) => s + r.modalPrice!) / current.length;
    }

    MarketPrice? mine;
    if (userDistrict != null && userDistrict.trim().isNotEmpty) {
      for (final r in priced) {
        if (r.district.isEmpty || !sameDistrict(r.district, userDistrict)) {
          continue;
        }
        if (mine == null) {
          mine = r;
          continue;
        }
        final da = mine.arrivalDate, db = r.arrivalDate;
        if (db != null && (da == null || db.isAfter(da))) {
          mine = r;
        } else if ((db == null && da == null || db == da) &&
            r.modalPrice! > mine.modalPrice!) {
          mine = r;
        }
      }
    }

    out.add(CommodityPrices(
      name: name,
      key: key,
      rows: List.unmodifiable(list),
      best: best,
      lowest: lowest,
      averageModal: avg,
      userDistrictRow: mine,
    ));
  });

  out.sort((a, b) {
    final c = b.count.compareTo(a.count);
    return c != 0 ? c : a.name.compareTo(b.name);
  });
  return out;
}
