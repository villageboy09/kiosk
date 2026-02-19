// lib/screens/crop_conversation_screen.dart
// WhatsApp-style crop conversation with stage stories and problem chat bubbles

// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/crop_problem.dart';
import '../models/advisory.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'advisory_details.dart';
import 'crop_chat_list_screen.dart';
import '../services/global_notifiers.dart';
import 'package:shimmer/shimmer.dart';

// ... (existing imports)

// ============================================================================
// DESIGN SYSTEM (Shared with chat list)
// ============================================================================
class _ChatColors {
  static const primary = Color(0xFF075E54);
  static const primaryLight = Color(0xFF128C7E);
  static const accent = Color(0xFF25D366);
  static const bg = Color(0xFFECE5DD);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF111B21);
  static const textSecondary = Color(0xFF667781);
  static const bubbleIncoming = Color(0xFFFFFFFF);
  static const bubbleOutgoing = Color(0xFFDCF8C6);
  static const storyRing = Color(0xFF25D366);
  static const storyRingViewed = Color(0xFFCCCCCC);
}

// ============================================================================
// CROP STAGE MODEL
// ============================================================================
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

// ============================================================================
// MAIN SCREEN
// ============================================================================
class CropConversationScreen extends StatefulWidget {
  final FarmerCrop crop;

  const CropConversationScreen({super.key, required this.crop});

  @override
  State<CropConversationScreen> createState() => _CropConversationScreenState();
}

