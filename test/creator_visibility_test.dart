import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cropsync/models/user.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/screens/profile_screen.dart';
import 'package:cropsync/screens/news/news_feed_screen.dart';
import 'package:cropsync/screens/reels_screen.dart';
import 'package:cropsync/theme/app_theme.dart';

class VisibilityTestAssetLoader extends AssetLoader {
  const VisibilityTestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'creator_studio_title': 'Creator Studio',
      'privacy_policy': 'Privacy Policy',
      'contact_us': 'Contact Us',
      'share_app': 'Share App',
      'news_title': 'Krishi News',
      'news_subtitle': 'Real-time agriculture updates',
      'news_category_all': 'All',
      'news_category_schemes': 'Govt Schemes',
      'news_category_market': 'Market & MSP',
      'news_category_tech': 'Tech & Drones',
      'news_category_weather': 'Weather & Climate',
      'news_category_tips': 'Farming Tips',
      'news_search_hint': 'Search news, schemes & advisories...',
      'reels_loading': 'Loading Agri Reels...',
      'reels_empty_title': 'No Reels Available',
      'reels_empty_desc': 'Check back soon for new agricultural videos',
    };
  }
}

Widget wrapWithTestApp(Widget child) {
  return EasyLocalization(
    supportedLocales: const [Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('en'),
    startLocale: const Locale('en'),
    useOnlyLangCode: true,
    assetLoader: const VisibilityTestAssetLoader(),
    child: Builder(
      builder: (context) => MaterialApp(
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        theme: ThemeData(
          scaffoldBackgroundColor: AppTheme.background,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppTheme.appBarBg,
            elevation: 0,
          ),
        ),
        home: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
  });

  group('User Model & AuthService isCreator Tests', () {
    test('User.isCreator returns true for Creator, Content Creator, content_creator', () {
      final creator1 = User(userId: '1', name: 'Creator 1', membershipType: 'Creator');
      final creator2 = User(userId: '2', name: 'Creator 2', membershipType: 'Content Creator');
      final creator3 = User(userId: '3', name: 'Creator 3', membershipType: 'content_creator');

      expect(creator1.isCreator, isTrue);
      expect(creator2.isCreator, isTrue);
      expect(creator3.isCreator, isTrue);
    });

    test('User.isCreator returns false for Farmer, Retailer, Officer, null', () {
      final farmer = User(userId: '4', name: 'Farmer 1', membershipType: 'Farmer');
      final retailer = User(userId: '5', name: 'Retailer 1', membershipType: 'Retailer');
      final officer = User(userId: '6', name: 'Officer 1', membershipType: 'Officer');
      final normal = User(userId: '7', name: 'Normal User', membershipType: null);

      expect(farmer.isCreator, isFalse);
      expect(retailer.isCreator, isFalse);
      expect(officer.isCreator, isFalse);
      expect(normal.isCreator, isFalse);
    });

    test('AuthService.isCreator correctly reflects session state', () async {
      final farmer = User(userId: '9876543210', name: 'Ramesh', membershipType: 'Farmer');
      SharedPreferences.setMockInitialValues({
        'current_user': jsonEncode(farmer.toJson()),
        'is_logged_in': true,
      });

      expect(await AuthService.isCreator(), isFalse);

      final creator = User(userId: '9876543211', name: 'Suresh', membershipType: 'Creator');
      await AuthService.updateLocalUser(creator);

      expect(await AuthService.isCreator(), isTrue);
    });
  });

  group('ProfileScreen Creator Studio Visibility Tests', () {
    testWidgets('Hides Creator Studio menu pill for Farmer accounts', (tester) async {
      final farmer = User(
        userId: '9876543210',
        name: 'Ramesh Farmer',
        phoneNumber: '9876543210',
        membershipType: 'Farmer',
      );
      SharedPreferences.setMockInitialValues({
        'current_user': jsonEncode(farmer.toJson()),
        'is_logged_in': true,
      });
      AuthService.currentUser = farmer;

      await tester.pumpWidget(wrapWithTestApp(const ProfileScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Contact Us'), findsOneWidget);
      expect(find.text('Creator Studio'), findsNothing);
    });

    testWidgets('Shows Creator Studio menu pill for Creator accounts', (tester) async {
      final creator = User(
        userId: '9876543211',
        name: 'Suresh Creator',
        phoneNumber: '9876543211',
        membershipType: 'Creator',
      );
      SharedPreferences.setMockInitialValues({
        'current_user': jsonEncode(creator.toJson()),
        'is_logged_in': true,
      });
      AuthService.currentUser = creator;

      await tester.pumpWidget(wrapWithTestApp(const ProfileScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Creator Studio'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
    });
  });

  group('NewsFeedScreen AppBar & Creator Studio Visibility Tests', () {
    testWidgets('Renders AppBar with sage background, title, and hides Studio for Farmer', (tester) async {
      final farmer = User(
        userId: '9876543210',
        name: 'Ramesh Farmer',
        membershipType: 'Farmer',
      );
      SharedPreferences.setMockInitialValues({
        'current_user': jsonEncode(farmer.toJson()),
        'is_logged_in': true,
      });
      AuthService.currentUser = farmer;

      await tester.pumpWidget(wrapWithTestApp(const NewsFeedScreen()));
      await tester.pumpAndSettle();

      // Verify AppBar exists and has title
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Krishi News'), findsOneWidget);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, equals(AppTheme.appBarBg));

      // Verify Studio button is hidden for farmer
      expect(find.text('Studio'), findsNothing);
    });

    testWidgets('Shows Studio button in AppBar for Creator accounts', (tester) async {
      final creator = User(
        userId: '9876543211',
        name: 'Suresh Creator',
        membershipType: 'Creator',
      );
      SharedPreferences.setMockInitialValues({
        'current_user': jsonEncode(creator.toJson()),
        'is_logged_in': true,
      });
      AuthService.currentUser = creator;

      await tester.pumpWidget(wrapWithTestApp(const NewsFeedScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Krishi News'), findsOneWidget);
      expect(find.text('Studio'), findsOneWidget);
    });
  });

  group('ReelsScreen Creator Studio Visibility Tests', () {
    testWidgets('Hides Studio button for Farmer accounts', (tester) async {
      final farmer = User(
        userId: '9876543210',
        name: 'Ramesh Farmer',
        membershipType: 'Farmer',
      );
      SharedPreferences.setMockInitialValues({
        'current_user': jsonEncode(farmer.toJson()),
        'is_logged_in': true,
      });
      AuthService.currentUser = farmer;

      await tester.pumpWidget(wrapWithTestApp(const ReelsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Krishi Reels'), findsOneWidget);
      expect(find.text('Studio'), findsNothing);
    });

    testWidgets('Shows Studio button for Creator accounts', (tester) async {
      final creator = User(
        userId: '9876543211',
        name: 'Suresh Creator',
        membershipType: 'Creator',
      );
      SharedPreferences.setMockInitialValues({
        'current_user': jsonEncode(creator.toJson()),
        'is_logged_in': true,
      });
      AuthService.currentUser = creator;

      await tester.pumpWidget(wrapWithTestApp(const ReelsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Krishi Reels'), findsOneWidget);
      expect(find.text('Studio'), findsOneWidget);
    });
  });
}
