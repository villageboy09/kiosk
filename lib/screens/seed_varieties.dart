// lib/screens/seed_varieties.dart

import 'package:cropsync/models/seed_variety.dart';
import 'package:cropsync/screens/seed_variety_detail_screen.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/cache_service.dart';
import 'package:cropsync/services/farmer_analytics_service.dart';
import 'package:cropsync/services/seed_wishlist_store.dart';
import 'package:cropsync/theme/app_text.dart';
import 'package:cropsync/utils/seed_logic.dart';
import 'package:cropsync/widgets/seeds/seed_booking_sheet.dart';
import 'package:cropsync/widgets/seeds/seed_filters_sheet.dart';
import 'package:cropsync/widgets/seeds/seed_variety_card.dart';
import 'package:cropsync/widgets/shop/shop_back_gate.dart';
import 'package:cropsync/widgets/shop/shop_category_style.dart';
import 'package:cropsync/widgets/shop/shop_chrome.dart';
import 'package:cropsync/widgets/shop/shop_discover.dart';
import 'package:cropsync/widgets/shop/shop_filters.dart';
import 'package:cropsync/widgets/shop/shop_product_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

export '../models/seed_variety.dart';
export 'seed_variety_detail_screen.dart';

const String _kAll = 'all_category';

/// Seed varieties: discover home, crop chips, search, filters, wishlist.
class SeedVarietiesScreen extends StatefulWidget {
  /// Raw backend crop name to pre-select.
  final String? initialCrop;

  /// Variety to open (once) after the first load.
  final int? initialVarietyId;

  /// Test-only data source replacing [ApiService.getSeedVarieties].
  @visibleForTesting
  final Future<List<SeedVariety>> Function(String lang, String? userId)?
      debugLoader;

  /// Test-only image provider for every card.
  @visibleForTesting
  final ImageProvider? debugImageProvider;

  const SeedVarietiesScreen({
    super.key,
    this.initialCrop,
    this.initialVarietyId,
    this.debugLoader,
    this.debugImageProvider,
  });

  @override
  State<SeedVarietiesScreen> createState() => _SeedVarietiesScreenState();
}

class _SeedVarietiesScreenState extends State<SeedVarietiesScreen> {
  List<SeedVariety>? _all;
  List<String> _crops = const []; // cropsByCount(_all), cached per load
  bool _loading = true;
  bool _hasLoadedOnce = false;
  Object? _error;
  int _request = 0;

  String _selectedCrop = _kAll;
  String _query = '';
  SeedFilters _filters = const SeedFilters();
  bool _showWishlistOnly = false;
  bool _forceGrid = false;

  Set<int> _wishlist = {};
  Future<void> _wishlistQueue = Future<void>.value();
  int _pendingToggles = 0;
  int? _seenMaxId; // watermark captured on open; null on first run
  Future<void>? _seenFuture;
  bool _deepLinkHandled = false;
  Locale? _lastLocale;

  final TextEditingController _searchController = TextEditingController();

  String get _userKey => SeedWishlistStore.currentKey();
  String get _seenKey => 'seed_seen_max_id_$_userKey';

  @override
  void initState() {
    super.initState();
    final crop = (widget.initialCrop ?? '').trim();
    if (crop.isNotEmpty) _selectedCrop = crop;
    _seenFuture = _captureSeen();
    _wishlistQueue = _loadWishlist();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = context.locale;
    if (_lastLocale != locale) {
      // The API returns the raw crop name in every language, so the current
      // selection stays valid; _resolveCrop handles unknown crops on reload.
      _lastLocale = locale;
      _load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- data

  String get _lang {
    final code = context.locale.languageCode;
    return (code == 'hi' || code == 'te') ? code : 'en';
  }

  Future<void> _captureSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.get(_seenKey);
      _seenMaxId = v is int ? v : null;
    } catch (_) {
      _seenMaxId = null;
    }
    if (mounted) setState(() {});
  }

