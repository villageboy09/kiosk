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

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> with SingleTickerProviderStateMixin {
  late Future<_WeatherSummary> _weatherFuture;
  late TabController _tabController;
  
  // AI Integration state
  Map<String, dynamic>? _aiAdvisory;
  bool _isLoadingAI = false;
  String _lastRefreshedStr = "Never";
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    _weatherFuture = _fetchWeather();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

    final prompt = """
You are an expert AI Agricultural Advisor. Analyze the following real-time weather data for ${weather.location}:
- Current Temp: ${weather.temp.round()}°C (Max: ${weather.tempMax.round()}°C, Min: ${weather.tempMin.round()}°C)
- Current Humidity: ${weather.humidity.round()}%
- Current Wind Speed: ${weather.windSpeed.round()} km/h
- Current Precipitation Probability: ${weather.precipProb.round()}%
- 7-Day Forecast: ${weather.daily.map((d) => "${d.date}: ${d.conditions} (Temp: ${d.temp.round()}°C, Rain: ${d.precipProb.round()}%)").join(', ')}

Return a JSON object containing dynamic agricultural advisories and recommended crops suited for these conditions.
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
    final currentMonth = DateTime.now().month;
    final seasonInfo = _getSeasonInfo(currentMonth);
    final insights = _analyzeWeatherPatterns(weather);

    return Column(
      children: [
        // Tab Bar Section
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppTheme.primary,
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: AppTheme.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
            tabs: const [
              Tab(text: 'Today & Forecast'),
              Tab(text: 'Seasonal Advisory'),
              Tab(text: 'Crops to Grow'),
              Tab(text: 'Weather Patterns'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTodayTab(weather),
              _buildSeasonalTab(weather, seasonInfo),
              _buildCropsTab(weather, seasonInfo),
              _buildPatternsTab(insights),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTodayTab(_WeatherSummary weather) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 16),

          // Main Temperature Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_getIcon(weather.icon), size: 64, color: const Color(0xFFFBBF24)),
                    const SizedBox(width: 20),
                    Text(
                      '${weather.temp.round()}°',
                      style: const TextStyle(
                        fontSize: 68,
                        fontWeight: FontWeight.w200,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  weather.conditions,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'H: ${weather.tempMax.round()}°',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'L: ${weather.tempMin.round()}°',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.7),
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
          const SizedBox(height: 24),

          // Hourly Forecast
          const Text(
            'Hourly Forecast',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: weather.hourly.length,
              itemBuilder: (_, i) =>
                  _buildHourlyCard(weather.hourly[i], i == 0),
            ),
          ),
          const SizedBox(height: 24),

          // 7-Day Forecast list
          const Text(
            '7-Day Forecast',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: weather.daily.length,
            itemBuilder: (context, index) {
              final day = weather.daily[index];
              return _buildDailyRow(day, index == 0);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDailyRow(_DailyData day, bool isToday) {
    DateTime parsedDate = DateTime.tryParse(day.date) ?? DateTime.now();
    String weekdayName = isToday ? 'Today' : DateFormat('EEEE').format(parsedDate);
    String dateStr = DateFormat('d MMM').format(parsedDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  weekdayName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(_getIcon(day.icon), size: 24, color: const Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(
                  '${day.precipProb.round()}%',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF4F46E5), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${day.tempMax.round()}°',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${day.tempMin.round()}°',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
    // Determine dynamic list of advisories (AI or local fallback)
    List<String> activeAdvisories = season.advisories;
    if (_aiAdvisory != null && _aiAdvisory!['advisories'] != null) {
      activeAdvisories = List<String>.from(_aiAdvisory!['advisories']);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nvidia AI Cache manager header card
          _buildAISettingsCard(weather),

          // Season Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'Current Active Season',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  season.name,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  season.duration,
                  style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Text(
                  season.description,
                  style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Seasonal Advisories
          Text(
            _aiAdvisory != null ? 'AI Agricultural Advisory' : 'Agricultural Advisory',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activeAdvisories.length,
            itemBuilder: (context, index) {
              final advisory = activeAdvisories[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF0FDFA),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.wb_incandescent_rounded, color: Color(0xFF0D9488), size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        advisory,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                          height: 1.4,
                        ),
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

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: activeCrops.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAISettingsCard(weather),
              Padding(
                padding: const EdgeInsets.only(bottom: 16, top: 8),
                child: Text(
                  _aiAdvisory != null ? 'AI Recommended Crops' : 'Recommended Crops',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          );
        }

        final crop = activeCrops[index - 1];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      crop.icon,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          crop.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Duration: ${crop.duration}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Color(0xFFF1F5F9)),
              ),
              Text(
                crop.description,
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildCropSpec('Soil Type', crop.soilType, Icons.landscape_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCropSpec('Water Req.', crop.waterReq, Icons.water_drop_outlined),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCropSpec(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF475569)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
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
          Icon(icon, size: 24, color: color),
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

  Widget _buildHourlyCard(_HourlyData hour, bool isNow) {
    return Container(
      width: 72,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isNow ? AppTheme.primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNow ? AppTheme.primary : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(
            isNow ? 'Now' : hour.time,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isNow ? Colors.white70 : AppTheme.textSecondary,
            ),
          ),
          Icon(
            _getIcon(hour.icon),
            size: 24,
            color: isNow ? Colors.white : const Color(0xFF64748B),
          ),
          Text(
            '${hour.temp.round()}°',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isNow ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  _SeasonInfo _getSeasonInfo(int month) {
    if (month >= 6 && month <= 10) {
      // Kharif
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
    } else if (month == 11 || month == 12 || month <= 2) {
      // Rabi
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
    } else {
      // Zaid
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
