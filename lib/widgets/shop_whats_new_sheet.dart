import 'package:cropsync/models/product.dart' show formatShopPrice;
import 'package:cropsync/models/shop_banner.dart';
import 'package:cropsync/models/shop_updates.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/shop_visit_tracker.dart';
import 'package:cropsync/theme/app_text.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const int _kMaxTiles = 4;
const Color _kGreenDark = Color(0xFF1B5E20);
const Color _kGreenSoft = Color(0xFFE8F5E9);

/// Shows the "what's new" sheet once per session when the shop has products or
/// banners the user has not seen yet. Never throws.
///
/// [debugOverride] replaces the network call (tests / previews).
Future<void> maybeShowShopWhatsNew(
  BuildContext context, {
  ShopUpdates? debugOverride,
}) async {
  try {
    if (ShopVisitTracker.shownThisSession) return;
    final lang = context.locale.languageCode;
    final userKey = ShopVisitTracker.currentUserKey();
    final seen = await ShopVisitTracker.load(userKey);

    final updates = debugOverride ??
        await ApiService.getShopUpdates(
          lang: lang,
          sinceProductId: seen.sinceProductId,
          sinceBannerId: seen.sinceBannerId,
          userId: userKey == 'guest' ? null : userKey,
        );
    if (updates == null) return;

    if (seen.isFirstRun) {
      await ShopVisitTracker.markSeen(
        userKey,
        productId: updates.latestProductId,
        bannerId: updates.latestBannerId,
      );
      return;
    }

    if (!updates.hasNew || ShopVisitTracker.shownThisSession) return;
    if (!context.mounted) return;

    ShopVisitTracker.markShownThisSession();
    // Mark seen up-front so killing the app while the sheet is open does not
    // re-show the same updates next session.
    await ShopVisitTracker.markSeen(
      userKey,
      productId: updates.latestProductId,
      bannerId: updates.latestBannerId,
    );
    if (!context.mounted) return;
    HapticFeedback.lightImpact();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.surface,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => ShopWhatsNewSheet(
        updates: updates,
        onShopNow: () => Navigator.of(sheetContext).pop(),
        onDismiss: () => Navigator.of(sheetContext).pop(),
      ),
    );
  } catch (e) {
    debugPrint('maybeShowShopWhatsNew failed: $e');
  }
}

class ShopWhatsNewSheet extends StatelessWidget {
  final ShopUpdates updates;
  final VoidCallback onShopNow;
  final VoidCallback onDismiss;

  const ShopWhatsNewSheet({
    super.key,
    required this.updates,
    required this.onShopNow,
    required this.onDismiss,
  });

  String _subtitle() {
    final parts = <String>[];
    final p = updates.newProductsCount;
    final b = updates.newBannersCount;
    if (p > 0) {
      parts.add((p == 1 ? 'shopnew_products_one' : 'shopnew_products_other')
          .tr(args: ['$p']));
    }
    if (b > 0) {
      parts.add((b == 1 ? 'shopnew_offers_one' : 'shopnew_offers_other')
          .tr(args: ['$b']));
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final shown = updates.newProducts.take(_kMaxTiles).toList();
    final more = updates.newProductsCount - shown.length;
    final banner =
        updates.newBanners.isNotEmpty ? updates.newBanners.first : null;
    final title = 'shopnew_title'.tr();
    final subtitle = _subtitle();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8F5E9), Color(0xFFF1F8E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: _kGreenDark, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: appStyle(context,
                              size: 19,
                              weight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              height: 1.3),
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: appStyle(context,
                              size: 13,
                              weight: FontWeight.w500,
                              color: _kGreenDark,
                              height: 1.35),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (shown.isNotEmpty) ...[
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < shown.length; i++)
                    _Reveal(
                      index: i,
                      child: _ProductTile(product: shown[i]),
                    ),
                  if (more > 0)
                    _Reveal(
                      index: shown.length,
                      child: _MoreTile(count: more),
                    ),
                ],
              ),
            ),
          ],
          if (banner != null) ...[
            const SizedBox(height: 16),
            _Reveal(index: shown.length + 1, child: _BannerPreview(banner)),
          ],
          const SizedBox(height: 20),
          Semantics(
            button: true,
            label: 'shopnew_explore'.tr(),
            excludeSemantics: true,
            child: SizedBox(
              height: 52,
              child: FilledButton(
                key: const Key('shop_whats_new_explore'),
                onPressed: onShopNow,
                style: FilledButton.styleFrom(
                  backgroundColor: _kGreenDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'shopnew_explore'.tr(),
                  textAlign: TextAlign.center,
                  style: appStyle(context,
                      size: 16, weight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Semantics(
            button: true,
            label: 'shopnew_later'.tr(),
            excludeSemantics: true,
            child: TextButton(
              key: const Key('shop_whats_new_later'),
              onPressed: onDismiss,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              child: Text(
                'shopnew_later'.tr(),
                textAlign: TextAlign.center,
                style: appStyle(context,
                    size: 14,
                    weight: FontWeight.w600,
                    color: AppTheme.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Light staggered fade + scale entrance (max ~350ms).
class _Reveal extends StatelessWidget {
  final int index;
  final Widget child;
  const _Reveal({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final ms = 200 + (index.clamp(0, 5)) * 30;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
      ),
      child: child,
    );
  }
}

class _ProductTile extends StatelessWidget {
  final ShopUpdateProduct product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppTheme.divider,
      alignment: Alignment.center,
      child: const Icon(Icons.eco_rounded, color: AppTheme.textHint, size: 28),
    );
    final url = product.imageUrl;
    return Container(
      width: 96,
      margin: const EdgeInsets.only(right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: url == null
                      ? placeholder
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => placeholder,
                          loadingBuilder: (_, child, progress) =>
                              progress == null ? child : placeholder,
                        ),
                ),
              ),
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kGreenDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'shopnew_new_pill'.tr(),
                    style: appStyle(context,
                        size: 9,
                        weight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: appStyle(context,
                text: product.name,
                size: 12,
                weight: FontWeight.w600,
                color: AppTheme.textPrimary,
                height: 1.3),
          ),
          if (product.price.isNotEmpty)
            Text(
              formatShopPrice(product.price),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appStyle(context,
                  size: 12, weight: FontWeight.w700, color: _kGreenDark),
            ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final int count;
  const _MoreTile({required this.count});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: _kGreenSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(6),
          child: Text(
            'shopnew_more'.tr(args: ['$count']),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: appStyle(context,
                size: 14, weight: FontWeight.w800, color: _kGreenDark),
          ),
        ),
      ),
    );
  }
}

class _BannerPreview extends StatelessWidget {
  final ShopUpdateBanner banner;
  const _BannerPreview(this.banner);

  @override
  Widget build(BuildContext context) {
    final url = banner.imageUrl;
    final gradient = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [banner.bgColor1, banner.bgColor2],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      padding: const EdgeInsets.all(14),
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (banner.title.isNotEmpty)
            Text(
              banner.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: appStyle(context,
                  text: banner.title,
                  size: 16,
                  weight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.25),
            ),
          if (banner.subtitle.isNotEmpty)
            Text(
              banner.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appStyle(context,
                  text: banner.subtitle,
                  size: 12,
                  weight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.9)),
            ),
        ],
      ),
    );
    final label = banner.title.trim().isNotEmpty
        ? banner.title.trim()
        : 'shop_banner_label'.tr();
    return Semantics(
      label: label,
      image: true,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: kShopBannerAspectRatio,
          child: url == null
              ? gradient
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => gradient,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : gradient,
                ),
        ),
      ),
    );
  }
}
