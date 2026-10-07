import 'package:cropsync/models/market_location.dart';
import 'package:cropsync/services/market_prices_service.dart';
import 'package:cropsync/theme/app_text.dart';
import 'package:cropsync/utils/market_aliases.dart';
import 'package:cropsync/widgets/market/market_logic.dart';
import 'package:cropsync/widgets/shop/shop_filters.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

const Color _kMuted = Color(0xFF64748B);
const Color _kTint = Color(0xFFE7F5EE);
const Color _kSubTint = Color(0xFFF4FAF7);
const double _kRow = 56;

/// What the location sheet closed with. A picked place is applied through
/// the `onPlace` callback while the sheet is still open, so only "use my
/// location" travels back as a result.
class MarketLocationChoice {
  /// Chosen place (state, optional district), or null for [useGps].
  final MarketLocation? location;
  final bool useGps;
  const MarketLocationChoice.place(MarketLocation this.location)
      : useGps = false;
  const MarketLocationChoice.gps()
      : location = null,
        useGps = true;
}

/// "Choose your place": every Indian state / UT (those the server has prices
/// for first), with the districts of the selected state inline. Picking a
/// state applies the state-wide selection at once through [onPlace]; a
/// district is an optional refinement. No text field (the screen already
/// owns the only one).
Future<MarketLocationChoice?> showMarketLocationSheet(
  BuildContext context, {
  required Future<MarketLocationsResult> Function() loadLocations,
  required void Function(MarketLocation place) onPlace,
  MarketLocation? current,
}) {
  return showModalBottomSheet<MarketLocationChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: false,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (_) => MarketLocationSheet(
      loadLocations: loadLocations,
      onPlace: onPlace,
      current: current,
    ),
  );
}

enum _Kind { heading, state, whole, district, hint, loading }

class _Entry {
  final _Kind kind;
  final String title;
  final String? subtitle;
  final String state;
  final String district;
  final bool selected;
  final bool expanded;
  const _Entry(
    this.kind, {
    this.title = '',
    this.subtitle,
    this.state = '',
    this.district = '',
    this.selected = false,
    this.expanded = false,
  });
}

class MarketLocationSheet extends StatefulWidget {
  final Future<MarketLocationsResult> Function() loadLocations;
  final void Function(MarketLocation place) onPlace;
  final MarketLocation? current;

  const MarketLocationSheet({
    super.key,
    required this.loadLocations,
    required this.onPlace,
    this.current,
  });

  @override
  State<MarketLocationSheet> createState() => _MarketLocationSheetState();
}

