import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cropsync/models/user.dart';

/// API Service class for handling all HTTP requests to the MySQL backend
class ApiService {
  static const String baseUrl = 'https://kiosk.cropsync.in/api';

  /// Login with user ID (6-digit PIN)
  /// Returns a User object on success, throws an exception on failure
  static Future<User> loginWithUserId(String userId) async {
    final url = Uri.parse('$baseUrl/login_api.php');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        final userData = data['user'] as Map<String, dynamic>;
        return User.fromJson(userData);
      } else {
        throw Exception(data['message'] ?? 'Login failed');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: Unable to connect to server');
    }
  }

  /// Get user profile by user ID
  static Future<User> getUserProfile(String userId) async {
    final url = Uri.parse('$baseUrl/login_api.php');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        final userData = data['user'] as Map<String, dynamic>;
        return User.fromJson(userData);
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch user profile');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error: Unable to connect to server');
    }
  }

  // ===================== CROP FUNCTIONS =====================

  /// Get all crops
  static Future<List<Map<String, dynamic>>> getCrops(
      {String lang = 'te'}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api.php?action=get_crops&lang=$lang'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['crops']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get varieties for a crop
  static Future<List<Map<String, dynamic>>> getVarieties(int cropId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api.php?action=get_varieties&crop_id=$cropId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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
      {String lang = 'te'}) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api.php?action=get_user_selections&user_id=$userId&lang=$lang'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['selections']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get used field names for a user
  static Future<Set<String>> getUsedFieldNames(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api.php?action=get_used_fields&user_id=$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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
        return jsonDecode(response.body);
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
        return jsonDecode(response.body);
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
        return jsonDecode(response.body);
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
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api.php?action=get_crop_stages&crop_id=$cropId&lang=$lang'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['stages']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get stage durations
  static Future<List<Map<String, dynamic>>> getStageDuration(int cropId,
      {int? varietyId}) async {
    try {
      String url = '$baseUrl/api.php?action=get_stage_duration&crop_id=$cropId';
      if (varietyId != null) {
        url += '&variety_id=$varietyId';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['durations']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get problems for a crop/stage
  static Future<List<Map<String, dynamic>>> getProblems(
      {int? cropId, int? stageId, String lang = 'te'}) async {
    try {
      String url = '$baseUrl/api.php?action=get_problems&lang=$lang';
      if (cropId != null) url += '&crop_id=$cropId';
      if (stageId != null) url += '&stage_id=$stageId';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['problems']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get advisories for a problem
  static Future<Map<String, dynamic>?> getAdvisories(int problemId,
      {String lang = 'te'}) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api.php?action=get_advisories&problem_id=$problemId&lang=$lang'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['advisory'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get advisory components/recommendations
  static Future<List<Map<String, dynamic>>> getAdvisoryComponents(
      int advisoryId,
      {String lang = 'te'}) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api.php?action=get_advisory_components&advisory_id=$advisoryId&lang=$lang'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['components']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
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
        return jsonDecode(response.body);
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
    String lang = 'en',
  }) async {
    try {
      String url = '$baseUrl/api.php?action=get_products&lang=$lang';
      if (category != null) url += '&category=${Uri.encodeComponent(category)}';
      if (search != null && search.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(search)}';
      }
      if (sort != null && sort != 'default') url += '&sort=$sort';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['products']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get product categories
  static Future<List<String>> getProductCategories({String lang = 'en'}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api.php?action=get_product_categories&lang=$lang'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<String>.from(data['categories']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
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
        return jsonDecode(response.body);
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
        return jsonDecode(response.body);
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
        return jsonDecode(response.body);
      }
      return {'success': false, 'error': 'Server error'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // ===================== SEED VARIETIES FUNCTIONS =====================

  /// Get seed varieties
  static Future<List<Map<String, dynamic>>> getSeedVarieties(
      {String? cropName, String lang = 'te'}) async {
    try {
      String url = '$baseUrl/api.php?action=get_seed_varieties&lang=$lang';
      if (cropName != null) {
        url += '&crop_name=${Uri.encodeComponent(cropName)}';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['varieties']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get crop names for seed varieties filter
  static Future<Map<String, dynamic>> getCropNamesForSeeds() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api.php?action=get_crop_names'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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
}
