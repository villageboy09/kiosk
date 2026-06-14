import 'package:cropsync/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Common AppBar widget for consistent styling across all screens
class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final bool centerTitle;
  final Widget? leading;

  const CommonAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.actions,
    this.centerTitle = false,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: AppTheme.appBarTitle,
      ),
      centerTitle: centerTitle,
      backgroundColor: AppTheme.appBarBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: leading ?? (showBackButton ? IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.appBarText),
        onPressed: () => Navigator.maybePop(context),
      ) : null),
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
      backgroundColor: AppTheme.appBarBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      flexibleSpace: flexibleSpace,
      leading: showBackButton ? IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.appBarText),
        onPressed: () => Navigator.maybePop(context),
      ) : null,
      automaticallyImplyLeading: false,
      title: Text(
        title,
        style: AppTheme.appBarTitle,
      ),
      centerTitle: false,
      actions: actions,
    );
  }
}
