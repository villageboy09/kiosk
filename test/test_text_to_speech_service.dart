import 'package:cropsync/services/deepseek_plant_doctor_service.dart';
import 'package:cropsync/services/text_to_speech_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextToSpeechService Language & Formatting Tests', () {
    test('resolveTtsLanguage maps languages to native Indian TTS locale tags', () {
      expect(TextToSpeechService.resolveTtsLanguage('te'), equals('te-IN'));
      expect(TextToSpeechService.resolveTtsLanguage('TE'), equals('te-IN'));
      expect(TextToSpeechService.resolveTtsLanguage('hi'), equals('hi-IN'));
      expect(TextToSpeechService.resolveTtsLanguage('HI'), equals('hi-IN'));
      expect(TextToSpeechService.resolveTtsLanguage('en'), equals('en-IN'));
      expect(TextToSpeechService.resolveTtsLanguage('EN'), equals('en-IN'));
      expect(TextToSpeechService.resolveTtsLanguage('fr'), equals('en-IN'));
    });

    test('cleanTextForSpeech cleans markdown, bullets, and expands agricultural units', () {
      const raw = '''
*Spray Mancozeb 75% WP* @ 2.5 g/L (500 g/acre in 200 L water).
• Ensure uniform spray coverage on leaves.
– Repeat after 10-12 days if required.
''';

      final cleaned = TextToSpeechService.cleanTextForSpeech(raw);

      // Verify markdown stripped
      expect(cleaned.contains('*'), isFalse);
      expect(cleaned.contains('•'), isFalse);
      expect(cleaned.contains('–'), isFalse);

      // Verify unit expansion
      expect(cleaned.contains('per acre'), isTrue);
      expect(cleaned.contains('per litre'), isTrue);
      expect(cleaned.contains('grams per'), isTrue);
    });

    test('cleanTextForSpeech preserves and fluently formats Telugu agricultural text', () {
      const teluguRaw = 'మాంకోజెబ్ 75% WP @ 2.5 గ్రా/లీ (500 గ్రా/ఎకరా 200 లీటర్ల నీటిలో కలపాలి)';
      final cleaned = TextToSpeechService.cleanTextForSpeech(teluguRaw);

      expect(cleaned, isNotEmpty);
      expect(cleaned.contains('మాంకోజెబ్'), isTrue);
      expect(cleaned.contains('నీటిలో'), isTrue);
      expect(cleaned.contains('@'), isFalse);
    });

    test('cleanTextForSpeech preserves and fluently formats Hindi agricultural text', () {
      const hindiRaw = 'मैंकोजेब 75% WP @ 2.5 ग्राम/लीटर (500 ग्राम/एकड़ 200 लीटर पानी में मिलाएं)';
      final cleaned = TextToSpeechService.cleanTextForSpeech(hindiRaw);

      expect(cleaned, isNotEmpty);
      expect(cleaned.contains('मैंकोजेब'), isTrue);
      expect(cleaned.contains('लीटर'), isTrue);
      expect(cleaned.contains('@'), isFalse);
    });
  });

  group('Multilingual DeepSeek Plant Doctor Enrichment Tests', () {
    const testJson = '''
{
  "is_plant": true,
  "reason": "",
  "detected_crop_name": "Tomato",
  "matched_problem_name": "Early Blight",
  "health_status": "diseased",
  "confidence": 0.92,
  "observed_symptoms": ["Concentric dark rings on lower leaves"],
  "ai_analysis": "Alternaria solani infection detected.",
  "weather_impact": "High humidity accelerates blight.",
  "recovery_recommendations": []
}
''';

    test('Enriches Telugu responses with Telugu CIBRC per-acre controls', () {
      final parsed = DeepSeekPlantDoctorService.parseCleanJson(testJson, language: 'te');
      final controls = parsed['ai_control_measures'] as Map<String, dynamic>;
      final chemical = controls['chemical'] as List;
      final biological = controls['biological'] as List;

      expect(chemical, isNotEmpty);
      // Contains Telugu script and per-acre dosage
      expect(chemical.first.toString(), contains('ఎకరాకు'));
      expect(chemical.first.toString(), contains('నీటిలో'));

      expect(biological, isNotEmpty);
      expect(biological.first.toString(), contains('ఎకరాకు'));
    });

    test('Enriches Hindi responses with Hindi CIBRC per-acre controls', () {
      final parsed = DeepSeekPlantDoctorService.parseCleanJson(testJson, language: 'hi');
      final controls = parsed['ai_control_measures'] as Map<String, dynamic>;
      final chemical = controls['chemical'] as List;
      final biological = controls['biological'] as List;

      expect(chemical, isNotEmpty);
      // Contains Hindi script and per-acre dosage
      expect(chemical.first.toString(), contains('प्रति एकड़'));
      expect(chemical.first.toString(), contains('लीटर पानी'));

      expect(biological, isNotEmpty);
      expect(biological.first.toString(), contains('प्रति एकड़'));
    });

    test('Enriches English responses with English CIBRC per-acre controls', () {
      final parsed = DeepSeekPlantDoctorService.parseCleanJson(testJson, language: 'en');
      final controls = parsed['ai_control_measures'] as Map<String, dynamic>;
      final chemical = controls['chemical'] as List;

      expect(chemical, isNotEmpty);
      expect(chemical.first.toString(), contains('acre'));
      expect(chemical.first.toString(), contains('water'));
    });
  });
}
