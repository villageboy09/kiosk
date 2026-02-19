// lib/screens/seed_varieties.dart

// ignore_for_file: use_build_context_synchronously

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart'; // Ensure google_fonts is imported if not already
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:video_player/video_player.dart';

/// Seed variety data model
class SeedVariety {
  final int id;
  final String cropName;
  final String varietyName;
  final String? varietyNameSecondary;
  final String? imageUrl;
  final String? details;
  final String? region;
  final String? sowingPeriod;
  final String? testimonialVideoUrl;
  final String? price;
  final String? priceUnit;
  final double? averageYield;
  final int? growthDuration;

  SeedVariety({
    required this.id,
    required this.cropName,
    required this.varietyName,
    this.varietyNameSecondary,
    this.imageUrl,
    this.details,
    this.region,
    this.sowingPeriod,
    this.testimonialVideoUrl,
    this.price,
    this.priceUnit,
    this.averageYield,
    this.growthDuration,
  });

  double get priceValue => double.tryParse(price ?? '0') ?? 0;

  factory SeedVariety.fromJson(Map<String, dynamic> json) {
    return SeedVariety(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      cropName: json['crop_name']?.toString() ?? 'Unknown',
      varietyName: json['variety_name']?.toString() ?? 'Unknown',
      varietyNameSecondary: json['variety_name_secondary']?.toString(),
      imageUrl: json['image_url']?.toString(),
      details: json['details']?.toString(),
      region: json['region']?.toString(),
      sowingPeriod: json['sowing_period']?.toString(),
      testimonialVideoUrl: json['testimonial_video_url']?.toString(),
      price: json['price']?.toString(),
      priceUnit: json['price_unit']?.toString(),
      averageYield: double.tryParse(json['average_yield']?.toString() ?? ''),
      growthDuration: int.tryParse(json['growth_duration']?.toString() ?? ''),
    );
  }
}

/// Main seed varieties screen - e-commerce grid style
class SeedVarietiesScreen extends StatefulWidget {
  const SeedVarietiesScreen({super.key});

  @override
  State<SeedVarietiesScreen> createState() => _SeedVarietiesScreenState();
}

class _SeedVarietiesScreenState extends State<SeedVarietiesScreen> {
  late Future<List<SeedVariety>> _varietiesFuture;
  List<SeedVariety> _allVarieties = [];
  List<SeedVariety> _filteredVarieties = [];
  String? _selectedCrop;
  Locale? _lastLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = context.locale;
    if (_lastLocale != currentLocale) {
      _lastLocale = currentLocale;
      _varietiesFuture = _fetchVarieties();
    }
  }

  Future<List<SeedVariety>> _fetchVarieties() async {
    try {
      final locale = context.locale.languageCode;
      final user = AuthService.currentUser;

      final response = await ApiService.getSeedVarieties(
        lang: locale,
        userId: user?.userId,
      );
      _allVarieties = response.map((v) => SeedVariety.fromJson(v)).toList();
      if (mounted) {
        setState(() => _filteredVarieties = _allVarieties);
      }
      return _filteredVarieties;
    } catch (e) {
      rethrow;
    }
  }

  void _filterByCrop(String? cropName) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCrop = cropName;
      _filteredVarieties = cropName == null
          ? _allVarieties
          : _allVarieties.where((v) => v.cropName == cropName).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      pinned: true,
      floating: true,
      snap: true,
      expandedHeight: 60,
      leading: null,
      automaticallyImplyLeading: false,
      title: Text(
        context.tr('seed_varieties_title'),
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildBody() {
    return FutureBuilder<List<SeedVariety>>(
      future: _varietiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(child: _SeedShimmer());
        }
        if (snapshot.hasError) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('load_error'),
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        final cropTypes = _allVarieties.map((v) => v.cropName).toSet().toList();

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(child: _buildFilters(cropTypes)),
              if (_filteredVarieties.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      context.tr('no_varieties_found'),
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ),
                )
              else
                SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.52,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _SeedCard(
                      variety: _filteredVarieties[index],
                      onTap: () => _showDetails(_filteredVarieties[index]),
                    ),
                    childCount: _filteredVarieties.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilters(List<String> cropTypes) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: SizedBox(
        height: 38,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: cropTypes.length + 1,
          itemBuilder: (context, index) {
            final isAll = index == 0;
            final crop = isAll ? null : cropTypes[index - 1];
            final label = isAll ? context.tr('all_filter') : crop!;
            final isSelected = _selectedCrop == crop;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _filterByCrop(crop),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1A1A1A) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1A1A1A)
                          : const Color(0xFFE8E8E8),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color:
                          isSelected ? Colors.white : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showDetails(SeedVariety variety) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SeedDetailsSheet(variety: variety),
    );
  }
}

