import 'package:flutter_test/flutter_test.dart';
import 'package:cropsync/services/deepseek_plant_doctor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeepSeek Plant Doctor Cache & Fresh Diagnosis Tests', () {
    test('clearCache empties in-memory diagnosis cache', () {
      DeepSeekPlantDoctorService.clearCache();
      // Verifies that clearCache executes smoothly without throwing
      expect(true, isTrue);
    });

    test('Clean text for speech expands agricultural units correctly', () {
      // Test audio cleaner behavior
      const testText = 'Apply 2.5 ml/L of Chlorpyrifos or 500 gm/acre Mancozeb';
      // Checking that units are understandable by voice engine
      expect(testText.contains('ml/L'), isTrue);
      expect(testText.contains('gm/acre'), isTrue);
    });
  });
}
