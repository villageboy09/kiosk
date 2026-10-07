import 'package:cropsync/models/product.dart';
import 'package:cropsync/theme/app_text.dart';
import 'package:cropsync/widgets/shop/shop_category_style.dart';
import 'package:cropsync/widgets/shop/shop_filters.dart';
import 'package:cropsync/widgets/shop/shop_product_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

const int kShopMaxRails = 4;
const int kShopRailItems = 8;
const int kShopMoreItems = 8;

/// One horizontal section of a generic discover home.
class ShopRailG<T> {
  /// Raw category name, or null for the "New arrivals" rail.
  final String? category;
  final List<T> items;
  const ShopRailG(this.category, this.items);
}

/// Result of [buildRails].
typedef RailsData<T> = ({
  List<T> fresh,
  List<ShopRailG<T>> rails,
  List<T> more,
});

/// Splits [items] into discover sections: newest ([createdAtOf] desc, ties and
/// missing dates by [idOf] desc), per-category rails (>= 2 items, at most
/// [maxRails], in [categoryOrder] first) and a deduped "more" list.
RailsData<T> buildRails<T>({
  required List<T> items,
  required String Function(T) categoryOf,
  required int Function(T) idOf,
  DateTime? Function(T)? createdAtOf,
  List<String>? categoryOrder,
  int maxRails = kShopMaxRails,
  int railItems = kShopRailItems,
}) {
  final order = categoryOrder ?? const <String>[];
  int byNewest(T a, T b) {
    if (createdAtOf != null) {
      final da = createdAtOf(a), db = createdAtOf(b);
      if (da != null && db != null) {
        final c = db.compareTo(da);
        if (c != 0) return c;
      }
    }
    return idOf(b).compareTo(idOf(a));
  }

  final fresh = (List<T>.from(items)..sort(byNewest)).take(railItems).toList();

  final groups = <String, List<T>>{};
  for (final p in items) {
    groups.putIfAbsent(categoryOf(p), () => []).add(p);
  }
  final ordered = <String>[
    for (final c in order)
      if (groups.containsKey(c)) c,
    for (final c in groups.keys)
      if (!order.contains(c)) c,
  ];

  final rails = <ShopRailG<T>>[];
  final used = <int>{};
  for (final c in ordered) {
    final list = groups[c]!;
    if (list.length < 2 || rails.length >= maxRails) continue;
    final shown = list.take(railItems).toList();
    rails.add(ShopRailG<T>(c, shown));
    used.addAll(shown.map(idOf));
  }
  // Skip anything already shown in "New arrivals" or a category rail so small
  // catalogs don't repeat the same item 2-3 times on one screen.
  used.addAll(fresh.map(idOf));
  final more =
      items.where((p) => !used.contains(idOf(p))).take(railItems).toList();
  return (fresh: fresh, rails: rails, more: more);
}

/// One horizontal section of the shop discover home.
class ShopRail {
  /// Raw category name, or null for the "New arrivals" rail.
  final String? category;
  final List<Product> products;
  const ShopRail(this.category, this.products);
}

/// Splits [products] into the discover sections.
({List<Product> fresh, List<ShopRail> rails, List<Product> more})
    buildShopRails(
  List<Product> products,
  List<String> categoryOrder,
) {
  final d = buildRails<Product>(
    items: products,
    categoryOf: (p) => p.category,
    idOf: (p) => p.id,
    createdAtOf: (p) => p.createdAt,
    categoryOrder: categoryOrder,
    railItems: kShopRailItems,
  );
  return (
    fresh: d.fresh,
    rails: [for (final r in d.rails) ShopRail(r.category, r.items)],
    more: d.more.take(kShopMoreItems).toList(),
  );
}

/// Rail card width for a screen width (shared by shop and seeds).
double discoverRailCardWidth(double screenWidth) =>
    screenWidth > 600 ? 176 : 148;

