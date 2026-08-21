import 'package:cropsync/models/user.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/farmer_analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('FarmerAnalyticsService Unit Tests', () {
    test('Logs crop view event safely without throwing when unauthenticated', () async {
      expect(
        () => FarmerAnalyticsService.logCropView(
          cropId: 1,
          cropName: 'Rice / వరి',
          language: 'te',
        ),
        returnsNormally,
      );
    });

    test('Logs problem view and control measures when authenticated', () async {
      AuthService.currentUser = User(
        userId: 'FARMER123',
        phoneNumber: '9848022338',
        membershipType: 'Farmer',
        name: 'Ramesh',
      );

      expect(
        () => FarmerAnalyticsService.logProblemView(
          problemId: 101,
          problemName: 'Blast Disease',
          category: 'Fungal Disease',
          cropId: 1,
          cropName: 'Rice',
        ),
        returnsNormally,
      );

      expect(
        () => FarmerAnalyticsService.logControlMeasureView(
          problemId: 101,
          problemName: 'Blast Disease',
          advisoryId: 50,
          cropName: 'Rice',
          category: 'Fungal Disease',
        ),
        returnsNormally,
      );
    });

    test('Logs Agri Shop and Seed Variety interactions safely', () async {
      expect(
        () => FarmerAnalyticsService.logShopItemView(
          productId: 10,
          productName: 'Tricyclazole 75% WP',
          category: 'Fungicide',
          price: '450',
          advertiserName: 'Agro Chem Ltd',
        ),
        returnsNormally,
      );

      expect(
        () => FarmerAnalyticsService.logShopEnquiry(
          productId: 10,
          productName: 'Tricyclazole 75% WP',
          advertiserId: 5,
        ),
        returnsNormally,
      );

      expect(
        () => FarmerAnalyticsService.logSeedVarietyView(
          seedId: 22,
          varietyName: 'BPT 5204',
          cropName: 'Rice',
          price: '1200',
          averageYield: 28.5,
        ),
        returnsNormally,
      );

      expect(
        () => FarmerAnalyticsService.logSeedBooking(
          seedId: 22,
          varietyName: 'BPT 5204',
          cropName: 'Rice',
          quantity: 2,
        ),
        returnsNormally,
      );
    });
  });
}
