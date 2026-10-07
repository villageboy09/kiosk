import 'package:cropsync/theme/app_text.dart';
import 'package:cropsync/widgets/shop/shop_filters.dart';
import 'package:flutter/material.dart';

/// Pastel tint + glyph for a shop category (derived from keywords).
class ShopCategoryStyle {
  final IconData icon;
  final Color tint;
  final Color accent;
  const ShopCategoryStyle(this.icon, this.tint, this.accent);
}

const _seeds = ShopCategoryStyle(
    Icons.grass_rounded, Color(0xFFE8F5E9), Color(0xFF2E7D32));
const _fertilizer = ShopCategoryStyle(
    Icons.science_rounded, Color(0xFFFFF4E0), Color(0xFFB45309));
const _pesticide = ShopCategoryStyle(
    Icons.bug_report_rounded, Color(0xFFFDEBEC), Color(0xFFB91C1C));
const _machinery = ShopCategoryStyle(
    Icons.agriculture_rounded, Color(0xFFE6F0FD), Color(0xFF1D4ED8));
const _tools = ShopCategoryStyle(
    Icons.handyman_rounded, Color(0xFFEFE9FB), Color(0xFF6D28D9));
const _irrigation = ShopCategoryStyle(
    Icons.water_drop_rounded, Color(0xFFE0F5F8), Color(0xFF0E7490));
const _animal =
    ShopCategoryStyle(Icons.pets_rounded, Color(0xFFFCE8F1), Color(0xFFBE185D));
const _default = ShopCategoryStyle(
    Icons.category_rounded, Color(0xFFEFF3F7), Color(0xFF475569));
const _all =
    ShopCategoryStyle(Icons.apps_rounded, Color(0xFFEFF3F7), Color(0xFF475569));

const _rules = <(List<String>, ShopCategoryStyle)>[
  (['seed', 'విత్త', 'बीज', 'plant', 'sapling', 'నారు'], _seeds),
  (
    ['fertil', 'manure', 'nutrient', 'ఎరువ', 'उर्वरक', 'खाद', 'compost'],
    _fertilizer
  ),
  (
    ['pestic', 'insect', 'herbic', 'fungic', 'పురుగు', 'కలుపు', 'कीट', 'दवा'],
    _pesticide
  ),
  (
    ['machin', 'tractor', 'implement', 'equip', 'మెషీన్', 'యంత్ర', 'मशीन'],
    _machinery
  ),
  (['tool', 'పనిము', 'పరికర', 'औज़ार', 'औजार', 'उपकरण', 'hardware'], _tools),
  (
    [
      'irrig',
      'water',
      'drip',
      'sprink',
      'pump',
      'నీటి',
      'సేద్య',
      'सिंचाई',
      'पानी'
    ],
    _irrigation
  ),
  (
    [
      'animal',
      'cattle',
      'feed',
      'dairy',
      'poultry',
      'livestock',
      'పశు',
      'పాడి',
      'पशु'
    ],
    _animal
  ),
];

/// Style for a category; `all_category` and unknown names get neutral styles.
ShopCategoryStyle shopCategoryStyle(String category) {
  if (category == 'all_category') return _all;
  final c = category.toLowerCase();
  for (final (keys, style) in _rules) {
    for (final k in keys) {
      if (c.contains(k)) return style;
    }
  }
  return _default;
}

ShopCategoryStyle _c(IconData i, int tint, int accent) =>
    ShopCategoryStyle(i, Color(tint), Color(accent));

