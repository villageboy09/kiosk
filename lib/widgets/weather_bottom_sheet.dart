import 'dart:convert';
import 'package:cropsync/theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';

/// Lightweight weather widget designed for bottom sheet display
class WeatherBottomSheet extends StatefulWidget {
  const WeatherBottomSheet({super.key});

  static void show(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => const WeatherBottomSheet(),
    );
  }

  @override
  State<WeatherBottomSheet> createState() => _WeatherBottomSheetState();
}

class _WeatherBottomSheetState extends State<WeatherBottomSheet> {
  late Future<_WeatherSummary> _weatherFuture;

  @override
  void initState() {
    super.initState();
    _weatherFuture = _fetchWeather();
  }

  Future<_WeatherSummary> _fetchWeather() async {
    final apiKey = dotenv.env['WEATHER_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("Weather API key missing");
    }

    // Get location
    final position = await _getPosition();
    final lat = position.latitude;
    final lon = position.longitude;

    // Get location name
    String locationName = "Current Location";
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        final city = place.locality ?? "";
        final area =
            place.subAdministrativeArea ?? place.administrativeArea ?? "";
        if (city.isNotEmpty && area.isNotEmpty) {
          locationName = "$city, $area";
        } else if (city.isNotEmpty) {
          locationName = city;
        } else if (area.isNotEmpty) {
          locationName = area;
        }
      }
    } catch (_) {}

    // Fetch weather
    final url = Uri.parse(
      'https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/$lat,$lon?unitGroup=metric&key=$apiKey&contentType=json',
    );
    final response = await http.get(url);
    if (response.statusCode != 200) throw Exception('Weather API failed');

    final data = json.decode(response.body);
    final today = data['days'][0];
    final hours = (today['hours'] as List)
        .take(12)
        .map((h) => _HourlyData(
              time: h['datetime']?.substring(0, 5) ?? '00:00',
              temp: (h['temp'] ?? 0.0).toDouble(),
              icon: h['icon'] ?? 'clear-day',
            ))
        .toList();

    return _WeatherSummary(
      location: locationName,
      temp: (today['temp'] ?? 0.0).toDouble(),
      tempMax: (today['tempmax'] ?? 0.0).toDouble(),
      tempMin: (today['tempmin'] ?? 0.0).toDouble(),
      conditions: today['conditions'] ?? 'N/A',
      icon: today['icon'] ?? 'clear-day',
      humidity: (today['humidity'] ?? 0.0).toDouble(),
      windSpeed: (today['windspeed'] ?? 0.0).toDouble(),
      precipProb: (today['precipprob'] ?? 0.0).toDouble(),
      hourly: hours,
    );
  }

  Future<Position> _getPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services disabled');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied');
    }
    return await Geolocator.getCurrentPosition();
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'snow':
        return Icons.ac_unit_rounded;
      case 'rain':
        return Icons.water_drop_rounded;
      case 'fog':
        return Icons.foggy;
      case 'wind':
        return Icons.air_rounded;
      case 'cloudy':
        return Icons.cloud_rounded;
      case 'partly-cloudy-day':
        return Icons.wb_cloudy_rounded;
      case 'partly-cloudy-night':
        return Icons.nights_stay_rounded;
      case 'clear-day':
        return Icons.wb_sunny_rounded;
      case 'clear-night':
        return Icons.nightlight_round;
      default:
        return Icons.wb_sunny_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Content
          Flexible(
            child: FutureBuilder<_WeatherSummary>(
              future: _weatherFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _WeatherShimmer();
                }
                if (snapshot.hasError) {
                  return _buildError(snapshot.error.toString());
                }
                if (!snapshot.hasData) {
                  return _buildError('No weather data');
                }
                return _buildContent(snapshot.data!);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Unable to load weather',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(_WeatherSummary weather) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location
          Row(
            children: [
              Icon(Icons.location_on_rounded,
                  size: 18, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                weather.location,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main weather card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A90D9), Color(0xFF357ABD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF357ABD).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_getIcon(weather.icon), size: 56, color: Colors.white),
                    const SizedBox(width: 16),
                    Text(
                      '${weather.temp.round()}°',
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  weather.conditions,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'H: ${weather.tempMax.round()}°',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      'L: ${weather.tempMin.round()}°',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Weather details row
          Row(
            children: [
              Expanded(
                  child: _buildDetailTile(
                Icons.water_drop_rounded,
                '${weather.humidity.round()}%',
                'weather_humidity'.tr(),
                const Color(0xFF4A90D9),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildDetailTile(
                Icons.air_rounded,
                '${weather.windSpeed.round()} km/h',
                'weather_wind'.tr(),
                const Color(0xFF00ACC1),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildDetailTile(
                Icons.umbrella_rounded,
                '${weather.precipProb.round()}%',
                'weather_rain'.tr(),
                const Color(0xFF5C6BC0),
              )),
            ],
          ),
          const SizedBox(height: 24),

          // Hourly forecast
          Text(
            'weather_hourly'.tr(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: weather.hourly.length,
              itemBuilder: (_, i) =>
                  _buildHourlyItem(weather.hourly[i], i == 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile(
      IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyItem(_HourlyData hour, bool isNow) {
    return Container(
      width: 64,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isNow ? AppTheme.primary : Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(
            isNow ? 'Now' : hour.time,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isNow ? Colors.white70 : Colors.grey[600],
            ),
          ),
          Icon(
            _getIcon(hour.icon),
            size: 22,
            color: isNow ? Colors.white : const Color(0xFF4A90D9),
          ),
          Text(
            '${hour.temp.round()}°',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isNow ? Colors.white : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}

/// Weather shimmer loading state
class _WeatherShimmer extends StatelessWidget {
  const _WeatherShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[50]!,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 16, width: 120, color: Colors.white),
            const SizedBox(height: 16),
            Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                )),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                  child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ))),
              const SizedBox(width: 12),
              Expanded(
                  child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ))),
              const SizedBox(width: 12),
              Expanded(
                  child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ))),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Internal data classes
class _WeatherSummary {
  final String location;
  final double temp;
  final double tempMax;
  final double tempMin;
  final String conditions;
  final String icon;
  final double humidity;
  final double windSpeed;
  final double precipProb;
  final List<_HourlyData> hourly;

  _WeatherSummary({
    required this.location,
    required this.temp,
    required this.tempMax,
    required this.tempMin,
    required this.conditions,
    required this.icon,
    required this.humidity,
    required this.windSpeed,
    required this.precipProb,
    required this.hourly,
  });
}

class _HourlyData {
  final String time;
  final double temp;
  final String icon;

  _HourlyData({required this.time, required this.temp, required this.icon});
}
