import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cropsync/models/chc_operator.dart';
import 'package:cropsync/services/api_service.dart';

/// Authentication service for CHC Operators — mirrors AuthService but
/// uses a separate SharedPreferences key so farmer & operator sessions
/// are completely isolated.
class OperatorAuthService {
  static const String _operatorKey = 'current_operator';
  static const String _isLoggedInKey = 'operator_is_logged_in';

  static ChcOperator? _currentOperator;

  static ChcOperator? get currentOperator => _currentOperator;

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  /// Login operator with phone + password. Saves session locally.
  static Future<ChcOperator> login(String phone, String password) async {
    final op = await ApiService.operatorLogin(phone, password);
    await _saveSession(op);
    _currentOperator = op;
    return op;
  }

  static Future<void> _saveSession(ChcOperator op) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_operatorKey, jsonEncode(op.toJson()));
    await prefs.setBool(_isLoggedInKey, true);
  }

  static Future<ChcOperator?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_operatorKey);
    if (raw != null) {
      _currentOperator = ChcOperator.fromJson(jsonDecode(raw));
      return _currentOperator;
    }
    return null;
  }

  static Future<ChcOperator?> getCurrentOperator() async {
    if (_currentOperator != null) return _currentOperator;
    return await loadSession();
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_operatorKey);
    await prefs.setBool(_isLoggedInKey, false);
    _currentOperator = null;
  }
}
