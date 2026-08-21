import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Service for tracking farmer interactions across Crop Advisory, Agri Shop, and Seed Varieties
class FarmerAnalyticsService {
  static const String _offlineQueueKey = 'farmer_offline_interaction_logs';
  static bool _isFlushing = false;

  /// Log a general interaction event asynchronously without blocking UI
  static void logInteraction({
    required String actionType,
    required String itemType,
    String? itemId,
    String? itemName,
    String? cropName,
    Map<String, dynamic>? metadata,
  }) {
    unawaited(_logInteractionAsync(
      actionType: actionType,
      itemType: itemType,
      itemId: itemId,
      itemName: itemName,
      cropName: cropName,
      metadata: metadata,
    ));
  }

  /// 1. Log Crop Catalog tap
  static void logCropView({
    required int cropId,
    required String cropName,
    String? language,
  }) {
    logInteraction(
      actionType: 'crop_view',
      itemType: 'crop',
      itemId: cropId.toString(),
      itemName: cropName,
      cropName: cropName,
      metadata: {
        if (language != null) 'language': language,
      },
    );
  }

  /// 2. Log Disease / Pest / Deficiency Problem card tap
  static void logProblemView({
    required int problemId,
    required String problemName,
    required String category,
    int? cropId,
    String? cropName,
    String? stageName,
  }) {
    logInteraction(
      actionType: 'problem_view',
      itemType: category.toLowerCase().contains('pest')
          ? 'pest'
          : category.toLowerCase().contains('deficiency')
              ? 'deficiency'
              : 'disease',
      itemId: problemId.toString(),
      itemName: problemName,
      cropName: cropName,
      metadata: {
        'category': category,
        if (cropId != null) 'crop_id': cropId,
        if (stageName != null) 'stage_name': stageName,
      },
    );
  }

  /// 3. Log Control Measures detailed view
  static void logControlMeasureView({
    required int problemId,
    required String problemName,
    int? advisoryId,
    String? cropName,
    String? category,
  }) {
    logInteraction(
      actionType: 'control_measure_view',
      itemType: 'control_measure',
      itemId: problemId.toString(),
      itemName: problemName,
      cropName: cropName,
      metadata: {
        if (advisoryId != null) 'advisory_id': advisoryId,
        if (category != null) 'category': category,
      },
    );
  }

  /// 4. Log Agri Shop product card tap
  static void logShopItemView({
    required int productId,
    required String productName,
    required String category,
    String? price,
    String? advertiserName,
  }) {
    logInteraction(
      actionType: 'shop_item_view',
      itemType: 'product',
      itemId: productId.toString(),
      itemName: productName,
      metadata: {
        'category': category,
        if (price != null) 'price': price,
        if (advertiserName != null) 'advertiser_name': advertiserName,
      },
    );
  }

  /// 5. Log Agri Shop product enquiry / interest click
  static void logShopEnquiry({
    required int productId,
    required String productName,
    required int advertiserId,
    String? advertiserName,
  }) {
    logInteraction(
      actionType: 'enquiry_click',
      itemType: 'product',
      itemId: productId.toString(),
      itemName: productName,
      metadata: {
        'advertiser_id': advertiserId,
        if (advertiserName != null) 'advertiser_name': advertiserName,
      },
    );
  }

  /// 6. Log Seed Variety card tap
  static void logSeedVarietyView({
    required int seedId,
    required String varietyName,
    required String cropName,
    String? price,
    double? averageYield,
  }) {
    logInteraction(
      actionType: 'seed_variety_view',
      itemType: 'seed_variety',
      itemId: seedId.toString(),
      itemName: varietyName,
      cropName: cropName,
      metadata: {
        if (price != null) 'price': price,
        if (averageYield != null) 'average_yield': averageYield,
      },
    );
  }

  /// 7. Log Seed Booking order
  static void logSeedBooking({
    required int seedId,
    required String varietyName,
    required String cropName,
    required num quantity,
  }) {
    logInteraction(
      actionType: 'seed_booking_click',
      itemType: 'seed_variety',
      itemId: seedId.toString(),
      itemName: varietyName,
      cropName: cropName,
      metadata: {
        'quantity': quantity,
      },
    );
  }

  /// 8. Log News Article reading view
  static void logNewsView({
    required int articleId,
    required String title,
    required String category,
  }) {
    logInteraction(
      actionType: 'news_article_view',
      itemType: 'news_article',
      itemId: articleId.toString(),
      itemName: title,
      metadata: {
        'category': category,
      },
    );
  }

  /// 9. Log News Article like toggle
  static void logNewsLike({
    required int articleId,
    required String title,
    required String category,
    required bool isLiked,
  }) {
    logInteraction(
      actionType: isLiked ? 'news_like' : 'news_unlike',
      itemType: 'news_article',
      itemId: articleId.toString(),
      itemName: title,
      metadata: {
        'category': category,
        'is_liked': isLiked,
      },
    );
  }

  /// 10. Log News Article comment post
  static void logNewsComment({
    required int articleId,
    required String title,
    required String category,
    required int commentLength,
  }) {
    logInteraction(
      actionType: 'news_comment_post',
      itemType: 'news_article',
      itemId: articleId.toString(),
      itemName: title,
      metadata: {
        'category': category,
        'comment_length': commentLength,
      },
    );
  }

