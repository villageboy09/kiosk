import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'package:cropsync/models/market_location.dart';
import 'package:cropsync/models/user.dart';
import 'package:cropsync/utils/market_aliases.dart';

/// Minimal position fix used by [LocationService.resolveMarketLocation] so
/// tests can inject fakes without constructing a full geolocator [Position].
class GeoFix {
  final double lat;
  final double lng;
  final DateTime? timestamp;
  const GeoFix(this.lat, this.lng, [this.timestamp]);
}

/// Injectable platform seams for [LocationService.resolveMarketLocation].
class LocationDeps {
  final Future<bool> Function() isServiceEnabled;
  final Future<LocationPermission> Function() checkPermission;
  final Future<LocationPermission> Function() requestPermission;
  final Future<GeoFix?> Function() lastKnown;
  final Future<GeoFix> Function(Duration timeLimit) current;
  final Future<List<Placemark>> Function(double lat, double lng) placemarks;
  final DateTime Function() now;

  /// Switches the platform geocoder to English (India) names. Optional so
  /// fakes need not provide it; failures are ignored.
  final Future<void> Function(String localeIdentifier)? setGeocoderLocale;

  const LocationDeps({
    required this.isServiceEnabled,
    required this.checkPermission,
    required this.requestPermission,
    required this.lastKnown,
    required this.current,
    required this.placemarks,
    required this.now,
    this.setGeocoderLocale,
  });

  static LocationDeps platform() => LocationDeps(
        isServiceEnabled: Geolocator.isLocationServiceEnabled,
        checkPermission: Geolocator.checkPermission,
        requestPermission: Geolocator.requestPermission,
        lastKnown: () async {
          final p = await Geolocator.getLastKnownPosition();
          return p == null
              ? null
              : GeoFix(p.latitude, p.longitude, p.timestamp);
        },
        current: (limit) async {
          final p = await Geolocator.getCurrentPosition(
            locationSettings: LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: limit,
            ),
          );
          return GeoFix(p.latitude, p.longitude, p.timestamp);
        },
        placemarks: placemarkFromCoordinates,
        now: DateTime.now,
        setGeocoderLocale: setLocaleIdentifier,
      );
}

/// Centralized location service for the app
/// Handles permission requests, caching, and location name resolution
class LocationService {
  static Position? _cachedPosition;
  static String? _cachedLocationName;
  static DateTime? _lastFetchTime;
  static const Duration _cacheValidity = Duration(minutes: 15);

  /// Check if we have a valid cached position
  static bool get hasValidCache {
    if (_cachedPosition == null || _lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheValidity;
  }

  /// Get cached position (null if not cached)
  static Position? get cachedPosition => _cachedPosition;

  /// Get cached location name (null if not cached)
  static String? get cachedLocationName => _cachedLocationName;

  /// Request location permission at app startup
  /// Returns true if permission is granted, false otherwise
  static Future<bool> requestPermission() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        // Request permission
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get current position (uses cache if valid, otherwise fetches fresh)
  static Future<Position?> getCurrentPosition(
      {bool forceRefresh = false}) async {
    // Return cached position if valid and not forcing refresh
    if (!forceRefresh && hasValidCache) {
      return _cachedPosition;
    }

    try {
      // Check permission first
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        return _cachedPosition; // Return cached even if stale
      }

      // Fetch fresh position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Update cache
      _cachedPosition = position;
      _lastFetchTime = DateTime.now();

      return position;
    } catch (e) {
      return _cachedPosition; // Return cached on error
    }
  }

