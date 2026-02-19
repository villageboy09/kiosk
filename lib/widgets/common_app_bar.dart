import 'package:cropsync/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Common AppBar widget for consistent styling across all screens
class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final bool useGradient;
  final bool centerTitle;
  final Widget? leading;
  final double elevation;

  const CommonAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.actions,
    this.useGradient = true,
    this.centerTitle = true,
    this.leading,
    this.elevation = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: AppTheme.appBarTitle,
      ),
      centerTitle: centerTitle,
      backgroundColor: useGradient ? Colors.transparent : AppTheme.primary,
      elevation: elevation,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: useGradient
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            )
          : null,
      leading: leading,
      automaticallyImplyLeading: false,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Sliver version of CommonAppBar for screens using CustomScrollView
class CommonSliverAppBar extends StatelessWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final bool floating;
  final bool snap;
  final bool pinned;
  final Widget? flexibleSpace;
  final double? expandedHeight;

  const CommonSliverAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.actions,
    this.floating = true,
    this.snap = true,
    this.pinned = false,
    this.flexibleSpace,
    this.expandedHeight,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: floating,
      snap: snap,
      pinned: pinned,
      expandedHeight: expandedHeight,
      backgroundColor: AppTheme.primary,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: flexibleSpace ??
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
      leading: null,
      automaticallyImplyLeading: false,
      title: Text(
        title,
        style: AppTheme.appBarTitle,
      ),
      centerTitle: true,
      actions: actions,
    );
  }
}