/// Seed card with 3:1 image to text ratio
class _SeedCard extends StatelessWidget {
  final SeedVariety variety;
  final VoidCallback onTap;

  const _SeedCard({required this.variety, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF0F0F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image section - 3 parts (75%)
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(13)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: variety.imageUrl ?? '',
                        width: double.infinity,
                        fit: BoxFit.cover,
                        memCacheWidth: 400,
                        memCacheHeight: 400,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[100],
                          child: const Center(
                              child: Icon(Icons.image, color: Colors.grey)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[100],
                          child: const Center(
                              child:
                                  Icon(Icons.broken_image, color: Colors.grey)),
                        ),
                      ),
                      if (variety.testimonialVideoUrl != null)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_circle_fill,
                                    color: Colors.white, size: 12),
                                SizedBox(width: 3),
                                Text('Video',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            variety.cropName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Text section - 1 part (25%)
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        variety.varietyName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (variety.growthDuration != null)
                            Row(
                              children: [
                                Icon(Icons.schedule_rounded,
                                    size: 10, color: Colors.grey[400]),
                                const SizedBox(width: 2),
                                Text(
                                  '${variety.growthDuration}d',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          if (variety.price != null)
                            Text(
                              '₹${variety.price}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2E7D32),
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
        ),
      ),
    );
  }
}

/// Seed details bottom sheet with video player and integrated purchase
class _SeedDetailsSheet extends StatefulWidget {
  final SeedVariety variety;

  const _SeedDetailsSheet({required this.variety});

  @override
  State<_SeedDetailsSheet> createState() => _SeedDetailsSheetState();
}

class _SeedDetailsSheetState extends State<_SeedDetailsSheet> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isVideoLoading = false;
  bool _showVideo = false;
  double _quantity = 1.0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    if (_videoController != null ||
        widget.variety.testimonialVideoUrl == null) {
      return;
    }