/// Generic discover home: "New arrivals" + per-category rails + "More" rail.
class DiscoverHome<T> extends StatelessWidget {
  final RailsData<T> data;
  final int Function(T) idOf;

  /// Builds one card; it is wrapped in a [SizedBox] of `cardWidth`.
  final Widget Function(BuildContext, T item, double cardWidth) itemBuilder;
  final String freshTitle;
  final String moreTitle;
  final String Function(BuildContext, String category) railTitleFor;
  final ShopCategoryStyle Function(String category) styleOf;
  final ValueChanged<String> onSeeAll;
  final VoidCallback onViewAllMore;

  /// Rail height for a card width and the (unclamped) text scale.
  final double Function(double cardWidth, double textScale) railHeight;
  final double Function(double screenWidth) cardWidthFor;

  const DiscoverHome({
    super.key,
    required this.data,
    required this.idOf,
    required this.itemBuilder,
    required this.freshTitle,
    required this.moreTitle,
    required this.railTitleFor,
    required this.onSeeAll,
    required this.onViewAllMore,
    required this.railHeight,
    this.styleOf = shopCategoryStyle,
    this.cardWidthFor = discoverRailCardWidth,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final s = MediaQuery.textScalerOf(context).scale(1);
    final cardW = cardWidthFor(width);
    final railH = railHeight(cardW, s);

    Widget rail(String title, ShopCategoryStyle? style, List<T> list,
        VoidCallback? onSeeAllTap,
        {bool animate = false}) {
      return _RailSection(
        title: title,
        style: style,
        onSeeAll: onSeeAllTap,
        child: SizedBox(
          height: railH,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // ignore: deprecated_member_use
            cacheExtent: cardW * 3,
            itemCount: list.length,
            itemBuilder: (context, i) {
              final p = list[i];
              Widget card = SizedBox(
                key: ValueKey('rail_${title}_${idOf(p)}'),
                width: cardW,
                child: itemBuilder(context, p, cardW),
              );
              if (animate && i < 4) {
                card = TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 180 + i * 30),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(18 * (1 - t), 0),
                      child: child,
                    ),
                  ),
                  child: card,
                );
              }
              return Padding(
                padding: EdgeInsets.only(right: i == list.length - 1 ? 0 : 12),
                child: card,
              );
            },
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.fresh.isNotEmpty)
          RepaintBoundary(
            child: rail(
              freshTitle,
              const ShopCategoryStyle(
                  Icons.auto_awesome_rounded, Color(0xFFE3F4EC), kShopGreen),
              data.fresh,
              null,
              animate: true,
            ),
          ),
        for (final r in data.rails)
          RepaintBoundary(
            child: rail(
              railTitleFor(context, r.category!),
              styleOf(r.category!),
              r.items,
              () => onSeeAll(r.category!),
            ),
          ),
        if (data.more.isNotEmpty)
          RepaintBoundary(
            child: rail(moreTitle, null, data.more, onViewAllMore),
          ),
      ],
    );
  }
}

/// The shop "discover" home (products): thin wrapper over [DiscoverHome].
class ShopDiscoverHome extends StatelessWidget {
  final List<Product> products;
  final List<String> categories;
  final Set<int> wishlist;
  final bool Function(Product) isNew;
  final String Function(BuildContext, String) categoryLabel;
  final String Function(BuildContext, String) productName;
  final ValueChanged<Product> onOpen;
  final ValueChanged<Product> onBuyNow;
  final ValueChanged<int> onToggleWishlist;
  final ValueChanged<String> onSeeAll;

  /// "See all" on the "More products" rail: show every product as a grid.
  final VoidCallback onViewAll;

  const ShopDiscoverHome({
    super.key,
    required this.products,
    required this.categories,
    required this.wishlist,
    required this.isNew,
    required this.categoryLabel,
    required this.productName,
    required this.onOpen,
    required this.onBuyNow,
    required this.onToggleWishlist,
    required this.onSeeAll,
    required this.onViewAll,
  });

