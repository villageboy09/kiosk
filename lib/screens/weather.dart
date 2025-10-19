// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart'; // Import the new package
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

// --- Data Models (Updated) ---
class WeatherData {
  final String locationName; // Simplified to a single, clean name
  final DailyForecast currentConditions;
  final List<DailyForecast> forecastDays;

  WeatherData({
    required this.locationName,
    required this.currentConditions,
    required this.forecastDays,
  });
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

class FarmingRecommendation {
  final String category;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String priority; // High, Medium, Low

  FarmingRecommendation({
    required this.category,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.priority,
  });
}

// --- Main Screen Widget ---
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  late Future<WeatherData> _weatherFuture;
  int _selectedIndex = 0;

  // --- UI Colors ---
  static const Color _backgroundColor = Color(0xFFF0F2F5);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textColorPrimary = Color(0xFF212121);
  static const Color _textColorSecondary = Color(0xFF757575);
  static const Color _accentColor = Color(0xFF2962FF);

  @override
  void initState() {
    super.initState();
    _weatherFuture = _fetchWeatherData();
  }

  // --- Data Fetching & Logic (Updated) ---
  Future<Position> _determinePosition() async {
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
    if (apiKey == null || apiKey.isEmpty) {
      // Also check if empty
      throw Exception("Weather API key is missing or empty in .env file.");
    }

    try {
      final position = await _determinePosition();
      final lat = position.latitude;
      final lon = position.longitude;

      // --- ROBUST GEOCODING BLOCK ---
      String locationName = "Current Location"; // Start with a fallback
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          // Combine city and district/state for a more complete name
          String city = place.locality ?? "";
          String area =
              place.subAdministrativeArea ?? place.administrativeArea ?? "";

          if (city.isNotEmpty && area.isNotEmpty) {
            locationName = "$city, $area";
          } else if (city.isNotEmpty) {
            locationName = city;
          } else if (area.isNotEmpty) {
            locationName = area;
          }
        }
      } catch (e) {
        print("Geocoding failed: $e. Using fallback location name.");
        // If geocoding fails, we just continue with the fallback name
      }
      // --- END ROBUST GEOCODING BLOCK ---

