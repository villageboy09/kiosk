import 'package:cropsync/services/shop_visit_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ShopVisitTracker.resetSession();
  });

  test('first run', () async {
    final s = await ShopVisitTracker.load('u1');
    expect(s.isFirstRun, isTrue);
    expect(s.sinceProductId, -1);
    expect(s.sinceBannerId, -1);
    await ShopVisitTracker.markSeen('u1', productId: 10, bannerId: 3);
    final s2 = await ShopVisitTracker.load('u1');
    expect(s2.isFirstRun, isFalse);
    expect(s2.productId, 10);
    expect(s2.bannerId, 3);
  });

  test('only raises', () async {
    await ShopVisitTracker.markSeen('u1', productId: 10, bannerId: 3);
    await ShopVisitTracker.markSeen('u1', productId: 5, bannerId: 1);
    var s = await ShopVisitTracker.load('u1');
    expect(s.productId, 10);
    expect(s.bannerId, 3);
    await ShopVisitTracker.markSeen('u1', productId: 12);
    s = await ShopVisitTracker.load('u1');
    expect(s.productId, 12);
    expect(s.bannerId, 3);
  });

  test('per-user isolation', () async {
    await ShopVisitTracker.markSeen('u1', productId: 10, bannerId: 3);
    expect((await ShopVisitTracker.load('u2')).isFirstRun, isTrue);
    expect((await ShopVisitTracker.load('guest')).isFirstRun, isTrue);
  });

  test('session guard', () {
    expect(ShopVisitTracker.shownThisSession, isFalse);
    ShopVisitTracker.markShownThisSession();
    expect(ShopVisitTracker.shownThisSession, isTrue);
  });

  test('guest key when no user', () {
    expect(ShopVisitTracker.currentUserKey(), 'guest');
  });
}
