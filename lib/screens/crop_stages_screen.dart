import 'package:cropsync/models/farmer_crop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/api_service.dart';
import 'crop_problems_screen.dart';
import 'package:shimmer/shimmer.dart';

class CropStage {
  final int id;
  final String name;
  final String? imageUrl;
  final String? description;
  final bool isCurrentStage;

  CropStage({
    required this.id,
    required this.name,
    this.imageUrl,
    this.description,
    this.isCurrentStage = false,
  });
}

class CropStagesScreen extends StatefulWidget {
  final FarmerCrop crop;

  const CropStagesScreen({super.key, required this.crop});

  @override
  State<CropStagesScreen> createState() => _CropStagesScreenState();
}

class _CropStagesScreenState extends State<CropStagesScreen> {
  bool _isLoading = true;
  List<CropStage> _stages = [];
  bool _hasLoadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoadedOnce) {
      _hasLoadedOnce = true;
      _loadStages();
    }
  }

  String _getLocale() {
    final code = context.locale.languageCode;
    return code == 'te' ? 'te' : code == 'hi' ? 'hi' : 'en';
  }

  Future<void> _loadStages() async {
    setState(() => _isLoading = true);

    try {
      final locale = _getLocale();
      final stagesData =
          await ApiService.getCropStages(widget.crop.cropId, lang: locale);
      final durations = await ApiService.getStageDuration(
        widget.crop.cropId,
        varietyId: widget.crop.varietyId,
      );

      int? currentStageId;
      for (var d in durations) {
        final start = d['start_day_from_sowing'] as int? ?? 0;
        final end = d['end_day_from_sowing'] as int? ?? 999;
        if (widget.crop.daysSinceSowing >= start &&
            widget.crop.daysSinceSowing <= end) {
          currentStageId = d['stage_id'] as int?;
          break;
        }
      }

      final List<CropStage> loadedStages = stagesData.map((s) {
        final id = s['id'] as int;
        return CropStage(
          id: id,
          name: s['name'] as String? ?? 'Stage',
          imageUrl: s['image_url'] as String?,
          description: s['description'] as String?,
          isCurrentStage: id == currentStageId,
        );
      }).toList();

      // Sort stages to bring the current stage to the top
      loadedStages.sort((a, b) {
        if (a.isCurrentStage && !b.isCurrentStage) return -1;
        if (!a.isCurrentStage && b.isCurrentStage) return 1;
        return 0; // Maintain existing order for the rest
      });

      if (mounted) {
        setState(() {
          _stages = loadedStages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openProblemsScreen(CropStage stage) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CropProblemsScreen(crop: widget.crop, stage: stage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: _isLoading
                ? _buildLoadingState()
                : _stages.isEmpty
                    ? _buildEmptyState()
                    : _buildStagesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final hasImage = widget.crop.cropImageUrl != null &&
        widget.crop.cropImageUrl!.isNotEmpty &&
        widget.crop.cropImageUrl!.startsWith('http');

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: const Color(0xFF075E54),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              CachedNetworkImage(
                imageUrl: widget.crop.cropImageUrl!,
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: 0.4),
                colorBlendMode: BlendMode.darken,
              )
            else
              Container(color: const Color(0xFF075E54)),
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.crop.cropName,
                    style: GoogleFonts.notoSansTelugu(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        widget.crop.fieldName,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.calendar_today, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.crop.daysSinceSowing} ${context.tr('days')}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white70,
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
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          5,
          (index) => Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          Icon(Icons.spa_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No stages available',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStagesList() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              'Select Stage',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF111B21),
              ),
            ),
          ),
          ..._stages.map((stage) => _StageCard(
                stage: stage,
                onTap: () => _openProblemsScreen(stage),
              )),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _StageCard extends StatefulWidget {
  final CropStage stage;
  final VoidCallback onTap;

  const _StageCard({required this.stage, required this.onTap});

  @override
  State<_StageCard> createState() => _StageCardState();
}

class _StageCardState extends State<_StageCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isCurrent = widget.stage.isCurrentStage;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: isCurrent
                ? Border.all(color: const Color(0xFF66BB6A).withValues(alpha: 0.5), width: 2)
                : Border.all(color: Colors.grey.withValues(alpha: 0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: isCurrent 
                    ? const Color(0xFF66BB6A).withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: isCurrent ? 16 : 12,
                offset: const Offset(0, 6),
              ),
            ],
            gradient: isCurrent
                ? const LinearGradient(
                    colors: [Color(0xFFF1F8E9), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Row(
            children: [
              // Image Section
              Container(
                width: 110,
                height: 110,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFFF5F5F5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: widget.stage.imageUrl != null && widget.stage.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.stage.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF66BB6A)),
                          ),
                          errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.eco_rounded, color: Colors.grey, size: 32),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.eco_rounded, color: Colors.grey, size: 40),
                        ),
                ),
              ),
              // Details Section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.stage.name,
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1F2937),
                                height: 1.2,
                              ),
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF66BB6A),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF66BB6A).withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                'Current',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (widget.stage.description != null && widget.stage.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.stage.description!,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFF6B7280),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Forward Arrow Indicator
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isCurrent ? const Color(0xFF66BB6A) : const Color(0xFFD1D5DB),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

