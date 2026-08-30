// lib/screens/advisory_details.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/models/advisory.dart';
import 'package:cropsync/models/crop_problem.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cropsync/theme/app_theme.dart';

import 'package:cropsync/services/farmer_analytics_service.dart';

// Enum to manage the state of the identification button
enum IdentificationState { initial, loading, success, error }

class AdvisoryDetailScreen extends StatefulWidget {
  final CropProblem problem;
  final String? cropName;

  const AdvisoryDetailScreen({
    super.key,
    required this.problem,
    this.cropName,
  });

  @override
  State<AdvisoryDetailScreen> createState() => _AdvisoryDetailScreenState();
}

class _AdvisoryDetailScreenState extends State<AdvisoryDetailScreen> {
  late Future<Advisory> _advisoryFuture;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // State variables for the button
  var _identificationState = IdentificationState.initial;
  bool _isButtonPressed = false;

  // Add this flag to prevent multiple calls
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Only initialize the PageController here
    _pageController.addListener(() {
      if (!mounted) return;
      setState(() {
        _currentPage = _pageController.page?.round() ?? 0;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Call the API fetch here instead, and only once
    if (!_isInitialized) {
      _advisoryFuture = _fetchAdvisoryDetailsAndCheckIdentified();
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _getLocaleField(String locale) {
    switch (locale) {
      case 'hi':
        return 'hi';
      case 'te':
        return 'te';
      default:
        return 'en';
    }
  }

  Future<Advisory> _fetchAdvisoryDetailsAndCheckIdentified() async {
    try {
      final locale = _getLocaleField(context.locale.languageCode);

      // Fetch advisory from MySQL API
      final advisoryData =
          await ApiService.getAdvisories(widget.problem.id, lang: locale)
              .timeout(const Duration(seconds: 10));
      if (!mounted) {
        throw StateError('Widget disposed before advisory loaded');
      }

      if (advisoryData == null) {
        throw Exception('Advisory not found');
      }

      // Fetch recommendations/components
      final advisoryId = advisoryData['id'] as int?;
      List<AdvisoryRecommendation> recommendations = [];

      if (advisoryId != null) {
        final componentsData =
            await ApiService.getAdvisoryComponents(advisoryId, lang: locale)
                .timeout(const Duration(seconds: 10));
        if (!mounted) {
          throw StateError('Widget disposed before advisory components loaded');
        }
        recommendations = componentsData
            .map((r) {
              return AdvisoryRecommendation.fromJson(r);
            })
            .where((rec) => rec.name != 'N/A' && rec.name.isNotEmpty)
            .toList();
      }

      final Advisory advisory = Advisory(
        title: advisoryData['title'] as String? ?? 'N/A',
        symptoms: advisoryData['symptoms'] as String? ?? 'N/A',
        notes: advisoryData['notes'] as String?,
        recommendations: recommendations,
      );

      // Log interaction
      FarmerAnalyticsService.logControlMeasureView(
        problemId: widget.problem.id,
        problemName: widget.problem.name,
        advisoryId: advisoryId,
        cropName: widget.cropName,
        category: widget.problem.category,
      );

      return advisory;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _markAsIdentified() async {
    setState(() => _identificationState = IdentificationState.loading);

    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User is not authenticated.');
      }

      final result = await ApiService.saveIdentifiedProblem(
        oderId: currentUser.userId,
        problemId: widget.problem.id,
      );

      if (result['success'] == true) {
        if (mounted) {
          setState(() => _identificationState = IdentificationState.success);
        }
      } else {
        throw Exception(result['error'] ?? 'Failed to save');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('mark_problem_error'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _identificationState = IdentificationState.initial);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FutureBuilder<Advisory>(
        future: _advisoryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerLoading();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _buildErrorState();
          }

          final advisory = snapshot.data!;
          final images = [
            widget.problem.imageUrl1,
            widget.problem.imageUrl2,
            widget.problem.imageUrl3
          ].where((url) => url != null && url.isNotEmpty).toList();

          // Group recommendations by type
          final chemicalRecs = advisory.recommendations
              .where((r) => r.type.toLowerCase() == 'chemical')
              .toList();
          final biologicalRecs = advisory.recommendations
              .where((r) => r.type.toLowerCase() == 'biological')
              .toList();

          final isTelugu = context.locale.languageCode == 'te';

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(images),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Category badge if available (Translated)
                    if (widget.problem.category != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        child: Wrap(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(
                                        widget.problem.category!)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: _getCategoryColor(
                                          widget.problem.category!)
                                      .withValues(alpha: 0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                _getLocalizedCategory(widget.problem.category!),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: _getCategoryColor(
                                      widget.problem.category!),
                                  letterSpacing: 0.5,
                                  height: isTelugu ? 1.4 : 1.15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Symptoms section
                    _buildSectionCard(
                      title: context.tr('symptoms_title'),
                      content: advisory.symptoms,
                      icon: Icons.visibility_rounded,
                      isTelugu: isTelugu,
                    ),

                    if (advisory.notes != null && advisory.notes!.isNotEmpty)
                      _buildSectionCard(
                        title: context.tr('notes_title'),
                        content: advisory.notes!,
                        icon: Icons.edit_note_rounded,
                        isTelugu: isTelugu,
                      ),

                    // Management/Remedies section
                    if (advisory.recommendations.isNotEmpty) ...[
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 28.0, bottom: 16.0),
                        child: Row(
                          children: [
                            const Icon(Icons.medical_services_rounded,
                                color: AppTheme.textPrimary, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                context.tr('management_title'),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.6,
                                  height: isTelugu ? 1.4 : 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Chemical treatments section
                      if (chemicalRecs.isNotEmpty) ...[
                        _buildTreatmentTypeHeader(
                          context.tr('chemical_treatments'),
                          Icons.biotech_rounded,
                          const Color(0xFF2563EB),
                          chemicalRecs.length,
                          isTelugu,
                        ),
                        ...chemicalRecs
                            .map((rec) => _buildRecommendationCard(rec, isTelugu)),
                      ],

                      // Biological treatments section
                      if (biologicalRecs.isNotEmpty) ...[
                        _buildTreatmentTypeHeader(
                          context.tr('biological_treatments'),
                          Icons.eco_rounded,
                          const Color(0xFF059669),
                          biologicalRecs.length,
                          isTelugu,
                        ),
                        ...biologicalRecs
                            .map((rec) => _buildRecommendationCard(rec, isTelugu)),
                      ],
                    ],

                    // Non-sticky Problem Identification Button
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0, bottom: 32.0),
                      child: _buildIdentificationButton(isTelugu),
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getLocalizedCategory(String? category) {
    if (category == null || category.trim().isEmpty) {
      return 'category_advisory'.tr();
    }
    final cat = category.toLowerCase().trim();
    if (cat.contains('fung')) return 'category_fungal_disease'.tr();
    if (cat.contains('insect') ||
        cat.contains('pest') ||
        cat.contains('borer') ||
        cat.contains('worm') ||
        cat.contains('పురుగు') ||
        cat.contains('కీటక')) {
      return 'category_insect_pest'.tr();
    }
    if (cat.contains('bacter')) return 'category_bacterial_disease'.tr();
    if (cat.contains('virus') || cat.contains('viral')) return 'category_viral_disease'.tr();
    if (cat.contains('nutrient') || cat.contains('deficiency') || cat.contains('లోపం')) {
      return 'category_nutrient_deficiency'.tr();
    }
    if (cat.contains('abiotic')) return 'category_abiotic_disorder'.tr();
    if (cat.contains('nematode')) return 'category_nematode'.tr();
    if (cat.contains('weed')) return 'category_weed'.tr();
    if (cat.contains('disease') || cat.contains('తెగులు') || cat.contains('रोग')) {
      return 'category_disease'.tr();
    }
    return category;
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'fungal disease':
        return const Color(0xFF9333EA);
      case 'insect pest':
        return const Color(0xFFEA580C);
      case 'bacterial disease':
        return const Color(0xFFDC2626);
      case 'viral disease':
        return const Color(0xFF7C3AED);
      case 'nutrient deficiency':
        return const Color(0xFF2563EB);
      case 'abiotic disorder':
        return const Color(0xFF4B5563);
      case 'nematode':
        return const Color(0xFF0D9488);
      default:
        return AppTheme.textSecondary;
    }
  }

  Widget _buildTreatmentTypeHeader(
      String title, IconData icon, Color color, int count, bool isTelugu) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.3,
                height: isTelugu ? 1.4 : 1.2,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSliverAppBar(List<String?> images) {
    return SliverAppBar(
      expandedHeight: 320.0,
      backgroundColor: const Color(0xFF111827),
      elevation: 0,
      pinned: true,
      leadingWidth: 72,
      leading: Center(child: AppTheme.backButton(context, color: Colors.white)),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          widget.problem.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.getTextStyle(
            context,
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            images.isNotEmpty
                ? _buildImageGallery(images)
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF111827), Color(0xFF1F2937)],
                      ),
                    ),
                  ),
            // Bottom gradient to ensure title readability when expanded
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 120,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGallery(List<String?> images) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: images.length,
          itemBuilder: (context, index) {
            return Hero(
              tag: 'problem_image_${widget.problem.id}_$index',
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullScreenImageViewer(
                            imageUrls: images.whereType<String>().toList(),
                            initialIndex: index,
                            tagPrefix: 'problem_image_${widget.problem.id}',
                          ),
                        ),
                      );
                    },
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: CachedNetworkImage(
                        imageUrl: images[index]!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: const Color(0xFFF3F4F6)),
                        errorWidget: (context, url, error) => const Icon(
                            Icons.broken_image_rounded,
                            color: AppTheme.textHint),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // Visual indicator that image can be tapped to zoom
        Positioned(
          top: 60,
          right: 16,
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FullScreenImageViewer(
                    imageUrls: images.whereType<String>().toList(),
                    initialIndex: _currentPage,
                    tagPrefix: 'problem_image_${widget.problem.id}',
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Zoom',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (images.length > 1)
          Positioned(
            bottom: 64.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  height: 6.0,
                  width: _currentPage == index ? 24.0 : 6.0,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(100),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String content,
    required IconData icon,
    required bool isTelugu,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.textPrimary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.4,
                    height: isTelugu ? 1.4 : 1.2,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(height: 1, thickness: 1),
          ),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              height: isTelugu ? 1.75 : 1.6,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(AdvisoryRecommendation rec, bool isTelugu) {
    final isChemical = rec.type.toLowerCase() == 'chemical';
    final typeColor =
        isChemical ? const Color(0xFF2563EB) : const Color(0xFF059669);

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20)),
                child: Icon(
                  _getIconForType(rec.type),
                  color: typeColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.4,
                        height: isTelugu ? 1.45 : 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Stage scope badge
          if (rec.stageScope != null && rec.stageScope != 'All Stages')
            Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 13, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Text(
                    rec.stageScope!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFD97706),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18.0),
            child: Divider(height: 1, thickness: 1),
          ),

          if (rec.dose != null && rec.dose!.isNotEmpty)
            _buildDetailRow(
              Icons.science_rounded,
              context.tr('dose_title'),
              rec.dose!,
              isTelugu,
            ),
          if (rec.method != null && rec.method!.isNotEmpty)
            _buildDetailRow(
              Icons.water_drop_rounded,
              context.tr('method_title'),
              rec.method!,
              isTelugu,
            ),
          if (rec.notes != null && rec.notes!.isNotEmpty)
            _buildDetailRow(
              Icons.notes_rounded,
              context.tr('notes_row_title'),
              rec.notes!,
              isTelugu,
            ),
        ],
      ),
    );
  }

  Widget _buildIdentificationButton(bool isTelugu) {
    bool isDisabled = _identificationState == IdentificationState.loading ||
        _identificationState == IdentificationState.success;

    return GestureDetector(
      onTapDown: (_) {
        if (!isDisabled) setState(() => _isButtonPressed = true);
      },
      onTapUp: (_) {
        if (!isDisabled) {
          setState(() => _isButtonPressed = false);
          _markAsIdentified();
        }
      },
      onTapCancel: () {
        if (!isDisabled) setState(() => _isButtonPressed = false);
      },
      child: AnimatedScale(
        scale: _isButtonPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: _identificationState == IdentificationState.success
                ? AppTheme.success
                : AppTheme.textPrimary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (_identificationState == IdentificationState.success
                        ? AppTheme.success
                        : AppTheme.textPrimary)
                    .withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: _buildButtonChild(isTelugu),
          ),
        ),
      ),
    );
  }

  // Helper widget to build the content inside the button
  Widget _buildButtonChild(bool isTelugu) {
    switch (_identificationState) {
      case IdentificationState.loading:
        return const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
        );
      case IdentificationState.success:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: Colors.white, size: 24),
            const SizedBox(width: 10),
            Text(
              context.tr('marked_identified'),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 0.2,
                height: isTelugu ? 1.35 : 1.15,
              ),
            ),
          ],
        );
      case IdentificationState.initial:
      default:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flag_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            Text(
              context.tr('i_have_this_problem'),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 0.2,
                height: isTelugu ? 1.35 : 1.15,
              ),
            ),
          ],
        );
    }
  }

  IconData _getIconForType(String type) {
    if (type.toLowerCase().contains('chemical')) return Icons.biotech_rounded;
    if (type.toLowerCase().contains('biological')) return Icons.eco_rounded;
    if (type.toLowerCase().contains('organic')) return Icons.eco_rounded;
    if (type.toLowerCase().contains('cultural')) return Icons.grass_rounded;
    return Icons.settings_rounded;
  }

  Widget _buildDetailRow(IconData icon, String title, String value, bool isTelugu) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppTheme.textPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    fontSize: 14.5,
                    letterSpacing: -0.2,
                    height: isTelugu ? 1.35 : 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: isTelugu ? 1.65 : 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.error, size: 64),
          const SizedBox(height: 20),
          Text(
            context.tr('load_advisory_error'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 17,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE5E7EB),
      highlightColor: const Color(0xFFF3F4F6),
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280.0,
            backgroundColor: AppTheme.background,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(color: Colors.white),
            ),
          ),
          SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                ]),
              )),
        ],
      ),
    );
  }
}

class FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String tagPrefix;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
    required this.tagPrefix,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, TransformationController> _transformControllers = {};
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  TransformationController _getController(int index) {
    if (!_transformControllers.containsKey(index)) {
      final controller = TransformationController();
      controller.addListener(() {
        final scale = controller.value.getMaxScaleOnAxis();
        final zoomed = scale > 1.05;
        if (zoomed != _isZoomed) {
          if (mounted) setState(() => _isZoomed = zoomed);
        }
      });
      _transformControllers[index] = controller;
    }
    return _transformControllers[index]!;
  }

  void _zoomIn() {
    final controller = _getController(_currentIndex);
    final currentScale = controller.value.getMaxScaleOnAxis();
    final newScale = (currentScale + 0.75).clamp(1.0, 5.0);
    controller.value = Matrix4.diagonal3Values(newScale, newScale, 1.0);
  }

  void _zoomOut() {
    final controller = _getController(_currentIndex);
    final currentScale = controller.value.getMaxScaleOnAxis();
    final newScale = (currentScale - 0.75).clamp(1.0, 5.0);
    controller.value = Matrix4.diagonal3Values(newScale, newScale, 1.0);
  }

  void _resetZoom() {
    final controller = _getController(_currentIndex);
    controller.value = Matrix4.identity();
  }

  void _handleDoubleTap(TapDownDetails details) {
    final controller = _getController(_currentIndex);
    final currentScale = controller.value.getMaxScaleOnAxis();
    if (currentScale > 1.2) {
      controller.value = Matrix4.identity();
    } else {
      final position = details.localPosition;
      final translation = Matrix4.translationValues(-position.dx * 1.5, -position.dy * 1.5, 0.0);
      final scale = Matrix4.diagonal3Values(2.5, 2.5, 1.0);
      controller.value = translation * scale;
    }
  }

  @override
  void dispose() {
    for (final c in _transformControllers.values) {
      c.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: _isZoomed
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                _isZoomed = false;
              });
            },
            itemBuilder: (context, index) {
              final controller = _getController(index);
              return GestureDetector(
                onDoubleTapDown: _handleDoubleTap,
                onDoubleTap: () {},
                child: Center(
                  child: Hero(
                    tag: '${widget.tagPrefix}_$index',
                    child: InteractiveViewer(
                      transformationController: controller,
                      minScale: 1.0,
                      maxScale: 5.0,
                      clipBehavior: Clip.none,
                      child: CachedNetworkImage(
                        imageUrl: widget.imageUrls[index],
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white54,
                          size: 64,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Close button on top right
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Zoom toolbar and page counter at bottom
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Page counter
                if (widget.imageUrls.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.imageUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 40),

                // Interactive Zoom Controls
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_rounded, color: Colors.white, size: 20),
                        tooltip: 'Zoom Out',
                        onPressed: _zoomOut,
                        visualDensity: VisualDensity.compact,
                      ),
                      if (_isZoomed)
                        IconButton(
                          icon: const Icon(Icons.restart_alt_rounded, color: AppTheme.accentGreen, size: 20),
                          tooltip: 'Reset Zoom',
                          onPressed: _resetZoom,
                          visualDensity: VisualDensity.compact,
                        ),
                      IconButton(
                        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                        tooltip: 'Zoom In',
                        onPressed: _zoomIn,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


