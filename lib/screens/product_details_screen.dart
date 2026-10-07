import 'package:cropsync/screens/agri_shop.dart';
import 'package:cropsync/widgets/shop/buy_now_sheet.dart';
import 'package:cropsync/widgets/shop/expandable_paragraphs.dart';
import 'package:cropsync/widgets/shop/shop_category_style.dart';
import 'package:cropsync/widgets/shop/shop_circle_button.dart';
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
  // Only the 'n/m' badge listens, so scrolling doesn't rebuild the screen.
  final ValueNotifier<int> _currentPage = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      _currentPage.value = _pageController.page?.round() ?? 0;
    });

    if (widget.product.videoUrl != null &&
        widget.product.videoUrl!.isNotEmpty) {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.networkUrl(
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
      // Video failed to initialize: release it; images remain the gallery.
      await controller?.dispose();
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _pageController.dispose();
    _currentPage.dispose();
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

  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _brand = Color(0xFF15803D);
  static const double _gutter = 20;
  static const double _barHeight = 76;
  static const double _overlap = 28;
  static const double _maxContentWidth = 640;

  /// Hero backdrop gradient from the same tint the shop cards use.
  static (Color, Color) _gradientFor(String category) {
    final st = shopCategoryStyle(category);
    return (st.tint, Color.lerp(st.tint, st.accent, 0.14)!);
  }

  bool get _showMrp {
    final p = widget.product;
    return p.mrp != null && p.mrp! > p.priceValue && p.priceValue > 0;
  }

  String get _mrpText => formatShopPrice(widget.product.mrp);

  Future<void> _buyNow() async {
    HapticFeedback.selectionClick();
    await showBuyNowSheet(context, widget.product);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final heroH = (media.size.height * 0.42).clamp(260.0, 460.0);
    final scrollBottom = _barHeight + media.padding.bottom + 16;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(bottom: scrollBottom),
              child: Stack(
                children: [
                  _buildHero(heroH),
                  Column(
                    children: [
                      SizedBox(height: heroH - _overlap),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, child) => Opacity(
                          opacity: v,
                          child: Transform.translate(
                            offset: Offset(0, 24 * (1 - v)),
                            child: child,
                          ),
                        ),
                        child: _buildContentCard(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, topPadding + 8, 12, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ShopCircleButton(
            icon: Icons.arrow_back_rounded,
            label: context.tr('shopd_back'),
            onTap: () => Navigator.of(context).pop(),
          ),
          ShopCircleButton(
            icon: Icons.ios_share_rounded,
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

  Widget _buildHero(double heroH) {
    final media = MediaQuery.of(context);
    final tint = _gradientFor(widget.product.category);
    final images = imageUrls;
    final video = hasVideo;
    final pageCount = (video ? 1 : 0) + images.length;
    final showImages = images.isNotEmpty;

    return Container(
      height: heroH,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tint.$1, tint.$2],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showImages)
            Positioned(
              bottom: _overlap + 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 190,
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 22,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Pages: the video (if it initialised) first, then every image.
          if (pageCount > 0)
            PageView.builder(
              controller: _pageController,
              itemCount: pageCount,
              itemBuilder: (context, index) {
                if (video && index == 0) {
                  return Padding(
                    padding: EdgeInsets.only(
                        top: media.padding.top + 60, bottom: _overlap),
                    child: Chewie(controller: _chewieController!),
                  );
                }
                final imgIndex = video ? index - 1 : index;
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                      32, media.padding.top + 60, 32, _overlap + 30),
                  child: SafeNetworkImage(
                    imageUrl: images[imgIndex],
                    fit: BoxFit.contain,
                    placeholder: Center(
                      child: Icon(Icons.image_outlined,
                          size: 48, color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ),
                );
              },
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: _overlap),
                child: Icon(Icons.eco_outlined,
                    color: Colors.white.withValues(alpha: 0.9), size: 84),
              ),
            ),
          if (pageCount > 1)
            Positioned(
              right: 16,
              bottom: _overlap + 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: ValueListenableBuilder<int>(
                  valueListenable: _currentPage,
                  builder: (context, page, _) => Text(
                    '${page.clamp(0, pageCount - 1) + 1}/$pageCount',
                    style: appStyle(context,
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContentCard() {
    final product = widget.product;
    final name = getLocalizedProductName(context, product.name);
    final category = getLocalizedCategory(context, product.category).trim();
    final seller = product.advertiserName.trim();
    final tint = _gradientFor(product.category);
    final discount = product.discountPercent;
    final showUnit = product.unit.isNotEmpty && product.unit != 'unit';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(_overlap)),
      ),
      padding: const EdgeInsets.fromLTRB(_gutter, 22, _gutter, 8),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (category.isNotEmpty)
                    _chip(category, tint.$2.withValues(alpha: 0.7), _ink,
                        dynamic: true),
                  _stockChip(),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                name,
                style: appStyle(context,
                    text: name,
                    size: 23,
                    weight: FontWeight.w800,
                    color: _ink,
                    height: 1.4),
              ),
              const SizedBox(height: 14),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 6,
                children: [
                  Text(
                    formatShopPrice(product.price),
                    style: appStyle(context,
                        size: 30, weight: FontWeight.w800, color: _ink),
                  ),
                  if (showUnit)
                    Text('/ ${product.unit}',
                        style: appStyle(context,
                            text: product.unit, size: 14, color: _muted)),
                  if (_showMrp)
                    Text(
                      _mrpText,
                      style: appStyle(context,
                          size: 16,
                          color: _muted,
                          decoration: TextDecoration.lineThrough),
                    ),
                  if (_showMrp && discount != null)
                    _chip(
                      context.tr('shopd_percent_off',
                          namedArgs: {'percent': discount.toString()}),
                      const Color(0xFFDCFCE7),
                      const Color(0xFF166534),
                    ),
                ],
              ),
              if (seller.isNotEmpty) ...[
                const SizedBox(height: 18),
                _buildSellerRow(seller),
              ],
              const SizedBox(height: 22),
              _buildHighlights(category, seller),
              ..._buildDescriptionSection(),
              const SizedBox(height: 20),
              _buildPayNote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg, {bool dynamic = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: appStyle(context,
            text: dynamic ? text : null,
            size: 12.5,
            weight: FontWeight.w700,
            color: fg,
            height: 1.35),
      ),
    );
  }

  Widget _stockChip() {
    final inStock = widget.product.inStock;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: inStock ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            inStock ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 14,
            color: inStock ? const Color(0xFF166534) : const Color(0xFF991B1B),
          ),
          const SizedBox(width: 5),
          Text(
            context.tr(inStock ? 'pd_in_stock' : 'shopd_out_of_stock'),
            style: appStyle(context,
                size: 12.5,
                weight: FontWeight.w700,
                height: 1.35,
                color: inStock
                    ? const Color(0xFF166534)
                    : const Color(0xFF991B1B)),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerRow(String seller) {
    final initial = seller.characters.first.toUpperCase();
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFE2E8F0),
            shape: BoxShape.circle,
          ),
          child: Text(initial,
              style: appStyle(context,
                  text: initial,
                  size: 17,
                  weight: FontWeight.w800,
                  color: _ink)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('sold_by'),
                  style:
                      appStyle(context, size: 12, color: _muted, height: 1.4)),
              Text(seller,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: appStyle(context,
                      text: seller,
                      size: 15,
                      weight: FontWeight.w700,
                      color: _ink,
                      height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHighlights(String category, String seller) {
    final items = <(IconData, String, String, bool)>[
      if (category.isNotEmpty)
        (Icons.category_outlined, context.tr('pd_category'), category, true),
      if (seller.isNotEmpty)
        (Icons.storefront_outlined, context.tr('pd_seller'), seller, true),
      (
        Icons.inventory_2_outlined,
        context.tr('pd_availability'),
        context
            .tr(widget.product.inStock ? 'pd_in_stock' : 'shopd_out_of_stock'),
        false
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('pd_highlights'),
            style: appStyle(context,
                size: 17, weight: FontWeight.w800, color: _ink, height: 1.4)),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(items[i].$1, size: 20, color: _brand),
                        const SizedBox(height: 8),
                        Text(items[i].$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: appStyle(context,
                                size: 11.5, color: _muted, height: 1.4)),
                        const SizedBox(height: 2),
                        Text(items[i].$3,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: appStyle(context,
                                text: items[i].$4 ? items[i].$3 : null,
                                size: 13,
                                weight: FontWeight.w700,
                                color: _ink,
                                height: 1.4)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDescriptionSection() {
    final paragraphs = widget.product.description
        .split(RegExp(r'\n+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (paragraphs.isEmpty) return const [];
    return [
      const SizedBox(height: 24),
      Text(context.tr('pd_about'),
          style: appStyle(context,
              size: 17, weight: FontWeight.w800, color: _ink, height: 1.4)),
      const SizedBox(height: 10),
      ExpandableParagraphs(paragraphs: paragraphs),
    ];
  }

  Widget _buildPayNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline_rounded, size: 17, color: _muted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr('pd_pay_note'),
              style: appStyle(context, size: 12.5, color: _muted, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final product = widget.product;
    final enabled = product.inStock;

    return Container(
      padding: EdgeInsets.fromLTRB(_gutter, 0, _gutter, bottomPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      // The bar has a fixed height, so cap the text scale inside it.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.4,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: SizedBox(
              height: _barHeight,
              child: Row(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: (MediaQuery.of(context).size.width * 0.34)
                            .clamp(96.0, 200.0)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_showMrp)
                          Text(
                            _mrpText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: appStyle(context,
                                size: 12,
                                color: _muted,
                                height: 1.2,
                                decoration: TextDecoration.lineThrough),
                          ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatShopPrice(product.price),
                            maxLines: 1,
                            style: appStyle(context,
                                size: 24,
                                weight: FontWeight.w800,
                                color: _ink,
                                height: 1.2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Semantics(
                      button: true,
                      enabled: enabled,
                      excludeSemantics: true,
                      label: context
                          .tr(enabled ? 'pd_buy_now' : 'shopd_out_of_stock'),
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: enabled ? _buyNow : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brand,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFE2E8F0),
                            disabledForegroundColor: _muted,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (enabled) ...[
                                const Icon(Icons.shopping_bag_outlined,
                                    size: 20),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Text(
                                  context.tr(enabled
                                      ? 'pd_buy_now'
                                      : 'shopd_out_of_stock'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: appStyle(context,
                                      size: 16,
                                      weight: FontWeight.w800,
                                      color: enabled ? Colors.white : _muted),
                                ),
                              ),
                              if (enabled) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 18),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
