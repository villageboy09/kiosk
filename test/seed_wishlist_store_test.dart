import 'package:cropsync/services/seed_wishlist_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('empty by default', () async {
    expect(await SeedWishlistStore.load('u1'), isEmpty);
  });

  test('toggle adds then removes and persists', () async {
    expect(await SeedWishlistStore.toggle('u1', 5), {5});
    expect(await SeedWishlistStore.toggle('u1', 7), {5, 7});
    expect(await SeedWishlistStore.load('u1'), {5, 7});
    expect(await SeedWishlistStore.toggle('u1', 5), {7});
    expect(await SeedWishlistStore.load('u1'), {7});
  });

  test('isolated per user', () async {
    await SeedWishlistStore.toggle('u1', 1);
    await SeedWishlistStore.toggle('u2', 2);
    expect(await SeedWishlistStore.load('u1'), {1});
    expect(await SeedWishlistStore.load('u2'), {2});
    expect(await SeedWishlistStore.load('guest'), isEmpty);
  });

  test('save/load roundtrip uses seed_wishlist_<user> key', () async {
    await SeedWishlistStore.save('abc', {3, 1});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('seed_wishlist_abc'), '[1,3]');
    expect(await SeedWishlistStore.load('abc'), {1, 3});
  });

  test('corrupt values are tolerated', () async {
    SharedPreferences.setMockInitialValues({
      'seed_wishlist_a': 'not json{',
      'seed_wishlist_b': '{"x":1}',
      'seed_wishlist_c': '[1,"2",null,"x",3.0]',
      'seed_wishlist_d': 42,
    });
    expect(await SeedWishlistStore.load('a'), isEmpty);
    expect(await SeedWishlistStore.load('b'), isEmpty);
    expect(await SeedWishlistStore.load('c'), {1, 2, 3});
    expect(await SeedWishlistStore.load('d'), isEmpty);
    // toggle recovers from corruption
    expect(await SeedWishlistStore.toggle('a', 9), {9});
  });

  test('currentKey is guest when logged out', () {
    expect(SeedWishlistStore.currentKey(), 'guest');
  });
}
