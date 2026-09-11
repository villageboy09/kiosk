import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Production-grade Text-to-Speech (TTS) Service for CropSync
/// 100% Free, Open-Source, and runs entirely on the device.
/// Fluently speaks Telugu (te-IN), Hindi (hi-IN), and English (en-IN) without token or API costs.
class TextToSpeechService {
  static final TextToSpeechService _instance = TextToSpeechService._internal();
  factory TextToSpeechService() => _instance;

  late final FlutterTts _flutterTts;
  bool _isInitialized = false;

  /// ValueNotifier broadcasting the sectionKey currently speaking (or null if idle)
  final ValueNotifier<String?> currentSpeakingKey = ValueNotifier<String?>(null);

  TextToSpeechService._internal() {
    _flutterTts = FlutterTts();
    _initTts();
  }

  Future<void> _initTts() async {
    if (_isInitialized) return;

    try {
      if (!kIsWeb && Platform.isAndroid) {
        try {
          final engines = await _flutterTts.getEngines;
          if (engines is List && engines.contains("com.google.android.tts")) {
            await _flutterTts.setEngine("com.google.android.tts");
          }
        } catch (_) {}
      }

      await _flutterTts.awaitSpeakCompletion(false);
      await _flutterTts.setSpeechRate(0.48); // Comprehension-optimized rate for farmers
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        debugPrint("🔊 TTS: Speech playback started");
      });

      _flutterTts.setCompletionHandler(() {
        debugPrint("🔇 TTS: Speech playback completed");
        currentSpeakingKey.value = null;
      });

      _flutterTts.setCancelHandler(() {
        debugPrint("⏹️ TTS: Speech playback cancelled");
        currentSpeakingKey.value = null;
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint("⚠️ TTS Error: $msg");
        currentSpeakingKey.value = null;
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint("TTS initialization warning: $e");
    }
  }

  /// Maps app language code to native Indian TTS locale tag
  static String resolveTtsLanguage(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'te':
        return 'te-IN'; // Telugu (India)
      case 'hi':
        return 'hi-IN'; // Hindi (India)
      case 'en':
      default:
        return 'en-IN'; // English (India)
    }
  }

  /// Toggles speech for a specific section:
  /// - If this section is already speaking, stops it.
  /// - If idle or another section is speaking, switches and speaks this section.
  Future<void> toggleSpeakSection({
    required String sectionKey,
    required String text,
    required String languageCode,
  }) async {
    if (currentSpeakingKey.value == sectionKey) {
      await stop();
      return;
    }

    await speakSection(
      sectionKey: sectionKey,
      text: text,
      languageCode: languageCode,
    );
  }

  /// Speaks text for a card section
  Future<void> speakSection({
    required String sectionKey,
    required String text,
    required String languageCode,
  }) async {
    await stop();

    final cleanedText = cleanTextForSpeech(text);
    if (cleanedText.isEmpty) return;

    final ttsLang = resolveTtsLanguage(languageCode);
    try {
      final isSupported = await _flutterTts.isLanguageAvailable(ttsLang);
      if (isSupported == 1 || isSupported == true) {
        await _flutterTts.setLanguage(ttsLang);
      } else {
        await _flutterTts.setLanguage(languageCode.toLowerCase());
      }

      currentSpeakingKey.value = sectionKey;
      await _flutterTts.speak(cleanedText);
    } catch (e) {
      debugPrint("Error speaking TTS: $e");
      currentSpeakingKey.value = null;
    }
  }

  /// Stops any currently playing speech
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint("Error stopping TTS: $e");
    } finally {
      currentSpeakingKey.value = null;
    }
  }

  /// Strips formatting symbols and expands agricultural units for fluent speech
  static String cleanTextForSpeech(String raw) {
    String text = raw;
    // Remove markdown symbols
    text = text.replaceAll(RegExp(r'[*_~#>`]'), ' ');
    // Replace bullet and dash points with comma for natural speech pause
    text = text.replaceAll(RegExp(r'•|–|—|\|'), ', ');
    // Expand @ symbol
    text = text.replaceAll(RegExp(r'@'), ' at ');
    // Expand compound units for fluent speech
    text = text.replaceAll(RegExp(r'\bml/acre\b', caseSensitive: false), ' ml per acre ');
    text = text.replaceAll(RegExp(r'\bgm?/acre\b', caseSensitive: false), ' grams per acre ');
    text = text.replaceAll(RegExp(r'\bkg/acre\b', caseSensitive: false), ' kg per acre ');
    text = text.replaceAll(RegExp(r'\bml/L\b|\bml/l\b', caseSensitive: false), ' ml per litre ');
    text = text.replaceAll(RegExp(r'\bgm?/L\b|\bgm?/l\b', caseSensitive: false), ' grams per litre ');
    text = text.replaceAll(RegExp(r'\bkg/L\b|\bkg/l\b', caseSensitive: false), ' kg per litre ');
    text = text.replaceAll(RegExp(r'/acre\b', caseSensitive: false), ' per acre ');
    text = text.replaceAll(RegExp(r'/L\b|/l\b', caseSensitive: false), ' per litre ');
    text = text.replaceAll(RegExp(r'\bml/\b', caseSensitive: false), ' ml per ');
    text = text.replaceAll(RegExp(r'\bgm?/\b', caseSensitive: false), ' grams per ');
    text = text.replaceAll(RegExp(r'\bkg/\b', caseSensitive: false), ' kg per ');
    // Clean excessive spaces
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  void dispose() {
    stop();
  }
}
