/// Formats a price for display: no decimals for whole numbers, otherwise two
/// (e.g. 450.00 -> "₹450", 99.5 -> "₹99.50"). Accepts num or numeric String;
/// unparseable input yields "₹0".
String formatShopPrice(Object? value) {
  final v = value is num ? value.toDouble() : double.tryParse('$value'.trim());
  final n = (v == null || v.isNaN || v.isInfinite) ? 0.0 : v;
  final rounded = (n * 100).round() / 100;
  final whole = rounded == rounded.roundToDouble();
  return '₹${rounded.toStringAsFixed(whole ? 0 : 2)}';
}

/// Shop product model.
class Product {
  final String name;
  final String category;

  /// Normalized price string: "450" for whole numbers, "99.50" otherwise.
  /// Use [priceValue] for math and [formatShopPrice] for display.
  final String price;
  final String description;
  final String? imageUrl1;
  final String? imageUrl2;
  final String? imageUrl3;
  final String? videoUrl;
  final String advertiserName;
  final bool isPopular;
  final String unit;
  final int id;
  final int advertiserId;

  /// Maximum retail price; null when absent or zero.
  final double? mrp;
  final bool inStock;
  final DateTime? createdAt;

  Product({
    required this.id,
    required this.advertiserId,
    required this.name,
    required this.category,
    required this.price,
    required this.description,
    this.imageUrl1,
    this.imageUrl2,
    this.imageUrl3,
    this.videoUrl,
    required this.advertiserName,
    this.isPopular = false,
    this.unit = 'unit',
    this.mrp,
    this.inStock = true,
    this.createdAt,
  });

  /// Parses an API row. [noDescription] / [unknownSeller] are fallbacks
  /// (callers pass localized strings).
  factory Product.fromJson(
    Map<String, dynamic> p, {
    String noDescription = '',
    String unknownSeller = '',
  }) {
    final priceNum = double.tryParse(p['price']?.toString() ?? '0') ?? 0.0;
    final mrpValue = double.tryParse(p['mrp']?.toString() ?? '');
    return Product(
      id: int.tryParse(
              p['product_id']?.toString() ?? p['id']?.toString() ?? '0') ??
          0,
      advertiserId: int.tryParse(p['advertiser_id']?.toString() ?? '0') ?? 0,
      name: p['product_name']?.toString() ?? p['name']?.toString() ?? 'N/A',
      category: p['category']?.toString() ?? 'General',
      price: _normalizePrice(priceNum),
      description: p['product_description']?.toString() ??
          p['description']?.toString() ??
          noDescription,
      imageUrl1: p['image_url_1']?.toString(),
      imageUrl2: p['image_url_2']?.toString(),
      imageUrl3: p['image_url_3']?.toString(),
      videoUrl:
          p['product_video_url']?.toString() ?? p['video_url']?.toString(),
      advertiserName: p['advertiser_name']?.toString() ?? unknownSeller,
      isPopular: priceNum > 500,
      unit: 'unit',
      mrp: (mrpValue == null || mrpValue <= 0) ? null : mrpValue,
      inStock: _parseBool(p['in_stock'], true),
      createdAt: DateTime.tryParse(p['created_at']?.toString() ?? ''),
    );
  }

  /// Numeric price (0 when unparseable).
  double get priceValue => double.tryParse(price) ?? 0;

  static String _normalizePrice(double v) {
    final r = (v * 100).round() / 100;
    return r.toStringAsFixed(r == r.roundToDouble() ? 0 : 2);
  }

  /// Real discount percent rounded, only when [mrp] exceeds the price.
  int? get discountPercent {
    final m = mrp;
    final price0 = priceValue;
    if (m == null || price0 <= 0 || m <= price0) return null;
    final pct = ((m - price0) / m * 100).round();
    return pct > 0 ? pct : null;
  }

  /// First non-empty image URL among imageUrl1..3 (empty string if none).
  String get primaryImage {
    for (final u in [imageUrl1, imageUrl2, imageUrl3]) {
      if (u != null && u.trim().isNotEmpty) return u;
    }
    return '';
  }

  static bool _parseBool(dynamic v, bool fallback) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase().trim();
    if (s == '1' || s == 'true' || s == 'yes') return true;
    if (s == '0' || s == 'false' || s == 'no') return false;
    return fallback;
  }
}
