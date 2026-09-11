import 'package:cropsync/services/ai_credit_service.dart';
import 'package:cropsync/services/razorpay_payment_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiCreditService Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Fresh user starts with 10 free daily credits', () async {
      const testUser = 'farmer_test_1';
      final status = await AiCreditService.getCreditStatus(userId: testUser);

      expect(status.dailyLimit, equals(10));
      expect(status.dailyUsed, equals(0));
      expect(status.dailyRemaining, equals(10));
      expect(status.purchasedCredits, equals(0));
      expect(status.totalAvailable, equals(10));
      expect(status.hasCredits, isTrue);
      expect(status.hasFreeCreditsRemaining, isTrue);
      expect(status.isUsingPurchasedCredits, isFalse);
    });

    test('Consuming credits decrements daily quota up to 10 scans', () async {
      const testUser = 'farmer_test_2';

      for (int i = 1; i <= 10; i++) {
        final canScan = await AiCreditService.canPerformAnalysis(userId: testUser);
        expect(canScan, isTrue);

        final consumed = await AiCreditService.consumeCredit(userId: testUser);
        expect(consumed, isTrue);

        final status = await AiCreditService.getCreditStatus(userId: testUser);
        expect(status.dailyUsed, equals(i));
        expect(status.dailyRemaining, equals(10 - i));
        expect(status.totalAvailable, equals(10 - i));
      }

      // 11th scan should fail (0 free daily scans left and 0 purchased credits)
      final canScan11th = await AiCreditService.canPerformAnalysis(userId: testUser);
      expect(canScan11th, isFalse);

      final consumed11th = await AiCreditService.consumeCredit(userId: testUser);
      expect(consumed11th, isFalse);
    });

    test('Adding 10 purchased credits enables scans when daily quota is exhausted', () async {
      const testUser = 'farmer_test_3';

      // Exhaust 10 daily scans
      for (int i = 0; i < 10; i++) {
        await AiCreditService.consumeCredit(userId: testUser);
      }

      var status = await AiCreditService.getCreditStatus(userId: testUser);
      expect(status.dailyRemaining, equals(0));
      expect(status.totalAvailable, equals(0));
      expect(status.hasCredits, isFalse);

      // Simulate purchasing 10 credits via Razorpay for ₹1
      status = await AiCreditService.addPurchasedCredits(
        10,
        userId: testUser,
        paymentId: 'pay_test_123456',
      );

      expect(status.purchasedCredits, equals(10));
      expect(status.totalAvailable, equals(10));
      expect(status.hasCredits, isTrue);
      expect(status.isUsingPurchasedCredits, isTrue);

      // Consume 1 purchased credit
      final consumed = await AiCreditService.consumeCredit(userId: testUser);
      expect(consumed, isTrue);

      status = await AiCreditService.getCreditStatus(userId: testUser);
      expect(status.dailyUsed, equals(10));
      expect(status.dailyRemaining, equals(0));
      expect(status.purchasedCredits, equals(9));
      expect(status.totalAvailable, equals(9));
    });

    test('New calendar day resets daily count to 10 but preserves purchased balance', () async {
      const testUser = 'farmer_test_4';
      final prefs = await SharedPreferences.getInstance();

      // Simulate yesterday's usage
      await prefs.setString('ai_credit_date_$testUser', '2026-01-01');
      await prefs.setInt('ai_credit_daily_used_$testUser', 10);
      await prefs.setInt('ai_credit_purchased_$testUser', 5);

      // Status check today should reset dailyUsed to 0 while keeping 5 purchased credits
      final status = await AiCreditService.getCreditStatus(userId: testUser);
      expect(status.dailyUsed, equals(0));
      expect(status.dailyRemaining, equals(10));
      expect(status.purchasedCredits, equals(5));
      expect(status.totalAvailable, equals(15)); // 10 free + 5 purchased
    });

    test('syncPurchasedCredits accurately syncs balance reported from server', () async {
      const testUser = 'farmer_test_5';

      final syncedStatus = await AiCreditService.syncPurchasedCredits(
        20,
        userId: testUser,
        paymentId: 'pay_server_verified_99',
      );

      expect(syncedStatus.purchasedCredits, equals(20));
      expect(syncedStatus.totalAvailable, equals(30)); // 10 free + 20 purchased
    });
  });

  group('Razorpay Mobile Number Autofill Tests', () {
    test('sanitizeIndianPhoneNumber handles various formats correctly', () {
      expect(RazorpayPaymentService.sanitizeIndianPhoneNumber('9876543210'), equals('9876543210'));
      expect(RazorpayPaymentService.sanitizeIndianPhoneNumber('+91 98765 43210'), equals('9876543210'));
      expect(RazorpayPaymentService.sanitizeIndianPhoneNumber('+91-98765-43210'), equals('9876543210'));
      expect(RazorpayPaymentService.sanitizeIndianPhoneNumber('919876543210'), equals('9876543210'));
      expect(RazorpayPaymentService.sanitizeIndianPhoneNumber('09876543210'), equals('9876543210'));
      expect(RazorpayPaymentService.sanitizeIndianPhoneNumber('  9876543210  '), equals('9876543210'));
    });

    test('resolveUserPhoneNumber resolves from SharedPreferences phone_number', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('phone_number', '+91 98765 43210');

      final resolved = await RazorpayPaymentService.resolveUserPhoneNumber();
      expect(resolved, equals('9876543210'));
    });

    test('resolveUserPhoneNumber resolves from SharedPreferences user_id if 10-digits', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await prefs.setString('user_id', '9123456780');

      final resolved = await RazorpayPaymentService.resolveUserPhoneNumber();
      expect(resolved, equals('9123456780'));
    });
  });
}

