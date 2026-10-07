import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cropsync/models/market_price.dart';
import 'package:cropsync/utils/market_aliases.dart';

enum MarketFetchError {
  network,
  timeout,
  server,
  upstreamUnavailable,
  missingApiKey,
  noData,
  parse,
}

enum MatchedLevel { district, state, none }

class CommodityStat {
  final String commodity;
  final int count;
  final double? minModal;
  final double? maxModal;
  const CommodityStat(
      {required this.commodity,
      required this.count,
      this.minModal,
      this.maxModal});

  factory CommodityStat.fromJson(Map<dynamic, dynamic> m) => CommodityStat(
        commodity: (m['commodity'] ?? '').toString(),
        count: (parseNumber(m['count']) ?? 0).toInt(),
        minModal: parsePrice(m['min_modal']),
        maxModal: parsePrice(m['max_modal']),
      );

  Map<String, dynamic> toJson() => {
        'commodity': commodity,
        'count': count,
        'min_modal': minModal,
        'max_modal': maxModal,
      };
}

class DistrictStat {
  final String district;
  final int count;
  const DistrictStat({required this.district, required this.count});

  factory DistrictStat.fromJson(Map<dynamic, dynamic> m) => DistrictStat(
        district: (m['district'] ?? '').toString(),
        count: (parseNumber(m['count']) ?? 0).toInt(),
      );

  Map<String, dynamic> toJson() => {'district': district, 'count': count};
}

class MarketStateInfo {
  final String state;
  final List<String> districts;
  final DateTime? latestDate;
  final int commodityCount;
  const MarketStateInfo({
    required this.state,
    required this.districts,
    this.latestDate,
    this.commodityCount = 0,
  });
}

class MarketLocationsResult {
  final List<MarketStateInfo> states;
  final MarketFetchError? error;
  final String? message;
  const MarketLocationsResult(
      {this.states = const [], this.error, this.message});
}

/// Result of a market price fetch. Records are always real data (live or
/// cached); on failure [records] is empty unless a cached copy was served.
///
/// When a cached copy is served because the network failed, [fromCache] and
/// [stale] are true, [records] is non-empty, and [error] still carries the
/// network failure so the UI can show "showing saved prices from <asOf>".
class MarketPricesResult {
  final List<MarketPrice> records;
  final List<CommodityStat> commodities;
  final List<DistrictStat> districts;
  final String? resolvedState;
  final String? resolvedDistrict;
  final MatchedLevel matchedLevel;
  final DateTime? asOf;
  final bool stale;
  final bool fromCache;

  /// True when paging stopped before all records were fetched.
  final bool partial;
  final int total;
  final MarketFetchError? error;
  final String? message;
  final DateTime? fetchedAt;

  /// Raw `error_hint` / `error` code of a failed response (e.g.
  /// `no_data_for_state`, when the server may still sync the state).
  final String? errorHint;

  const MarketPricesResult({
    this.records = const [],
    this.commodities = const [],
    this.districts = const [],
    this.resolvedState,
    this.resolvedDistrict,
    this.matchedLevel = MatchedLevel.none,
    this.asOf,
    this.stale = false,
    this.fromCache = false,
    this.partial = false,
    this.total = 0,
    this.error,
    this.message,
    this.fetchedAt,
    this.errorHint,
  });

  bool get hasData => records.isNotEmpty;
  bool get isError => error != null && records.isEmpty;

  MarketPricesResult copyWith({
    bool? stale,
    bool? fromCache,
    bool? partial,
    List<MarketPrice>? records,
    MarketFetchError? error,
    String? message,
  }) =>
      MarketPricesResult(
        records: records ?? this.records,
        commodities: commodities,
        districts: districts,
        resolvedState: resolvedState,
        resolvedDistrict: resolvedDistrict,
        matchedLevel: matchedLevel,
        asOf: asOf,
        stale: stale ?? this.stale,
        fromCache: fromCache ?? this.fromCache,
        partial: partial ?? this.partial,
        total: total,
        error: error ?? this.error,
        message: message ?? this.message,
        errorHint: errorHint,
        fetchedAt: fetchedAt,
      );

