// lib/screens/seed_varieties.dart

import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/farmer_analytics_service.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:video_player/video_player.dart';
import 'package:cropsync/widgets/dialogs/app_success_dialog.dart';
import 'package:cropsync/services/share_service.dart';
import 'package:cropsync/utils/commodity_translator.dart';

String _getTranslatedCropName(BuildContext context, String cropName) {
  if (cropName.trim().isEmpty) return cropName;
  final langCode = context.locale.languageCode;

  // 1. CommodityTranslator provides accurate bi-directional translations
  final fromCommodity =
      CommodityTranslator.getLocalizedName(cropName, langCode);
  if (fromCommodity != cropName) return fromCommodity;

  // 2. Direct exact translation
  final directTr = context.tr(cropName);
  if (directTr != cropName) return directTr;

  // 3. Snake_case normalized lookup
  final key = cropName.toLowerCase().trim().replaceAll(' ', '_');
  final translated = context.tr(key);
  if (translated != key) return translated;

  final rawKey = cropName.toLowerCase().trim();
  final rawTranslated = context.tr(rawKey);
  if (rawTranslated != rawKey) return rawTranslated;

  return cropName;
}

String _getTranslatedRegion(BuildContext context, String region) {
  if (region.trim().isEmpty) return region;
  final direct = context.tr(region);
  if (direct != region) return direct;

  final key = region.toLowerCase().trim().replaceAll(' ', '_');
  final trKey = context.tr(key);
  if (trKey != key) return trKey;

  return region;
}

String _getTranslatedSowingPeriod(BuildContext context, String period) {
  if (period.trim().isEmpty) return period;
  final direct = context.tr(period);
  if (direct != period) return direct;

  final key =
      period.toLowerCase().trim().replaceAll(' ', '_').replaceAll('-', '_');
  final trKey = context.tr(key);
  if (trKey != key) return trKey;

  return period;
}

/// Seed variety data model
class SeedVariety {
  final int id;
  final String cropName;
  final String varietyName;
  final String? varietyNameSecondary;
  final String? imageUrl;
  final String? details;
  final String? region;
  final String? sowingPeriod;
  final String? testimonialVideoUrl;
  final String? price;
  final String? priceUnit;
  final double? averageYield;
  final int? growthDuration;

  SeedVariety({
    required this.id,
    required this.cropName,
    required this.varietyName,
    this.varietyNameSecondary,
    this.imageUrl,
    this.details,
    this.region,
    this.sowingPeriod,
    this.testimonialVideoUrl,
    this.price,
    this.priceUnit,
    this.averageYield,
    this.growthDuration,
  });

  double get priceValue => double.tryParse(price ?? '0') ?? 0;

  factory SeedVariety.fromJson(Map<String, dynamic> json) {
    return SeedVariety(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      cropName: json['crop_name']?.toString() ?? 'Unknown',
      varietyName: json['variety_name']?.toString() ?? 'Unknown',
      varietyNameSecondary: json['variety_name_secondary']?.toString() ??
          (json['variety_name_en'] != null &&
                  json['variety_name_en'].toString().trim().isNotEmpty &&
                  json['variety_name_en'] != json['variety_name']
              ? json['variety_name_en']?.toString()
              : (json['variety_name_te'] != null &&
                      json['variety_name_te'].toString().trim().isNotEmpty &&
                      json['variety_name_te'] != json['variety_name']
                  ? json['variety_name_te']?.toString()
                  : null)),
      imageUrl: json['image_url']?.toString(),
      details: json['details']?.toString(),
      region: json['region']?.toString(),
      sowingPeriod: json['sowing_period']?.toString(),
      testimonialVideoUrl: json['testimonial_video_url']?.toString(),
      price: json['price']?.toString(),
      priceUnit: json['price_unit']?.toString(),
      averageYield: double.tryParse(json['average_yield']?.toString() ?? ''),
      growthDuration: int.tryParse(json['growth_duration']?.toString() ?? ''),
    );
  }
}

/// Main seed varieties screen - Full E-Commerce Experience for Certified Seeds
class SeedVarietiesScreen extends StatefulWidget {
  final String? initialCrop;
  final int? initialVarietyId;

  const SeedVarietiesScreen({
    super.key,
    this.initialCrop,
    this.initialVarietyId,
  });

  @override
  State<SeedVarietiesScreen> createState() => _SeedVarietiesScreenState();
}

class _SeedVarietiesScreenState extends State<SeedVarietiesScreen> {
  late Future<List<SeedVariety>> _varietiesFuture;
  List<SeedVariety> _allVarieties = [];
  final TextEditingController _searchController = TextEditingController();
  final PageController _bannerPageController = PageController();

  String _searchQuery = '';
  String _selectedCrop = 'all';
  String _sortOrder = 'default'; // 'default', 'yield_desc', 'duration_asc', 'price_asc', 'price_desc'
  String _metricFilter = 'all'; // 'all', 'high_yield', 'short_duration', 'priced'
  bool _showWishlistOnly = false;
  int _activeBannerIndex = 0;

