import 'package:cropsync/auth/signup_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignupTestAssetLoader extends AssetLoader {
  const SignupTestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'signup_title': 'Create Account',
      'signup_subtitle': 'Join CropSync today',
      'signup_name_hint': 'Enter your full name',
      'signup_phone_hint': 'Enter 10-digit mobile number',
      'signup_confirm_create': 'Confirm & Create',
      'signup_already_have_account': 'Already have an account? Login',
      'signup_select_role': 'Select Your Role',
      'signup_role_warning': 'Warning: Role cannot be changed once selected.',
      'role_farmer_title': 'Farmer',
      'role_retailer_title': 'Retailer Partner',
      'role_officer_title': 'Extension Officer',
      'role_chc_operator_title': 'CHC Operator',
      'role_content_creator_title': 'Content Creator',
      'signup_error_name': 'Please enter your name',
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
        assetLoader: const SignupTestAssetLoader(),
        child: Builder(
          builder: (context) {
            return MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: const SignupScreen(),
            );
          },
        ),
      ),
    );
  }

  group('Phone Validation Unit Tests', () {
    test('Rejects empty or short phone numbers', () {
      expect(SignupScreen.validatePhoneNumber(''), isNotNull);
      expect(SignupScreen.validatePhoneNumber('12345'), isNotNull);
      expect(SignupScreen.validatePhoneNumber('987654321'), isNotNull); // 9 digits
    });

    test('Rejects invalid starting prefixes (0 to 5)', () {
      expect(SignupScreen.validatePhoneNumber('0123456789'), isNotNull);
      expect(SignupScreen.validatePhoneNumber('5555555555'), isNotNull);
      expect(SignupScreen.validatePhoneNumber('1234567890'), isNotNull);
      expect(SignupScreen.validatePhoneNumber('2345678901'), isNotNull);
    });

    test('Rejects identical repeating digits', () {
      expect(SignupScreen.validatePhoneNumber('9999999999'), isNotNull);
      expect(SignupScreen.validatePhoneNumber('8888888888'), isNotNull);
      expect(SignupScreen.validatePhoneNumber('7777777777'), isNotNull);
      expect(SignupScreen.validatePhoneNumber('6666666666'), isNotNull);
    });

    test('Rejects low-entropy / nearly-identical numbers (e.g. 9999999998)', () {
      expect(SignupScreen.validatePhoneNumber('9999999998'), isNotNull);
      expect(SignupScreen.validatePhoneNumber('9999999988'), isNotNull);
      expect(SignupScreen.validatePhoneNumber('9999988888'), isNotNull);
      expect(SignupScreen.validatePhoneNumber('9899999999'), isNotNull);
      expect(SignupScreen.validatePhoneNumber('9000000001'), isNotNull);
    });

    test('Rejects sequential numbers', () {
      expect(SignupScreen.validatePhoneNumber('9876543210'), isNotNull);
      expect(SignupScreen.validatePhoneNumber('8765432109'), isNotNull);
      expect(SignupScreen.validatePhoneNumber('9123456789'), isNotNull);
    });

    test('Rejects repetitive 2-digit and chunk patterns', () {
      expect(SignupScreen.validatePhoneNumber('9898989898'), isNotNull);
      expect(SignupScreen.validatePhoneNumber('9191919191'), isNotNull);
      expect(SignupScreen.validatePhoneNumber('7878787878'), isNotNull);
      expect(SignupScreen.validatePhoneNumber('9876598765'), isNotNull);
    });

    test('Accepts valid standard Indian mobile numbers', () {
      expect(SignupScreen.validatePhoneNumber('9848022338'), isNull);
      expect(SignupScreen.validatePhoneNumber('8978129845'), isNull);
      expect(SignupScreen.validatePhoneNumber('7093849182'), isNull);
      expect(SignupScreen.validatePhoneNumber('9490192837'), isNull);
      expect(SignupScreen.validatePhoneNumber('6309871234'), isNull);
    });
  });

  group('SignupScreen Responsive Widget Tests', () {
    testWidgets('Renders phone layout cleanly on small screen (360x640)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(screenSize: const Size(360, 640)));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Join CropSync today'), findsOneWidget);
      expect(find.text('Farmer'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget); // Only Phone input field
      expect(find.text('+91 '), findsOneWidget);
      expect(find.text('SIM'), findsOneWidget);
      expect(find.text('Confirm & Create'), findsOneWidget);
    });

    testWidgets('Renders tablet two-column layout on wide screen (1280x800)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(screenSize: const Size(1280, 800)));
      await tester.pumpAndSettle();

      expect(find.text('CropSync'), findsOneWidget);
      expect(find.text('Smart Crop Advisory'), findsOneWidget);
      expect(find.text('Instant Registration'), findsOneWidget);
      expect(find.text('Verified Agricultural Network'), findsOneWidget);
      expect(find.text('Confirm & Create'), findsOneWidget);
    });

    testWidgets('Rejects 9999999998 pattern in UI and disables submit button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(screenSize: const Size(400, 800)));
      await tester.pumpAndSettle();

      // Enter fake 9999999998 number directly into the phone field
      final phoneField = find.byType(TextField).first;
      await tester.enterText(phoneField, '9999999998');
      await tester.pump();

      // Submit button should be disabled because 9999999998 is an invalid pattern
      final buttonFinder = find.widgetWithText(ElevatedButton, 'Confirm & Create');
      expect(buttonFinder, findsOneWidget);
      final ElevatedButton invalidButton = tester.widget(buttonFinder);
      expect(invalidButton.onPressed, isNull);

      // Verify no green checkmark is present
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

      // Verify red warning error icon is shown
      expect(find.byIcon(Icons.error_outline_rounded), findsWidgets);

      // Enter a valid real phone number (e.g. 9848022338)
      await tester.enterText(phoneField, '9848022338');
      await tester.pump();

      // Submit button should now be enabled
      final ElevatedButton validButton = tester.widget(buttonFinder);
      expect(validButton.onPressed, isNotNull);

      // Green checkmark should now be displayed
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });
}
