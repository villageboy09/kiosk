// lib/screens/agri_shop.dart

import 'dart:async';

import 'package:cropsync/models/product.dart';
import 'package:cropsync/models/shop_banner.dart';
import 'package:cropsync/screens/product_details_screen.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/farmer_analytics_service.dart';
import 'package:cropsync/services/shop_visit_tracker.dart';
import 'package:cropsync/theme/app_text.dart';
import 'package:cropsync/widgets/shop/buy_now_sheet.dart';
import 'package:cropsync/widgets/shop/shop_back_gate.dart';
import 'package:cropsync/widgets/shop/shop_banner_carousel.dart';
import 'package:cropsync/widgets/shop/shop_chrome.dart';
import 'package:cropsync/widgets/shop/shop_category_style.dart';
import 'package:cropsync/widgets/shop/shop_discover.dart';
import 'package:cropsync/widgets/shop/shop_filters.dart';
import 'package:cropsync/widgets/shop/shop_product_card.dart';
import 'package:cropsync/widgets/shop_whats_new_sheet.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

export '../models/product.dart';
export '../widgets/shop/shop_back_gate.dart';

/// Localizes category names (e.g. 'మెషీన్', 'Machinery', 'Tools', 'పనిముట్లు')
String getLocalizedCategory(BuildContext context, String category) {
  if (category == 'all_category') return context.tr('all_category');

  // 1. Direct translation
  final direct = context.tr(category);
  if (direct != category) return direct;

  // 2. Normalized snake_case
  final key =
      category.toLowerCase().trim().replaceAll(' ', '_').replaceAll('/', '_');
  final normTr = context.tr(key);
  if (normTr != key) return normTr;

  return category;
}

/// Localizes product names (e.g. 'Chaff Cutter', 'ఛాఫ్ కట్టర్', 'Sprayer')
String getLocalizedProductName(BuildContext context, String name) {
  if (name.trim().isEmpty) return name;

  // 1. Direct translation
  final direct = context.tr(name);
  if (direct != name) return direct;

  // 2. Normalized snake_case
  final key = name.toLowerCase().trim().replaceAll(' ', '_');
  final normTr = context.tr(key);
  if (normTr != key) return normTr;

  return name;
}

class AgriShopScreen extends StatefulWidget {
  const AgriShopScreen({super.key});

  @override
  State<AgriShopScreen> createState() => _AgriShopScreenState();
}

class _AgriShopScreenState extends State<AgriShopScreen> {
  static const _searchDebounce = Duration(milliseconds: 400);

  List<Product>? _products;
  List<String> _categories = const ['all_category'];
  List<ShopBanner> _banners = const [];
  bool _isLoadingProducts = true;
  bool _hasLoadedOnce = false;
  Object? _error;

  String _appliedSearch = '';
  String _selectedCategory = 'all_category';
  ShopFilters _filters = const ShopFilters();
  bool _showWishlistOnly = false;
  bool _forceGrid = false; // 'See all' on the discover 'More products' rail
  String _loadedKey = '|'; // category|search the current _products belong to
  String _inflightKey = ''; // key of the request currently loading

  Set<int> _wishlist = {};
  int? _seenProductId; // captured once on open, before anything marks seen
  Future<void>? _seenFuture;
  bool _whatsNewTriggered = false;
  int _productsRequest = 0;
  int _categoriesRequest = 0;
  int _bannersRequest = 0;
  bool _resolvingBanner = false;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  Locale? _lastLocale;

  String get _userKey => ShopVisitTracker.currentUserKey();
  String get _wishlistKey => 'shop_wishlist_$_userKey';

