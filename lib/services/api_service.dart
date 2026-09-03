// ignore_for_file: avoid_print

import 'dart:convert';

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cropsync/models/user.dart';
import 'package:cropsync/models/chc_operator.dart';
import 'package:cropsync/services/cache_service.dart';

/// API Service class for handling all HTTP requests to the MySQL backend
class ApiService {
  static const String baseUrl = 'https://kiosk.cropsync.in/api';

  /// Update user profile details and profile picture
  static Future<User> updateUserProfile({
    required String userId,
    String? name,
    String? phoneNumber,
    String? district,
    String? region,
    File? profileImageFile,
    String? profileImageUrl,
  }) async {
    final url = Uri.parse('$baseUrl/api.php?action=update_user_profile');

    if (profileImageFile != null) {
      final request = http.MultipartRequest('POST', url);
      request.fields['action'] = 'update_user_profile';
      request.fields['user_id'] = userId;
      if (name != null) request.fields['name'] = name;
      if (phoneNumber != null) request.fields['phone_number'] = phoneNumber;
      if (district != null) request.fields['district'] = district;
      if (region != null) request.fields['region'] = region;

      request.files.add(
        await http.MultipartFile.fromPath('profile_image', profileImageFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        final userData = data['user'] as Map<String, dynamic>;
        return User.fromJson(userData);
      } else {
        throw Exception(data['message'] ?? data['error'] ?? 'Failed to update profile');
      }
    } else {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'update_user_profile',
          'user_id': userId,
          if (name != null) 'name': name,
          if (phoneNumber != null) 'phone_number': phoneNumber,
          if (district != null) 'district': district,
          if (region != null) 'region': region,
          if (profileImageUrl != null) 'profile_image_url': profileImageUrl,
        }),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        final userData = data['user'] as Map<String, dynamic>;
        return User.fromJson(userData);
      } else {
        throw Exception(data['message'] ?? data['error'] ?? 'Failed to update profile');
      }
    }
  }

  /// Login with user ID (6-digit PIN)
  /// Login with user ID / Phone number
  /// Returns a User object on success, throws an exception on failure
  static Future<User> loginWithUserId(String userId, {String? role}) async {
    final cleanPhone = userId.trim().replaceAll(RegExp(r'\D'), '');
    final phone = cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
    final url = Uri.parse('$baseUrl/api.php?action=login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': phone,
          'phone_number': phone,
          if (role != null) 'role': role,
        }),
      ).timeout(const Duration(seconds: 15));

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        final userData = data['user'] as Map<String, dynamic>;
        return User.fromJson(userData);
      } else {
        throw Exception(
            data['message'] ?? 'Login failed. Please check your details.');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Please check your internet connection.');
    }
  }

  /// Get user profile by user ID
  static Future<User> getUserProfile(String userId, {String? role}) async {
    final url = Uri.parse('$baseUrl/api.php?action=get_user_profile');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          if (role != null) 'role': role,
        }),
      );

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        final userData = data['user'] as Map<String, dynamic>;
        return User.fromJson(userData);
      } else {
        throw Exception(data['message'] ??
            'Could not load your profile. Please try again.');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception(
          'Unable to connect to server. Please check your internet connection.');
    }
  }

  // ===================== OTP & REGISTRATION FUNCTIONS =====================

  /// Send OTP using MSG91
  static Future<Map<String, dynamic>> sendOtp(String phoneNumber) async {
    final url = Uri.parse('$baseUrl/api.php?action=send_otp');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': phoneNumber}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {
        'success': false,
        'error': 'Server error: ${response.statusCode}'
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Verify OTP using MSG91
  static Future<Map<String, dynamic>> verifyOtp(
      String phoneNumber, String otp) async {
    final url = Uri.parse('$baseUrl/api.php?action=verify_otp');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_number': phoneNumber,
          'otp': otp,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {
        'success': false,
        'error': 'Server error: ${response.statusCode}'
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Register a new user
  static Future<Map<String, dynamic>> registerUser(
      String name, String phoneNumber, String clientCode, {
        String? role,
        String? password,
        String? securityQuestion,
        String? securityAnswer,
        String? username,
        String? email,
      }) async {
    final cleanPhone = phoneNumber.trim().replaceAll(RegExp(r'\D'), '');
    final phone = cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
    final url = Uri.parse('$baseUrl/api.php?action=register_user');

    try {
      final body = {
        'name': name,
        'user_id': phone,
        'phone_number': phone,
        'client_code': clientCode,
      };
      if (role != null) {
        body['role'] = role;
      }
      if (password != null) {
        body['password'] = password;
      }
      if (securityQuestion != null) {
        body['security_question'] = securityQuestion;
      }
      if (securityAnswer != null) {
        body['security_answer'] = securityAnswer;
      }
      if (username != null) {
        body['username'] = username;
      }
      if (email != null) {
        body['email'] = email;
      }
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {
        'success': false,
        'error': 'Server error: ${response.statusCode}'
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Check if a user exists by phone number.
  /// Returns user data if found, null otherwise.
  static Future<Map<String, dynamic>?> checkUser(String phoneNumber, {String? role}) async {
    try {
      final cleanPhone = phoneNumber.trim().replaceAll(RegExp(r'\D'), '');
      final phone = cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
      String url = '$baseUrl/api.php?action=check_user&phone_number=$phone';
      if (role != null) {
        url += '&role=$role';
      }
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['exists'] == true) {
          return data['user'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ===================== CROP FUNCTIONS =====================

  /// Get all crops
  static Future<List<Map<String, dynamic>>> getCrops(
      {String lang = 'te'}) async {
    final cacheKey = '${CacheKeys.crops}_$lang';

    return CacheService.getOrFetch(
      cacheKey,
      () async {
        try {
          final response = await http.get(
            Uri.parse('$baseUrl/api.php?action=get_crops&lang=$lang'),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            if (data['success'] == true) {
              return List<Map<String, dynamic>>.from(data['crops']);
            }
          }
          return [];
        } catch (e) {
          return [];
        }
      },
    );
  }

  /// Get varieties for a crop
  static Future<List<Map<String, dynamic>>> getVarieties(int cropId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api.php?action=get_varieties&crop_id=$cropId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['varieties']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ===================== USER CROP SELECTIONS =====================

  /// Get user's crop selections
  static Future<List<Map<String, dynamic>>> getUserSelections(String userId,
      {String lang = 'te', bool forceRefresh = false}) async {
    final cacheKey = '${CacheKeys.userSelections}_${userId}_$lang';
    if (forceRefresh) {
      CacheService.invalidate(cacheKey);
    }
    return CacheService.getOrFetch(cacheKey, () async {
      try {
        final response = await http.get(
          Uri.parse(
              '$baseUrl/api.php?action=get_user_selections&user_id=$userId&lang=$lang'),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data['success'] == true) {
            return List<Map<String, dynamic>>.from(data['selections']);
          }
        }
        return <Map<String, dynamic>>[];
      } catch (e) {
        return <Map<String, dynamic>>[];
      }
    });
  }

  /// Get used field names for a user
  static Future<Set<String>> getUsedFieldNames(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api.php?action=get_used_fields&user_id=$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          return Set<String>.from(data['used_fields']);
        }
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// Save a new crop selection
  static Future<Map<String, dynamic>> saveSelection({
    required String userId,
    required int cropId,
    int? varietyId,
    required String sowingDate,
    required String fieldName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api.php?action=save_selection'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'crop_id': cropId,
          'variety_id': varietyId,
          'sowing_date': sowingDate,
          'field_name': fieldName,
        }),
      );

      if (response.statusCode == 200) {
        CacheService.invalidatePrefix(CacheKeys.userSelections);
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'error': 'Server error'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Update an existing crop selection
  static Future<Map<String, dynamic>> updateSelection({
    required int id,
    required int cropId,
    int? varietyId,
    required String sowingDate,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api.php?action=update_selection'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': id,
          'crop_id': cropId,
          'variety_id': varietyId,
          'sowing_date': sowingDate,
        }),
      );

      if (response.statusCode == 200) {
        CacheService.invalidatePrefix(CacheKeys.userSelections);
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'error': 'Server error'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Delete a crop selection
  static Future<Map<String, dynamic>> deleteSelection(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api.php?action=delete_selection&id=$id'),
      );

      if (response.statusCode == 200) {
        CacheService.invalidatePrefix(CacheKeys.userSelections);
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'error': 'Server error'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ===================== ADVISORY FUNCTIONS =====================

  /// Get crop stages
  static Future<List<Map<String, dynamic>>> getCropStages(int cropId,
      {String lang = 'te'}) async {
    final cacheKey = '${CacheKeys.cropStages}_${cropId}_$lang';
    return CacheService.getOrFetch(cacheKey, () async {
      try {
        final response = await http.get(
          Uri.parse(
              '$baseUrl/api.php?action=get_crop_stages&crop_id=$cropId&lang=$lang'),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data['success'] == true) {
            return List<Map<String, dynamic>>.from(data['stages']);
          }
        }
        return <Map<String, dynamic>>[];
      } catch (e) {
        return <Map<String, dynamic>>[];
      }
    });
  }

  /// Get stage durations
  static Future<List<Map<String, dynamic>>> getStageDuration(int cropId,
      {int? varietyId}) async {
    final cacheKey = 'stage_duration_${cropId}_${varietyId ?? 'all'}';
    return CacheService.getOrFetch(cacheKey, () async {
      try {
        String url =
            '$baseUrl/api.php?action=get_stage_duration&crop_id=$cropId';
        if (varietyId != null) {
          url += '&variety_id=$varietyId';
        }

        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data['success'] == true) {
            return List<Map<String, dynamic>>.from(data['durations']);
          }
        }
        return <Map<String, dynamic>>[];
      } catch (e) {
        return <Map<String, dynamic>>[];
      }
    });
  }

  /// Get problems for a crop/stage
  static Future<List<Map<String, dynamic>>> getProblems(
      {int? cropId, int? stageId, String lang = 'te'}) async {
    final cacheKey = 'problems_${cropId ?? 'all'}_${stageId ?? 'all'}_$lang';
    return CacheService.getOrFetch(cacheKey, () async {
      try {
        String url = '$baseUrl/api.php?action=get_problems&lang=$lang';
        if (cropId != null) url += '&crop_id=$cropId';
        if (stageId != null) url += '&stage_id=$stageId';

        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data['success'] == true) {
            final problems = List<Map<String, dynamic>>.from(data['problems']);
            return problems;
          }
        }
        return <Map<String, dynamic>>[];
      } catch (e) {
        return <Map<String, dynamic>>[];
      }
    });
  }

  /// Get advisories for a problem
  static Future<Map<String, dynamic>?> getAdvisories(int problemId,
      {String lang = 'te'}) async {
    final cacheKey = 'advisories_${problemId}_$lang';
    return CacheService.getOrFetch(cacheKey, () async {
      try {
        final response = await http.get(
          Uri.parse(
              '$baseUrl/api.php?action=get_advisories&problem_id=$problemId&lang=$lang'),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data['success'] == true) {
            return data['advisory'] as Map<String, dynamic>?;
          }
        }
        return null;
      } catch (e) {
        return null;
      }
    });
  }

  /// Get advisory components/recommendations
  static Future<List<Map<String, dynamic>>> getAdvisoryComponents(
      int advisoryId,
      {String lang = 'te'}) async {
    final cacheKey = 'advisory_components_${advisoryId}_$lang';
    return CacheService.getOrFetch(cacheKey, () async {
      try {
        final response = await http.get(
          Uri.parse(
              '$baseUrl/api.php?action=get_advisory_components&advisory_id=$advisoryId&lang=$lang'),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data['success'] == true) {
            return List<Map<String, dynamic>>.from(data['components']);
          }
        }
        return <Map<String, dynamic>>[];
      } catch (e) {
        return <Map<String, dynamic>>[];
      }
    });
  }

  /// Save an identified problem
  static Future<Map<String, dynamic>> saveIdentifiedProblem({
    required String oderId,
    required int problemId,
    int? selectionId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api.php?action=save_identified_problem'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': oderId,
          'problem_id': problemId,
          'selection_id': selectionId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'error': 'Server error'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ===================== PRODUCT FUNCTIONS =====================

  /// Get products
  static Future<List<Map<String, dynamic>>> getProducts({
    String? category,
    String? search,
    String? sort,
    String? userId,
    String lang = 'en',
  }) async {
    final cacheKey = CacheKeys.withParams(
      '${CacheKeys.products}_$lang',
      {
        'category': category,
        'search': search,
        'sort': sort,
        'user_id': userId,
      },
    );

    return CacheService.getOrFetch(
      cacheKey,
      () async {
        try {
          String url = '$baseUrl/api.php?action=get_products&lang=$lang';
          if (category != null) {
            url += '&category=${Uri.encodeComponent(category)}';
          }
          if (search != null && search.isNotEmpty) {
            url += '&search=${Uri.encodeComponent(search)}';
          }
          if (userId != null) {
            url += '&user_id=${Uri.encodeComponent(userId)}';
          }
          if (sort != null && sort != 'default') url += '&sort=$sort';

          final response = await http.get(Uri.parse(url));

          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            if (data['success'] == true) {
              return List<Map<String, dynamic>>.from(data['products']);
            }
          }
          return [];
        } catch (e) {
          return [];
        }
      },
      duration:
          const Duration(minutes: 5), // Products might update more frequently
    );
  }

  /// Get product categories
  static Future<List<String>> getProductCategories({String lang = 'en'}) async {
    final cacheKey = '${CacheKeys.productCategories}_$lang';

    return CacheService.getOrFetch(
      cacheKey,
      () async {
        try {
          final response = await http.get(
            Uri.parse(
                '$baseUrl/api.php?action=get_product_categories&lang=$lang'),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            if (data['success'] == true) {
              return List<String>.from(data['categories']);
            }
          }
          return [];
        } catch (e) {
          return [];
        }
      },
      duration: const Duration(hours: 1), // Categories rarely change
    );
  }

  /// Save a purchase request
  static Future<Map<String, dynamic>> savePurchaseRequest({
    required String userId,
    required int productId,
    int quantity = 1,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api.php?action=save_purchase_request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'product_id': productId,
          'quantity': quantity,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'error': 'Server error'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> createPurchaseRequest({
    required String userId,
    required int productId,
    required int advertiserId,
    required int quantity,
    required double totalPrice,
    String? message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api.php?action=create_purchase_request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'product_id': productId,
          'advertiser_id': advertiserId,
          'quantity': quantity,
          'total_price': totalPrice,
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'error': 'Server error'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Create a product enquiry
  static Future<Map<String, dynamic>> createEnquiry({
    required int productId,
    required String farmerId,
    required int advertiserId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api.php?action=create_enquiry'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'product_id': productId,
          'farmer_id': farmerId,
          'advertiser_id': advertiserId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'error': 'Server error'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ===================== SEED VARIETIES FUNCTIONS =====================

  /// Get seed varieties
  /// Get seed varieties
  static Future<List<Map<String, dynamic>>> getSeedVarieties(
      {String? cropName, String? userId, String lang = 'te'}) async {
    final cacheKey = CacheKeys.withParams(
      '${CacheKeys.seedVarieties}_$lang',
      {'crop_name': cropName, 'user_id': userId},
    );

    return CacheService.getOrFetch(
      cacheKey,
      () async {
        try {
          String url = '$baseUrl/api.php?action=get_seed_varieties&lang=$lang';
          if (cropName != null) {
            url += '&crop_name=${Uri.encodeComponent(cropName)}';
          }
          if (userId != null) {
            url += '&user_id=${Uri.encodeComponent(userId)}';
          }

          final response = await http.get(Uri.parse(url));

          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            if (data['success'] == true) {
              return List<Map<String, dynamic>>.from(data['varieties']);
            }
          }
          return [];
        } catch (e) {
          return [];
        }
      },
    );
  }

  /// Get crop names for seed varieties filter
  static Future<Map<String, dynamic>> getCropNamesForSeeds({String lang = 'te'}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api.php?action=get_crop_names&lang=$lang'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          return {
            'crop_names': List<String>.from(data['crop_names'] ?? []),
            'crops': List<Map<String, dynamic>>.from(data['crops'] ?? []),
          };
        }
      }
      return {'crop_names': [], 'crops': []};
    } catch (e) {
      return {'crop_names': [], 'crops': []};
    }
  }

  /// Create a seed booking/purchase request
  static Future<Map<String, dynamic>> createSeedBooking({
    required String bookingId,
    required String userId,
    required int seedVarietyId,
    required double quantityKg,
    required double totalPrice,
  }) async {
    const url = '$baseUrl/api.php?action=create_seed_booking';
    final body = jsonEncode({
      'booking_id': bookingId,
      'user_id': userId,
      'seed_variety_id': seedVarietyId,
      'quantity_kg': quantityKg,
      'total_price': totalPrice,
      'booking_status': 'pending',
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {
        'success': false,
        'error': 'Server error: ${response.statusCode}'
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ===================== CHC BOOKING FUNCTIONS =====================

  /// Create a CHC (Custom Hiring Center) booking
  /// Updated to match new database structure with billing_type, unit_type, etc.
  static Future<Map<String, dynamic>> createCHCBooking({
    required String bookingId,
    required String userId,
    required String equipmentType,
    String? cropType,
    required double acres,
    required DateTime serviceDate,
    required double ratePerAcre,
    required double totalCost,
    String billingType = 'Fixed',
    String? unitType,
    double? billedQty,
    String? notes,
    String bookingStatus = 'Confirmed',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api.php?action=create_chc_booking'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'booking_id': bookingId,
          'user_id': userId,
          'equipment_type': equipmentType,
          'billing_type': billingType,
          'crop_type': cropType,
          'land_size_acres': acres,
          'billed_qty': billedQty ?? acres,
          'unit_type': unitType ?? 'Acre',
          'service_date':
              '${serviceDate.year}-${serviceDate.month.toString().padLeft(2, '0')}-${serviceDate.day.toString().padLeft(2, '0')}',
          'rate': ratePerAcre,
          'total_cost': totalCost,
          'notes': notes,
          'booking_status': bookingStatus,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'error': 'Server error'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Get CHC bookings for a user
  static Future<List<Map<String, dynamic>>> getCHCBookings(
      String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api.php?action=get_chc_bookings&user_id=$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['bookings']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get CHC equipment list from database
  /// Only returns Active equipment with quantity > 0
  static Future<List<Map<String, dynamic>>> getCHCEquipments(
      {bool isMember = false, String? clientCode}) async {
    try {
      String url =
          '$baseUrl/api.php?action=get_chc_equipments&is_member=${isMember ? 1 : 0}';
      if (clientCode != null && clientCode.isNotEmpty) {
        url += '&client_code=${Uri.encodeComponent(clientCode)}';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['equipments']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Calculate tractor-trolley pricing using backend slab logic.
  static Future<Map<String, dynamic>> calculateTrolleyPrice({
    required dynamic equipmentId,
    String? clientCode,
    required double distance,
    required bool isMember,
  }) async {
    if (clientCode == null || clientCode.isEmpty) {
      return {
        'success': false,
        'error': 'Client code is required to calculate trolley price',
      };
    }

    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api.php?action=calculate_trolley_price'
          '&equipment_id=$equipmentId'
          '&client_code=${Uri.encodeComponent(clientCode)}'
          '&distance=$distance'
          '&is_member=${isMember ? 1 : 0}',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is Map<String, dynamic>) {
          return data;
        }
      }

      return {
        'success': false,
        'error': 'Failed to calculate trolley price',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Check equipment availability for a specific date
  /// Returns available slots count and whether booking is possible
  static Future<Map<String, dynamic>> checkEquipmentAvailability({
    required String equipmentName,
    required String serviceDate,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api.php?action=check_chc_availability&equipment_name=${Uri.encodeComponent(equipmentName)}&service_date=$serviceDate'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'error': 'Server error'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Get booked dates for an equipment (for calendar highlighting)
  static Future<List<Map<String, dynamic>>> getBookedDates({
    required String equipmentName,
    required int month,
    required int year,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api.php?action=get_booked_dates&equipment_name=${Uri.encodeComponent(equipmentName)}&month=$month&year=$year'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['dates']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ===================== OPERATOR FUNCTIONS =====================

  /// Authenticate a CHC Operator by phone number and password.
  /// Returns a ChcOperator object on success, throws on failure.
  static Future<ChcOperator> operatorLogin(
      String phoneNumber, String password) async {
    final url = Uri.parse('$baseUrl/api.php?action=operator_login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': phoneNumber, 'password': password}),
      );
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return ChcOperator.fromJson(data['operator'] as Map<String, dynamic>);
      } else {
        throw Exception(
            data['message'] ?? 'Login failed. Check your credentials.');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Please check your internet connection.');
    }
  }

  /// Fetches an operator's full profile info from the server by ID.
  static Future<ChcOperator> getOperatorDetails(String operatorId) async {
    final url = Uri.parse(
        '$baseUrl/api.php?action=get_operator_details&operator_id=${Uri.encodeComponent(operatorId.trim())}');
    try {
      final response = await http.get(url);
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return ChcOperator.fromJson(data['operator'] as Map<String, dynamic>);
      } else {
        throw Exception(data['message'] ?? 'Failed to load operator details.');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Please check your internet connection.');
    }
  }

  /// Get all CHC bookings assigned to a specific operator.
  static Future<List<Map<String, dynamic>>> getOperatorBookings(
    String operatorId, {
    List<String>? assignmentStatuses,
  }) async {
    try {
      final trimmedOperatorId = operatorId.trim();
      if (trimmedOperatorId.isEmpty) return [];

      final statuses = (assignmentStatuses ?? [])
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final query = StringBuffer(
          '$baseUrl/api.php?action=get_operator_bookings&operator_id=${Uri.encodeComponent(trimmedOperatorId)}');
      if (statuses.isNotEmpty) {
        query.write(
            '&assignment_statuses=${Uri.encodeComponent(statuses.join(','))}');
      }

      final response = await http.get(
        Uri.parse(query.toString()),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['bookings']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getOperatorAnalytics(String operatorId, {String timeframe = 'month'}) async {
    try {
      final trimmedOperatorId = operatorId.trim();
      if (trimmedOperatorId.isEmpty) return null;

      final url = '$baseUrl/api.php?action=get_operator_analytics&operator_id=${Uri.encodeComponent(trimmedOperatorId)}&timeframe=${Uri.encodeComponent(timeframe)}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          return data['analytics'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Update booking and/or assignment status from operator dashboard.
  static Future<Map<String, dynamic>> updateOperatorBookingStatus({
    required String bookingId,
    String? bookingStatus,
    String? assignmentStatus,
    String? rescheduledDate,
    double? amountPaid,
    String? paymentStatus,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api.php?action=update_operator_booking_status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'booking_id': bookingId,
          'booking_status': bookingStatus,
          'assignment_status': assignmentStatus,
          'rescheduled_date': rescheduledDate,
          'amount_paid': amountPaid,
          'payment_status': paymentStatus,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {
        'success': false,
        'error': 'Server error: ${response.statusCode}'
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Manually complete/log a walk-in booking by an operator.
  static Future<Map<String, dynamic>> completeBookingManual({
    required String operatorId,
    String? bookingId,
    required String farmerPhone,
    required String farmerName,
    required String village,
    required String equipmentUsed,
    required int equipmentId,
    required String startTime,
    required String endTime,
    required double finalAmount,
    double amountPaid = 0,
    String? serviceDate,
    String? cropType,
    double landSizeAcres = 0,
    double billedQty = 0,
    String? unitType,
    double rate = 0,
    String? notes,
    String? operatorNotes,
    double distance = 0,
    String? services,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api.php?action=complete_booking_manual'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'operator_id': operatorId,
          'booking_id': bookingId,
          'farmer_phone': farmerPhone,
          'farmer_name': farmerName,
          'village': village,
          'equipment_used': equipmentUsed,
          'equipment_id': equipmentId,
          'start_time': startTime,
          'end_time': endTime,
          'distance': distance,
          'service_date': serviceDate,
          'crop_type': cropType,
          'land_size_acres': landSizeAcres,
          'billed_qty': billedQty,
          'unit_type': unitType,
          'rate': rate,
          'notes': notes,
          'operator_notes': operatorNotes,
          'final_amount': finalAmount,
          'amount_paid': amountPaid,
          'services': services,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'error': 'Server error'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ===================== ANNOUNCEMENTS FUNCTIONS =====================

  /// Get announcements for home screen
  static Future<List<Map<String, dynamic>>> getAnnouncements(
      {int limit = 5}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api.php?action=get_announcements&limit=$limit'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['announcements']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ===================== MARKET PRICES V2 ENDPOINTS =====================

  /// Get state market prices
  static Future<Map<String, dynamic>> getStateMarketPrices(String state) async {
    final url = Uri.parse(
        '$baseUrl/api.php?action=get_state_market_prices&state=${Uri.encodeComponent(state)}');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true && (decoded['records'] as List?)?.isNotEmpty == true) {
          return decoded;
        }
      }
    } catch (_) {}
    return _getDefaultStateMarketPrices(state);
  }

  /// Get live market prices directly from the upstream market API.
  static Future<Map<String, dynamic>> getLiveStateMarketPrices(
      String state) async {
    final url = Uri.parse(
        '$baseUrl/api.php?action=get_live_state_market_prices&state=${Uri.encodeComponent(state)}');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['success'] == true && (decoded['records'] as List?)?.isNotEmpty == true) {
          return decoded;
        }
      }
    } catch (_) {}
    return getStateMarketPrices(state);
  }

  static Map<String, dynamic> _getDefaultStateMarketPrices(String state) {
    final stateName = state.isNotEmpty ? state : 'Telangana';
    final isAP = stateName.toLowerCase().contains('andhra');
    final now = DateTime.now();
    final today = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final districts = isAP
        ? ['Guntur', 'Kurnool', 'Krishna', 'East Godavari', 'Anantapur']
        : ['Hyderabad', 'Warangal', 'Khammam', 'Karimnagar', 'Nizamabad', 'Suryapet', 'Mahabubnagar'];

    final commodities = [
      {'name': 'Paddy(Dhan)(Common)', 'variety': 'Common', 'min': '2250', 'max': '2360', 'modal': '2300'},
      {'name': 'Cotton', 'variety': 'Medium Staple', 'min': '6900', 'max': '7450', 'modal': '7150'},
      {'name': 'Maize', 'variety': 'Yellow', 'min': '2100', 'max': '2400', 'modal': '2280'},
      {'name': 'Chilli Red', 'variety': 'Teja / Guntur', 'min': '14500', 'max': '18500', 'modal': '16500'},
      {'name': 'Tomato', 'variety': 'Hybrid', 'min': '1800', 'max': '2800', 'modal': '2300'},
      {'name': 'Red Gram (Arhar/Tur)', 'variety': 'Red', 'min': '7200', 'max': '7900', 'modal': '7550'},
      {'name': 'Groundnut', 'variety': 'Pods with Shell', 'min': '5800', 'max': '6700', 'modal': '6350'},
      {'name': 'Soyabean', 'variety': 'Yellow', 'min': '4300', 'max': '4850', 'modal': '4600'},
      {'name': 'Turmeric', 'variety': 'Finger', 'min': '11000', 'max': '14800', 'modal': '13200'},
      {'name': 'Onion', 'variety': 'Red', 'min': '1500', 'max': '2200', 'modal': '1850'},
      {'name': 'Bengal Gram(Gram)(Whole)', 'variety': 'Desi', 'min': '5400', 'max': '6100', 'modal': '5800'},
      {'name': 'Green Gram (Moong)', 'variety': 'Medium', 'min': '7600', 'max': '8400', 'modal': '8100'},
      {'name': 'Potato', 'variety': 'Jyoti', 'min': '1600', 'max': '2100', 'modal': '1900'},
      {'name': 'Banana', 'variety': 'Robusta', 'min': '1200', 'max': '1800', 'modal': '1500'},
    ];

    final records = <Map<String, dynamic>>[];
    for (final d in districts) {
      for (final c in commodities) {
        records.add({
          'state': stateName,
          'district': d,
          'market': '$d Market',
          'commodity': c['name'],
          'variety': c['variety'],
          'grade': 'FAQ',
          'arrival_date': today,
          'min_price': c['min'],
          'max_price': c['max'],
          'modal_price': c['modal'],
        });
      }
    }

    return {
      'success': true,
      'state': stateName,
      'date': today,
      'records': records,
      'source': 'local_cache',
    };
  }

  /// Get commodity trends
  static Future<Map<String, dynamic>> getCommodityTrends(
      String state, String district, String commodity) async {
    final url = Uri.parse(
        '$baseUrl/api.php?action=get_commodity_trends&state=${Uri.encodeComponent(state)}&district=${Uri.encodeComponent(district)}&commodity=${Uri.encodeComponent(commodity)}');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'error': 'Server error'};
    } catch (e) {
      return {'success': false, 'error': 'Network error'};
    }
  }

  // ===================== RETAILER AND EXTENSION OFFICER MODULES =====================

  static Future<Map<String, dynamic>?> getRetailerInfo(String phoneNumber) async {
    // Queries info about a retailer by phone/contact number
    final url = Uri.parse('$baseUrl/api.php?action=login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': phoneNumber}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['role'] == 'retailer') {
          return data;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getOfficerInfo(String phoneNumber) async {
    // Queries info about an extension officer by phone/contact number
    final url = Uri.parse('$baseUrl/api.php?action=login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': phoneNumber}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['role'] == 'officer') {
          return data;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> getRetailerDashboard(int retailerId, {String lang = 'te'}) async {
    final url = Uri.parse('$baseUrl/api.php?action=get_retailer_dashboard&retailer_id=$retailerId&lang=$lang');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'error': 'Server error'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<List<Map<String, dynamic>>> getRetailerLeads(int retailerId, {String lang = 'te'}) async {
    final url = Uri.parse('$baseUrl/api.php?action=get_retailer_leads&retailer_id=$retailerId&lang=$lang');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['leads']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> updateLeadStatus({
    required dynamic leadId,
    required String status,
    String? notes,
  }) async {
    final url = Uri.parse('$baseUrl/api.php?action=update_lead_status');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lead_id': leadId,
          'status': status,
          'notes': notes,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'error': 'Server error'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getExtensionDashboard(int officerId) async {
    final url = Uri.parse('$baseUrl/api.php?action=get_extension_dashboard&officer_id=$officerId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'error': 'Server error'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<List<Map<String, dynamic>>> getActiveOutbreaks({
    String? district,
    String? mandal,
  }) async {
    String urlStr = '$baseUrl/api.php?action=get_active_outbreaks';
    if (district != null) urlStr += '&district=${Uri.encodeComponent(district)}';
    if (mandal != null) urlStr += '&mandal=${Uri.encodeComponent(mandal)}';
    
    final url = Uri.parse(urlStr);
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['outbreaks']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

