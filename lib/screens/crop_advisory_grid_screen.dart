import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/farmer_analytics_service.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:cropsync/widgets/skeletons/shimmer_grid_skeleton.dart';
import 'package:cropsync/widgets/states/app_error_state.dart';
import 'package:cropsync/widgets/states/app_empty_state.dart';
import 'crop_problems_screen.dart';

class CropAdvisoryGridScreen extends StatefulWidget {
  const CropAdvisoryGridScreen({super.key});

  @override
  State<CropAdvisoryGridScreen> createState() => _CropAdvisoryGridScreenState();
}

class _CropAdvisoryGridScreenState extends State<CropAdvisoryGridScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allCrops = [];
  List<Map<String, dynamic>> _filteredCrops = [];
  String? _errorMessage;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Locale? _lastLocale;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = context.locale;
    if (_lastLocale != currentLocale) {
      _lastLocale = currentLocale;
      _loadCrops();
    }
  }

  String _getLocale() {
    final code = context.locale.languageCode;
    return code == 'te'
        ? 'te'
        : code == 'hi'
            ? 'hi'
            : 'en';
  }

  Future<void> _loadCrops() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final locale = _getLocale();
      final cropsData = await ApiService.getCrops(lang: locale);

      if (mounted) {
        setState(() {
          _allCrops = cropsData;
          _filterCrops();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'error_loading_crops'.tr();
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _filterCrops();
    });
  }

  void _filterCrops() {
    if (_searchQuery.isEmpty) {
      _filteredCrops = List.from(_allCrops);
    } else {
      _filteredCrops = _allCrops.where((crop) {
        final name = (crop['name']?.toString() ?? '').toLowerCase();
        return name.contains(_searchQuery);
      }).toList();
    }
  }

  void _openCropProblems(Map<String, dynamic> crop) {
    HapticFeedback.lightImpact();

    final cropId = int.tryParse(crop['id']?.toString() ?? '1') ?? 1;
    final cropName = crop['name']?.toString() ?? 'Crop';
    final cropImageUrl = crop['image_url']?.toString();

    // Log the farmer's interaction
    FarmerAnalyticsService.logCropView(
      cropId: cropId,
      cropName: cropName,
      language: _getLocale(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CropProblemsScreen(
          cropId: cropId,
          cropName: cropName,
          cropImageUrl: cropImageUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'home_feature_advisory_title'.tr().isNotEmpty
              ? 'home_feature_advisory_title'.tr()
              : 'Crop Advisory',
          style: AppTheme.appBarTitle,
        ),
        centerTitle: false,
        backgroundColor: AppTheme.appBarBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadCrops,
          color: AppTheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Header & Search section
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isTablet ? 24 : 16,
                    12,
                    isTablet ? 24 : 16,
                    12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subtitle
                      Text(
                        'advisory_grid_subtitle'.tr(),
                        style: TextStyle(
                          fontSize: isTablet ? 15 : 13,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Search bar (Pill shaped)
                      Container(
                        height: isTablet ? 54 : 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: TextField(
                            controller: _searchController,
                            textAlignVertical: TextAlignVertical.center,
                            style: TextStyle(
                              fontSize: isTablet ? 15 : 14,
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'advisory_search_crop_hint'.tr(),
                              hintStyle: TextStyle(
                                fontSize: isTablet ? 14 : 13,
                                color: const Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w500,
                              ),
                              isDense: true,
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: Color(0xFF9CA3AF),
                                size: 22,
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear_rounded,
                                        color: Color(0xFF9CA3AF),
                                        size: 18,
                                      ),
                                      onPressed: () => _searchController.clear(),
                                    )
                                  : null,
                              suffixIconConstraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              filled: false,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Main content: Shimmer / Error / Empty / Grid
              if (_isLoading)
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 24 : 16,
                    vertical: 8,
                  ),
                  sliver: const SliverToBoxAdapter(
                    child: ShimmerGridSkeleton(
                      itemCount: 6,
                      childAspectRatio: 0.9,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                    ),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppErrorState(
                    message: _errorMessage!,
                    onRetry: _loadCrops,
                  ),
                )
              else if (_filteredCrops.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    icon: Icons.eco_rounded,
                    title: 'no_crops_found'.tr(),
                    subtitle: 'no_crops_found_sub'.tr(),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    isTablet ? 24 : 16,
                    6,
                    isTablet ? 24 : 16,
                    24,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: isTablet ? 300 : 200,
                      crossAxisSpacing: isTablet ? 20 : 14,
                      mainAxisSpacing: isTablet ? 20 : 14,
                      childAspectRatio: isTablet ? 0.92 : 0.86,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final crop = _filteredCrops[index];
                        return _CropCard(
                          crop: crop,
                          isTablet: isTablet,
                          onTap: () => _openCropProblems(crop),
                        );
                      },
                      childCount: _filteredCrops.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Visual crop card with high quality imagery and responsive layout
class _CropCard extends StatelessWidget {
  final Map<String, dynamic> crop;
  final bool isTablet;
  final VoidCallback onTap;

  const _CropCard({
    required this.crop,
    required this.isTablet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = crop['name']?.toString() ?? 'Crop';
    final imageUrl = crop['image_url']?.toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Crop Photo
              Expanded(
                flex: 11,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 400,
                        placeholder: (context, url) => Container(
                          color: const Color(0xFFF3F4F6),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => _buildFallbackIcon(),
                      )
                    else
                      _buildFallbackIcon(),

                    // Subtle gradient for contrast
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.25),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Title & Advisory Badge
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 14 : 10,
                  vertical: isTablet ? 12 : 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.2,
                        height: context.locale.languageCode == 'te' ? 1.45 : 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'advisory_available'.tr(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF047857),
                              height: context.locale.languageCode == 'te' ? 1.35 : 1.15,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: Color(0xFF9CA3AF),
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

  Widget _buildFallbackIcon() {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: Center(
        child: Icon(
          Icons.eco_rounded,
          size: isTablet ? 48 : 36,
          color: const Color(0xFF10B981).withValues(alpha: 0.5),
        ),
      ),
    );
  }
}


