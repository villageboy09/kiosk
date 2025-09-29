import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// --- Data Models ---
class WeatherData {
  final String address;
  final DailyForecast currentConditions;
  final List<DailyForecast> forecastDays;

  WeatherData(
      {required this.address,
      required this.currentConditions,
      required this.forecastDays});
}

class DailyForecast {
  final DateTime datetime;
  final double temp;
  final double tempmax;
  final double tempmin;
  final double humidity;
  final double precipprob;
  final double windspeed;
  final String conditions;
  final String icon;
  final List<HourlyForecast> hours;

  DailyForecast({
    required this.datetime,
    required this.temp,
    required this.tempmax,
    required this.tempmin,
    required this.humidity,
    required this.precipprob,
    required this.windspeed,
    required this.conditions,
    required this.icon,
    required this.hours,
  });
}

class HourlyForecast {
  final String time;
  final double temp;
  final String icon;

  HourlyForecast({required this.time, required this.temp, required this.icon});
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  late Future<WeatherData> _weatherFuture;

  @override
  void initState() {
    super.initState();
    _weatherFuture = _fetchWeatherData();
  }

  Future<Position> _determinePosition() async {
    // ... (Geolocation permission logic remains the same)
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services are disabled.');

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<WeatherData> _fetchWeatherData() async {
    final apiKey = dotenv.env['WEATHER_API_KEY'];
    if (apiKey == null) {
      throw Exception("Weather API key not found in .env file.");
    }

    final position = await _determinePosition();
    final lat = position.latitude;
    final lon = position.longitude;

    final url = Uri.parse(
        'https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/$lat,$lon?unitGroup=metric&key=$apiKey&contentType=json');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      final List<DailyForecast> forecastDays =
          (data['days'] as List).map((dayData) {
        final List<HourlyForecast> hourly =
            (dayData['hours'] as List).map((hourData) {
          return HourlyForecast(
            time: hourData['datetime'].substring(0, 5),
            temp: hourData['temp']?.toDouble() ?? 0.0,
            icon: hourData['icon'] ?? 'clear-day',
          );
        }).toList();

        return DailyForecast(
          datetime: DateTime.parse(dayData['datetime']),
          temp: dayData['temp']?.toDouble() ?? 0.0,
          tempmax: dayData['tempmax']?.toDouble() ?? 0.0,
          tempmin: dayData['tempmin']?.toDouble() ?? 0.0,
          humidity: dayData['humidity']?.toDouble() ?? 0.0,
          precipprob: dayData['precipprob']?.toDouble() ?? 0.0,
          windspeed: dayData['windspeed']?.toDouble() ?? 0.0,
          conditions: dayData['conditions'] ?? 'N/A',
          icon: dayData['icon'] ?? 'clear-day',
          hours: hourly,
        );
      }).toList();

      return WeatherData(
        address: data['resolvedAddress'],
        currentConditions: forecastDays.first,
        forecastDays: forecastDays.take(7).toList(), // Take a 7-day forecast
      );
    } else {
      throw Exception(
          'Failed to load weather data. Status code: ${response.statusCode}');
    }
  }

  IconData _getWeatherIcon(String iconName) {
    switch (iconName) {
      case 'snow':
        return Icons.ac_unit;
      case 'rain':
        return Icons.grain;
      case 'fog':
        return Icons.foggy;
      case 'wind':
        return Icons.air;
      case 'cloudy':
        return Icons.cloud_outlined;
      case 'partly-cloudy-day':
        return Icons.wb_cloudy_outlined;
      case 'partly-cloudy-night':
        return Icons.nightlight_round;
      case 'clear-day':
        return Icons.wb_sunny_outlined;
      case 'clear-night':
        return Icons.nights_stay_outlined;
      default:
        return Icons.wb_sunny_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('వాతావరణం (Weather)', style: GoogleFonts.lexend()),
      ),
      body: FutureBuilder<WeatherData>(
        future: _weatherFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerEffect();
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}',
                    textAlign: TextAlign.center));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No weather data available.'));
          }

          final weather = snapshot.data!;
          final current = weather.currentConditions;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _weatherFuture = _fetchWeatherData();
              });
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildCurrentWeatherCard(weather.address, current),
                const SizedBox(height: 24),
                _buildSectionHeader(
                    'ఈ రోజు గంటవారీ అంచనా (Today\'s Hourly Forecast)'),
                _buildHourlyForecast(current.hours),
                const SizedBox(height: 24),
                _buildSectionHeader('7-రోజుల అంచనా (7-Day Forecast)'),
                _buildDailyForecast(weather.forecastDays),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- UI Builder Widgets ---

  Widget _buildCurrentWeatherCard(String address, DailyForecast current) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF64B5F6), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Text(address.split(',').first,
                style: GoogleFonts.lexend(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_getWeatherIcon(current.icon),
                    color: Colors.white, size: 80),
                const SizedBox(width: 20),
                Text('${current.temp.round()}°C',
                    style: GoogleFonts.lexend(
                        fontSize: 72,
                        color: Colors.white,
                        fontWeight: FontWeight.w300)),
              ],
            ),
            Text(current.conditions,
                style: GoogleFonts.lexend(fontSize: 18, color: Colors.white70)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('H: ${current.tempmax.round()}°',
                    style: GoogleFonts.lexend(color: Colors.white)),
                Text('L: ${current.tempmin.round()}°',
                    style: GoogleFonts.lexend(color: Colors.white)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title,
        style: GoogleFonts.lexend(fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildHourlyForecast(List<HourlyForecast> hours) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: hours.length,
        itemBuilder: (context, index) {
          final hour = hours[index];
          return Card(
            child: Container(
              width: 80,
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text(hour.time, style: GoogleFonts.lexend(fontSize: 12)),
                  Icon(_getWeatherIcon(hour.icon), size: 32),
                  Text('${hour.temp.round()}°',
                      style: GoogleFonts.lexend(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyForecast(List<DailyForecast> days) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Icon(_getWeatherIcon(day.icon), color: Colors.blue[700]),
            title: Text(DateFormat('EEEE').format(day.datetime),
                style: GoogleFonts.lexend(fontWeight: FontWeight.bold)),
            subtitle: Text(day.conditions),
            trailing: Text('${day.tempmax.round()}° / ${day.tempmin.round()}°',
                style: GoogleFonts.lexend(fontSize: 16)),
          ),
        );
      },
    );
  }

  Widget _buildShimmerEffect() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
              height: 250,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 24),
          Container(height: 20, width: 200, color: Colors.white),
          const SizedBox(height: 8),
          Container(height: 120, color: Colors.white),
          const SizedBox(height: 24),
          Container(height: 20, width: 150, color: Colors.white),
          const SizedBox(height: 8),
          ...List.generate(
              4,
              (_) => Container(
                  height: 60,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.white)),
        ],
      ),
    );
  }
}
