import 'package:cropsync/models/product.dart';
import 'package:cropsync/theme/app_text.dart';
import 'package:cropsync/widgets/safe_network_image.dart';
import 'package:cropsync/widgets/shop/shop_category_style.dart';
import 'package:cropsync/widgets/shop/shop_filters.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

/// Max text scale honoured inside a card (keeps fixed-extent grid cells safe).
const double kShopCardMaxTextScale = 1.5;

/// Inset between the card edge and the image tile.
const double kShopCardImageInset = 4;

/// Height of the info area (name, price, MRP row, Buy now button) under the
/// image for a given text scale.
double shopCardInfoHeight(double textScale) {
  final s = textScale.clamp(1.0, kShopCardMaxTextScale);
  // top 8, name 2 lines, 4, price, 2, mrp row, 8, button 40, bottom 10, slack.
  return 8 +
      2 * 13.5 * 1.4 * s +
      4 +
      15 * 1.3 * s +
      2 +
      (10.5 * 1.3 * s + 4) +
      8 +
      40 +
      10 +
      2;
}

/// Full cell height for a card of [width] with image ratio [imageAspect].
double shopCardExtent(double width, double textScale,
        {double imageAspect = 1}) =>
    width / imageAspect + shopCardInfoHeight(textScale);

/// Generic cell height: image area ([width] / [imageAspect]) + [infoHeight].
double cardExtent(double width, double textScale,
        {required double infoHeight, double imageAspect = 1.0}) =>
    width / imageAspect + infoHeight;

/// Compact full-width pill button (disabled look when [enabled] is false).
/// Defaults to "Buy now" / "Out of stock"; pass [label] to override the text
/// and [outlined] for a green-outline secondary look.
class ShopBuyButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  final String? label;
  final bool outlined;

  const ShopBuyButton({
    super.key,
    required this.enabled,
    required this.onPressed,
    this.label,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = this.label ??
        context.tr(enabled ? 'shoph_buy_now' : 'shop_out_of_stock');
    final fg = !enabled
        ? const Color(0xFF64748B)
        : (outlined ? kShopGreen : Colors.white);
    return SizedBox(
      height: 40,
      width: double.infinity,
      child: Material(
        color: !enabled
            ? const Color(0xFFE9EEF3)
            : (outlined ? Colors.white : kShopGreen),
        shape: outlined && enabled
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: kShopGreen, width: 1.2),
              )
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: appStyle(
                    context,
                    text: label,
                    size: 13,
                    weight: FontWeight.w700,
                    color: fg,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card chrome: clamped text scale, semantics, rounded bordered Material and
/// an InkWell. Shared by shop product cards and seed variety cards.
class ShopCardShell extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final String semanticsLabel;
  final Map<CustomSemanticsAction, VoidCallback> customActions;

  const ShopCardShell({
    super.key,
    required this.child,
    required this.onTap,
    required this.semanticsLabel,
    this.customActions = const {},
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: kShopCardMaxTextScale,
      child: Semantics(
        container: true,
        button: true,
        label: semanticsLabel,
        onTap: onTap,
        excludeSemantics: true,
        customSemanticsActions: customActions,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE8EDF2)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: child),
        ),
      ),
    );
  }
}

/// White square image tile (4px inset, BoxFit.contain) with optional "New"
/// pill, heart button (28px visual / 44px tap) and bottom-left video badge.
class ShopImageTile extends StatelessWidget {
  final String? imageUrl;
  final double aspect;
  final int memCacheWidth;
  final ShopCategoryStyle placeholderStyle;
  final bool dimmed;
  final bool isNew;
  final bool isWishlisted;

  /// Null hides the heart button.
  final VoidCallback? onToggleWishlist;
  final bool showVideoBadge;

  @visibleForTesting
  final ImageProvider? debugImageProvider;

  const ShopImageTile({
    super.key,
    required this.imageUrl,
    required this.placeholderStyle,
    this.aspect = 1,
    this.memCacheWidth = 400,
    this.dimmed = false,
    this.isNew = false,
    this.isWishlisted = false,
    this.onToggleWishlist,
    this.showVideoBadge = false,
    this.debugImageProvider,
  });

