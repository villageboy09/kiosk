import 'dart:convert';

import 'package:cropsync/services/shop_visit_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-user persistence of the seeds wishlist (set of seed variety ids).
class SeedWishlistStore {
  static String _k(String userKey) => 'seed_wishlist_$userKey';

  /// Key of the current user ('guest' when logged out).
  static String currentKey() => ShopVisitTracker.currentUserKey();

  static Future<Set<int>> load(String userKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.get(_k(userKey));
      if (raw is! String || raw.isEmpty) return <int>{};
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <int>{};
      return decoded
          .map((e) => e is num ? e.toInt() : int.tryParse('$e'))
          .whereType<int>()
          .toSet();
    } catch (_) {
      return <int>{};
    }
  }

  static Future<void> save(String userKey, Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final list = ids.toList()..sort();
    await prefs.setString(_k(userKey), jsonEncode(list));
  }

  /// Adds the id if absent, removes if present; persists and returns the new set.
  static Future<Set<int>> toggle(String userKey, int id) async {
    final ids = await load(userKey);
    if (!ids.remove(id)) ids.add(id);
    await save(userKey, ids);
    return ids;
  }
}
