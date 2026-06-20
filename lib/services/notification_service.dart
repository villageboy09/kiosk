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

  static Future<void> subscribeToDistrictTopic(User user) async {
    if (kIsWeb) return; // FCM topics are not supported on web
    final district = user.district;
    if (district == null || district.trim().isEmpty) return;
    
    final safeDistrict = district
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9-_.~%]'), '_');

    if (safeDistrict.isNotEmpty) {
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
        _handleNotificationClick(initialMessage);
      });
    }

    // Handle when app is opened from background state via a notification click
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message);
    });

    // Handle foreground notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showForegroundDialog(message);
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

  static void _handleNotificationClick(RemoteMessage message) {
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

    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => targetScreen),
    );
  }

  static void _showForegroundDialog(RemoteMessage message) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final title = message.notification?.title ?? 'Notification';
    final body = message.notification?.body ?? '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: message.data['screen'] != null
            ? SnackBarAction(
                label: 'View',
                textColor: const Color(0xFF4ADE80), // Premium bright green text for action
                onPressed: () => _handleNotificationClick(message),
              )
            : null,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFF1E293B), // Premium dark slate background
      ),
    );
  }
}
