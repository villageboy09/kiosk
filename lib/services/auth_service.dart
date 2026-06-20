import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cropsync/models/user.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/notification_service.dart';

/// Authentication Service for managing user sessions locally
class AuthService {
  static const String _userKey = 'current_user';
  static const String _isLoggedInKey = 'is_logged_in';

  static User? _currentUser;

  /// Get the current logged-in user
  static User? get currentUser => _currentUser;

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  /// Login with user ID and save session
  static Future<User> login(String userId, {String? role}) async {
    final user = await ApiService.loginWithUserId(userId, role: role);
    await _saveUserSession(user);
    _currentUser = user;
    
    // Subscribe to Firebase notifications
    try {
      await NotificationService.subscribeToDistrictTopic(user);
      await NotificationService.synchronizeCropSubscriptions(user);
    } catch (e) {
      // Don't fail login if FCM subscription fails
    }
    
    return user;
  }

  /// Save user session to SharedPreferences
  static Future<void> _saveUserSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    await prefs.setBool(_isLoggedInKey, true);
  }

  /// Load user session from SharedPreferences
  static Future<User?> loadUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);

    if (userJson != null) {
      final userData = jsonDecode(userJson) as Map<String, dynamic>;
      _currentUser = User.fromJson(userData);
      return _currentUser;
    }
    return null;
  }

  /// Refresh user data from server
  static Future<User?> refreshUserData() async {
    if (_currentUser == null) {
      await loadUserSession();
    }

    if (_currentUser != null) {
      try {
        String? role;
        if (_currentUser!.membershipType == 'Retailer') {
          role = 'retailer';
        } else if (_currentUser!.membershipType == 'Officer') {
          role = 'officer';
        } else {
          role = 'farmer';
        }
        final user = await ApiService.getUserProfile(_currentUser!.userId, role: role);
        await _saveUserSession(user);
        _currentUser = user;
        return user;
      } catch (e) {
        // Return cached user if refresh fails
        return _currentUser;
      }
    }
    return null;
  }

  /// Logout and clear session
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.setBool(_isLoggedInKey, false);
    _currentUser = null;
  }

  /// Get current user, loading from storage if needed
  static Future<User?> getCurrentUser() async {
    if (_currentUser != null) {
      return _currentUser;
    }
    return await loadUserSession();
  }

  /// Update local user data (for profile updates)
  static Future<void> updateLocalUser(User user) async {
    await _saveUserSession(user);
    _currentUser = user;
  }
}