class _CropConversationScreenState extends State<CropConversationScreen>
    with TickerProviderStateMixin {
  bool _isLoadingStages = true;
  bool _isLoadingProblems = false;
  List<CropStage> _stages = [];
  List<CropProblem> _problems = [];
  CropStage? _selectedStage;
  int? _expandedProblemId;

  late AnimationController _typingController;
  int? _typingProblemId;
  bool _hasLoadedOnce = false;

  // Advisory cache for inline display
  final Map<int, Advisory?> _advisoryCache = {};
  final Set<int> _loadingAdvisoryIds = {};

  // Track identified problems
  final Set<int> _identifiedProblemIds = {};
  final Set<int> _markingProblemIds = {};

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Listen for refresh
    GlobalNotifiers.shouldRefreshAdvisory.addListener(_handleAdvisoryRefresh);
  }

  @override
  void dispose() {
    _typingController.dispose();
    GlobalNotifiers.shouldRefreshAdvisory
        .removeListener(_handleAdvisoryRefresh);
    super.dispose();
  }

  // Refresh data when Settings changes
  void _handleAdvisoryRefresh() {
    if (mounted) {
      _loadStages(); // Re-fetch data
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load stages here instead of initState because context.locale
    // is not available until after initState completes
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
    setState(() => _isLoadingStages = true);

    try {
      final locale = _getLocale();
      final stagesData =
          await ApiService.getCropStages(widget.crop.cropId, lang: locale);
      final durations = await ApiService.getStageDuration(
        widget.crop.cropId,
        varietyId: widget.crop.varietyId,
      );

      // Determine current stage based on days since sowing
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

      if (mounted) {
        setState(() {
          _stages = loadedStages;
          _isLoadingStages = false;
          // Auto-select current stage or first stage
          final current = loadedStages.where((s) => s.isCurrentStage).toList();
          if (current.isNotEmpty) {
            _selectStage(current.first);
          } else if (loadedStages.isNotEmpty) {
            _selectStage(loadedStages.first);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStages = false);
      }
    }
  }

  Future<void> _selectStage(CropStage stage) async {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedStage = stage;
      _problems = [];
      _isLoadingProblems = true;
      _expandedProblemId = null;
    });

    try {
      final locale = _getLocale();
      final problemsData = await ApiService.getProblems(
        cropId: widget.crop.cropId,
        stageId: stage.id,
        lang: locale,
      );

      final List<CropProblem> loadedProblems = problemsData.map((p) {
        return CropProblem.fromJson(p);
      }).toList();

      // Deduplicate by problem ID (API may return duplicates)
      final seenIds = <int>{};
      final uniqueProblems = loadedProblems.where((p) {
        if (seenIds.contains(p.id)) return false;
        seenIds.add(p.id);
        return true;
      }).toList();

      if (mounted) {
        setState(() {
          _problems = uniqueProblems;
          _isLoadingProblems = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProblems = false);
      }
    }
  }

  void _toggleProblemExpansion(CropProblem problem) async {
    HapticFeedback.lightImpact();

    if (_expandedProblemId == problem.id) {
      setState(() => _expandedProblemId = null);
    } else {
      // Show typing indicator then expand
      setState(() {
        _typingProblemId = problem.id;
        _expandedProblemId = null;
      });

      // Fetch advisory if not cached
      if (!_advisoryCache.containsKey(problem.id)) {
        _loadingAdvisoryIds.add(problem.id);
        try {
          final locale = _getLocale();
          final advisoryData =
              await ApiService.getAdvisories(problem.id, lang: locale);

          if (advisoryData != null) {
            final advisoryId = advisoryData['id'] as int?;
            List<AdvisoryRecommendation> recommendations = [];

            if (advisoryId != null) {
              final componentsData = await ApiService.getAdvisoryComponents(
                  advisoryId,
                  lang: locale);
              recommendations = componentsData
                  .map((r) => AdvisoryRecommendation.fromJson(r))
                  .where((rec) => rec.name != 'N/A' && rec.name.isNotEmpty)
                  .toList();
            }

            _advisoryCache[problem.id] = Advisory(
              title: advisoryData['title'] as String? ?? 'N/A',
              symptoms: advisoryData['symptoms'] as String? ?? 'N/A',
              notes: advisoryData['notes'] as String?,
              recommendations: recommendations,
            );
          } else {
            _advisoryCache[problem.id] = null;
          }
        } catch (e) {
          // Silent error handling for production
          _advisoryCache[problem.id] = null;
        }
        _loadingAdvisoryIds.remove(problem.id);
      }

      // Short delay for typing effect, then expand
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        setState(() {
          _typingProblemId = null;
          _expandedProblemId = problem.id;
        });
      }
    }
  }

  void _openProblemDetails(CropProblem problem) {
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
      backgroundColor: _ChatColors.bg,
      body: Column(
        children: [
          _buildHeader(),
          if (!_isLoadingStages && _stages.isNotEmpty) _buildStageStories(),
          Expanded(
            child: _isLoadingStages
                ? const Center(
                    child:
                        CircularProgressIndicator(color: _ChatColors.primary))
                : _buildChatArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final hasImage = widget.crop.cropImageUrl != null &&
        widget.crop.cropImageUrl!.isNotEmpty &&
        widget.crop.cropImageUrl!.startsWith('http');

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.of(context).padding.top + 8,
        12,
        12,
      ),
      decoration: const BoxDecoration(color: _ChatColors.primary),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 12),
          // Crop avatar
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: ClipOval(
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: widget.crop.cropImageUrl!,
                      fit: BoxFit.cover,
                      memCacheHeight: 90, // Optimized for 44px * 2
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.white24,
                        child: const Icon(Icons.grass, color: Colors.white),
                      ),
                    )
                  : Container(
                      color: Colors.white24,
                      child: const Icon(Icons.grass, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.crop.cropName,
                  style: GoogleFonts.notoSansTelugu(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${widget.crop.fieldName} • ${widget.crop.daysSinceSowing} రోజులు',
                  style: GoogleFonts.notoSansTelugu(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: IconButton(
              onPressed: () => _loadStages(),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'Refresh',
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageStories() {
    return Container(
      height: 100,
      color: _ChatColors.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _stages.length,
        itemBuilder: (ctx, i) {
          final stage = _stages[i];
          final isSelected = _selectedStage?.id == stage.id;

          return GestureDetector(
            onTap: () => _selectStage(stage),
            child: Container(
              width: 70,
              margin: const EdgeInsets.only(right: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Story circle with gradient ring
                  Container(
                    width: isSelected ? 60 : 52, // Larger if selected
                    height: isSelected ? 60 : 52,
                    padding: EdgeInsets.all(isSelected ? 3 : 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color:
                                    _ChatColors.primary.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                      gradient: LinearGradient(
                        colors: stage.isCurrentStage
                            ? [_ChatColors.storyRing, _ChatColors.accent]
                            : isSelected
                                ? [
                                    _ChatColors.primaryLight,
                                    _ChatColors.primary
                                  ]
                                : [
                                    _ChatColors.storyRingViewed,
                                    _ChatColors.storyRingViewed
                                  ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _ChatColors.surface,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipOval(
                        child: stage.imageUrl != null &&
                                stage.imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: stage.imageUrl!,
                                fit: BoxFit.cover,
                                memCacheHeight: 120, // Limit memory cache size
                                fadeInDuration:
                                    const Duration(milliseconds: 150),
                                placeholder: (_, __) => Container(
                                  color: Colors.green[50],
                                  child:
                                      Icon(Icons.eco, color: Colors.green[400]),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: Colors.green[50],
                                  child:
                                      Icon(Icons.eco, color: Colors.green[400]),
                                ),
                              )
                            : Container(
                                color: Colors.green[50],
                                child:
                                    Icon(Icons.eco, color: Colors.green[400]),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Stage name
                  Flexible(
                    child: Text(
                      stage.name,
                      style: GoogleFonts.notoSansTelugu(
                        fontSize: 9,
                        fontWeight: stage.isCurrentStage || isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected
                            ? _ChatColors.primary
                            : _ChatColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatArea() {
    if (_isLoadingProblems) {
      return Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: 4,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 16, right: 60),
            child: Container(
              height: 120,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_problems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 64, color: Colors.green[300]),
            const SizedBox(height: 16),
            Text(
              'ఈ దశలో సమస్యలు లేవు!',
              style: GoogleFonts.notoSansTelugu(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _ChatColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No problems in this stage',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _ChatColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      cacheExtent: 500, // Pre-render items for smoother scrolling
      physics: const BouncingScrollPhysics(), // Smoother scrolling
      itemCount: _problems.length,
      itemBuilder: (ctx, i) {
        // Wrap in RepaintBoundary for optimized rendering
        return RepaintBoundary(
          child: _buildProblemBubble(_problems[i]),
        );
      },
    );
  }

  Widget _buildProblemBubble(CropProblem problem) {
    final isExpanded = _expandedProblemId == problem.id;
    final hasImage = problem.imageUrl1 != null && problem.imageUrl1!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Problem bubble (incoming message style)
        GestureDetector(
          onTap: () => _toggleProblemExpansion(problem),
          onLongPress: () => _openProblemDetails(problem),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8, right: 60),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _ChatColors.bubbleIncoming,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Problem image carousel (auto-sliding)
                if (hasImage)
                  _ProblemImageCarousel(
                    images: [
                      problem.imageUrl1,
                      problem.imageUrl2,
                      problem.imageUrl3,
                    ]
                        .where((url) => url != null && url.isNotEmpty)
                        .cast<String>()
                        .toList(),
                  ),
                if (hasImage) const SizedBox(height: 8),
                // Category chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(problem.category)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    problem.category ?? 'Other',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _getCategoryColor(problem.category),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Problem name
                Text(
                  problem.name,
                  style: GoogleFonts.notoSansTelugu(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _ChatColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                // Tap hint
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.touch_app,
                      size: 14,
                      color: _ChatColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isExpanded ? 'Hide treatments' : 'Tap for treatments',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: _ChatColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Treatment replies (if expanded)
        if (isExpanded) _buildTreatmentReplies(problem),

        // Typing indicator (if this specific problem is loading)
        if (_typingProblemId == problem.id)
          Align(
            alignment: Alignment.centerRight,
            child: _buildTypingIndicator(),
          ),
      ],
    );
  }

  Widget _buildTreatmentReplies(CropProblem problem) {
    final advisory = _advisoryCache[problem.id];

    // If still loading or no data, show fallback
    if (advisory == null) {
      return _buildAdvisoryFallback(problem);
    }

    // Group recommendations by type
    final chemicalRecs = advisory.recommendations
        .where((r) => r.type.toLowerCase() == 'chemical')
        .toList();
    final biologicalRecs = advisory.recommendations
        .where((r) => r.type.toLowerCase() == 'biological')
        .toList();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Symptoms bubble
          if (advisory.symptoms.isNotEmpty && advisory.symptoms != 'N/A')
            _buildChatBubble(
              icon: Icons.visibility_outlined,
              title: 'లక్షణాలు',
              subtitle: 'Symptoms',
              content: advisory.symptoms,
              color: Colors.orange[700]!,
            ),

          // Chemical treatments bubble
          if (chemicalRecs.isNotEmpty)
            _buildTreatmentBubble(
              icon: Icons.biotech_outlined,
              title: 'రసాయన చికిత్స',
              subtitle: 'Chemical Treatment',
              recommendations: chemicalRecs,
              color: Colors.blue[600]!,
            ),

          // Biological treatments bubble
          if (biologicalRecs.isNotEmpty)
            _buildTreatmentBubble(
              icon: Icons.eco_outlined,
              title: 'జీవసంబంధ చికిత్స',
              subtitle: 'Biological Treatment',
              recommendations: biologicalRecs,
              color: Colors.green[600]!,
            ),

          // Mark as identified button (inline)
          _buildMarkAsIdentifiedButton(problem),
        ],
      ),
    );
  }

  Widget _buildMarkAsIdentifiedButton(CropProblem problem) {
    final isMarking = _markingProblemIds.contains(problem.id);
    final isIdentified = _identifiedProblemIds.contains(problem.id);

    return GestureDetector(
      onTap: isMarking || isIdentified
          ? null
          : () => _markProblemAsIdentified(problem),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(left: 60, bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isIdentified
              ? Colors.green.withValues(alpha: 0.15)
              : _ChatColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isIdentified
                ? Colors.green.withValues(alpha: 0.4)
                : _ChatColors.accent.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMarking)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _ChatColors.accent,
                ),
              )
            else if (isIdentified)
              const Icon(Icons.check_circle, size: 16, color: Colors.green)
            else
              const Icon(Icons.flag_outlined,
                  size: 16, color: _ChatColors.accent),
            const SizedBox(width: 6),
            Text(
              isIdentified ? 'ఈ సమస్య గుర్తించబడింది' : 'నాకు ఈ సమస్య ఉంది',
              style: GoogleFonts.notoSansTelugu(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isIdentified ? Colors.green : _ChatColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markProblemAsIdentified(CropProblem problem) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please login to mark problems',
              style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _markingProblemIds.add(problem.id));

    try {
      final result = await ApiService.saveIdentifiedProblem(
        oderId: currentUser.userId,
        problemId: problem.id,
      );

      if (result['success'] == true) {
        if (mounted) {
          setState(() {
            _markingProblemIds.remove(problem.id);
            _identifiedProblemIds.add(problem.id);
          });
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('సమస్య విజయవంతంగా గుర్తించబడింది!',
                  style: GoogleFonts.notoSansTelugu()),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception(result['error'] ?? 'Failed to save');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _markingProblemIds.remove(problem.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('గుర్తింపు విఫలమైంది: $e',
                style: GoogleFonts.notoSansTelugu()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAdvisoryFallback(CropProblem problem) {
    return GestureDetector(
      onTap: () => _openProblemDetails(problem),
      child: Container(
        margin: const EdgeInsets.only(left: 60, bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: _ChatColors.bubbleOutgoing,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(4),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 18, color: _ChatColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'చికిత్స సమాచారం అందుబాటులో లేదు',
                  style: GoogleFonts.notoSansTelugu(
                    fontSize: 13,
                    color: _ChatColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to view full details',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: _ChatColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble({
    required IconData icon,
    required String title,
    required String subtitle,
    required String content,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 60, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _ChatColors.bubbleOutgoing,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(4),
          bottomLeft: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.notoSansTelugu(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: _ChatColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Content
          Text(
            content,
            style: GoogleFonts.notoSansTelugu(
              fontSize: 13,
              height: 1.4,
              color: _ChatColors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentBubble({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<AdvisoryRecommendation> recommendations,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 60, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _ChatColors.bubbleOutgoing,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(4),
          bottomLeft: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with count badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.notoSansTelugu(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: _ChatColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${recommendations.length}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Treatment items
          ...recommendations.map((rec) => _buildTreatmentItem(rec, color)),
        ],
      ),
    );
  }

  Widget _buildTreatmentItem(AdvisoryRecommendation rec, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Medicine name
          Text(
            rec.name,
            style: GoogleFonts.notoSansTelugu(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _ChatColors.text,
            ),
          ),
          if (rec.altName != null && rec.altName!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              rec.altName!,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: _ChatColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (rec.dose != null && rec.dose!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.science_outlined, size: 14, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    rec.dose!,
                    style: GoogleFonts.notoSansTelugu(
                      fontSize: 12,
                      color: _ChatColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (rec.method != null && rec.method!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.water_drop_outlined, size: 14, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    rec.method!,
                    style: GoogleFonts.notoSansTelugu(
                      fontSize: 12,
                      color: _ChatColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _ChatColors.bubbleOutgoing,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDot(0),
          const SizedBox(width: 4),
          _buildDot(1),
          const SizedBox(width: 4),
          _buildDot(2),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _typingController,
      builder: (context, child) {
        final offset = (index * 0.15);
        final value = ((_typingController.value + offset) % 1.0);
        final scale = 0.6 + (0.4 * (1 - (2 * value - 1).abs()));
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: _ChatColors.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Color _getCategoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'pest':
        return Colors.orange[700]!;
      case 'disease':
        return Colors.red[600]!;
      case 'deficiency':
        return Colors.amber[700]!;
      case 'weed':
        return Colors.green[700]!;
      default:
        return Colors.grey[600]!;
    }
  }
}

// ============================================================================
// PROBLEM IMAGE CAROUSEL (Auto-sliding)
// ============================================================================
class _ProblemImageCarousel extends StatefulWidget {
  final List<String> images;

  const _ProblemImageCarousel({required this.images});

  @override
  State<_ProblemImageCarousel> createState() => _ProblemImageCarouselState();
}

class _ProblemImageCarouselState extends State<_ProblemImageCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Start auto-slide if more than one image
    if (widget.images.length > 1) {
      _startAutoSlide();
    }
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % widget.images.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _openImageViewer(int initialIndex) {
    _autoSlideTimer?.cancel();
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => _ImageViewerDialog(
        images: widget.images,
        initialIndex: initialIndex,
      ),
    ).then((_) {
      if (widget.images.length > 1) _startAutoSlide();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();

    // Single image - no carousel needed
    if (widget.images.length == 1) {
      return GestureDetector(
        onTap: () => _openImageViewer(0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: widget.images.first,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                memCacheHeight: 360,
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (_, __) => Container(
                  height: 180,
                  color: Colors.grey[200],
                  child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 180,
                  color: Colors.grey[200],
                  child: const Icon(Icons.image, color: Colors.grey),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.zoom_in, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Multiple images - carousel with dots
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _openImageViewer(index),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: widget.images[index],
                        fit: BoxFit.cover,
                        memCacheHeight: 360,
                        fadeInDuration: const Duration(milliseconds: 150),
                        placeholder: (_, __) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.zoom_in,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Page indicator dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.images.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentPage == index ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? _ChatColors.primary
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// FULLSCREEN IMAGE VIEWER WITH ZOOM
// ============================================================================
class _ImageViewerDialog extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _ImageViewerDialog({required this.images, required this.initialIndex});

  @override
  State<_ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<_ImageViewerDialog> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: widget.images[index],
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                style: IconButton.styleFrom(backgroundColor: Colors.black45),
              ),
            ),
            if (widget.images.length > 1)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.images.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
