import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cropsync/widgets/skeletons/shimmer_grid_skeleton.dart';
import 'package:cropsync/widgets/states/app_empty_state.dart';
import '../models/farmer_crop.dart';
import '../models/crop_problem.dart';
import '../services/api_service.dart';
import 'advisory_details.dart';
import 'crop_stages_screen.dart';
import 'package:cropsync/theme/app_theme.dart';

class CropProblemsScreen extends StatefulWidget {
  final FarmerCrop crop;
  final CropStage stage;

  const CropProblemsScreen({
    super.key,
    required this.crop,
    required this.stage,
  });

  @override
  State<CropProblemsScreen> createState() => _CropProblemsScreenState();
}

class _CropProblemsScreenState extends State<CropProblemsScreen> {
  bool _isLoading = true;
  List<CropProblem> _problems = [];
  bool _hasLoadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoadedOnce) {
      _hasLoadedOnce = true;
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
    setState(() => _isLoading = true);

    try {
      final locale = _getLocale();
      final problemsData = await ApiService.getProblems(
        cropId: widget.crop.cropId,
        stageId: widget.stage.id,
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
          _problems = uniqueProblems;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openTreatmentDetails(CropProblem problem) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdvisoryDetailScreen(problem: problem),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              widget.stage.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.appBarTitle,
            ),
            const SizedBox(height: 2),
            Text(
              widget.crop.cropName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.getTextStyle(
                context,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: AppTheme.appBarText.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _problems.isEmpty
                    ? _buildEmptyState()
                    : _buildProblemsGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const ShimmerGridSkeleton(
      childAspectRatio: 0.75,
    );
  }

  Widget _buildEmptyState() {
    return AppEmptyState(
      icon: Icons.check_circle_outline_rounded,
      title: context.tr('no_problems_found'),
      subtitle: 'Your crop looks healthy at this stage.',
    );
  }

  Color _getCategoryColor(String? category) {
    if (category == null) return AppTheme.textHint;
    final cat = category.toLowerCase();
    if (cat.contains('fung')) return const Color(0xFF9333EA);
    if (cat.contains('insect') || cat.contains('pest')) {
      return const Color(0xFFEA580C);
    }
    if (cat.contains('nutrient') || cat.contains('deficiency')) {
      return const Color(0xFF2563EB);
    }
    if (cat.contains('weed')) return const Color(0xFF78350F);
    if (cat.contains('nematode')) return const Color(0xFF0D9488);
    if (cat.contains('disease')) return const Color(0xFFDC2626);
    return AppTheme.textSecondary;
  }

  Widget _buildProblemsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        childAspectRatio: 0.72,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: _problems.length,
      itemBuilder: (ctx, i) => _ProblemCard(
        problem: _problems[i],
        onTap: () => _openTreatmentDetails(_problems[i]),
        categoryColor: _getCategoryColor(_problems[i].category),
      ),
    );
  }
}

class _ProblemCard extends StatelessWidget {
  final CropProblem problem;
  final VoidCallback onTap;
  final Color categoryColor;

  const _ProblemCard({
    required this.problem,
    required this.onTap,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = problem.imageUrl1 != null && problem.imageUrl1!.isNotEmpty;

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
            // Image Section
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                child: hasImage
                    ? CachedNetworkImage(
                        imageUrl: problem.imageUrl1!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: const Color(0xFFF3F4F6),
                          child: const Center(
                              child: Icon(Icons.bug_report_rounded,
                                  color: AppTheme.textHint)),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFFF3F4F6),
                          child: const Center(
                              child: Icon(Icons.bug_report_rounded,
                                  color: AppTheme.textHint)),
                        ),
                      )
                    : Container(
                        color: categoryColor.withValues(alpha: 0.05),
                        child: Center(
                          child: Icon(Icons.bug_report_rounded,
                              color: categoryColor, size: 40),
                        ),
                      ),
              ),
            ),
            // Details Section
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        problem.category ?? 'Other',
                        style: TextStyle(
                          
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: categoryColor,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Problem Name
                    Text(
                      problem.name,
                      style: const TextStyle(
                        
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Interaction hint
                    const Row(
                      children: [
                        Text(
                          'View Treatments',
                          style: TextStyle(
                            
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 10, color: AppTheme.textPrimary),
                      ],
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