final _cropRules = <(List<String>, ShopCategoryStyle)>[
  (
    ['paddy', 'rice', 'వరి', 'బియ్యం', 'धान', 'चावल'],
    _c(Icons.grain_rounded, 0xFFFFF4D6, 0xFFB45309)
  ),
  (
    ['cotton', 'పత్తి', 'कपास'],
    _c(Icons.cloud_rounded, 0xFFE6F0FD, 0xFF1D4ED8)
  ),
  (
    ['chilli', 'chili', 'pepper', 'మిర్చి', 'మిరప', 'मिर्च'],
    _c(Icons.local_fire_department_rounded, 0xFFFDEBEC, 0xFFB91C1C)
  ),
  (
    ['maize', 'corn', 'మొక్కజొన్న', 'मक्का', 'मकई'],
    _c(Icons.eco_rounded, 0xFFFFF9DB, 0xFFA16207)
  ),
  (
    ['groundnut', 'peanut', 'వేరుశనగ', 'వేరుసెనగ', 'मूंगफली'],
    _c(Icons.spa_rounded, 0xFFF6EBDD, 0xFF92400E)
  ),
  (
    ['wheat', 'గోధుమ', 'गेहूं', 'गेहूँ'],
    _c(Icons.grass_rounded, 0xFFFBF0DC, 0xFFB7791F)
  ),
  (
    ['soy', 'సోయా', 'सोया'],
    _c(Icons.energy_savings_leaf_rounded, 0xFFE8F5E9, 0xFF2E7D32)
  ),
  (
    ['tomato', 'టమాట', 'టమోటా', 'टमाटर'],
    _c(Icons.circle_rounded, 0xFFFCE4E4, 0xFFDC2626)
  ),
  (
    ['vegetable', 'veggie', 'కూరగాయ', 'सब्जी', 'सब्ज़ी'],
    _c(Icons.park_rounded, 0xFFE3F4EC, 0xFF047857)
  ),
  (
    [
      'pulse',
      'dal',
      'gram',
      'pigeon',
      'lentil',
      'కంది',
      'పప్పు',
      'పెసర',
      'మినుము',
      'दाल',
      'अरहर',
      'तूर',
      'चना'
    ],
    _c(Icons.blur_circular_rounded, 0xFFEFE9FB, 0xFF6D28D9)
  ),
  (
    ['sugarcane', 'చెరకు', 'गन्ना'],
    _c(Icons.straighten_rounded, 0xFFE0F5F8, 0xFF0E7490)
  ),
  (
    ['fruit', 'mango', 'banana', 'పండు', 'ఫల', 'फल'],
    _c(Icons.apple_rounded, 0xFFFCE8F1, 0xFFBE185D)
  ),
];

const _cropDefault =
    ShopCategoryStyle(Icons.eco_rounded, Color(0xFFE8F5E9), Color(0xFF2E7D32));

/// Style (icon + pastel tint) for a crop name in English/Hindi/Telugu.
/// Unknown crops get a neutral green leaf.
ShopCategoryStyle cropStyle(String name) {
  final c = name.toLowerCase().trim();
  if (c.isEmpty) return _cropDefault;
  for (final (keys, style) in _cropRules) {
    for (final k in keys) {
      if (c.contains(k)) return style;
    }
  }
  return _cropDefault;
}

/// Horizontal category chip row: tinted icon bubble + label, selected chip is
/// solid brand green. The selected chip is scrolled into view on first build
/// and whenever the selection changes.
class ShopCategoryChips extends StatefulWidget {
  final List<String> categories;
  final String selected;
  final String Function(BuildContext, String) labelOf;
  final ValueChanged<String> onSelected;

  /// Icon/tint resolver per entry (defaults to [shopCategoryStyle]).
  final ShopCategoryStyle Function(String) styleOf;

  const ShopCategoryChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.styleOf = shopCategoryStyle,
  });

  @override
  State<ShopCategoryChips> createState() => _ShopCategoryChipsState();
}

class _ShopCategoryChipsState extends State<ShopCategoryChips> {
  final Map<String, GlobalKey> _keys = {};

  @override
  void initState() {
    super.initState();
    _scheduleReveal(animate: false);
  }

  @override
  void didUpdateWidget(ShopCategoryChips old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      _scheduleReveal(animate: true);
    } else if (old.categories.length != widget.categories.length) {
      _scheduleReveal(animate: false);
    }
  }

  void _scheduleReveal({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _keys[widget.selected]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: animate ? const Duration(milliseconds: 220) : Duration.zero,
        curve: Curves.easeOut,
      );
    });
  }

  Widget _chip(BuildContext context, String raw) {
    final label = widget.labelOf(context, raw);
    final isSel = raw == widget.selected;
    final style = widget.styleOf(raw);
    return Semantics(
      key: _keys.putIfAbsent(raw, GlobalKey.new),
      button: true,
      selected: isSel,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => widget.onSelected(raw),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.fromLTRB(5, 0, 14, 0),
            decoration: BoxDecoration(
              color: isSel ? kShopGreen : kShopGrey,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSel
                        ? Colors.white.withValues(alpha: 0.22)
                        : style.tint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    style.icon,
                    size: 16,
                    color: isSel ? Colors.white : style.accent,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  maxLines: 1,
                  style: appStyle(
                    context,
                    text: label,
                    size: 13,
                    weight: FontWeight.w600,
                    color: isSel ? Colors.white : kShopInk,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _keys.removeWhere((k, _) => !widget.categories.contains(k));
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (var i = 0; i < widget.categories.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _chip(context, widget.categories[i]),
            ],
          ],
        ),
      ),
    );
  }
}
