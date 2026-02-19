/// Cache service for storing API responses and reducing network calls
class CacheService {
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTime = {};

  /// Default cache duration
  static const Duration defaultCacheDuration = Duration(minutes: 10);

  /// Get data from cache or fetch fresh using the provided fetcher function
  ///
  /// [key] - Unique identifier for this cached data
  /// [fetcher] - Function to fetch fresh data if cache is invalid
  /// [duration] - How long the cache should be valid (default: 10 minutes)
  static Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetcher, {
    Duration duration = defaultCacheDuration,
  }) async {
    // Check if we have valid cached data
    if (isValid(key, duration)) {
      return _cache[key] as T;
    }

    // Fetch fresh data

    try {
      final data = await fetcher();

      // Store in cache
      _cache[key] = data;
      _cacheTime[key] = DateTime.now();

      return data;
    } catch (e) {
      // If fetch fails but we have stale cache, return it
      if (_cache.containsKey(key)) {
        return _cache[key] as T;
      }
      rethrow;
    }
  }

  /// Check if a cached entry is still valid
  static bool isValid(String key, [Duration? duration]) {
    if (!_cache.containsKey(key) || !_cacheTime.containsKey(key)) {
      return false;
    }

    final cacheAge = DateTime.now().difference(_cacheTime[key]!);
    return cacheAge < (duration ?? defaultCacheDuration);
  }

  /// Get cached data without fetching (returns null if not cached or invalid)
  static T? get<T>(String key, {Duration? duration}) {
    if (isValid(key, duration)) {
      return _cache[key] as T?;
    }
    return null;
  }

  /// Manually set cache data
  static void set<T>(String key, T data) {
    _cache[key] = data;
    _cacheTime[key] = DateTime.now();
  }

  /// Invalidate a specific cache entry
  static void invalidate(String key) {
    _cache.remove(key);
    _cacheTime.remove(key);
  }

  /// Invalidate all cache entries matching a prefix
  static void invalidatePrefix(String prefix) {
    final keysToRemove =
        _cache.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
      _cacheTime.remove(key);
    }
  }

  /// Clear all cached data
  static void clearAll() {
    _cache.clear();
    _cacheTime.clear();
  }

  /// Get cache statistics (for debugging)
  static Map<String, dynamic> getStats() {
    return {
      'totalEntries': _cache.length,
      'keys': _cache.keys.toList(),
      'ages': _cacheTime.map((key, time) =>
          MapEntry(key, DateTime.now().difference(time).inSeconds)),
    };
  }
}

/// Cache keys used throughout the app
class CacheKeys {
  static const String seedVarieties = 'seed_varieties';
  static const String products = 'products';
  static const String productCategories = 'product_categories';
  static const String chcEquipments = 'chc_equipments';
  static const String crops = 'crops';
  static const String cropStages = 'crop_stages';
  static const String marketPrices = 'market_prices';
  static const String userSelections = 'user_selections';

  /// Generate a key with parameters
  static String withParams(String base, Map<String, dynamic> params) {
    if (params.isEmpty) return base;
    final sortedParams = params.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final paramString =
        sortedParams.map((e) => '${e.key}=${e.value}').join('&');
    return '$base?$paramString';
  }
}
