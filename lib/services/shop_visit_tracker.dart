import 'package:cropsync/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Last-seen shop product/banner ids for one user.
class ShopSeen {
  final int? productId;
  final int? bannerId;
  const ShopSeen({this.productId, this.bannerId});

  /// Nothing stored yet: caller should fetch updates with since=-1, then
  /// markSeen with the returned latest ids and show nothing.
  bool get isFirstRun => productId == null && bannerId == null;

  /// since value to send to the API (-1 on first run).
  int get sinceProductId => productId ?? -1;
  int get sinceBannerId => bannerId ?? -1;
}

class ShopVisitTracker {
  ShopVisitTracker._();

  static bool _shownThisSession = false;

  /// True once the updates sheet was shown this app session.
  static bool get shownThisSession => _shownThisSession;

  /// Call when the sheet is shown.
  static void markShownThisSession() => _shownThisSession = true;

  /// Test helper.
  static void resetSession() => _shownThisSession = false;

  /// Key for the current user ('guest' when logged out).
  static String currentUserKey() {
    final id = AuthService.currentUser?.userId;
    return (id == null || id.isEmpty) ? 'guest' : id;
  }

  static String _pk(String user) => 'shop_seen_product_id_$user';
  static String _bk(String user) => 'shop_seen_banner_id_$user';

  static Future<ShopSeen> load(String userKey) async {
    final prefs = await SharedPreferences.getInstance();
    return ShopSeen(
      productId: prefs.getInt(_pk(userKey)),
      bannerId: prefs.getInt(_bk(userKey)),
    );
  }

  /// Stores ids, only ever raising existing values.
  static Future<void> markSeen(String userKey,
      {int? productId, int? bannerId}) async {
    final prefs = await SharedPreferences.getInstance();
    if (productId != null) {
      final cur = prefs.getInt(_pk(userKey));
      if (cur == null || productId > cur) {
        await prefs.setInt(_pk(userKey), productId);
      }
    }
    if (bannerId != null) {
      final cur = prefs.getInt(_bk(userKey));
      if (cur == null || bannerId > cur) {
        await prefs.setInt(_bk(userKey), bannerId);
      }
    }
  }
}
