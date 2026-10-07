// lib/screens/market_prices.dart

import 'dart:async';
import 'dart:convert';

import 'package:cropsync/models/market_location.dart';
import 'package:cropsync/models/market_price.dart';
import 'package:cropsync/screens/commodity_detail_screen.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/location_service.dart';
import 'package:cropsync/services/market_prices_service.dart';
import 'package:cropsync/theme/app_text.dart';
import 'package:cropsync/widgets/language_button.dart';
import 'package:cropsync/widgets/market/market_cards.dart';
import 'package:cropsync/widgets/market/market_filters_sheet.dart';
import 'package:cropsync/widgets/market/market_location_sheet.dart';
import 'package:cropsync/widgets/market/market_location_ui.dart';
import 'package:cropsync/widgets/market/market_logic.dart';
import 'package:cropsync/widgets/shop/shop_back_gate.dart';
import 'package:cropsync/widgets/shop/shop_category_style.dart';
import 'package:cropsync/widgets/shop/shop_chrome.dart';
import 'package:cropsync/widgets/shop/shop_discover.dart';
import 'package:cropsync/widgets/shop/shop_filters.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

/// SharedPreferences key of the place the user picked by hand.
const String kMarketManualLocationKey = 'market_manual_location';

/// SharedPreferences key of the last place that worked (GPS or profile).
const String kMarketLastLocationKey = 'market_last_location';

const String _kNearRail = '__near';
const String _kHighestRail = '__highest';

/// Market prices: location chip, discover rails, search, filters, rows.
class MarketPricesScreen extends StatefulWidget {
  /// Raw commodity name that pre-fills the search box (deep links).
  final String? initialCommodity;

  @visibleForTesting
  final MarketPricesService? service;

  /// Replaces [LocationService.resolveMarketLocation].
  @visibleForTesting
  final Future<MarketLocationResult> Function()? locationResolver;

  /// Test-only image provider for every commodity image.
  @visibleForTesting
  final ImageProvider? debugImageProvider;

  const MarketPricesScreen({
    super.key,
    this.initialCommodity,
    this.service,
    this.locationResolver,
    this.debugImageProvider,
  });

  @override
  State<MarketPricesScreen> createState() => _MarketPricesScreenState();
}

