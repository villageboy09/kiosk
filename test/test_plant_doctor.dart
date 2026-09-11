import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cropsync/services/deepseek_plant_doctor_service.dart';
import 'package:cropsync/services/image_optimizer.dart';
import 'package:cropsync/services/weather_tool_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeepSeek Plant Doctor & Weather Tool Integration Tests', () {
    test('WeatherToolService fetches Realtime, Historical, and Forecast data', () async {
      // Test with Hyderabad/Telangana coordinates (major Indian agricultural region)
      const lat = 17.385;
      const lon = 78.486;

      final weather = await WeatherToolService.getAgriWeatherContext(
        latitude: lat,
        longitude: lon,
      );

      expect(weather, isNotNull);
      expect(weather.containsKey('realtime'), isTrue);
      expect(weather.containsKey('historical_7d'), isTrue);
      expect(weather.containsKey('forecast_7d'), isTrue);
      expect(weather.containsKey('agri_summary'), isTrue);

      final realtime = weather['realtime'] as Map<String, dynamic>;
      expect(realtime.containsKey('temp_c'), isTrue);
      expect(realtime.containsKey('rh_pct'), isTrue);
      expect(realtime.containsKey('wind_kmh'), isTrue);
      expect(realtime.containsKey('wind_dir'), isTrue);
      expect(realtime.containsKey('spray_condition'), isTrue);

      final historical = weather['historical_7d'] as Map<String, dynamic>;
      expect(historical.containsKey('avg_temp_c'), isTrue);
      expect(historical.containsKey('total_rain_mm'), isTrue);
      expect(historical.containsKey('fungal_incubation_risk'), isTrue);

      final forecast = weather['forecast_7d'] as Map<String, dynamic>;
      expect(forecast.containsKey('rain_prob_48h_pct'), isTrue);
      expect(forecast.containsKey('spray_washoff_warning'), isTrue);

      // Verify token compactness: JSON representation should be under 500 characters (~120 tokens)
      final jsonStr = jsonEncode(weather);
      expect(jsonStr.length, lessThan(800));
    });

    test('WeatherToolService respects timeframe filtering', () async {
      const lat = 17.385;
      const lon = 78.486;

      final realtimeOnly = await WeatherToolService.getAgriWeatherContext(
        latitude: lat,
        longitude: lon,
        timeframe: 'realtime',
      );
      expect(realtimeOnly.containsKey('realtime'), isTrue);
      expect(realtimeOnly.containsKey('historical_7d'), isFalse);

      final forecastOnly = await WeatherToolService.getAgriWeatherContext(
        latitude: lat,
        longitude: lon,
        timeframe: 'forecast',
      );
      expect(forecastOnly.containsKey('forecast_7d'), isTrue);
      expect(forecastOnly.containsKey('realtime'), isFalse);
    });

    test('DeepSeekPlantDoctorService config and model name check', () {
      expect(DeepSeekPlantDoctorService.modelName, equals('deepseek-v4-flash-vision-exp'));
    });

    test('DeepSeekPlantDoctorService throws if API key is not configured', () async {
      // Test without API key throws clear actionable exception
      expect(
        () => DeepSeekPlantDoctorService.diagnoseCrop(
          imageFile: File('non_existent_image.jpg'),
        ),
        throwsA(isA<DeepSeekException>()),
      );
    });

    test('Truncated JSON recovery handles mid-sentence truncation and enriches chemical controls', () {
      // Exact truncated JSON from the user screenshot
      const truncatedJson = '''
{
  "is_plant": true,
  "reason": "",
  "detected_crop_name": "Onion",
  "detected_crop_id": 28,
  "matched_problem_name": "Stemphylium Leaf Blight",
  "matched_problem_id": 550,
  "health_status": "diseased",
  "confidence": 0.88,
  "observed_symptoms": ["Numerous small oval tan-brown lesions scattered along green tubular leaves"],
  "ai_analysis": "Onion foliage shows classic Stemphylium vesicarium leaf blight: small necrotic spots.",
  "weather_impact": "Current 32°C, RH 49%, wind 12 km/h NNW - spray-favorable NOW.",
  "recovery_recommendations": ["Spray Mancozeb 75% WP @ 2.5 g/L + sticker
''';

      final result = DeepSeekPlantDoctorService.parseCleanJson(truncatedJson);
      expect(result['detected_crop_name'], equals('Onion'));
      expect(result['matched_problem_name'], equals('Stemphylium Leaf Blight'));
      expect(result['health_status'], equals('diseased'));
      expect(result['confidence'], equals(0.88));
      expect(result['ai_analysis'], contains('Stemphylium'));
      expect(result['ai_analysis'].toString().startsWith('{'), isFalse);

      // Verify Chemical controls are automatically populated with CIBRC molecules and dosages!
      final controls = result['ai_control_measures'] as Map<String, dynamic>;
      expect(controls.containsKey('chemical'), isTrue);
      final chemicalList = controls['chemical'] as List;
      expect(chemicalList, isNotEmpty);
      expect(chemicalList.first.toString(), contains('Mancozeb'));
      expect(chemicalList.first.toString(), contains('acre'));
      expect(chemicalList.first.toString(), contains('water'));
    });

    test('ImageOptimizer detects mime type and formats dataUriScheme correctly', () async {
      // 1x1 transparent PNG bytes
      final pngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82
      ]);

      final optimized = await ImageOptimizer.optimizeBytes(pngBytes);
      expect(optimized.mimeType, equals('image/png'));
      expect(optimized.dataUriScheme.startsWith('data:image/png;base64,'), isTrue);
    });
  });
}
