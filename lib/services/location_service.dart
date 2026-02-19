import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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

  /// Get just the district name
  static Future<String> getDistrict() async {
    try {
      final position = await getCurrentPosition();
      if (position == null) return 'Hyderabad'; // Default

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return place.subAdministrativeArea ?? place.locality ?? 'Hyderabad';
      }
      return 'Hyderabad';
    } catch (e) {
      return 'Hyderabad';
    }
  }

  /// Get just the state name
  static Future<String> getState() async {
    try {
      final position = await getCurrentPosition();
      if (position == null) return 'Telangana'; // Default

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        return placemarks.first.administrativeArea ?? 'Telangana';
      }
      return 'Telangana';
    } catch (e) {
      return 'Telangana';
    }
  }

  /// Clear the cache
  static void clearCache() {
    _cachedPosition = null;
    _cachedLocationName = null;
    _lastFetchTime = null;
  }
}