  final Set<int> _wishlistIds = {};
  Locale? _lastLocale;

  @override
  void initState() {
    super.initState();
    if (widget.initialCrop != null && widget.initialCrop!.isNotEmpty) {
      _selectedCrop = widget.initialCrop!;
    }
    _searchController.addListener(() {
      final query = _searchController.text.trim().toLowerCase();
      if (query != _searchQuery) {
        setState(() => _searchQuery = query);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bannerPageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = context.locale;
    if (_lastLocale != currentLocale) {
      _lastLocale = currentLocale;
      _varietiesFuture = _fetchVarieties();
    }
  }

  Future<List<SeedVariety>> _fetchVarieties() async {
    try {
      final locale = context.locale.languageCode;
      final user = AuthService.currentUser;

      final response = await ApiService.getSeedVarieties(
        lang: locale,
        userId: user?.userId,
      );
      _allVarieties = response.map((v) => SeedVariety.fromJson(v)).toList();

      if (mounted) {
        if (widget.initialVarietyId != null) {
          final target = _allVarieties
              .where((v) => v.id == widget.initialVarietyId)
              .firstOrNull;
          if (target != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        SeedVarietyDetailScreen(variety: target),
                  ),
                );
              }
            });
          }
        }
      }
      return _allVarieties;
    } catch (e) {
      rethrow;
    }
  }

  void _toggleWishlist(int seedId) {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_wishlistIds.contains(seedId)) {
        _wishlistIds.remove(seedId);
      } else {
        _wishlistIds.add(seedId);
      }
    });
  }

  List<SeedVariety> _getFilteredVarieties() {
    var list = List<SeedVariety>.from(_allVarieties);

    // Filter by Crop
    if (_selectedCrop != 'all') {
      list = list.where((v) => v.cropName == _selectedCrop).toList();
    }

    // Filter by Wishlist
    if (_showWishlistOnly) {
      list = list.where((v) => _wishlistIds.contains(v.id)).toList();
    }

    // Filter by Search Query
    if (_searchQuery.isNotEmpty) {
      list = list.where((v) {
        final cropTr = _getTranslatedCropName(context, v.cropName).toLowerCase();
        final variety = v.varietyName.toLowerCase();
        final secondary = (v.varietyNameSecondary ?? '').toLowerCase();
        return variety.contains(_searchQuery) ||
            cropTr.contains(_searchQuery) ||
            v.cropName.toLowerCase().contains(_searchQuery) ||
            secondary.contains(_searchQuery);
      }).toList();
    }

    // Metric Filter
    if (_metricFilter == 'high_yield') {
      list = list.where((v) => (v.averageYield ?? 0) >= 20).toList();
    } else if (_metricFilter == 'short_duration') {
      list = list.where((v) => (v.growthDuration ?? 999) <= 120).toList();
    } else if (_metricFilter == 'priced') {
      list = list.where((v) => v.price != null && v.price!.trim().isNotEmpty).toList();
    }

    // Sorting
    if (_sortOrder == 'yield_desc') {
      list.sort((a, b) => (b.averageYield ?? 0).compareTo(a.averageYield ?? 0));
    } else if (_sortOrder == 'duration_asc') {
      list.sort((a, b) =>
          (a.growthDuration ?? 999).compareTo(b.growthDuration ?? 999));
    } else if (_sortOrder == 'price_asc') {
      list.sort((a, b) => a.priceValue.compareTo(b.priceValue));
    } else if (_sortOrder == 'price_desc') {
      list.sort((a, b) => b.priceValue.compareTo(a.priceValue));
    }

    return list;
  }

  void _navigateToDetail(SeedVariety variety) {
    HapticFeedback.lightImpact();
    FarmerAnalyticsService.logSeedVarietyView(
      seedId: variety.id,
      varietyName: variety.varietyName,
      cropName: variety.cropName,
      price: variety.price,
      averageYield: variety.averageYield,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SeedVarietyDetailScreen(variety: variety),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: FutureBuilder<List<SeedVariety>>(
        future: _varietiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _allVarieties.isEmpty) {
            return const _SeedShimmer();
          }

          if (snapshot.hasError && _allVarieties.isEmpty) {
            return _buildErrorView(snapshot.error.toString());
          }

          final filteredList = _getFilteredVarieties();
          final cropNames =
              _allVarieties.map((v) => v.cropName).toSet().toList();

          return RefreshIndicator(
            color: const Color(0xFF047857),
            backgroundColor: Colors.white,
            onRefresh: () async {
              setState(() {
                _varietiesFuture = _fetchVarieties();
              });
              await _varietiesFuture;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                _buildEcommerceAppBar(),
                _buildLocationStrip(),
                if (!_showWishlistOnly) ...[
                  _buildSearchHeader(),
                  _buildPromotionalBanners(),
                  _buildCropSelectorRail(cropNames),
                  _buildMetricFilterChips(),
                  _buildTrendingSeedsCarousel(),
                ],
                if (_showWishlistOnly) _buildWishlistActiveHeader(),
                _buildSectionHeader(filteredList.length),
                ..._buildSeedGridSlivers(filteredList),
                _buildTrustAssuranceFooter(),
                const SliverToBoxAdapter(child: SizedBox(height: 70)),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildAssistanceStickyBar(),
    );
  }

  // =========================================================================
  // APP BAR & LOCATION HEADER
  // =========================================================================

  Widget _buildEcommerceAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      centerTitle: false,
      leading: AppTheme.backButton(context),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF047857).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.spa_rounded,
              color: Color(0xFF047857),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('seed_varieties_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'ICAR & University Certified',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Wishlist Quick Access Toggle
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Material(
                color: _showWishlistOnly
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFF1F5F9),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _showWishlistOnly = !_showWishlistOnly);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Icon(
                      _showWishlistOnly
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 20,
                      color: _showWishlistOnly
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
              if (_wishlistIds.isNotEmpty)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      '${_wishlistIds.length}',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
          height: 0.7,
        ),
      ),
    );
  }

  Widget _buildLocationStrip() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFFECFDF5),
        child: Row(
          children: [
            const Icon(
              Icons.verified_outlined,
              size: 15,
              color: Color(0xFF047857),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Direct Research Seed Stock: 100% Breeder Authenticity',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF065F46),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Text(
                'CERTIFIED',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF047857),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SEARCH & FILTER BAR
  // =========================================================================

  Widget _buildSearchHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: context.tr('search_seeds_hint'),
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                      fontSize: 13.5,
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 14, right: 10),
                      child: Icon(
                        Icons.search_rounded,
                        color: Color(0xFF047857),
                        size: 22,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 22,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.cancel_rounded,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Filter / Sort button
            Material(
              color: (_sortOrder != 'default' || _metricFilter != 'all')
                  ? const Color(0xFF047857)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: _showAdvancedSortModal,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (_sortOrder != 'default' || _metricFilter != 'all')
                          ? const Color(0xFF047857)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 21,
                        color: (_sortOrder != 'default' ||
                                _metricFilter != 'all')
                            ? Colors.white
                            : const Color(0xFF334155),
                      ),
                      if (_sortOrder != 'default' || _metricFilter != 'all')
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF59E0B),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // PROMOTIONAL BANNER CAROUSEL
  // =========================================================================

  Widget _buildPromotionalBanners() {
    final banners = [
      {
        'tag': 'ICAR RESEARCH',
        'title': context.tr('breeder_seeds_title'),
        'subtitle': context.tr('breeder_seeds_subtitle'),
        'gradient': [const Color(0xFF064E3B), const Color(0xFF047857)],
        'icon': Icons.verified_rounded,
        'badge': 'GENUINE 100%',
      },
      {
        'tag': 'STATE FIELD TRIALS',
        'title': context.tr('multi_region_trials'),
        'subtitle': context.tr('multi_region_trials_desc'),
        'gradient': [const Color(0xFF1E293B), const Color(0xFF0F172A)],
        'icon': Icons.analytics_outlined,
        'badge': 'TESTED YIELD',
      },
      {
        'tag': 'OFFICIAL PACKAGING',
        'title': context.tr('sealed_bag_delivery'),
        'subtitle': context.tr('sealed_bag_delivery_desc'),
        'gradient': [const Color(0xFF78350F), const Color(0xFFB45309)],
        'icon': Icons.local_shipping_rounded,
        'badge': 'KIOSK DROP',
      },
    ];

    return SliverToBoxAdapter(
      child: Column(
        children: [
          SizedBox(
            height: 140,
            child: PageView.builder(
              controller: _bannerPageController,
              itemCount: banners.length,
              onPageChanged: (index) {
                setState(() => _activeBannerIndex = index);
              },
              itemBuilder: (context, index) {
                final b = banners[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: b['gradient'] as List<Color>,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: (b['gradient'] as List<Color>)[0]
                              .withValues(alpha: 0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      b['tag'] as String,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      b['badge'] as String,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFF78350F),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                b['title'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                b['subtitle'] as String,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            b['icon'] as IconData,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Page indicator dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              banners.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _activeBannerIndex == i ? 18 : 6,
                height: 5,
                decoration: BoxDecoration(
                  color: _activeBannerIndex == i
                      ? const Color(0xFF047857)
                      : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // =========================================================================
  // CROP SELECTOR RAIL (HORIZONTAL CHIPS WITH DIRECT IN-PLACE FILTERING)
  // =========================================================================

  Widget _buildCropSelectorRail(List<String> cropNames) {
    final list = ['all', ...cropNames];

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Crop',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  '${cropNames.length} crops available',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final crop = list[index];
                final isSelected = _selectedCrop == crop;
                final icon = _getCropIcon(crop);
                final displayName = crop == 'all'
                    ? context.tr('all_filter')
                    : _getTranslatedCropName(context, crop);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCrop = crop);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF047857)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF047857)
                                : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF047857)
                                        .withValues(alpha: 0.22),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A)
                                        .withValues(alpha: 0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF047857),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              displayName,
                              style: GoogleFonts.plusJakartaSans(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  IconData _getCropIcon(String crop) {
    final lower = crop.toLowerCase();
    if (lower == 'all') return Icons.grid_view_rounded;
    if (lower.contains('paddy') || lower.contains('rice') || lower.contains('వరి') || lower.contains('धान')) {
      return Icons.grass_rounded;
    }
    if (lower.contains('cotton') || lower.contains('పత్తి') || lower.contains('कपास')) {
      return Icons.cloud_outlined;
    }
    if (lower.contains('chilli') || lower.contains('chili') || lower.contains('మిరప') || lower.contains('मिर्च')) {
      return Icons.local_fire_department_rounded;
    }
    if (lower.contains('maize') || lower.contains('corn') || lower.contains('మొక్కజొన్న') || lower.contains('मक्का')) {
      return Icons.grain_rounded;
    }
    if (lower.contains('groundnut') || lower.contains('peanut') || lower.contains('వేరుశనగ')) {
      return Icons.circle_outlined;
    }
    if (lower.contains('wheat') || lower.contains('గోధుమ') || lower.contains('गेहूं')) {
      return Icons.eco_rounded;
    }
    return Icons.spa_rounded;
  }

  // =========================================================================
  // METRIC QUICK FILTERS
  // =========================================================================

  Widget _buildMetricFilterChips() {
    final filters = [
      {'id': 'all', 'label': 'All Varieties'},
      {'id': 'high_yield', 'label': '⚡ High Yield (≥20Q)'},
      {'id': 'short_duration', 'label': '⏱️ Short Duration (≤120d)'},
      {'id': 'priced', 'label': '🏷️ Priced & Bookable'},
    ];

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: filters.length,
            itemBuilder: (context, index) {
              final f = filters[index];
              final isSelected = _metricFilter == f['id'];

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(
                    f['label']!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF047857)
                          : const Color(0xFF475569),
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (val) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _metricFilter = f['id']!;
                    });
                  },
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xFFD1FAE5),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF059669)
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TRENDING / TOP SEEDS CAROUSEL
  // =========================================================================

  Widget _buildTrendingSeedsCarousel() {
    final topYieldVarieties = _allVarieties
        .where((v) => (v.averageYield ?? 0) >= 20)
        .take(6)
        .toList();

    if (topYieldVarieties.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFFD97706),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'High-Yield Recommendations',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Top Yielders',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 114,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: topYieldVarieties.length,
              itemBuilder: (context, index) {
                final v = topYieldVarieties[index];
                return Container(
                  width: 270,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _navigateToDetail(v),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            // Thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 80,
                                height: 88,
                                color: const Color(0xFFF8FAFC),
                                child: CachedNetworkImage(
                                  imageUrl: v.imageUrl ?? '',
                                  fit: BoxFit.contain,
                                  placeholder: (_, __) => const Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => const Icon(
                                    Icons.grass_rounded,
                                    color: Color(0xFF10B981),
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${v.averageYield} Q/Acre Yield',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFF047857),
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    v.varietyName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        v.price != null
                                            ? '₹${v.price}'
                                            : 'Pre-book',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF047857),
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF047857),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white,
                                          size: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // =========================================================================
  // SECTION HEADER & WISHLIST FILTER HEADER
  // =========================================================================

  Widget _buildWishlistActiveHeader() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.favorite_rounded,
                color: Color(0xFFEF4444), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Showing Saved Seed Varieties',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: const Color(0xFF991B1B),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _showWishlistOnly = false),
              child: Text(
                'View All',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: const Color(0xFF047857),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(int count) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _showWishlistOnly
                    ? 'Saved Seeds ($count)'
                    : (_selectedCrop == 'all'
                        ? 'All Certified Seeds ($count)'
                        : '${_getTranslatedCropName(context, _selectedCrop)} ($count)'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: _showAdvancedSortModal,
                  child: Row(
                    children: [
                      Text(
                        _sortOrder == 'yield_desc'
                            ? 'Top Yield'
                            : (_sortOrder == 'duration_asc'
                                ? 'Fast Maturity'
                                : (_sortOrder == 'price_asc'
                                    ? 'Price: Low'
                                    : 'Default')),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF047857),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF047857),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SEED GRID SLIVERS
  // =========================================================================

  List<Widget> _buildSeedGridSlivers(List<SeedVariety> varieties) {
    if (varieties.isEmpty) {
      return [SliverToBoxAdapter(child: _buildEmptyState())];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            childAspectRatio: 0.58,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final variety = varieties[index];
              return _EcommerceSeedCard(
                key: ValueKey(variety.id),
                variety: variety,
                isWishlisted: _wishlistIds.contains(variety.id),
                onWishlistToggle: () => _toggleWishlist(variety.id),
                onTap: () => _navigateToDetail(variety),
              );
            },
            childCount: varieties.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: Color(0xFF047857),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('no_varieties_found'),
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF0F172A),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No seed varieties match your selected crop or filter criteria. Try clearing search or reset filters.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                  _selectedCrop = 'all';
                  _sortOrder = 'default';
                  _metricFilter = 'all';
                  _showWishlistOnly = false;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Reset All Filters',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(
              context.tr('load_error'),
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _varietiesFuture = _fetchVarieties();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TRUST & ASSURANCE FOOTER
  // =========================================================================

  Widget _buildTrustAssuranceFooter() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF047857),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('crop_sync_seed_guarantee'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        context.tr('why_order_seeds'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 14),
            _buildAssurancePillar(
              Icons.biotech_outlined,
              context.tr('breeder_authenticity'),
              context.tr('breeder_authenticity_desc'),
            ),
            const SizedBox(height: 12),
            _buildAssurancePillar(
              Icons.analytics_outlined,
              context.tr('multi_region_trials'),
              context.tr('multi_region_trials_desc'),
            ),
            const SizedBox(height: 12),
            _buildAssurancePillar(
              Icons.local_shipping_outlined,
              context.tr('sealed_bag_delivery'),
              context.tr('sealed_bag_delivery_desc'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssurancePillar(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF047857)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // STICKY ASSISTANCE BAR
  // =========================================================================

  Widget _buildAssistanceStickyBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(
            color: Color(0xFFE2E8F0),
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Color(0xFF047857),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need Help Choosing Seed Varieties?',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Free Soil & Weather Advisory from Agronomists',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF047857),
                  content: Text(
                    'CropSync Agronomist connected! Calling seed specialist...',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            ),
            child: Text(
              'Call Help',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ADVANCED SORT & FILTER MODAL
  // =========================================================================

  void _showAdvancedSortModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sort & Filter Seeds',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _sortOrder = 'default';
                            _metricFilter = 'all';
                          });
                          setState(() {
                            _sortOrder = 'default';
                            _metricFilter = 'all';
                          });
                        },
                        child: Text(
                          'Reset',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFEF4444),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'SORT BY',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSortRadioTile(
                    label: 'Relevance / Recommended',
                    value: 'default',
                    groupValue: _sortOrder,
                    onTap: () {
                      setSheetState(() => _sortOrder = 'default');
                      setState(() => _sortOrder = 'default');
                    },
                  ),
                  _buildSortRadioTile(
                    label: 'Highest Yield (Q/Acre)',
                    value: 'yield_desc',
                    groupValue: _sortOrder,
                    onTap: () {
                      setSheetState(() => _sortOrder = 'yield_desc');
                      setState(() => _sortOrder = 'yield_desc');
                    },
                  ),
                  _buildSortRadioTile(
                    label: 'Shortest Duration (Fast Harvest)',
                    value: 'duration_asc',
                    groupValue: _sortOrder,
                    onTap: () {
                      setSheetState(() => _sortOrder = 'duration_asc');
                      setState(() => _sortOrder = 'duration_asc');
                    },
                  ),
                  _buildSortRadioTile(
                    label: 'Price: Low to High',
                    value: 'price_asc',
                    groupValue: _sortOrder,
                    onTap: () {
                      setSheetState(() => _sortOrder = 'price_asc');
                      setState(() => _sortOrder = 'price_asc');
                    },
                  ),
                  _buildSortRadioTile(
                    label: 'Price: High to Low',
                    value: 'price_desc',
                    groupValue: _sortOrder,
                    onTap: () {
                      setSheetState(() => _sortOrder = 'price_desc');
                      setState(() => _sortOrder = 'price_desc');
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        context.tr('apply_filters'),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortRadioTile({
    required String label,
    required String value,
    required String groupValue,
    required VoidCallback onTap,
  }) {
    final isSelected = value == groupValue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF047857)
                      : const Color(0xFF334155),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF047857),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// HIGH CRAFT E-COMMERCE SEED CARD
// ===========================================================================

class _EcommerceSeedCard extends StatefulWidget {
  final SeedVariety variety;
  final bool isWishlisted;
  final VoidCallback onWishlistToggle;
  final VoidCallback onTap;

  const _EcommerceSeedCard({
    super.key,
    required this.variety,
    required this.isWishlisted,
    required this.onWishlistToggle,
    required this.onTap,
  });

  @override
  State<_EcommerceSeedCard> createState() => _EcommerceSeedCardState();
}

class _EcommerceSeedCardState extends State<_EcommerceSeedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawPrice = widget.variety.priceValue;
    final originalMrp = (rawPrice * 1.25).round();
    final savings = originalMrp - rawPrice.round();

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _animController.forward();
      },
      onTapUp: (_) {
        _animController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _animController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= IMAGE AREA =================
              Expanded(
                flex: 11,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.all(8),
                      child: Hero(
                        tag: 'seed_image_${widget.variety.id}',
                        child: CachedNetworkImage(
                          imageUrl: widget.variety.imageUrl ?? '',
                          fit: BoxFit.contain,
                          memCacheWidth: 300,
                          placeholder: (context, url) => Container(
                            color: const Color(0xFFF1F5F9),
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFFF1F5F9),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.spa_rounded,
                              color: Color(0xFF10B981),
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // ICAR / Certified Badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF064E3B), Color(0xFF047857)],
                          ),
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF064E3B)
                                  .withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          'CERTIFIED',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                    // Video Indicator Badge
                    if (widget.variety.testimonialVideoUrl != null &&
                        widget.variety.testimonialVideoUrl!.isNotEmpty)
                      Positioned(
                        bottom: 6,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                context.tr('video_badge'),
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Wishlist Heart Button
                    Positioned(
                      top: 6,
                      right: 6,
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.85),
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: widget.onWishlistToggle,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: Icon(
                                  widget.isWishlisted
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 15,
                                  color: widget.isWishlisted
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Share Button (Bottom Right)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.85),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            final priceStr = widget.variety.price != null
                                ? '₹${widget.variety.price}${widget.variety.priceUnit != null ? " / ${widget.variety.priceUnit}" : ""}'
                                : null;
                            ShareService.shareItem(
                              context: context,
                              type: 'seed',
                              id: widget.variety.id.toString(),
                              crop: widget.variety.cropName,
                              title:
                                  '${widget.variety.varietyName} (${widget.variety.cropName})',
                              price: priceStr,
                              description: widget.variety.details ??
                                  'High-yielding seed variety available on CropSync.',
                              imageUrl: widget.variety.imageUrl,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            child: const Icon(
                              Icons.share_outlined,
                              size: 13,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ================= DETAILS AREA =================
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Crop tag
                    Row(
                      children: [
                        const Icon(
                          Icons.eco_rounded,
                          color: Color(0xFF047857),
                          size: 11,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            _getTranslatedCropName(
                                context, widget.variety.cropName),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF047857),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Variety Name
                    Text(
                      widget.variety.varietyName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Performance Metrics Tag Row
                    Row(
                      children: [
                        if (widget.variety.averageYield != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${widget.variety.averageYield}Q Yield',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF047857),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (widget.variety.growthDuration != null)
                          Text(
                            '${widget.variety.growthDuration}d maturity',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Pricing Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        if (rawPrice > 0) ...[
                          Text(
                            '₹${widget.variety.price}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (savings > 0) ...[
                            const SizedBox(width: 5),
                            Text(
                              '₹$originalMrp',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF94A3B8),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ] else
                          Text(
                            'Pre-order / Enquire',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF047857),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Order / View CTA Button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF047857),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.white,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.tr('view_details'),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// SUB-SCREEN: CROP SPECIFIC VARIETIES (RETAINED FOR COMPATIBILITY)
// ===========================================================================

class CropVarietiesListScreen extends StatelessWidget {
  final String cropName;
  final List<SeedVariety> varieties;

  const CropVarietiesListScreen({
    super.key,
    required this.cropName,
    required this.varieties,
  });

  @override
  Widget build(BuildContext context) {
    final translatedCrop = _getTranslatedCropName(context, cropName);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 64,
        leading: AppTheme.backButton(context),
        title: Column(
          children: [
            Text(
              '$translatedCrop ${context.tr("varieties")}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
            Text(
              '${varieties.length} ${context.tr("varieties_verified")}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFE2E8F0),
            height: 0.8,
          ),
        ),
      ),
      body: varieties.isEmpty
          ? Center(
              child: Text(
                context.tr('no_varieties_found'),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.grey[500],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(14),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                childAspectRatio: 0.58,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
              ),
              itemCount: varieties.length,
              itemBuilder: (context, index) {
                return _EcommerceSeedCard(
                  variety: varieties[index],
                  isWishlisted: false,
                  onWishlistToggle: () {},
                  onTap: () {
                    HapticFeedback.lightImpact();
                    FarmerAnalyticsService.logSeedVarietyView(
                      seedId: varieties[index].id,
                      varietyName: varieties[index].varietyName,
                      cropName: varieties[index].cropName,
                      price: varieties[index].price,
                      averageYield: varieties[index].averageYield,
                    );
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            SeedVarietyDetailScreen(variety: varieties[index]),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

// ===========================================================================
// SUB-SCREEN: SEED VARIETY DETAIL SCREEN (LUXURY SPECIFICATIONS & BOOKING)
// ===========================================================================

class SeedVarietyDetailScreen extends StatefulWidget {
  final SeedVariety variety;

  const SeedVarietyDetailScreen({super.key, required this.variety});

  @override
  State<SeedVarietyDetailScreen> createState() =>
      _SeedVarietyDetailScreenState();
}

class _SeedVarietyDetailScreenState extends State<SeedVarietyDetailScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isVideoLoading = false;
  bool _showVideo = false;
  double _quantity = 1.0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    if (_videoController != null ||
        widget.variety.testimonialVideoUrl == null) {
      if (_videoController != null) {
        setState(() => _showVideo = true);
        _videoController!.play();
      }
      return;
    }

    setState(() => _isVideoLoading = true);

    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.variety.testimonialVideoUrl!),
      );
      await _videoController!.initialize();

      if (mounted) {
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: true,
          looping: false,
          aspectRatio: _videoController!.value.aspectRatio,
          showControls: true,
          materialProgressColors: ChewieProgressColors(
            playedColor: const Color(0xFF047857),
            handleColor: const Color(0xFF047857),
            bufferedColor: Colors.grey[300]!,
            backgroundColor: Colors.grey[200]!,
          ),
        );
        setState(() {
          _showVideo = true;
          _isVideoLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVideoLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load video')),
        );
      }
    }
  }

  double get _totalPrice => widget.variety.priceValue * _quantity;

  Future<void> _submitPurchase() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final user = AuthService.currentUser;

      if (user == null) throw Exception('Not logged in');

      final bookingId = 'SB${DateTime.now().millisecondsSinceEpoch}';

      final result = await ApiService.createSeedBooking(
        bookingId: bookingId,
        userId: user.userId,
        seedVarietyId: widget.variety.id,
        quantityKg: _quantity,
        totalPrice: _totalPrice,
      );

      if (result['success'] == true) {
        FarmerAnalyticsService.logSeedBooking(
          seedId: widget.variety.id,
          varietyName: widget.variety.varietyName,
          cropName: widget.variety.cropName,
          quantity: _quantity,
        );

        if (!mounted) return;
        _showSuccessPopup(context.tr('purchase_request_sent'));
      } else {
        throw Exception(result['error'] ?? 'Failed');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${context.tr('error')}: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessPopup(String message) {
    AppSuccessDialog.show(
      context,
      title: context.tr('success'),
      message: message,
      buttonText: context.tr('ok'),
      onConfirm: () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final variety = widget.variety;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Scrollable Body
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: variety.price != null ? 140 : 40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroMediaShowcase(),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitleSection(),
                        const SizedBox(height: 20),
                        _buildSpecsMatrix(),
                        const SizedBox(height: 20),
                        _buildRegionSection(),
                        const SizedBox(height: 20),
                        _buildAgronomicCharacteristics(),
                        const SizedBox(height: 20),
                        _buildAuthenticityBanner(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Top Navigation Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildFloatingTopBar(),
          ),

          // Bottom Sticky Booking Bar
          if (variety.price != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildStickyBookingBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingTopBar() {
    final topPadding = MediaQuery.of(context).padding.top;
    final variety = widget.variety;

    return Container(
      padding: EdgeInsets.fromLTRB(16, topPadding + 6, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildFrostedButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_rounded,
                    size: 14, color: Color(0xFF047857)),
                const SizedBox(width: 4),
                Text(
                  context.tr('certified_seed'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF047857),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          _buildFrostedButton(
            icon: Icons.share_outlined,
            onTap: () {
              final priceStr = variety.price != null
                  ? '₹${variety.price}${variety.priceUnit != null ? " / ${variety.priceUnit}" : ""}'
                  : null;
              ShareService.shareItem(
                context: context,
                type: 'seed',
                id: variety.id.toString(),
                crop: variety.cropName,
                title: '${variety.varietyName} (${variety.cropName})',
                price: priceStr,
                description: variety.details ??
                    'High-yielding seed variety available on CropSync.',
                imageUrl: variety.imageUrl,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFrostedButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.white.withValues(alpha: 0.85),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF0F172A)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroMediaShowcase() {
    final heroHeight = MediaQuery.of(context).size.height * 0.40;
    final variety = widget.variety;

    return Container(
      height: heroHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8FAFC), Color(0xFFEDF2F7)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_showVideo && _chewieController != null)
            Chewie(controller: _chewieController!)
          else
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                MediaQuery.of(context).padding.top + 50,
                24,
                variety.testimonialVideoUrl != null ? 56 : 20,
              ),
              child: CachedNetworkImage(
                imageUrl: variety.imageUrl ?? '',
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
                errorWidget: (_, __, ___) => Center(
                  child: Icon(Icons.grass_rounded,
                      size: 64, color: Colors.grey[400]),
                ),
              ),
            ),
          if (variety.testimonialVideoUrl != null && !_showVideo)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isVideoLoading ? null : _initVideo,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _isVideoLoading
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  context.tr('loading_video'),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF10B981),
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded,
                                      size: 13, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  context.tr('watch_video_advisory'),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    final variety = widget.variety;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Text(
                '${_getTranslatedCropName(context, variety.cropName).toUpperCase()} ${context.tr("hybrid")}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF047857),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    context.tr('available_for_order'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          variety.varietyName,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.6,
            height: 1.15,
          ),
        ),
        if (variety.varietyNameSecondary != null &&
            variety.varietyNameSecondary != variety.varietyName) ...[
          const SizedBox(height: 3),
          Text(
            variety.varietyNameSecondary!,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (variety.price != null) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹${variety.price}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.6,
                ),
              ),
              if (variety.priceUnit != null &&
                  variety.priceUnit!.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  '/ ${variety.priceUnit}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSpecsMatrix() {
    final variety = widget.variety;
    final statCards = <Widget>[];

    if (variety.growthDuration != null) {
      statCards.add(
        _buildStatTile(
          icon: Icons.schedule_rounded,
          iconColor: const Color(0xFF2563EB),
          bgColor: const Color(0xFFEFF6FF),
          label: context.tr('growth_duration'),
          value: '${variety.growthDuration} ${context.tr('days')}',
          subtext: context.tr('sowing_to_maturity'),
        ),
      );
    }

    if (variety.averageYield != null) {
      statCards.add(
        _buildStatTile(
          icon: Icons.trending_up_rounded,
          iconColor: const Color(0xFF047857),
          bgColor: const Color(0xFFECFDF5),
          label: context.tr('average_yield'),
          value:
              '${variety.averageYield} ${context.tr('quintals_per_acre_short')}',
          subtext: context.tr('quintals_per_acre'),
        ),
      );
    }

    if (variety.sowingPeriod != null &&
        variety.sowingPeriod!.trim().isNotEmpty) {
      statCards.add(
        _buildStatTile(
          icon: Icons.calendar_month_rounded,
          iconColor: const Color(0xFFD97706),
          bgColor: const Color(0xFFFFFBEB),
          label: context.tr('sowing_period'),
          value:
              _getTranslatedSowingPeriod(context, variety.sowingPeriod!.trim()),
          subtext: context.tr('ideal_season_window'),
        ),
      );
    }

    if (statCards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('key_agronomic_metrics'),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: statCards
              .map((tile) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: tile,
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
    required String subtext,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRegionSection() {
    final variety = widget.variety;
    if (variety.region == null || variety.region!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final rawRegion = variety.region!.trim();
    final states = rawRegion
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place_rounded,
                  size: 18, color: Color(0xFF047857)),
              const SizedBox(width: 8),
              Text(
                context.tr('recommended_regions'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: states.map((state) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF047857),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getTranslatedRegion(context, state),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAgronomicCharacteristics() {
    final variety = widget.variety;
    if (variety.details == null || variety.details!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final rawDetails = variety.details!.trim();
    final List<MapEntry<String, String>> attributes = [];
    final List<String> paragraphs = [];

    final segments = rawDetails.split(RegExp(r'(?<=\.)\s+'));

    for (final seg in segments) {
      if (seg.contains(':')) {
        final parts = seg.split(':');
        if (parts.length >= 2) {
          final key = parts[0].replaceAll('.', '').trim();
          final val = parts.sublist(1).join(':').replaceAll('.', '').trim();
          if (key.isNotEmpty && val.isNotEmpty) {
            attributes.add(MapEntry(key, val));
            continue;
          }
        }
      }
      if (seg.trim().isNotEmpty) {
        paragraphs.add(seg.trim());
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined,
                  size: 18, color: Color(0xFF0F172A)),
              const SizedBox(width: 8),
              Text(
                context.tr('variety_specifications'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (attributes.isNotEmpty) ...[
            ...attributes.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          entry.key,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          if (paragraphs.isNotEmpty) ...[
            if (attributes.isNotEmpty) const SizedBox(height: 8),
            Text(
              paragraphs.join(' '),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF475569),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAuthenticityBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_rounded,
              color: Color(0xFF047857), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('breeder_guarantee'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF065F46),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr('breeder_guarantee_desc'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF047857),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBookingBar() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final variety = widget.variety;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, bottomPadding + 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Quantity Controls
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_rounded,
                      size: 18, color: Color(0xFF0F172A)),
                  onPressed: _quantity > 1
                      ? () => setState(() => _quantity -= 1)
                      : null,
                ),
                Text(
                  '${_quantity.toInt()} ${variety.priceUnit ?? "kg"}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_rounded,
                      size: 18, color: Color(0xFF0F172A)),
                  onPressed: () => setState(() => _quantity += 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Price and Order CTA
          Expanded(
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitPurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_bag_outlined,
                            size: 18, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'Order ₹${_totalPrice.toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// SHIMMER PLACEHOLDER FOR INITIAL LOAD
// ===========================================================================

class _SeedShimmer extends StatelessWidget {
  const _SeedShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF8FAFC),
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              height: 140,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(14),
            sliver: SliverGrid(
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                childAspectRatio: 0.58,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                childCount: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
