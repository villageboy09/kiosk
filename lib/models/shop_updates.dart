import 'package:flutter/material.dart';

Color _hex(dynamic v, Color fallback) {
  final s = v?.toString().trim().replaceFirst('#', '') ?? '';
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(s)) return fallback;
  return Color(0xFF000000 | int.parse(s, radix: 16));
}

int _int(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

String? _url(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

class ShopUpdateProduct {
  final int id;
  final String name;
  final String? imageUrl;
  final String price;

  const ShopUpdateProduct({
    required this.id,
    required this.name,
    this.imageUrl,
    this.price = '',
  });

  factory ShopUpdateProduct.fromJson(Map<String, dynamic> j) =>
      ShopUpdateProduct(
        id: _int(j['product_id'] ?? j['id']),
        name: j['name']?.toString() ?? '',
        imageUrl: _url(j['image_url']),
        price: j['price']?.toString() ?? '',
      );
}

class ShopUpdateBanner {
  final int id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final Color bgColor1;
  final Color bgColor2;

  const ShopUpdateBanner({
    required this.id,
    this.title = '',
    this.subtitle = '',
    this.imageUrl,
    this.bgColor1 = const Color(0xFF1B5E20),
    this.bgColor2 = const Color(0xFF43A047),
  });

  factory ShopUpdateBanner.fromJson(Map<String, dynamic> j) => ShopUpdateBanner(
        id: _int(j['id']),
        title: j['title']?.toString() ?? '',
        subtitle: j['subtitle']?.toString() ?? '',
        imageUrl: _url(j['image_url']),
        bgColor1: _hex(j['bg_color_1'], const Color(0xFF1B5E20)),
        bgColor2: _hex(j['bg_color_2'], const Color(0xFF43A047)),
      );
}

class ShopUpdates {
  final int latestProductId;
  final int latestBannerId;
  final int newProductsCount;
  final List<ShopUpdateProduct> newProducts;
  final int newBannersCount;
  final List<ShopUpdateBanner> newBanners;

  const ShopUpdates({
    this.latestProductId = 0,
    this.latestBannerId = 0,
    this.newProductsCount = 0,
    this.newProducts = const [],
    this.newBannersCount = 0,
    this.newBanners = const [],
  });

  factory ShopUpdates.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(dynamic v, T Function(Map<String, dynamic>) f) => v is List
        ? v
            .whereType<Map>()
            .map((e) => f(Map<String, dynamic>.from(e)))
            .toList()
        : <T>[];
    final products = list(j['new_products'], ShopUpdateProduct.fromJson);
    final banners = list(j['new_banners'], ShopUpdateBanner.fromJson);
    return ShopUpdates(
      latestProductId: _int(j['latest_product_id']),
      latestBannerId: _int(j['latest_banner_id']),
      newProductsCount: j['new_products_count'] == null
          ? products.length
          : _int(j['new_products_count']),
      newProducts: products,
      newBannersCount: j['new_banners_count'] == null
          ? banners.length
          : _int(j['new_banners_count']),
      newBanners: banners,
    );
  }

  bool get hasNew => newProductsCount > 0 || newBannersCount > 0;
}
