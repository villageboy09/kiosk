// lib/screens/product_details_screen.dart

// ignore_for_file: use_build_context_synchronously

import 'package:cropsync/screens/agri_shop.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cropsync/widgets/safe_network_image.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;
  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSubmittingEnquiry = false;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _currentPage = _pageController.page?.round() ?? 0;
        });
      }
    });

    if (widget.product.videoUrl != null &&
        widget.product.videoUrl!.isNotEmpty) {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.product.videoUrl!),
      );
      await _videoController!.initialize();
      if (mounted) {
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: false,
          looping: false,
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 42),
                  const SizedBox(height: 8),
                  Text(
                    'Video unavailable',
                    style: GoogleFonts.lexend(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          },
        );
        setState(() {});
      }
    } catch (e) {
      // Video failed to initialize, will show images instead
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  List<String> get imageUrls => [
        widget.product.imageUrl1,
        widget.product.imageUrl2,
        widget.product.imageUrl3,
      ]
          .whereType<String>()
          .map((url) => url.trim())
          .where((url) => url.isNotEmpty)
          .toList(growable: false);

  String? get primaryImageUrl => imageUrls.isEmpty ? null : imageUrls.first;

  bool get hasVideo =>
      _videoController != null && _videoController!.value.isInitialized;

  void _showSuccessPopup(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 80,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  context.tr('success'),
                  style: GoogleFonts.lexend(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(); // close dialog
                      Navigator.of(context).pop(); // go back to AgriShop
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      context.tr('ok'),
                      style: GoogleFonts.lexend(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitEnquiry() async {
    if (_isSubmittingEnquiry) return;

    setState(() => _isSubmittingEnquiry = true);

    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final result = await ApiService.createEnquiry(
        productId: widget.product.id,
        farmerId: currentUser.userId,
        advertiserId: widget.product.advertiserId,
      );

      if (result['success'] != true) {
        throw Exception(result['error'] ?? 'Failed to send enquiry');
      }

      if (!mounted) return;
      _showSuccessPopup(context.tr('enquiry_sent_success'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('error')}: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingEnquiry = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: CustomScrollView(
            slivers: [
              _buildMediaAppBar(),
              _buildProductInfo(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  SliverAppBar _buildMediaAppBar() {
    final expandedHeight = (MediaQuery.of(context).size.height * 0.35)
        .clamp(280.0, 420.0)
        .toDouble();

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      floating: false,
      stretch: true,
      backgroundColor: Colors.grey.shade100,
      elevation: 0,
      leading: Center(
        child: InkWell(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(180),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.arrow_back, color: Colors.black87, size: 20),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (hasVideo)
              Chewie(controller: _chewieController!)
            else if (imageUrls.isNotEmpty)
              PageView.builder(
                controller: _pageController,
                itemCount: imageUrls.length,
                itemBuilder: (context, index) {
                  final img = SafeNetworkImage(
                    imageUrl: imageUrls[index],
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: Colors.grey.shade200,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey.shade400,
                        size: 36,
                      ),
                    ),
                  );

                  if (index == 0) {
                    return Hero(
                      tag: 'product_image_${widget.product.id}',
                      child: img,
                    );
                  }
                  return img;
                },
              )
            else
              Hero(
                tag: 'product_image_${widget.product.id}',
                child: Icon(Icons.eco_outlined,
                    color: Colors.grey.shade300, size: 80),
              ),
            if (imageUrls.length > 1 && !hasVideo)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    imageUrls.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildProductInfo() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.product.category,
              style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              widget.product.name,
              style: GoogleFonts.lexend(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.store_mall_directory_outlined,
                    color: Colors.grey.shade500, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${context.tr('sold_by')}: ${widget.product.advertiserName}',
                  style: GoogleFonts.lexend(
                      fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              context.tr('description'),
              style: GoogleFonts.lexend(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.product.description,
              style: GoogleFonts.lexend(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: primaryImageUrl != null
                        ? SafeNetworkImage(
                            imageUrl: primaryImageUrl!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            placeholder: Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey.shade200,
                              child: Icon(
                                Icons.eco_outlined,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade200,
                            child: Icon(
                              Icons.eco_outlined,
                              color: Colors.grey.shade400,
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          style: GoogleFonts.lexend(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${widget.product.price}',
                          style: GoogleFonts.lexend(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('enquiry_description'),
              style: GoogleFonts.lexend(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isCompact = MediaQuery.sizeOf(context).width < 420;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              )
            ],
          ),
          child: isCompact
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('price'),
                            style: GoogleFonts.lexend(
                                color: Colors.grey.shade500, fontSize: 12)),
                        Text('₹${widget.product.price}',
                            style: GoogleFonts.lexend(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _isSubmittingEnquiry ? null : _submitEnquiry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmittingEnquiry
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Text(
                              context.tr('enquire_now'),
                              style: GoogleFonts.lexend(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('price'),
                            style: GoogleFonts.lexend(
                                color: Colors.grey.shade500, fontSize: 12)),
                        Text('₹${widget.product.price}',
                            style: GoogleFonts.lexend(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmittingEnquiry ? null : _submitEnquiry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmittingEnquiry
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : Text(
                                context.tr('enquire_now'),
                                style: GoogleFonts.lexend(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
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
