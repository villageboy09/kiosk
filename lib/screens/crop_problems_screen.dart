import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/farmer_crop.dart';
import '../models/crop_problem.dart';
import '../services/api_service.dart';
import 'advisory_details.dart';
import 'crop_stages_screen.dart';
import 'package:shimmer/shimmer.dart';

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

      final List<CropProblem> loadedProblems = problemsData.map((p) {
        return CropProblem.fromJson(p);
      }).toList();

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
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.stage.name,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              widget.crop.cropName,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF66BB6A),
        elevation: 4,
        shadowColor: const Color(0xFF66BB6A).withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
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
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 80, color: Colors.green[300]),
            const SizedBox(height: 16),
            Text(
              context.tr('no_problems_found'),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF111B21),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your crop looks healthy at this stage.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    if (category == null) return Colors.grey;
    final cat = category.toLowerCase();
    if (cat.contains('fung')) return Colors.purple;
    if (cat.contains('insect') || cat.contains('pest')) return Colors.orange;
    if (cat.contains('nutrient') || cat.contains('deficiency')) {
      return Colors.blue;
    }
    if (cat.contains('weed')) return Colors.brown;
    if (cat.contains('nematode')) return Colors.teal;
    if (cat.contains('disease')) return Colors.red;
    return Colors.grey;
  }

  Widget _buildProblemsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
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
            // Image Section
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: hasImage
                    ? CachedNetworkImage(
                        imageUrl: problem.imageUrl1!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: Colors.grey[100],
                          child: const Center(
                              child:
                                  Icon(Icons.bug_report, color: Colors.grey)),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey[100],
                          child: const Center(
                              child:
                                  Icon(Icons.bug_report, color: Colors.grey)),
                        ),
                      )
                    : Container(
                        color: categoryColor.withValues(alpha: 0.1),
                        child: Center(
                          child: Icon(Icons.bug_report,
                              color: categoryColor, size: 40),
                        ),
                      ),
              ),
            ),
            // Details Section
            Expanded(
              flex: 4,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        problem.category ?? 'Other',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: categoryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Problem Name
                    Text(
                      problem.name,
                      style: GoogleFonts.notoSansTelugu(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111B21),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Interaction hint
                    Row(
                      children: [
                        Text(
                          'View Treatments',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF075E54),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios,
                            size: 10, color: Color(0xFF075E54)),
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