  Map<String, dynamic> toCacheJson() => {
        'records': records.map((r) => r.toJson()).toList(),
        'commodities': commodities.map((c) => c.toJson()).toList(),
        'districts': districts.map((d) => d.toJson()).toList(),
        'resolved_state': resolvedState,
        'resolved_district': resolvedDistrict,
        'matched_level': matchedLevel.name,
        'as_of': asOf?.toIso8601String(),
        'stale': stale,
        'partial': partial,
        'total': total,
        'fetched_at': (fetchedAt ?? DateTime.now()).toIso8601String(),
      };

  static MarketPricesResult? fromCacheJson(Map<String, dynamic> m) {
    final recs = (m['records'] as List?)
            ?.whereType<Map>()
            .map(MarketPrice.fromJson)
            .toList() ??
        const <MarketPrice>[];
    if (recs.isEmpty) return null;
    return MarketPricesResult(
      records: recs,
      commodities: (m['commodities'] as List?)
              ?.whereType<Map>()
              .map(CommodityStat.fromJson)
              .toList() ??
          const [],
      districts: (m['districts'] as List?)
              ?.whereType<Map>()
              .map(DistrictStat.fromJson)
              .toList() ??
          const [],
      resolvedState: m['resolved_state'] as String?,
      resolvedDistrict: m['resolved_district'] as String?,
      matchedLevel: _level(m['matched_level']),
      asOf: parseMarketDate(m['as_of']),
      stale: m['stale'] == true,
      fromCache: true,
      partial: m['partial'] == true,
      total: (parseNumber(m['total']) ?? recs.length).toInt(),
      fetchedAt: DateTime.tryParse((m['fetched_at'] ?? '').toString()),
    );
  }
}

MatchedLevel _level(dynamic v) {
  switch (v?.toString()) {
    case 'district':
      return MatchedLevel.district;
    case 'state':
      return MatchedLevel.state;
    default:
      return MatchedLevel.none;
  }
}

class MarketPricesService {
  static const String defaultBaseUrl = 'https://kiosk.cropsync.in/api';
  static const Duration requestTimeout = Duration(seconds: 15);
  static const Duration cacheTtl = Duration(hours: 6);

  /// Partial results (paging stopped early) are only trusted this long, so
  /// the next open tries again for the full list.
  static const Duration partialCacheTtl = Duration(minutes: 30);
  static const int pageSize = 1000;
  static const int maxPages = 12;

  /// Most records stored per cached location (SharedPreferences is small).
  static const int maxCachedRecords = 2000;
  static const int _maxCachedPerCommodity = 20;

  /// Recent-days window requested from the server (it clamps to 1..7) so
  /// commodities that arrive on different days all show up.
  static const int defaultDays = 3;
  static const String cachePrefix = 'market_v3_';
  static const String _legacyCachePrefix = 'market_v2_';
  static const int _keepPerLocation = 2;

  final http.Client _client;
  final String baseUrl;
  final DateTime Function() _now;

  MarketPricesService({
    http.Client? client,
    this.baseUrl = defaultBaseUrl,
    DateTime Function()? now,
  })  : _client = client ?? http.Client(),
        _now = now ?? DateTime.now;

  void dispose() => _client.close();

  /// Completes when every cache write started so far has finished (writes are
  /// not awaited by [fetchPrices] so they never delay the first paint).
  @visibleForTesting
  Future<void> pendingWrites = Future<void>.value();

  Uri _uri(String action, Map<String, String> params) {
    final q = <String, String>{'action': action};
    params.forEach((k, v) {
      if (v.isNotEmpty) q[k] = v;
    });
    return Uri.parse('$baseUrl/api.php').replace(queryParameters: q);
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final res = await _client.get(uri).timeout(requestTimeout);
    if (res.statusCode != 200) {
      throw _HttpFailure(res.statusCode);
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('not an object');
    }
    return decoded;
  }

  MarketFetchError _mapException(Object e) {
    if (e is TimeoutException) return MarketFetchError.timeout;
    if (e is FormatException) return MarketFetchError.parse;
    if (e is _HttpFailure) return MarketFetchError.server;
    return MarketFetchError.network;
  }

