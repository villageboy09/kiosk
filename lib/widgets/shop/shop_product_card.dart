import 'package:cropsync/models/product.dart';
import 'package:cropsync/theme/app_text.dart';
import 'package:cropsync/widgets/safe_network_image.dart';
import 'package:cropsync/widgets/shop/shop_filters.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

/// Max text scale honoured inside a card (keeps fixed-extent grid cells safe).
const double kShopCardMaxTextScale = 1.5;

/// Height of the text area under the square image for a given text scale.
double shopCardInfoHeight(double textScale) {
  final s = textScale.clamp(1.0, kShopCardMaxTextScale);
  // padding 8+10, name 2 lines (13*1.45), price (16*1.3), mrp row (11.5*1.4).
  return 18 + 2 * 13 * 1.45 * s + 4 + 16 * 1.3 * s + 2 + 11.5 * 1.4 * s + 6;
}

class ShopProductCard extends StatelessWidget {
  final Product product;
  final String displayName;
  final bool isWishlisted;
  final bool isNew;
  final int memCacheWidth;
  final VoidCallback onTap;
  final VoidCallback onToggleWishlist;

  const ShopProductCard({
    super.key,
    required this.product,
    required this.displayName,
    required this.isWishlisted,
    required this.isNew,
    required this.memCacheWidth,
    required this.onTap,
    required this.onToggleWishlist,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final discount = product.discountPercent;
    final mrp = product.mrp;
    final showMrp = discount != null && mrp != null;
    final priceText = formatShopPrice(product.priceValue);
    final semanticsLabel = [
      if (isNew) context.tr('shop_new'),
      displayName,
      priceText,
      if (!product.inStock) context.tr('shop_out_of_stock'),
    ].join(', ');

    return MediaQuery(
      data: mq.copyWith(
        textScaler: mq.textScaler.clamp(
          maxScaleFactor: kShopCardMaxTextScale,
        ),
      ),
      child: Semantics(
        container: true,
        button: true,
        label: semanticsLabel,
        onTap: onTap,
        excludeSemantics: true,
        customSemanticsActions: {
          CustomSemanticsAction(
            label: context.tr(isWishlisted
                ? 'shop_remove_from_wishlist'
                : 'shop_add_to_wishlist'),
          ): onToggleWishlist,
        },
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE8EDF2)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: const Color(0xFFF8FAFC),
                        child: Opacity(
                          opacity: product.inStock ? 1 : 0.5,
                          child: SafeNetworkImage(
                            imageUrl: product.primaryImage,
                            fit: BoxFit.cover,
                            memCacheWidth: memCacheWidth,
                          ),
                        ),
                      ),
                      if (isNew)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: kShopGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              context.tr('shop_new'),
                              style: appStyle(
                                context,
                                size: 10.5,
                                weight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 0,
                        right: 0,
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
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.85),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isWishlisted
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      size: 18,
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
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
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
                            size: 13,
                            weight: FontWeight.w600,
                            color: kShopInk,
                            height: 1.45,
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
                            size: 16,
                            weight: FontWeight.w800,
                            color: kShopInk,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (!product.inStock)
                          Text(
                            context.tr('shop_out_of_stock'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: appStyle(
                              context,
                              size: 11.5,
                              weight: FontWeight.w600,
                              color: const Color(0xFF94A3B8),
                              height: 1.4,
                            ),
                          )
                        else if (showMrp)
                          Row(
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
                                    color: const Color(0xFF94A3B8),
                                    height: 1.4,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  context.tr('shop_percent_off',
                                      namedArgs: {'percent': '$discount'}),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: appStyle(
                                    context,
                                    size: 11.5,
                                    weight: FontWeight.w700,
                                    color: kShopGreen,
                                    height: 1.4,
                                  ),
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
      ),
    );
  }
}
