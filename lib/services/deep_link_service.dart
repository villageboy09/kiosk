import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:cropsync/models/crop_problem.dart';
import 'package:cropsync/screens/advisory_details.dart';
import 'package:cropsync/screens/agri_shop.dart';
import 'package:cropsync/screens/crop_problems_screen.dart';
import 'package:cropsync/screens/market_prices.dart';
import 'package:cropsync/screens/news/news_detail_screen.dart';
import 'package:cropsync/screens/news/news_feed_screen.dart';
import 'package:cropsync/screens/product_details_screen.dart';
import 'package:cropsync/screens/reels_screen.dart';
import 'package:cropsync/screens/seed_varieties.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/news_service.dart';
import 'package:cropsync/services/notification_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Centralized Deep Linking & Universal Link Service for CropSync
/// Handles:
///  - cropsync://share?type=...
///  - https://kiosk.cropsync.in/api/share.php?type=...
///  - https://cropsync.in/share?type=...
class DeepLinkService {
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _linkSubscription;
  static bool _isInitialized = false;

  /// Initialize deep link listening on app startup
  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      // 1. Handle cold-boot launch URL (app launched directly by clicking link)
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('DeepLinkService: Initial link received: $initialUri');
        // Wait a tick for UI navigator to be fully mounted
        Future.delayed(const Duration(milliseconds: 600), () {
          handleUri(initialUri);
        });
      }

      // 2. Listen to links while app is in background or foreground
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) {
          debugPrint('DeepLinkService: Stream link received: $uri');
          handleUri(uri);
        },
        onError: (err) {
          debugPrint('DeepLinkService error: $err');
        },
      );
    } catch (e) {
      debugPrint('DeepLinkService initialization error: $e');
    }
  }

  /// Process and navigate based on URI
  static Future<void> handleUri(Uri uri) async {
    final nav = NotificationService.navigatorKey.currentState;
    if (nav == null) {
      // Retry after a short delay if navigator is not mounted yet
      Future.delayed(const Duration(milliseconds: 500), () => handleUri(uri));
      return;
    }

    final query = uri.queryParameters;
    final type = query['type']?.toLowerCase().trim() ?? '';
    final id = query['id']?.trim() ?? '';
    final crop = query['crop']?.trim() ?? '';
    final commodity = query['commodity']?.trim() ?? '';
    final lang = query['lang']?.toLowerCase().trim();

    // Optionally adapt locale if passed and valid
    if (lang != null && ['en', 'hi', 'te'].contains(lang)) {
      final ctx = NotificationService.navigatorKey.currentContext;
      if (ctx != null && ctx.locale.languageCode != lang) {
        ctx.setLocale(Locale(lang));
      }
    }

    switch (type) {
      case 'shop':
        await _handleShopRoute(nav, id, query);
        break;

      case 'advisory':
        await _handleAdvisoryRoute(nav, id, crop, query);
        break;

      case 'market':
        nav.push(
          MaterialPageRoute(
            builder: (_) => MarketPricesScreen(initialCommodity: commodity.isNotEmpty ? commodity : query['title']),
          ),
        );
        break;

      case 'seed':
      case 'seeds':
        nav.push(
          MaterialPageRoute(
            builder: (_) => SeedVarietiesScreen(
              initialCrop: crop.isNotEmpty ? crop : query['crop_name'],
              initialVarietyId: int.tryParse(id),
            ),
          ),
        );
        break;

      case 'news':
        await _handleNewsRoute(nav, id);
        break;

      case 'reel':
      case 'reels':
        nav.push(
          MaterialPageRoute(
            builder: (_) => ReelsScreen(initialReelId: int.tryParse(id)),
          ),
        );
        break;

      default:
        debugPrint('DeepLinkService: Unrecognized deep link type: $type');
        break;
    }
  }

  static Future<void> _handleShopRoute(NavigatorState nav, String id, Map<String, String> query) async {
    final productId = int.tryParse(id);
    if (productId != null) {
      try {
        final products = await ApiService.getProducts();
        final match = products.where((p) {
          final pId = int.tryParse(p['product_id']?.toString() ?? p['id']?.toString() ?? '0');
          return pId == productId;
        }).firstOrNull;

        if (match != null) {
          final product = Product(
            id: productId,
            advertiserId: int.tryParse(match['advertiser_id']?.toString() ?? '0') ?? 0,
            name: match['product_name']?.toString() ?? match['name']?.toString() ?? 'Product',
            category: match['category']?.toString() ?? 'General',
            price: match['price']?.toString() ?? '0',
            description: match['product_description']?.toString() ?? match['description']?.toString() ?? '',
            imageUrl1: match['image_url_1']?.toString(),
            imageUrl2: match['image_url_2']?.toString(),
            imageUrl3: match['image_url_3']?.toString(),
            videoUrl: match['product_video_url']?.toString(),
            advertiserName: match['advertiser_name']?.toString() ?? 'Agri Partner',
          );
          nav.push(MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: product)));
          return;
        }
      } catch (e) {
        debugPrint('Error resolving product deep link: $e');
      }
    }
    // Fallback to AgriShop
    nav.push(MaterialPageRoute(builder: (_) => const AgriShopScreen()));
  }

  static Future<void> _handleAdvisoryRoute(NavigatorState nav, String id, String crop, Map<String, String> query) async {
    final cropName = crop.isNotEmpty ? crop : (query['crop'] ?? query['title'] ?? 'Crop');
    final problemId = int.tryParse(id);

    if (problemId != null) {
      // Direct problem detail
      final problem = CropProblem(
        id: problemId,
        name: query['title'] ?? 'Crop Advisory',
        category: query['desc'],
        imageUrl1: query['img'],
      );
      nav.push(MaterialPageRoute(builder: (_) => AdvisoryDetailScreen(problem: problem, cropName: cropName)));
      return;
    }

    // Otherwise open Crop Problems list for that crop
    nav.push(
      MaterialPageRoute(
        builder: (_) => CropProblemsScreen(
          cropId: 1,
          cropName: cropName,
        ),
      ),
    );
  }

  static Future<void> _handleNewsRoute(NavigatorState nav, String id) async {
    final articleId = int.tryParse(id);
    if (articleId != null) {
      try {
        final article = await NewsService.getArticleDetail(articleId);
        if (article != null) {
          nav.push(MaterialPageRoute(builder: (_) => NewsDetailScreen(article: article)));
          return;
        }
      } catch (e) {
        debugPrint('Error resolving news article deep link: $e');
      }
    }
    // Fallback to news feed
    nav.push(MaterialPageRoute(builder: (_) => const NewsFeedScreen()));
  }

  static void dispose() {
    _linkSubscription?.cancel();
    _isInitialized = false;
  }
}
