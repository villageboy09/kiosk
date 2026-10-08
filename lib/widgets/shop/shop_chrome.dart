import 'package:cropsync/widgets/shop/shop_circle_button.dart';
import 'package:cropsync/theme/app_text.dart';
import 'package:cropsync/widgets/shop/shop_filters.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Round translucent back button used as the shop app bar leading widget.
class ShopCircleBackButton extends StatelessWidget {
  final VoidCallback onPressed;
  const ShopCircleBackButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ShopCircleButton(
        icon: Icons.arrow_back_rounded,
        label: MaterialLocalizations.of(context).backButtonTooltip,
        onTap: onPressed,
      ),
    );
  }
}

/// Centered single-line app bar title.
class ShopAppBarTitle extends StatelessWidget {
  final String title;
  const ShopAppBarTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: appStyle(
        context,
        text: title,
        size: 18,
        weight: FontWeight.w800,
        color: kShopInk,
        height: 1.3,
      ),
    );
  }
}

/// Pinned white sliver app bar: back button, centered [title], optional
/// [trailing] (a 48px-wide action). Leading/actions are 56px wide so the
/// title stays optically centered.
SliverAppBar buildShopAppBar(
  BuildContext context, {
  required String title,
  required VoidCallback onBack,
  Widget? trailing,
}) {
  return SliverAppBar(
    pinned: true,
    toolbarHeight: 56,
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    titleSpacing: 0,
    leadingWidth: 60,
    leading: ShopCircleBackButton(onPressed: onBack),
    title: ShopAppBarTitle(title),
    actions: [
      if (trailing != null) ...[trailing, const SizedBox(width: 8)] else
        const SizedBox(width: 56),
    ],
  );
}

/// 44px grey search field + filter button (with an "active" dot).
/// Contains exactly one [TextField].
class ShopSearchRow extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onFilterTap;
  final bool filterActive;
  final VoidCallback onClear;

  const ShopSearchRow({
    super.key,
    required this.controller,
    required this.hint,
    required this.onFilterTap,
    required this.onClear,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.filterActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = controller.text;
    OutlineInputBorder border() => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                textInputAction: TextInputAction.search,
                style: appStyle(
                  context,
                  text: text,
                  size: 14,
                  color: kShopInk,
                  height: 1.3,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: kShopGrey,
                  isDense: true,
                  hintText: hint,
                  hintStyle: appStyle(
                    context,
                    text: hint,
                    size: 14,
                    color: const Color(0xFF94A3B8),
                    height: 1.3,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 20, color: Color(0xFF64748B)),
                  suffixIcon: text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: context.tr('shop_clear'),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: onClear,
                        ),
                  border: border(),
                  enabledBorder: border(),
                  focusedBorder: border(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: context.tr('shop_filters'),
            child: Material(
              color: kShopGrey,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onFilterTap,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.tune_rounded, size: 22, color: kShopInk),
                      if (filterActive)
                        Positioned(
                          top: 9,
                          right: 9,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: kShopGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
