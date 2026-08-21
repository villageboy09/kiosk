import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/widgets/skeletons/shimmer_grid_skeleton.dart';
import 'package:cropsync/widgets/states/app_empty_state.dart';
import 'package:cropsync/widgets/states/app_error_state.dart';
import '../models/farmer_crop.dart';
import '../models/crop_problem.dart';
import '../services/api_service.dart';
import '../services/farmer_analytics_service.dart';
import 'advisory_details.dart';
import 'crop_stages_screen.dart';
import 'package:cropsync/theme/app_theme.dart';

class CropProblemsScreen extends StatefulWidget {
  final int cropId;
  final String cropName;
  final String? cropImageUrl;
  final CropStage? stage;
  final FarmerCrop? crop;

  CropProblemsScreen({
    super.key,
    int? cropId,
    String? cropName,
    this.cropImageUrl,
    this.stage,
    this.crop,
  })  : cropId = cropId ?? crop?.cropId ?? 1,
        cropName = cropName ?? crop?.cropName ?? 'Crop';

  /// Factory constructor for backward compatibility
  factory CropProblemsScreen.fromCropAndStage({
    Key? key,
    required FarmerCrop crop,
    required CropStage stage,
  }) {
    return CropProblemsScreen(
      key: key,
      cropId: crop.cropId,
      cropName: crop.cropName,
      cropImageUrl: crop.cropImageUrl,
      stage: stage,
      crop: crop,
    );
  }

  @override
  State<CropProblemsScreen> createState() => _CropProblemsScreenState();
}

