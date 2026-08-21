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

        if (listData.isNotEmpty) {
          final reels = listData
              .map((item) => item is Map<String, dynamic> ? Reel.fromJson(item) : null)
              .whereType<Reel>()
              .toList();

          // Save to local cache
          _cacheReels(jsonEncode(listData));
          return reels;
        }
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

          if (listData.isNotEmpty) {
            final reels = listData
                .map((item) => item is Map<String, dynamic> ? Reel.fromJson(item) : null)
                .whereType<Reel>()
                .toList();
            _cacheReels(jsonEncode(listData));
            return reels;
          }
        }
      } catch (_) {}
    }

    // Try reading cached reels
    final cached = await _getCachedReels();
    if (cached.isNotEmpty) {
      return cached;
    }

    // Final fallback to curated default agricultural reels
    return _getDefaultReels();
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

  static Future<List<Reel>> _getCachedReels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_reelsCacheKey);
      if (data != null && data.isNotEmpty) {
        final decoded = jsonDecode(data);
        if (decoded is List) {
          return decoded
              .map((item) => item is Map<String, dynamic> ? Reel.fromJson(item) : null)
              .whereType<Reel>()
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Default production fallback agricultural reels
  static List<Reel> _getDefaultReels() {
    return [
      Reel(
        id: 1,
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
        creator: const ReelCreator(
          id: 1,
          username: 'ramesh_kalyan',
          displayName: 'Dr. Ramesh Kalyan',
          profileImageUrl: 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=200&q=80',
          phoneNumber: '+919876543210',
          bio: 'Senior Agronomist & Organic Paddy Cultivation Specialist',
        ),
        caption: 'Harvesting organic rice using modern combined harvester machinery. Crop yield is exceptional this season! 🌾 #organicfarming #riceharvest #agritech',
        musicTitle: 'Original Audio - Dr. Ramesh Kalyan',
        phoneNumber: '+919876543210',
        tags: 'organic,rice,harvest,machinery',
        likes: '1.2K',
        likesRaw: 1250,
        saves: '320',
        savesRaw: 320,
        commentsCount: 4,
        viewsCount: 12400,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        comments: [
          ReelComment(
            id: 1,
            reelId: 1,
            farmerUsername: 'kalyan_farmer',
            commentText: 'Super helpful video! Where did you purchase this harvester?',
            createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          ),
          ReelComment(
            id: 2,
            reelId: 1,
            farmerUsername: 'venkat_reddy',
            commentText: 'Yield looks amazing sir. What was the fertilizer schedule?',
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
          ReelComment(
            id: 3,
            reelId: 1,
            farmerUsername: 'nagaraju_agri',
            commentText: 'Very clean harvest, zero grain damage 👍',
            createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          ),
          ReelComment(
            id: 4,
            reelId: 1,
            farmerUsername: 'sita_ram',
            commentText: 'Great work brother 🌾',
            createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
          ),
        ],
      ),
      Reel(
        id: 2,
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
        creator: const ReelCreator(
          id: 2,
          username: 'agri_tech_india',
          displayName: 'AgriTech India',
          profileImageUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=200&q=80',
          phoneNumber: '+919876543211',
          bio: 'Precision Agriculture, Smart Drip Irrigation & IoT Sensors',
        ),
        caption: 'Drip irrigation system setup in my tomato field. Highly water-efficient and boosts flowering! 🍅💧 #savewater #irrigation #tomatofarming',
        musicTitle: 'Nature Sounds - Water Flow',
        phoneNumber: '+919876543211',
        tags: 'drip,irrigation,tomato,water',
        likes: '890',
        likesRaw: 890,
        saves: '210',
        savesRaw: 210,
        commentsCount: 3,
        viewsCount: 8900,
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        comments: [
          ReelComment(
            id: 5,
            reelId: 2,
            farmerUsername: 'anand_kumar',
            commentText: 'What is the cost per acre for this drip setup?',
            createdAt: DateTime.now().subtract(const Duration(hours: 10)),
          ),
          ReelComment(
            id: 6,
            reelId: 2,
            farmerUsername: 'balaji_raju',
            commentText: 'Does govt subsidy cover this model?',
            createdAt: DateTime.now().subtract(const Duration(hours: 8)),
          ),
          ReelComment(
            id: 7,
            reelId: 2,
            farmerUsername: 'mahesh_k',
            commentText: 'Works great in summer especially 🍅',
            createdAt: DateTime.now().subtract(const Duration(hours: 4)),
          ),
        ],
      ),
      Reel(
        id: 3,
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
        creator: const ReelCreator(
          id: 3,
          username: 'suresh_village_boy',
          displayName: 'Suresh Kumar',
          profileImageUrl: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?auto=format&fit=crop&w=200&q=80',
          phoneNumber: '+919876543212',
          bio: 'Natural Farming Practitioner & Bio-Pesticide Educator',
        ),
        caption: 'Best organic pest control spray demo using neem oil & soap solution. Safe and chemical-free! 🌱🐛 #organicpestcontrol #sustainableagri',
        musicTitle: 'Original Audio - Suresh Kumar',
        phoneNumber: '+919876543212',
        tags: 'neem,pestcontrol,organic,safe',
        likes: '2.1K',
        likesRaw: 2100,
        saves: '580',
        savesRaw: 580,
        commentsCount: 3,
        viewsCount: 21500,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        comments: [
          ReelComment(
            id: 8,
            reelId: 3,
            farmerUsername: 'prasad_rao',
            commentText: 'What is the exact ratio of neem oil to water?',
            createdAt: DateTime.now().subtract(const Duration(hours: 18)),
          ),
          ReelComment(
            id: 9,
            reelId: 3,
            farmerUsername: 'chandra_sekhar',
            commentText: 'Effective against whiteflies too?',
            createdAt: DateTime.now().subtract(const Duration(hours: 14)),
          ),
          ReelComment(
            id: 10,
            reelId: 3,
            farmerUsername: 'ramu_farmer',
            commentText: 'Used this last week, results are great 🌱',
            createdAt: DateTime.now().subtract(const Duration(hours: 8)),
          ),
        ],
      ),
      Reel(
        id: 4,
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
        creator: const ReelCreator(
          id: 4,
          username: 'organic_ananya',
          displayName: 'Ananya Rao',
          profileImageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=200&q=80',
          phoneNumber: '+919876543213',
          bio: 'Vermicompost, Jeevamrutham & Soil Microbe Regeneration',
        ),
        caption: 'Preparing natural compost manure using cow dung, dry leaves, and jaggery solution. Farm prep in full swing! 🚜🍂 #composting #organicfertilizer',
        musicTitle: 'Morning Flute Melody',
        phoneNumber: '+919876543213',
        tags: 'compost,organic,manure,farming',
        likes: '1.5K',
        likesRaw: 1540,
        saves: '410',
        savesRaw: 410,
        commentsCount: 2,
        viewsCount: 15300,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        comments: [
          ReelComment(
            id: 11,
            reelId: 4,
            farmerUsername: 'govind_reddy',
            commentText: 'How many days does it take to fully decompose?',
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
          ReelComment(
            id: 12,
            reelId: 4,
            farmerUsername: 'krishna_murthy',
            commentText: 'Jeevamrutham along with this works wonders.',
            createdAt: DateTime.now().subtract(const Duration(hours: 20)),
          ),
        ],
      ),
    ];
  }
}