  MarketFetchError? _mapServerError(Map<String, dynamic> j) {
    if (j['success'] == true) return null;
    switch (j['error']?.toString()) {
      case 'upstream_unavailable':
        return MarketFetchError.upstreamUnavailable;
      case 'missing_api_key':
        return MarketFetchError.missingApiKey;
      case 'no_data_for_state':
        return MarketFetchError.noData;
    }
    if (j['error_hint']?.toString() == 'no_data_for_state') {
      return MarketFetchError.noData;
    }
    return MarketFetchError.server;
  }

  /// Fetches prices. With [fetchAll] (default) pages through every record
  /// (at most [maxPages] pages of [pageSize]; the result is flagged `partial`
  /// when that was not enough). The server orders by date then commodity, so
  /// callers wanting every commodity should ask for `days: 1` first. Never fabricates data. Results for a whole
  /// state/district (no [commodity]) are cached for [cacheTtl]; if the
  /// network fails the last cached copy is returned flagged
  /// `fromCache`/`stale`.
  Future<MarketPricesResult> fetchPrices({
    required String state,
    String? district,
    String? commodity,
    String lang = 'en',
    int limit = pageSize,
    int offset = 0,
    bool fetchAll = true,
    bool forceRefresh = false,
    int days = defaultDays,
  }) async {
    final cState = canonicalState(state);
    final dist = (district ?? '').trim();
    final cacheable =
        (commodity ?? '').trim().isEmpty && offset == 0 && fetchAll;
    final prefix = _prefixFor(cState, dist, days.clamp(1, 7));

    if (cacheable && !forceRefresh) {
      final hit = await _readCache(prefix, onlyFresh: true);
      if (hit != null) return hit;
    }

    final fresh = await _fetchNetwork(
      state: cState.isEmpty ? state : cState,
      district: dist,
      commodity: commodity ?? '',
      lang: lang,
      limit: limit,
      offset: offset,
      fetchAll: fetchAll,
      days: days,
    );

    if (fresh.error == null && fresh.records.isNotEmpty) {
      if (cacheable) {
        pendingWrites = pendingWrites.then((_) => _writeCache(prefix, fresh));
      }
      return fresh;
    }

    if (cacheable && fresh.error != MarketFetchError.noData) {
      final old = await _readCache(prefix, onlyFresh: false);
      if (old != null) {
        return old.copyWith(
            stale: true, error: fresh.error, message: fresh.message);
      }
    }
    return fresh;
  }

