// ignore_for_file: prefer_const_constructors

import 'package:cropsync/screens/agri_shop.dart';
import 'package:cropsync/screens/chc_booking_screen.dart';
import 'package:cropsync/screens/market_prices.dart';
import 'package:cropsync/screens/seed_varieties.dart';
import 'package:cropsync/screens/weather_screen.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Locale? _lastLocale;

  @override
  void initState() {
    super.initState();
    GlobalNotifiers.selectionAdded.addListener(_onSelectionChanged);
    GlobalNotifiers.selectionDeleted.addListener(_onSelectionChanged);
    GlobalNotifiers.selectionUpdated.addListener(_onSelectionChanged);
    _loadFirstCrop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = context.locale;
    if (_lastLocale != currentLocale) {
      _lastLocale = currentLocale;
      _loadFirstCrop();
    }
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
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: _ServicesGrid(
                onTabSelected: widget.onTabSelected,
                firstCrop: _firstCrop,
                isLoadingCrop: _isLoadingCrop,
                stageImageUrl: _stageImageUrl,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Services grid using GridView for centered layout
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
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.85,
      ),
      children: [
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
          title: 'home_feature_weather_title'.tr(),
          subtitle: 'home_feature_weather_subtitle'.tr(),
          imagePath: 'assets/images/weather.jpg',
          color: Colors.lightBlue,
          onTap: () => _navigateTo(context, const WeatherScreen()),
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
      ],
    );
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

/// Individual service card - Zepto style with bouncy tap/selection effect
class _ServiceCard extends StatefulWidget {
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
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              boxShadow: AppTheme.shadowSm,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Material(
                color: Colors.white,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. Full Cover Image
                    if (widget.imageUrl != null)
                      CachedNetworkImage(
                        imageUrl: widget.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: widget.color.withValues(alpha: 0.1)),
                        errorWidget: (context, url, error) => Container(color: widget.color.withValues(alpha: 0.1)),
                      )
                    else if (widget.imagePath != null)
                      Image.asset(
                        widget.imagePath!,
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
                            widget.title,
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
                            widget.subtitle,
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
      ),
    );
  }
}
