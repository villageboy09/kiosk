import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cropsync/models/creator_studio_model.dart';
import 'package:cropsync/models/reel_model.dart';

import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/auth_service.dart';

class CreatorActionResult {
  final bool success;
  final String? message;
  final String? error;
  final dynamic data;

  const CreatorActionResult({
    required this.success,
    this.message,
    this.error,
    this.data,
  });
}

class CreatorService {
  static const String _studioCacheKey = 'cropsync_creator_studio_cache_v1';
  static String get _apiEndpoint => '${ApiService.baseUrl}/api.php';
  static String get _reelsEndpoint => '${ApiService.baseUrl}/reels.php';

  static Future<Map<String, String>> _getUserDetails() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        final phone = (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
            ? user.phoneNumber!
            : user.userId;
        final name = user.name.isNotEmpty ? user.name : 'Agri Creator';
        return {'phone': phone, 'name': name, 'userId': user.userId};
      }
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('user_phone') ??
          prefs.getString('phone_number') ??
          prefs.getString('phoneNumber') ??
          '';
      final name = prefs.getString('user_name') ??
          prefs.getString('username') ??
          prefs.getString('farmer_name') ??
          'Agri Creator';
      final userId = prefs.getString('user_id') ??
          prefs.getString('userId') ??
          '';
      return {'phone': phone, 'name': name, 'userId': userId};
    } catch (_) {
      return {'phone': '', 'name': 'Agri Creator', 'userId': ''};
    }
  }

  /// Fetch creator studio dashboard data (KPIs, reels, articles, trends) in real time
  static Future<CreatorStudioData> getStudioData({bool forceRefresh = false}) async {
    final user = await _getUserDetails();

    final queryParams = {
      'action': 'get_creator_studio_data',
      if (user['phone']!.isNotEmpty) 'phone_number': user['phone']!,
      if (user['name']!.isNotEmpty) 'user_name': user['name']!,
      if (user['name']!.isNotEmpty) 'username': user['name']!,
      if (user['userId']!.isNotEmpty) 'user_id': user['userId']!,
    };

    final url = Uri.parse(_apiEndpoint).replace(queryParameters: queryParams);

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          final studioData = CreatorStudioData.fromJson(decoded);
          await _cacheStudioData(decoded);
          return studioData;
        }
      }
    } catch (e) {
      debugPrint('CreatorService: getStudioData api.php failed ($e), trying fallback');
    }

    // Try reels.php as secondary
    try {
      final secondaryUrl = Uri.parse(_reelsEndpoint).replace(queryParameters: {
        'action': 'studio',
        if (user['phone']!.isNotEmpty) 'phone_number': user['phone']!,
        if (user['name']!.isNotEmpty) 'user_name': user['name']!,
        if (user['name']!.isNotEmpty) 'username': user['name']!,
        if (user['userId']!.isNotEmpty) 'user_id': user['userId']!,
      });
      final response = await http.get(secondaryUrl).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          final studioData = CreatorStudioData.fromJson(decoded);
          await _cacheStudioData(decoded);
          return studioData;
        }
      }
    } catch (e) {
      debugPrint('CreatorService: secondary studio failed: $e');
    }

    final cached = await _getCachedStudioData();
    if (cached != null) return cached;

    return _getDefaultStudioData(user['name'] ?? 'Agri Creator', user['phone'] ?? '');
  }

  /// Upload and publish a new Reel with rich result
  static Future<CreatorActionResult> uploadReelDetailed({
    required String videoUrl,
    required String caption,
    File? videoFile,
    String musicTitle = 'Original Audio',
    String? phoneNumber,
    String? tags,
    int? creatorId,
  }) async {
    final user = await _getUserDetails();
    final phone = (phoneNumber != null && phoneNumber.isNotEmpty) ? phoneNumber : (user['phone'] ?? '');
    final creatorName = user['name'] ?? 'Agri Creator';

    final payload = {
      'action': 'upload_reel',
      'video_url': videoUrl,
      'caption': caption,
      'music_title': musicTitle,
      'phone_number': phone,
      'creator_name': creatorName,
      'tags': tags ?? '',
      if (creatorId != null && creatorId > 0) 'creator_id': creatorId,
    };

    // If local videoFile is provided and exists, perform multipart upload
    if (videoFile != null && videoFile.existsSync()) {
      try {
        final uri = Uri.parse('$_apiEndpoint?action=upload_reel');
        final request = http.MultipartRequest('POST', uri);
        request.fields['action'] = 'upload_reel';
        request.fields['video_url'] = videoUrl;
        request.fields['caption'] = caption;
        request.fields['music_title'] = musicTitle;
        request.fields['phone_number'] = phone;
        request.fields['creator_name'] = creatorName;
        request.fields['tags'] = tags ?? '';
        if (creatorId != null && creatorId > 0) {
          request.fields['creator_id'] = creatorId.toString();
        }

        final fileName = videoFile.path.split(Platform.pathSeparator).last;
        request.files.add(await http.MultipartFile.fromPath(
          'video_file',
          videoFile.path,
          filename: fileName,
        ));

        final streamedResponse = await request.send().timeout(const Duration(seconds: 40));
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200 || response.statusCode == 201) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map<String, dynamic> && decoded['success'] == true) {
            await _clearReelsCache();
            return CreatorActionResult(
              success: true,
              message: decoded['message']?.toString() ?? 'Reel published successfully',
              data: decoded,
            );
          }
        }
      } catch (e) {
        debugPrint('CreatorService: multipart upload failed ($e), attempting JSON fallback');
      }
    }

    // 1. Primary endpoint: api.php?action=upload_reel
    try {
      final primaryUrl = Uri.parse('$_apiEndpoint?action=upload_reel');
      final response = await http
          .post(
            primaryUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          if (decoded['success'] == true) {
            await _clearReelsCache();
            return CreatorActionResult(
              success: true,
              message: decoded['message']?.toString() ?? 'Reel published successfully',
              data: decoded,
            );
          } else if (decoded['error'] != null) {
            return CreatorActionResult(
              success: false,
              error: decoded['error'].toString(),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('CreatorService: uploadReel primary failed: $e');
    }

    // 2. Secondary endpoint: reels.php?action=upload
    try {
      final secondaryUrl = Uri.parse('$_reelsEndpoint?action=upload');
      final response = await http
          .post(
            secondaryUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              ...payload,
              'action': 'upload',
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          if (decoded['success'] == true) {
            await _clearReelsCache();
            return CreatorActionResult(
              success: true,
              message: decoded['message']?.toString() ?? 'Reel published successfully',
              data: decoded,
            );
          } else if (decoded['error'] != null) {
            return CreatorActionResult(
              success: false,
              error: decoded['error'].toString(),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('CreatorService: uploadReel secondary failed: $e');
    }

    return const CreatorActionResult(
      success: false,
      error: 'Failed to publish reel. Please check your connection and try again.',
    );
  }

  static Future<void> _clearReelsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_studioCacheKey);
      await prefs.remove('cropsync_cached_reels_v1');
    } catch (_) {}
  }

  /// Upload and publish a new Reel (backward-compatible bool signature)
  static Future<bool> uploadReel({
    required String videoUrl,
    required String caption,
    File? videoFile,
    String musicTitle = 'Original Audio',
    String? phoneNumber,
    String? tags,
    int? creatorId,
  }) async {
    final result = await uploadReelDetailed(
      videoUrl: videoUrl,
      videoFile: videoFile,
      caption: caption,
      musicTitle: musicTitle,
      phoneNumber: phoneNumber,
      tags: tags,
      creatorId: creatorId,
    );
    return result.success;
  }

  /// Delete a Reel
  static Future<bool> deleteReel(int reelId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_apiEndpoint?action=delete_reel'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'action': 'delete_reel', 'reel_id': reelId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded['success'] == true) return true;
      }
    } catch (e) {
      debugPrint('CreatorService: deleteReel api.php failed: $e');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_reelsEndpoint?action=delete_reel'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'action': 'delete_reel', 'reel_id': reelId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded['success'] == true;
      }
    } catch (e) {
      debugPrint('CreatorService: deleteReel reels.php fallback failed: $e');
    }
    return false;
  }

  /// Toggle Reel Active Status
  static Future<bool> toggleReelStatus(int reelId, bool isActive) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_apiEndpoint?action=toggle_reel_status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'toggle_reel_status',
              'reel_id': reelId,
              'is_active': isActive ? 1 : 0,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded['success'] == true;
      }
    } catch (e) {
      debugPrint('CreatorService: toggleReelStatus failed: $e');
    }
    return false;
  }

  /// Create and publish a news article with rich result
  static Future<CreatorActionResult> createNewsArticleDetailed({
    required String title,
    required String summary,
    required String content,
    required String category,
    String? imageUrl,
    File? imageFile,
    String? author,
    String? sourceName,
    bool isFeatured = false,
    String status = 'published',
  }) async {
    final user = await _getUserDetails();
    final authorName = (author != null && author.isNotEmpty) ? author : (user['name'] ?? 'CropSync Agri Desk');
    final sName = (sourceName != null && sourceName.isNotEmpty) ? sourceName : 'CropSync Desk';
    final phone = user['phone'] ?? '';

    // If local image file provided, upload via MultipartRequest
    if (imageFile != null && await imageFile.exists()) {
      try {
        final uri = Uri.parse('$_apiEndpoint?action=create_news_article');
        final request = http.MultipartRequest('POST', uri);

        request.fields['action'] = 'create_news_article';
        request.fields['title'] = title;
        request.fields['summary'] = summary;
        request.fields['content'] = content;
        request.fields['category'] = category;
        request.fields['author'] = authorName;
        request.fields['source_name'] = sName;
        request.fields['is_featured'] = isFeatured ? '1' : '0';
        request.fields['status'] = status;
        request.fields['phone_number'] = phone;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          request.fields['image_url'] = imageUrl;
        }

        final fileName = 'news_${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split(Platform.pathSeparator).last}';
        request.files.add(await http.MultipartFile.fromPath(
          'image_file',
          imageFile.path,
          filename: fileName,
        ));

        final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200 || response.statusCode == 201) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map<String, dynamic> && decoded['success'] == true) {
            return CreatorActionResult(
              success: true,
              message: decoded['message']?.toString() ?? 'Article published successfully',
              data: decoded,
            );
          } else if (decoded is Map && decoded['error'] != null) {
            return CreatorActionResult(
              success: false,
              error: decoded['error'].toString(),
            );
          }
        }
      } catch (e) {
        debugPrint('CreatorService: multipart createNewsArticle failed: $e');
      }
    }

    final payload = {
      'action': 'create_news_article',
      'title': title,
      'summary': summary,
      'content': content,
      'category': category,
      'image_url': imageUrl ?? '',
      'author': authorName,
      'source_name': sName,
      'is_featured': isFeatured ? 1 : 0,
      'status': status,
      'phone_number': phone,
    };

    try {
      final primaryUrl = Uri.parse('$_apiEndpoint?action=create_news_article');
      final response = await http
          .post(
            primaryUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          if (decoded['success'] == true) {
            return CreatorActionResult(
              success: true,
              message: decoded['message']?.toString() ?? 'Article published successfully',
              data: decoded,
            );
          } else if (decoded['error'] != null) {
            return CreatorActionResult(
              success: false,
              error: decoded['error'].toString(),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('CreatorService: createNewsArticle failed: $e');
    }

    return const CreatorActionResult(
      success: false,
      error: 'Failed to publish article. Please check your connection and try again.',
    );
  }

  /// Create and publish a news article (backward-compatible bool signature)
  static Future<bool> createNewsArticle({
    required String title,
    required String summary,
    required String content,
    required String category,
    String? imageUrl,
    File? imageFile,
    String? author,
    String? sourceName,
    bool isFeatured = false,
    String status = 'published',
  }) async {
    final result = await createNewsArticleDetailed(
      title: title,
      summary: summary,
      content: content,
      category: category,
      imageUrl: imageUrl,
      imageFile: imageFile,
      author: author,
      sourceName: sourceName,
      isFeatured: isFeatured,
      status: status,
    );
    return result.success;
  }

  /// Delete a News Article
  static Future<bool> deleteNewsArticle(int articleId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_apiEndpoint?action=delete_news_article'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'action': 'delete_news_article', 'article_id': articleId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded['success'] == true) return true;
      }
    } catch (e) {
      debugPrint('CreatorService: deleteNewsArticle api.php failed: $e');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_reelsEndpoint?action=delete_news_article'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'action': 'delete_news_article', 'article_id': articleId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded['success'] == true;
      }
    } catch (e) {
      debugPrint('CreatorService: deleteNewsArticle reels.php fallback failed: $e');
    }
    return false;
  }

  static Future<bool> deleteArticle(int articleId) => deleteNewsArticle(articleId);

  /// Toggle News Article Status
  static Future<bool> toggleNewsStatus(int articleId, String status) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_apiEndpoint?action=toggle_news_status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'toggle_news_status',
              'article_id': articleId,
              'status': status,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded['success'] == true;
      }
    } catch (e) {
      debugPrint('CreatorService: toggleNewsStatus failed: $e');
    }
    return false;
  }

  static Future<void> _cacheStudioData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_studioCacheKey, jsonEncode(data));
    } catch (_) {}
  }

  static Future<CreatorStudioData?> _getCachedStudioData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_studioCacheKey);
      if (str != null) {
        final decoded = jsonDecode(str);
        if (decoded is Map<String, dynamic>) {
          return CreatorStudioData.fromJson(decoded);
        }
      }
    } catch (_) {}
    return null;
  }

  static CreatorStudioData _getDefaultStudioData(String name, String phone) {
    return CreatorStudioData(
      creator: ReelCreator(
        id: 1,
        username: name.toLowerCase().replaceAll(' ', '_'),
        displayName: name,
        profileImageUrl: '',
        isVerified: false,
        phoneNumber: phone,
        bio: 'Agri Creator on CropSync',
      ),
      stats: const CreatorStats(
        totalViews: 0,
        totalLikes: 0,
        totalComments: 0,
        totalSaves: 0,
        totalCalls: 0,
        totalShares: 0,
        engagementRate: 0.0,
        avgWatchDurationSeconds: 0.0,
        totalReels: 0,
        totalArticles: 0,
      ),
      reels: [],
      articles: [],
      dailyTrends: [],
    );
  }
}