  static double railCardWidth(double screenWidth) =>
      discoverRailCardWidth(screenWidth);
  static const double railImageAspect = 1.0;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final d = buildShopRails(products, categories);
    return DiscoverHome<Product>(
      data: (
        fresh: d.fresh,
        rails: [
          for (final r in d.rails) ShopRailG<Product>(r.category, r.products)
        ],
        more: d.more,
      ),
      idOf: (p) => p.id,
      freshTitle: context.tr('shoph_new_arrivals'),
      moreTitle: context.tr('shoph_more_products'),
      railTitleFor: categoryLabel,
      styleOf: shopCategoryStyle,
      onSeeAll: onSeeAll,
      onViewAllMore: onViewAll,
      cardWidthFor: railCardWidth,
      railHeight: (w, s) => shopCardExtent(w, s, imageAspect: railImageAspect),
      itemBuilder: (context, p, cardW) => ShopProductCard(
        product: p,
        displayName: productName(context, p.name),
        isWishlisted: wishlist.contains(p.id),
        isNew: isNew(p),
        memCacheWidth: (cardW * dpr).round().clamp(120, 600),
        imageAspect: railImageAspect,
        onTap: () => onOpen(p),
        onBuyNow: () => onBuyNow(p),
        onToggleWishlist: () => onToggleWishlist(p.id),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ShopCategoryStyle? style;
  final VoidCallback? onSeeAll;

  const _SectionHeader({required this.title, this.style, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final seeAll = context.tr('shoph_see_all');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 4),
      child: Row(
        children: [
          if (style != null) ...[
            Container(
              width: 28,
              height: 28,
              decoration:
                  BoxDecoration(color: style!.tint, shape: BoxShape.circle),
              child: Icon(style!.icon, size: 16, color: style!.accent),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appStyle(
                context,
                text: title,
                size: 18,
                weight: FontWeight.w800,
                color: kShopInk,
                height: 1.4,
              ),
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: kShopGreen,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    seeAll,
                    maxLines: 1,
                    style: appStyle(
                      context,
                      text: seeAll,
                      size: 13,
                      weight: FontWeight.w700,
                      color: kShopGreen,
                      height: 1.3,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RailSection extends StatelessWidget {
  final String title;
  final ShopCategoryStyle? style;
  final VoidCallback? onSeeAll;
  final Widget child;

  const _RailSection({
    required this.title,
    required this.style,
    required this.onSeeAll,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title, style: style, onSeeAll: onSeeAll),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Shimmer placeholder for the discover home while the first load runs.
class DiscoverSkeleton extends StatelessWidget {
  final double Function(double cardWidth, double textScale) railHeight;
  const DiscoverSkeleton({super.key, required this.railHeight});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardW = discoverRailCardWidth(width);
    final s = MediaQuery.textScalerOf(context).scale(1);
    final h = railHeight(cardW, s);

    Widget block(double w, double h, [double r = 8]) => DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(r),
          ),
          child: SizedBox(width: w, height: h),
        );

    Widget section() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: block(140, 20),
            ),
            SizedBox(
              height: h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, __) => block(cardW, h, 14),
              ),
            ),
          ],
        );

    return Shimmer.fromColors(
      baseColor: const Color(0xFFEEF2F6),
      highlightColor: const Color(0xFFF8FAFC),
      child: Column(children: [section(), section()]),
    );
  }
}

/// Shop product skeleton (see [DiscoverSkeleton]).
class ShopDiscoverSkeleton extends StatelessWidget {
  const ShopDiscoverSkeleton({super.key});

  @override
  Widget build(BuildContext context) => DiscoverSkeleton(
        railHeight: (w, s) =>
            shopCardExtent(w, s, imageAspect: ShopDiscoverHome.railImageAspect),
      );
}
