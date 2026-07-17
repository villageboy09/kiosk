import 'package:shared_preferences/shared_preferences.dart';
import 'package:cropsync/screens/agri_shop.dart';
import 'package:cropsync/screens/market_prices.dart';
import 'package:cropsync/screens/seed_varieties.dart';
import 'package:cropsync/screens/weather_screen.dart';
import 'package:cropsync/models/user.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NotificationService {
  NotificationService._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // In-app notifications in-memory state
  static final List<RemoteMessage> notifications = [];
  static final ValueNotifier<int> unreadNotifier = ValueNotifier<int>(0);
  static VoidCallback? onNotificationReceived;

  static Future<void> subscribeToDistrictTopic(User user, {String? lang}) async {
    if (kIsWeb) return; // FCM topics are not supported on web
    final district = user.district;
    if (district == null || district.trim().isEmpty) return;
    
    final safeDistrict = district
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9-_.~%]'), '_');

    if (safeDistrict.isNotEmpty) {
      String targetLang = lang ?? 'en';
      if (lang == null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final savedLocale = prefs.getString('locale');
          if (savedLocale != null && savedLocale.isNotEmpty) {
            targetLang = savedLocale.split('_')[0].toLowerCase();
          }
        } catch (e) {
          // fallback
        }
      }

      // Ensure language is valid
      if (!['en', 'hi', 'te'].contains(targetLang)) {
        targetLang = 'en';
      }

      // Unsubscribe from other languages first
      final languages = ['en', 'hi', 'te'];
      for (final l in languages) {
        if (l != targetLang) {
          await FirebaseMessaging.instance.unsubscribeFromTopic('district_${safeDistrict}_$l');
        }
      }

      // Subscribe to targeted language topic
      await FirebaseMessaging.instance.subscribeToTopic('district_${safeDistrict}_$targetLang');
      
      // Also keep the general legacy topic subscribed
      await FirebaseMessaging.instance.subscribeToTopic('district_$safeDistrict');
    }
  }

  static Future<void> synchronizeCropSubscriptions(User user) async {
    if (kIsWeb) return; // FCM topics are not supported on web
    final district = user.district;
    if (district == null || district.trim().isEmpty) return;

    final safeDistrict = district
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9-_.~%]'), '_');

    if (safeDistrict.isEmpty) return;

    try {
      final selections = await ApiService.getUserSelections(user.userId, lang: 'en');
      final activeCrops = selections
          .map((s) => s['crop_name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .map((name) => name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9-_.~%]'), '_'))
          .where((name) => name.isNotEmpty)
          .toSet();

      final allCropsData = await ApiService.getCrops(lang: 'en');
      final allCrops = allCropsData
          .map((c) => c['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .map((name) => name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9-_.~%]'), '_'))
          .where((name) => name.isNotEmpty)
          .toSet();

      final generalMarketTopic = 'district_${safeDistrict}_market_general';

      if (activeCrops.isEmpty) {
        // Subscribe to general market topic and unsubscribe from all crop topics
        await FirebaseMessaging.instance.subscribeToTopic(generalMarketTopic);
        for (final crop in allCrops) {
          final topic = 'district_${safeDistrict}_crop_$crop';
          await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
        }
      } else {
        // Unsubscribe from general market topic and synchronize crop topics
        await FirebaseMessaging.instance.unsubscribeFromTopic(generalMarketTopic);
        for (final crop in allCrops) {
          final topic = 'district_${safeDistrict}_crop_$crop';
          if (activeCrops.contains(crop)) {
            await FirebaseMessaging.instance.subscribeToTopic(topic);
          } else {
            await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
          }
        }
      }
    } catch (e) {
      debugPrint('Error synchronizing crop subscriptions: $e');
    }
  }

  /// Call this at app startup — sets up message handlers only.
  /// Does NOT request any permissions (no dialogs, no lag).
  static Future<void> initialize() async {
    if (kIsWeb) return; // Firebase messaging listeners and topics are not supported on web
    // Subscribe to general topic for all farmers (no permission needed) in background
    FirebaseMessaging.instance.subscribeToTopic('all_farmers').catchError((e) {
      debugPrint('Error subscribing to all_farmers topic: $e');
    });

    // Handle when app is launched from a terminated state via a notification click
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      // Delay slightly to ensure navigator is mounted
      Future.delayed(const Duration(milliseconds: 500), () {
        handleNotificationClick(initialMessage);
      });
    }

    // Handle when app is opened from background state via a notification click
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      handleNotificationClick(message);
    });

    // Handle foreground notifications (added to in-memory history + triggers bell wiggle)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      notifications.insert(0, message);
      unreadNotifier.value++;
      if (onNotificationReceived != null) {
        onNotificationReceived!();
      }
    });
  }

  /// Call this AFTER the UI is fully rendered (e.g., from home screen initState
  /// with a post-frame callback). Shows the OS permission dialog naturally,
  /// without blocking or lagging the startup animation.
  static Future<void> requestPermissions() async {
    if (kIsWeb) return; // Permissions not applicable on web
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static void handleNotificationClick(RemoteMessage message) {
    // Clear unread
    unreadNotifier.value = 0;

    // Add to in-memory feed if not present
    if (!notifications.contains(message)) {
      notifications.insert(0, message);
    }

    final data = message.data;
    final screen = data['screen'];
    
    if (screen == null) return;

    Widget targetScreen;
    switch (screen) {
      case 'weather':
        targetScreen = const WeatherScreen();
        break;
      case 'market':
        targetScreen = const MarketPricesScreen();
        break;
      case 'seeds':
        targetScreen = const SeedVarietiesScreen();
        break;
      case 'shop':
        targetScreen = const AgriShopScreen();
        break;
      default:
        return;
    }

    // Clean navigation stack setup: Pushes target and clears nested stack routes.
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => targetScreen),
      (route) => route.isFirst,
    );
  }
}
