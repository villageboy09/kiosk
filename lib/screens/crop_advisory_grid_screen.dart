import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/farmer_crop.dart';
import 'crop_stages_screen.dart';
import 'package:shimmer/shimmer.dart';

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
      );

      final List<FarmerCrop> loadedCrops = [];

      for (final s in selectionsData) {
        final cropId = int.tryParse(s['crop_id'].toString()) ?? 1;
        final varietyId = int.tryParse(s['variety_id'].toString()) ?? 1;
        final sowingDate =
            DateTime.tryParse(s['sowing_date'].toString()) ?? DateTime.now();
        final daysSinceSowing = DateTime.now().difference(sowingDate).inDays;

        int? currentStageId;
        String? currentStageName;
        int problemCount = 0;

        try {
          final durations =
              await ApiService.getStageDuration(cropId, varietyId: varietyId);
          for (var d in durations) {
            final start = d['start_day_from_sowing'] as int? ?? 0;
            final end = d['end_day_from_sowing'] as int? ?? 999;
            if (daysSinceSowing >= start && daysSinceSowing <= end) {
              currentStageId = d['stage_id'] as int?;
              break;
            }
          }

          if (currentStageId != null) {
            final stages = await ApiService.getCropStages(cropId, lang: locale);
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
            );
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
        24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF075E54),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('home_feature_advisory_title'),
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('advisories_title'),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadCrops,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 6,
      itemBuilder: (_, i) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: GoogleFonts.poppins(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadCrops,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF075E54),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grass_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              context.tr('no_fields_yet'),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111B21),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('add_first_crop'),
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[600],
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
      color: const Color(0xFF075E54),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
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
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    child: hasImage
                        ? CachedNetworkImage(
                            imageUrl: crop.cropImageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (_, __) => Container(
                              color: Colors.grey[100],
                              child: Icon(Icons.grass, color: Colors.grey[400]),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.grey[100],
                              child: Icon(Icons.grass, color: Colors.grey[400]),
                            ),
                          )
                        : Container(
                            color:
                                const Color(0xFF075E54).withValues(alpha: 0.1),
                            child: const Center(
                              child: Icon(Icons.grass,
                                  color: Color(0xFF075E54), size: 40),
                            ),
                          ),
                  ),
                  // Problem Badge
                  if (crop.problemCount > 0)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
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
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
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
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crop.cropName,
                      style: GoogleFonts.notoSansTelugu(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111B21),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            crop.fieldName,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
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
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        crop.currentStageName ?? context.tr('stage'),
                        style: GoogleFonts.notoSansTelugu(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2E7D32),
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
