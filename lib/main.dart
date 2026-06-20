import 'package:cropsync/screens/home_screen.dart';
import 'package:cropsync/screens/operator/operator_dashboard.dart';
import 'package:cropsync/welcome_screen.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/operator_auth_service.dart';
import 'package:cropsync/services/update_service.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:cropsync/widgets/responsive/app_viewport.dart';
import 'package:cropsync/screens/retailer/retailer_dashboard.dart';
import 'package:cropsync/screens/officer/extension_officer_dashboard.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cropsync/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await NotificationService.initialize();
  } catch (e) {
    // Gracefully handle if Firebase/Notifications are not configured or supported (e.g. on Web)
    debugPrint("Firebase/Notification initialization failed/skipped: $e");
  }
  await EasyLocalization.ensureInitialized();

  // Load environment variables (optional, for any other config)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // .env file is optional now
  }

  // Load both farmer and operator sessions if they exist
  await Future.wait([
    AuthService.loadUserSession(),
    OperatorAuthService.loadSession(),
  ]);

  if (AuthService.currentUser != null) {
    try {
      NotificationService.subscribeToDistrictTopic(AuthService.currentUser!);
      NotificationService.synchronizeCropSubscriptions(AuthService.currentUser!);
    } catch (e) {
      debugPrint("Notification subscription skipped: $e");
    }
  }

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
        Locale('te'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('te'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

  static Future<Map<String, bool>> checkSessions() async {
    final results = await Future.wait([
      AuthService.isLoggedIn(),
      OperatorAuthService.isLoggedIn(),
    ]);
    return {
      'farmer': results[0],
      'operator': results[1],
    };
  }
}

class _MyAppState extends State<MyApp> {
  late final Future<Map<String, bool>> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = MyApp.checkSessions();
    
    // Check for app updates in the background
    UpdateService.checkForUpdates();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      theme: AppTheme.lightTheme(context),
      debugShowCheckedModeBanner: false,
      title: 'CropSync',
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return AppViewport(child: child);
      },
      home: FutureBuilder<Map<String, bool>>(
        future: _sessionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primary,
                ),
              ),
            );
          }

          final data = snapshot.data ?? {};

          // Operator session takes priority if operator is logged in
          if (data['operator'] == true) {
            return const OperatorDashboard();
          }

          // Regular farmer session
          if (data['farmer'] == true) {
            final user = AuthService.currentUser;
            if (user?.membershipType == 'Retailer') {
              return const RetailerDashboard();
            } else if (user?.membershipType == 'Officer') {
              return const ExtensionOfficerDashboard();
            }
            return const HomeScreen();
          }

          return const SplashScreen();
        },
      ),
    );
  }
}
