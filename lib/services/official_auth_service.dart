import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cropsync/models/chc_official.dart';
import 'package:cropsync/services/api_service.dart';

/// Authentication service for CHC Officials / Department Officers.
/// Handles local session storage, active workspace scoping, and logout.
class OfficialAuthService {
  static const String _officialKey = 'current_chc_official';
  static const String _isLoggedInKey = 'chc_official_is_logged_in';

  static ChcOfficial? _currentOfficial;

  static ChcOfficial? get currentOfficial => _currentOfficial;

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  /// Login official using email and password
  static Future<ChcOfficial> login(String email, String password) async {
    final official = await ApiService.chcOfficialLogin(email, password);
    await _saveSession(official);
    _currentOfficial = official;
    return official;
  }

  static Future<void> _saveSession(ChcOfficial official) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_officialKey, jsonEncode(official.toJson()));
    await prefs.setBool(_isLoggedInKey, true);
  }

  static Future<ChcOfficial?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_officialKey);
    if (raw != null) {
      try {
        _currentOfficial = ChcOfficial.fromJson(jsonDecode(raw));
        return _currentOfficial;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<ChcOfficial?> getCurrentOfficial() async {
    if (_currentOfficial != null) return _currentOfficial;
    return await loadSession();
  }

  /// Change active client code scope (e.g. ALL, SDP001)
  static Future<void> switchClientCode(String newClientCode) async {
    final official = await getCurrentOfficial();
    if (official != null) {
      final updated = official.copyWith(currentClientCode: newClientCode);
      await _saveSession(updated);
      _currentOfficial = updated;
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_officialKey);
    await prefs.setBool(_isLoggedInKey, false);
    _currentOfficial = null;
  }
}