  Future<MarketPricesResult> _fetchNetwork({
    required String state,
    required String district,
    required String commodity,
    required String lang,
    required int limit,
    required int offset,
    required bool fetchAll,
    required int days,
  }) async {
    final records = <MarketPrice>[];
    var commodities = <CommodityStat>[];
    var districts = <DistrictStat>[];
    String? rState, rDistrict;
    var level = MatchedLevel.none;
    DateTime? asOf;
    var stale = false;
    var total = 0;
    var partial = false;
    var pageOffset = offset;

    for (var page = 0; page < maxPages; page++) {
      Map<String, dynamic> j;
      try {
        j = await _getJson(_uri('get_market_prices', {
          'state': state,
          'district': district,
          'commodity': commodity,
          'lang': lang,
          'limit': '$limit',
          'offset': '$pageOffset',
          'days': '${days.clamp(1, 7)}',
        }));
      } catch (e) {
        if (page > 0 && records.isNotEmpty) {
          partial = true;
          break;
        }
        return MarketPricesResult(error: _mapException(e));
      }

      final err = _mapServerError(j);
      if (err != null) {
        if (page > 0 && records.isNotEmpty) {
          partial = true;
          break;
        }
        return MarketPricesResult(
          error: err,
          message: j['message']?.toString(),
          resolvedState: j['state']?.toString(),
          asOf: parseMarketDate(j['as_of']),
          errorHint: (j['error_hint'] ?? j['error'])?.toString(),
        );
      }

      List<MarketPrice> pageRecs;
      try {
        pageRecs = (j['records'] as List? ?? const [])
            .whereType<Map>()
            .map(MarketPrice.fromJson)
            .where((r) => r.commodity.isNotEmpty)
            .toList();
      } catch (_) {
        return const MarketPricesResult(error: MarketFetchError.parse);
      }
      records.addAll(pageRecs);
      final rawCount = (j['records'] as List? ?? const []).length;

      if (page == 0) {
        rState = (j['resolved'] is Map ? j['resolved']['state'] : null)
                ?.toString() ??
            j['state']?.toString();
        rDistrict = (j['resolved'] is Map ? j['resolved']['district'] : null)
            ?.toString();
        if (rDistrict != null && rDistrict.isEmpty) rDistrict = null;
        level = _level(j['matched_level']);
        asOf = parseMarketDate(j['as_of']);
        stale = j['stale'] == true;
        commodities = (j['commodities'] as List? ?? const [])
            .whereType<Map>()
            .map(CommodityStat.fromJson)
            .toList();
        districts = (j['districts'] as List? ?? const [])
            .whereType<Map>()
            .map(DistrictStat.fromJson)
            .toList();
      }
      total = (parseNumber(j['total']) ?? records.length).toInt();
      pageOffset += rawCount;

      if (!fetchAll || rawCount == 0 || pageOffset - offset >= total) break;
      if (page == maxPages - 1) partial = true;
    }

    if (records.isEmpty) {
      return MarketPricesResult(
        error: MarketFetchError.noData,
        resolvedState: rState,
        resolvedDistrict: rDistrict,
        asOf: asOf,
        stale: stale,
        matchedLevel: level,
      );
    }

    return MarketPricesResult(
      records: records,
      commodities: commodities,
      districts: districts,
      resolvedState: rState,
      resolvedDistrict: rDistrict,
      matchedLevel: level,
      asOf: asOf,
      stale: stale,
      partial: partial,
      total: total,
      fetchedAt: _now(),
    );
  }

  Future<MarketLocationsResult> fetchLocations() async {
    try {
      final j = await _getJson(_uri('get_market_locations', const {}));
      if (j['success'] != true) {
        return MarketLocationsResult(
            error: _mapServerError(j), message: j['message']?.toString());
      }
      final states = (j['states'] as List? ?? const [])
          .whereType<Map>()
          .map((s) => MarketStateInfo(
                state: canonicalState((s['state'] ?? '').toString()),
                districts: (s['districts'] as List? ?? const [])
                    .map((d) => d is Map
                        ? (d['district'] ?? '').toString()
                        : d.toString())
                    .where((d) => d.isNotEmpty)
                    .toList(),
                latestDate: parseMarketDate(s['latest_date']),
                commodityCount:
                    (parseNumber(s['commodity_count']) ?? 0).toInt(),
              ))
          .where((s) => s.state.isNotEmpty)
          .toList();
      return MarketLocationsResult(states: states);
    } catch (e) {
      return MarketLocationsResult(error: _mapException(e));
    }
  }

  /// Real historical points only; [] when the server has insufficient data,
  /// fewer than 2 points, or on any failure.
  Future<List<TrendPoint>> fetchTrends({
    required String state,
    String? district,
    required String commodity,
    int days = 30,
  }) async {
    try {
      final j = await _getJson(_uri('get_commodity_trends', {
        'state': canonicalState(state),
        'district': (district ?? '').trim(),
        'commodity': commodity,
        'days': '$days',
      }));
      if (j['success'] != true || j['insufficient_data'] == true) {
        return const [];
      }
      final pts = (j['trends'] as List? ?? const [])
          .whereType<Map>()
          .map(TrendPoint.tryParse)
          .whereType<TrendPoint>()
          .toList();
      if (pts.length < 2) return const [];
      if (pts.every((p) => p.date != null)) {
        pts.sort((a, b) => a.date!.compareTo(b.date!));
      }
      return pts;
    } catch (_) {
      return const [];
    }
  }

  // ------------------------------- cache ---------------------------------

