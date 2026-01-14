// lib/screens/advisory_details.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/models/advisory.dart';
import 'package:cropsync/models/crop_problem.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:easy_localization/easy_localization.dart';

// Enum to manage the state of the identification button
enum IdentificationState { initial, loading, success, error }

// --- UI Colors for Consistency ---
class _UIColors {
  static const Color background = Color(0xFFF0F2F5);
  static const Color card = Color(0xFFFFFFFF);
  static const Color primaryText = Color(0xFF212121);
  static const Color secondaryText = Color(0xFF757575);
  static const Color accent = Color(0xFF27AE60); // A green accent for agriculture
}

class AdvisoryDetailScreen extends StatefulWidget {
  final CropProblem problem;
  const AdvisoryDetailScreen({super.key, required this.problem});

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
      final advisoryData = await ApiService.getAdvisories(widget.problem.id, lang: locale);

      if (advisoryData == null) {
        throw Exception('Advisory not found');
      }

      // Fetch recommendations/components
      final advisoryId = advisoryData['id'] as int?;
      List<AdvisoryRecommendation> recommendations = [];

      if (advisoryId != null) {
        final componentsData = await ApiService.getAdvisoryComponents(advisoryId, lang: locale);
        recommendations = componentsData.map((r) {
          return AdvisoryRecommendation(
            type: r['component_type'] as String? ?? 'General',
            name: r['component_name'] as String? ?? 'N/A',
            dose: r['dose'] as String?,
            method: r['application_method'] as String?,
            notes: r['notes'] as String?,
          );
        }).where((rec) => rec.name != 'N/A').toList();
      }

      final Advisory advisory = Advisory(
        title: advisoryData['title'] as String? ?? 'N/A',
        symptoms: advisoryData['symptoms'] as String? ?? 'N/A',
        notes: advisoryData['notes'] as String?,
        recommendations: recommendations,
      );

      // Check if problem is already identified by user
      // Note: This would require an API endpoint to check
      // For now, we'll skip this check as it's not critical

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
            content: Text(context.tr('mark_problem_error'), style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _identificationState = IdentificationState.initial);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _UIColors.background,
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

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  _buildSliverAppBar(images),
                  SliverPadding(
                    padding: const EdgeInsets.all(16.0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildSectionCard(
                          title: context.tr('symptoms_title'),
                          content: advisory.symptoms,
                          icon: Icons.visibility_outlined,
                        ),
                        if (advisory.notes != null)
                          _buildSectionCard(
                            title: context.tr('notes_title'),
                            content: advisory.notes!,
                            icon: Icons.edit_note_outlined,
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
                          child: Text(context.tr('management_title'),
                              style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: _UIColors.primaryText)),
                        ),
                        ...advisory.recommendations.map((rec) => _buildRecommendationCard(rec)),
                        // Invisible spacer for the floating button
                        const SizedBox(height: 100),
                      ]),
                    ),
                  ),
                ],
              ),
              // Floating button positioned at the bottom
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _buildFloatingIdentificationButton(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(List<String?> images) {
    return SliverAppBar(
      expandedHeight: 280.0,
      backgroundColor: _UIColors.background,
      elevation: 0,
      pinned: true,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            decoration: BoxDecoration(
              color: _UIColors.card.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                color: _UIColors.primaryText, size: 20),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          widget.problem.name,
          style: GoogleFonts.poppins(
            color: _UIColors.primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        background: images.isNotEmpty
            ? _buildImageGallery(images)
            : Container(color: Colors.grey[200]),
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
              tag: 'problem_image_${widget.problem.id}',
              child: CachedNetworkImage(
                imageUrl: images[index]!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey[200]),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.broken_image, color: _UIColors.secondaryText),
              ),
            );
          },
        ),
        if (images.length > 1)
          Positioned(
            bottom: 16.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  height: 8.0,
                  width: _currentPage == index ? 24.0 : 8.0,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
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
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: _UIColors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _UIColors.accent, size: 24),
              const SizedBox(width: 12),
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _UIColors.primaryText)),
            ],
          ),
          const Divider(height: 24),
          Text(content,
              style: GoogleFonts.poppins(
                  fontSize: 15, height: 1.6, color: _UIColors.secondaryText)),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(AdvisoryRecommendation rec) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: _UIColors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: _UIColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16)),
                child: Icon(
                  _getIconForType(rec.type),
                  color: _UIColors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rec.name,
                        style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: _UIColors.primaryText)),
                    Text(rec.type,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: _UIColors.secondaryText,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (rec.dose != null)
            _buildDetailRow(Icons.science_outlined, context.tr('dose_title'), rec.dose!),
          if (rec.method != null)
            _buildDetailRow(Icons.water_drop_outlined, context.tr('method_title'), rec.method!),
          if (rec.notes != null)
            _buildDetailRow(Icons.notes_outlined, context.tr('notes_row_title'), rec.notes!),
        ],
      ),
    );
  }

  Widget _buildFloatingIdentificationButton() {
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _identificationState == IdentificationState.success
              ? Colors.green
              : _UIColors.accent,
          borderRadius: BorderRadius.circular(24),
          // "Pressed" effect created by changing the shadow
          boxShadow: _isButtonPressed
              ? [] // No shadow when pressed
              : [
                  BoxShadow(
                    color: _UIColors.accent.withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Center(
          child: _buildButtonChild(),
        ),
      ),
    );
  }

  // Helper widget to build the content inside the button
  Widget _buildButtonChild() {
    switch (_identificationState) {
      case IdentificationState.loading:
        return const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
        );
      case IdentificationState.success:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(context.tr('marked_identified'),
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        );
      case IdentificationState.initial:
      default:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flag_outlined, color: Colors.white),
            const SizedBox(width: 8),
            Text(context.tr('i_have_this_problem'),
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        );
    }
  }

  IconData _getIconForType(String type) {
    if (type.toLowerCase().contains('chemical')) return Icons.biotech_outlined;
    if (type.toLowerCase().contains('organic')) return Icons.eco_outlined;
    if (type.toLowerCase().contains('cultural')) return Icons.grass_outlined;
    return Icons.settings_outlined;
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: _UIColors.secondaryText),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: _UIColors.primaryText,
                        fontSize: 15)),
                const SizedBox(height: 4),
                Text(value,
                    style: GoogleFonts.poppins(
                        color: _UIColors.secondaryText, fontSize: 14, height: 1.5)),
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
          const Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 16),
          Text(
            context.tr('load_advisory_error'),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 18, color: _UIColors.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280.0,
            backgroundColor: _UIColors.background,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(color: Colors.white),
            ),
          ),
          SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Container(
                      height: 120,
                      decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(24))),
                  const SizedBox(height: 16),
                  Container(
                      height: 150,
                      decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(24))),
                  const SizedBox(height: 16),
                  Container(
                      height: 150,
                      decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(24))),
                ]),
              ))
        ],
      ),
    );
  }
}
