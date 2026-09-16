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
    String? crop,
    String? category,
    String? language,
    String? sourceUrl,
    String? originalContentDate,
    bool rightsDeclared = true,
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
      if (crop != null && crop.isNotEmpty) 'crop': crop,
      if (category != null && category.isNotEmpty) 'category': category,
      if (language != null && language.isNotEmpty) 'language': language,
      if (sourceUrl != null && sourceUrl.isNotEmpty) 'source_url': sourceUrl,
      if (originalContentDate != null && originalContentDate.isNotEmpty) 'original_content_date': originalContentDate,
      'rights_declared': rightsDeclared ? 1 : 0,
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
        if (crop != null && crop.isNotEmpty) request.fields['crop'] = crop;
        if (category != null && category.isNotEmpty) request.fields['category'] = category;
        if (language != null && language.isNotEmpty) request.fields['language'] = language;
        if (sourceUrl != null && sourceUrl.isNotEmpty) request.fields['source_url'] = sourceUrl;
        if (originalContentDate != null && originalContentDate.isNotEmpty) {
          request.fields['original_content_date'] = originalContentDate;
        }
        request.fields['rights_declared'] = rightsDeclared ? '1' : '0';

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
        if (decoded['success'] == true) {
          await _clearReelsCache();
          return true;
        }
      }
    } catch (e) {
      debugPrint('CreatorService: toggleReelStatus failed: $e');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_reelsEndpoint?action=toggle_reel_status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'toggle_reel_status',
              'reel_id': reelId,
              'is_active': isActive ? 1 : 0,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded['success'] == true) {
          await _clearReelsCache();
          return true;
        }
      }
    } catch (e) {
      debugPrint('CreatorService: toggleReelStatus reels fallback failed: $e');
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

  /// Get Creator Partner Profile
  static Future<Map<String, dynamic>?> getCreatorProfile({int? creatorId, String? phone}) async {
    try {
      final user = await _getUserDetails();
      final p = phone ?? user['phone'] ?? '';
      final url = Uri.parse(_apiEndpoint).replace(queryParameters: {
        'action': 'get_creator_profile',
        if (creatorId != null && creatorId > 0) 'creator_id': creatorId.toString(),
        if (p.isNotEmpty) 'phone': p,
      });
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['creator'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      debugPrint('CreatorService: getCreatorProfile failed: $e');
    }
    return null;
  }

  /// Creator Partner Onboarding
  static Future<CreatorActionResult> onboardCreator({
    required String displayName,
    required String bio,
    required String phone,
    String? email,
    List<String>? agricultureNiches,
    List<String>? languages,
    Map<String, String>? socialHandles,
    String? upiId,
    bool termsAccepted = true,
  }) async {
    try {
      final payload = {
        'action': 'creator_onboard',
        'display_name': displayName,
        'bio': bio,
        'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        if (agricultureNiches != null) 'agriculture_niches': jsonEncode(agricultureNiches),
        if (languages != null) 'languages': jsonEncode(languages),
        if (socialHandles != null) 'social_handles': jsonEncode(socialHandles),
        if (upiId != null && upiId.isNotEmpty) 'upi_id': upiId,
        'terms_accepted': termsAccepted ? 1 : 0,
      };
      final res = await http.post(
        Uri.parse('$_apiEndpoint?action=creator_onboard'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200 && decoded['success'] == true) {
        return CreatorActionResult(
          success: true,
          message: decoded['message']?.toString() ?? 'Onboarding application submitted!',
          data: decoded,
        );
      } else {
        return CreatorActionResult(
          success: false,
          error: decoded['error']?.toString() ?? 'Failed to submit application',
        );
      }
    } catch (e) {
      return CreatorActionResult(success: false, error: 'Network error: $e');
    }
  }

  /// Submit Creator Terms Acceptance
  static Future<bool> submitCreatorTerms({
    required int creatorId,
    String termsVersion = 'v1.0',
    String? rightsDeclaration,
  }) async {
    try {
      final payload = {
        'action': 'submit_creator_terms',
        'creator_id': creatorId,
        'terms_version': termsVersion,
        if (rightsDeclaration != null) 'rights_declaration': rightsDeclaration,
      };
      final res = await http.post(
        Uri.parse('$_apiEndpoint?action=submit_creator_terms'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      return decoded['success'] == true;
    } catch (e) {
      debugPrint('CreatorService: submitCreatorTerms failed: $e');
      return false;
    }
  }

  /// Get Creator Monthly Payouts
  static Future<List<Map<String, dynamic>>> getCreatorPayouts({required int creatorId}) async {
    try {
      final url = Uri.parse(_apiEndpoint).replace(queryParameters: {
        'action': 'get_creator_payouts',
        'creator_id': creatorId.toString(),
      });
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded['success'] == true && decoded['payouts'] is List) {
          return List<Map<String, dynamic>>.from(decoded['payouts']);
        }
      }
    } catch (e) {
      debugPrint('CreatorService: getCreatorPayouts failed: $e');
    }
    return [];
  }

  /// Get Creator Campaigns & Assignments
  static Future<List<Map<String, dynamic>>> getCreatorCampaigns({required int creatorId}) async {
    try {
      final url = Uri.parse(_apiEndpoint).replace(queryParameters: {
        'action': 'get_creator_campaigns',
        'creator_id': creatorId.toString(),
      });
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded['success'] == true && decoded['campaigns'] is List) {
          return List<Map<String, dynamic>>.from(decoded['campaigns']);
        }
      }
    } catch (e) {
      debugPrint('CreatorService: getCreatorCampaigns failed: $e');
    }
    return [];
  }

  /// Submit Campaign Deliverable Proof
  static Future<CreatorActionResult> submitCampaignDeliverable({
    required int deliverableId,
    required String proofUrl,
    String? notes,
  }) async {
    try {
      final payload = {
        'action': 'submit_campaign_deliverable',
        'deliverable_id': deliverableId,
        'proof_url': proofUrl,
        if (notes != null) 'notes': notes,
      };
      final res = await http.post(
        Uri.parse('$_apiEndpoint?action=submit_campaign_deliverable'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded['success'] == true) {
        return CreatorActionResult(
          success: true,
          message: decoded['message']?.toString() ?? 'Deliverable submitted for review',
        );
      }
      return CreatorActionResult(success: false, error: decoded['error']?.toString() ?? 'Failed to submit deliverable');
    } catch (e) {
      return CreatorActionResult(success: false, error: 'Network error: $e');
    }
  }

  /// Resubmit a Reel after edits / changes requested
  static Future<CreatorActionResult> resubmitReel({
    required int reelId,
    String? caption,
    String? crop,
    String? category,
    String? language,
    String? sourceUrl,
  }) async {
    try {
      final payload = {
        'action': 'resubmit_reel',
        'reel_id': reelId,
        if (caption != null) 'caption': caption,
        if (crop != null) 'crop': crop,
        if (category != null) 'category': category,
        if (language != null) 'language': language,
        if (sourceUrl != null) 'source_url': sourceUrl,
      };
      final res = await http.post(
        Uri.parse('$_apiEndpoint?action=resubmit_reel'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded['success'] == true) {
        await _clearReelsCache();
        return CreatorActionResult(
          success: true,
          message: decoded['message']?.toString() ?? 'Reel resubmitted for review',
        );
      }
      return CreatorActionResult(success: false, error: decoded['error']?.toString() ?? 'Failed to resubmit reel');
    } catch (e) {
      return CreatorActionResult(success: false, error: 'Network error: $e');
    }
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
        totalViews: 12450,
        totalLikes: 820,
        totalComments: 95,
        totalSaves: 240,
        totalCalls: 35,
        totalShares: 48,
        engagementRate: 9.8,
        avgWatchDurationSeconds: 22.5,
        totalReels: 3,
        totalArticles: 2,
      ),
      reels: [],
      articles: [],
      dailyTrends: const [
        DailyTrendItem(day: 'Mon', views: 1200, likes: 80),
        DailyTrendItem(day: 'Tue', views: 1800, likes: 110),
        DailyTrendItem(day: 'Wed', views: 1500, likes: 95),
        DailyTrendItem(day: 'Thu', views: 2100, likes: 140),
        DailyTrendItem(day: 'Fri', views: 1900, likes: 125),
        DailyTrendItem(day: 'Sat', views: 2400, likes: 160),
        DailyTrendItem(day: 'Sun', views: 1550, likes: 110),
      ],
    );
  }
}
