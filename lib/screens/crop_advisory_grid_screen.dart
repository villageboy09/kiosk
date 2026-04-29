import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cropsync/widgets/skeletons/shimmer_grid_skeleton.dart';
import 'package:cropsync/widgets/states/app_empty_state.dart';
import 'package:cropsync/widgets/states/app_error_state.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/farmer_crop.dart';
import 'crop_stages_screen.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:cropsync/services/global_notifiers.dart';

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
    if (!_hasLoadedOnce) {
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
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                    ? _buildErrorState()
                    : _crops.isEmpty
                        ? _buildEmptyState()
                        : _buildCropGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 24,
        24,
        32,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111827), Color(0xFF1F2937)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('home_feature_advisory_title'),
                    style: AppTheme.getTextStyle(
                      context,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      context.tr('crop_advisories_label'),
                      style: AppTheme.getTextStyle(
                        context,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _loadCrops,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  tooltip: context.tr('refresh'),
                ),
              ),
            ],
          ),
        ],
      ),
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
    return AppEmptyState(
      icon: Icons.grass_rounded,
      title: context.tr('no_fields_yet'),
      subtitle: context.tr('add_first_crop'),
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
                            crop.fieldName,
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
