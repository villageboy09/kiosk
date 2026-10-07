import 'dart:async';

import 'package:cropsync/models/product.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/farmer_analytics_service.dart';
import 'package:cropsync/theme/app_text.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:cropsync/widgets/safe_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Signature of the call that places the order request (injectable for tests).
typedef PlaceEnquiryFn = Future<EnquiryResult> Function({
  required int productId,
  required String farmerId,
  required int advertiserId,
});

/// Shows the shared "Buy now" checkout sheet. Resolves to true when the order
/// request was placed (even if the sheet was dismissed after success).
///
/// The enquiries table has no quantity/notes column, so no quantity is sent.
Future<bool> showBuyNowSheet(
  BuildContext context,
  Product product, {
  @visibleForTesting PlaceEnquiryFn? placeEnquiry,
}) async {
  var placed = false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Drag-to-dismiss is disabled: it bypasses the PopScope guard and cannot be
    // toggled per phase. Back and barrier taps go through maybePop, so PopScope
    // blocks them while an order is submitting; idle dismissal still works via
    // barrier, back and the Cancel button.
    enableDrag: false,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => BuyNowSheet(
      product: product,
      placeEnquiry: placeEnquiry,
      onPlaced: () => placed = true,
    ),
  );
  return placed;
}

enum _Phase { idle, submitting, success, error }

class BuyNowSheet extends StatefulWidget {
  const BuyNowSheet({
    super.key,
    required this.product,
    this.placeEnquiry,
    this.onPlaced,
  });

  final Product product;
  final PlaceEnquiryFn? placeEnquiry;
  final VoidCallback? onPlaced;

  @override
  State<BuyNowSheet> createState() => _BuyNowSheetState();
}

