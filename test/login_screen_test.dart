import 'package:cropsync/auth/login_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginTestAssetLoader extends AssetLoader {
  const LoginTestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'login_welcome_back': 'Welcome Back',
      'login_submit': 'Sign In',
      'choose_role': 'Choose Your Role',
      'role_farmer_title': 'Farmer',
      'role_retailer_title': 'Retailer Partner',
      'role_officer_title': 'Extension Officer',
      'role_chc_operator_title': 'CHC Operator',
      'role_content_creator_title': 'Content Creator',
      'signup_create_account': 'Create Account',
      'signup_error_phone': 'Please enter a valid 10-digit phone number',
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget createTestWidget({required Size screenSize}) {
    return MediaQuery(
      data: MediaQueryData(size: screenSize),
      child: EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        startLocale: const Locale('en'),
        fallbackLocale: const Locale('en'),
        assetLoader: const LoginTestAssetLoader(),
        child: Builder(
          builder: (context) {
            return MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: const LoginScreen(),
            );
          },
        ),
      ),
    );
  }

  group('LoginScreen Phone Validation Unit Tests', () {
    test('Rejects empty or short phone numbers', () {
      expect(LoginScreen.validatePhoneNumber(''), isNotNull);
      expect(LoginScreen.validatePhoneNumber('987654321'), isNotNull); // 9 digits
    });

    test('Rejects invalid starting prefixes (0 to 5)', () {
      expect(LoginScreen.validatePhoneNumber('0123456789'), isNotNull);
      expect(LoginScreen.validatePhoneNumber('5555555555'), isNotNull);
      expect(LoginScreen.validatePhoneNumber('1234567890'), isNotNull);
    });

    test('Rejects low-entropy patterns like 9999999998', () {
      expect(LoginScreen.validatePhoneNumber('9999999998'), isNotNull);
      expect(LoginScreen.validatePhoneNumber('9999999988'), isNotNull);
      expect(LoginScreen.validatePhoneNumber('9898989898'), isNotNull);
    });

    test('Accepts valid standard Indian mobile numbers', () {
      expect(LoginScreen.validatePhoneNumber('9848022338'), isNull);
      expect(LoginScreen.validatePhoneNumber('8978129845'), isNull);
      expect(LoginScreen.validatePhoneNumber('7093849182'), isNull);
    });
  });

  group('LoginScreen Responsive Widget Tests', () {
    testWidgets('Renders unified single-step phone layout cleanly on small screen (360x640)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(screenSize: const Size(360, 640)));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('LOGGING IN AS'), findsOneWidget);
      expect(find.text('Farmer'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget); // Direct Phone Input Field
      expect(find.text('+91 '), findsOneWidget);
      expect(find.text('SIM'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('New to CropSync? Create Account'), findsOneWidget);
    });

    testWidgets('Renders tablet two-column layout on wide screen (1280x800)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(screenSize: const Size(1280, 800)));
      await tester.pumpAndSettle();

      expect(find.text('CropSync'), findsOneWidget);
      expect(find.text('Smart Farming, Simplified.'), findsOneWidget);
      expect(find.text('1-Tap SIM Login'), findsOneWidget);
      expect(find.text('Smart Crop Advisory'), findsOneWidget);
      expect(find.text('Connected Community'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('New to CropSync? Create Account'), findsOneWidget);
    });

    testWidgets('Direct typing with real-time validation and button state',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(screenSize: const Size(400, 800)));
      await tester.pumpAndSettle();

      final phoneField = find.byType(TextField).first;

      // Type invalid pattern 9999999998
      await tester.enterText(phoneField, '9999999998');
      await tester.pump();

      // Submit button should be disabled
      final buttonFinder = find.widgetWithText(ElevatedButton, 'Sign In');
      expect(buttonFinder, findsOneWidget);
      final ElevatedButton invalidButton = tester.widget(buttonFinder);
      expect(invalidButton.onPressed, isNull);

      // Verify red warning error icon is shown
      expect(find.byIcon(Icons.error_outline_rounded), findsWidgets);

      // Type valid real phone number
      await tester.enterText(phoneField, '9848022338');
      await tester.pump();

      // Submit button should now be enabled
      final ElevatedButton validButton = tester.widget(buttonFinder);
      expect(validButton.onPressed, isNotNull);

      // Green checkmark icon should appear
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });
}
