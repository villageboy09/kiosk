import 'dart:ui';
import 'package:cropsync/screens/agri_shop.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/farmer_analytics_service.dart';
import 'package:cropsync/services/share_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cropsync/widgets/safe_network_image.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:cropsync/theme/app_text.dart';

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
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.product.videoUrl!),
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _videoController = controller;
      _chewieController = ChewieController(
        videoPlayerController: controller,
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
                  context.tr('video_unavailable'),
                  style: appStyle(context,
                      color: AppTheme.textSecondary, weight: FontWeight.w700),
                ),
              ],
            ),
          );
        },
      );
      setState(() {});
    } catch (e) {
      // Video failed to initialize, will show images instead
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
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
                        color: AppTheme.textPrimary,
                        size: 80,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  context.tr('success'),
                  style: appStyle(
                    context,
                    size: 22,
                    weight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: appStyle(
                    context,
                    text: message,
                    size: 16,
                    color: AppTheme.textSecondary,
                    weight: FontWeight.w600,
                    height: 1.4,
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
                      backgroundColor: AppTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: Text(
                      context.tr('ok'),
                      style: appStyle(
                        context,
                        color: Colors.white,
                        size: 16,
                        weight: FontWeight.w700,
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

      // Log farmer shop enquiry
      FarmerAnalyticsService.logShopEnquiry(
        productId: widget.product.id,
        productName: widget.product.name,
        advertiserId: widget.product.advertiserId,
        advertiserName: widget.product.advertiserName,
      );

      if (!mounted) return;
      _showSuccessPopup(context.tr('enquiry_sent_success'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.tr('error')}: ${e.toString()}',
            style: appStyle(context, color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingEnquiry = false);
      }
    }
  }

  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const double _gutter = 20;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMediaShowcase(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(_gutter, 20, _gutter, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProductHeader(),
                        if (widget.product.advertiserName
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildSellerLine(),
                        ],
                        const SizedBox(height: 20),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 20),
                        _buildDescription(),
                        const SizedBox(height: 24),
                        _buildTrustNote(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildFloatingTopBar(),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingTopBar() {
    final topPadding = MediaQuery.of(context).padding.top;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, topPadding + 6, 12, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildFrostedButton(
            icon: Icons.arrow_back_rounded,
            label: context.tr('shopd_back'),
            onTap: () => Navigator.of(context).pop(),
          ),
          _buildFrostedButton(
            icon: Icons.share_outlined,
            label: context.tr('shopd_share'),
            onTap: () {
              HapticFeedback.lightImpact();
              ShareService.shareItem(
                context: context,
                type: 'shop',
                id: widget.product.id.toString(),
                title: widget.product.name,
                description: widget.product.description,
                price: '₹${widget.product.price}',
                imageUrl: primaryImageUrl,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFrostedButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        textStyle: appStyle(context, size: 12, color: Colors.white),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Material(
              color: Colors.white.withValues(alpha: 0.88),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onTap,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(icon, size: 21, color: _ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaShowcase() {
    final media = MediaQuery.of(context);
    final heroHeight =
        (media.size.height * 0.34).clamp(220.0, 360.0) + media.padding.top;

    return Container(
      height: heroHeight,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF6F8FA),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasVideo)
            Padding(
              padding: EdgeInsets.only(top: media.padding.top + 44),
              child: Chewie(controller: _chewieController!),
            )
          else if (imageUrls.isNotEmpty)
            PageView.builder(
              controller: _pageController,
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                final img = Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    media.padding.top + 48,
                    24,
                    28,
                  ),
                  child: SafeNetworkImage(
                    imageUrl: imageUrls[index],
                    fit: BoxFit.contain,
                    placeholder: Container(
                      color: const Color(0xFFF1F5F9),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
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
              child: Center(
                child: Icon(Icons.eco_outlined,
                    color: Colors.grey.shade300, size: 72),
              ),
            ),
          if (imageUrls.length > 1 && !hasVideo)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  imageUrls.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentPage == index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? _ink
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductHeader() {
    final product = widget.product;
    final name = getLocalizedProductName(context, product.name);
    final category = getLocalizedCategory(context, product.category);
    final discount = product.discountPercent;
    final mrp = product.mrp;
    final showMrp = mrp != null && (double.tryParse(product.price) ?? 0) < mrp;
    final showUnit = product.unit.isNotEmpty && product.unit != 'unit';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (category.trim().isNotEmpty) ...[
          Text(
            category,
            style: appStyle(
              context,
              text: category,
              size: 13,
              weight: FontWeight.w600,
              color: _muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          name,
          style: appStyle(
            context,
            text: name,
            size: 24,
            weight: FontWeight.w800,
            color: _ink,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 4,
          children: [
            Text(
              '₹${product.price}${showUnit ? ' / ${product.unit}' : ''}',
              style: appStyle(
                context,
                size: 24,
                weight: FontWeight.w800,
                color: _ink,
              ),
            ),
            if (showMrp)
              Text(
                '₹${mrp.toStringAsFixed(mrp % 1 == 0 ? 0 : 2)}',
                style: appStyle(
                  context,
                  size: 15,
                  color: _muted,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            if (showMrp && discount != null)
              Text(
                context.tr('shopd_percent_off',
                    namedArgs: {'percent': discount.toString()}),
                style: appStyle(
                  context,
                  size: 14,
                  weight: FontWeight.w700,
                  color: const Color(0xFF15803D),
                ),
              ),
            if (!product.inStock)
              Text(
                context.tr('shopd_out_of_stock'),
                style: appStyle(
                  context,
                  size: 14,
                  weight: FontWeight.w600,
                  color: _muted,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSellerLine() {
    final seller = widget.product.advertiserName.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.storefront_outlined, size: 18, color: _muted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${context.tr('sold_by')} $seller',
            style: appStyle(
              context,
              text: seller,
              size: 14,
              color: const Color(0xFF475569),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    final paragraphs = widget.product.description
        .split(RegExp(r'\n+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (paragraphs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('description'),
          style: appStyle(
            context,
            size: 17,
            weight: FontWeight.w700,
            color: _ink,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Text(
            paragraphs[i],
            style: appStyle(
              context,
              text: paragraphs[i],
              size: 15,
              color: const Color(0xFF475569),
              height: 1.7,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTrustNote() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.verified_user_outlined, size: 16, color: _muted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.tr('shopd_trust_note'),
            style: appStyle(
              context,
              size: 12.5,
              color: _muted,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final product = widget.product;

    return Container(
      padding: EdgeInsets.fromLTRB(_gutter, 10, _gutter, bottomPadding + 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Flexible(
            flex: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('price'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appStyle(
                    context,
                    color: _muted,
                    size: 12,
                    weight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                Text(
                  '₹${product.price}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appStyle(
                    context,
                    size: 20,
                    weight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmittingEnquiry ? null : _submitEnquiry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _ink,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: appStyle(
                    context,
                    size: 15,
                    weight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmittingEnquiry
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded, size: 16),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              context.tr('enquire_now'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: appStyle(
                                context,
                                color: Colors.white,
                                size: 15,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