  /// Get location name (district, state) from coordinates
  static Future<String> getLocationName({bool forceRefresh = false}) async {
    // Return cached name if available and not forcing refresh
    if (!forceRefresh && _cachedLocationName != null && hasValidCache) {
      return _cachedLocationName!;
    }

    try {
      final position = await getCurrentPosition(forceRefresh: forceRefresh);
      if (position == null) {
        return _cachedLocationName ?? 'Unknown Location';
      }

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final district = place.subAdministrativeArea ?? place.locality ?? '';
        final state = place.administrativeArea ?? '';

        _cachedLocationName = district.isNotEmpty
            ? '$district, $state'
            : state.isNotEmpty
                ? state
                : 'Unknown Location';

        return _cachedLocationName!;
      }

      return _cachedLocationName ?? 'Unknown Location';
    } catch (e) {
      return _cachedLocationName ?? 'Unknown Location';
    }
  }

  /// Clear the cache
  static void clearCache() {
    _cachedPosition = null;
    _cachedLocationName = null;
    _lastFetchTime = null;
  }

  // ===================== Market location (new API) =====================

  static const Duration _lastKnownFresh = Duration(minutes: 30);
  static const Duration _geocodeTimeout = Duration(seconds: 4);
  static const Duration _totalBudget = Duration(seconds: 10);

  /// Resolves the user's state/district for market prices through ONE
  /// permission flow and a bounded total time. Never falls back silently to
  /// a default place: on any problem a [MarketLocationFailure] is returned.
  static Future<MarketLocationResult> resolveMarketLocation({
    Duration gpsTimeout = const Duration(seconds: 8),
    bool allowCachedLastKnown = true,
    LocationDeps? deps,
  }) async {
    final d = deps ?? LocationDeps.platform();
    final sw = Stopwatch()..start();
    try {
      if (!await d.isServiceEnabled()) {
        return const MarketLocationResult(
            failure: MarketLocationFailure.serviceDisabled);
      }
      var perm = await d.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await d.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        return const MarketLocationResult(
            failure: MarketLocationFailure.permissionDeniedForever);
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.unableToDetermine) {
        return const MarketLocationResult(
            failure: MarketLocationFailure.permissionDenied);
      }

      GeoFix? fix;
      GeoFix? stale;
      try {
        final lk = await d.lastKnown();
        if (lk != null) {
          final ts = lk.timestamp;
          if (ts != null && d.now().difference(ts) < _lastKnownFresh) {
            fix = lk;
          } else {
            stale = lk;
          }
        }
      } catch (_) {}

      if (fix == null) {
        try {
          fix = await d.current(gpsTimeout).timeout(gpsTimeout);
        } on TimeoutException {
          if (allowCachedLastKnown && stale != null) {
            fix = stale;
          } else {
            return const MarketLocationResult(
                failure: MarketLocationFailure.timeout);
          }
        } catch (_) {
          if (allowCachedLastKnown && stale != null) {
            fix = stale;
          } else {
            return const MarketLocationResult(
                failure: MarketLocationFailure.timeout);
          }
        }
      }

      var remaining = _totalBudget - sw.elapsed;
      if (remaining < const Duration(seconds: 2)) {
        remaining = const Duration(seconds: 2);
      }
      final geoLimit =
          remaining < _geocodeTimeout ? remaining : _geocodeTimeout;

      // Android's geocoder follows the device language; ask for English so
      // names match the (English) market data.
      try {
        await d.setGeocoderLocale?.call('en_IN');
      } catch (_) {}

      List<Placemark> marks;
      try {
        marks = await d.placemarks(fix.lat, fix.lng).timeout(geoLimit);
      } catch (_) {
        return const MarketLocationResult(
            failure: MarketLocationFailure.geocodeFailed);
      }
      if (marks.isEmpty) {
        return const MarketLocationResult(
            failure: MarketLocationFailure.geocodeFailed);
      }

      String pick(String? Function(Placemark) f) {
        for (final m in marks) {
          final v = f(m)?.trim();
          if (v != null && v.isNotEmpty) return v;
        }
        return '';
      }

      final state = canonicalState(pick((m) => m.administrativeArea));
      final district = englishDistrictName(
          pick((m) => m.subAdministrativeArea).isNotEmpty
              ? pick((m) => m.subAdministrativeArea)
              : pick((m) => m.locality));
      if (state.isEmpty && district.isEmpty) {
        return const MarketLocationResult(
            failure: MarketLocationFailure.geocodeFailed);
      }
      return MarketLocationResult(
        location: MarketLocation(
          state: state,
          district: district,
          lat: fix.lat,
          lng: fix.lng,
          source: MarketLocationSource.gps,
        ),
      );
    } catch (_) {
      return const MarketLocationResult(
          failure: MarketLocationFailure.unsupported);
    }
  }

  /// Location from the saved profile. The user model has no state field, so
  /// the state comes from `region` when it names a known state, else from a
  /// known AP/Telangana district; otherwise it is '' (UI must ask).
  /// Returns null when the profile has no district.
  static MarketLocation? locationFromProfile(User? user) {
    final district = user?.district?.trim() ?? '';
    if (district.isEmpty) return null;
    var state = '';
    final region = user?.region?.trim() ?? '';
    if (region.isNotEmpty) {
      final c = canonicalState(region);
      if (isKnownState(c)) state = c;
    }
    if (state.isEmpty) state = stateForKnownDistrict(district) ?? '';
    return MarketLocation(
      state: state,
      district: district,
      source: MarketLocationSource.profile,
    );
  }

  /// Opens the OS location (GPS) settings page.
  static Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  /// Opens this app's settings page (to re-enable a denied-forever permission).
  static Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}