  /// Cache key prefix: `market_v3_<state>_<district>_d<days>_`. Never empty
  /// parts: a state that is not a known one (e.g. a Telugu spelling nobody
  /// aliased) is keyed by its Latin letters plus a stable hash of the name.
  String _prefixFor(String state, String district, int days) {
    final d = normalizeDistrictKey(district);
    final dk = d.isEmpty ? 'all' : d.replaceAll('_', '-');
    return '$cachePrefix${stateCacheKey(state)}_${dk}_d${days}_';
  }

  /// Stable, never-empty cache key for a state name.
  @visibleForTesting
  static String stateCacheKey(String rawState) {
    final c = canonicalState(rawState);
    final slug = c.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    if (isKnownState(c) && slug.isNotEmpty) return slug;
    if (c.isEmpty) return 'none';
    var h = 0x811c9dc5;
    for (final u in c.toLowerCase().codeUnits) {
      h = ((h ^ u) * 0x01000193) & 0xffffffff;
    }
    return '${slug}x${h.toRadixString(16)}';
  }

  Future<MarketPricesResult?> _readCache(String prefix,
      {required bool onlyFresh}) async {
    try {
      await pendingWrites;
      final prefs = await SharedPreferences.getInstance();
      MarketPricesResult? best;
      for (final k in prefs.getKeys().where((k) => k.startsWith(prefix))) {
        final raw = prefs.getString(k);
        if (raw == null) continue;
        try {
          final r = MarketPricesResult.fromCacheJson(
              jsonDecode(raw) as Map<String, dynamic>);
          if (r == null) continue;
          if (best == null ||
              (r.fetchedAt ?? DateTime(0))
                  .isAfter(best.fetchedAt ?? DateTime(0))) {
            best = r;
          }
        } catch (_) {}
      }
      if (best == null) return null;
      if (onlyFresh) {
        final at = best.fetchedAt;
        final ttl = best.partial ? partialCacheTtl : cacheTtl;
        if (at == null || _now().difference(at) > ttl) return null;
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  /// At most [maxCachedRecords] rows: when over, keep the newest rows of
  /// every commodity (20 each, fewer if still too many) so coverage stays.
  @visibleForTesting
  static MarketPricesResult trimForCache(MarketPricesResult r) {
    if (r.records.length <= maxCachedRecords) return r;
    final byKey = <String, List<MarketPrice>>{};
    for (final rec in r.records) {
      byKey.putIfAbsent(commodityKey(rec.commodity), () => []).add(rec);
    }
    for (final list in byKey.values) {
      // Stable: newest first, undated last.
      final idx = {for (var i = 0; i < list.length; i++) list[i]: i};
      list.sort((a, b) {
        final da = a.arrivalDate, db = b.arrivalDate;
        if (da != null && db != null) {
          final c = db.compareTo(da);
          if (c != 0) return c;
        } else if (da != null) {
          return -1;
        } else if (db != null) {
          return 1;
        }
        return idx[a]!.compareTo(idx[b]!);
      });
    }
    var per = _maxCachedPerCommodity;
    List<MarketPrice> out;
    while (true) {
      out = [for (final l in byKey.values) ...l.take(per)];
      if (out.length <= maxCachedRecords || per == 1) break;
      per = per > 5 ? per ~/ 2 : per - 1;
    }
    if (out.length > maxCachedRecords) {
      out = out.take(maxCachedRecords).toList();
    }
    return r.copyWith(records: out, partial: true);
  }

  Future<void> _writeCache(String prefix, MarketPricesResult r) async {
    try {
      r = trimForCache(r);
      final prefs = await SharedPreferences.getInstance();
      final day = r.asOf ?? _now();
      final ds =
          '${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
      await prefs.setString('$prefix$ds', jsonEncode(r.toCacheJson()));

      // Keep only the newest few entries per location, drop legacy keys.
      final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList()
        ..sort();
      for (final k in keys.reversed.skip(_keepPerLocation)) {
        await prefs.remove(k);
      }
      for (final k in prefs
          .getKeys()
          .where((k) =>
              k.startsWith('cached_market_prices_') ||
              k.startsWith(_legacyCachePrefix))
          .toList()) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}

class _HttpFailure implements Exception {
  final int status;
  const _HttpFailure(this.status);
}