    setState(() => _isVideoLoading = true);

    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.variety.testimonialVideoUrl!),
      );
      await _videoController!.initialize();

      if (mounted) {
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: true,
          looping: false,
          aspectRatio: 16 / 9,
          showControls: true,
          materialProgressColors: ChewieProgressColors(
            playedColor: AppTheme.primary,
            handleColor: AppTheme.primary,
            bufferedColor: Colors.grey[300]!,
            backgroundColor: Colors.grey[200]!,
          ),
        );
        setState(() {
          _showVideo = true;
          _isVideoLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVideoLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load video')),
        );
      }
    }
  }

  double get _totalPrice => widget.variety.priceValue * _quantity;

  Future<void> _submitPurchase() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final user = AuthService.currentUser;

      if (user == null) throw Exception('Not logged in');

      final bookingId = 'SB${DateTime.now().millisecondsSinceEpoch}';

      final result = await ApiService.createSeedBooking(
        bookingId: bookingId,
        userId: user.userId,
        seedVarietyId: widget.variety.id,
        quantityKg: _quantity,
        totalPrice: _totalPrice,
      );

      if (result['success'] == true) {
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.tr('purchase_request_sent')),
            backgroundColor: AppTheme.primary,
          ),
        );
      } else {
        throw Exception(result['error'] ?? 'Failed');
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final variety = widget.variety;

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Content
          Flexible(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image/Video
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _showVideo && _chewieController != null
                          ? Chewie(controller: _chewieController!)
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: variety.imageUrl ?? '',
                                  fit: BoxFit.cover,
                                  memCacheWidth: 800,
                                  placeholder: (_, __) =>
                                      Container(color: const Color(0xFFF5F5F5)),
                                  errorWidget: (_, __, ___) => Container(
                                    color: const Color(0xFFF5F5F5),
                                    child: Icon(Icons.eco_outlined,
                                        size: 48, color: Colors.grey[400]),
                                  ),
                                ),
                                if (variety.testimonialVideoUrl != null)
                                  Material(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    child: InkWell(
                                      onTap:
                                          _isVideoLoading ? null : _initVideo,
                                      child: Center(
                                        child: _isVideoLoading
                                            ? const CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 3)
                                            : Container(
                                                padding:
                                                    const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.9),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                    Icons.play_arrow_rounded,
                                                    size: 40,
                                                    color: AppTheme.primary),
                                              ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Crop badge + duration
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          variety.cropName,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary),
                        ),
                      ),
                      if (variety.growthDuration != null) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.schedule_rounded,
                            size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text('${variety.growthDuration} ${context.tr('days')}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500])),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Name
                  Text(variety.varietyName,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A))),
                  if (variety.varietyNameSecondary != null &&
                      variety.varietyNameSecondary != variety.varietyName)
                    Text(variety.varietyNameSecondary!,
                        style:
                            TextStyle(fontSize: 15, color: Colors.grey[500])),

                  // Info grid
                  const SizedBox(height: 16),
                  _buildInfoGrid(),

                  // Description
                  if (variety.details != null &&
                      variety.details!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(context.tr('details'),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(variety.details!,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            height: 1.4)),
                  ],

                  // Purchase section (integrated in sheet)
                  if (variety.price != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        children: [
                          // Price per unit
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(context.tr('price'),
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey[600])),
                              Text(
                                '₹${variety.price}${variety.priceUnit != null ? ' / ${_formatUnit(variety.priceUnit!)}' : '/kg'}',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2E7D32)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Quantity selector
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(context.tr('quantity_kg'),
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey[600])),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xFFE5E7EB)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: _quantity > 0.5
                                          ? () => setState(() => _quantity =
                                              (_quantity - 0.5).clamp(0.5, 100))
                                          : null,
                                      icon: const Icon(Icons.remove, size: 18),
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(),
                                      color: AppTheme.primary,
                                    ),
                                    Container(
                                      width: 50,
                                      alignment: Alignment.center,
                                      child: Text(_quantity.toStringAsFixed(1),
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    IconButton(
                                      onPressed: () => setState(() =>
                                          _quantity = (_quantity + 0.5)
                                              .clamp(0.5, 100)),
                                      icon: const Icon(Icons.add, size: 18),
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(),
                                      color: AppTheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Total
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(context.tr('total'),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                                Text('₹${_totalPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF166534))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Submit button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSubmitting ? null : _submitPurchase,
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.shopping_cart_outlined,
                                      size: 18),
                              label: Text(context.tr('submit_request')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                textStyle: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid() {
    final variety = widget.variety;
    final items = <_InfoItem>[];

    if (variety.region != null) {
      items.add(_InfoItem(
          Icons.location_on_outlined, context.tr('region'), variety.region!));
    }
    if (variety.sowingPeriod != null) {
      items.add(_InfoItem(Icons.calendar_today_outlined,
          context.tr('sowing_period'), variety.sowingPeriod!));
    }
    if (variety.growthDuration != null) {
      items.add(_InfoItem(
          Icons.schedule_outlined,
          context.tr('growth_duration'),
          '${variety.growthDuration} ${context.tr('days')}'));
    }
    if (variety.averageYield != null) {
      items.add(_InfoItem(Icons.eco_outlined, context.tr('average_yield'),
          '${variety.averageYield} ${context.tr('quintals_per_acre')}'));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map((item) => Container(
                width: (MediaQuery.of(context).size.width - 60) / 2,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(item.icon, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Flexible(
                            child: Text(item.label,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[500]),
                                overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(item.value,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A))),
                  ],
                ),
              ))
          .toList(),
    );
  }

  String _formatUnit(String unit) {
    switch (unit) {
      case 'per_kg':
        return context.tr('per_kg');
      case 'per_packet':
        return context.tr('per_packet');
      case 'per_450g_packet':
        return context.tr('per_450g_packet');
      default:
        return unit;
    }
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  _InfoItem(this.icon, this.label, this.value);
}

/// Shimmer loading state
class _SeedShimmer extends StatelessWidget {
  const _SeedShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8E8E8),
      highlightColor: const Color(0xFFF5F5F5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                itemBuilder: (_, __) => Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.52,
                ),
                itemCount: 6,
                itemBuilder: (_, __) => Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
