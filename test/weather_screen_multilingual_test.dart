import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Weather Multi-language Translations & Keys Tests', () {
    const keys = [
      'weather_today',
      'weather_weekly_forecast',
      'weather_weekly_subtitle',
      'weather_7day_forecast',
      'weather_seasonal_advisory',
      'weather_current_season',
      'weather_crops_to_grow',
      'weather_recommended_crops_subtitle',
      'weather_insights',
      'weather_insights_subtitle',
      'weather_pattern_insights_title',
      'weather_pattern_insights_subtitle',
      'weather_latest_update',
      'weather_season_label',
      'weather_advisory_label',
      'weather_sowing_label',
      'weather_ai_advisor_active',
      'weather_refreshed_label',
      'weather_just_now',
      'weather_mins_ago',
      'weather_hours_ago',
      'weather_load_error',
      'weather_retry',
      'weather_no_advisories',
      'weather_ai_update_failed',
      'weather_refresh_wait',
      'weather_severity_high',
      'weather_severity_medium',
      'weather_severity_info',
      'weather_high_short',
      'weather_low_short',
    ];

    test('All 31 weather keys exist and are non-empty in en.json', () {
      final file = File('assets/translations/en.json');
      expect(file.existsSync(), isTrue);
      final jsonMap = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      for (final k in keys) {
        expect(jsonMap.containsKey(k), isTrue, reason: 'Missing $k in en.json');
        expect(jsonMap[k].toString().trim().isNotEmpty, isTrue, reason: 'Empty $k in en.json');
      }
    });

    test('All 31 weather keys exist and are non-empty in te.json', () {
      final file = File('assets/translations/te.json');
      expect(file.existsSync(), isTrue);
      final jsonMap = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      for (final k in keys) {
        expect(jsonMap.containsKey(k), isTrue, reason: 'Missing $k in te.json');
        expect(jsonMap[k].toString().trim().isNotEmpty, isTrue, reason: 'Empty $k in te.json');
      }
    });

    test('All 31 weather keys exist and are non-empty in hi.json', () {
      final file = File('assets/translations/hi.json');
      expect(file.existsSync(), isTrue);
      final jsonMap = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      for (final k in keys) {
        expect(jsonMap.containsKey(k), isTrue, reason: 'Missing $k in hi.json');
        expect(jsonMap[k].toString().trim().isNotEmpty, isTrue, reason: 'Empty $k in hi.json');
      }
    });
  });
}
