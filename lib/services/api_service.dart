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
}