  Widget _placeholder() => ColoredBox(
        color: const Color(0xFFF8FAFC),
        child: Center(
          child: Icon(
            placeholderStyle.icon,
            size: 36,
            color: placeholderStyle.accent.withValues(alpha: 0.25),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final imageProvider = debugImageProvider;
    return AspectRatio(
      aspectRatio: aspect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.all(kShopCardImageInset),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEDF1F5)),
                ),
                child: ColoredBox(
                  // White like most catalogue photos so letterbox
                  // bars from BoxFit.contain are invisible.
                  color: Colors.white,
                  child: Opacity(
                    opacity: dimmed ? 0.55 : 1,
                    child: imageProvider != null
                        ? Image(
                            image: imageProvider,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : SafeNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.contain,
                            memCacheWidth: memCacheWidth,
                            placeholder: _placeholder(),
                          ),
                  ),
                ),
              ),
            ),
          ),
          if (isNew)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: kShopGreen.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  context.tr('shop_new'),
                  style: appStyle(
                    context,
                    size: 9.5,
                    weight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          if (showVideoBadge)
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    size: 16, color: Colors.white),
              ),
            ),
          if (onToggleWishlist != null)
            Positioned(
              top: 2,
              right: 2,
              child: Semantics(
                button: true,
                toggled: isWishlisted,
                label: context.tr(isWishlisted
                    ? 'shop_remove_from_wishlist'
                    : 'shop_add_to_wishlist'),
                child: ExcludeSemantics(
                  child: InkResponse(
                    onTap: onToggleWishlist,
                    radius: 22,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isWishlisted
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 17,
                            color: isWishlisted
                                ? const Color(0xFFE11D48)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ShopProductCard extends StatelessWidget {
  final Product product;
  final String displayName;
  final bool isWishlisted;
  final bool isNew;
  final int memCacheWidth;
  final VoidCallback onTap;
  final VoidCallback onToggleWishlist;
  final VoidCallback onBuyNow;

  /// Image area width / height (1 = square; rails use a wider ratio).
  final double imageAspect;

  /// Test-only override so card rendering can be checked without network.
  @visibleForTesting
  final ImageProvider? debugImageProvider;

  const ShopProductCard({
    super.key,
    required this.product,
    required this.displayName,
    required this.isWishlisted,
    required this.isNew,
    required this.memCacheWidth,
    required this.onTap,
    required this.onToggleWishlist,
    required this.onBuyNow,
    this.imageAspect = 1,
    this.debugImageProvider,
  });

  @override
  Widget build(BuildContext context) {
    // This context sits above ShopCardShell's clamp, so clamp explicitly.
    final cardTextScale = MediaQuery.textScalerOf(context)
        .scale(1)
        .clamp(1.0, kShopCardMaxTextScale);
    final discount = product.discountPercent;
    final mrp = product.mrp;
    final showMrp = discount != null && mrp != null && product.inStock;
    final priceText = formatShopPrice(product.priceValue);
    final catStyle = shopCategoryStyle(product.category);
    final semanticsLabel = [
      if (isNew) context.tr('shop_new'),
      displayName,
      priceText,
      if (!product.inStock) context.tr('shop_out_of_stock'),
    ].join(', ');

    return ShopCardShell(
      onTap: onTap,
      semanticsLabel: semanticsLabel,
      customActions: {
        CustomSemanticsAction(
          label: context.tr(isWishlisted
              ? 'shop_remove_from_wishlist'
              : 'shop_add_to_wishlist'),
        ): onToggleWishlist,
        if (product.inStock)
          CustomSemanticsAction(label: context.tr('shoph_buy_now')): onBuyNow,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShopImageTile(
            imageUrl: product.primaryImage,
            aspect: imageAspect,
            memCacheWidth: memCacheWidth,
            placeholderStyle: catStyle,
            dimmed: !product.inStock,
            isNew: isNew,
            isWishlisted: isWishlisted,
            onToggleWishlist: onToggleWishlist,
            debugImageProvider: debugImageProvider,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: appStyle(
                      context,
                      text: displayName,
                      size: 13.5,
                      weight: FontWeight.w500,
                      color: kShopInk,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    priceText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appStyle(
                      context,
                      text: priceText,
                      size: 15,
                      weight: FontWeight.w800,
                      color: kShopInk,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 10.5 * 1.3 * cardTextScale + 4,
                    child: showMrp
                        ? Row(
                            children: [
                              Flexible(
                                child: Text(
                                  formatShopPrice(mrp),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: appStyle(
                                    context,
                                    text: '0',
                                    size: 11.5,
                                    color: const Color(0xFF64748B),
                                    height: 1.3,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE3F4EC),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    context.tr('shop_percent_off',
                                        namedArgs: {'percent': '$discount'}),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: appStyle(
                                      context,
                                      size: 10.5,
                                      weight: FontWeight.w700,
                                      color: kShopGreen,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                  const Spacer(),
                  ShopBuyButton(
                    enabled: product.inStock,
                    onPressed: onBuyNow,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