      final url = Uri.parse(
          'https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/$lat,$lon?unitGroup=metric&key=$apiKey&contentType=json');

      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception(
            'Weather API request failed. Status: ${response.statusCode}, Body: ${response.body}');
      }

      final data = json.decode(response.body);

      if (data['days'] == null || (data['days'] as List).isEmpty) {
        throw Exception(
            'Weather API returned no forecast data. Check your API key and account status.');
      }

      final List<DailyForecast> forecastDays =
          (data['days'] as List).map((dayData) {
        final List<HourlyForecast> hourly =
            (dayData['hours'] as List).map((hourData) {
          return HourlyForecast(
            time: hourData['datetime']?.substring(0, 5) ?? '00:00',
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
        locationName: locationName,
        currentConditions: forecastDays.first,
        forecastDays: forecastDays.take(7).toList(),
      );
    } catch (e) {
      print("Error in _fetchWeatherData: $e");
      // Re-throw the error so the FutureBuilder can display it in the UI
      rethrow;
    }
  }

  List<FarmingRecommendation> _generateRecommendations(WeatherData weather) {
    List<FarmingRecommendation> recommendations = [];
    final current = weather.currentConditions;
    final forecast = weather.forecastDays;

    if (current.precipprob > 60) {
      recommendations.add(FarmingRecommendation(
        category: 'Irrigation',
        title: 'Postpone Irrigation',
        description:
            'High chance of precipitation (${current.precipprob.round()}%) today. No need to irrigate; conserve water.',
        icon: Icons.water_drop_outlined,
        color: Colors.blue,
        priority: 'High',
      ));
    } else if (current.precipprob < 20 && current.humidity < 50) {
      recommendations.add(FarmingRecommendation(
        category: 'Irrigation',
        title: 'Irrigation Needed',
        description:
            'Low humidity (${current.humidity.round()}%) and no rain expected. Irrigate crops in the morning or evening for best results.',
        icon: Icons.water,
        color: Colors.orange,
        priority: 'High',
      ));
    }

    if (current.tempmax > 35) {
      recommendations.add(FarmingRecommendation(
        category: 'Temperature',
        title: 'High Temperature Alert',
        description:
            'Max temperature today is ${current.tempmax.round()}°C. Provide shade, use mulch to retain soil moisture, and avoid midday irrigation.',
        icon: Icons.thermostat,
        color: Colors.red,
        priority: 'High',
      ));
    }

    if (current.windspeed > 20) {
      recommendations.add(FarmingRecommendation(
        category: 'Wind',
        title: 'Avoid Spraying',
        description:
            'High wind speed of ${current.windspeed.round()} km/h. Avoid spraying pesticides or fertilizers to prevent drift. Check for crop damage.',
        icon: Icons.air,
        color: Colors.teal,
        priority: 'Medium',
      ));
    }

    final rainyDaysAhead =
        forecast.take(3).where((day) => day.precipprob > 50).length;
    if (rainyDaysAhead >= 2) {
      recommendations.add(FarmingRecommendation(
        category: 'Harvesting',
        title: 'Harvest Before Rain',
        description:
            'Rain is expected on $rainyDaysAhead of the next 3 days. Prioritize harvesting mature crops to prevent quality loss.',
        icon: Icons.cloud_done_sharp,
        color: Colors.green,
        priority: 'High',
      ));
    }

    if (current.humidity > 70 && current.temp > 20 && current.temp < 30) {
      recommendations.add(FarmingRecommendation(
        category: 'Pest Management',
        title: 'Pest & Disease Alert',
        description:
            'High humidity (${current.humidity.round()}%) and warm temperatures create ideal conditions for pests and fungal diseases. Scout your fields regularly.',
        icon: Icons.bug_report,
        color: Colors.deepOrange,
        priority: 'Medium',
      ));
    }

    recommendations.sort((a, b) {
      const priority = {'High': 0, 'Medium': 1, 'Low': 2};
      return priority[a.priority]!.compareTo(priority[b.priority]!);
    });

    return recommendations;
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

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Farming Advisory',
            style: GoogleFonts.lexend(
                color: _textColorPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              decoration: BoxDecoration(
                color: _cardColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                  )
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: _textColorPrimary,
                size: 20,
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<WeatherData>(
        future: _weatherFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerEffect();
          }
          if (snapshot.hasError) {
            return Center(
                child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}',
                      textAlign: TextAlign.center, style: GoogleFonts.lexend()),
                ],
              ),
            ));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No weather data available.'));
          }
          final weather = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _weatherFuture = _fetchWeatherData();
              });
            },
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildRecommendationsView(weather),
                _buildWeatherView(weather),
                _buildForecastView(weather),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _SlidingPillNavigationBar(
        selectedIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  // --- View Builders (Updated) ---
  Widget _buildRecommendationsView(WeatherData weather) {
    final recommendations = _generateRecommendations(weather);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildLocationCard(weather.locationName), // Updated
        const SizedBox(height: 24),
        Text('Today\'s Farming Advice',
            style: GoogleFonts.lexend(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _textColorPrimary)),
        const SizedBox(height: 8),
        Text('Plan your activities based on weather conditions.',
            style:
                GoogleFonts.lexend(fontSize: 15, color: _textColorSecondary)),
        const SizedBox(height: 20),
        ...recommendations.map((rec) => _buildRecommendationCard(rec)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildWeatherView(WeatherData weather) {
    final current = weather.currentConditions;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildCurrentWeatherCard(weather.locationName, current), // Updated
        const SizedBox(height: 24),
        _buildWeatherDetailsGrid(current),
        const SizedBox(height: 24),
        Text('Today\'s Hourly Forecast',
            style: GoogleFonts.lexend(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textColorPrimary)),
        const SizedBox(height: 12),
        _buildHourlyForecast(current.hours),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildForecastView(WeatherData weather) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 12),
        Text('7-Day Weather Forecast',
            style: GoogleFonts.lexend(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _textColorPrimary)),
        const SizedBox(height: 16),
        _buildDailyForecast(weather.forecastDays),
        const SizedBox(height: 20),
      ],
    );
  }

  // --- UI Component Builders (Redesigned & Updated) ---

  Widget _buildLocationCard(String locationName) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: _accentColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              locationName,
              style: GoogleFonts.lexend(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textColorPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(FarmingRecommendation rec) {
    Color priorityColor;
    switch (rec.priority) {
      case 'High':
        priorityColor = Colors.red.shade400;
        break;
      case 'Medium':
        priorityColor = Colors.orange.shade400;
        break;
      default:
        priorityColor = Colors.green.shade400;
        break;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: rec.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(rec.icon, color: rec.color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rec.title,
                        style: GoogleFonts.lexend(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: _textColorPrimary)),
                    const SizedBox(height: 4),
                    Text(rec.category,
                        style: GoogleFonts.lexend(
                            fontSize: 14,
                            color: _textColorSecondary,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  rec.priority,
                  style: GoogleFonts.lexend(
                      color: priorityColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              )
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1),
          ),
          Text(rec.description,
              style: GoogleFonts.lexend(
                  fontSize: 15, color: _textColorSecondary, height: 1.5)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                  onPressed: () {},
                  child: Text(
                    "Details",
                    style: GoogleFonts.lexend(
                        fontWeight: FontWeight.bold, color: _accentColor),
                  ))
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCurrentWeatherCard(String locationName, DailyForecast current) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF4C82E8), Color(0xFF2A5EDA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          Text(locationName,
              style: GoogleFonts.lexend(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(_getWeatherIcon(current.icon),
                  color: Colors.white, size: 70),
              const SizedBox(width: 16),
              Text('${current.temp.round()}°',
                  style: GoogleFonts.lexend(
                      fontSize: 80,
                      color: Colors.white,
                      fontWeight: FontWeight.w300)),
              Text('C',
                  style: GoogleFonts.lexend(
                      fontSize: 24,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w400)),
            ],
          ),
          Text(current.conditions,
              style: GoogleFonts.lexend(fontSize: 18, color: Colors.white70)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text('H: ${current.tempmax.round()}°',
                  style: GoogleFonts.lexend(color: Colors.white, fontSize: 16)),
              Text('L: ${current.tempmin.round()}°',
                  style: GoogleFonts.lexend(color: Colors.white, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetailsGrid(DailyForecast current) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildDetailCard('Humidity', '${current.humidity.round()}%',
            Icons.water_drop_outlined, Colors.blue),
        _buildDetailCard('Rain Chance', '${current.precipprob.round()}%',
            Icons.beach_access_outlined, Colors.indigo),
        _buildDetailCard('Wind Speed', '${current.windspeed.round()} km/h',
            Icons.air, Colors.teal),
        _buildDetailCard('Conditions', current.conditions,
            _getWeatherIcon(current.icon), Colors.orange),
      ],
    );
  }

  Widget _buildDetailCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const Spacer(),
          Text(value,
              style: GoogleFonts.lexend(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textColorPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  GoogleFonts.lexend(fontSize: 13, color: _textColorSecondary)),
        ],
      ),
    );
  }

  Widget _buildHourlyForecast(List<HourlyForecast> hours) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: hours.length,
        itemBuilder: (context, index) {
          final hour = hours[index];
          final isNow = index == 0;
          return Container(
            width: 80,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isNow ? _accentColor : _cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isNow
                      ? _accentColor.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(hour.time,
                    style: GoogleFonts.lexend(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isNow ? Colors.white : _textColorSecondary)),
                Icon(_getWeatherIcon(hour.icon),
                    size: 36, color: isNow ? Colors.white : _accentColor),
                Text('${hour.temp.round()}°',
                    style: GoogleFonts.lexend(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isNow ? Colors.white : _textColorPrimary)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyForecast(List<DailyForecast> days) {
    return Column(
      children: days.map((day) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            children: [
              Icon(_getWeatherIcon(day.icon), color: _accentColor, size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('EEEE').format(day.datetime),
                        style: GoogleFonts.lexend(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _textColorPrimary)),
                    const SizedBox(height: 2),
                    Text(day.conditions,
                        style: GoogleFonts.lexend(
                            fontSize: 13, color: _textColorSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  Icon(Icons.water_drop_outlined,
                      size: 16, color: Colors.blue.shade300),
                  const SizedBox(width: 4),
                  Text('${day.precipprob.round()}%',
                      style: GoogleFonts.lexend(
                          fontSize: 13, color: _textColorSecondary)),
                ],
              ),
              const SizedBox(width: 16),
              Text('${day.tempmax.round()}° / ${day.tempmin.round()}°',
                  style: GoogleFonts.lexend(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _textColorPrimary)),
            ],
          ),
        );
      }).toList(),
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
              height: 60,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20))),
          const SizedBox(height: 24),
          Container(
              height: 30,
              width: 200,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 16),
          Container(
              height: 20,
              width: 250,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 20),
          ...List.generate(
              3,
              (_) => Container(
                  height: 150,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20)))),
        ],
      ),
    );
  }
}

// --- CUSTOM WIDGET: Sliding Pill Navigation Bar ---
class _SlidingPillNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _SlidingPillNavigationBar({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final navItems = [
      {'icon': Icons.lightbulb_outline, 'label': 'Advice'},
      {'icon': Icons.wb_sunny_outlined, 'label': 'Weather'},
      {'icon': Icons.calendar_today_outlined, 'label': 'Forecast'},
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(50),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / navItems.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left: itemWidth * selectedIndex,
                top: 0,
                child: Container(
                  width: itemWidth,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: List.generate(navItems.length, (index) {
                  final item = navItems[index];
                  final isSelected = selectedIndex == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTap(index),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        height: 56,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item['icon'] as IconData,
                              color: isSelected
                                  ? const Color(0xFF2962FF)
                                  : const Color(0xFF757575),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['label'] as String,
                              style: GoogleFonts.lexend(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? const Color(0xFF2962FF)
                                    : const Color(0xFF757575),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
