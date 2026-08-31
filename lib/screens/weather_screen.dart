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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:cropsync/services/location_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> with SingleTickerProviderStateMixin {
  late Future<_WeatherSummary> _weatherFuture;
  // AI Integration state
  Map<String, dynamic>? _aiAdvisory;
  bool _isLoadingAI = false;
  String _lastRefreshedStr = "Never";
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    _weatherFuture = _fetchWeather();
  }


  Future<_WeatherSummary> _fetchWeather() async {
    final prefs = await SharedPreferences.getInstance();

    // Check cache first (30 mins validity)
    final cachedJson = prefs.getString('cached_weather_raw_api_data');
    final cachedLoc = prefs.getString('cached_weather_resolved_location');
    final cachedTimeStr = prefs.getString('cached_weather_timestamp');

    if (cachedJson != null && cachedLoc != null && cachedTimeStr != null) {
      final cachedTime = DateTime.tryParse(cachedTimeStr);
      if (cachedTime != null && DateTime.now().difference(cachedTime).inMinutes < 30) {
        try {
          final data = json.decode(cachedJson);
          final today = data['days'][0];
          final hours = (today['hours'] as List)
              .take(12)
              .map((h) => _HourlyData(
                    time: h['datetime']?.substring(0, 5) ?? '00:00',
                    temp: (h['temp'] ?? 0.0).toDouble(),
                    icon: h['icon'] ?? 'clear-day',
                  ))
              .toList();

          final dailyList = (data['days'] as List)
              .take(7)
              .map((d) => _DailyData(
                    date: d['datetime'] ?? '',
                    temp: (d['temp'] ?? 0.0).toDouble(),
                    tempMax: (d['tempmax'] ?? 0.0).toDouble(),
                    tempMin: (d['tempmin'] ?? 0.0).toDouble(),
                    conditions: d['conditions'] ?? 'N/A',
                    icon: d['icon'] ?? 'clear-day',
                    humidity: (d['humidity'] ?? 0.0).toDouble(),
                    windSpeed: (d['windspeed'] ?? 0.0).toDouble(),
                    precipProb: (d['precipprob'] ?? 0.0).toDouble(),
                  ))
              .toList();

          final summary = _WeatherSummary(
            location: cachedLoc,
            temp: (today['temp'] ?? 0.0).toDouble(),
            tempMax: (today['tempmax'] ?? 0.0).toDouble(),
            tempMin: (today['tempmin'] ?? 0.0).toDouble(),
            conditions: today['conditions'] ?? 'N/A',
            icon: today['icon'] ?? 'clear-day',
            humidity: (today['humidity'] ?? 0.0).toDouble(),
            windSpeed: (today['windspeed'] ?? 0.0).toDouble(),
            precipProb: (today['precipprob'] ?? 0.0).toDouble(),
            hourly: hours,
            daily: dailyList,
            latitude: prefs.getDouble('cached_weather_latitude') ?? 0.0,
            longitude: prefs.getDouble('cached_weather_longitude') ?? 0.0,
          );

          _loadOrFetchAIAdvisory(summary);
          return summary;
        } catch (_) {}
      }
    }

    final apiKey = dotenv.env['WEATHER_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("Weather API key missing");
    }

    // Get location
    final position = await LocationService.getCurrentPosition() ?? await _getPosition();
    final lat = position.latitude;
    final lon = position.longitude;

    // Get location name
    String locationName = "Current Location";
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        final subLocality = place.subLocality ?? "";
        final locality = place.locality ?? "";
        final district = place.subAdministrativeArea ?? "";
        
        List<String> parts = [];
        if (subLocality.isNotEmpty) {
          parts.add(subLocality);
        }
        if (locality.isNotEmpty) {
          parts.add(locality);
        } else if (district.isNotEmpty) {
          parts.add(district);
        }
        
        if (parts.isNotEmpty) {
          locationName = parts.join(", ");
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

    final dailyList = (data['days'] as List)
        .take(7)
        .map((d) => _DailyData(
              date: d['datetime'] ?? '',
              temp: (d['temp'] ?? 0.0).toDouble(),
              tempMax: (d['tempmax'] ?? 0.0).toDouble(),
              tempMin: (d['tempmin'] ?? 0.0).toDouble(),
              conditions: d['conditions'] ?? 'N/A',
              icon: d['icon'] ?? 'clear-day',
              humidity: (d['humidity'] ?? 0.0).toDouble(),
              windSpeed: (d['windspeed'] ?? 0.0).toDouble(),
              precipProb: (d['precipprob'] ?? 0.0).toDouble(),
            ))
        .toList();

    final summary = _WeatherSummary(
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
      daily: dailyList,
      latitude: lat,
      longitude: lon,
    );

    // Save to cache
    await prefs.setString('cached_weather_raw_api_data', jsonEncode(data));
    await prefs.setString('cached_weather_resolved_location', locationName);
    await prefs.setString('cached_weather_timestamp', DateTime.now().toIso8601String());
    await prefs.setDouble('cached_weather_latitude', lat);
    await prefs.setDouble('cached_weather_longitude', lon);

    // Try loading AI advisory after weather is loaded
    _loadOrFetchAIAdvisory(summary);

    return summary;
  }

  // Strategic AI Caching & Loader
  Future<void> _loadOrFetchAIAdvisory(_WeatherSummary weather, {bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = "ai_advisory_${weather.latitude}_${weather.longitude}";
    final timeKey = "ai_advisory_time_${weather.latitude}_${weather.longitude}";

    final cachedData = prefs.getString(cacheKey);
    final cachedTimeStr = prefs.getString(timeKey);

    DateTime? cachedTime;
    if (cachedTimeStr != null) {
      cachedTime = DateTime.tryParse(cachedTimeStr);
    }

    // Cache is valid for 6 hours
    final isCacheValid = cachedTime != null && 
        DateTime.now().difference(cachedTime).inHours < 6;

    if (!forceRefresh && cachedData != null && isCacheValid) {
      setState(() {
        _aiAdvisory = jsonDecode(cachedData);
        _lastRefreshTime = cachedTime;
        _lastRefreshedStr = _formatDurationSince(cachedTime!);
      });
      return;
    }

    // Force refresh or expired cache -> fetch from Nvidia NIM
    setState(() {
      _isLoadingAI = true;
    });

    final aiResult = await _fetchAIAdvisoryFromNvidia(weather);
    if (aiResult != null) {
      final nowStr = DateTime.now().toIso8601String();
      await prefs.setString(cacheKey, jsonEncode(aiResult));
      await prefs.setString(timeKey, nowStr);

      setState(() {
        _aiAdvisory = aiResult;
        _lastRefreshTime = DateTime.now();
        _lastRefreshedStr = "Just now";
        _isLoadingAI = false;
      });
    } else {
      setState(() {
        _isLoadingAI = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update AI Advisory. Using offline data.")),
        );
      }
    }
  }

  String _formatDurationSince(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes} mins ago";
    return "${diff.inHours} hours ago";
  }

  Future<Map<String, dynamic>?> _fetchAIAdvisoryFromNvidia(_WeatherSummary weather) async {
    final nvidiaKey = dotenv.env['NVIDIA_API_KEY'];
    if (nvidiaKey == null || nvidiaKey.isEmpty) {
      debugPrint("NVIDIA API key not set in environment");
      return null;
    }

    final locale = context.locale.languageCode;
    final langName = locale == 'te'
        ? 'Telugu'
        : locale == 'hi'
            ? 'Hindi'
            : 'English';

    final prompt = """
You are an expert AI Agricultural Advisor. Analyze the following real-time weather data and 7-day forecast for ${weather.location}:
- Current Temp: ${weather.temp.round()}°C (Max: ${weather.tempMax.round()}°C, Min: ${weather.tempMin.round()}°C)
- Current Humidity: ${weather.humidity.round()}%
- Current Wind Speed: ${weather.windSpeed.round()} km/h
- Current Precipitation Probability: ${weather.precipProb.round()}%
- 7-Day Forecast: ${weather.daily.map((d) => "${d.date}: ${d.conditions} (Temp: ${d.temp.round()}°C, Rain: ${d.precipProb.round()}%)").join(', ')}

Return a JSON object containing dynamic agricultural advisories and recommended crops suited for these conditions.

Crucially, generate advisories that are highly specific to the current point of time and the actual 7-day weather forecast (e.g. specific to the next 24-48 hours, or the current week's weather pattern like incoming rains, high temperature spikes, wind storms, or dry spells). Do NOT give generalized seasonal farming tips; focus on immediate action items for the farmer based on this week's exact weather changes.

You MUST output all the JSON values (specifically crop names, descriptions, soil types, water requirements, and advisories) in the $langName language. Ensure that the JSON keys remain exactly as defined (in English) but the string values are translated/written in $langName.

Keep all crop descriptions, soil types, and advisories highly concise (under 20 words each) to prevent truncating the JSON response.
Do NOT output any other text than the JSON block itself. Output raw JSON ONLY.
Format:
{
  "advisories": [
    "actionable farming tip 1",
    "actionable farming tip 2",
    "actionable farming tip 3"
  ],
  "crops": [
    {
      "name": "Crop name",
      "duration": "e.g., 90-100 days",
      "soilType": "preferred soil",
      "waterReq": "water level",
      "icon": "suitable emoji",
      "description": "why this crop is recommended now"
    }
  ]
}
""";

    try {
      final response = await http.post(
        Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $nvidiaKey',
        },
        body: jsonEncode({
          'model': 'nvidia/nemotron-3-ultra-550b-a55b',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.2,
          'max_tokens': 4000,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final resData = jsonDecode(utf8.decode(response.bodyBytes));
        final content = resData['choices'][0]['message']['content'] as String;
        
        // Clean markdown JSON wrapper
        String cleaned = content;
        if (cleaned.contains('```json')) {
          cleaned = cleaned.split('```json').last;
        }
        if (cleaned.contains('```')) {
          cleaned = cleaned.split('```').first;
        }
        
        return jsonDecode(cleaned.trim()) as Map<String, dynamic>;
      } else {
        debugPrint("Nvidia API returned status code ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error calling Nvidia API: $e");
    }
    return null;
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: AppTheme.backButton(context, color: AppTheme.appBarText),
        title: Text(
          'nav_weather'.tr(),
          style: AppTheme.appBarTitle,
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.hardEdge,
                  child: InkWell(
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('cached_weather_raw_api_data');
                      await prefs.remove('cached_weather_resolved_location');
                      await prefs.remove('cached_weather_timestamp');
                      setState(() {
                        _weatherFuture = _fetchWeather();
                      });
                    },
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.appBarText.withValues(alpha: 0.1),
                      ),
                      child: const Icon(
                        Icons.sync_rounded,
                        size: 20,
                        color: AppTheme.appBarText,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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

  void _showBottomSheet(BuildContext context, String title, Widget content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
              ),
              Flexible(child: content),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _AnimatedIcon(
                  child: Icon(icon, color: color, size: 28),
                ),
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(_WeatherSummary weather) {
    final currentMonth = DateTime.now().month;
    final seasonInfo = _getSeasonInfo(currentMonth);
    final insights = _analyzeWeatherPatterns(weather);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Daily Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today\'s Weather',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${weather.temp.round()}°',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w200,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          weather.conditions,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'H: ${weather.tempMax.round()}°  L: ${weather.tempMin.round()}°',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                // Right Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          weather.location,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: RepaintBoundary(
                        child: Lottie.network(
                          _getLottieUrl(weather.icon),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(_getIcon(weather.icon), size: 64, color: const Color(0xFFFBBF24));
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Weather metrics grid
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
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  Icons.air_rounded,
                  '${weather.windSpeed.round()} km/h',
                  'weather_wind'.tr(),
                  const Color(0xFF0D9488),
                ),
              ),
              const SizedBox(width: 10),
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
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            childAspectRatio: 0.95,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildSummaryCard(
                title: 'Weekly Forecast',
                subtitle: '7-day weather outlook',
                icon: Icons.calendar_month_rounded,
                color: const Color(0xFF3B82F6),
                onTap: () {
                  _showBottomSheet(
                    context,
                    '7-Day Forecast',
                    SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF), // soft blue
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFDBEAFE)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, color: Color(0xFF3B82F6), size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Latest update: ${DateFormat('MMM d, yyyy - h:mm a').format(DateTime.now())}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF1D4ED8),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _generateWeeklySummaryText(weather.daily),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF1E3A8A),
                                    height: 1.6,
                                  ),
                                  textAlign: TextAlign.justify,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              _buildSummaryCard(
                title: 'Seasonal Advisory',
                subtitle: 'Current season: ${seasonInfo.name}',
                icon: Icons.eco_rounded,
                color: const Color(0xFF10B981),
                onTap: () {
                  _showBottomSheet(context, 'Seasonal Advisory', _buildSeasonalTab(weather, seasonInfo));
                },
              ),
              _buildSummaryCard(
                title: 'Crops to Grow',
                subtitle: 'Recommended crops for this season',
                icon: Icons.agriculture_rounded,
                color: const Color(0xFFF59E0B),
                onTap: () {
                  _showBottomSheet(context, 'Crops to Grow', _buildCropsTab(weather, seasonInfo));
                },
              ),
              _buildSummaryCard(
                title: 'Weather Insights',
                subtitle: 'Patterns & AI analysis',
                icon: Icons.insights_rounded,
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  _showBottomSheet(context, 'Weather Insights', _buildPatternsTab(insights));
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _generateWeeklySummaryText(List<_DailyData> daily) {
    if (daily.isEmpty) return 'No weekly forecast available.';

    double avgMax = 0;
    double avgMin = 0;
    Map<String, int> conditionsCount = {};
    double avgPrecip = 0;

    for (var day in daily) {
      avgMax += day.tempMax;
      avgMin += day.tempMin;
      avgPrecip += day.precipProb;
      conditionsCount[day.conditions] = (conditionsCount[day.conditions] ?? 0) + 1;
    }

    avgMax /= daily.length;
    avgMin /= daily.length;
    avgPrecip /= daily.length;

    String mostCommonCondition = '';
    int maxCount = 0;
    conditionsCount.forEach((condition, count) {
      if (count > maxCount) {
        maxCount = count;
        mostCommonCondition = condition;
      }
    });

    String precipText = '';
    if (avgPrecip > 50) {
      precipText = ' Expect significant rainfall, so plan agricultural activities carefully.';
    } else if (avgPrecip > 20) {
      precipText = ' There is a moderate chance of rain.';
    } else {
      precipText = ' The week looks mostly dry.';
    }

    return 'The upcoming week is expected to be mostly ${mostCommonCondition.toLowerCase()} with average highs around ${avgMax.round()}°C and lows near ${avgMin.round()}°C.$precipText';
  }

  Widget _buildAISettingsCard(_WeatherSummary weather) {
    final hasKey = dotenv.env['NVIDIA_API_KEY'] != null && dotenv.env['NVIDIA_API_KEY']!.isNotEmpty;
    if (!hasKey) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology_rounded, color: Color(0xFF16A34A), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "NVIDIA AI Advisor Active",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF14532D)),
                ),
                Text(
                  "Refreshed: $_lastRefreshedStr",
                  style: const TextStyle(fontSize: 12, color: Color(0xFF166534)),
                ),
              ],
            ),
          ),
          _isLoadingAI
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A)),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF16A34A)),
                  onPressed: () {
                    // Prevent button spamming: limit refresh to once per 15 seconds locally
                    if (_lastRefreshTime != null && 
                        DateTime.now().difference(_lastRefreshTime!).inSeconds < 15) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please wait a moment before refreshing again.")),
                      );
                      return;
                    }
                    _loadOrFetchAIAdvisory(weather, forceRefresh: true);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildSeasonalTab(_WeatherSummary weather, _SeasonInfo season) {
    List<String> activeAdvisories = season.advisories;
    if (_aiAdvisory != null && _aiAdvisory!['advisories'] != null) {
      activeAdvisories = List<String>.from(_aiAdvisory!['advisories']);
    }

    String advisorySummary = activeAdvisories.isNotEmpty 
        ? activeAdvisories.join(' ') 
        : 'No specific advisories at this time.';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAISettingsCard(weather),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4), // soft green
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDCFCE7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.eco_rounded, color: Color(0xFF10B981), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Latest update: ${DateFormat('MMM d, yyyy - h:mm a').format(DateTime.now())}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF047857),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Season: ${season.name} (${season.duration})\n\n${season.description}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF065F46),
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFFA7F3D0)),
                const SizedBox(height: 12),
                Text(
                  'Advisory:\n$advisorySummary',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF065F46),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.justify,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSowingDate(String seasonName) {
    final lower = seasonName.toLowerCase();
    if (lower.contains('kharif') || lower.contains('ఖరీఫ్') || lower.contains('खरीफ')) {
      return 'June - July';
    } else if (lower.contains('rabi') || lower.contains('రబీ') || lower.contains('रबी')) {
      return 'October - November';
    } else {
      return 'March - April';
    }
  }

  Widget _buildCropsTab(_WeatherSummary weather, _SeasonInfo season) {
    // Dynamic crop recommendations (AI or local fallback)
    List<_CropRecommendation> activeCrops = season.recommendedCrops;
    if (_aiAdvisory != null && _aiAdvisory!['crops'] != null) {
      try {
        final list = _aiAdvisory!['crops'] as List;
        activeCrops = list.map((item) => _CropRecommendation(
          name: item['name']?.toString() ?? 'Crop',
          duration: item['duration']?.toString() ?? 'Dynamic',
          soilType: item['soilType']?.toString() ?? 'Flexible',
          waterReq: item['waterReq']?.toString() ?? 'Moderate',
          icon: item['icon']?.toString() ?? '🌱',
          description: item['description']?.toString() ?? '',
        )).toList();
      } catch (_) {}
    }

    final sowingDate = _getSowingDate(season.name);

    return GridView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: activeCrops.length,
      itemBuilder: (context, index) {
        final crop = activeCrops[index];
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  crop.icon,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                crop.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Sowing:\n$sowingDate',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }



  Widget _buildPatternsTab(List<_WeatherInsight> insights) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Smart Weather Pattern Insights',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Dynamic agricultural suggestions parsed from forecast models.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: insights.length,
            itemBuilder: (context, index) {
              final insight = insights[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: insight.color.withValues(alpha: 0.15)),
                  boxShadow: [
                    BoxShadow(
                      color: insight.color.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: insight.color.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(insight.icon, color: insight.color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  insight.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: insight.color,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: insight.color.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  insight.severity,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: insight.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            insight.description,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _AnimatedIcon(
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }



  _SeasonInfo _getSeasonInfo(int month) {
    final locale = context.locale.languageCode;

    if (month >= 6 && month <= 10) {
      // Kharif
      if (locale == 'te') {
        return _SeasonInfo(
          name: 'ఖరీఫ్ (వర్షాకాలం)',
          duration: 'జూన్ - అక్టోబర్',
          description: 'అధిక ఉష్ణోగ్రతలు మరియు సమృద్ధిగా వర్షపాతం ఉంటుంది. నీటి ఆధారిత పంటలకు అనుకూలం.',
          advisories: [
            'భారీ వర్షాల సమయంలో నీరు నిల్వ ఉండకుండా పొలంలో సరైన డ్రైనేజీ కాలువలను ఏర్పాటు చేయండి.',
            '24 గంటల్లో భారీ వర్షం కురిసే అవకాశం ఉంటే పురుగుమందులు చల్లడం లేదా ఎరువులు వేయడం వాయిదా వేయండి.',
            'అధిక తేమ పరిస్థితులు శిలీంధ్రాల వ్యాప్తికి దారితీస్తాయి. ఆకులను క్రమం తప్పకుండా గమనించండి.',
            'పోషకాల కోసం పోటీని నివారించడానికి పొలాల గట్లను శుభ్రం చేయండి మరియు సకాలంలో కలుపు తీయండి.',
          ],
          recommendedCrops: [
            _CropRecommendation(
              name: 'వరి (ప్యాడీ)',
              duration: '120-150 రోజులు',
              soilType: 'మట్టి లేదా క్లే లోమ్',
              waterReq: 'అధికం (నిల్వ నీరు)',
              icon: '🌾',
              description: 'వర్షాకాలపు ప్రధాన ఆహార ధాన్యం. తేమను నిలుపుకునే జిగురు మట్టిలో బాగా పెరుగుతుంది.',
            ),
            _CropRecommendation(
              name: 'మొక్కజొన్న (కార్న్)',
              duration: '90-110 రోజులు',
              soilType: 'ఇసుకతో కూడిన మోరప నేలలు',
              waterReq: 'మధ్యస్థం',
              icon: '🌽',
              description: 'వెచ్చని వాతావరణం అవసరం. నీరు నిల్వ ఉండే నేలలకు ఇది సున్నితమైనది.',
            ),
            _CropRecommendation(
              name: 'పత్తి (కాటన్)',
              duration: '150-180 రోజులు',
              soilType: 'నల్ల రేగడి నేలలు',
              waterReq: 'మధ్యస్థం',
              icon: '☁️',
              description: 'ఎండ మరియు నల్ల రేగడి నేలలు అవసరమయ్యే వాణిజ్య పంట.',
            ),
            _CropRecommendation(
              name: 'సోయాబీన్',
              duration: '100-120 రోజులు',
              soilType: 'సోయాబీన్ నేలలు',
              waterReq: 'మధ్యస్థం',
              icon: '🌱',
              description: 'నత్రజని స్థిరీకరణను పెంచి, నేల ఆరోగ్యాన్ని మెరుగుపరిచే పంట.',
            ),
          ],
        );
      } else if (locale == 'hi') {
        return _SeasonInfo(
          name: 'खरीफ (मानसून)',
          duration: 'जून - अक्टूबर',
          description: 'उच्च तापमान और प्रचुर वर्षा की विशेषता। पानी वाली फसलों के लिए आदर्श।',
          advisories: [
            'भारी बारिश के दौरान जलभराव को रोकने के लिए खेतों में उचित जल निकासी की व्यवस्था करें।',
            'यदि 24 घंटे के भीतर भारी बारिश का अनुमान हो तो कीटनाशकों या उर्वरकों का छिड़काव स्थगित करें।',
            'उच्च आर्द्रता की स्थिति कवक के प्रकोप को बढ़ावा देती है। पत्तियों का नियमित निरीक्षण करें।',
            'पोषक तत्वों की प्रतिस्पर्धा से बचने के लिए समय पर निराई-गुड़ाई करें।',
          ],
          recommendedCrops: [
            _CropRecommendation(
              name: 'धान (चावल)',
              duration: '120-150 दिन',
              soilType: 'मटियार या दोमट मिट्टी',
              waterReq: 'उच्च (खड़ा पानी)',
              icon: '🌾',
              description: 'मानसून की मुख्य फसल। पानी रोकने वाली दोमट या मटियार मिट्टी में सबसे अच्छी होती है।',
            ),
            _CropRecommendation(
              name: 'मक्का',
              duration: '90-110 दिन',
              soilType: 'बलुई दोमट मिट्टी',
              waterReq: 'मध्यम',
              icon: '🌽',
              description: 'गर्म मौसम की आवश्यकता। जलभराव के प्रति संवेदनशील।',
            ),
            _CropRecommendation(
              name: 'कपास',
              duration: '150-180 दिन',
              soilType: 'काली मिट्टी',
              waterReq: 'मध्यम',
              icon: '☁️',
              description: 'काली मिट्टी में प्रचुर धूप and मध्यम वर्षा के साथ उगने वाली नकदी फसल।',
            ),
            _CropRecommendation(
              name: 'सोयाबीन',
              duration: '100-120 दिन',
              soilType: 'दोमट मिट्टी',
              waterReq: 'मध्यम',
              icon: '🌱',
              description: 'मिट्टी की उर्वरता बढ़ाने और नाइट्रोजन स्थिरीकरण करने वाली फसल।',
            ),
          ],
        );
      } else {
        return _SeasonInfo(
          name: 'Kharif (Monsoon)',
          duration: 'June - October',
          description: 'Characterized by high temperatures and plentiful rainfall. Ideal for water-intensive crops.',
          advisories: [
            'Ensure proper drainage channels in fields to prevent waterlogging during heavy downpours.',
            'Postpone spraying pesticides or applying fertilizers if heavy rain is forecasted within 24 hours.',
            'High humidity conditions favor fungal outbreaks. Inspect leaves regularly for spots or rust.',
            'Clean field bunds and carry out timely weeding to avoid nutrient competition.',
          ],
          recommendedCrops: [
            _CropRecommendation(
              name: 'Paddy (Rice)',
              duration: '120-150 Days',
              soilType: 'Clayey or Clay Loam',
              waterReq: 'High (Flooded / standing water)',
              icon: '🌾',
              description: 'The staple grain of the monsoon season. Thrives in heavy clay soil that retains moisture.',
            ),
            _CropRecommendation(
              name: 'Maize (Corn)',
              duration: '90-110 Days',
              soilType: 'Well-drained Sandy Loam',
              waterReq: 'Moderate',
              icon: '🌽',
              description: 'Requires warm weather and well-aerated soils. Highly sensitive to waterlogging.',
            ),
            _CropRecommendation(
              name: 'Cotton',
              duration: '150-180 Days',
              soilType: 'Deep Black Soil (Regur)',
              waterReq: 'Moderate (Dry climate during ripening)',
              icon: '☁️',
              description: 'Cash crop requiring bright sunshine, moderate rainfall, and rich black soil with good moisture holding capacity.',
            ),
            _CropRecommendation(
              name: 'Soybean',
              duration: '100-120 Days',
              soilType: 'Loamy Soil',
              waterReq: 'Moderate',
              icon: '🌱',
              description: 'An excellent nitrogen-fixing crop that improves soil health and yields high-protein seeds.',
            ),
          ],
        );
      }
    } else if (month == 11 || month == 12 || month <= 2) {
      // Rabi
      if (locale == 'te') {
        return _SeasonInfo(
          name: 'రబీ (శీతాకాలం)',
          duration: 'నవంబర్ - ఫిబ్రవరి',
          description: 'శీతాకాలంలో విత్తుతారు మరియు వసంతకాలంలో కోస్తారు. చల్లని వాతావరణం మరియు పరిమిత నీటి పారుదల అవసరం.',
          advisories: [
            'నేల తేమను నిశితంగా గమనించండి; గోధుమలో కిరీటం వేరు ఏర్పడే దశల వద్ద ఖచ్చితంగా నీరు పెట్టండి.',
            'పౌడరీ మిల్డో వ్యాప్తిని అరికట్టడానికి ఉదయం పడే మంచుపై నిఘా ఉంచండి. అవసరమైన శీలీంద్ర నాశిని పిచికారీ చేయండి.',
            'డ్రిప్ లేదా స్ప్రింక్లర్ పద్ధతుల ద్వారా నీటిని ఆదా చేయండి.',
            'పంట వేసిన మొదటి 30-45 రోజులలో పొలంలో కలుపు లేకుండా చూసుకోండి.',
          ],
          recommendedCrops: [
            _CropRecommendation(
              name: 'గోధుమ (వీట్)',
              duration: '120-140 రోజులు',
              soilType: ' సారవంతమైన క్లే లోమ్',
              waterReq: 'మధ్యస్థం (4-6 నీటి తడులు)',
              icon: '🌾',
              description: 'శీతాకాలపు ప్రధాన తృణధాన్యం. పెరిగేటప్పుడు చలి, పక్వానికి వచ్చేటప్పుడు ఎండ అవసరం.',
            ),
            _CropRecommendation(
              name: 'శనగలు (బెంగాల్ గ్రామ్)',
              duration: '100-110 రోజులు',
              soilType: 'తేలికపాటి నుండి మధ్యస్థ లోమ్',
              waterReq: 'అల్పం (కరువును తట్టుకుంటుంది)',
              icon: '🧆',
              description: 'నేలలోని తేమను ఉపయోగించుకుని తక్కువ నీటితో పండే పప్పుధాన్యపు పంట.',
            ),
            _CropRecommendation(
              name: 'ఆవాలు (మస్టర్డ్)',
              duration: '110-130 రోజులు',
              soilType: 'ఇసుక లోమ్ నుండి క్లే లోమ్',
              waterReq: 'అల్పం నుండి మధ్యస్థం',
              icon: '🌼',
              description: 'తక్కువ ఉష్ణోగ్రతలను మరియు పొడి వాతావరణాన్ని తట్టుకుని పండే నూనెగింజల పంట.',
            ),
            _CropRecommendation(
              name: 'బంగాళాదుంప (పొటాటో)',
              duration: '90-120 రోజులు',
              soilType: 'సడలైన ఇసుక లోమ్ నేలలు',
              waterReq: 'మధ్యస్థం',
              icon: '🥔',
              description: 'దుంపలు బాగా పెరగడానికి సేంద్రియ ఎరువులు మరియు సడలైన నేల అవసరమయ్యే పంట.',
            ),
          ],
        );
      } else if (locale == 'hi') {
        return _SeasonInfo(
          name: 'रबी (शीतकाल)',
          duration: 'नवंबर - फरवरी',
          description: 'सर्दियों में बोई जाने वाली और वसंत में काटी जाने वाली फसलें। ठंडी जलवायु की आवश्यकता।',
          advisories: [
            'मिट्टी की नमी की बारीकी से निगरानी करें; गेहूं में ताज जड़ बनने की नाजुक अवस्था में सिंचाई करें।',
            'सुबह की ओस/पाला से चूर्णिल आसिता (पाउडर माइल्ड्यू) का खतरा रहता है। अनुशंसित कवकनाशी का छिड़काव करें।',
            'टपक सिंचाई (ड्रिप) या स्प्रिंकलर का उपयोग करके पानी की बचत करें।',
            'फसलों की वृद्धि के शुरुआती 30-45 दिनों में खेत को खरपतवार मुक्त रखें।',
          ],
          recommendedCrops: [
            _CropRecommendation(
              name: 'गेहूं',
              duration: '120-140 दिन',
              soilType: 'उर्वरक दोमट मिट्टी',
              waterReq: 'मध्यम (4-6 सिंचाई)',
              icon: '🌾',
              description: 'सर्दियों की प्रमुख अनाज फसल। ठंडे मौसम और पकने के समय खिली धूप की जरूरत।',
            ),
            _CropRecommendation(
              name: 'चना',
              duration: '100-110 दिन',
              soilType: 'हल्की से मध्यम दोमट',
              waterReq: 'कम (सूखा-सहनशील)',
              icon: '🧆',
              description: 'कम सिंचाई में मिट्टी की अवशिष्ट नमी पर उगने वाली दलहनी फसल।',
            ),
            _CropRecommendation(
              name: 'सरसों',
              duration: '110-130 दिन',
              soilType: 'बलुई दोमट मिट्टी',
              waterReq: 'कम से मध्यम',
              icon: '🌼',
              description: 'सर्दियों की शुष्क परिस्थितियों को सहन करने वाली तिलहनी फसल।',
            ),
            _CropRecommendation(
              name: 'आलू',
              duration: '90-120 दिन',
              soilType: 'भुरभुरी बलुई दोमट',
              waterReq: 'मध्यम (हल्की सिंचाई)',
              icon: '🥔',
              description: 'भुरभुरी और पोषक तत्वों से भरपूर मिट्टी में उगने वाली कंद फसल।',
            ),
          ],
        );
      } else {
        return _SeasonInfo(
          name: 'Rabi (Winter)',
          duration: 'November - February',
          description: 'Sown in winter and harvested in spring. Requires cool climate and moderate irrigation.',
          advisories: [
            'Monitor soil moisture levels closely; irrigate during critical stages like crown root initiation in wheat.',
            'Watch out for morning dew/frost which can trigger powdery mildew. Spray recommended fungicides proactively.',
            'Optimize water usage using drip or sprinkler irrigation to conserve groundwater.',
            'Keep fields free from weeds during the first 30-45 days of crop growth.',
          ],
          recommendedCrops: [
            _CropRecommendation(
              name: 'Wheat',
              duration: '120-140 Days',
              soilType: 'Fertile Clayey Loam',
              waterReq: 'Moderate (Requires 4-6 timely irrigations)',
              icon: '🌾',
              description: 'The premier winter cereal crop. Requires a cool growing period and bright sunny weather at ripening.',
            ),
            _CropRecommendation(
              name: 'Chickpea (Bengal Gram)',
              duration: '100-110 Days',
              soilType: 'Light to Medium Loam',
              waterReq: 'Low (Drought-resistant)',
              icon: '🧆',
              description: 'A pulse crop that thrives in residual soil moisture and cool winter nights without needing excessive irrigation.',
            ),
            _CropRecommendation(
              name: 'Mustard',
              duration: '110-130 Days',
              soilType: 'Sandy Loam to Clay Loam',
              waterReq: 'Low to Moderate',
              icon: '🌼',
              description: 'An oilseed crop that tolerates dry winter conditions and adds beautiful yellow flowers to the landscape.',
            ),
            _CropRecommendation(
              name: 'Potato',
              duration: '90-120 Days',
              soilType: 'Loose, Well-aerated Sandy Loam',
              waterReq: 'Moderate (Frequent light waterings)',
              icon: '🥔',
              description: 'High-yielding tuber crop that needs loose, organic-rich soil to allow tubers to grow freely.',
            ),
          ],
        );
      }
    } else {
      // Zaid
      if (locale == 'te') {
        return _SeasonInfo(
          name: 'జైద్ (వేసవి కాలం)',
          duration: 'మార్చి - మే',
          description: 'రబీ మరియు ఖరీఫ్ మధ్య స్వల్ప కాల వేసవి కాలం. వెచ్చని పొడి వాతావరణం మరియు నిరంతర నీటి తడులు అవసరం.',
          advisories: [
            'ఆవిరి నష్టాలను నివారించడానికి ఉదయం లేదా సాయంత్రం వేళల్లో తరచుగా నీరు పెట్టండి.',
            'నేల తేమను కాపాడటానికి మరియు కలుపు నివారణకు ఎండుగడ్డితో మల్చింగ్ చేయండి.',
            'వేడి వాతావరణంలో వేగంగా వృద్ధి చెండే తెల్లదోమలు, తామర పురుగులపై నిఘా ఉంచండి.',
            'తాజాదనం కోల్పోకుండా పుచ్చకాయలు మరియు గుమ్మడికాయలను ఉదయమే కోయండి.',
          ],
          recommendedCrops: [
            _CropRecommendation(
              name: 'పుచ్చకాయ / కర్బూజ',
              duration: '80-90 రోజులు',
              soilType: 'ఇసుక నేలలు / నదీ పడకలు',
              waterReq: 'మధ్యస్థం (క్రమం తప్పకుండా తేలికపాటి తడులు)',
              icon: '🍉',
              description: 'వేడి వాతావరణంలో ఇసుక నేలల్లో బాగా పండే తీపి పండ్లు.',
            ),
            _CropRecommendation(
              name: 'దోసకాయ (కుకుంబర్)',
              duration: '60-70 రోజులు',
              soilType: 'సేంద్రియ పదార్థాలు గల ఇసుక లోమ్',
              waterReq: 'మధ్యస్థం',
              icon: '🥒',
              description: 'వేగంగా పెరిగే వేసవి కూరగాయ. తీగెలను పైకి పాకించడం ద్వారా కాయలు శుభ్రంగా ఉంటాయి.',
            ),
            _CropRecommendation(
              name: 'పెసర (గ్రీన్ గ్రామ్)',
              duration: '65-75 రోజులు',
              soilType: 'నీరు నిల్వ ఉండని లోమీ నేలలు',
              waterReq: 'అల్పం',
              icon: '🌱',
              description: 'త్వరగా పండే పప్పుధాన్యపు పంట. ఇది నేలలో నత్రజనిని స్థిరీకరిస్తుంది.',
            ),
            _CropRecommendation(
              name: 'పొద్దుతిరుగుడు (సన్ ఫ్లవర్)',
              duration: '90-100 రోజులు',
              soilType: 'సారవంతమైన లోమ్ నేలలు',
              waterReq: 'మధ్యస్థం',
              icon: '🌻',
              description: 'కరువును తట్టుకునే నూనెగింజల పంట. పూలు సూర్యుని వైపు తిరుగుతాయి.',
            ),
          ],
        );
      } else if (locale == 'hi') {
        return _SeasonInfo(
          name: 'जायद (गर्मी)',
          duration: 'मार्च - मई',
          description: 'रबी और खरीफ के बीच की छोटी गर्मी की ऋतु। फसलों को निरंतर सिंचाई की आवश्यकता।',
          advisories: [
            'वाष्पीकरण से बचने के लिए सुबह या शाम के समय बार-बार सिंचाई करें।',
            'मिट्टी की नमी बनाए रखने और खरपतवार रोकने के लिए पुआल की मल्चिंग करें।',
            'गर्म मौसम में तेजी से बढ़ने वाले रसचूषक कीटों (जैसे सफेद मक्खी) पर नजर रखें।',
            'ताजगी बनाए रखने के लिए तरबूज और खरबूज की तुड़ाई सुबह के समय ही करें।',
          ],
          recommendedCrops: [
            _CropRecommendation(
              name: 'तरबूज / खरबूज',
              duration: '80-90 दिन',
              soilType: 'बलुई / रेतीली नदी तट की मिट्टी',
              waterReq: 'मध्यम (नियमित हल्की सिंचाई)',
              icon: '🍉',
              description: 'गर्म मौसम के फल जो रेतीली मिट्टी और तेज धूप में अच्छे होते हैं।',
            ),
            _CropRecommendation(
              name: 'खीरा',
              duration: '60-70 दिन',
              soilType: 'कार्बनिक पदार्थों से भरपूर बलुई दोमट',
              waterReq: 'मध्यम',
              icon: '🥒',
              description: 'तेजी से बढ़ने वाली गर्मी की सब्जी। मचान विधि से फल साफ रहते हैं।',
            ),
            _CropRecommendation(
              name: 'मूंग',
              duration: '65-75 दिन',
              soilType: 'अच्छी जल निकासी वाली दोमट मिट्टी',
              waterReq: 'कम',
              icon: '🌱',
              description: 'जल्दी पकने वाली दलहनी फसल जो मिट्टी में नाइट्रोजन बढ़ाती है।',
            ),
            _CropRecommendation(
              name: 'सूरजमुखी',
              duration: '90-100 दिन',
              soilType: 'गहरी उपजाऊ दोमट मिट्टी',
              waterReq: 'मध्यम',
              icon: '🌻',
              description: 'सूखा-सहनशील तिलहनी फसल जिसके फूल सूर्य की दिशा में घूमते हैं।',
            ),
          ],
        );
      } else {
        return _SeasonInfo(
          name: 'Zaid (Summer)',
          duration: 'March - May',
          description: 'Short summer season between Rabi and Kharif. Crops need warm dry weather and continuous irrigation.',
          advisories: [
            'Irrigate frequently during morning or evening hours to prevent high evaporation losses.',
            'Use mulching (straw or plastic sheets) to conserve soil moisture and suppress summer weeds.',
            'Watch out for sucking pests like whiteflies and thrips, which multiply rapidly in warm weather.',
            'Harvest melons and gourds in the morning to retain maximum freshness and shelf life.',
          ],
          recommendedCrops: [
            _CropRecommendation(
              name: 'Watermelon / Musk Melon',
              duration: '80-90 Days',
              soilType: 'Sandy / Alluvial Riverbeds',
              waterReq: 'Moderate (Regular light watering)',
              icon: '🍉',
              description: 'Delicious hot-weather fruits that thrive in sandy soils with warm days and cool nights.',
            ),
            _CropRecommendation(
              name: 'Cucumber',
              duration: '60-70 Days',
              soilType: 'Sandy Loam rich in organic matter',
              waterReq: 'Moderate',
              icon: '🥒',
              description: 'Fast-growing summer vegetable. Trellising helps keep fruits clean and disease-free.',
            ),
            _CropRecommendation(
              name: 'Moong Bean (Green Gram)',
              duration: '65-75 Days',
              soilType: 'Well-drained Loamy Soil',
              waterReq: 'Low',
              icon: '🌱',
              description: 'Quick-maturing legume that enriches the soil with nitrogen and fits perfectly in the summer window.',
            ),
            _CropRecommendation(
              name: 'Sunflower',
              duration: '90-100 Days',
              soilType: 'Deep, Fertile Loam',
              waterReq: 'Moderate',
              icon: '🌻',
              description: 'Drought-tolerant oilseed crop with bright yellow heads that follow the path of the sun.',
            ),
          ],
        );
      }
    }
  }

  List<_WeatherInsight> _analyzeWeatherPatterns(_WeatherSummary weather) {
    List<_WeatherInsight> insights = [];

    // 1. Rain Analysis
    double maxRainProb = 0.0;
    for (var day in weather.daily) {
      if (day.precipProb > maxRainProb) {
        maxRainProb = day.precipProb;
      }
    }

    if (maxRainProb > 70.0) {
      insights.add(_WeatherInsight(
        title: 'High Precipitation Risk',
        description: 'Heavy rainfall is expected in the coming days (highest probability: ${maxRainProb.round()}%). Hold off on pesticide sprays or fertilizer application as they may wash away.',
        icon: Icons.umbrella_rounded,
        color: const Color(0xFFEF4444),
        severity: 'High',
      ));
    } else if (maxRainProb > 30.0) {
      insights.add(_WeatherInsight(
        title: 'Scattered Showers Ahead',
        description: 'Light or scattered rain is likely. Keep an eye on local forecasts before scheduling field operations.',
        icon: Icons.umbrella_rounded,
        color: const Color(0xFFF59E0B),
        severity: 'Medium',
      ));
    } else {
      insights.add(_WeatherInsight(
        title: 'Dry Spell Expected',
        description: 'Very low chance of rain over the next 7 days. Ensure regular irrigation according to crop water needs.',
        icon: Icons.wb_sunny_rounded,
        color: const Color(0xFF10B981),
        severity: 'Info',
      ));
    }

    // 2. Pest & Disease Alert based on Humidity & Temp
    double avgHumidity = 0.0;
    double maxTemp = 0.0;
    for (var day in weather.daily) {
      avgHumidity += day.humidity;
      if (day.tempMax > maxTemp) {
        maxTemp = day.tempMax;
      }
    }
    avgHumidity /= weather.daily.length;

    if (avgHumidity > 80.0 && maxTemp > 28.0) {
      insights.add(_WeatherInsight(
        title: 'High Pest & Fungal Risk',
        description: 'High humidity (avg ${avgHumidity.round()}%) combined with warm temperatures (up to ${maxTemp.round()}°C) creates perfect conditions for fungal diseases (like blast or blight) and sucking pests. Inspect your crops daily.',
        icon: Icons.bug_report_rounded,
        color: const Color(0xFFEF4444),
        severity: 'High',
      ));
    } else if (avgHumidity > 65.0) {
      insights.add(_WeatherInsight(
        title: 'Moderate Disease Window',
        description: 'Elevated humidity levels detected. Ensure proper spacing between crops to allow air circulation and minimize moisture retention.',
        icon: Icons.healing_rounded,
        color: const Color(0xFFF59E0B),
        severity: 'Medium',
      ));
    }

    // 3. Wind speed check
    double maxWind = 0.0;
    for (var day in weather.daily) {
      if (day.windSpeed > maxWind) {
        maxWind = day.windSpeed;
      }
    }
    if (maxWind > 25.0) {
      insights.add(_WeatherInsight(
        title: 'Strong Winds Alert',
        description: 'Wind speeds may reach up to ${maxWind.round()} km/h. Avoid foliar spraying and secure tall crops or young saplings with supports to prevent lodging.',
        icon: Icons.air_rounded,
        color: const Color(0xFFF59E0B),
        severity: 'Medium',
      ));
    }

    // 4. Irrigation Guidance
    if (maxRainProb > 60.0) {
      insights.add(_WeatherInsight(
        title: 'Postpone Manual Irrigation',
        description: 'Significant rain is forecasted. You can save water and avoid root rot by postponing scheduled manual irrigations.',
        icon: Icons.water_drop_rounded,
        color: const Color(0xFF3B82F6),
        severity: 'Info',
      ));
    } else {
      insights.add(_WeatherInsight(
        title: 'Normal Irrigation Schedule',
        description: 'No heavy rain expected. Maintain your regular irrigation cycles, focusing on the root zones during cooler morning/evening hours.',
        icon: Icons.opacity_rounded,
        color: const Color(0xFF10B981),
        severity: 'Info',
      ));
    }

    return insights;
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 20, width: 150, color: Colors.white),
            const SizedBox(height: 20),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: List.generate(
                3,
                (i) => Expanded(
                  child: Container(
                    height: 90,
                    margin: EdgeInsets.only(right: i == 2 ? 0 : 10),
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
  final List<_DailyData> daily;
  final double latitude;
  final double longitude;

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
    required this.daily,
    required this.latitude,
    required this.longitude,
  });
}

class _HourlyData {
  final String time;
  final double temp;
  final String icon;

  _HourlyData({required this.time, required this.temp, required this.icon});
}

class _DailyData {
  final String date;
  final double tempMax;
  final double tempMin;
  final double temp;
  final String conditions;
  final String icon;
  final double humidity;
  final double windSpeed;
  final double precipProb;

  _DailyData({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.temp,
    required this.conditions,
    required this.icon,
    required this.humidity,
    required this.windSpeed,
    required this.precipProb,
  });
}

class _SeasonInfo {
  final String name;
  final String duration;
  final String description;
  final List<String> advisories;
  final List<_CropRecommendation> recommendedCrops;

  _SeasonInfo({
    required this.name,
    required this.duration,
    required this.description,
    required this.advisories,
    required this.recommendedCrops,
  });
}

class _CropRecommendation {
  final String name;
  final String duration;
  final String soilType;
  final String waterReq;
  final String icon;
  final String description;

  _CropRecommendation({
    required this.name,
    required this.duration,
    required this.soilType,
    required this.waterReq,
    required this.icon,
    required this.description,
  });
}

class _WeatherInsight {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String severity;

  _WeatherInsight({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.severity,
  });
}

class _AnimatedIcon extends StatefulWidget {
  final Widget child;
  const _AnimatedIcon({required this.child});

  @override
  State<_AnimatedIcon> createState() => _AnimatedIconState();
}

class _AnimatedIconState extends State<_AnimatedIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ScaleTransition(
        scale: _animation,
        child: widget.child,
      ),
    );
  }
}

String _getLottieUrl(String iconCode) {
  switch (iconCode) {
    case 'clear-day':
      return 'https://raw.githubusercontent.com/basmilius/weather-icons/master/production/lottie/clear-day.json';
    case 'clear-night':
      return 'https://raw.githubusercontent.com/basmilius/weather-icons/master/production/lottie/clear-night.json';
    case 'partly-cloudy-day':
      return 'https://raw.githubusercontent.com/basmilius/weather-icons/master/production/lottie/partly-cloudy-day.json';
    case 'partly-cloudy-night':
      return 'https://raw.githubusercontent.com/basmilius/weather-icons/master/production/lottie/partly-cloudy-night.json';
    case 'cloudy':
      return 'https://raw.githubusercontent.com/basmilius/weather-icons/master/production/lottie/cloudy.json';
    case 'rain':
    case 'showers-day':
    case 'showers-night':
      return 'https://raw.githubusercontent.com/basmilius/weather-icons/master/production/lottie/rain.json';
    case 'thunder-rain':
    case 'thunder-showers-day':
    case 'thunder-showers-night':
      return 'https://raw.githubusercontent.com/basmilius/weather-icons/master/production/lottie/thunderstorms-day.json';
    case 'snow':
    case 'snow-showers-day':
    case 'snow-showers-night':
      return 'https://raw.githubusercontent.com/basmilius/weather-icons/master/production/lottie/snow.json';
    case 'fog':
    case 'mist':
      return 'https://raw.githubusercontent.com/basmilius/weather-icons/master/production/lottie/mist.json';
    default:
      return 'https://raw.githubusercontent.com/basmilius/weather-icons/master/production/lottie/clear-day.json';
  }
}