  @override
  void initState() {
    super.initState();
    _seenFuture = _captureSeen();
    _loadWishlist();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = context.locale;
    if (_lastLocale != locale) {
      _lastLocale = locale;
      _selectedCategory = 'all_category';
      _loadCategories();
      _loadProducts();
      _loadBanners();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- data

  Future<void> _captureSeen() async {
    try {
      final seen = await ShopVisitTracker.load(_userKey);
      _seenProductId = seen.isFirstRun ? null : seen.productId;
    } catch (_) {
      _seenProductId = null;
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadWishlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = (prefs.getStringList(_wishlistKey) ?? const [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();
      if (mounted && ids.isNotEmpty) {
        setState(() => _wishlist = {..._wishlist, ...ids});
      }
    } catch (_) {}
  }

  Future<void> _saveWishlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _wishlistKey,
        _wishlist.map((e) => e.toString()).toList(),
      );
    } catch (_) {}
  }

  String get _lang {
    final code = context.locale.languageCode;
    return (code == 'hi' || code == 'te') ? code : 'en';
  }

  Future<void> _loadCategories() async {
    final request = ++_categoriesRequest;
    try {
      final cats = await ApiService.getProductCategories(lang: _lang);
      if (mounted && request == _categoriesRequest) {
        setState(() => _categories = ['all_category', ...cats]);
      }
    } catch (_) {
      if (mounted && request == _categoriesRequest) {
        setState(() => _categories = const ['all_category']);
      }
    }
  }

  Future<void> _loadBanners() async {
    final request = ++_bannersRequest;
    final banners = await ApiService.getShopBanners(lang: _lang);
    if (mounted && request == _bannersRequest) {
      setState(() => _banners = banners);
    }
  }

  Future<void> _loadProducts() async {
    final request = ++_productsRequest;
    final key = '$_selectedCategory|$_appliedSearch';
    _inflightKey = key;
    setState(() {
      _isLoadingProducts = true;
      _error = null;
    });
    try {
      final noDescription = context.tr('no_description');
      final unknownSeller = context.tr('unknown_seller');
      final response = await ApiService.getProducts(
        lang: _lang,
        category:
            _selectedCategory == 'all_category' ? null : _selectedCategory,
        search: _appliedSearch.isEmpty ? null : _appliedSearch,
        userId: AuthService.currentUser?.userId,
      );
      if (!mounted || request != _productsRequest) return;
      final products = response
          .map((p) => Product.fromJson(
                p,
                noDescription: noDescription,
                unknownSeller: unknownSeller,
              ))
          .toList();
      setState(() {
        _products = products;
        _loadedKey = key;
        _isLoadingProducts = false;
        _hasLoadedOnce = true;
      });
      _maybeShowWhatsNew();
    } catch (e) {
      if (!mounted || request != _productsRequest) return;
      setState(() {
        _error = e;
        _isLoadingProducts = false;
      });
      if (_products != null) _showLoadErrorSnack();
    }
  }

  void _showLoadErrorSnack() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(context.tr('shop_load_error')),
        action: SnackBarAction(
          label: context.tr('shop_retry'),
          onPressed: _loadProducts,
        ),
      ));
  }

  void _maybeShowWhatsNew() {
    if (_whatsNewTriggered) return;
    _whatsNewTriggered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _seenFuture; // make sure "new" ids were captured first
      if (!mounted) return;
      unawaited(maybeShowShopWhatsNew(context));
    });
  }

  Future<void> _refresh() =>
      Future.wait([_loadCategories(), _loadProducts(), _loadBanners()]);

  // ------------------------------------------------------------- derived

  bool get _filtersActive => _filters.isActive;

  bool get _anythingActive =>
      _filtersActive ||
      _showWishlistOnly ||
      _appliedSearch.isNotEmpty ||
      _selectedCategory != 'all_category';

  bool get _isDiscover =>
      !_forceGrid &&
      !_filtersActive &&
      !_showWishlistOnly &&
      _appliedSearch.isEmpty &&
      _selectedCategory == 'all_category';

  bool _isNew(Product p) => _seenProductId != null && p.id > _seenProductId!;

  List<Product> _visibleProducts() {
    var list = List<Product>.from(_products ?? const <Product>[]);
    if (_showWishlistOnly) {
      list = list.where((p) => _wishlist.contains(p.id)).toList();
    }
    double price(Product p) => p.priceValue;
    switch (_filters.price) {
      case ShopPrice.all:
        break;
      case ShopPrice.under500:
        list = list.where((p) => price(p) < 500).toList();
      case ShopPrice.mid:
        list = list.where((p) => price(p) >= 500 && price(p) <= 2000).toList();
      case ShopPrice.above2000:
        list = list.where((p) => price(p) > 2000).toList();
    }
    switch (_filters.sort) {
      case ShopSort.defaultOrder:
        break;
      case ShopSort.priceAsc:
        list.sort((a, b) => price(a).compareTo(price(b)));
      case ShopSort.priceDesc:
        list.sort((a, b) => price(b).compareTo(price(a)));
      case ShopSort.newest:
        list.sort((a, b) {
          final da = a.createdAt, db = b.createdAt;
          if (da != null && db != null) {
            final c = db.compareTo(da);
            if (c != 0) return c;
          }
          return b.id.compareTo(a.id);
        });
    }
    return list;
  }

  // ------------------------------------------------------------- actions

  void _onSearchChanged(String value) {
    setState(() {}); // clear icon + banner visibility
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () => _applySearch(value));
  }

  void _applySearch(String value) {
    final q = value.trim();
    if (q == _appliedSearch || (q.length == 1)) return;
    _appliedSearch = q;
    _loadProducts();
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {});
    if (_appliedSearch.isNotEmpty) {
      _appliedSearch = '';
      _loadProducts();
    }
  }

  void _selectCategory(String category) {
    if (category == _selectedCategory) {
      if (_forceGrid) setState(() => _forceGrid = false);
      return;
    }
    setState(() {
      _selectedCategory = category;
      _forceGrid = false;
    });
    _loadProducts();
  }

  void _toggleWishlist(int id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_wishlist.remove(id)) _wishlist.add(id);
    });
    _saveWishlist();
  }

  Future<void> _openFilters() async {
    final result = await showShopFilterSheet(context, _filters);
    if (result != null && mounted) setState(() => _filters = result);
  }

  /// Back navigation: anywhere but the discover home (or with text in the
  /// search field) first returns to discover; only discover leaves the screen.
  bool get _atShopHome => _isDiscover && _searchController.text.trim().isEmpty;

  void _onBackPressed() {
    if (_atShopHome) {
      Navigator.maybePop(context);
    } else {
      _backToDiscover();
    }
  }

  void _backToDiscover() {
    FocusManager.instance.primaryFocus?.unfocus();
    _resetAll();
  }

  void _resetAll({bool reload = true}) {
    _debounce?.cancel();
    _searchController.clear();
    // Refetch only if the loaded (or in-flight) data is not the unfiltered
    // "all" list; otherwise discover reuses it without a network call.
    const allKey = 'all_category|';
    final allInFlight = _isLoadingProducts && _inflightKey == allKey;
    final allLoaded =
        _loadedKey == allKey && !(_isLoadingProducts && _inflightKey != allKey);
    final needsReload = !(allInFlight || allLoaded);
    setState(() {
      _filters = const ShopFilters();
      _showWishlistOnly = false;
      _forceGrid = false;
      _selectedCategory = 'all_category';
      _appliedSearch = '';
    });
    if (reload && needsReload) _loadProducts();
  }

  void _openProduct(Product product) {
    FarmerAnalyticsService.logShopItemView(
      productId: product.id,
      productName: product.name,
      category: product.category,
      price: product.price,
      advertiserName: product.advertiserName,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: product)),
    );
  }

  void _buyNow(Product product) {
    showBuyNowSheet(context, product);
  }

  void _seeAll(String category) {
    if (_showWishlistOnly) setState(() => _showWishlistOnly = false);
    _selectCategory(category);
  }

  Future<void> _onBannerTap(ShopBanner banner) async {
    final value = banner.targetValue.trim();
    if (value.isEmpty) return;
    switch (banner.targetType) {
      case ShopBannerTarget.none:
        return;
      case ShopBannerTarget.category:
        final match = _matchCategory(value);
        if (match != null) {
          if (_showWishlistOnly) setState(() => _showWishlistOnly = false);
          _selectCategory(match);
        }
      case ShopBannerTarget.product:
        final id = int.tryParse(value);
        if (id == null) return;
        await _openProductById(id);
      case ShopBannerTarget.url:
        final uri = Uri.tryParse(value);
        if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return;
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
    }
  }

  /// Opens product [id]; if it is not in the currently loaded (possibly
  /// filtered) list, resets filters, reloads unfiltered and looks again.
  Future<void> _openProductById(int id) async {
    Product? find() {
      for (final p in _products ?? const <Product>[]) {
        if (p.id == id) return p;
      }
      return null;
    }

    var found = find();
    if (found == null) {
      if (_resolvingBanner) return;
      _resolvingBanner = true;
      try {
        _resetAll(reload: false);
        await _loadProducts();
        if (!mounted) return;
        found = find();
      } finally {
        _resolvingBanner = false;
      }
    }
    if (!mounted) return;
    if (found != null) {
      _openProduct(found);
    } else {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text(context.tr('no_products_found'))));
    }
  }

  String? _matchCategory(String value) {
    final v = value.toLowerCase().trim();
    for (final c in _categories) {
      if (c == 'all_category') continue;
      if (c.toLowerCase().trim() == v ||
          getLocalizedCategory(context, c).toLowerCase().trim() == v) {
        return c;
      }
    }
    return null;
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final products = _visibleProducts();
    final searching = _searchController.text.trim().isNotEmpty;
    final showBanner = !searching && !_showWishlistOnly && _banners.isNotEmpty;

    return ShopBackGate(
        atHome: _atShopHome,
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
                if (showBanner)
                  SliverToBoxAdapter(
                    child: Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 820),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ShopBannerCarousel(
                                banners: _banners,
                                onTap: _onBannerTap,
                              ),
                            ))),
                  ),
                SliverToBoxAdapter(
                  child: ShopCategoryChips(
                    categories: _categories,
                    selected: _selectedCategory,
                    labelOf: getLocalizedCategory,
                    onSelected: _selectCategory,
                  ),
                ),
                if (_filtersActive || _showWishlistOnly)
                  SliverToBoxAdapter(child: _buildActiveFilters()),
                ..._buildBody(products),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ));
  }

  Widget _buildAppBar() {
    return buildShopAppBar(
      context,
      title: context.tr('crop_sync_market'),
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
            setState(() => _showWishlistOnly = !_showWishlistOnly);
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
      hint: context.tr('search_products'),
      onChanged: _onSearchChanged,
      onSubmitted: (v) {
        _debounce?.cancel();
        _applySearch(v);
      },
      onFilterTap: _openFilters,
      filterActive: _filtersActive,
      onClear: _clearSearch,
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
            if (_filters.sort != ShopSort.defaultOrder)
              chip(
                shopSortLabel(context, _filters.sort),
                () => setState(() =>
                    _filters = _filters.copyWith(sort: ShopSort.defaultOrder)),
              ),
            if (_filters.price != ShopPrice.all)
              chip(
                shopPriceLabel(context, _filters.price),
                () => setState(
                    () => _filters = _filters.copyWith(price: ShopPrice.all)),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBody(List<Product> products) {
    final discover = _isDiscover;
    // `_products` may still hold the previous category's items while a new
    // load is in flight (or after it failed); never render them as this view.
    final stale = _loadedKey != '$_selectedCategory|$_appliedSearch';
    if (_isLoadingProducts && (!_hasLoadedOnce || stale)) {
      return [
        discover
            ? const SliverToBoxAdapter(child: ShopDiscoverSkeleton())
            : _buildSkeletonGrid(),
      ];
    }
    if (_error != null && (_products == null || stale)) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _StateMessage(
            icon: Icons.cloud_off_rounded,
            message: context.tr('shop_load_error'),
            actionLabel: context.tr('shop_retry'),
            onAction: _loadProducts,
          ),
        ),
      ];
    }
    if (products.isEmpty) {
      return [
        if (_isLoadingProducts)
          _buildSkeletonGrid()
        else
          SliverFillRemaining(
            hasScrollBody: false,
            child: _StateMessage(
              icon: _showWishlistOnly
                  ? Icons.favorite_border_rounded
                  : Icons.search_off_rounded,
              message: context.tr(_showWishlistOnly
                  ? 'shop_wishlist_empty'
                  : 'no_products_found'),
              actionLabel: _anythingActive ? context.tr('shop_reset') : null,
              onAction: _anythingActive ? _resetAll : null,
            ),
          ),
      ];
    }
    if (discover) {
      return [
        SliverToBoxAdapter(
          child: ShopDiscoverHome(
            products: products,
            categories: _categories,
            wishlist: _wishlist,
            isNew: _isNew,
            categoryLabel: getLocalizedCategory,
            productName: getLocalizedProductName,
            onOpen: _openProduct,
            onBuyNow: _buyNow,
            onToggleWishlist: _toggleWishlist,
            onSeeAll: _seeAll,
            onViewAll: () => setState(() => _forceGrid = true),
          ),
        ),
      ];
    }
    return [_buildCount(products.length), _buildGrid(products)];
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

  /// Shared grid metrics so the real grid and skeleton line up.
  ({int cols, double cellWidth, double extent}) _metrics(double width) {
    const pad = 16.0, gap = 12.0;
    final avail = width - pad * 2;
    final cols = width > 600 ? (avail ~/ 200).clamp(3, 4) : 2;
    final cell = (avail - gap * (cols - 1)) / cols;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return (cols: cols, cellWidth: cell, extent: shopCardExtent(cell, scale));
  }

  SliverGridDelegate _delegate(
          ({int cols, double cellWidth, double extent}) m) =>
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: m.cols,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: m.extent,
      );

  Widget _buildGrid(List<Product> products) {
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
                final p = products[i];
                return ShopProductCard(
                  key: ValueKey(p.id),
                  product: p,
                  displayName: getLocalizedProductName(context, p.name),
                  isWishlisted: _wishlist.contains(p.id),
                  isNew: _isNew(p),
                  memCacheWidth: cache,
                  onTap: () => _openProduct(p),
                  onBuyNow: () => _buyNow(p),
                  onToggleWishlist: () => _toggleWishlist(p.id),
                );
              },
              childCount: products.length,
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
