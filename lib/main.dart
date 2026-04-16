import 'package:cropsync/screens/home_screen.dart';
import 'package:cropsync/screens/operator/operator_dashboard.dart';
import 'package:cropsync/welcome_screen.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/operator_auth_service.dart';
import 'package:cropsync/services/location_service.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:cropsync/widgets/responsive/app_viewport.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  // Request location permission early (non-blocking)
  LocationService.requestPermission();

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
      startLocale: const Locale('te'),
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
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      theme: ThemeData(
        // Use locale-aware text theme
        textTheme: AppTheme.getTextTheme(context.locale.languageCode),
        primaryColor: AppTheme.primary,
        scaffoldBackgroundColor: AppTheme.background,
        appBarTheme: const AppBarTheme(
          backgroundColor:
              Colors.transparent, // Modern prominent transparent app bars!
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: AppTheme.textPrimary),
          titleTextStyle: TextStyle(
            fontFamily: 'Google Sans',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.2, // Tighter letter spacing
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.textPrimary, // Stark contrast buttons
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 16), // Taller
            elevation:
                0, // Flat design with shadows handles separately when needed
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusLg), // Pill/large radius
            ),
            textStyle: AppTheme.button
                .copyWith(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
          foregroundColor: AppTheme.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: AppTheme.button.copyWith(fontWeight: FontWeight.w600),
        )),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppTheme.card,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: const BorderSide(color: AppTheme.border, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: BorderSide(
                color: AppTheme.border.withValues(alpha: 0.5), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: const BorderSide(
                color: AppTheme.textPrimary, width: 2), // High contrast focus
          ),
        ),
        cardTheme: CardThemeData(
          color: AppTheme.card,
          elevation: 0, // rely on containers with custom boxshadow
          shape: RoundedRectangleBorder(
            borderRadius:
                const BorderRadius.all(Radius.circular(AppTheme.radiusLg)),
            side: BorderSide(
                color:
                    AppTheme.border.withValues(alpha: 0.3)), // Subtle outline
          ),
          margin: EdgeInsets.zero,
        ),
        dividerTheme: const DividerThemeData(
          color: AppTheme.divider,
          thickness: 1,
        ),
      ),
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
            return const HomeScreen();
          }

          return const SplashScreen();
        },
      ),
    );
  }
}
