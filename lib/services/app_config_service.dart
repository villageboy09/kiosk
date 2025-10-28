// lib/services/app_config_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppConfigService {
  // --- Singleton Setup ---
  // Private constructor
  AppConfigService._privateConstructor();
  // Static instance of the service
  static final AppConfigService instance =
      AppConfigService._privateConstructor();

  // --- Configuration Data ---
  // Supabase table name (kept static as it's part of the app's structure)
  static const String _configTable = 'app_config';

  // Map to hold the loaded configuration values
  final Map<String, String> _config = {};
  // Flag to track if the config has been loaded
  bool _isLoaded = false;

  // --- Methods ---

  /// Fetches configuration data from the Supabase `app_config` table.
  /// Only runs once per app session.
  Future<void> loadConfig() async {
    // Prevent reloading if already loaded
    if (_isLoaded) return;

    try {
      final supabase = Supabase.instance.client;
      // Fetch all key-value pairs from the config table
      final List<Map<String, dynamic>> data =
          await supabase.from(_configTable).select('key, value');

      // Clear any old config values before loading new ones
      _config.clear();

      // Populate the _config map
      for (var row in data) {
        // Ensure both key and value are strings and not null
        final key = row['key']?.toString();
        final value = row['value']?.toString();
        if (key != null && value != null) {
          _config[key] = value;
        }
      }

      // Mark config as loaded
      _isLoaded = true;
      debugPrint('✅ AppConfigService: Configuration loaded successfully.');
    } catch (e) {
      debugPrint('❌ AppConfigService: Error loading config: $e');
      // Optional: Implement fallback mechanism or default values here
      // For example, you could load default values from a local file
      // if the Supabase fetch fails.
    }
  }

  /// Retrieves a configuration value by its [key].
  ///
  /// Returns the [defaultValue] if the key is not found or config isn't loaded.
  String getValue(String key, {String defaultValue = ''}) {
    // Return the value from the map, or the default if not found
    return _config[key] ?? defaultValue;
  }

  /// Checks if the configuration has been loaded successfully.
  bool get isLoaded => _isLoaded;
}
