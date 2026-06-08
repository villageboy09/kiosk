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
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/models/farmer_crop.dart';
import 'package:cropsync/services/global_notifiers.dart';

/// Home tab content - Zepto-inspired clean UI
class HomeTab extends StatefulWidget {
  final String greeting;
  final String farmerName;
  final String? profileImageUrl;
  final void Function(int) onTabSelected;

  const HomeTab({
    super.key,
    required this.greeting,
    required this.farmerName,
    this.profileImageUrl,
    required this.onTabSelected,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  FarmerCrop? _firstCrop;
  bool _isLoadingCrop = true;
  String? _stageImageUrl;

  @override
  void initState() {
    super.initState();
    GlobalNotifiers.selectionAdded.addListener(_onSelectionChanged);
    GlobalNotifiers.selectionDeleted.addListener(_onSelectionChanged);
    GlobalNotifiers.selectionUpdated.addListener(_onSelectionChanged);
    _loadFirstCrop();
  }

  @override
  void dispose() {
    GlobalNotifiers.selectionAdded.removeListener(_onSelectionChanged);
    GlobalNotifiers.selectionDeleted.removeListener(_onSelectionChanged);
    GlobalNotifiers.selectionUpdated.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    if (mounted) {
      _loadFirstCrop();
    }
  }

  String _getLocale() {
    if (!mounted) return 'en';
    final code = EasyLocalization.of(context)?.locale.languageCode ?? 'en';
    return code == 'te'
        ? 'te'
        : code == 'hi'
            ? 'hi'
            : 'en';
  }

  Future<void> _loadFirstCrop() async {
    if (!mounted) return;
    setState(() {
      _isLoadingCrop = true;
      _firstCrop = null;
      _stageImageUrl = null;
    });

    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        if (mounted) setState(() => _isLoadingCrop = false);
        return;
      }

      final locale = _getLocale();
      final selectionsData = await ApiService.getUserSelections(
        currentUser.userId,
        lang: locale,
      ).timeout(const Duration(seconds: 8));

      if (selectionsData.isEmpty) {
        if (mounted) {
          setState(() {
            _firstCrop = null;
            _isLoadingCrop = false;
          });
        }
        return;
      }

      // Find the selection for Field 1 ('Field 1' or 'పొలం 1'), otherwise fallback to the first available selection
      dynamic s;
      for (var item in selectionsData) {
        final fName = item['field_name']?.toString();
        if (fName == 'Field 1' || fName == 'పొలం 1') {
          s = item;
          break;
        }
      }
      s ??= selectionsData.first;

      final cropId = int.tryParse(s['crop_id'].toString()) ?? 1;
      final varietyId = int.tryParse(s['variety_id'].toString()) ?? 1;
      final sowingDate = DateTime.tryParse(s['sowing_date'].toString()) ?? DateTime.now();
      final daysSinceSowing = DateTime.now().difference(sowingDate).inDays;

      int? currentStageId;
      String? currentStageName;
      String? stageImageUrl;

      try {
        final durations = await ApiService.getStageDuration(
          cropId,
          varietyId: varietyId,
        ).timeout(const Duration(seconds: 5));
        for (var d in durations) {
          final start = d['start_day_from_sowing'] as int? ?? 0;
          final end = d['end_day_from_sowing'] as int? ?? 999;
          if (daysSinceSowing >= start && daysSinceSowing <= end) {
            currentStageId = d['stage_id'] as int?;
            break;
          }
        }

        if (currentStageId != null) {
          final stages = await ApiService.getCropStages(
            cropId,
            lang: locale,
          ).timeout(const Duration(seconds: 5));
          for (var stage in stages) {
            if (stage['id'] == currentStageId) {
              currentStageName = stage['name'] as String?;
              stageImageUrl = stage['image_url'] as String?;
              break;
            }
          }
        }
      } catch (_) {
        // ignore stage duration or stages fetching errors
      }

      if (mounted) {
        setState(() {
          _firstCrop = FarmerCrop(
            id: int.tryParse(s['selection_id'].toString()) ?? 0,
            fieldName: s['field_name']?.toString() ?? 'Field',
            cropName: s['crop_name']?.toString() ?? 'Crop',
            cropImageUrl: s['crop_image_url']?.toString(),
            cropId: cropId,
            varietyId: varietyId,
            sowingDate: sowingDate,
            currentStageId: currentStageId,
            currentStageName: currentStageName,
          );
          _stageImageUrl = stageImageUrl;
          _isLoadingCrop = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingCrop = false);
      }
    }
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
            sliver: _ServicesGrid(
              onTabSelected: widget.onTabSelected,
              firstCrop: _firstCrop,
              isLoadingCrop: _isLoadingCrop,
              stageImageUrl: _stageImageUrl,
            ),
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
  final void Function(int) onTabSelected;
  final FarmerCrop? firstCrop;
  final bool isLoadingCrop;
  final String? stageImageUrl;

  const _ServicesGrid({
    required this.onTabSelected,
    required this.firstCrop,
    required this.isLoadingCrop,
    this.stageImageUrl,
  });

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
        if (isLoadingCrop)
          _ServiceCard(
            title: 'home_feature_advisory_title'.tr(),
            subtitle: '${'loading'.tr()}...',
            color: AppTheme.primary,
            onTap: () {},
          )
        else if (firstCrop == null)
          _ServiceCard(
            title: 'Add your first crop',
            subtitle: 'add_first_crop'.tr(),
            color: AppTheme.primary,
            onTap: () => onTabSelected(2),
          )
        else
          _ServiceCard(
            title: firstCrop!.cropName,
            subtitle: firstCrop!.currentStageName ?? 'stage'.tr(),
            imageUrl: stageImageUrl ?? firstCrop!.cropImageUrl,
            color: AppTheme.primary,
            onTap: () => onTabSelected(1),
          ),
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
  final String? imagePath;
  final String? imageUrl;
  final Color color;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.title,
    required this.subtitle,
    this.imagePath,
    this.imageUrl,
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
                  if (imageUrl != null)
                    CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: color.withValues(alpha: 0.1)),
                      errorWidget: (context, url, error) => Container(color: color.withValues(alpha: 0.1)),
                    )
                  else if (imagePath != null)
                    Image.asset(
                      imagePath!,
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