  /// 11. Log Reel video watch / view
  static Future<void> logReelView({
    required int reelId,
    required int watchDurationSeconds,
    required bool isCompleted,
    String? creatorUsername,
  }) async {
    logInteraction(
      actionType: 'reel_view',
      itemType: 'reel',
      itemId: reelId.toString(),
      itemName: 'Reel #$reelId',
      metadata: {
        'watch_duration_seconds': watchDurationSeconds,
        'is_completed': isCompleted,
        if (creatorUsername != null) 'creator': creatorUsername,
      },
    );
  }

  /// 12. Log Reel like / unlike toggle
  static Future<void> logReelLike({
    required int reelId,
    required bool isLiked,
    String? creatorUsername,
  }) async {
    logInteraction(
      actionType: isLiked ? 'reel_like' : 'reel_unlike',
      itemType: 'reel',
      itemId: reelId.toString(),
      itemName: 'Reel #$reelId',
      metadata: {
        'is_liked': isLiked,
        if (creatorUsername != null) 'creator': creatorUsername,
      },
    );
  }

  /// 13. Log Reel save / bookmark toggle
  static Future<void> logReelSave({
    required int reelId,
    required bool isSaved,
    String? creatorUsername,
  }) async {
    logInteraction(
      actionType: isSaved ? 'reel_save' : 'reel_unsave',
      itemType: 'reel',
      itemId: reelId.toString(),
      itemName: 'Reel #$reelId',
      metadata: {
        'is_saved': isSaved,
        if (creatorUsername != null) 'creator': creatorUsername,
      },
    );
  }

  /// 14. Log Reel comment post
  static Future<void> logReelComment({
    required int reelId,
    required int commentLength,
  }) async {
    logInteraction(
      actionType: 'reel_comment_post',
      itemType: 'reel',
      itemId: reelId.toString(),
      itemName: 'Reel #$reelId',
      metadata: {
        'comment_length': commentLength,
      },
    );
  }

  /// 15. Log Reel social share
  static Future<void> logReelShare({
    required int reelId,
  }) async {
    logInteraction(
      actionType: 'reel_share',
      itemType: 'reel',
      itemId: reelId.toString(),
      itemName: 'Reel #$reelId',
    );
  }

  /// 16. Log Reel call / contact creator click
  static Future<void> logReelCall({
    required int reelId,
    String? phoneNumber,
  }) async {
    logInteraction(
      actionType: 'reel_call_creator',
      itemType: 'reel',
      itemId: reelId.toString(),
      itemName: 'Reel #$reelId',
      metadata: {
        if (phoneNumber != null) 'phone_number': phoneNumber,
      },
    );
  }

  /// Internal async worker
  static Future<void> _logInteractionAsync({
    required String actionType,
    required String itemType,
    String? itemId,
    String? itemName,
    String? cropName,
    Map<String, dynamic>? metadata,
  }) async {
    final user = AuthService.currentUser;
    final logPayload = {
      'user_id': user?.userId,
      'phone_number': user?.phoneNumber,
      'user_role': user?.membershipType?.toLowerCase() ?? 'farmer',
      'action_type': actionType,
      'item_type': itemType,
      'item_id': itemId,
      'item_name': itemName,
      'crop_name': cropName,
      'metadata': metadata,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/api.php?action=log_interaction'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(logPayload),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        // Successfully sent, now flush any pending offline logs
        _flushOfflineQueue();
      } else {
        await _enqueueOfflineLog(logPayload);
      }
    } catch (e) {
      // Network failure or timeout -> save locally in offline queue
      await _enqueueOfflineLog(logPayload);
    }
  }

  /// Enqueue failed log to SharedPreferences
  static Future<void> _enqueueOfflineLog(Map<String, dynamic> log) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> currentQueue =
          prefs.getStringList(_offlineQueueKey) ?? [];

      currentQueue.add(jsonEncode(log));

      // Keep max 150 offline logs to prevent unbounded storage
      if (currentQueue.length > 150) {
        currentQueue.removeRange(0, currentQueue.length - 150);
      }

      await prefs.setStringList(_offlineQueueKey, currentQueue);
    } catch (e) {
      if (kDebugMode) {
        print('Error enqueuing offline farmer interaction log: $e');
      }
    }
  }

  /// Flush offline queue to server in batch
  static Future<void> _flushOfflineQueue() async {
    if (_isFlushing) return;
    _isFlushing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> currentQueue =
          prefs.getStringList(_offlineQueueKey) ?? [];

      if (currentQueue.isEmpty) {
        _isFlushing = false;
        return;
      }

      final List<Map<String, dynamic>> logsToSend = currentQueue
          .map((item) {
            try {
              return jsonDecode(item) as Map<String, dynamic>;
            } catch (_) {
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      if (logsToSend.isEmpty) {
        await prefs.remove(_offlineQueueKey);
        _isFlushing = false;
        return;
      }

      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/api.php?action=log_interaction'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'logs': logsToSend}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        await prefs.remove(_offlineQueueKey);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error flushing offline interaction logs: $e');
      }
    } finally {
      _isFlushing = false;
    }
  }

  /// Public method to trigger flush on app start
  static void initAndFlush() {
    unawaited(_flushOfflineQueue());
  }
}
