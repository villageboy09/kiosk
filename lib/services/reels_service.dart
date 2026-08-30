import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cropsync/models/reel_model.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/farmer_analytics_service.dart';

class ReelsService {
  static const String _reelsCacheKey = 'cropsync_cached_reels_v1';
  static const String _userLikesPrefix = 'reel_liked_';
  static const String _userSavesPrefix = 'reel_saved_';

  /// Primary endpoint via ApiService baseUrl
  static String get _apiEndpoint => '${ApiService.baseUrl}/api.php';
  static String get _reelsPhpEndpoint => '${ApiService.baseUrl}/reels.php';

  /// Retrieve active farmer phone number and username
  static Future<Map<String, String>> _getUserDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('user_phone') ??
          prefs.getString('phone_number') ??
          prefs.getString('phoneNumber') ??
          '';
      final username = prefs.getString('user_name') ??
          prefs.getString('username') ??
          prefs.getString('farmer_name') ??
          'farmer';
      final userId = prefs.getString('user_id') ??
          prefs.getString('userId') ??
          '';
      return {'phone': phone, 'username': username, 'userId': userId};
    } catch (_) {
      return {'phone': '', 'username': 'farmer', 'userId': ''};
    }
  }

  /// Fetch all active reels from backend API with offline fallback
  static Future<List<Reel>> getReels({bool forceRefresh = false}) async {
    final user = await _getUserDetails();
    final queryParams = {
      'action': 'get_reels',
      if (user['phone']!.isNotEmpty) 'phone_number': user['phone']!,
      if (user['username']!.isNotEmpty) 'username': user['username']!,
    };

    final url = Uri.parse(_apiEndpoint).replace(queryParameters: queryParams);

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        List<dynamic> listData = [];

        if (decoded is List) {
          listData = decoded;
        } else if (decoded is Map && decoded['reels'] is List) {
          listData = decoded['reels'] as List;
        } else if (decoded is Map && decoded['data'] is List) {
          listData = decoded['data'] as List;
        }

        final reels = listData
            .map((item) => item is Map<String, dynamic> ? Reel.fromJson(item) : null)
            .whereType<Reel>()
            .toList();

        // Save to local cache
        _cacheReels(jsonEncode(listData));
        return reels;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Reels API error (falling back to cache/reels.php): $e');
      }
      // Fallback try reels.php directly
      try {
        final fallbackUrl = Uri.parse(_reelsPhpEndpoint).replace(queryParameters: queryParams);
        final fallbackRes = await http.get(fallbackUrl).timeout(const Duration(seconds: 8));
        if (fallbackRes.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(fallbackRes.bodyBytes));
          List<dynamic> listData = [];
          if (decoded is List) listData = decoded;
          if (decoded is Map && decoded['reels'] is List) listData = decoded['reels'] as List;

          final reels = listData
              .map((item) => item is Map<String, dynamic> ? Reel.fromJson(item) : null)
              .whereType<Reel>()
              .toList();
          _cacheReels(jsonEncode(listData));
          return reels;
        }
      } catch (_) {}
    }

    return [];
  }

  /// Toggle Like/Unlike for a reel
  static Future<Map<String, dynamic>> toggleLike(int reelId) async {
    final user = await _getUserDetails();
    final prefs = await SharedPreferences.getInstance();
    final localLikeKey = '$_userLikesPrefix$reelId';
    final currentlyLiked = prefs.getBool(localLikeKey) ?? false;
    final newLikeState = !currentlyLiked;
    await prefs.setBool(localLikeKey, newLikeState);

    // Track farmer analytics
    await FarmerAnalyticsService.logReelLike(
      reelId: reelId,
      isLiked: newLikeState,
    );

    try {
      final response = await http.post(
        Uri.parse('$_apiEndpoint?action=toggle_reel_like'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'reel_id': reelId,
          'phone_number': user['phone'],
          'farmer_username': user['username'],
          'user_id': user['userId'],
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return {
          'success': true,
          'hasLiked': data['is_liked'] ?? data['hasLiked'] ?? newLikeState,
          'likes': data['likes'] ?? (newLikeState ? '1' : '0'),
          'likesRaw': data['likes_count'] ?? data['likesRaw'] ?? 0,
        };
      }
    } catch (_) {
      // Offline support - optimistic success
    }

    return {
      'success': true,
      'hasLiked': newLikeState,
      'likes': newLikeState ? '1' : '0',
      'likesRaw': newLikeState ? 1 : 0,
    };
  }

  /// Toggle Save/Bookmark for a reel
  static Future<Map<String, dynamic>> toggleSave(int reelId) async {
    final user = await _getUserDetails();
    final prefs = await SharedPreferences.getInstance();
    final localSaveKey = '$_userSavesPrefix$reelId';
    final currentlySaved = prefs.getBool(localSaveKey) ?? false;
    final newSaveState = !currentlySaved;
    await prefs.setBool(localSaveKey, newSaveState);

    // Track farmer analytics
    await FarmerAnalyticsService.logReelSave(
      reelId: reelId,
      isSaved: newSaveState,
    );

    try {
      final response = await http.post(
        Uri.parse('$_apiEndpoint?action=toggle_reel_save'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'reel_id': reelId,
          'phone_number': user['phone'],
          'farmer_username': user['username'],
          'user_id': user['userId'],
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return {
          'success': true,
          'hasSaved': data['is_saved'] ?? data['hasSaved'] ?? newSaveState,
          'saves': data['saves'] ?? (newSaveState ? '1' : '0'),
          'savesRaw': data['saves_count'] ?? data['savesRaw'] ?? 0,
        };
      }
    } catch (_) {
      // Offline fallback
    }

    return {
      'success': true,
      'hasSaved': newSaveState,
      'saves': newSaveState ? '1' : '0',
      'savesRaw': newSaveState ? 1 : 0,
    };
  }

  /// Fetch comments for a reel
  static Future<List<ReelComment>> getComments(int reelId) async {
    final url = Uri.parse('$_apiEndpoint?action=get_reel_comments&reel_id=$reelId');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map && decoded['comments'] is List) {
          return (decoded['comments'] as List)
              .map((c) => c is Map<String, dynamic> ? ReelComment.fromJson(c) : null)
              .whereType<ReelComment>()
              .toList();
        }
      }
    } catch (_) {}

    return [];
  }

  /// Add comment to a reel
  static Future<ReelComment?> addComment(int reelId, String commentText) async {
    if (commentText.trim().isEmpty) return null;
    final user = await _getUserDetails();

    // Track farmer analytics
    await FarmerAnalyticsService.logReelComment(
      reelId: reelId,
      commentLength: commentText.length,
    );

    try {
      final response = await http.post(
        Uri.parse('$_apiEndpoint?action=add_reel_comment'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'reel_id': reelId,
          'farmer_username': user['username'],
          'phone_number': user['phone'],
          'user_id': user['userId'],
          'comment_text': commentText.trim(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is Map && data['comment'] is Map<String, dynamic>) {
          return ReelComment.fromJson(data['comment'] as Map<String, dynamic>);
        }
      }
    } catch (_) {}

    // Offline optimistic comment
    return ReelComment(
      id: DateTime.now().millisecondsSinceEpoch,
      reelId: reelId,
      farmerUsername: user['username']!.isNotEmpty ? user['username']! : 'You (Farmer)',
      phoneNumber: user['phone']!,
      userId: user['userId']!,
      commentText: commentText.trim(),
      createdAt: DateTime.now(),
    );
  }

  /// Log action (Call, Share, WhatsApp)
  static Future<void> logAction(int reelId, String actionType) async {
    final user = await _getUserDetails();

    if (actionType == 'call') {
      await FarmerAnalyticsService.logReelCall(reelId: reelId);
    } else if (actionType == 'share') {
      await FarmerAnalyticsService.logReelShare(reelId: reelId);
    }

    try {
      await http.post(
        Uri.parse('$_apiEndpoint?action=log_reel_action'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'reel_id': reelId,
          'farmer_username': user['username'],
          'phone_number': user['phone'],
          'user_id': user['userId'],
          'action_type': actionType,
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// Log watch duration analytics
  static Future<void> logWatch(int reelId, int durationSeconds, bool isCompleted) async {
    final user = await _getUserDetails();
    await FarmerAnalyticsService.logReelView(
      reelId: reelId,
      watchDurationSeconds: durationSeconds,
      isCompleted: isCompleted,
    );

    try {
      await http.post(
        Uri.parse('$_apiEndpoint?action=log_reel_watch'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'reel_id': reelId,
          'farmer_username': user['username'],
          'phone_number': user['phone'],
          'user_id': user['userId'],
          'duration': durationSeconds,
          'completed': isCompleted ? 1 : 0,
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // --- Cache Helpers ---
  static Future<void> _cacheReels(String jsonString) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_reelsCacheKey, jsonString);
    } catch (_) {}
  }


}
