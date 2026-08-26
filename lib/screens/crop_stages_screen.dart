import 'package:cropsync/models/farmer_crop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cropsync/widgets/states/app_empty_state.dart';
import 'package:cropsync/widgets/skeletons/shimmer_grid_skeleton.dart';
import '../services/api_service.dart';
import 'crop_problems_screen.dart';
import 'package:cropsync/theme/app_theme.dart';

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
    return code == 'te'
        ? 'te'
        : code == 'hi'
            ? 'hi'
            : 'en';
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
          if (_isLoading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: _buildLoadingState()),
            )
          else if (_stages.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'select_stage'.tr(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 300,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final stage = _stages[index];
                    return _StageGridCard(
                      stage: stage,
                      onTap: () => _openProblemsScreen(stage),
                    );
                  },
                  childCount: _stages.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final hasImage = widget.crop.cropImageUrl != null &&
        widget.crop.cropImageUrl!.isNotEmpty &&
        widget.crop.cropImageUrl!.startsWith('http');

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppTheme.appBarBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: Center(child: AppTheme.backButton(context, color: AppTheme.appBarText)),
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final isCollapsed = constraints.biggest.height <=
              MediaQuery.of(context).padding.top + kToolbarHeight + 1;
          return FlexibleSpaceBar(
            centerTitle: false,
            title: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isCollapsed ? 1.0 : 0.0,
              child: Text(
                widget.crop.cropName,
                style: AppTheme.appBarTitle,
              ),
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (hasImage)
                  CachedNetworkImage(
                    imageUrl: widget.crop.cropImageUrl!,
                    fit: BoxFit.cover,
                    color: Colors.black.withValues(alpha: 0.5),
                    colorBlendMode: BlendMode.darken,
                  )
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF111827), Color(0xFF1F2937)],
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 32,
                  left: 24,
                  right: 24,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isCollapsed ? 0.0 : 1.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.crop.cropName,
                          style: AppTheme.getTextStyle(
                            context,
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_rounded,
                                      color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.crop.fieldName,
                                    style: AppTheme.getTextStyle(
                                      context,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_today_rounded,
                                      color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'days_count'.tr(args: [widget.crop.daysSinceSowing.toString()]),
                                    style: AppTheme.getTextStyle(
                                      context,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const SizedBox(
      height: 420,
      child: ShimmerGridSkeleton(
        itemCount: 4,
        crossAxisCount: 1,
        childAspectRatio: 3.0,
      ),
    );
  }

  Widget _buildEmptyState() {
    return AppEmptyState(
      icon: Icons.spa_rounded,
      title: 'no_stages_available'.tr(),
    );
  }

}

class _StageGridCard extends StatefulWidget {
  final CropStage stage;
  final VoidCallback onTap;

  const _StageGridCard({required this.stage, required this.onTap});

  @override
  State<_StageGridCard> createState() => _StageGridCardState();
}

class _StageGridCardState extends State<_StageGridCard> {
  bool _isPressed = false;

  Widget _buildFallbackIcon() {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: const Icon(
        Icons.eco_rounded,
        color: Color(0xFF9CA3AF),
        size: 40,
      ),
    );
  }

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
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: isCurrent
                ? Border.all(color: const Color(0xFF2E7D32), width: 2)
                : Border.all(color: const Color(0xFFE5E7EB), width: 1),
            boxShadow: [
              BoxShadow(
                color: isCurrent
                    ? const Color(0xFF2E7D32).withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: isCurrent ? 16 : 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.stage.imageUrl != null && widget.stage.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: widget.stage.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: const Color(0xFFF3F4F6),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => _buildFallbackIcon(),
                            )
                          : _buildFallbackIcon(),
                      if (isCurrent)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'current_stage'.tr(),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.stage.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937),
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (widget.stage.description != null && widget.stage.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.stage.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
