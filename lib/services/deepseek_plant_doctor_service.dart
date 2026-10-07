// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/image_optimizer.dart';
import 'package:cropsync/services/weather_tool_service.dart';
import 'package:cropsync/utils/safe_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// DeepSeek vision based plant doctor.
/// Tries the server gateway first, then calls DeepSeek directly.
/// Every result is grounded against the crop's problem catalog and
/// guaranteed to be in the farmer's language (translation pass if needed).
class DeepSeekPlantDoctorService {
  static const String modelName = 'deepseek-v4-flash-vision-exp';
  static const String _endpoint = 'https://api.deepseek.com/chat/completions';

  static const List<String> supportedCropsList = [
    'Paddy (Rice)',
    'Cotton',
    'Sunflower',
    'Banana',
    'Turmeric',
    'Maize',
    'Chilli',
    'Tomato',
    'Bitter Gourd',
    'Tea',
    'Apple',
    'Sugarcane',
    'Brinjal',
    'Cumin',
    'Groundnut',
    'Mango',
    'Onion',
    'Soybean',
    'Wheat',
    'Garlic',
    'Okra',
    'Potato',
    'Pomegranate',
    'Grapes'
  ];

  static final Map<String, _CachedDiagnosis> _diagnosisCache = {};
  static const Duration _cacheTtl = Duration(hours: 2);

  // Kept byte-identical across calls so DeepSeek's prefix KV cache hits.
  static const String _staticSystemPrompt = """
You are Dr. Krishi, a senior Indian plant pathologist and entomologist.
Look carefully at the photo and name the SPECIFIC disease, pest or deficiency you see (e.g. "Rice Blast", "Early Blight", "Fall Armyworm", "Zinc Deficiency"). Never answer with generic labels like "Leaf Issue", "Crop Health Analysis", "Fungal infection" or "Disease".

You ONLY diagnose these 24 crops:
Paddy (Rice), Cotton, Sunflower, Banana, Turmeric, Maize, Chilli, Tomato, Bitter Gourd, Tea, Apple, Sugarcane, Brinjal, Cumin, Groundnut, Mango, Onion, Soybean, Wheat, Garlic, Okra, Potato, Pomegranate, Grapes.

Method:
1. Confirm the photo is a plant and is clear enough.
2. Describe the visible signs (lesion shape, colour, margin, halo, location, insects, frass, webbing, mottling).
3. Compare with the known problems of the crop (use the candidate catalog when given) and choose the single most likely cause.
4. If the plant looks healthy, say healthy. Do not invent a disease.

Guardrails:
- Not a plant: {"is_plant":false,"is_crop_supported":false,"is_clear_image":false,"reason":"..."}
- Plant but not one of the 24 crops: {"is_plant":true,"is_crop_supported":false,"unsupported_crop_name":"<name>","detected_crop_name":"<name>","health_status":"unknown","reason":"...","ai_control_measures":{"chemical":[],"biological":[],"preventative":[]}}. Never prescribe sprays for unsupported crops.
- Blurry or dark: {"is_plant":true,"is_clear_image":false,"reason":"..."}

For supported crops reply with exactly this JSON (no markdown):
{"is_plant":true,"is_crop_supported":true,"is_clear_image":true,"detected_crop_name":"<crop, target language>","problem_name_en":"<specific common name in English>","scientific_name":"<pathogen/pest latin name or null>","matched_problem_name":"<same problem, target language>","matched_problem_id":<catalog id or null>,"health_status":"healthy|diseased|deficiency|pest_infestation","severity_level":"mild|moderate|severe","confidence":0.0-1.0,"observed_symptoms":["..."],"ai_analysis":"2 short sentences.","weather_impact":"1 sentence on spray timing/risk.","recovery_recommendations":["..."],"ai_control_measures":{"chemical":["<molecule % formulation> @ <dose>/acre in <L> water"],"biological":["<agent> @ <dose>/acre in <L> water"],"preventative":["..."]}}
Use CIBRC-registered molecules with exact per-acre dose and water volume. Keep molecule/brand names in English letters.
""";

  static const List<Map<String, dynamic>> _staticTools = [
    {
      "type": "function",
      "function": {
        "name": "get_weather_data",
        "description":
            "Fetch weather (temp, RH, wind, rain) for farm coordinates",
        "parameters": {
          "type": "object",
          "properties": {
            "latitude": {"type": "number"},
            "longitude": {"type": "number"}
          },
          "required": ["latitude", "longitude"]
        }
      }
    }
  ];

  static String languageName(String code) {
    switch (code) {
      case 'te':
        return 'Telugu (తెలుగు)';
      case 'hi':
        return 'Hindi (हिन्दी)';
      default:
        return 'English';
    }
  }

  static String? _apiKey() {
    final key = dotenv.isInitialized
        ? dotenv.env['DEEPSEEK_API_KEY']
        : Platform.environment['DEEPSEEK_API_KEY'];
    return (key == null || key.trim().isEmpty) ? null : key.trim();
  }