  Future<void> _persistSeen(List<SeedVariety> items) async {
    try {
      await _seenFuture;
      if (items.isEmpty) return;
      var max = 0;
      for (final v in items) {
        if (v.id > max) max = v.id;
      }
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.get(_seenKey);
      if (stored is! int || max > stored) await prefs.setInt(_seenKey, max);
    } catch (_) {}
  }

  /// Replaces the in-memory wishlist with what the store holds. Skipped while
  /// toggles are still being persisted (their result will sync afterwards).
  Future<void> _loadWishlist() async {
    final ids = await SeedWishlistStore.load(_userKey);
    if (mounted && _pendingToggles == 0) {
      setState(() => _wishlist = ids);
    }
  }

  Future<void> _load({bool refresh = false}) async {
    final request = ++_request;
    final lang = _lang;
    final userId = AuthService.currentUser?.userId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (refresh) {
        CacheService.invalidatePrefix('${CacheKeys.seedVarieties}_$lang');
      }
      final List<SeedVariety> items;
      if (widget.debugLoader != null) {
        items = await widget.debugLoader!(lang, userId);
      } else {
        final raw = await ApiService.getSeedVarieties(
          lang: lang,
          userId: userId,
          throwOnError: true,
        );
        items = raw.map(SeedVariety.fromJson).toList();
      }
      if (!mounted || request != _request) return;
      final list = dedupeSeedVarieties(items);
      setState(() {
        _all = list;
        _crops = cropsByCount(list);
        _loading = false;
        _hasLoadedOnce = true;
        _selectedCrop = _resolveCrop(_selectedCrop, list);
      });
      _persistSeen(list);
      _maybeOpenDeepLink(list);
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = e;
        _loading = false;
      });
      if (_all != null) _showLoadErrorSnack();
    }
  }

  /// Maps a requested crop onto the loaded crop names (case-insensitive);
  /// an unknown crop falls back to "all".
  String _resolveCrop(String crop, List<SeedVariety> list) {
    if (crop == _kAll) return crop;
    final want = crop.trim().toLowerCase();
    for (final c in _crops) {
      if (c.trim().toLowerCase() == want) return c;
    }
    return _kAll;
  }

  void _maybeOpenDeepLink(List<SeedVariety> list) {
    final id = widget.initialVarietyId;
    if (_deepLinkHandled || id == null) return;
    _deepLinkHandled = true;
    final target = list.where((v) => v.id == id).firstOrNull;
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openVariety(target);
    });
  }

  void _showLoadErrorSnack() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(context.tr('seedui_load_error')),
        action: SnackBarAction(
          label: context.tr('shop_retry'),
          onPressed: () => _load(refresh: true),
        ),
      ));
  }

  Future<void> _refresh() => _load(refresh: true);

  // ------------------------------------------------------------- derived

  bool get _filtersActive => _filters.isActive;

  bool get _anythingActive =>
      _filtersActive ||
      _showWishlistOnly ||
      _query.isNotEmpty ||
      _selectedCrop != _kAll;

  bool get _isDiscover =>
      !_forceGrid &&
      !_filtersActive &&
      !_showWishlistOnly &&
      _query.isEmpty &&
      _selectedCrop == _kAll;

  bool get _atHome => _isDiscover && _searchController.text.trim().isEmpty;

  bool _isNew(SeedVariety v) => _seenMaxId != null && v.id > _seenMaxId!;

  List<SeedVariety> _visible() {
    return applySeedFilters(
      _all ?? const <SeedVariety>[],
      filters: _filters,
      query: _query,
      crop: _selectedCrop == _kAll ? null : _selectedCrop,
      wishlistOnly: _showWishlistOnly,
      wishlist: _wishlist,
    );
  }

  // ------------------------------------------------------------- actions

  void _onSearchChanged(String value) {
    setState(() => _query = value.trim());
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _selectCrop(String crop) {
    setState(() {
      _selectedCrop = crop;
      _forceGrid = false;
    });
  }

  void _seeAll(String crop) {
    if (_showWishlistOnly) setState(() => _showWishlistOnly = false);
    _selectCrop(crop);
  }

  void _toggleWishlist(int id) {
    HapticFeedback.selectionClick();
    // Optimistic flip for instant feedback...
    setState(() {
      _wishlist = Set<int>.of(_wishlist);
      if (!_wishlist.remove(id)) _wishlist.add(id);
    });
    // ...then persist through the store, which reads its current value fresh
    // each time (serialised, and after the initial load), and adopt its result.
    final key = _userKey;
    _pendingToggles++;
    _wishlistQueue = _wishlistQueue.then((_) async {
      Set<int>? result;
      try {
        result = await SeedWishlistStore.toggle(key, id);
      } catch (_) {}
      _pendingToggles--;
      if (mounted && _pendingToggles == 0) {
        if (result != null) {
          setState(() => _wishlist = result!);
        } else {
          await _loadWishlist();
        }
      }
    });
  }

  Future<void> _openFilters() async {
    final result = await showSeedFiltersSheet(context, _filters);
    if (result != null && mounted) setState(() => _filters = result);
  }

  void _onBackPressed() {
    if (_atHome) {
      Navigator.maybePop(context);
    } else {
      _backToDiscover();
    }
  }

  void _backToDiscover() {
    FocusManager.instance.primaryFocus?.unfocus();
    _searchController.clear();
    setState(() {
      _filters = const SeedFilters();
      _showWishlistOnly = false;
      _forceGrid = false;
      _selectedCrop = _kAll;
      _query = '';
    });
  }

  Future<void> _openVariety(SeedVariety variety) async {
    FarmerAnalyticsService.logSeedVarietyView(
      seedId: variety.id,
      varietyName: variety.varietyName,
      cropName: variety.cropName,
      price: variety.price,
      averageYield: variety.averageYield,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SeedVarietyDetailScreen(variety: variety),
      ),
    );
    // The detail screen can change the wishlist: pick it up again.
    if (mounted) await _loadWishlist();
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final items = _visible();
    return ShopBackGate(
      atHome: _atHome,
      onBackToHome: _backToDiscover,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: RefreshIndicator(
          color: kShopGreen,
          backgroundColor: Colors.white,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(child: _buildSearchRow()),
              SliverToBoxAdapter(child: _buildChips()),
              if (_filtersActive || _showWishlistOnly)
                SliverToBoxAdapter(child: _buildActiveFilters()),
              ..._buildBody(items),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return buildShopAppBar(
      context,
      title: context.tr('seed_varieties_title'),
      onBack: _onBackPressed,
      trailing: Semantics(
        button: true,
        toggled: _showWishlistOnly,
        label: context.tr('shop_wishlist'),
        child: IconButton(
          tooltip: context.tr('shop_wishlist'),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() {
              _showWishlistOnly = !_showWishlistOnly;
              _forceGrid = false;
            });
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                _showWishlistOnly
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: _showWishlistOnly ? const Color(0xFFE11D48) : kShopInk,
                size: 24,
              ),
              if (_wishlist.isNotEmpty && !_showWishlistOnly)
                Positioned(
                  top: -1,
                  right: -1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE11D48),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchRow() {
    return ShopSearchRow(
      controller: _searchController,
      hint: context.tr('search_seeds_hint'),
      onChanged: _onSearchChanged,
      onSubmitted: _onSearchChanged,
      onFilterTap: _openFilters,
      filterActive: _filtersActive,
      onClear: _clearSearch,
    );
  }

  String _cropLabel(BuildContext context, String raw) => raw == _kAll
      ? context.tr('all_category')
      : seedCropDisplayName(context, raw);

  ShopCategoryStyle _cropStyleOf(String raw) =>
      raw == _kAll ? shopCategoryStyle(_kAll) : cropStyle(raw);

  Widget _buildChips() {
    final crops = _crops;
    // Keep a selected crop visible even if it is not in the loaded list.
    final list = [
      _kAll,
      ...crops,
      if (_selectedCrop != _kAll && !crops.contains(_selectedCrop))
        _selectedCrop,
    ];
    return ShopCategoryChips(
      categories: list,
      selected: _selectedCrop,
      labelOf: _cropLabel,
      styleOf: _cropStyleOf,
      onSelected: _selectCrop,
    );
  }

  Widget _buildActiveFilters() {
    Widget chip(String label, VoidCallback onRemove) => Chip(
          label: Text(
            label,
            style: appStyle(
              context,
              text: label,
              size: 12,
              weight: FontWeight.w600,
              color: kShopGreen,
              height: 1.3,
            ),
          ),
          deleteIcon: const Icon(Icons.close_rounded, size: 16),
          deleteIconColor: kShopGreen,
          onDeleted: onRemove,
          visualDensity: VisualDensity.compact,
          backgroundColor: const Color(0xFFE7F5EE),
          side: BorderSide.none,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Wrap(
          spacing: 8,
          runSpacing: 0,
          children: [
            if (_showWishlistOnly)
              chip(context.tr('shop_wishlist'),
                  () => setState(() => _showWishlistOnly = false)),
            if (_filters.sort != SeedSort.defaultOrder)
              chip(
                seedSortLabel(context, _filters.sort),
                () => setState(() =>
                    _filters = _filters.copyWith(sort: SeedSort.defaultOrder)),
              ),
            if (_filters.bookableOnly)
              chip(
                context.tr('seedui_bookable_only'),
                () => setState(
                    () => _filters = _filters.copyWith(bookableOnly: false)),
              ),
            if (_filters.highYield)
              chip(
                context.tr('seedui_high_yield'),
                () => setState(
                    () => _filters = _filters.copyWith(highYield: false)),
              ),
            if (_filters.shortDuration)
              chip(
                context.tr('seedui_short_duration'),
                () => setState(
                    () => _filters = _filters.copyWith(shortDuration: false)),
              ),
          ],
        ),
      ),
    );
  }

  double _railHeight(double w, double s) =>
      cardExtent(w, s, infoHeight: seedCardInfoHeight(s));

  List<Widget> _buildBody(List<SeedVariety> items) {
    final discover = _isDiscover;
    if (_loading && !_hasLoadedOnce) {
      return [
        discover
            ? SliverToBoxAdapter(
                child: DiscoverSkeleton(railHeight: _railHeight))
            : _buildSkeletonGrid(),
      ];
    }
    if (_error != null && _all == null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _StateMessage(
            icon: Icons.cloud_off_rounded,
            message: context.tr('seedui_load_error'),
            actionLabel: context.tr('shop_retry'),
            onAction: () => _load(refresh: true),
          ),
        ),
      ];
    }
    if (items.isEmpty) {
      final catalogEmpty = (_all ?? const []).isEmpty;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _StateMessage(
            icon: _showWishlistOnly
                ? Icons.favorite_border_rounded
                : Icons.search_off_rounded,
            message: context.tr(_showWishlistOnly
                ? 'seedui_wishlist_empty'
                : 'no_varieties_found'),
            actionLabel: catalogEmpty
                ? context.tr('shop_retry')
                : (_anythingActive ? context.tr('shop_reset') : null),
            onAction: catalogEmpty
                ? () => _load(refresh: true)
                : (_anythingActive ? _backToDiscover : null),
          ),
        ),
      ];
    }
    if (discover) {
      return [SliverToBoxAdapter(child: _buildDiscover(items))];
    }
    return [_buildCount(items.length), _buildGrid(items)];
  }

  Widget _buildDiscover(List<SeedVariety> items) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final crops = _crops;
    final d = buildRails<SeedVariety>(
      items: items,
      categoryOf: (v) => v.cropName,
      idOf: (v) => v.id,
      createdAtOf: (v) => v.createdAt,
      categoryOrder: crops,
    );
    final fresh = d.fresh;
    final more = d.more.take(kShopMoreItems).toList();

    return DiscoverHome<SeedVariety>(
      data: (fresh: fresh, rails: d.rails, more: more),
      idOf: (v) => v.id,
      freshTitle: context.tr('shoph_new_arrivals'),
      moreTitle: context.tr('seedui_more_varieties'),
      railTitleFor: (ctx, crop) => ctx.tr('seedui_rail_varieties',
          namedArgs: {'crop': seedCropDisplayName(ctx, crop)}),
      styleOf: cropStyle,
      onSeeAll: _seeAll,
      onViewAllMore: () => setState(() => _forceGrid = true),
      railHeight: _railHeight,
      itemBuilder: (context, v, cardW) => _card(
        v,
        (cardW * dpr).round().clamp(120, 600),
      ),
    );
  }

  Widget _card(SeedVariety v, int cache) {
    return SeedVarietyCard(
      variety: v,
      displayName: v.displayName(_lang),
      cropLabel: seedCropDisplayName(context, v.cropName),
      lang: _lang,
      isWishlisted: _wishlist.contains(v.id),
      isNew: _isNew(v),
      memCacheWidth: cache,
      debugImageProvider: widget.debugImageProvider,
      onTap: () => _openVariety(v),
      onAction: () =>
          v.isBookable ? showSeedBookingSheet(context, v) : _openVariety(v),
      onToggleWishlist: () => _toggleWishlist(v.id),
    );
  }

  Widget _buildCount(int count) {
    final text =
        context.tr('shoph_items_count', namedArgs: {'count': '$count'});
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(
          text,
          style: appStyle(
            context,
            text: text,
            size: 12.5,
            weight: FontWeight.w500,
            color: const Color(0xFF64748B),
            height: 1.4,
          ),
        ),
      ),
    );
  }

  ({int cols, double cellWidth, double extent}) _metrics(double width) {
    const pad = 16.0, gap = 12.0;
    final avail = width - pad * 2;
    final cols = width > 600 ? (avail ~/ 200).clamp(3, 4) : 2;
    final cell = (avail - gap * (cols - 1)) / cols;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return (
      cols: cols,
      cellWidth: cell,
      extent: cardExtent(cell, scale, infoHeight: seedCardInfoHeight(scale)),
    );
  }

  SliverGridDelegate _delegate(
          ({int cols, double cellWidth, double extent}) m) =>
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: m.cols,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: m.extent,
      );

  Widget _buildGrid(List<SeedVariety> items) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final m = _metrics(constraints.crossAxisExtent);
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final cache = (m.cellWidth * dpr).round().clamp(120, 800);
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverGrid(
            gridDelegate: _delegate(m),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final v = items[i];
                return KeyedSubtree(
                  key: ValueKey('seed_${v.id}'),
                  child: _card(v, cache),
                );
              },
              childCount: items.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonGrid() {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final m = _metrics(constraints.crossAxisExtent);
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverGrid(
            gridDelegate: _delegate(m),
            delegate: SliverChildBuilderDelegate(
              (context, i) => Shimmer.fromColors(
                baseColor: const Color(0xFFEEF2F6),
                highlightColor: const Color(0xFFF8FAFC),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              childCount: m.cols * 3,
            ),
          ),
        );
      },
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StateMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: appStyle(
              context,
              text: message,
              size: 14,
              weight: FontWeight.w600,
              color: const Color(0xFF475569),
              height: 1.4,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: kShopGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(120, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ).copyWith(
                textStyle: WidgetStatePropertyAll(appStyle(
                  context,
                  size: 14,
                  weight: FontWeight.w700,
                )),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
