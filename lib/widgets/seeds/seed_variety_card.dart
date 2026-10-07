import 'package:cropsync/models/seed_variety.dart';
import 'package:cropsync/theme/app_text.dart';
import 'package:cropsync/utils/seed_logic.dart';
import 'package:cropsync/widgets/shop/shop_category_style.dart';
import 'package:cropsync/widgets/shop/shop_filters.dart';
import 'package:cropsync/widgets/shop/shop_product_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

const double _kNameSize = 13.5;
const double _kCropSize = 11.5;
const double _kFactSize = 10.5;
const double _kPriceSize = 15;

/// Height of one fact chip (text line + 2px vertical padding each side).
double _factChipHeight(double s) => _kFactSize * 1.4 * s + 4;

/// Two stacked fact chips (yield, duration) with a 2px gap.
double _factBlockHeight(double s) => 2 * _factChipHeight(s) + 2;

/// Height of the info area under the image (name, crop, fact chips, price,
/// action pill) for a text scale. Identical for bookable / non bookable cards
/// so rails and grid rows stay aligned.
double seedCardInfoHeight(double textScale) {
  final s = textScale.clamp(1.0, kShopCardMaxTextScale);
  // top 8, name 2 lines, 3, crop line, 4, 2 stacked fact chips, 4, price, gap 8,
  // button 40, bottom 10, slack 2.
  return 8 +
      2 * _kNameSize * 1.4 * s +
      3 +
      _kCropSize * 1.3 * s +
      4 +
      _factBlockHeight(s) +
      4 +
      _kPriceSize * 1.3 * s +
      8 +
      40 +
      10 +
      2;
}

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// White-tile seed variety card, same look as the shop product card.
class SeedVarietyCard extends StatelessWidget {
  final SeedVariety variety;
  final String displayName;
  final String cropLabel;
  final String lang;
  final bool isWishlisted;
  final bool isNew;
  final int memCacheWidth;
  final double imageAspect;
  final VoidCallback onTap;
  final VoidCallback onAction;
  final VoidCallback onToggleWishlist;

  @visibleForTesting
  final ImageProvider? debugImageProvider;

  const SeedVarietyCard({
    super.key,
    required this.variety,
    required this.displayName,
    required this.cropLabel,
    required this.lang,
    required this.isWishlisted,
    required this.isNew,
    required this.memCacheWidth,
    required this.onTap,
    required this.onAction,
    required this.onToggleWishlist,
    this.imageAspect = 1,
    this.debugImageProvider,
  });

  /// One fact chip. Never shrinks the text (no FittedBox): long labels
  /// ellipsize instead, so Telugu/Hindi stay at a readable size.
  Widget _fact(BuildContext context, String text, Color bg, Color fg) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: appStyle(
            context,
            text: text,
            size: _kFactSize,
            weight: FontWeight.w700,
            color: fg,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = variety;
    final bookable = v.isBookable;
    final priceText = seedPriceLabel(v, lang);
    final yieldV = v.averageYield;
    final days = v.growthDuration;
    final yieldText = (yieldV != null && yieldV > 0)
        ? '${_num(yieldV)} ${context.tr('quintals_per_acre_short')}'
        : null;
    final daysText = (days != null && days > 0)
        ? context.tr('days_count', args: ['$days'])
        : null;
    final actionLabel = context.tr(bookable ? 'book_button' : 'view_details');
    final semanticsLabel = [
      if (isNew) context.tr('shop_new'),
      displayName,
      cropLabel,
      if (priceText.isNotEmpty) priceText,
    ].join(', ');
    // This context is above ShopCardShell's clamp, so clamp here too: the
    // fixed boxes below must match the scale the card text really uses.
    final scale = MediaQuery.textScalerOf(context)
        .scale(1)
        .clamp(1.0, kShopCardMaxTextScale);

    return ShopCardShell(
      onTap: onTap,
      semanticsLabel: semanticsLabel,
      customActions: {
        CustomSemanticsAction(
          label: context.tr(isWishlisted
              ? 'shop_remove_from_wishlist'
              : 'shop_add_to_wishlist'),
        ): onToggleWishlist,
        CustomSemanticsAction(label: actionLabel): onAction,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShopImageTile(
            imageUrl: v.primaryImage,
            aspect: imageAspect,
            memCacheWidth: memCacheWidth,
            placeholderStyle: cropStyle(v.cropName),
            isNew: isNew,
            isWishlisted: isWishlisted,
            onToggleWishlist: onToggleWishlist,
            showVideoBadge: v.hasVideo,
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
                      size: _kNameSize,
                      weight: FontWeight.w500,
                      color: kShopInk,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    cropLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appStyle(
                      context,
                      text: cropLabel,
                      size: _kCropSize,
                      color: const Color(0xFF64748B),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: _factBlockHeight(scale),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (yieldText != null)
                          _fact(context, yieldText, const Color(0xFFE3F4EC),
                              kShopGreen),
                        if (yieldText != null && daysText != null)
                          const SizedBox(height: 2),
                        if (daysText != null)
                          _fact(context, daysText, kShopGrey,
                              const Color(0xFF475569)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: _kPriceSize * 1.3 * scale,
                    child: priceText.isEmpty
                        ? null
                        : Text(
                            priceText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: appStyle(
                              context,
                              text: priceText,
                              size: _kPriceSize,
                              weight: FontWeight.w800,
                              color: kShopInk,
                              height: 1.3,
                            ),
                          ),
                  ),
                  const Spacer(),
                  ShopBuyButton(
                    enabled: true,
                    outlined: !bookable,
                    label: actionLabel,
                    onPressed: onAction,
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
