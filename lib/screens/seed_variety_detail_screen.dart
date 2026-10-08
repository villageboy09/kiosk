import 'package:chewie/chewie.dart';
import 'package:cropsync/models/product.dart' show formatShopPrice;
import 'package:cropsync/models/seed_variety.dart';
import 'package:cropsync/services/seed_wishlist_store.dart';
import 'package:cropsync/services/share_service.dart';
import 'package:cropsync/theme/app_text.dart';
import 'package:cropsync/utils/seed_logic.dart';
import 'package:cropsync/widgets/safe_network_image.dart';
import 'package:cropsync/widgets/seeds/seed_booking_sheet.dart';
import 'package:cropsync/widgets/shop/expandable_paragraphs.dart';
import 'package:cropsync/widgets/shop/shop_category_style.dart';
import 'package:cropsync/widgets/shop/shop_circle_button.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// Result of [parseSeedDetails]: free-text paragraphs plus "Key: value" traits.
class SeedDetailsParts {
  final List<String> paragraphs;
  final List<MapEntry<String, String>> traits;
  const SeedDetailsParts(this.paragraphs, this.traits);
}

/// Splits the backend `details` text into description paragraphs and
/// "Key: value" characteristics. Handles \r\n, blank lines and long single-line
/// texts made of several sentences.
SeedDetailsParts parseSeedDetails(String? details) {
  final paragraphs = <String>[];
  final traits = <MapEntry<String, String>>[];
  final text = (details ?? '').replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final buf = <String>[];
    void flush() {
      if (buf.isNotEmpty) paragraphs.add(buf.join(' '));
      buf.clear();
    }

    for (final seg in line.split(RegExp(r'(?<=[.!?।])\s+'))) {
      final s = seg.trim();
      if (s.isEmpty) continue;
      final i = s.indexOf(':');
      if (i > 0 && i <= 40) {
        final key = s.substring(0, i).trim();
        final val = s
            .substring(i + 1)
            .replaceAll(RegExp(r'^[\s:]+'), '')
            .replaceAll(RegExp(r'\.+$'), '')
            .trim();
        if (val.isEmpty &&
            key.isNotEmpty &&
            key.split(RegExp(r'\s+')).length <= 5) {
          continue; // "Key:" with no value: nothing to show
        }
        if (key.isNotEmpty &&
            val.isNotEmpty &&
            !val.startsWith('//') &&
            key.split(RegExp(r'\s+')).length <= 5) {
          flush();
          traits.add(MapEntry(key, val));
          continue;
        }
      }
      buf.add(s);
    }
    flush();
  }
  return SeedDetailsParts(paragraphs, traits);
}

String _trRegion(BuildContext context, String region) {
  if (region.trim().isEmpty) return region;
  final direct = context.tr(region);
  if (direct != region) return direct;
  final key = region.toLowerCase().trim().replaceAll(' ', '_');
  final t = context.tr(key);
  return t != key ? t : region;
}

String _trSowing(BuildContext context, String period) {
  if (period.trim().isEmpty) return period;
  final direct = context.tr(period);
  if (direct != period) return direct;
  final key =
      period.toLowerCase().trim().replaceAll(' ', '_').replaceAll('-', '_');
  final t = context.tr(key);
  return t != key ? t : period;
}

