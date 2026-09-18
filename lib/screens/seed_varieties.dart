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
  final key = cropName.toLowerCase();
  final translated = context.tr(key);
  return translated == key ? cropName : translated;
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
      varietyNameSecondary: json['variety_name_secondary']?.toString(),
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

/// Main seed varieties screen - Crop Selection & Directory
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
  String _searchQuery = '';
  Locale? _lastLocale;

  @override
  void initState() {
    super.initState();
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
        if (widget.initialCrop != null && widget.initialCrop!.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigateToCrop(widget.initialCrop!);
          });
        } else if (widget.initialVarietyId != null) {
          final target = _allVarieties
              .where((v) => v.id == widget.initialVarietyId)
              .firstOrNull;
          if (target != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SeedVarietyDetailScreen(variety: target),
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

  void _navigateToCrop(String cropName) {
    HapticFeedback.selectionClick();
    final varietiesForCrop =
        _allVarieties.where((v) => v.cropName == cropName).toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CropVarietiesListScreen(
          cropName: cropName,
          varieties: varietiesForCrop,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          _buildFeaturedHero(),
          _buildSearchBar(),
          _buildCropsGridSection(),
          _buildTrustSection(),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      floating: false,
      leadingWidth: 64,
      leading: AppTheme.backButton(context),
      title: Text(
        context.tr('seed_varieties_title'),
        style: GoogleFonts.googleSans(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF0F172A),
          letterSpacing: -0.4,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: const Color(0xFFE2E8F0),
          height: 1,
        ),
      ),
    );
  }

  Widget _buildFeaturedHero() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF047857).withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded,
                      color: Color(0xFFFDE047), size: 14),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'ICAR & Research Certified',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.googleSans(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'High-Yielding Breeder Seeds',
              style: GoogleFonts.googleSans(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Direct access to pure, high-germination hybrid seeds with regional maturity & yield assurance.',
              style: GoogleFonts.googleSans(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildHeroFeatureChip(Icons.shield_outlined, '100% Genuine'),
                _buildHeroFeatureChip(Icons.trending_up, 'Yield Tested'),
                _buildHeroFeatureChip(Icons.local_shipping_outlined, 'Farm Delivery'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroFeatureChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.googleSans(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.googleSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'Search crops or seed varieties...',
              hintStyle: GoogleFonts.googleSans(
                fontSize: 14,
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF64748B), size: 22),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          size: 18, color: Color(0xFF64748B)),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCropsGridSection() {
    return FutureBuilder<List<SeedVariety>>(
      future: _varietiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(child: _SeedShimmer());
        }
        if (snapshot.hasError) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded,
                      size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('load_error'),
                    style: GoogleFonts.googleSans(
                      color: const Color(0xFF64748B),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final cropTypes = _allVarieties.map((v) => v.cropName).toSet().toList();
        final filteredCrops = cropTypes.where((crop) {
          if (_searchQuery.isEmpty) return true;
          final translated = _getTranslatedCropName(context, crop).toLowerCase();
          final hasMatchingVariety = _allVarieties
              .where((v) => v.cropName == crop)
              .any((v) => v.varietyName.toLowerCase().contains(_searchQuery));
          return crop.toLowerCase().contains(_searchQuery) ||
              translated.contains(_searchQuery) ||
              hasMatchingVariety;
        }).toList();

        if (filteredCrops.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded,
                        size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'No matching crops found',
                      style: GoogleFonts.googleSans(
                        color: const Color(0xFF64748B),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.78,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final crop = filteredCrops[index];
                final varietiesForThisCrop =
                    _allVarieties.where((v) => v.cropName == crop).toList();

                // Pick representative variety image if available
                final sampleWithImage = varietiesForThisCrop
                    .where((v) => v.imageUrl != null && v.imageUrl!.isNotEmpty)
                    .firstOrNull;

                final representativeUrl = sampleWithImage?.imageUrl ??
                    CommodityTranslator.resolveImageUrl(crop);

                return _CropCard(
                  cropName: crop,
                  varietyCount: varietiesForThisCrop.length,
                  imageUrl: representativeUrl,
                  onTap: () => _navigateToCrop(crop),
                );
              },
              childCount: filteredCrops.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrustSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.verified_user_rounded,
                      color: Color(0xFF059669), size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CropSync Seed Guarantee',
                      style: GoogleFonts.googleSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Why farmers order through CropSync',
                      style: GoogleFonts.googleSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 14),
            _buildTrustRow(
              Icons.biotech_outlined,
              'Breeder Authenticity',
              'Pure genetic seed stock sourced directly from accredited research stations.',
            ),
            const SizedBox(height: 12),
            _buildTrustRow(
              Icons.analytics_outlined,
              'Multi-Region Field Trials',
              'Tested yield numbers and growth duration verified in your state agro-climate.',
            ),
            const SizedBox(height: 12),
            _buildTrustRow(
              Icons.local_shipping_outlined,
              'Sealed Bag Delivery',
              'Tamper-proof official packaging delivered to your nearest CHC / Farm Center.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF059669)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.googleSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.googleSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Category Card for Crops with Rich Imagery & Fallback
class _CropCard extends StatelessWidget {
  final String cropName;
  final int varietyCount;
  final String imageUrl;
  final VoidCallback onTap;

  const _CropCard({
    required this.cropName,
    required this.varietyCount,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final translatedName = _getTranslatedCropName(context, cropName);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Container with clean background
              Expanded(
                flex: 12,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.all(12),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        memCacheWidth: 300,
                        placeholder: (context, url) => Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            _buildArtFallback(),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          'ICAR',
                          style: GoogleFonts.googleSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF047857),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Crop Details Container
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      translatedName,
                      style: GoogleFonts.googleSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$varietyCount ${context.tr("varieties")}',
                            style: GoogleFonts.googleSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFF8FAFC),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 13,
                            color: Color(0xFF059669),
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
    );
  }

  Widget _buildArtFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFECFDF5),
            const Color(0xFFD1FAE5).withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF059669).withValues(alpha: 0.15),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.grass_rounded,
                size: 26,
                color: Color(0xFF059669),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              cropName,
              style: GoogleFonts.googleSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF065F46),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen displaying the seeds for a specific crop
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
      backgroundColor: const Color(0xFFF8FAFC),
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
              style: GoogleFonts.googleSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
            Text(
              '${varieties.length} varieties verified',
              style: GoogleFonts.googleSans(
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
            height: 1,
          ),
        ),
      ),
      body: varieties.isEmpty
          ? Center(
              child: Text(
                context.tr('no_varieties_found'),
                style: GoogleFonts.googleSans(
                  color: Colors.grey[500],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.64,
              ),
              itemCount: varieties.length,
              itemBuilder: (context, index) {
                return _SeedCard(
                  variety: varieties[index],
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

/// Seed product card with high-conversion e-commerce layout
class _SeedCard extends StatelessWidget {
  final SeedVariety variety;
  final VoidCallback onTap;

  const _SeedCard({required this.variety, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section with badges
              Expanded(
                flex: 13,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.all(8),
                      child: CachedNetworkImage(
                        imageUrl: variety.imageUrl ?? '',
                        fit: BoxFit.contain,
                        memCacheWidth: 300,
                        placeholder: (context, url) => Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Center(
                            child: Icon(Icons.grass_rounded,
                                color: Color(0xFF10B981), size: 36),
                          ),
                        ),
                      ),
                    ),
                    // Video chip badge
                    if (variety.testimonialVideoUrl != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 13),
                              const SizedBox(width: 2),
                              Text(
                                'Video',
                                style: GoogleFonts.googleSans(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Share icon
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            final priceStr = variety.price != null
                                ? '₹${variety.price}${variety.priceUnit != null ? " / ${variety.priceUnit}" : ""}'
                                : null;
                            ShareService.shareItem(
                              context: context,
                              type: 'seed',
                              id: variety.id.toString(),
                              crop: variety.cropName,
                              title:
                                  '${variety.varietyName} (${variety.cropName})',
                              price: priceStr,
                              description: variety.details ??
                                  'High-yielding seed variety available on CropSync.',
                              imageUrl: variety.imageUrl,
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.share_outlined,
                                size: 13, color: Color(0xFF0F172A)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Body Information Section
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      variety.varietyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.googleSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Duration and Yield Tags
                    Row(
                      children: [
                        if (variety.growthDuration != null) ...[
                          Icon(Icons.schedule_rounded,
                              size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 3),
                          Text(
                            '${variety.growthDuration}d',
                            style: GoogleFonts.googleSans(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (variety.averageYield != null) ...[
                          const Icon(Icons.trending_up_rounded,
                              size: 13, color: Color(0xFF059669)),
                          const SizedBox(width: 2),
                          Text(
                            '${variety.averageYield}Q',
                            style: GoogleFonts.googleSans(
                              fontSize: 11,
                              color: const Color(0xFF059669),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Price & Action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (variety.price != null)
                          Text(
                            '₹${variety.price}',
                            style: GoogleFonts.googleSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.4,
                            ),
                          )
                        else
                          Text(
                            'Enquire',
                            style: GoogleFonts.googleSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'View',
                            style: GoogleFonts.googleSans(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }
}

/// Seed details screen with luxury hero media showcase & structured specs
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
            playedColor: const Color(0xFF059669),
            handleColor: const Color(0xFF059669),
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
          // Frosted Glass Back Button
          _buildFrostedButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          // Verified Certification Pill
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
                    size: 14, color: Color(0xFF059669)),
                const SizedBox(width: 4),
                Text(
                  'CERTIFIED SEED',
                  style: GoogleFonts.googleSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF065F46),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Frosted Glass Share Button
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

  /// High-Impact Hero Showcase (Occupies ~40% screen height for video/ads)
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

          // Non-obtrusive floating video trigger pill at bottom
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
                                  'Loading Video...',
                                  style: GoogleFonts.googleSans(
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
                                  'Watch Field Video & Advisory',
                                  style: GoogleFonts.googleSans(
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
                '${_getTranslatedCropName(context, variety.cropName).toUpperCase()} HYBRID',
                style: GoogleFonts.googleSans(
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
                    'Available for Order',
                    style: GoogleFonts.googleSans(
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
          style: GoogleFonts.googleSans(
            fontSize: 25,
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
            style: GoogleFonts.googleSans(
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
                style: GoogleFonts.googleSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.6,
                ),
              ),
              if (variety.priceUnit != null && variety.priceUnit!.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  '/ ${variety.priceUnit}',
                  style: GoogleFonts.googleSans(
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

  /// Key Performance Indicators (Duration, Yield, Sowing Window)
  Widget _buildSpecsMatrix() {
    final variety = widget.variety;
    final statCards = <Widget>[];

    if (variety.growthDuration != null) {
      statCards.add(
        _buildStatTile(
          icon: Icons.schedule_rounded,
          iconColor: const Color(0xFF2563EB),
          bgColor: const Color(0xFFEFF6FF),
          label: 'GROWTH DURATION',
          value: '${variety.growthDuration} Days',
          subtext: 'Sowing to Maturity',
        ),
      );
    }

    if (variety.averageYield != null) {
      statCards.add(
        _buildStatTile(
          icon: Icons.trending_up_rounded,
          iconColor: const Color(0xFF059669),
          bgColor: const Color(0xFFECFDF5),
          label: 'AVERAGE YIELD',
          value: '${variety.averageYield} Q/Acre',
          subtext: 'Quintals per acre',
        ),
      );
    }

    // Only add sowing period if non-empty and non-null (PREVENTS EMPTY CARD BUG)
    if (variety.sowingPeriod != null &&
        variety.sowingPeriod!.trim().isNotEmpty) {
      statCards.add(
        _buildStatTile(
          icon: Icons.calendar_month_rounded,
          iconColor: const Color(0xFFD97706),
          bgColor: const Color(0xFFFFFBEB),
          label: 'SOWING PERIOD',
          value: variety.sowingPeriod!.trim(),
          subtext: 'Ideal Season Window',
        ),
      );
    }

    if (statCards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Agronomic Metrics',
          style: GoogleFonts.googleSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: statCards.map((tile) => Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: tile,
          ))).toList(),
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
            style: GoogleFonts.googleSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.googleSans(
              fontSize: 14.5,
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

  /// Full-width Suitable Regions Section with Clean State Chips
  Widget _buildRegionSection() {
    final variety = widget.variety;
    if (variety.region == null || variety.region!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final rawRegion = variety.region!.trim();
    // Split by comma or semicolon
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
                  size: 18, color: Color(0xFF059669)),
              const SizedBox(width: 8),
              Text(
                'Recommended Agro-Climatic Regions',
                style: GoogleFonts.googleSans(
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
                        color: Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      state,
                      style: GoogleFonts.googleSans(
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

  /// Clean Table/List of Agronomic Characteristics
  Widget _buildAgronomicCharacteristics() {
    final variety = widget.variety;
    if (variety.details == null || variety.details!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final rawDetails = variety.details!.trim();

    // Parse key-value format (e.g. "Released Year: 2025. Oil Content: 37-40%. Plant Height: 150cm")
    final List<MapEntry<String, String>> attributes = [];
    final List<String> paragraphs = [];

    // Split sentences or periods
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
                'Variety Specifications & Traits',
                style: GoogleFonts.googleSans(
                  fontSize: 15,
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
                          style: GoogleFonts.googleSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: GoogleFonts.googleSans(
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
              style: GoogleFonts.googleSans(
                fontSize: 13.5,
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
              color: Color(0xFF059669), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '100% Breeder Authenticity Guarantee',
                  style: GoogleFonts.googleSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF065F46),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Supplied in certified breeder packaging with lot number & germination certificate.',
                  style: GoogleFonts.googleSans(
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

  /// Sticky Booking Bar with Quantity Stepper & High-Conversion CTA
  Widget _buildStickyBookingBar() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final variety = widget.variety;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, bottomPadding + 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Total Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL ESTIMATED PRICE',
                    style: GoogleFonts.googleSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${_totalPrice.toStringAsFixed(2)}',
                    style: GoogleFonts.googleSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              // Quantity Stepper Capsule
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _quantity > 0.5
                          ? () {
                              HapticFeedback.selectionClick();
                              setState(() => _quantity =
                                  (_quantity - 0.5).clamp(0.5, 100));
                            }
                          : null,
                      icon: const Icon(Icons.remove, size: 16),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      color: const Color(0xFF0F172A),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${_quantity.toStringAsFixed(1)} ${variety.priceUnit ?? 'unit'}',
                        style: GoogleFonts.googleSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _quantity =
                            (_quantity + 0.5).clamp(0.5, 100));
                      },
                      icon: const Icon(Icons.add, size: 16),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      color: const Color(0xFF0F172A),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // CTA Booking Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitPurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_bag_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('submit_request'),
                          style: GoogleFonts.googleSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
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

/// Shimmer loading state
class _SeedShimmer extends StatelessWidget {
  const _SeedShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.78,
          ),
          itemCount: 6,
          itemBuilder: (_, __) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}
