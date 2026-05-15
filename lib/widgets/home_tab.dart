// ignore_for_file: prefer_const_constructors

import 'package:cropsync/screens/agri_shop.dart';
import 'package:cropsync/screens/chc_booking_screen.dart';
import 'package:cropsync/screens/market_prices.dart';
import 'package:cropsync/screens/seed_varieties.dart';
import 'package:cropsync/widgets/weather_bottom_sheet.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Home tab content - Zepto-inspired clean UI
class HomeTab extends StatefulWidget {
  final String greeting;
  final String farmerName;
  final String? profileImageUrl;

  const HomeTab({
    super.key,
    required this.greeting,
    required this.farmerName,
    this.profileImageUrl,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(
              child: _WelcomeCard(
                greeting: widget.greeting,
                farmerName: widget.farmerName,
                onTap: () => WeatherBottomSheet.show(context),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Text(
                'home_services_title'.tr(),
                style: AppTheme.h2,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            sliver: _ServicesGrid(),
          ),
          // Announcements Section
        ],
      ),
    );
  }
}

/// Welcome card - Clean UI with Temperature
class _WelcomeCard extends StatefulWidget {
  final String greeting;
  final String farmerName;
  final VoidCallback onTap;

  const _WelcomeCard({
    required this.greeting,
    required this.farmerName,
    required this.onTap,
  });

  @override
  State<_WelcomeCard> createState() => _WelcomeCardState();
}

class _WelcomeCardState extends State<_WelcomeCard> {
  Future<int?>? _tempFuture;

  @override
  void initState() {
    super.initState();
    _tempFuture = _fetchTemp();
  }

  Future<int?> _fetchTemp() async {
    try {
      final apiKey = dotenv.env['WEATHER_API_KEY'];
      if (apiKey == null) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final url = Uri.parse(
        'https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/${position.latitude},${position.longitude}?unitGroup=metric&key=$apiKey&contentType=json',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final days = data['days'];
        if (days is List && days.isNotEmpty) {
          final temp = days.first['temp'];
          if (temp is num) {
            return temp.round();
          }
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF9FAFB),
                    Colors.white,
                    Color(0xFFF3F4F6),
                  ],
                ),
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.greeting,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textHint,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.farmerName,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            height: 1.1,
                            letterSpacing: -1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  FutureBuilder<int?>(
                    future: _tempFuture,
                    builder: (context, snapshot) {
                      final temp = snapshot.data;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.wb_sunny_rounded,
                              color: Color(0xFFFFA000),
                              size: 20,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              temp != null ? '$temp°' : '--',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Services grid using SliverGrid for performance
class _ServicesGrid extends StatelessWidget {
  const _ServicesGrid();

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio:
            0.85, // Elongated iOS-style tall cards // Shorter, more compact cards
      ),
      delegate: SliverChildListDelegate([
        _ServiceCard(
          title: 'home_feature_market_title'.tr(),
          subtitle: 'home_feature_market_subtitle'.tr(),
          imagePath: 'assets/images/market_prices.jpg',
          color: AppTheme.accentOrange,
          onTap: () => _navigateTo(context, const MarketPricesScreen()),
        ),
        _ServiceCard(
          title: 'home_feature_shop_title'.tr(),
          subtitle: 'home_feature_shop_subtitle'.tr(),
          imagePath: 'assets/images/agri_shop.jpg',
          color: AppTheme.accentBrown,
          onTap: () => _navigateTo(context, const AgriShopScreen()),
        ),
        _ServiceCard(
          title: 'home_feature_seeds_title'.tr(),
          subtitle: 'home_feature_seeds_subtitle'.tr(),
          imagePath: 'assets/images/seed_varieties.jpg',
          color: AppTheme.accentBlue,
          onTap: () => _navigateTo(context, const SeedVarietiesScreen()),
        ),
        _ServiceCard(
          title: 'chc_title'.tr(),
          subtitle: 'chc_book_now'.tr(),
          imagePath: 'assets/images/custom_hiring_center.jpg',
          color: AppTheme.accentPurple,
          onTap: () => _navigateTo(context, const CHCBookingScreen()),
        ),
      ]),
    ); // Fixed missing semicolon
  }

  void _navigateTo(BuildContext context, Widget page) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.03, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }
}

/// Individual service card - Zepto style
class _ServiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final Color color;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.shadowSm,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Material(
            color: Colors.white,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Full Cover Image
                  Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                  ),
    
                  // 2. Subtle Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.2),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
    
                  // 3. Text Content
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          title,
                          style: AppTheme.getTextStyle(
                            context,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: AppTheme.getTextStyle(
                            context,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