class _MarketPricesScreenState extends State<MarketPricesScreen>
    with WidgetsBindingObserver {
  late final MarketPricesService _service;
  late final bool _ownsService;

  // Location
  bool _initializing = true;
  MarketLocation? _loc;
  bool _manual = false;
  bool _gpsResolving = false;
  MarketLocationFailure? _gpsFailure;
  bool _gpsBannerDismissed = false;
  int _gpsRun = 0;

  /// True after the banner sent the user to an OS settings screen; the next
  /// app resume then retries the GPS (and only then).
  bool _awaitingSettingsReturn = false;

  /// One automatic retry for a state the server has no data for yet (it may
  /// sync the state on the first request).
  static const Duration _autoRetryDelay = Duration(seconds: 8);
  Timer? _retryTimer;
  bool _autoRetried = false;
  bool _autoRetryPending = false;

  /// A manual retry is running while data is still on screen.
  bool _retrying = false;

  /// The search box holds a deep-link name that has not been checked against
  /// the data yet.
  bool _initialPending = false;

  // Data
  MarketPricesResult? _result;
  List<CommodityPrices> _all = const [];
  Map<String, String> _index = const {};
  List<String> _categories = const [];
  Map<String, int> _ids = const {};
  int _request = 0;

  // View state
  MarketFilters _filters = const MarketFilters();
  String _query = '';
  bool _forceGrid = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsService = widget.service == null;
    _service = widget.service ?? MarketPricesService();
    final initial = cleanInitialCommodity(widget.initialCommodity);
    if (initial.isNotEmpty) {
      _searchController.text = initial;
      _query = initial;
      _initialPending = true;
    }
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _searchController.dispose();
    if (_ownsService) _service.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the OS settings page the banner opened: try the GPS again.
    // A plain "permission denied" never retries by itself (it would pop the
    // OS dialog on every resume); it waits for the "Enable location" tap.
    if (state != AppLifecycleState.resumed) return;
    final fromSettings = _awaitingSettingsReturn;
    _awaitingSettingsReturn = false;
    if (!fromSettings || _manual || _gpsResolving) return;
    final f = _gpsFailure;
    if (f == MarketLocationFailure.permissionDeniedForever ||
        f == MarketLocationFailure.serviceDisabled) {
      _resolveGps();
    }
  }

  // ------------------------------------------------------------ location

  String get _lang {
    final code = context.locale.languageCode;
    return (code == 'hi' || code == 'te') ? code : 'en';
  }

  bool get _hasState => _loc != null && _loc!.hasState;

  static MarketLocation? _readLocation(SharedPreferences prefs, String key) {
    try {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final state = (m['state'] ?? '').toString().trim();
      if (state.isEmpty) return null;
      final src = MarketLocationSource.values.firstWhere(
        (s) => s.name == m['source'],
        orElse: () => MarketLocationSource.cached,
      );
      return MarketLocation(
        state: state,
        district: (m['district'] ?? '').toString().trim(),
        source: src,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeLocation(String key, MarketLocation loc) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode({
          'state': loc.state,
          'district': loc.district,
          'source': loc.source.name,
        }),
      );
    } catch (_) {}
  }

  Future<void> _init() async {
    MarketLocation? manual, last;
    try {
      final prefs = await SharedPreferences.getInstance();
      manual = _readLocation(prefs, kMarketManualLocationKey);
      last = _readLocation(prefs, kMarketLastLocationKey);
    } catch (_) {}
    if (!mounted) return;
    final start = manual ??
        last ??
        LocationService.locationFromProfile(AuthService.currentUser);
    setState(() {
      _initializing = false;
      _manual = manual != null;
      _loc = start == null
          ? null
          : (manual != null
              ? start.copyWith(source: MarketLocationSource.manual)
              : start);
    });
    if (_hasState) _fetch();
    if (!_manual) _resolveGps();
  }

  Future<void> _resolveGps() async {
    final run = ++_gpsRun;
    setState(() => _gpsResolving = true);
    MarketLocationResult r;
    try {
      r = await (widget.locationResolver ??
          LocationService.resolveMarketLocation)();
    } catch (_) {
      r = const MarketLocationResult(
          failure: MarketLocationFailure.unsupported);
    }
    if (!mounted || run != _gpsRun) return;
    if (_manual) {
      setState(() => _gpsResolving = false);
      return;
    }
    final found = r.location;
    if (found == null || !found.hasState) {
      setState(() {
        _gpsResolving = false;
        _gpsFailure = r.failure ?? MarketLocationFailure.geocodeFailed;
        _gpsBannerDismissed = false;
      });
      return;
    }
    final cur = _loc;
    final sameState = cur != null &&
        cur.hasState &&
        cur.state.toLowerCase() == found.state.toLowerCase();
    final changed = cur == null || !cur.hasState || !sameLocation(cur, found);
    // The whole state is always fetched; a different district of the same
    // state only re-sorts the rows ("Near you"), it never refetches.
    final refetch = changed && !sameState;
    setState(() {
      _gpsResolving = false;
      _gpsFailure = null;
      _loc = found;
      if (refetch) _clearData();
    });
    _writeLocation(kMarketLastLocationKey, found);
    if (refetch) {
      _fetch();
    } else if (changed && _result != null) {
      _apply(_result!);
    }
  }

  Future<void> _applyManual(MarketLocation picked) async {
    final loc = picked.copyWith(source: MarketLocationSource.manual);
    _gpsRun++; // ignore a GPS answer that is still in flight
    final cur = _loc;
    final sameState = cur != null &&
        cur.hasState &&
        cur.state.toLowerCase() == loc.state.toLowerCase();
    final reuse = sameState &&
        (_result == null ? _request > 0 : _result!.hasData && _all.isNotEmpty);
    setState(() {
      _manual = true;
      _gpsResolving = false;
      _gpsFailure = null;
      _loc = loc;
      if (!reuse) _clearData();
    });
    _writeLocation(kMarketManualLocationKey, loc);
    if (!reuse) {
      _fetch();
    } else if (_result != null) {
      _apply(_result!); // same state: only the district hint changes
    }
  }

  Future<void> _useGps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kMarketManualLocationKey);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _manual = false;
      _gpsFailure = null;
      _gpsBannerDismissed = false;
    });
    _resolveGps();
  }

  Future<void> _openLocationSheet() async {
    final choice = await showMarketLocationSheet(
      context,
      loadLocations: _service.fetchLocations,
      current: _loc,
      onPlace: (p) => unawaited(_applyManual(p)),
    );
    if (choice == null || !mounted) return;
    if (choice.useGps) await _useGps();
  }

  void _clearData() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _autoRetried = false;
    _autoRetryPending = false;
    _result = null;
    _all = const [];
    _index = const {};
    _categories = const [];
    _ids = const {};
  }

  // ---------------------------------------------------------------- data

  Future<void> _fetch({bool force = false}) async {
    final loc = _loc;
    if (loc == null || !loc.hasState) return;
    final request = ++_request;

    Future<MarketPricesResult> load(int days) async {
      try {
        return await _service.fetchPrices(
          state: loc.state,
          // Always the whole state; the district is only an ordering hint
          // applied when grouping ([_apply]).
          lang: _lang,
          forceRefresh: force,
          days: days,
        );
      } catch (_) {
        return const MarketPricesResult(error: MarketFetchError.server);
      }
    }

    // First paint: only the newest day (small, every commodity of that day).
    final res = await load(1);
    if (!mounted || request != _request) return;
    _apply(res);
    if (!res.hasData &&
        res.error == MarketFetchError.noData &&
        res.errorHint == 'no_data_for_state' &&
        !_autoRetried) {
      _scheduleAutoRetry();
      return;
    }

    // Then, without blocking, add the earlier days and merge.
    if (res.hasData && res.error == null) {
      final extra = await load(MarketPricesService.defaultDays);
      if (!mounted || request != _request) return;
      if (extra.error == null && extra.records.isNotEmpty) {
        _apply(
          res.copyWith(
            records: dedupeLatestRows([...res.records, ...extra.records]),
          ),
        );
      }
    }
  }

  /// The server may sync a state on its first request: ask once more after
  /// a short wait, showing the skeleton meanwhile.
  void _scheduleAutoRetry() {
    _retryTimer?.cancel();
    setState(() => _autoRetryPending = true);
    _retryTimer = Timer(_autoRetryDelay, () {
      _retryTimer = null;
      if (!mounted || !_hasState) return;
      _autoRetried = true;
      _fetch(force: true);
    });
  }

  void _apply(MarketPricesResult res) {
    final rows = dedupeLatestRows(res.records);
    // The user's district only sorts / highlights rows; it never filters.
    final d = (_loc?.district ?? '').trim();
    final String? userDistrict = d.isEmpty ? null : d;
    final grouped = groupByCommodity(rows, userDistrict: userDistrict);
    final cats = categoriesPresent(grouped);
    final index = buildSearchIndex(grouped);
    setState(() {
      _retrying = false;
      _autoRetryPending = false;
      _result = res;
      _all = grouped;
      _index = index;
      _categories = cats;
      _ids = {for (var i = 0; i < grouped.length; i++) grouped[i].key: i};
      if (_filters.category != kMarketAll &&
          !cats.contains(_filters.category)) {
        _filters = _filters.copyWith(category: kMarketAll);
      }
      // A deep-link name that matches nothing must not leave an empty list.
      if (_initialPending && grouped.isNotEmpty) {
        _initialPending = false;
        final any = applyMarketFilters(grouped,
            filters: const MarketFilters(),
            query: _query,
            index: index,
            lang: _lang);
        if (any.isEmpty) {
          _searchController.clear();
          _query = '';
        }
      }
    });
  }

  /// Retry after an error: back to the loading state first.
  Future<void> _retry({bool clear = true}) {
    setState(() {
      if (clear) {
        _clearData();
      } else {
        _retrying = true;
      }
    });
    return _fetch(force: true);
  }

  Future<void> _refresh() async {
    if (_hasState) {
      if (!_manual && !_gpsResolving) unawaited(_resolveGps());
      await _fetch(force: true);
    } else if (!_manual) {
      await _resolveGps();
    }
  }

  // ------------------------------------------------------------- derived

  bool get _isDiscover => !_forceGrid && _filters.isDefault && _query.isEmpty;

  bool get _atHome => _isDiscover && _searchController.text.trim().isEmpty;

  List<CommodityPrices> _visible() => applyMarketFilters(
        _all,
        filters: _filters,
        query: _query,
        index: _index,
        lang: _lang,
      );

  // ------------------------------------------------------------- actions

  void _onSearchChanged(String v) => setState(() => _query = v.trim());

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _selectCategory(String c) => setState(() {
        _filters = _filters.copyWith(category: c);
        _forceGrid = false;
      });

  Future<void> _openFilters() async {
    final r = await showMarketFiltersSheet(context, _filters,
        categories: _categories);
    if (r != null && mounted) setState(() => _filters = r);
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
      _filters = const MarketFilters();
      _forceGrid = false;
      _query = '';
    });
  }

  void _seeAll(String rail) {
    setState(() {
      if (rail == _kNearRail) {
        _filters = const MarketFilters();
        _forceGrid = true;
      } else if (rail == _kHighestRail) {
        _filters = _filters.copyWith(sort: MarketSort.highest);
        _forceGrid = true;
      } else {
        _filters = _filters.copyWith(category: rail);
        _forceGrid = false;
      }
    });
  }

  void _openCommodity(CommodityPrices c) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommodityDetailScreen(commodity: c, location: _loc),
      ),
    );
  }

  Future<void> _gpsBannerAction() async {
    switch (_gpsFailure) {
      case MarketLocationFailure.permissionDeniedForever:
        _awaitingSettingsReturn = true;
        await LocationService.openAppSettings();
      case MarketLocationFailure.serviceDisabled:
        _awaitingSettingsReturn = true;
        await LocationService.openLocationSettings();
      case MarketLocationFailure.permissionDenied:
        await _resolveGps();
      default:
        await _openLocationSheet();
    }
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
              buildShopAppBar(
                context,
                title: context.tr('market_prices_title'),
                onBack: _onBackPressed,
                trailing: const LanguageButton.pill(color: kShopInk),
              ),
              SliverToBoxAdapter(
                child: MarketLocationChip(
                  location: _loc,
                  detecting: _initializing || _gpsResolving,
                  onTap: _openLocationSheet,
                ),
              ),
              ..._buildBanners(),
              if (_all.isNotEmpty) SliverToBoxAdapter(child: _buildSearchRow()),
              if (_categories.isNotEmpty)
                SliverToBoxAdapter(child: _buildChips()),
              if (_filters.isActive)
                SliverToBoxAdapter(child: _buildActiveFilters()),
              ..._buildBody(items),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBanners() {
    final out = <Widget>[];
    final f = _gpsFailure;
    if (f != null && !_manual && !_gpsBannerDismissed) {
      final v = gpsIssueView(f);
      out.add(SliverToBoxAdapter(
        child: MarketBanner(
          icon: Icons.location_off_rounded,
          message: context.tr(v.messageKey),
          actionLabel: context.tr(v.actionKey),
          onAction: _gpsBannerAction,
          onDismiss: () => setState(() => _gpsBannerDismissed = true),
        ),
      ));
    }
    if (_retrying) {
      out.add(const SliverToBoxAdapter(
        child: LinearProgressIndicator(minHeight: 2, color: kShopGreen),
      ));
    }
    final res = _result;
    if (res != null && res.hasData) {
      if (res.fromCache || res.stale) {
        final d = res.asOf ?? res.fetchedAt;
        final date = d == null ? null : marketDateLabel(context, d);
        final msg = date == null
            ? context.tr('mkt_prices_stale')
            : context.tr(
                res.fromCache ? 'mkt_showing_saved' : 'mktui_stale_from',
                namedArgs: {'date': date});
        out.add(SliverToBoxAdapter(
          child: MarketBanner(
            icon: Icons.history_rounded,
            message: msg,
            actionLabel: res.error != null ? context.tr('shop_retry') : null,
            onAction: res.error != null ? () => _retry(clear: false) : null,
          ),
        ));
      }
      if (res.partial) {
        var msg = context.tr('mktui_partial');
        if (msg == 'mktui_partial') msg = context.tr('mkt_prices_stale');
        out.add(SliverToBoxAdapter(
          child: MarketBanner(
            tone: MarketBannerTone.info,
            icon: Icons.info_outline_rounded,
            message: msg,
          ),
        ));
      }
      final loc = _loc;
      if (loc != null &&
          loc.district.isNotEmpty &&
          _all.isNotEmpty &&
          !_all.any((c) => c.userDistrictRow != null)) {
        out.add(SliverToBoxAdapter(
          child: MarketBanner(
            tone: MarketBannerTone.info,
            icon: Icons.info_outline_rounded,
            message: context.tr('mktui_state_fallback',
                namedArgs: {'district': loc.district, 'state': loc.state}),
          ),
        ));
      }
    }
    return out;
  }

  Widget _buildSearchRow() => ShopSearchRow(
        controller: _searchController,
        hint: context.tr('mktui_search_hint'),
        onChanged: _onSearchChanged,
        onSubmitted: _onSearchChanged,
        onFilterTap: _openFilters,
        filterActive: _filters.isActive,
        onClear: _clearSearch,
      );

  Widget _buildChips() {
    return ShopCategoryChips(
      categories: [kMarketAll, ..._categories],
      selected: _filters.category,
      labelOf: marketCategoryLabel,
      styleOf: marketChipStyle,
      onSelected: _selectCategory,
    );
  }

  Widget _buildActiveFilters() {
    Widget chip(String label, VoidCallback onRemove) => Chip(
          label: Text(
            label,
            style: appStyle(context,
                text: label,
                size: 12,
                weight: FontWeight.w600,
                color: kShopGreen,
                height: 1.3),
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
          children: [
            if (_filters.sort != MarketSort.district)
              chip(
                marketSortLabel(context, _filters.sort),
                () => setState(() =>
                    _filters = _filters.copyWith(sort: MarketSort.district)),
              ),
            if (_filters.onlyPriced)
              chip(
                context.tr('mktui_only_priced'),
                () => setState(
                    () => _filters = _filters.copyWith(onlyPriced: false)),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- body

  List<Widget> _buildBody(List<CommodityPrices> items) {
    final discover = _isDiscover;

    if (!_hasState) {
      if (_initializing || _gpsResolving) return [_skeleton(discover)];
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: MarketStatePanel(
            icon: Icons.travel_explore_rounded,
            title: context.tr('mktui_choose_state_title'),
            body: context.tr('mktui_choose_state_body'),
            actions: [
              (
                label: context.tr('mkt_choose_location'),
                onTap: _openLocationSheet,
                primary: true,
              ),
            ],
          ),
        ),
      ];
    }

    final res = _result;
    if (res == null || (_autoRetryPending && _all.isEmpty)) {
      return [_skeleton(discover)];
    }

    if (_all.isEmpty) {
      final err = res.error ?? MarketFetchError.noData;
      // The whole state is always requested, so there is no district-only
      // "show state-wide" step any more.
      final view = marketErrorView(err, districtRequested: false);
      final place = placeLabel(_loc!);
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: MarketStatePanel(
            icon: err == MarketFetchError.network ||
                    err == MarketFetchError.timeout
                ? Icons.wifi_off_rounded
                : (err == MarketFetchError.noData
                    ? Icons.search_off_rounded
                    : Icons.cloud_off_rounded),
            title: context.tr(view.titleKey, namedArgs: {'place': place}),
            body: context.tr(view.bodyKey),
            actions: [
              for (final a in view.actions)
                switch (a) {
                  MarketErrorAction.retry => (
                      label: context.tr('shop_retry'),
                      onTap: _retry,
                      primary: true,
                    ),
                  MarketErrorAction.showStateWide => (
                      label: context.tr('mktui_choose_another'),
                      onTap: _openLocationSheet,
                      primary: true,
                    ),
                  MarketErrorAction.chooseAnother => (
                      label: context.tr('mktui_choose_another'),
                      onTap: _openLocationSheet,
                      primary: !view.actions
                          .contains(MarketErrorAction.showStateWide),
                    ),
                },
            ],
          ),
        ),
      ];
    }

    if (items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: MarketStatePanel(
            icon: Icons.search_off_rounded,
            title: context.tr('mktui_no_results'),
            actions: [
              (
                label: context.tr('shop_reset'),
                onTap: _backToDiscover,
                primary: false,
              ),
            ],
          ),
        ),
      ];
    }

    if (discover) {
      return [SliverToBoxAdapter(child: _buildDiscover(items))];
    }
    return [_buildCount(items.length), _buildRows(items)];
  }

  Widget _skeleton(bool discover) => discover
      ? const SliverToBoxAdapter(
          child: DiscoverSkeleton(railHeight: marketRailHeight))
      : _buildSkeletonRows();

  Widget _buildDiscover(List<CommodityPrices> items) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    int idOf(CommodityPrices c) => _ids[c.key] ?? 0;
    CommodityRailEntry entry(CommodityPrices c, RailRowMode m) =>
        CommodityRailEntry(c, m, idOf(c));

    final used = <String>{};
    final rails = <ShopRailG<CommodityRailEntry>>[];

    final near = [
      for (final c in items)
        if (c.userDistrictRow != null) c,
    ].take(kShopRailItems).toList();
    if (near.isNotEmpty) {
      rails.add(ShopRailG(
          _kNearRail, [for (final c in near) entry(c, RailRowMode.near)]));
      used.addAll(near.map((c) => c.key));
    }

    // Honest ordering by the real best modal price.
    final highest = [
      for (final c in items)
        if (c.best != null) c,
    ]..sort((a, b) {
        final r = b.best!.modalPrice!.compareTo(a.best!.modalPrice!);
        return r != 0 ? r : idOf(a).compareTo(idOf(b));
      });
    final top = highest.take(kShopRailItems).toList();
    if (top.isNotEmpty) {
      rails.add(ShopRailG(
          _kHighestRail, [for (final c in top) entry(c, RailRowMode.best)]));
      used.addAll(top.map((c) => c.key));
    }

    final counts = <String, int>{};
    for (final c in items) {
      counts[c.category] = (counts[c.category] ?? 0) + 1;
    }
    final order = counts.keys.toList()
      ..sort((a, b) {
        final r = counts[b]!.compareTo(counts[a]!);
        return r != 0 ? r : a.compareTo(b);
      });
    final built = buildRails<CommodityPrices>(
      items: items,
      categoryOf: (c) => c.category,
      idOf: idOf,
      categoryOrder: order,
      maxRails: 3,
    );
    for (final r in built.rails) {
      rails.add(ShopRailG(r.category, [
        for (final c in r.items) entry(c, RailRowMode.auto),
      ]));
      used.addAll(r.items.map((c) => c.key));
    }

    final more = [
      for (final c in items)
        if (!used.contains(c.key)) entry(c, RailRowMode.auto),
    ].take(kShopMoreItems).toList();

    return DiscoverHome<CommodityRailEntry>(
      data: (fresh: const [], rails: rails, more: more),
      idOf: (e) => e.id,
      freshTitle: '',
      moreTitle: context.tr('mktui_rail_more'),
      railTitleFor: (ctx, key) => switch (key) {
        _kNearRail => ctx.tr('mktui_rail_near'),
        _kHighestRail => ctx.tr('mktui_rail_highest'),
        _ => marketCategoryLabel(ctx, key),
      },
      styleOf: (key) => switch (key) {
        _kNearRail => const ShopCategoryStyle(
            Icons.place_rounded, Color(0xFFE3F4EC), kShopGreen),
        _kHighestRail => const ShopCategoryStyle(
            Icons.military_tech_rounded, Color(0xFFFFF4D6), Color(0xFFB45309)),
        _ => marketChipStyle(key),
      },
      onSeeAll: _seeAll,
      onViewAllMore: () => setState(() => _forceGrid = true),
      railHeight: marketRailHeight,
      itemBuilder: (context, e, cardW) => CommodityRailCard(
        entry: e,
        displayName: commodityDisplayName(e.commodity.name, _lang),
        memCacheWidth: (cardW * dpr).round().clamp(120, 600),
        debugImageProvider: widget.debugImageProvider,
        onTap: () => _openCommodity(e.commodity),
      ),
    );
  }

  Widget _buildCount(int count) {
    final text = context.tr('mktui_count', namedArgs: {'count': '$count'});
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(
          text,
          style: appStyle(context,
              text: text,
              size: 12.5,
              weight: FontWeight.w500,
              color: const Color(0xFF64748B),
              height: 1.4),
        ),
      ),
    );
  }

  Widget _rowFor(CommodityPrices c, int cache) => KeyedSubtree(
        key: ValueKey('row_${c.key}'),
        child: CommodityRow(
          commodity: c,
          displayName: commodityDisplayName(c.name, _lang),
          memCacheWidth: cache,
          debugImageProvider: widget.debugImageProvider,
          onTap: () => _openCommodity(c),
        ),
      );

  Widget _buildRows(List<CommodityPrices> items) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final cache = (88 * dpr).round().clamp(80, 300);
        if (width <= 600) {
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _rowFor(items[i], cache),
                ),
                childCount: items.length,
              ),
            ),
          );
        }
        const pad = 16.0, gap = 12.0;
        final avail = width - pad * 2;
        final cols = (avail ~/ 400).clamp(2, 3);
        final scale = MediaQuery.textScalerOf(context).scale(1);
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(pad, 8, pad, 0),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              mainAxisExtent: marketRowExtent(scale),
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _rowFor(items[i], cache),
              childCount: items.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonRows() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Shimmer.fromColors(
              baseColor: const Color(0xFFEEF2F6),
              highlightColor: const Color(0xFFF8FAFC),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const SizedBox(height: 112, width: double.infinity),
              ),
            ),
          ),
          childCount: 6,
        ),
      ),
    );
  }
}