  /// [knownProblems] should be the selected crop's catalog with
  /// `id`, `name` (localized) and `name_en`.
  static Future<Map<String, dynamic>> diagnoseCrop({
    required File imageFile,
    double? latitude,
    double? longitude,
    String language = 'en',
    int? selectedCropId,
    String? selectedCropName,
    List<Map<String, dynamic>>? knownCrops,
    List<Map<String, dynamic>>? knownProblems,
    String? symptomsContext,
    bool forceFresh = false,
  }) async {
    final apiKey = _apiKey();
    if (apiKey == null) {
      throw DeepSeekException(
        "DeepSeek API Key is missing. Please add DEEPSEEK_API_KEY to your .env file.",
        statusCode: 401,
      );
    }

    if (!await imageFile.exists()) {
      throw DeepSeekException("Image file does not exist on device.");
    }

    final fileBytes = await imageFile.readAsBytes();

    final cacheKey = _generateCacheKey(fileBytes, language, latitude, longitude,
        crop: selectedCropName);
    if (!forceFresh) {
      final cached = _diagnosisCache[cacheKey];
      if (cached != null &&
          DateTime.now().difference(cached.timestamp) < _cacheTtl) {
        return cached.result;
      }
    } else {
      _diagnosisCache.remove(cacheKey);
    }

    final optimized = await ImageOptimizer.optimizeBytes(fileBytes);
    final imageUri = optimized.dataUriScheme;

    Map<String, dynamic>? result = await _tryGateway(
      apiKey: apiKey,
      imageUri: imageUri,
      language: language,
      selectedCropId: selectedCropId,
      selectedCropName: selectedCropName,
      latitude: latitude,
      longitude: longitude,
    );

    result ??= await _diagnoseDirect(
      apiKey: apiKey,
      imageUri: imageUri,
      language: language,
      selectedCropName: selectedCropName,
      knownProblems: knownProblems,
      symptomsContext: symptomsContext,
      latitude: latitude,
      longitude: longitude,
    );

    _sanitizeAndEnrich(result, knownCrops, knownProblems, language: language);
    await _ensureLanguage(result, language, apiKey);
    _applyLocalizedCatalogName(result, knownProblems, language);

    _diagnosisCache[cacheKey] =
        _CachedDiagnosis(result: result, timestamp: DateTime.now());
    return result;
  }

