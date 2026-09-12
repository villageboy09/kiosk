/// SafeParser provides foolproof type parsing from dynamic JSON payloads.
/// Prevents common Flutter/Dart crashes:
/// - TypeError: type 'String' is not a subtype of type 'int'
/// - NoSuchMethodError: 'toDouble' was called on a String
/// - Unexpected null values from backend APIs
class SafeParser {
  SafeParser._();

  /// Safely parses an integer from any dynamic value (int, num, String, double, etc.)
  static int toInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return fallback;
      final parsed = int.tryParse(trimmed);
      if (parsed != null) return parsed;
      final parsedDouble = double.tryParse(trimmed);
      if (parsedDouble != null) return parsedDouble.toInt();
    }
    return fallback;
  }

  /// Safely parses a nullable integer
  static int? toNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final parsed = int.tryParse(trimmed);
      if (parsed != null) return parsed;
      final parsedDouble = double.tryParse(trimmed);
      if (parsedDouble != null) return parsedDouble.toInt();
    }
    return null;
  }

  /// Safely parses a double from any dynamic value (num, int, String, etc.)
  static double toDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return fallback;
      return double.tryParse(trimmed) ?? fallback;
    }
    return fallback;
  }

  /// Safely parses a nullable double
  static double? toNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return double.tryParse(trimmed);
    }
    return null;
  }

  /// Safely parses a String, trimming extra whitespace
  static String toStringVal(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    return value.toString().trim();
  }

  /// Safely parses a boolean from bool, num (1/0), or String ('true'/'false'/'1'/'0')
  static bool toBool(dynamic value, [bool fallback = false]) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value == 1;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return fallback;
  }
}
