import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cropsync/widgets/skeletons/shimmer_grid_skeleton.dart';
import 'package:cropsync/widgets/states/app_error_state.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/farmer_crop.dart';
import 'crop_stages_screen.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:cropsync/services/global_notifiers.dart';

String _getDisplayFieldName(String name) {
  if (name == 'Field 1' || name == 'పొలం 1') return 'field_1'.tr();
  if (name == 'Field 2' || name == 'పొలం 2') return 'field_2'.tr();
  if (name == 'Field 3' || name == 'పొలం 3') return 'field_3'.tr();
  if (name == 'Field 4' || name == 'పొలం 4') return 'field_4'.tr();
  return name;
}

class CropAdvisoryGridScreen extends StatefulWidget {
  const CropAdvisoryGridScreen({super.key});

  @override
  State<CropAdvisoryGridScreen> createState() => _CropAdvisoryGridScreenState();
}

class _CropAdvisoryGridScreenState extends State<CropAdvisoryGridScreen> {
  bool _isLoading = true;
  List<FarmerCrop> _crops = [];
  String? _errorMessage;
  bool _hasLoadedOnce = false;
  Locale? _lastLocale;

  @override
  void initState() {
    super.initState();
    GlobalNotifiers.selectionAdded.addListener(_onSelectionChanged);
    GlobalNotifiers.selectionDeleted.addListener(_onSelectionChanged);
    GlobalNotifiers.selectionUpdated.addListener(_onSelectionChanged);
  }

  void _onSelectionChanged() {
    if (mounted) {
      _loadCrops();
    }
  }

  @override
  void dispose() {
    GlobalNotifiers.selectionAdded.removeListener(_onSelectionChanged);
    GlobalNotifiers.selectionDeleted.removeListener(_onSelectionChanged);
    GlobalNotifiers.selectionUpdated.removeListener(_onSelectionChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = context.locale;
    if (_lastLocale != currentLocale) {
      _lastLocale = currentLocale;
      _loadCrops();
    } else if (!_hasLoadedOnce) {
      _hasLoadedOnce = true;
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
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        setState(() {
          _errorMessage = context.tr('login_required');
          _isLoading = false;
        });
        return;
      }

      final locale = _getLocale();
      final selectionsData = await ApiService.getUserSelections(
        currentUser.userId,
        lang: locale,
      ).timeout(const Duration(seconds: 10));

      final List<FarmerCrop> loadedCrops = [];

      for (final s in selectionsData) {
        if (!mounted) return;
        final cropId = int.tryParse(s['crop_id'].toString()) ?? 1;
        final varietyId = int.tryParse(s['variety_id'].toString()) ?? 1;
        final sowingDate =
            DateTime.tryParse(s['sowing_date'].toString()) ?? DateTime.now();
        final daysSinceSowing = DateTime.now().difference(sowingDate).inDays;

        int? currentStageId;
        String? currentStageName;
        int problemCount = 0;

        try {
          final durations = await ApiService.getStageDuration(
            cropId,
            varietyId: varietyId,
          ).timeout(const Duration(seconds: 8));
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
            ).timeout(const Duration(seconds: 8));
            for (var stage in stages) {
              if (stage['id'] == currentStageId) {
                currentStageName = stage['name'] as String?;
                break;
              }
            }
            final problems = await ApiService.getProblems(
              cropId: cropId,
              stageId: currentStageId,
              lang: locale,
            ).timeout(const Duration(seconds: 8));
            problemCount = problems.length;
          }
        } catch (e) {
          // ignore error
        }

        loadedCrops.add(FarmerCrop(
          id: int.tryParse(s['selection_id'].toString()) ?? 0,
          fieldName: s['field_name']?.toString() ?? 'Field',
          cropName: s['crop_name']?.toString() ?? 'Crop',
          cropImageUrl: s['crop_image_url']?.toString(),
          cropId: cropId,
          varietyId: varietyId,
          sowingDate: sowingDate,
          currentStageId: currentStageId,
          currentStageName: currentStageName,
          problemCount: problemCount,
        ));
      }

      if (mounted) {
        setState(() {
          _crops = loadedCrops;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load crops: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _openCropStages(FarmerCrop crop) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CropStagesScreen(crop: crop),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Light blue-grey background
      appBar: AppBar(
        title: Text(
          context.tr('home_feature_advisory_title'),
          style: AppTheme.appBarTitle,
        ),
        backgroundColor: AppTheme.appBarBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _loadCrops,
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.appBarText),
            tooltip: context.tr('refresh'),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _crops.isEmpty
                  ? _buildEmptyState()
                  : _buildCropGrid(),
    );
  }

  Widget _buildLoadingState() {
    return const ShimmerGridSkeleton(
      childAspectRatio: 0.85,
    );
  }

  Widget _buildErrorState() {
    return AppErrorState(
      message: _errorMessage!,
      onRetry: _loadCrops,
    );
  }

  Widget _buildEmptyState() {
    final user = AuthService.currentUser;
    final imageUrl = user?.profileImageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty && imageUrl.startsWith('http');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 144,
              height: 144,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.1), width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: hasImage
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: 144,
                        height: 144,
                        placeholder: (_, __) => Container(
                          color: const Color(0xFFF3F4F6),
                          child: const Icon(Icons.person, size: 80, color: AppTheme.textHint),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFFF3F4F6),
                          child: const Icon(Icons.person, size: 80, color: AppTheme.textHint),
                        ),
                      )
                    : Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                        width: 144,
                        height: 144,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFF3F4F6),
                          child: const Icon(Icons.person, size: 80, color: AppTheme.textHint),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              context.tr('no_fields_yet'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('add_first_crop'),
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropGrid() {
    return RefreshIndicator(
      onRefresh: _loadCrops,
      color: AppTheme.textPrimary,
      child: GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 280,
          childAspectRatio: 0.78,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
        ),
        itemCount: _crops.length,
        itemBuilder: (ctx, i) => _CropCard(
          crop: _crops[i],
          onTap: () => _openCropStages(_crops[i]),
        ),
      ),
    );
  }
}

class _CropCard extends StatelessWidget {
  final FarmerCrop crop;
  final VoidCallback onTap;

  const _CropCard({required this.crop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasImage = crop.cropImageUrl != null &&
        crop.cropImageUrl!.isNotEmpty &&
        crop.cropImageUrl!.startsWith('http');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image section
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    child: hasImage
                        ? CachedNetworkImage(
                            imageUrl: crop.cropImageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (_, __) => Container(
                              color: const Color(0xFFF3F4F6),
                              child: const Icon(Icons.grass_rounded,
                                  color: AppTheme.textHint),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFFF3F4F6),
                              child: const Icon(Icons.grass_rounded,
                                  color: AppTheme.textHint),
                            ),
                          )
                        : Container(
                            color: AppTheme.textPrimary.withValues(alpha: 0.05),
                            child: const Center(
                              child: Icon(Icons.grass_rounded,
                                  color: AppTheme.textPrimary, size: 40),
                            ),
                          ),
                  ),
                  // Problem Badge
                  if (crop.problemCount > 0)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.textPrimary,
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${crop.problemCount}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Details section
            Expanded(
              flex: 4,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crop.cropName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 13, color: AppTheme.textHint),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _getDisplayFieldName(crop.fieldName),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        crop.currentStageName ?? context.tr('stage'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