class _BuyNowSheetState extends State<BuyNowSheet>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF15803D);
  static const _greenSoft = Color(0xFFECFDF3);
  static const _ink = Color(0xFF0F172A);

  _Phase _phase = _Phase.idle;
  EnquiryFailure? _failure;
  bool _busy = false; // synchronous double-tap guard
  late final AnimationController _check = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void dispose() {
    _check.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !widget.product.inStock) return;
    _busy = true;
    setState(() {
      _phase = _Phase.submitting;
      _failure = null;
    });

    final p = widget.product;
    final user = AuthService.currentUser;
    EnquiryResult result;
    if (user == null || user.userId.isEmpty) {
      result = const EnquiryResult.failed(EnquiryFailure.notLoggedIn);
    } else if (p.advertiserId <= 0) {
      result = const EnquiryResult.failed(EnquiryFailure.missingSeller);
    } else {
      final place = widget.placeEnquiry ?? _defaultPlace;
      try {
        result = await place(
          productId: p.id,
          farmerId: user.userId,
          advertiserId: p.advertiserId,
        );
      } catch (_) {
        result = const EnquiryResult.failed(EnquiryFailure.server);
      }
    }

    _busy = false;
    if (!mounted) {
      if (result.ok) widget.onPlaced?.call();
      return;
    }

    if (result.ok) {
      widget.onPlaced?.call();
      try {
        FarmerAnalyticsService.logShopEnquiry(
          productId: p.id,
          productName: p.name,
          advertiserId: p.advertiserId,
          advertiserName: p.advertiserName,
        );
      } catch (_) {}
      HapticFeedback.mediumImpact();
      setState(() => _phase = _Phase.success);
      _check.forward(from: 0);
    } else {
      setState(() {
        _phase = _Phase.error;
        _failure = result.failure ?? EnquiryFailure.server;
      });
    }
  }

  static Future<EnquiryResult> _defaultPlace({
    required int productId,
    required String farmerId,
    required int advertiserId,
  }) =>
      ApiService.placeEnquiry(
        productId: productId,
        farmerId: farmerId,
        advertiserId: advertiserId,
      );

  String _errorText() {
    switch (_failure) {
      case EnquiryFailure.notLoggedIn:
        return 'buy_err_login'.tr();
      case EnquiryFailure.missingSeller:
        return 'buy_err_seller'.tr();
      case EnquiryFailure.network:
        return 'buy_err_network'.tr();
      case EnquiryFailure.server:
      case null:
        return 'buy_err_server'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: _phase != _Phase.submitting,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: _phase == _Phase.success
                    ? _buildSuccess(context)
                    : _buildForm(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildForm(BuildContext context) {
    final p = widget.product;
    final submitting = _phase == _Phase.submitting;
    return Column(
      key: const ValueKey('buy_form'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _handle(),
        const SizedBox(height: 18),
        Text(
          'buy_title'.tr(),
          style: appStyle(context,
              size: 20, weight: FontWeight.w800, color: _ink, height: 1.2),
        ),
        const SizedBox(height: 16),
        _summary(context, p),
        const SizedBox(height: 14),
        _contactBlock(context),
        if (_phase == _Phase.error) ...[
          const SizedBox(height: 12),
          _errorBox(context),
        ],
        const SizedBox(height: 20),
        _primaryButton(context, submitting),
        const SizedBox(height: 4),
        TextButton(
          key: const ValueKey('buy_cancel'),
          onPressed: submitting ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            foregroundColor: AppTheme.textSecondary,
          ),
          child: Text(
            'buy_cancel'.tr(),
            style: appStyle(context, size: 14, weight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context, Product p) {
    final discount = p.discountPercent;
    final mrp = p.mrp;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 72,
            height: 72,
            child: SafeNetworkImage(
              imageUrl: p.primaryImage,
              fit: BoxFit.cover,
              width: 72,
              height: 72,
              memCacheWidth: 216,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: appStyle(context,
                    text: p.name,
                    size: 15,
                    weight: FontWeight.w700,
                    color: _ink,
                    height: 1.3),
              ),
              if (p.advertiserName.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  'buy_sold_by'.tr(args: [p.advertiserName]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appStyle(context,
                      text: p.advertiserName,
                      size: 12.5,
                      color: AppTheme.textSecondary),
                ),
              ],
              const SizedBox(height: 6),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    formatShopPrice(p.priceValue),
                    style: appStyle(context,
                        size: 18, weight: FontWeight.w800, color: _ink),
                  ),
                  if (discount != null && mrp != null) ...[
                    Text(
                      formatShopPrice(mrp),
                      style: appStyle(context,
                          size: 13,
                          color: AppTheme.textHint,
                          decoration: TextDecoration.lineThrough),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _greenSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'buy_off'.tr(args: ['$discount']),
                        style: appStyle(context,
                            size: 11.5, weight: FontWeight.w700, color: _green),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contactBlock(BuildContext context) {
    final phone = AuthService.currentUser?.phoneNumber?.trim() ?? '';
    final callText = phone.isEmpty
        ? 'buy_call_you_generic'.tr()
        : 'buy_call_you'.tr(args: [phone]);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _IconDot(icon: Icons.call_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    callText,
                    style: appStyle(context,
                        size: 14,
                        weight: FontWeight.w600,
                        color: _ink,
                        height: 1.35),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _IconDot(icon: Icons.payments_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'buy_pay_note'.tr(),
                    style: appStyle(context,
                        size: 13, color: AppTheme.textSecondary, height: 1.4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _errorBox(BuildContext context) {
    return Container(
      key: const ValueKey('buy_error'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.errorBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.error_outline_rounded,
                size: 20, color: AppTheme.error),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorText(),
              style: appStyle(context,
                  size: 13.5,
                  weight: FontWeight.w600,
                  color: AppTheme.errorText,
                  height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton(BuildContext context, bool submitting) {
    final p = widget.product;
    // Login / missing-seller errors can only repeat themselves, so the primary
    // action is disabled there (the app has no in-sheet login route: LoginScreen
    // replaces the whole stack).
    final dead = _phase == _Phase.error &&
        (_failure == EnquiryFailure.missingSeller ||
            _failure == EnquiryFailure.notLoggedIn);
    final enabled = p.inStock && !submitting && !dead;
    final isRetry = _phase == _Phase.error &&
        _failure != EnquiryFailure.missingSeller &&
        _failure != EnquiryFailure.notLoggedIn;
    final label = !p.inStock
        ? 'buy_out_of_stock'.tr()
        : (isRetry ? 'buy_try_again'.tr() : 'buy_place_order'.tr());
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        key: const ValueKey('buy_primary'),
        onPressed: enabled ? _submit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              submitting ? _green : const Color(0xFFE5E7EB),
          disabledForegroundColor:
              submitting ? Colors.white : AppTheme.textHint,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.4),
              )
            : Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appStyle(context, size: 16, weight: FontWeight.w700),
              ),
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Column(
      key: const ValueKey('buy_success'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _handle(),
        const SizedBox(height: 28),
        Center(
          child: ScaleTransition(
            scale: CurvedAnimation(parent: _check, curve: Curves.elasticOut),
            child: Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: _greenSoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 36),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'buy_success_title'.tr(),
          textAlign: TextAlign.center,
          style: appStyle(context,
              size: 20, weight: FontWeight.w800, color: _ink, height: 1.25),
        ),
        const SizedBox(height: 8),
        Text(
          'buy_success_msg'.tr(),
          textAlign: TextAlign.center,
          style: appStyle(context,
              size: 14, color: AppTheme.textSecondary, height: 1.45),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            key: const ValueKey('buy_done'),
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'buy_done'.tr(),
              style: appStyle(context, size: 16, weight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _IconDot extends StatelessWidget {
  const _IconDot({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 17, color: const Color(0xFF15803D)),
      );
}
