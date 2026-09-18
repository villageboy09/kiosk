import 'package:cropsync/services/saved_advisories_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SavedAdvisoriesService Tests', () {
    test('Can save and retrieve an advisory', () async {
      final initial = await SavedAdvisoriesService.getSavedAdvisories();
      expect(initial, isEmpty);

      final saved = await SavedAdvisoriesService.saveAdvisory(
        cropName: 'Chilli',
        problemName: 'Powdery Mildew',
        healthStatus: 'diseased',
        confidence: 94,
        summary: 'White powdery spots on Chilli leaves.',
        weatherImpact: 'Dry weather favors disease spread.',
        chemicalControls: ['Azoxystrobin 23% SC @ 1ml/L'],
        biologicalControls: ['Neem oil 5ml/L'],
        preventativeControls: ['Ensure proper aeration'],
        symptoms: ['White powder on leaves'],
        recoveryTips: ['Remove infected leaves'],
        matchedProblemId: 101,
      );

      expect(saved.id, isNotEmpty);
      expect(saved.cropName, 'Chilli');
      expect(saved.problemName, 'Powdery Mildew');

      final list = await SavedAdvisoriesService.getSavedAdvisories();
      expect(list.length, 1);
      expect(list.first.problemName, 'Powdery Mildew');
      expect(list.first.confidence, 94);
      expect(list.first.chemicalControls.first, 'Azoxystrobin 23% SC @ 1ml/L');

      final isSaved = await SavedAdvisoriesService.isAdvisorySaved(
        'Powdery Mildew',
        cropName: 'Chilli',
      );
      expect(isSaved, isTrue);

      final isDifferentSaved = await SavedAdvisoriesService.isAdvisorySaved(
        'Leaf Curl Virus',
        cropName: 'Chilli',
      );
      expect(isDifferentSaved, isFalse);
    });

    test('Can delete a saved advisory', () async {
      final saved = await SavedAdvisoriesService.saveAdvisory(
        cropName: 'Rice',
        problemName: 'Blast',
        healthStatus: 'diseased',
        confidence: 91,
        summary: 'Spindle-shaped lesions.',
      );

      var list = await SavedAdvisoriesService.getSavedAdvisories();
      expect(list.length, 1);

      final deleted = await SavedAdvisoriesService.deleteAdvisory(saved.id);
      expect(deleted, isTrue);

      list = await SavedAdvisoriesService.getSavedAdvisories();
      expect(list, isEmpty);
    });
  });
}