  static Future<Map<String, dynamic>?> _tryGateway({
    required String apiKey,
    required String imageUri,
    required String language,
    int? selectedCropId,
    String? selectedCropName,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final gwResponse = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/plant_doctor_gateway.php'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'language': language,
              'crop_id': selectedCropId,
              'crop_name': selectedCropName,
              'latitude': latitude,
              'longitude': longitude,
              'image_base64': imageUri,
            }),
          )
          // Gateway itself waits up to 45s on DeepSeek.
          .timeout(const Duration(seconds: 55));

      if (gwResponse.statusCode == 200) {
        final gwData = jsonDecode(utf8.decode(gwResponse.bodyBytes));
        if (gwData is Map &&
            gwData['success'] == true &&
            gwData['diagnosis'] is Map) {
          final diag = Map<String, dynamic>.from(gwData['diagnosis'] as Map);
          if (!_isGenericProblemName(diag)) return diag;
          debugPrint(
              "Plant Doctor: gateway returned a generic name, retrying direct");
        }
      }
    } catch (e) {
      debugPrint("Plant Doctor gateway failed, falling back to direct: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>> _diagnoseDirect({
    required String apiKey,
    required String imageUri,
    required String language,
    String? selectedCropName,
    List<Map<String, dynamic>>? knownProblems,
    String? symptomsContext,
    double? latitude,
    double? longitude,
  }) async {
    String weatherContextStr = "";
    if (latitude != null && longitude != null) {
      try {
        final weather = await WeatherToolService.getAgriWeatherContext(
          latitude: latitude,
          longitude: longitude,
        ).timeout(const Duration(seconds: 4));

        final realtime = weather['realtime'] as Map<String, dynamic>? ?? {};
        final hist = weather['historical_7d'] as Map<String, dynamic>? ?? {};
        final fore = weather['forecast_7d'] as Map<String, dynamic>? ?? {};

        weatherContextStr =
            "Weather: ${realtime['temp_c']}C, RH ${realtime['rh_pct']}%, Wind ${realtime['wind_kmh']}km/h ${realtime['wind_dir']}. "
            "Rain 7d: ${hist['total_rain_mm']}mm. 48h rain prob: ${fore['rain_prob_48h_pct']}%, Wind max: ${fore['max_wind_kmh']}km/h. ";
      } catch (e) {
        debugPrint("Pre-weather fetch warning: $e");
      }
    }

    final langName = languageName(language);
    final userPrompt = StringBuffer();
    if (selectedCropName != null && selectedCropName.trim().isNotEmpty) {
      userPrompt.write(
          "Crop selected by farmer: $selectedCropName. Diagnose this crop only. ");
    }
    final catalog = _catalogPromptString(knownProblems);
    if (catalog.isNotEmpty) {
      userPrompt.write(
          "Known problems of this crop (id:name): [$catalog]. If the photo matches one, set matched_problem_id to that id and use that name; otherwise give the correct specific name and matched_problem_id null. ");
    }
    if (symptomsContext != null && symptomsContext.trim().isNotEmpty) {
      userPrompt.write("Farmer notes: $symptomsContext. ");
    }
    userPrompt.write(weatherContextStr);
    userPrompt.write(
        "Target language: $langName. Write every JSON value (except problem_name_en, scientific_name, health_status, severity_level and molecule names) in $langName script. JSON keys stay in English.");

    final messages = <Map<String, dynamic>>[
      {"role": "system", "content": _staticSystemPrompt},
      {
        "role": "user",
        "content": [
          {"type": "text", "text": userPrompt.toString()},
          {
            "type": "image_url",
            "image_url": {"url": imageUri, "detail": "high"},
          },
        ],
      },
    ];

    const maxToolIterations = 3;
    for (int iteration = 0; iteration < maxToolIterations; iteration++) {
      final Map<String, dynamic> requestBody = {
        "model": modelName,
        "messages": messages,
        "thinking": {"type": "disabled"},
        "temperature": 0.1,
        // Telugu/Hindi output costs 3-4x tokens; 700 truncated the JSON.
        "max_tokens": 1800,
      };
      if (weatherContextStr.isEmpty && iteration < maxToolIterations - 1) {
        requestBody["tools"] = _staticTools;
      }

      final message = await _chat(apiKey, requestBody,
          timeout: const Duration(seconds: 60));

      final toolCalls = message['tool_calls'] as List?;
      if (toolCalls != null && toolCalls.isNotEmpty) {
        messages.add(message);
        for (final toolCall in toolCalls) {
          final function = toolCall['function'] as Map<String, dynamic>;
          final callId = toolCall['id'] as String;
          Map<String, dynamic> weatherData = {};
          if (function['name'] == 'get_weather_data') {
            Map<String, dynamic> args = {};
            try {
              args = jsonDecode(function['arguments'] as String? ?? '{}');
            } catch (_) {}
            final lat =
                (args['latitude'] as num?)?.toDouble() ?? latitude ?? 17.385;
            final lon =
                (args['longitude'] as num?)?.toDouble() ?? longitude ?? 78.486;
            try {
              weatherData = await WeatherToolService.getAgriWeatherContext(
                  latitude: lat, longitude: lon);
            } catch (_) {}
          }
          // Every tool_call_id must get a reply or the next request is rejected.
          messages.add({
            "role": "tool",
            "tool_call_id": callId,
            "content": jsonEncode(weatherData)
          });
        }
        continue;
      }

      return _parseRaw(message['content'] as String? ?? '');
    }

    throw DeepSeekException("DeepSeek model exceeded maximum iterations.");
  }

  static Future<Map<String, dynamic>> _chat(
    String apiKey,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      _handleApiError(response);
    }

    final resData =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    _logTokenTelemetry(resData);
    final choice = (resData['choices'] as List).first as Map<String, dynamic>;
    return choice['message'] as Map<String, dynamic>;
  }

  static String _catalogPromptString(
      List<Map<String, dynamic>>? knownProblems) {
    if (knownProblems == null || knownProblems.isEmpty) return '';
    return knownProblems
        .take(60)
        .map((p) => "${p['id']}:${p['name_en'] ?? p['name']}")
        .join(", ");
  }

  // ---------------------------------------------------------------------------
  // LANGUAGE GUARANTEE
  // ---------------------------------------------------------------------------

  static bool hasNativeScript(String text, String language) {
    if (text.trim().isEmpty) return true;
    switch (language) {
      case 'te':
        return RegExp(r'[\u0C00-\u0C7F]').hasMatch(text);
      case 'hi':
        return RegExp(r'[\u0900-\u097F]').hasMatch(text);
      default:
        return !RegExp(r'[\u0900-\u097F\u0C00-\u0C7F]').hasMatch(text);
    }
  }

  /// Re-renders an existing diagnosis in [language] (used after a language switch).
  static Future<Map<String, dynamic>> translateDiagnosis(
      Map<String, dynamic> result, String language) async {
    final apiKey = _apiKey();
    if (apiKey == null) return result;
    final copy = Map<String, dynamic>.from(result);
    await _ensureLanguage(copy, language, apiKey);
    return copy;
  }

  static bool needsTranslation(Map<String, dynamic> data, String language) =>
      _needsTranslation(data, language);

  static bool _needsTranslation(Map<String, dynamic> data, String language) {
    final fields = <String>[
      data['matched_problem_name']?.toString() ?? '',
      data['ai_analysis']?.toString() ?? '',
      data['weather_impact']?.toString() ?? '',
    ];
    final controls = data['ai_control_measures'];
    if (controls is Map) {
      for (final k in ['chemical', 'biological', 'preventative']) {
        final l = controls[k];
        if (l is List && l.isNotEmpty) fields.add(l.first.toString());
      }
    }
    final symptoms = data['observed_symptoms'];
    if (symptoms is List && symptoms.isNotEmpty)
      fields.add(symptoms.first.toString());
    return fields.any((f) => !hasNativeScript(f, language));
  }

  /// Translates any English leftovers (from the model, gateway or local
  /// fallbacks) into the farmer's language with one text-only call.
  static Future<void> _ensureLanguage(
      Map<String, dynamic> data, String language, String apiKey) async {
    if (!_needsTranslation(data, language)) return;

    const keys = [
      'detected_crop_name',
      'matched_problem_name',
      'observed_symptoms',
      'ai_analysis',
      'weather_impact',
      'recovery_recommendations',
      'ai_control_measures',
      'reason',
    ];
    final payload = <String, dynamic>{
      for (final k in keys)
        if (data[k] != null) k: data[k],
    };
    final langName = languageName(language);

    try {
      final message = await _chat(
        apiKey,
        {
          "model": modelName,
          "messages": [
            {
              "role": "system",
              "content":
                  "You translate agricultural advisories for Indian farmers. Translate every string value of the JSON into simple, natural $langName that a farmer understands. Keep JSON keys, numbers, units (ml, g, L, acre) and pesticide molecule / brand names in English letters. Return only the JSON.",
            },
            {"role": "user", "content": jsonEncode(payload)},
          ],
          "thinking": {"type": "disabled"},
          "temperature": 0.1,
          "max_tokens": 2000,
        },
        timeout: const Duration(seconds: 40),
      );

      final translated = _decodeJsonObject(message['content'] as String? ?? '');
      if (translated == null) return;
      for (final k in keys) {
        final v = translated[k];
        if (v == null) continue;
        if (k == 'ai_control_measures') {
          if (v is Map) data[k] = _normalizeControls(v);
        } else if (v is List) {
          data[k] = v.map((e) => e.toString()).toList();
        } else if (v is String && v.trim().isNotEmpty) {
          data[k] = v;
        }
      }
    } catch (e) {
      debugPrint("Plant Doctor translation pass failed: $e");
    }
  }

  /// When the model picked a catalog problem, show the officially curated
  /// localized name for it.
  static void _applyLocalizedCatalogName(
    Map<String, dynamic> data,
    List<Map<String, dynamic>>? knownProblems,
    String language,
  ) {
    final id = data['matched_problem_id'];
    if (id == null || knownProblems == null) return;
    for (final p in knownProblems) {
      if (p['id'].toString() == id.toString()) {
        final local = (p['name'] ?? '').toString().trim();
        if (local.isNotEmpty && hasNativeScript(local, language)) {
          data['matched_problem_name'] = local;
        }
        final en = (p['name_en'] ?? '').toString().trim();
        if (en.isNotEmpty &&
            (data['problem_name_en']?.toString().trim().isEmpty ?? true)) {
          data['problem_name_en'] = en;
        }
        data['official_database_verified'] = true;
        return;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // PARSING
  // ---------------------------------------------------------------------------

  @visibleForTesting
  static Map<String, dynamic> parseCleanJson(
    String raw, {
    List<Map<String, dynamic>>? knownCrops,
    List<Map<String, dynamic>>? knownProblems,
    String language = 'en',
  }) {
    final parsed = _parseRaw(raw);
    _sanitizeAndEnrich(parsed, knownCrops, knownProblems, language: language);
    return parsed;
  }

  static Map<String, dynamic> _parseRaw(String raw) {
    return _decodeJsonObject(raw) ?? _extractFieldsViaRegex(raw);
  }

  static Map<String, dynamic>? _decodeJsonObject(String raw) {
    String cleaned = raw.trim();
    final fence =
        RegExp(r'```(?:json)?\s*([\s\S]*?)(?:```|$)').firstMatch(cleaned);
    if (fence != null) cleaned = fence.group(1)!.trim();
    final start = cleaned.indexOf('{');
    if (start > 0) cleaned = cleaned.substring(start);

    try {
      final d = jsonDecode(cleaned);
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
    try {
      final d = jsonDecode(_repairTruncatedJson(cleaned));
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
    return null;
  }

  static String _repairTruncatedJson(String jsonStr) {
    String repaired = jsonStr.trim();
    final stack = <String>[];
    bool inString = false;
    for (int i = 0; i < repaired.length; i++) {
      final c = repaired[i];
      if (c == '"' && (i == 0 || repaired[i - 1] != '\\')) {
        inString = !inString;
      } else if (!inString) {
        if (c == '{') stack.add('}');
        if (c == '[') stack.add(']');
        if ((c == '}' || c == ']') && stack.isNotEmpty) stack.removeLast();
      }
    }
    if (inString) repaired += '"';
    repaired = repaired.replaceFirst(RegExp(r'[,:]\s*$'), '');
    while (stack.isNotEmpty) {
      repaired += stack.removeLast();
    }
    return repaired;
  }

  static Map<String, dynamic> _extractFieldsViaRegex(String raw) {
    String extractString(String key) {
      final match =
          RegExp('"$key"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"').firstMatch(raw);
      return match?.group(1) ?? "";
    }

    num extractNumber(String key, num fallback) {
      final match = RegExp('"$key"\\s*:\\s*([0-9.]+)').firstMatch(raw);
      return match != null
          ? (num.tryParse(match.group(1)!) ?? fallback)
          : fallback;
    }

    List<String> extractList(String key) {
      final match = RegExp('"$key"\\s*:\\s*\\[([^\\]]*)\\]?').firstMatch(raw);
      if (match == null) return [];
      return RegExp('"([^"]+)"')
          .allMatches(match.group(1)!)
          .map((m) => m.group(1)!)
          .toList();
    }

    bool isFalse(String key) => RegExp('"$key"\\s*:\\s*false').hasMatch(raw);

    final isPlant = !isFalse('is_plant');
    final isCropSupported = !isFalse('is_crop_supported');
    final isClearImage = !isFalse('is_clear_image');
    final unsupportedCrop = extractString('unsupported_crop_name');
    final matchedProblemId = extractNumber('matched_problem_id', -1).toInt();
    final cropName = extractString('detected_crop_name');
    final healthStatus = extractString('health_status');

    return {
      "is_plant": isPlant,
      "is_crop_supported": isCropSupported,
      "unsupported_crop_name":
          unsupportedCrop.isNotEmpty ? unsupportedCrop : null,
      "is_clear_image": isClearImage,
      "matched_problem_id": matchedProblemId > 0 ? matchedProblemId : null,
      "severity_level": extractString('severity_level').isNotEmpty
          ? extractString('severity_level')
          : "moderate",
      "reason": extractString('reason'),
      "detected_crop_name": cropName.isNotEmpty ? cropName : unsupportedCrop,
      "problem_name_en": extractString('problem_name_en'),
      "scientific_name": extractString('scientific_name'),
      "matched_problem_name": extractString('matched_problem_name'),
      "health_status": healthStatus.isNotEmpty ? healthStatus : "unknown",
      "confidence": extractNumber('confidence', 0.7).toDouble(),
      "observed_symptoms": extractList('observed_symptoms'),
      "ai_analysis": extractString('ai_analysis'),
      "weather_impact": extractString('weather_impact'),
      "recovery_recommendations": extractList('recovery_recommendations'),
      "ai_control_measures": {
        "chemical":
            (isCropSupported && isPlant) ? extractList('chemical') : <String>[],
        "biological": (isCropSupported && isPlant)
            ? extractList('biological')
            : <String>[],
        "preventative": (isCropSupported && isPlant)
            ? extractList('preventative')
            : <String>[],
      }
    };
  }

  static const Set<String> _genericNames = {
    '',
    'issue',
    'problem',
    'disease',
    'leaf issue',
    'crop issue',
    'crop health analysis',
    'infection',
    'unknown',
    'n/a',
    'none',
    'null',
    'fungal infection',
    'fungal disease',
  };

  static bool _isGenericProblemName(Map<String, dynamic> d) {
    if (d['is_plant'] == false ||
        d['is_crop_supported'] == false ||
        d['is_clear_image'] == false) return false;
    if (d['health_status']?.toString().toLowerCase() == 'healthy') return false;
    final en = (d['problem_name_en'] ?? '').toString().trim().toLowerCase();
    final local =
        (d['matched_problem_name'] ?? '').toString().trim().toLowerCase();
    return _genericNames.contains(en) && _genericNames.contains(local);
  }

  static Map<String, dynamic> _normalizeControls(dynamic v) {
    List<String> list(dynamic x) => x is List
        ? x.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
        : (x is String && x.trim().isNotEmpty ? [x] : <String>[]);
    if (v is! Map)
      return {
        'chemical': <String>[],
        'biological': <String>[],
        'preventative': <String>[]
      };
    return {
      'chemical': list(v['chemical']),
      'biological': list(v['biological']),
      'preventative': list(v['preventative']),
    };
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u0900-\u097F\u0C00-\u0C7F ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static int? _matchCatalogId(
      String name, List<Map<String, dynamic>> problems) {
    final n = _norm(name);
    if (n.length < 3) return null;
    for (final p in problems) {
      for (final candidate in [p['name_en'], p['problem_name_en'], p['name']]) {
        final c = _norm((candidate ?? '').toString());
        if (c.length >= 3 && c == n) return SafeParser.toNullableInt(p['id']);
      }
    }
    for (final p in problems) {
      final c = _norm((p['name_en'] ?? p['problem_name_en'] ?? '').toString());
      if (c.length >= 4 && (n.contains(c) || c.contains(n)))
        return SafeParser.toNullableInt(p['id']);
    }
    return null;
  }

  static void _sanitizeAndEnrich(
    Map<String, dynamic> data,
    List<Map<String, dynamic>>? knownCrops,
    List<Map<String, dynamic>>? knownProblems, {
    String language = 'en',
  }) {
    final lang = language.toLowerCase();
    final isTelugu = lang == 'te';
    final isHindi = lang == 'hi';

    bool flag(String k) => data[k] is bool
        ? data[k] as bool
        : (data[k]?.toString().toLowerCase() != 'false');
    final isPlant = flag('is_plant');
    final isCropSupported = flag('is_crop_supported');
    final isClear = flag('is_clear_image');
    data['is_plant'] = isPlant;
    data['is_crop_supported'] = isCropSupported;
    data['is_clear_image'] = isClear;

    final conf = data['confidence'];
    double c = conf is num
        ? conf.toDouble()
        : (double.tryParse(conf?.toString() ?? '') ?? 0.7);
    if (c > 1) c = c / 100;
    data['confidence'] = c.clamp(0.0, 1.0);

    data['health_status'] =
        (data['health_status']?.toString().toLowerCase().trim() ?? 'unknown');
    data['severity_level'] =
        (data['severity_level']?.toString().toLowerCase().trim() ?? 'moderate');

    for (final k in ['observed_symptoms', 'recovery_recommendations']) {
      final v = data[k];
      data[k] = v is List
          ? v.map((e) => e.toString()).toList()
          : (v is String && v.isNotEmpty ? [v] : <String>[]);
    }

    if (!isPlant || !isCropSupported || !isClear) {
      data['ai_control_measures'] = _normalizeControls(null);
      return;
    }

    data['ai_control_measures'] =
        _normalizeControls(data['ai_control_measures']);
    final controls = data['ai_control_measures'] as Map<String, dynamic>;

    final healthStatus = data['health_status'] as String;
    final isHealthy = healthStatus == 'healthy';

    // Validate model-provided id against the catalog, then fall back to name matching.
    if (knownProblems != null && knownProblems.isNotEmpty) {
      final rawId = data['matched_problem_id'];
      final validId = rawId != null &&
          knownProblems.any((p) => p['id'].toString() == rawId.toString());
      if (!validId) {
        data['matched_problem_id'] = isHealthy
            ? null
            : (_matchCatalogId(
                    data['problem_name_en']?.toString() ?? '', knownProblems) ??
                _matchCatalogId(data['matched_problem_name']?.toString() ?? '',
                    knownProblems));
      }
    }

    String analysis = data['ai_analysis']?.toString() ?? "";
    if (analysis.trim().startsWith('{') || analysis.contains('"is_plant"')) {
      data['ai_analysis'] = '';
    }

    // Keyword fallbacks need an English name; the localized one won't match.
    final problemName =
        '${data['problem_name_en'] ?? ''} ${data['scientific_name'] ?? ''} ${data['matched_problem_name'] ?? ''}'
            .toLowerCase();

    final chemList = List<String>.from(controls['chemical'] as List);
    if (chemList.isEmpty && !isHealthy) {
      if (problemName.contains('blight') ||
          problemName.contains('spot') ||
          problemName.contains('blast') ||
          problemName.contains('rot') ||
          problemName.contains('fung') ||
          problemName.contains('mildew') ||
          problemName.contains('rust') ||
          problemName.contains('anthracnose')) {
        if (isTelugu) {
          chemList.add(
              "Mancozeb 75% WP ఎకరాకు 600-800 గ్రాములు 200 లీటర్ల నీటిలో కలిపి పిచికారీ చేయాలి (లేదా Azoxystrobin 18.2% + Difenoconazole 11.4% SC ఎకరాకు 200 మి.లీ 200 లీటర్ల నీటిలో).");
          chemList.add(
              "తీవ్రత ఎక్కువగా ఉంటే: Hexaconazole 5% EC ఎకరాకు 400 మి.లీ 200 లీటర్ల నీటిలో 50 మి.లీ గమ్/స్టిక్కర్ కలిపి పిచికారీ చేయండి.");
        } else if (isHindi) {
          chemList.add(
              "मैन्कोजेब 75% WP @ 600-800 ग्राम प्रति एकड़ 200 लीटर पानी में मिलाकर छिड़काव करें (या एजोक्सीस्ट्रोबिन 18.2% + डिफेनोकोनाज़ोल 11.4% SC @ 200 मिली प्रति एकड़ 200 लीटर पानी में)।");
          chemList.add(
              "गंभीर संक्रमण में: हेक्साकोनाज़ोल 5% EC @ 400 मिली प्रति एकड़ 200 लीटर पानी में स्टीकर के साथ छिड़कें।");
        } else {
          chemList.add(
              "Spray Mancozeb 75% WP @ 600-800 g/acre mixed in 200 L water (or Azoxystrobin 18.2% + Difenoconazole 11.4% SC @ 200 ml/acre in 200 L water).");
          chemList.add(
              "For advanced infection: Apply Hexaconazole 5% EC @ 400 ml/acre mixed in 200 L water with 50 ml sticker.");
        }
      } else if (problemName.contains('thrip') ||
          problemName.contains('aphid') ||
          problemName.contains('whitefly') ||
          problemName.contains('sucking') ||
          problemName.contains('mite') ||
          problemName.contains('jassid') ||
          problemName.contains('hopper')) {
        if (isTelugu) {
          chemList.add(
              "Imidacloprid 17.8% SL ఎకరాకు 60-80 మి.లీ 150-200 లీటర్ల నీటిలో లేదా Thiamethoxam 25% WG ఎకరాకు 40-50 గ్రాములు కలిపి పిచికారీ చేయాలి.");
          chemList.add(
              "తామర పురుగులు/నల్లి తీవ్రతకు: Fipronil 5% SC ఎకరాకు 400-500 మి.లీ 200 లీటర్ల నీటిలో పిచికారీ చేయండి.");
        } else if (isHindi) {
          chemList.add(
              "इमिडाक्लोप्रिड 17.8% SL @ 60-80 मिली प्रति एकड़ 150-200 लीटर पानी में या थायमेथोक्सम 25% WG @ 40-50 ग्राम मिलाकर छिड़काव करें।");
          chemList.add(
              "थ्रिप्स या माइट्स के लिए: फिप्रोनिल 5% SC @ 400-500 मिली प्रति एकड़ 200 लीटर पानी में छिड़कें।");
        } else {
          chemList.add(
              "Spray Imidacloprid 17.8% SL @ 60-80 ml/acre mixed in 150-200 L water or Thiamethoxam 25% WG @ 40-50 g/acre in 200 L water.");
          chemList.add(
              "For severe mite/thrip infestation: Spray Fipronil 5% SC @ 400-500 ml/acre mixed in 200 L water.");
        }
      } else if (problemName.contains('borer') ||
          problemName.contains('caterpillar') ||
          problemName.contains('worm') ||
          problemName.contains('pest') ||
          healthStatus == 'pest_infestation') {
        if (isTelugu) {
          chemList.add(
              "Chlorantraniliprole 18.5% SC ఎకరాకు 60 మి.లీ 150-200 లీటర్ల నీటిలో కలిపి పిచికారీ చేయండి.");
          chemList.add(
              "ప్రత్యామ్నాయం: Emamectin Benzoate 5% SG ఎకరాకు 80-100 గ్రాములు 200 లీటర్ల నీటిలో కలిపి పిచికారీ చేయాలి.");
        } else if (isHindi) {
          chemList.add(
              "Chlorantraniliprole 18.5% SC @ 60 मिली प्रति एकड़ 150-200 लीटर पानी में मिलाकर छिड़काव करें।");
          chemList.add(
              "विकल्प: इमामेक्टिन बेंजोएट 5% SG @ 80-100 ग्राम प्रति एकड़ 200 लीटर पानी में छिड़कें।");
        } else {
          chemList.add(
              "Spray Chlorantraniliprole 18.5% SC @ 60 ml/acre mixed in 150-200 L water.");
          chemList.add(
              "Alternative: Emamectin Benzoate 5% SG @ 80-100 g/acre mixed in 200 L water.");
        }
      } else if (problemName.contains('deficiency') ||
          problemName.contains('yellow') ||
          healthStatus == 'deficiency') {
        if (isTelugu) {
          chemList.add(
              "19:19:19 (NPK) ఎకరాకు 1 కిలో + సూక్ష్మపోషకాల మిశ్రమం ఎకరాకు 250 గ్రాములు 200 లీటర్ల నీటిలో కలిపి పిచికారీ చేయండి.");
          chemList.add(
              "జింక్ లోపానికి: Chelated Zinc (Zn-EDTA 12%) ఎకరాకు 200 గ్రాములు 200 లీటర్ల నీటిలో పిచికారీ చేయాలి.");
        } else if (isHindi) {
          chemList.add(
              "19:19:19 (NPK) @ 1 किग्रा प्रति एकड़ + सूक्ष्म पोषक तत्व मिश्रण @ 250 ग्राम 200 लीटर पानी में मिलाकर छिड़कें।");
          chemList.add(
              "जिंक की कमी के लिए: चिलेटेड जिंक (Zn-EDTA 12%) @ 200 ग्राम प्रति एकड़ 200 लीटर पानी में छिड़कें।");
        } else {
          chemList.add(
              "Foliar application: 19:19:19 (NPK) @ 1 kg/acre + Chelated micronutrient mixture @ 250 g/acre mixed in 200 L water.");
          chemList.add(
              "For zinc/iron deficiency: Spray Chelated Zinc (Zn-EDTA 12%) @ 200 g/acre in 200 L water.");
        }
      } else {
        if (isTelugu) {
          chemList.add(
              "Carbendazim 12% + Mancozeb 63% WP ఎకరాకు 400 గ్రాములు 200 లీటర్ల నీటిలో కలిపి పిచికారీ చేయండి.");
        } else if (isHindi) {
          chemList.add(
              "कार्बेन्डाजिम 12% + मैन्कोजेब 63% WP @ 400 ग्राम प्रति एकड़ 200 लीटर पानी में मिलाकर छिड़कें।");
        } else {
          chemList.add(
              "Apply Carbendazim 12% + Mancozeb 63% WP @ 400 g/acre mixed in 200 L water.");
        }
      }
      controls['chemical'] = chemList;
    }

    final bioList = List<String>.from(controls['biological'] as List);
    if (bioList.isEmpty && !isHealthy) {
      final soilBorne = problemName.contains('blight') ||
          problemName.contains('wilt') ||
          problemName.contains('rot');
      if (isTelugu) {
        bioList.add(
            "వేప నూనె (Azadirachtin 10,000 ppm) ఎకరాకు 500 మి.లీ నుండి 1 లీటర్ 150-200 లీటర్ల నీటిలో కలిపి పిచికారీ చేయండి.");
        bioList.add(soilBorne
            ? "ట్రైకోడెర్మా విరిడే 1% WP లేదా సూడోమోనాస్ ఫ్లోరోసెన్స్ ఎకరాకు 1-2 కిలోలు 200 లీటర్ల నీటిలో కలిపి పిచికారీ లేదా వేరు భాగంలో తడపాలి."
            : "ఎకరాకు 15-20 పసుపు, నీలం జిగురు అట్టలు అమర్చండి; బవేరియా బాసియానా 1.15% WP ఎకరాకు 1 కిలో 200 లీటర్ల నీటిలో పిచికారీ చేయండి.");
      } else if (isHindi) {
        bioList.add(
            "नीम का तेल (Azadirachtin 10,000 ppm) @ 500 मिली से 1 लीटर प्रति एकड़ 150-200 लीटर पानी में मिलाकर छिड़काव करें।");
        bioList.add(soilBorne
            ? "ट्राइकोडर्मा विरिडी 1% WP या स्यूडोमोनास फ्लोरोसेंस @ 1-2 किग्रा प्रति एकड़ 200 लीटर पानी में मिलाकर छिड़काव या जड़ों में प्रयोग करें।"
            : "प्रति एकड़ 15-20 पीले और नीले चिपचिपे ट्रैप लगाएं; ब्यूवेरिया बासियाना 1.15% WP @ 1 किग्रा प्रति एकड़ 200 लीटर पानी में छिड़कें।");
      } else {
        bioList.add(
            "Neem oil (Azadirachtin 10,000 ppm) @ 500 ml to 1 L/acre mixed in 150-200 L water with a mild surfactant.");
        bioList.add(soilBorne
            ? "Trichoderma viride 1% WP or Pseudomonas fluorescens @ 1-2 kg/acre in 200 L water as spray or soil drench."
            : "Install 15-20 yellow and blue sticky traps per acre and spray Beauveria bassiana 1.15% WP @ 1 kg/acre in 200 L water.");
      }
      controls['biological'] = bioList;
    }

    final prevList = List<String>.from(controls['preventative'] as List);
    if (prevList.isEmpty && !isHealthy) {
      if (isTelugu) {
        prevList.add(
            "పొలంలో నీరు నిలవకుండా మురుగు నీటి పారుదల సరిగా ఉండేలా చూడండి.");
        prevList
            .add("నత్రజని ఎరువులు అధికంగా వాడకండి; సమతుల్య ఎరువులు వేయండి.");
      } else if (isHindi) {
        prevList.add("खेत में जलभराव न होने दें, उचित जल निकास रखें।");
        prevList
            .add("नाइट्रोजन उर्वरक का अधिक प्रयोग न करें; संतुलित उर्वरक दें।");
      } else {
        prevList.add(
            "Ensure proper field drainage to avoid waterlogging and high canopy humidity.");
        prevList.add("Use balanced fertilizer; avoid excess nitrogen.");
      }
      controls['preventative'] = prevList;
    }

    if (knownCrops != null && data['detected_crop_id'] == null) {
      final detectedCrop = _norm(data['detected_crop_name']?.toString() ?? '');
      if (detectedCrop.length >= 3) {
        for (final crop in knownCrops) {
          final name = _norm((crop['name'] ?? '').toString());
          if (name.length >= 3 &&
              (detectedCrop.contains(name) || name.contains(detectedCrop))) {
            data['detected_crop_id'] = crop['id'];
            break;
          }
        }
      }
    }
  }

  static void _logTokenTelemetry(Map<String, dynamic> resData) {
    final usage = resData['usage'] as Map<String, dynamic>?;
    if (usage == null) return;
    debugPrint(
        "DeepSeek tokens: total ${usage['total_tokens']} | prompt ${usage['prompt_tokens']} "
        "(cache hit ${usage['prompt_cache_hit_tokens'] ?? 0}) | output ${usage['completion_tokens']}");
  }

  static String _generateCacheKey(
      List<int> bytes, String lang, double? lat, double? lon,
      {String? crop}) {
    int hash = bytes.length;
    final step = (bytes.length / 64).clamp(1, 100000).toInt();
    for (int i = 0; i < bytes.length; i += step) {
      hash = (hash * 31 + bytes[i]) & 0x7FFFFFFF;
    }
    final latStr = lat != null ? lat.toStringAsFixed(2) : '0';
    final lonStr = lon != null ? lon.toStringAsFixed(2) : '0';
    final cropStr =
        (crop != null && crop.isNotEmpty) ? crop.toLowerCase() : 'auto';
    return "diag_${hash}_${lang}_${cropStr}_${latStr}_$lonStr";
  }

  static void _handleApiError(http.Response response) {
    final code = response.statusCode;
    String message = "DeepSeek API Error ($code)";
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map && body['error'] != null) {
        message = body['error']['message']?.toString() ?? message;
      }
    } catch (_) {}

    if (code == 401) {
      throw DeepSeekException("Invalid DeepSeek API key.", statusCode: 401);
    } else if (code == 402) {
      throw DeepSeekException("AI service balance exhausted. Please try later.",
          statusCode: 402);
    } else if (code == 429) {
      throw DeepSeekException(
          "Too many requests. Please wait a moment and try again.",
          statusCode: 429);
    } else if (code == 503 || code == 500) {
      throw DeepSeekException(
          "AI service is busy. Please retry in a few seconds.",
          statusCode: code);
    } else {
      throw DeepSeekException(message, statusCode: code);
    }
  }

  static void clearCache() {
    _diagnosisCache.clear();
  }
}

class _CachedDiagnosis {
  final Map<String, dynamic> result;
  final DateTime timestamp;
  _CachedDiagnosis({required this.result, required this.timestamp});
}

class DeepSeekException implements Exception {
  final String message;
  final int? statusCode;
  DeepSeekException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