class _MarketLocationSheetState extends State<MarketLocationSheet> {
  MarketLocationsResult? _data;
  bool _loading = true;
  late MarketLocation? _current = widget.current;
  String? _expanded;
  final GlobalKey _expandedKey = GlobalKey();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    MarketLocationsResult r;
    try {
      r = await widget.loadLocations();
    } catch (_) {
      r = const MarketLocationsResult(error: MarketFetchError.network);
    }
    if (!mounted) return;
    setState(() {
      _data = r;
      _loading = false;
    });
  }

  String get _lang {
    final code = context.locale.languageCode;
    return (code == 'hi' || code == 'te') ? code : 'en';
  }

  String get _curState => _current != null && _current!.hasState
      ? canonicalState(_current!.state)
      : '';

  bool get _loadFailed => !_loading && (_data?.error != null);

  MarketStateInfo? _info(String canonical) {
    for (final s in _data?.states ?? const <MarketStateInfo>[]) {
      if (canonicalState(s.state) == canonical) return s;
    }
    return null;
  }

  static bool _hasPrices(MarketStateInfo? i) =>
      i != null && (i.districts.isNotEmpty || i.commodityCount > 0);

  // ----------------------------------------------------------- entries

  List<_Entry> _entries() {
    final lang = _lang;
    final cur = _curState;
    final names = <String>{
      ...kAllIndianStates,
      for (final s in _data?.states ?? const <MarketStateInfo>[])
        canonicalState(s.state),
    }..remove('');
    int byName(String a, String b) => stateDisplayName(a, lang)
        .toLowerCase()
        .compareTo(stateDisplayName(b, lang).toLowerCase());

    final withPrices = <String>[], more = <String>[];
    for (final n in names) {
      if (n == cur) continue;
      (_hasPrices(_info(n)) ? withPrices : more).add(n);
    }
    withPrices.sort(byName);
    more.sort(byName);

    final out = <_Entry>[];
    void addState(String n) {
      final info = _info(n);
      final isCur = n == cur;
      final open = _expanded == n;
      out.add(_Entry(
        _Kind.state,
        title: stateDisplayName(n, lang),
        subtitle: isCur && (_current?.district ?? '').trim().isNotEmpty
            ? _current!.district.trim()
            : info != null && info.districts.isNotEmpty
                ? context.tr('mktui_districts_count',
                    namedArgs: {'count': '${info.districts.length}'})
                : null,
        state: n,
        selected: isCur,
        expanded: open,
      ));
      if (!open) return;
      final cd = (_current?.district ?? '').trim();
      out.add(_Entry(_Kind.whole,
          title: context.tr('mktui_whole_state'),
          state: n,
          selected: isCur && cd.isEmpty));
      if (_loading) {
        out.add(const _Entry(_Kind.loading));
      } else if (info != null && info.districts.isNotEmpty) {
        final ds = [...info.districts]..sort();
        for (final d in ds) {
          out.add(_Entry(_Kind.district,
              title: d,
              state: n,
              district: d,
              selected: isCur && cd.isNotEmpty && sameDistrict(cd, d)));
        }
      } else if (_loadFailed) {
        out.add(_Entry(_Kind.hint, title: context.tr('mktui_places_failed')));
      }
    }

    if (cur.isNotEmpty) {
      out.add(_Entry(_Kind.heading, title: context.tr('mktui_sec_your_state')));
      addState(cur);
    }
    final grouped = withPrices.isNotEmpty;
    if (grouped) {
      out.add(
          _Entry(_Kind.heading, title: context.tr('mktui_sec_with_prices')));
      withPrices.forEach(addState);
      if (more.isNotEmpty) {
        out.add(_Entry(_Kind.heading, title: context.tr('mktui_sec_more')));
        more.forEach(addState);
      }
    } else {
      out.add(_Entry(_Kind.heading,
          title: context.tr(
              cur.isEmpty ? 'mktui_choose_state_title' : 'mktui_sec_more')));
      more.forEach(addState);
    }
    return out;
  }

  // ----------------------------------------------------------- actions

  void _apply(String state, String district) {
    final place = MarketLocation(
        state: state, district: district, source: MarketLocationSource.manual);
    setState(() => _current = place);
    widget.onPlace(place);
  }

  void _onState(_Entry e) {
    final info = _info(e.state);
    final refine =
        _loading || _loadFailed || (info != null && info.districts.isNotEmpty);
    if (e.selected) {
      // Already applied: just fold / unfold its districts.
      setState(() => _expanded = e.expanded ? null : e.state);
      if (!e.expanded) _revealExpanded();
      return;
    }
    _apply(e.state, '');
    if (!refine) {
      Navigator.pop(context);
      return;
    }
    setState(() => _expanded = e.state);
    _revealExpanded();
  }

  void _revealExpanded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _expandedKey.currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(ctx,
          alignment: 0.02,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic);
    });
  }

  // -------------------------------------------------------------- build

  TextStyle _t(String text, double size, FontWeight w, Color c) =>
      appStyle(context,
          text: text, size: size, weight: w, color: c, height: 1.3);

  Widget _handle() => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Center(
          child: Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      );

  Widget _titleRow() {
    final title = context.tr('mktui_loc_pick');
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _t(title, 21, FontWeight.w800, kShopInk)),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.close_rounded, color: kShopInk),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _gpsRow() {
    final label = context.tr('mktui_use_my_location');
    final cur = _current;
    final detected = cur != null &&
            cur.hasState &&
            (cur.source == MarketLocationSource.gps ||
                cur.source == MarketLocationSource.cached)
        ? placeLabel(cur)
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: _kTint,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pop(context, const MarketLocationChoice.gps()),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                        color: kShopGreen, shape: BoxShape.circle),
                    child: const Icon(Icons.my_location_rounded,
                        size: 22, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style:
                                _t(label, 15.5, FontWeight.w800, kShopGreen)),
                        if (detected != null)
                          Text(detected,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  _t(detected, 12.5, FontWeight.w500, _kMuted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 24, color: kShopGreen),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(_Entry e) {
    switch (e.kind) {
      case _Kind.heading:
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
          child: Text(e.title,
              style: _t(e.title, 12.5, FontWeight.w800, _kMuted)
                  .copyWith(letterSpacing: 0.4)),
        );
      case _Kind.loading:
        return const SizedBox(
          height: _kRow,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: kShopGreen),
            ),
          ),
        );
      case _Kind.hint:
        return Container(
          color: _kSubTint,
          padding: const EdgeInsets.fromLTRB(36, 8, 20, 12),
          child:
              Text(e.title, style: _t(e.title, 12.5, FontWeight.w500, _kMuted)),
        );
      case _Kind.whole:
      case _Kind.district:
        final whole = e.kind == _Kind.whole;
        return _tile(
          title: e.title,
          selected: e.selected,
          tint: e.selected ? _kTint : _kSubTint,
          indent: 36,
          leading: whole ? Icons.map_outlined : null,
          onTap: () {
            _apply(e.state, e.district);
            Navigator.pop(context);
          },
        );
      case _Kind.state:
        return KeyedSubtree(
          key: e.expanded ? _expandedKey : ValueKey('state_${e.state}'),
          child: _tile(
            title: e.title,
            subtitle: e.subtitle,
            selected: e.selected,
            tint: e.selected ? _kTint : Colors.transparent,
            trailing: e.expanded
                ? Icons.expand_less_rounded
                : Icons.chevron_right_rounded,
            onTap: () => _onState(e),
          ),
        );
    }
  }

  Widget _tile({
    required String title,
    String? subtitle,
    required bool selected,
    required Color tint,
    required VoidCallback onTap,
    double indent = 20,
    IconData? leading,
    IconData trailing = Icons.chevron_right_rounded,
  }) {
    return Material(
      color: tint,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kRow),
          child: Padding(
            padding: EdgeInsets.fromLTRB(indent, 8, 16, 8),
            child: Row(
              children: [
                if (leading != null) ...[
                  Icon(leading, size: 20, color: _kMuted),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: _t(
                              title,
                              15.5,
                              selected ? FontWeight.w800 : FontWeight.w600,
                              selected ? kShopGreen : kShopInk)),
                      if (subtitle != null)
                        Text(subtitle,
                            style:
                                _t(subtitle, 12.5, FontWeight.w500, _kMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(selected ? Icons.check_circle_rounded : trailing,
                    size: 22, color: selected ? kShopGreen : _kMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries();
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return LayoutBuilder(
      builder: (context, box) => SizedBox(
        height: box.maxHeight * 0.9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _handle(),
            _titleRow(),
            _gpsRow(),
            if (_loading)
              const LinearProgressIndicator(
                  minHeight: 2, color: kShopGreen, backgroundColor: _kTint)
            else
              const Divider(height: 2, thickness: 1, color: Color(0xFFEEF2F6)),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: EdgeInsets.only(bottom: bottom + 24),
                itemCount: entries.length,
                itemBuilder: (_, i) => _row(entries[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
