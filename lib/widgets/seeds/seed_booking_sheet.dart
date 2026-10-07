import 'dart:async';

import 'package:cropsync/models/product.dart' show formatShopPrice;
import 'package:cropsync/models/seed_variety.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/farmer_analytics_service.dart';
import 'package:cropsync/theme/app_text.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:cropsync/utils/commodity_translator.dart';
import 'package:cropsync/utils/seed_logic.dart';
import 'package:cropsync/widgets/safe_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Smallest and largest quantity a farmer can book in one request.
const int kSeedMinQuantity = 1;
const int kSeedMaxQuantity = 999;

/// Why a booking request failed.
enum SeedBookingFailure { notLoggedIn, noVendor, network, server, unknown }

/// Typed outcome of `ApiService.createSeedBooking`.
class SeedBookingResult {
  final bool ok;
  final SeedBookingFailure? failure;
  const SeedBookingResult.success()
      : ok = true,
        failure = null;
  const SeedBookingResult.failed(SeedBookingFailure this.failure) : ok = false;

  /// Maps the raw API map (`{success, error}`) to a typed result.
  factory SeedBookingResult.fromMap(Map<String, dynamic>? map) {
    if (map != null && map['success'] == true) {
      return const SeedBookingResult.success();
    }
    if (map != null && map['unknown'] == true) {
      return const SeedBookingResult.failed(SeedBookingFailure.unknown);
    }
    final err = '${map?['error'] ?? ''}'.toLowerCase();
    if (err.contains('no active vendor')) {
      return const SeedBookingResult.failed(SeedBookingFailure.noVendor);
    }
    if (err.startsWith('network error') || err.contains('socketexception')) {
      return const SeedBookingResult.failed(SeedBookingFailure.network);
    }
    return const SeedBookingResult.failed(SeedBookingFailure.server);
  }
}

/// Signature of the call that places the booking (injectable for tests).
typedef SeedBookingFn = Future<SeedBookingResult> Function({
  required String bookingId,
  required String userId,
  required int seedVarietyId,
  required double quantity,
  required double totalPrice,
});

Future<SeedBookingResult> _defaultPlaceBooking({
  required String bookingId,
  required String userId,
  required int seedVarietyId,
  required double quantity,
  required double totalPrice,
}) async =>
    SeedBookingResult.fromMap(await ApiService.createSeedBooking(
      bookingId: bookingId,
      userId: userId,
      seedVarietyId: seedVarietyId,
      quantityKg: quantity,
      totalPrice: totalPrice,
    ));

/// Unit the quantity is counted in: 'kg' (default), 'packet', 'bag' or
/// 'quintal', derived from the raw `price_unit`.
String seedQuantityUnit(String? rawUnit) {
  final k = (rawUnit ?? '').toLowerCase().trim();
  if (k.contains('packet') || k.contains('pack') || k.contains('pouch')) {
    return 'packet';
  }
  if (k.contains('bag')) return 'bag';
  if (k.contains('quintal')) return 'quintal';
  // A bare gram/ml pack size ('per_450g', 'per_500ml') is sold as a packet;
  // plain kilogram units stay 'kg'.
  if (RegExp(r'\d\s*(g|gm|gms|gram|grams|ml|l|ltr|litre|liter)$').hasMatch(k)) {
    return 'packet';
  }
  return 'kg';
}

/// Translated plural label for [seedQuantityUnit] ('kg', 'packets', ...).
String seedQuantityUnitLabel(BuildContext context, String? rawUnit) =>
    context.tr('seedd_unit_${seedQuantityUnit(rawUnit)}');

/// Crop name in the current language (CommodityTranslator first, then the
/// app's translation keys); falls back to the raw name.
String seedCropDisplayName(BuildContext context, String cropName) {
  if (cropName.trim().isEmpty) return cropName;
  final lang = context.locale.languageCode;
  final fromCommodity = CommodityTranslator.getLocalizedName(cropName, lang);
  if (fromCommodity != cropName) return fromCommodity;
  final direct = context.tr(cropName);
  if (direct != cropName) return direct;
  final snake = cropName.toLowerCase().trim().replaceAll(' ', '_');
  final t = context.tr(snake);
  if (t != snake) return t;
  final raw = cropName.toLowerCase().trim();
  final t2 = context.tr(raw);
  if (t2 != raw) return t2;
  return cropName;
}

/// Shows the seed booking confirmation sheet. Resolves to true when the
/// booking request was placed (even if the sheet was dismissed afterwards).
Future<bool> showSeedBookingSheet(
  BuildContext context,
  SeedVariety variety, {
  @visibleForTesting SeedBookingFn? placeBooking,
  @visibleForTesting ImageProvider? debugImageProvider,
}) async {
  var placed = false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Drag-to-dismiss would bypass the PopScope guard; barrier/back/Cancel
    // still work while idle and are blocked while submitting.
    enableDrag: false,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => SeedBookingSheet(
      variety: variety,
      placeBooking: placeBooking,
      debugImageProvider: debugImageProvider,
      onPlaced: () => placed = true,
    ),
  );
  return placed;
}

