import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Production-grade Weather Tool Service for Plant Doctor
/// Fetches and compresses Realtime, Historical (past 7d), and Forecast (next 7d)
/// weather parameters (temperature, humidity, wind, rainfall) to minimize token consumption
/// while giving the model high-precision environmental context.
class WeatherToolService {
  /// Open-Meteo endpoint (reliable, free, high-resolution global & Indian grid)
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// In-memory cache for weather data to prevent duplicate calls during the same session
  static final Map<String, _CachedWeather> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 30);

  /// Fetch comprehensive agricultural weather data for specified coordinates
  static Future<Map<String, dynamic>> getAgriWeatherContext({
    required double latitude,
    required double longitude,
    String timeframe = 'all', // 'realtime', 'historical', 'forecast', or 'all'
  }) async {
    // Round coordinates to 2 decimal places (~1.1 km precision) for cache hits
    final roundedLat = double.parse(latitude.toStringAsFixed(2));
    final roundedLon = double.parse(longitude.toStringAsFixed(2));
    final cacheKey = '$roundedLat,$roundedLon';

    // Check local cache
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.timestamp) < _cacheTtl) {
      return _filterTimeframe(cached.data, timeframe);
    }

    try {
      final uri = Uri.parse(
        '$_baseUrl?latitude=$roundedLat&longitude=$roundedLon'
        '&current=temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,wind_direction_10m'
        '&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,wind_speed_10m_max'
        '&past_days=7&forecast_days=7&timezone=auto',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body) as Map<String, dynamic>;
        final processed = _processWeatherData(raw);

        // Store in cache
        _cache[cacheKey] = _CachedWeather(
          data: processed,
          timestamp: DateTime.now(),
        );

        return _filterTimeframe(processed, timeframe);
      } else {
        return _filterTimeframe(
          _fallbackWeather(latitude, longitude, "Weather API returned HTTP ${response.statusCode}"),
          timeframe,
        );
      }
    } catch (e) {
      debugPrint("WeatherToolService error: $e");
      return _filterTimeframe(
        _fallbackWeather(latitude, longitude, e.toString()),
        timeframe,
      );
    }
  }

  /// Clear the in-memory weather cache
  static void clearCache() {
    _cache.clear();
  }

  /// Compactly process raw weather into token-dense agricultural indicators
  static Map<String, dynamic> _processWeatherData(Map<String, dynamic> raw) {
    final current = raw['current'] as Map<String, dynamic>? ?? {};
    final daily = raw['daily'] as Map<String, dynamic>? ?? {};

    // 1. Current / Realtime
    final currentTemp = (current['temperature_2m'] as num?)?.toDouble() ?? 28.0;
    final currentRh = (current['relative_humidity_2m'] as num?)?.toInt() ?? 70;
    final currentWindSpeed = (current['wind_speed_10m'] as num?)?.toDouble() ?? 8.0;
    final currentWindDeg = (current['wind_direction_10m'] as num?)?.toInt() ?? 180;
    final currentRain = (current['precipitation'] as num?)?.toDouble() ?? 0.0;
    final windDirection = _degToCompass(currentWindDeg);

    // 2. Historical (Past 7 days)
    final dailyTimes = (daily['time'] as List?)?.cast<String>() ?? [];
    final dailyMaxTemps = (daily['temperature_2m_max'] as List?)?.cast<num>() ?? [];
    final dailyMinTemps = (daily['temperature_2m_min'] as List?)?.cast<num>() ?? [];
    final dailyPrecip = (daily['precipitation_sum'] as List?)?.cast<num>() ?? [];
    final dailyPrecipProb = (daily['precipitation_probability_max'] as List?)?.cast<num>() ?? [];
    final dailyWind = (daily['wind_speed_10m_max'] as List?)?.cast<num>() ?? [];

    // Indices: 0..6 = past 7 days, 7 = today, 8..14 = next 7 days
    double pastRainSum = 0;
    int wetDaysCount = 0;
    double pastTempSum = 0;
    final pastCount = dailyTimes.length >= 7 ? 7 : dailyTimes.length;

    for (int i = 0; i < pastCount; i++) {
      final rain = dailyPrecip.length > i ? (dailyPrecip[i].toDouble()) : 0.0;
      pastRainSum += rain;
      if (rain > 1.0) wetDaysCount++;

      final maxT = dailyMaxTemps.length > i ? dailyMaxTemps[i].toDouble() : 30.0;
      final minT = dailyMinTemps.length > i ? dailyMinTemps[i].toDouble() : 20.0;
      pastTempSum += (maxT + minT) / 2.0;
    }
    final pastAvgTemp = pastCount > 0 ? (pastTempSum / pastCount) : 25.0;

    // 3. Forecast (Next 7 days)
    int forecastRainChance48h = 0;
    double forecastMaxWind = 0;
    double forecastRainTotal = 0;

    final startIndex = dailyTimes.length >= 8 ? 7 : 0;
    final endIndex = dailyTimes.length;

    for (int i = startIndex; i < endIndex; i++) {
      if (i < dailyPrecipProb.length) {
        final prob = dailyPrecipProb[i].toInt();
        if (i <= startIndex + 2 && prob > forecastRainChance48h) {
          forecastRainChance48h = prob;
        }
      }
      if (i < dailyPrecip.length) {
        forecastRainTotal += dailyPrecip[i].toDouble();
      }
      if (i < dailyWind.length) {
        final w = dailyWind[i].toDouble();
        if (w > forecastMaxWind) forecastMaxWind = w;
      }
    }

    // High fungal risk indicator: high humidity (>75%) + warm temp (22-30C) + past rainfall
    final highFungalRisk = currentRh >= 75 && pastAvgTemp >= 20 && pastAvgTemp <= 32 && (wetDaysCount >= 2 || currentRh >= 85);
    // Spray drift risk: wind > 15 km/h
    final sprayDriftRisk = currentWindSpeed > 15.0;
    // Rain washoff risk: rain expected in next 24-48h
    final rainWashoffRisk = forecastRainChance48h >= 60;

    return {
      'realtime': {
        'temp_c': currentTemp,
        'rh_pct': currentRh,
        'wind_kmh': currentWindSpeed,
        'wind_dir': windDirection,
        'rain_mm': currentRain,
        'spray_condition': sprayDriftRisk ? 'Unfavorable (Wind >15km/h)' : 'Favorable',
      },
      'historical_7d': {
        'avg_temp_c': double.parse(pastAvgTemp.toStringAsFixed(1)),
        'total_rain_mm': double.parse(pastRainSum.toStringAsFixed(1)),
        'wet_days': wetDaysCount,
        'fungal_incubation_risk': highFungalRisk ? 'High' : 'Moderate/Low',
      },
      'forecast_7d': {
        'rain_prob_48h_pct': forecastRainChance48h,
        'total_rain_7d_mm': double.parse(forecastRainTotal.toStringAsFixed(1)),
        'max_wind_kmh': double.parse(forecastMaxWind.toStringAsFixed(1)),
        'spray_washoff_warning': rainWashoffRisk,
      },
      'agri_summary': 'RH $currentRh%, Temp ${currentTemp.toStringAsFixed(1)}°C, Wind $currentWindSpeed km/h $windDirection. '
          'Past 7d rain: ${pastRainSum.toStringAsFixed(1)}mm ($wetDaysCount wet days). '
          '48h rain chance: $forecastRainChance48h%.'
    };
  }

  /// Filter response according to requested timeframe
  static Map<String, dynamic> _filterTimeframe(Map<String, dynamic> fullData, String timeframe) {
    if (timeframe == 'realtime') {
      return {'realtime': fullData['realtime'], 'agri_summary': fullData['agri_summary']};
    } else if (timeframe == 'historical') {
      return {'historical_7d': fullData['historical_7d'], 'agri_summary': fullData['agri_summary']};
    } else if (timeframe == 'forecast') {
      return {'forecast_7d': fullData['forecast_7d'], 'agri_summary': fullData['agri_summary']};
    }
    return fullData;
  }

  /// Convert wind degrees to cardinal compass direction
  static String _degToCompass(int degrees) {
    const directions = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
    final idx = ((degrees + 11.25) / 22.5).floor() % 16;
    return directions[idx];
  }

  /// Fallback weather structure if network fails
  static Map<String, dynamic> _fallbackWeather(double lat, double lon, String reason) {
    return {
      'realtime': {
        'temp_c': 28.0,
        'rh_pct': 70,
        'wind_kmh': 8.0,
        'wind_dir': 'SW',
        'spray_condition': 'Unknown',
      },
      'historical_7d': {
        'avg_temp_c': 27.5,
        'total_rain_mm': 10.0,
        'wet_days': 1,
        'fungal_incubation_risk': 'Moderate',
      },
      'forecast_7d': {
        'rain_prob_48h_pct': 30,
        'spray_washoff_warning': false,
      },
      'agri_summary': 'Standard Indian semi-arid seasonal weather fallback (Lat: ${lat.toStringAsFixed(2)}, Lon: ${lon.toStringAsFixed(2)}). Note: $reason'
    };
  }
}

class _CachedWeather {
  final Map<String, dynamic> data;
  final DateTime timestamp;
  _CachedWeather({required this.data, required this.timestamp});
}
