import 'dart:convert';

import 'package:cropsync/models/shop_banner.dart';
import 'package:cropsync/models/shop_updates.dart';
import 'package:cropsync/screens/agri_shop.dart' show Product, formatShopPrice;
import 'package:cropsync/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ShopBanner', () {
    test('parses full row', () {
      final b = ShopBanner.fromJson({
        'id': '4',
        'title': 'T',
        'target_type': 'product',
        'target_value': '9',
        'bg_color_1': '#112233',
        'bg_color_2': 'FF0000',
        'icon_key': 'bolt',
        'image_url': 'https://x/y.jpg',
        'sort_order': '2',
        'created_at': '2026-01-02 03:04:05',
      });
      expect(b.id, 4);
      expect(b.targetType, ShopBannerTarget.product);
      expect(b.bgColor1, const Color(0xFF112233));
      expect(b.bgColor2, const Color(0xFFFF0000));
      expect(b.isImageBanner, isTrue);
      expect(b.icon, Icons.bolt_rounded);
      expect(b.createdAt, DateTime(2026, 1, 2, 3, 4, 5));
      expect(b.updatedAt, isNull);
    });
    test('fallbacks', () {
      final b = ShopBanner.fromJson({
        'id': 1,
        'bg_color_1': 'zzz',
        'target_type': 'weird',
        'image_url': '  ',
        'icon_key': 'nope',
      });
      expect(b.bgColor1, const Color(0xFF1B5E20));
      expect(b.targetType, ShopBannerTarget.none);
      expect(b.isImageBanner, isFalse);
      expect(b.icon, Icons.local_offer_rounded);
    });
    test('aspect ratio', () => expect(kShopBannerAspectRatio, 2.5));
  });

  group('Product', () {
    Map<String, dynamic> row(Map<String, dynamic> extra) =>
        {'product_id': '7', 'name': 'N', 'price': '450.00', ...extra};

    test('null/zero mrp -> null, no discount', () {
      expect(Product.fromJson(row({})).mrp, isNull);
      expect(Product.fromJson(row({'mrp': 0})).mrp, isNull);
      expect(Product.fromJson(row({'mrp': '0.00'})).discountPercent, isNull);
    });
    test('discountPercent', () {
      final p = Product.fromJson(row({'mrp': '600'}));
      expect(p.price, '450');
      expect(p.priceValue, 450);
      expect(p.discountPercent, 25);
      expect(Product.fromJson(row({'mrp': '450'})).discountPercent, isNull);
      expect(Product.fromJson(row({'mrp': '300'})).discountPercent, isNull);
    });
    test('inStock and createdAt', () {
      expect(Product.fromJson(row({})).inStock, isTrue);
      expect(Product.fromJson(row({'in_stock': '0'})).inStock, isFalse);
      expect(Product.fromJson(row({'in_stock': 1})).inStock, isTrue);
      expect(
          Product.fromJson(row({'created_at': 'garbage'})).createdAt, isNull);
      expect(Product.fromJson(row({})).createdAt, isNull);
      expect(
          Product.fromJson(row({'created_at': '2026-03-04 10:00:00'}))
              .createdAt,
          DateTime(2026, 3, 4, 10));
    });
    test('primaryImage', () {
      expect(Product.fromJson(row({})).primaryImage, '');
      expect(
          Product.fromJson(row({'image_url_1': '', 'image_url_3': 'c'}))
              .primaryImage,
          'c');
      expect(Product.fromJson(row({'image_url_2': 'b'})).primaryImage, 'b');
    });
  });

  group('ShopUpdates', () {
    test('parses and hasNew', () {
      final u = ShopUpdates.fromJson({
        'success': true,
        'latest_product_id': '20',
        'latest_banner_id': 5,
        'new_products_count': 2,
        'new_products': [
          {'product_id': 19, 'name': 'A', 'image_url': '', 'price': '10'},
          {'product_id': '20', 'name': 'B', 'image_url': 'u', 'price': '20'},
        ],
        'new_banners_count': 0,
        'new_banners': [],
      });
      expect(u.latestProductId, 20);
      expect(u.newProducts.length, 2);
      expect(u.newProducts.first.imageUrl, isNull);
      expect(u.hasNew, isTrue);
      expect(ShopUpdates.fromJson({}).hasNew, isFalse);
    });
    test('banner colors', () {
      final u = ShopUpdates.fromJson({
        'new_banners_count': 1,
        'new_banners': [
          {'id': 1, 'title': 't', 'bg_color_1': '#000000', 'bg_color_2': 'bad'}
        ],
      });
      expect(u.newBanners.single.bgColor1, const Color(0xFF000000));
      expect(u.newBanners.single.bgColor2, const Color(0xFF43A047));
      expect(u.hasNew, isTrue);
    });
  });

  group('ApiService shop', () {
    test('getShopBanners parses and returns [] on error', () async {
      final ok = MockClient((r) async {
        expect(r.url.queryParameters['action'], 'get_shop_banners');
        expect(r.url.queryParameters['lang'], 'te');
        return http.Response(
            jsonEncode({
              'success': true,
              'banners': [
                {'id': 1, 'title': 'x'}
              ]
            }),
            200);
      });
      expect(
          (await ApiService.getShopBanners(lang: 'te', client: ok)).length, 1);
      final bad = MockClient((r) async => http.Response('nope', 500));
      expect(await ApiService.getShopBanners(lang: 'te', client: bad), isEmpty);
    });
    test('getShopUpdates query and null on error', () async {
      final ok = MockClient((r) async {
        expect(r.url.queryParameters['since_product_id'], '-1');
        expect(r.url.queryParameters['user_id'], 'u1');
        return http.Response(
            jsonEncode({'success': true, 'latest_product_id': 3}), 200);
      });
      final u = await ApiService.getShopUpdates(
          lang: 'en',
          sinceProductId: -1,
          sinceBannerId: -1,
          userId: 'u1',
          client: ok);
      expect(u!.latestProductId, 3);
      final bad = MockClient((r) async => throw Exception('x'));
      expect(
          await ApiService.getShopUpdates(
              lang: 'en', sinceProductId: 0, sinceBannerId: 0, client: bad),
          isNull);
    });
  });

  group('formatShopPrice', () {
    test('whole numbers have no decimals', () {
      expect(formatShopPrice('450.00'), '₹450');
      expect(formatShopPrice(450), '₹450');
      expect(formatShopPrice('450'), '₹450');
    });
    test('fractions keep two decimals', () {
      expect(formatShopPrice('99.5'), '₹99.50');
      expect(formatShopPrice(99.5), '₹99.50');
      expect(formatShopPrice('12.345'), '₹12.35');
    });
    test('garbage falls back to zero', () {
      expect(formatShopPrice(''), '₹0');
      expect(formatShopPrice(null), '₹0');
    });
    test('Product keeps paise', () {
      final p =
          Product.fromJson({'product_id': 1, 'name': 'N', 'price': '99.50'});
      expect(p.price, '99.50');
      expect(p.priceValue, 99.5);
      expect(formatShopPrice(p.priceValue), '₹99.50');
    });
  });
}
