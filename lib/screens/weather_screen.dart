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

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
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

    final data = json.decode(utf8.decode(response.bodyBytes));
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: AppTheme.backButton(context, color: AppTheme.appBarText),
        title: Text(
          'nav_weather'.tr(),
          style: AppTheme.appBarTitle,
        ),
        centerTitle: false,
        backgroundColor: AppTheme.appBarBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: FutureBuilder<_WeatherSummary>(
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
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Unable to load weather',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _weatherFuture = _fetchWeather();
                });
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(_WeatherSummary weather) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location Header
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                weather.location,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Main Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: AppTheme.headerGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_getIcon(weather.icon), size: 72, color: Colors.white),
                    const SizedBox(width: 24),
                    Text(
                      '${weather.temp.round()}°',
                      style: const TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  weather.conditions,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'H: ${weather.tempMax.round()}°',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Text(
                      'L: ${weather.tempMin.round()}°',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Weather metrics
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  Icons.water_drop_rounded,
                  '${weather.humidity.round()}%',
                  'weather_humidity'.tr(),
                  const Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  Icons.air_rounded,
                  '${weather.windSpeed.round()} km/h',
                  'weather_wind'.tr(),
                  const Color(0xFF0D9488),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  Icons.umbrella_rounded,
                  '${weather.precipProb.round()}%',
                  'weather_rain'.tr(),
                  const Color(0xFF4F46E5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Hourly
          Text(
            'weather_hourly'.tr(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: weather.hourly.length,
              itemBuilder: (_, i) =>
                  _buildHourlyCard(weather.hourly[i], i == 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyCard(_HourlyData hour, bool isNow) {
    return Container(
      width: 72,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isNow ? AppTheme.primary : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNow ? AppTheme.primary : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(
            isNow ? 'Now' : hour.time,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isNow ? Colors.white70 : AppTheme.textSecondary,
            ),
          ),
          Icon(
            _getIcon(hour.icon),
            size: 24,
            color: isNow ? Colors.white : AppTheme.textPrimary,
          ),
          Text(
            '${hour.temp.round()}°',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isNow ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherShimmer extends StatelessWidget {
  const _WeatherShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[50]!,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 20, width: 150, color: Colors.white),
            const SizedBox(height: 24),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: List.generate(
                3,
                (i) => Expanded(
                  child: Container(
                    height: 90,
                    margin: EdgeInsets.only(right: i == 2 ? 0 : 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