String _fmtNum(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

class SeedVarietyDetailScreen extends StatefulWidget {
  final SeedVariety variety;

  /// Skips network video initialisation (tests).
  @visibleForTesting
  final bool debugSkipVideo;

  /// Image shown instead of the network image (tests).
  @visibleForTesting
  final ImageProvider? debugImageProvider;

  const SeedVarietyDetailScreen({
    super.key,
    required this.variety,
    this.debugSkipVideo = false,
    this.debugImageProvider,
  });

  @override
  State<SeedVarietyDetailScreen> createState() =>
      _SeedVarietyDetailScreenState();
}

class _SeedVarietyDetailScreenState extends State<SeedVarietyDetailScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  final PageController _pageController = PageController();
  final ValueNotifier<int> _currentPage = ValueNotifier<int>(0);
  bool _wished = false;
  late final String _userKey = SeedWishlistStore.currentKey();

  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _brand = Color(0xFF15803D);
  static const double _gutter = 20;
  static const double _barHeight = 76;
  static const double _overlap = 28;
  static const double _maxContentWidth = 640;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != 1) _pauseVideo(); // the video is the last (second) page
      _currentPage.value = page;
    });
    _loadWish();
    if (widget.variety.hasVideo && !widget.debugSkipVideo) _initVideo();
  }

  Future<void> _loadWish() async {
    final ids = await SeedWishlistStore.load(_userKey);
    if (!mounted) return;
    final wished = ids.contains(widget.variety.id);
    if (wished != _wished) setState(() => _wished = wished);
  }

  Future<void> _toggleWish() async {
    HapticFeedback.selectionClick();
    setState(() => _wished = !_wished);
    try {
      final ids = await SeedWishlistStore.toggle(_userKey, widget.variety.id);
      if (!mounted) return;
      final actual = ids.contains(widget.variety.id);
      if (actual != _wished) setState(() => _wished = actual);
    } catch (_) {
      if (mounted) setState(() => _wished = !_wished);
    }
  }

  Future<void> _initVideo() async {
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.variety.testimonialVideoUrl!.trim()),
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
        aspectRatio: controller.value.aspectRatio > 0
            ? controller.value.aspectRatio
            : 16 / 9,
        materialProgressColors: ChewieProgressColors(
          playedColor: _brand,
          handleColor: _brand,
          bufferedColor: const Color(0xFFCBD5E1),
          backgroundColor: const Color(0xFFE2E8F0),
        ),
        errorBuilder: (context, message) => Center(
          child: Text(
            context.tr('video_unavailable'),
            style:
                appStyle(context, color: Colors.white, weight: FontWeight.w700),
          ),
        ),
      );
      setState(() {});
    } catch (_) {
      // Video failed: release it; the image remains.
      await controller?.dispose();
    }
  }

  void _pauseVideo() {
    final c = _videoController;
    if (c != null && c.value.isInitialized && c.value.isPlaying) c.pause();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pauseVideo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chewieController?.dispose();
    _videoController?.dispose();
    _pageController.dispose();
    _currentPage.dispose();
    super.dispose();
  }

  bool get _videoReady =>
      _chewieController != null &&
      _videoController != null &&
      _videoController!.value.isInitialized;

  String get _lang => context.locale.languageCode;

  String _regionText() {
    final v = widget.variety;
    String? pick(String? s) => (s ?? '').trim().isEmpty ? null : s!.trim();
    final byLang = switch (_lang) {
      'en' => pick(v.regionEn),
      'te' => pick(v.regionTe),
      'hi' => pick(v.regionHi),
      _ => null,
    };
    if (byLang != null) return byLang;
    final raw = pick(v.region);
    if (raw == null) return '';
    return raw
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => _trRegion(context, s))
        .join(', ');
  }

  String _sowingText() {
    final v = widget.variety;
    String? pick(String? s) => (s ?? '').trim().isEmpty ? null : s!.trim();
    final byLang = switch (_lang) {
      'en' => pick(v.sowingPeriodEn),
      'te' => pick(v.sowingPeriodTe),
      'hi' => pick(v.sowingPeriodHi),
      _ => null,
    };
    if (byLang != null) return byLang;
    final raw = pick(v.sowingPeriod);
    return raw == null ? '' : _trSowing(context, raw);
  }

  Future<void> _book() async {
    HapticFeedback.selectionClick();
    _pauseVideo();
    await showSeedBookingSheet(context, widget.variety);
  }

  String _shareTitle(SeedVariety v) {
    final crop = seedCropDisplayName(context, v.cropName).trim();
    final name = v.displayName(_lang);
    return crop.isEmpty ? name : '$name ($crop)';
  }

  void _share() {
    HapticFeedback.lightImpact();
    final v = widget.variety;
    final price = seedPriceLabel(v, _lang);
    ShareService.shareItem(
      context: context,
      type: 'seed',
      id: v.id.toString(),
      crop: v.cropName,
      title: _shareTitle(v),
      price: price.isEmpty ? null : price,
      description: (v.details ?? '').trim().isEmpty ? null : v.details,
      imageUrl: v.primaryImage.isEmpty ? null : v.primaryImage,
    );
  }

  (Color, Color) get _gradient {
    final st = cropStyle(widget.variety.cropName);
    return (st.tint, Color.lerp(st.tint, st.accent, 0.14)!);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final heroH = (media.size.height * 0.46).clamp(280.0, 480.0);
    final bookable = widget.variety.isBookable;
    final scrollBottom =
        (bookable ? _barHeight : 0) + media.padding.bottom + 16;

    if (media.size.width >= 900 && media.size.width > media.size.height) {
      return _buildLandscape(media, bookable);
    }

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
          if (bookable)
            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),
        ],
      ),
    );
  }

  /// Landscape tablets: image on the left, details + booking bar on the right.
  Widget _buildLandscape(MediaQueryData media, bool bookable) {
    final heroWidth = media.size.width * 0.5;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Row(
            children: [
              SizedBox(
                width: heroWidth,
                height: media.size.height,
                child: _buildHero(media.size.height, overlap: 0),
              ),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(top: media.padding.top),
                        child: _buildContentCard(landscape: true),
                      ),
                    ),
                    if (bookable) _buildBottomBar(),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            width: heroWidth,
            child: _buildTopBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, topPadding + 8, 12, 6),
      child: Row(
        children: [
          ShopCircleButton(
            icon: Icons.arrow_back_rounded,
            label: context.tr('shopd_back'),
            onTap: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          ShopCircleButton(
            icon: Icons.ios_share_rounded,
            label: context.tr('shopd_share'),
            onTap: _share,
          ),
          const SizedBox(width: 10),
          _WishButton(
            key: const ValueKey('seed_wish'),
            wished: _wished,
            label: context.tr(
                _wished ? 'shop_remove_from_wishlist' : 'shop_add_to_wishlist'),
            onTap: _toggleWish,
          ),
        ],
      ),
    );
  }

  /// The product photo sits directly on the hero backdrop: no tile, border or
  /// shadow. White photo backgrounds are multiplied into the tinted gradient so
  /// they blend instead of showing as a white rectangle.
  Widget _heroImage(double width, double height) {
    final v = widget.variety;
    final style = cropStyle(v.cropName);
    final placeholder = Center(
      child: Icon(style.icon,
          size: height * 0.3, color: style.accent.withValues(alpha: 0.35)),
    );
    final img = widget.debugImageProvider;
    return _MultiplyBlend(
      child: SizedBox(
        key: const ValueKey('seed_hero_image'),
        width: width,
        height: height,
        child: img != null
            ? Image(
                image: img,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => placeholder,
              )
            : SafeNetworkImage(
                imageUrl: v.primaryImage,
                fit: BoxFit.contain,
                placeholder: placeholder,
              ),
      ),
    );
  }

  BoxDecoration get _heroBackdrop {
    final tint = _gradient;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(Colors.white, tint.$1, 0.7)!, tint.$2],
      ),
    );
  }

  Widget _buildHero(double heroH, {double overlap = _overlap}) {
    final media = MediaQuery.of(context);
    final video = _videoReady;
    final pageCount = video ? 2 : 1;
    final topInset = media.padding.top + 60;

    return Container(
      height: heroH,
      width: double.infinity,
      decoration: _heroBackdrop,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            key: const ValueKey('seed_hero_pages'),
            controller: _pageController,
            itemCount: pageCount,
            itemBuilder: (context, index) {
              if (video && index == 1) {
                return Padding(
                  padding: EdgeInsets.only(top: topInset, bottom: overlap),
                  child: Chewie(controller: _chewieController!),
                );
              }
              // The page paints its own backdrop: PageView pages are separate
              // repaint boundaries, and the multiply blend needs it beneath.
              return DecoratedBox(
                decoration: _heroBackdrop,
                child: LayoutBuilder(builder: (context, c) {
                  final h = (c.maxHeight - media.padding.top - 24 - overlap - 8)
                      .clamp(120.0, 520.0);
                  final w = (c.maxWidth - 32).clamp(120.0, 560.0);
                  return Padding(
                    padding: EdgeInsets.only(
                        top: media.padding.top + 24, bottom: overlap + 8),
                    child: Center(child: _heroImage(w, h)),
                  );
                }),
              );
            },
          ),
          if (pageCount > 1)
            Positioned(
              right: 16,
              bottom: overlap + 12,
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

  Widget _buildContentCard({bool landscape = false}) {
    final v = widget.variety;
    final lang = _lang;
    final name = v.displayName(lang);
    final secondary = (v.varietyNameSecondary ?? '').trim();
    final crop = seedCropDisplayName(context, v.cropName).trim();
    final tint = _gradient;
    final label = seedPriceLabel(v, lang);
    final parts = parseSeedDetails(v.details);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: landscape
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(_overlap)),
      ),
      padding: const EdgeInsets.fromLTRB(_gutter, 22, _gutter, 8),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (crop.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(crop, tint.$2.withValues(alpha: 0.7), _ink),
                  ],
                ),
              if (crop.isNotEmpty) const SizedBox(height: 12),
              Text(
                name,
                style: appStyle(context,
                    text: name,
                    size: 23,
                    weight: FontWeight.w800,
                    color: _ink,
                    height: 1.4),
              ),
              if (secondary.isNotEmpty && secondary != name) ...[
                const SizedBox(height: 2),
                Text(
                  secondary,
                  style: appStyle(context,
                      text: secondary,
                      size: 14,
                      weight: FontWeight.w600,
                      color: _muted,
                      height: 1.4),
                ),
              ],
              const SizedBox(height: 14),
              if (v.isBookable)
                Text(
                  label,
                  key: const ValueKey('seed_price'),
                  style: appStyle(context,
                      text: label,
                      size: 28,
                      weight: FontWeight.w800,
                      color: _ink,
                      height: 1.3),
                )
              else
                _buildNoPrice(),
              ..._buildFacts(),
              ..._buildAbout(parts),
              ..._buildTraits(parts),
              const SizedBox(height: 20),
              _buildNote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoPrice() {
    return Container(
      key: const ValueKey('seed_no_price'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.sell_outlined, size: 18, color: _muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr('seedd_price_na'),
              style: appStyle(context,
                  size: 14,
                  weight: FontWeight.w600,
                  color: _muted,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: appStyle(context,
            text: text,
            size: 12.5,
            weight: FontWeight.w700,
            color: fg,
            height: 1.4),
      ),
    );
  }

  Widget _sectionTitle(String key) => Text(
        context.tr(key),
        style: appStyle(context,
            size: 17, weight: FontWeight.w800, color: _ink, height: 1.4),
      );

  List<Widget> _buildFacts() {
    final v = widget.variety;
    final rows = <(IconData, String, String)>[
      if (_sowingText().isNotEmpty)
        (
          Icons.calendar_month_outlined,
          context.tr('seedd_sowing'),
          _sowingText()
        ),
      if ((v.growthDuration ?? 0) > 0)
        (
          Icons.schedule_rounded,
          context.tr('seedd_duration'),
          '${v.growthDuration} ${context.tr('days')}'
        ),
      if ((v.averageYield ?? 0) > 0)
        (
          Icons.trending_up_rounded,
          context.tr('seedd_yield'),
          '${_fmtNum(v.averageYield!)} ${context.tr('quintals_per_acre_short')}'
        ),
      if (_regionText().isNotEmpty)
        (Icons.place_outlined, context.tr('seedd_region'), _regionText()),
    ];
    if (rows.isEmpty) return const [];
    return [
      const SizedBox(height: 22),
      _kvTable(const ValueKey('seed_facts'), rows),
    ];
  }

  /// Two-column table: parameter (muted, left, 42%) | value (bold, left, 58%).
  /// Fixed flex columns keep every row's label and value at the same x.
  Widget _kvTable(Key key, List<(IconData?, String, String)> rows) {
    const border = BorderSide(color: Color(0xFFE2E8F0));
    // The outer border is a foreground decoration so it paints above the row
    // fills (which would otherwise square off the rounded corners and hide the
    // edges), and uses a darker line than the row dividers so it stays visible.
    return Container(
      key: key,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(42),
          1: FlexColumnWidth(58),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        border: const TableBorder(horizontalInside: border),
        children: [
          for (var i = 0; i < rows.length; i++)
            TableRow(
              key: ValueKey('seed_kv_row_$i'),
              decoration: BoxDecoration(
                color: i.isOdd ? const Color(0xFFF8FAFC) : Colors.white,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (rows[i].$1 != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(rows[i].$1, size: 16, color: _brand),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          rows[i].$2,
                          key: ValueKey('seed_kv_label_$i'),
                          style: appStyle(context,
                              text: rows[i].$2,
                              size: 13,
                              color: _muted,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 13, 14, 13),
                  child: Text(
                    rows[i].$3,
                    key: ValueKey('seed_kv_value_$i'),
                    textAlign: TextAlign.left,
                    style: appStyle(context,
                        text: rows[i].$3,
                        size: 14.5,
                        weight: FontWeight.w600,
                        color: _ink,
                        height: 1.4),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _buildAbout(SeedDetailsParts parts) {
    if (parts.paragraphs.isEmpty) return const [];
    return [
      const SizedBox(height: 24),
      _sectionTitle('seedd_about'),
      const SizedBox(height: 10),
      ExpandableParagraphs(paragraphs: parts.paragraphs),
    ];
  }

  List<Widget> _buildTraits(SeedDetailsParts parts) {
    final rows = [
      for (final t in parts.traits)
        if (t.key.trim().isNotEmpty && t.value.trim().isNotEmpty)
          (null as IconData?, t.key, t.value),
    ];
    if (rows.isEmpty) return const [];
    return [
      const SizedBox(height: 24),
      _sectionTitle('seedd_traits'),
      const SizedBox(height: 10),
      _kvTable(const ValueKey('seed_traits'), rows),
    ];
  }

  Widget _buildNote() {
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
              context.tr('seedd_note'),
              style: appStyle(context, size: 12.5, color: _muted, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final v = widget.variety;
    final unit = localizedPriceUnit(v.priceUnit, _lang);

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
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatShopPrice(v.priceValue),
                            key: const ValueKey('seed_bar_price'),
                            maxLines: 1,
                            style: appStyle(context,
                                size: 24,
                                weight: FontWeight.w800,
                                color: _ink,
                                height: 1.2),
                          ),
                        ),
                        if (unit.isNotEmpty)
                          Text(
                            unit,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: appStyle(context,
                                text: unit,
                                size: 12,
                                color: _muted,
                                height: 1.3),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Semantics(
                      button: true,
                      excludeSemantics: true,
                      label: context.tr('seedd_book_now'),
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          key: const ValueKey('seed_book_now'),
                          onPressed: _book,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brand,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shopping_bag_outlined, size: 20),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  context.tr('seedd_book_now'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: appStyle(context,
                                      size: 16, weight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
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

/// Circular heart toggle matching [ShopCircleButton]'s look.
class _WishButton extends StatelessWidget {
  const _WishButton({
    super.key,
    required this.wished,
    required this.label,
    required this.onTap,
  });

  final bool wished;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: wished,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        textStyle: appStyle(context, size: 12, color: Colors.white),
        child: Material(
          color: Colors.white.withValues(alpha: 0.82),
          shape: const CircleBorder(),
          elevation: 1.5,
          shadowColor: Colors.black26,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 46,
              height: 46,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (c, a) =>
                    ScaleTransition(scale: a, child: c),
                child: Icon(
                  wished
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  key: ValueKey(wished),
                  size: 22,
                  color: wished
                      ? const Color(0xFFE11D48)
                      : const Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints [child] with BlendMode.multiply onto whatever is already painted
/// beneath it, so white photo backgrounds take on the backdrop colour.
class _MultiplyBlend extends SingleChildRenderObjectWidget {
  const _MultiplyBlend({required Widget child}) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMultiplyBlend();
}

class _RenderMultiplyBlend extends RenderProxyBox {
  @override
  void paint(PaintingContext context, Offset offset) {
    final rect = offset & size;
    context.canvas.saveLayer(rect, Paint()..blendMode = BlendMode.multiply);
    super.paint(context, offset);
    context.canvas.restore();
  }
}