enum _Phase { idle, submitting, success, error }

class SeedBookingSheet extends StatefulWidget {
  const SeedBookingSheet({
    super.key,
    required this.variety,
    this.placeBooking,
    this.onPlaced,
    this.debugImageProvider,
  });

  final SeedVariety variety;
  final SeedBookingFn? placeBooking;
  final VoidCallback? onPlaced;
  final ImageProvider? debugImageProvider;

  @override
  State<SeedBookingSheet> createState() => _SeedBookingSheetState();
}

class _SeedBookingSheetState extends State<SeedBookingSheet>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF15803D);
  static const _greenSoft = Color(0xFFECFDF3);
  static const _ink = Color(0xFF0F172A);

  /// One id per sheet instance, reused on retry so a repeated request cannot
  /// create a second booking row.
  final String _bookingId = generateSeedBookingId();

  _Phase _phase = _Phase.idle;
  SeedBookingFailure? _failure;
  int _qty = kSeedMinQuantity;
  bool _busy = false; // synchronous double-tap guard
  late final AnimationController _check = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  double get _total => seedBookingTotal(widget.variety.priceValue, _qty);

  @override
  void dispose() {
    _check.dispose();
    super.dispose();
  }

  void _setQty(int q) {
    if (_phase == _Phase.submitting) return;
    final next = q.clamp(kSeedMinQuantity, kSeedMaxQuantity);
    if (next == _qty) return;
    HapticFeedback.selectionClick();
    setState(() => _qty = next);
  }

  Future<void> _submit() async {
    final v = widget.variety;
    if (_busy || !v.isBookable) return;
    _busy = true;
    setState(() {
      _phase = _Phase.submitting;
      _failure = null;
    });

    final qty = _qty;
    final total = seedBookingTotal(v.priceValue, qty);
    final user = AuthService.currentUser;
    SeedBookingResult result;
    if (user == null || user.userId.isEmpty) {
      result = const SeedBookingResult.failed(SeedBookingFailure.notLoggedIn);
    } else {
      final place = widget.placeBooking ?? _defaultPlaceBooking;
      try {
        result = await place(
          bookingId: _bookingId,
          userId: user.userId,
          seedVarietyId: v.id,
          quantity: qty.toDouble(),
          totalPrice: total,
        );
      } catch (_) {
        result = const SeedBookingResult.failed(SeedBookingFailure.server);
      }
    }

    _busy = false;
    if (result.ok) {
      widget.onPlaced?.call();
      try {
        FarmerAnalyticsService.logSeedBooking(
          seedId: v.id,
          varietyName: v.varietyName,
          cropName: v.cropName,
          quantity: qty,
        );
      } catch (_) {}
    }
    if (!mounted) return;

    if (result.ok) {
      HapticFeedback.mediumImpact();
      setState(() => _phase = _Phase.success);
      _check.forward(from: 0);
    } else {
      setState(() {
        _phase = _Phase.error;
        _failure = result.failure ?? SeedBookingFailure.server;
      });
    }
  }

  String _errorText() {
    switch (_failure) {
      case SeedBookingFailure.notLoggedIn:
        return 'seedd_err_login'.tr();
      case SeedBookingFailure.noVendor:
        return 'seedd_err_no_vendor'.tr();
      case SeedBookingFailure.network:
        return 'buy_err_network'.tr();
      case SeedBookingFailure.unknown:
        return 'seedd_err_unknown'.tr();
      case SeedBookingFailure.server:
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
    final submitting = _phase == _Phase.submitting;
    return Column(
      key: const ValueKey('seed_form'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _handle(),
        const SizedBox(height: 18),
        Text(
          'seedd_confirm_title'.tr(),
          style: appStyle(context,
              size: 20, weight: FontWeight.w800, color: _ink, height: 1.4),
        ),
        const SizedBox(height: 16),
        _summary(context),
        const SizedBox(height: 16),
        _quantityRow(context, submitting),
        const SizedBox(height: 12),
        _totalRow(context),
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
          key: const ValueKey('seed_cancel'),
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

  Widget _summary(BuildContext context) {
    final v = widget.variety;
    final lang = context.locale.languageCode;
    final name = v.displayName(lang);
    final crop = seedCropDisplayName(context, v.cropName);
    final img = widget.debugImageProvider;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 72,
          height: 72,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          child: img != null
              ? Image(
                  image: img,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const _SeedPlaceholder(),
                )
              : SafeNetworkImage(
                  imageUrl: v.primaryImage,
                  fit: BoxFit.contain,
                  width: 60,
                  height: 60,
                  memCacheWidth: 180,
                  placeholder: const _SeedPlaceholder(),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: appStyle(context,
                    text: name,
                    size: 15,
                    weight: FontWeight.w700,
                    color: _ink,
                    height: 1.4),
              ),
              if (crop.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  crop,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appStyle(context,
                      text: crop,
                      size: 12.5,
                      color: AppTheme.textSecondary,
                      height: 1.4),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                seedPriceLabel(v, lang),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: appStyle(context,
                    text: seedPriceLabel(v, lang),
                    size: 17,
                    weight: FontWeight.w800,
                    color: _ink,
                    height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quantityRow(BuildContext context, bool submitting) {
    final unit = seedQuantityUnitLabel(context, widget.variety.priceUnit);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        spacing: 12,
        children: [
          Text(
            'seedd_quantity'.tr(),
            style: appStyle(context,
                size: 14, weight: FontWeight.w700, color: _ink, height: 1.4),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepButton(
                key: const ValueKey('seed_minus'),
                icon: Icons.remove_rounded,
                label: 'seedd_decrease'.tr(),
                onTap: !submitting && _qty > kSeedMinQuantity
                    ? () => _setQty(_qty - 1)
                    : null,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '$_qty $unit',
                    key: const ValueKey('seed_qty'),
                    textAlign: TextAlign.center,
                    style: appStyle(context,
                        text: unit,
                        size: 15,
                        weight: FontWeight.w800,
                        color: _ink,
                        height: 1.4),
                  ),
                ),
              ),
              _StepButton(
                key: const ValueKey('seed_plus'),
                icon: Icons.add_rounded,
                label: 'seedd_increase'.tr(),
                onTap: !submitting && _qty < kSeedMaxQuantity
                    ? () => _setQty(_qty + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalRow(BuildContext context) {
    final total = formatShopPrice(_total);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(
            'seedd_total'.tr(),
            style: appStyle(context,
                size: 14,
                weight: FontWeight.w600,
                color: AppTheme.textSecondary,
                height: 1.4),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                total,
                key: const ValueKey('seed_total'),
                maxLines: 1,
                style: appStyle(context,
                    size: 24,
                    weight: FontWeight.w800,
                    color: _ink,
                    height: 1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactBlock(BuildContext context) {
    final phone = AuthService.currentUser?.phoneNumber?.trim() ?? '';
    final callText = phone.isEmpty
        ? 'buy_call_you_generic'.tr()
        : 'buy_call_you'.tr(args: [phone]);
    Widget line(IconData icon, String text, TextStyle style) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconDot(icon: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(text, style: style),
              ),
            ),
          ],
        );
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
          line(
              Icons.call_rounded,
              callText,
              appStyle(context,
                  size: 14, weight: FontWeight.w600, color: _ink, height: 1.4)),
          const SizedBox(height: 10),
          line(
              Icons.payments_outlined,
              'buy_pay_note'.tr(),
              appStyle(context,
                  size: 13, color: AppTheme.textSecondary, height: 1.4)),
        ],
      ),
    );
  }

  Widget _errorBox(BuildContext context) {
    return Container(
      key: const ValueKey('seed_error'),
      padding: const EdgeInsets.all(12),
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
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton(BuildContext context, bool submitting) {
    // Login / no-vendor errors can only repeat themselves.
    final dead = _phase == _Phase.error &&
        (_failure == SeedBookingFailure.noVendor ||
            _failure == SeedBookingFailure.notLoggedIn);
    final enabled = widget.variety.isBookable && !submitting && !dead;
    final isRetry = _phase == _Phase.error && !dead;
    final label = isRetry ? 'buy_try_again'.tr() : 'seedd_confirm_btn'.tr();
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        key: const ValueKey('seed_primary'),
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
      key: const ValueKey('seed_success'),
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
          'seedd_success_title'.tr(),
          textAlign: TextAlign.center,
          style: appStyle(context,
              size: 20, weight: FontWeight.w800, color: _ink, height: 1.4),
        ),
        const SizedBox(height: 8),
        Text(
          'buy_success_msg'.tr(),
          textAlign: TextAlign.center,
          style: appStyle(context,
              size: 14, color: AppTheme.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            key: const ValueKey('seed_done'),
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

class _SeedPlaceholder extends StatelessWidget {
  const _SeedPlaceholder();

  @override
  Widget build(BuildContext context) => const Center(
        child: Icon(Icons.grass_rounded, size: 28, color: Color(0xFFCBD5E1)),
      );
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return Semantics(
      button: true,
      enabled: on,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: on ? Colors.white : const Color(0xFFF1F5F9),
        shape: const CircleBorder(side: BorderSide(color: Color(0xFFE2E8F0))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon,
                size: 22,
                color: on ? const Color(0xFF15803D) : const Color(0xFFCBD5E1)),
          ),
        ),
      ),
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