class _CropProblemsScreenState extends State<CropProblemsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<CropProblem> _allProblems = [];
  List<CropProblem> _filteredProblems = [];
  String _selectedCategory = 'all'; // 'all', 'disease', 'pest', 'deficiency', 'other'
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
      _loadProblems();
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

  Future<void> _loadProblems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final locale = _getLocale();
      final problemsData = await ApiService.getProblems(
        cropId: widget.cropId,
        stageId: widget.stage?.id,
        lang: locale,
      );

      final List<CropProblem> loadedProblems = problemsData
          .whereType<Map<String, dynamic>>()
          .map(CropProblem.fromJson)
          .toList();

      // Deduplicate by problem ID
      final seenIds = <int>{};
      final uniqueProblems = loadedProblems.where((p) {
        if (seenIds.contains(p.id)) return false;
        seenIds.add(p.id);
        return true;
      }).toList();

      if (mounted) {
        setState(() {
          _allProblems = uniqueProblems;
          _filterProblems();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load problems. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _filterProblems();
    });
  }

  void _onCategorySelected(String category) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategory = category;
      _filterProblems();
    });
  }

  void _filterProblems() {
    List<CropProblem> list = _allProblems;

    // Filter by Category
    if (_selectedCategory != 'all') {
      list = list.where((p) {
        final cat = (p.category ?? '').toLowerCase();
        if (_selectedCategory == 'disease') {
          return cat.contains('fung') ||
              cat.contains('bacter') ||
              cat.contains('virus') ||
              cat.contains('disease') ||
              cat.contains('తెగులు');
        } else if (_selectedCategory == 'pest') {
          return cat.contains('insect') ||
              cat.contains('pest') ||
              cat.contains('worm') ||
              cat.contains('borer') ||
              cat.contains('కీటక') ||
              cat.contains('పురుగు');
        } else if (_selectedCategory == 'deficiency') {
          return cat.contains('nutrient') ||
              cat.contains('deficiency') ||
              cat.contains('nitrogen') ||
              cat.contains('zinc') ||
              cat.contains('లోపం');
        } else if (_selectedCategory == 'other') {
          return cat.contains('weed') || cat.contains('nematode');
        }
        return true;
      }).toList();
    }

    // Filter by Search Query
    if (_searchQuery.isNotEmpty) {
      list = list.where((p) {
        final nameMatch = p.name.toLowerCase().contains(_searchQuery);
        final catMatch = (p.category ?? '').toLowerCase().contains(_searchQuery);
        return nameMatch || catMatch;
      }).toList();
    }

    _filteredProblems = list;
  }

  void _openTreatmentDetails(CropProblem problem) {
    HapticFeedback.lightImpact();

    // Log the farmer's problem inspection
    FarmerAnalyticsService.logProblemView(
      problemId: problem.id,
      problemName: problem.name,
      category: problem.category ?? 'General',
      cropId: widget.cropId,
      cropName: widget.cropName,
      stageName: widget.stage?.name,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdvisoryDetailScreen(
          problem: problem,
          cropName: widget.cropName,
        ),
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    if (category == null) return AppTheme.textSecondary;
    final cat = category.toLowerCase();
    if (cat.contains('fung') || cat.contains('disease') || cat.contains('bacter') || cat.contains('virus')) {
      return const Color(0xFFDC2626); // Red
    }
    if (cat.contains('insect') || cat.contains('pest') || cat.contains('worm') || cat.contains('borer')) {
      return const Color(0xFFEA580C); // Orange
    }
    if (cat.contains('nutrient') || cat.contains('deficiency')) {
      return const Color(0xFF2563EB); // Blue
    }
    if (cat.contains('weed')) return const Color(0xFF78350F); // Brown
    return const Color(0xFF0D9488); // Teal
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: AppTheme.backButton(context, color: AppTheme.appBarText),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppTheme.appBarBg,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.cropName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.appBarTitle.copyWith(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              widget.stage != null
                  ? widget.stage!.name
                  : 'Sowing to Harvesting Advisory',
              style: TextStyle(
                fontSize: isTablet ? 12 : 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProblems,
          color: AppTheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Search & Filter Tabs Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isTablet ? 24 : 16,
                    12,
                    isTablet ? 24 : 16,
                    8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search Bar (Pill shaped)
                      Container(
                        height: isTablet ? 52 : 48,
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
                        child: TextField(
                          controller: _searchController,
                          textAlignVertical: TextAlignVertical.center,
                          style: TextStyle(
                            fontSize: isTablet ? 15 : 14,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search diseases, pests, or deficiencies...',
                            hintStyle: TextStyle(
                              fontSize: isTablet ? 13.5 : 12.5,
                              color: const Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF9CA3AF),
                              size: 20,
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
                            filled: false,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Category Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildFilterChip('all', 'All Problems', Icons.grid_view_rounded),
                            const SizedBox(width: 8),
                            _buildFilterChip('disease', '🦠 Diseases', null),
                            const SizedBox(width: 8),
                            _buildFilterChip('pest', '🐛 Pests & Insects', null),
                            const SizedBox(width: 8),
                            _buildFilterChip('deficiency', '🌿 Deficiencies', null),
                            const SizedBox(width: 8),
                            _buildFilterChip('other', '🌱 Other', null),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content Area
              if (_isLoading)
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 24 : 16,
                    vertical: 12,
                  ),
                  sliver: const SliverToBoxAdapter(
                    child: ShimmerGridSkeleton(
                      itemCount: 6,
                      childAspectRatio: 0.72,
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
                    onRetry: _loadProblems,
                  ),
                )
              else if (_filteredProblems.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    icon: Icons.eco_rounded,
                    title: 'No problems found',
                    subtitle: _searchQuery.isNotEmpty
                        ? 'No match for "$_searchQuery". Try another keyword.'
                        : 'Your crop has no recorded problems for this category.',
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    isTablet ? 24 : 16,
                    8,
                    isTablet ? 24 : 16,
                    24,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: isTablet ? 300 : 200,
                      crossAxisSpacing: isTablet ? 20 : 14,
                      mainAxisSpacing: isTablet ? 20 : 14,
                      childAspectRatio: isTablet ? 0.76 : 0.71,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final problem = _filteredProblems[index];
                        return _ProblemCard(
                          problem: problem,
                          isTablet: isTablet,
                          onTap: () => _openTreatmentDetails(problem),
                          categoryColor: _getCategoryColor(problem.category),
                        );
                      },
                      childCount: _filteredProblems.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, IconData? icon) {
    final isSelected = _selectedCategory == key;

    return GestureDetector(
      onTap: () => _onCategorySelected(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? AppTheme.primary : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.20),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProblemCard extends StatelessWidget {
  final CropProblem problem;
  final bool isTablet;
  final VoidCallback onTap;
  final Color categoryColor;

  const _ProblemCard({
    required this.problem,
    required this.isTablet,
    required this.onTap,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = problem.imageUrl1 != null && problem.imageUrl1!.isNotEmpty;

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
              // Image Section
              Expanded(
                flex: 11,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasImage)
                      CachedNetworkImage(
                        imageUrl: problem.imageUrl1!,
                        fit: BoxFit.cover,
                        memCacheWidth: 400,
                        placeholder: (context, url) => Container(
                          color: const Color(0xFFF3F4F6),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
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

                    // Category Pill on Image
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: categoryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              problem.category ?? 'Advisory',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Details & Button Section
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 12 : 10,
                  vertical: isTablet ? 10 : 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      problem.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              'View Control Remedies',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 11,
                            color: AppTheme.textPrimary,
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

  Widget _buildFallbackIcon() {
    return Container(
      color: categoryColor.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          Icons.bug_report_rounded,
          color: categoryColor,
          size: isTablet ? 44 : 36,
        ),
      ),
    );
  }
}
