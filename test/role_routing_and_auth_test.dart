import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cropsync/models/user.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/auth/login_screen.dart';
import 'package:cropsync/auth/signup_screen.dart';
import 'package:cropsync/screens/creator/creator_home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('User Role & Permissions Model Tests', () {
    test('Farmer user correctly resolves isFarmer and rejects isCreator', () {
      final user = User(
        userId: '9876543210',
        name: 'Ramesh Farmer',
        phoneNumber: '9876543210',
        role: 'farmer',
        membershipType: 'Farmer',
      );

      expect(user.isFarmer, isTrue);
      expect(user.isCreator, isFalse);
      expect(user.isRetailer, isFalse);
      expect(user.isOfficer, isFalse);
      expect(user.isOperator, isFalse);
    });

    test(
        'Content Creator user correctly resolves isCreator and rejects isFarmer',
        () {
      final user = User(
        userId: '9876543211',
        name: 'Dr. Kalyan Creator',
        phoneNumber: '9876543211',
        role: 'content_creator',
        membershipType: 'Creator',
      );

      expect(user.isCreator, isTrue);
      expect(user.isFarmer, isFalse);
      expect(user.isRetailer, isFalse);
    });

    test('Retailer user correctly resolves isRetailer', () {
      final user = User(
        userId: '9876543212',
        name: 'Agri Inputs Store',
        phoneNumber: '9876543212',
        role: 'retailer',
        membershipType: 'Retailer',
      );

      expect(user.isRetailer, isTrue);
      expect(user.isFarmer, isFalse);
      expect(user.isCreator, isFalse);
    });

    test('User fromJson normalizes legacy creator variations', () {
      final user1 = User.fromJson({
        'user_id': '9876543210',
        'name': 'Test',
        'role': 'creator',
      });
      expect(user1.isCreator, isTrue);
      expect(user1.isFarmer, isFalse);

      final user2 = User.fromJson({
        'user_id': '9876543210',
        'name': 'Test',
        'role': 'farmer',
        'membership_type': 'Creator',
      });
      expect(user2.isCreator, isTrue);
      expect(user2.isFarmer, isFalse);
    });
  });

  group('Strict Phone Validation Tests', () {
    test(
        'LoginScreen phone validation rejects invalid lengths and repetitive numbers',
        () {
      expect(LoginScreen.validatePhoneNumber(''), isNotNull);
      expect(LoginScreen.validatePhoneNumber('12345'), isNotNull);
      expect(LoginScreen.validatePhoneNumber('9999999999'), isNotNull);
      expect(LoginScreen.validatePhoneNumber('9898989898'), isNotNull);
      expect(LoginScreen.validatePhoneNumber('5123456789'),
          isNotNull); // Doesn't start with 6-9
      expect(LoginScreen.validatePhoneNumber('9848022338'),
          isNull); // Valid Indian mobile
    });

    test('SignupScreen phone validation accepts valid mobile', () {
      expect(SignupScreen.validatePhoneNumber(''), isNotNull);
      expect(SignupScreen.validatePhoneNumber('9848022338'), isNull);
    });
  });

  group('AuthService Session Isolation & Cleanup', () {
    test('Logout clears currentUser and removes creator studio cache keys',
        () async {
      SharedPreferences.setMockInitialValues({
        'current_user':
            '{"user_id":"9876543210","name":"Arjun","role":"farmer"}',
        'is_logged_in': true,
        'user_phone': '9876543210',
        'cropsync_creator_studio_cache_9876543210': '{"cached":true}',
        'cropsync_creator_studio_cache_v1': '{"cached":true}',
      });

      await AuthService.loadUserSession();
      expect(AuthService.currentUser, isNotNull);

      await AuthService.logout();
      expect(AuthService.currentUser, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_logged_in'), isFalse);
      expect(
          prefs.getString('cropsync_creator_studio_cache_9876543210'), isNull);
      expect(prefs.getString('cropsync_creator_studio_cache_v1'), isNull);
    });
  });

  group('Creator Studio Navigation Guard Widget Tests', () {
    testWidgets(
        'navigateToStudio blocks Farmer from entering Studio and shows SnackBar',
        (tester) async {
      // Set current user as Farmer
      AuthService.currentUser = User(
        userId: '9876543210',
        name: 'Farmer John',
        phoneNumber: '9876543210',
        role: 'farmer',
        membershipType: 'Farmer',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => CreatorHomeScreen.navigateToStudio(context),
                  child: const Text('Go to Studio'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go to Studio'));
      await tester.pump(); // Pump snackbar animation

      // Must show restricted warning snackbar
      expect(find.textContaining('Creator Studio is for Content Creators'),
          findsOneWidget);
      expect(find.text('Login as Creator'), findsOneWidget);

      // Must NOT have navigated to CreatorHomeScreen
      expect(find.byType(CreatorHomeScreen), findsNothing);
    });
  });
}
