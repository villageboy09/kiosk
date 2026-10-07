import 'package:flutter/material.dart';

/// Banner image aspect ratio (1250x500).
const double kShopBannerAspectRatio = 5 / 2;

enum ShopBannerTarget { none, product, category, url }

Color _hex(dynamic v, Color fallback) {
  final s = v?.toString().trim().replaceFirst('#', '') ?? '';
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(s)) return fallback;
  return Color(0xFF000000 | int.parse(s, radix: 16));
}

DateTime? _date(dynamic v) => DateTime.tryParse(v?.toString() ?? '');

class ShopBanner {
  final int id;
  final String tag;
  final String title;
  final String subtitle;
  final String ctaText;
  final String badge;
  final ShopBannerTarget targetType;
  final String targetValue;
  final Color bgColor1;
  final Color bgColor2;
  final String iconKey;
  final String? imageUrl;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ShopBanner({
    required this.id,
    this.tag = '',
    this.title = '',
    this.subtitle = '',
    this.ctaText = '',
    this.badge = '',
    this.targetType = ShopBannerTarget.none,
    this.targetValue = '',
    this.bgColor1 = const Color(0xFF1B5E20),
    this.bgColor2 = const Color(0xFF43A047),
    this.iconKey = '',
    this.imageUrl,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory ShopBanner.fromJson(Map<String, dynamic> j) {
    final img = j['image_url']?.toString().trim();
    final type = j['target_type']?.toString().toLowerCase().trim();
    return ShopBanner(
      id: int.tryParse(j['id']?.toString() ?? '') ?? 0,
      tag: j['tag']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      subtitle: j['subtitle']?.toString() ?? '',
      ctaText: j['cta_text']?.toString() ?? '',
      badge: j['badge']?.toString() ?? '',
      targetType: ShopBannerTarget.values.firstWhere(
        (e) => e.name == type,
        orElse: () => ShopBannerTarget.none,
      ),
      targetValue: j['target_value']?.toString() ?? '',
      bgColor1: _hex(j['bg_color_1'], const Color(0xFF1B5E20)),
      bgColor2: _hex(j['bg_color_2'], const Color(0xFF43A047)),
      iconKey: j['icon_key']?.toString() ?? '',
      imageUrl: (img == null || img.isEmpty) ? null : img,
      sortOrder: int.tryParse(j['sort_order']?.toString() ?? '') ?? 0,
      createdAt: _date(j['created_at']),
      updatedAt: _date(j['updated_at']),
    );
  }

  bool get isImageBanner => imageUrl != null && imageUrl!.isNotEmpty;

  IconData get icon {
    switch (iconKey) {
      case 'eco':
        return Icons.eco_rounded;
      case 'verified':
        return Icons.verified_rounded;
      case 'local_shipping':
        return Icons.local_shipping_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'agriculture':
        return Icons.agriculture_rounded;
      case 'shield':
        return Icons.shield_rounded;
      case 'percent':
        return Icons.percent_rounded;
      default:
        return Icons.local_offer_rounded;
    }
  }
}
