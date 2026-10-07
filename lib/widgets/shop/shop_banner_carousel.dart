import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/models/shop_banner.dart';
import 'package:cropsync/theme/app_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Data-driven banner carousel. Renders nothing when there is nothing to show.
class ShopBannerCarousel extends StatefulWidget {
  final List<ShopBanner> banners;
  final ValueChanged<ShopBanner> onTap;

  const ShopBannerCarousel({
    super.key,
    required this.banners,
    required this.onTap,
  });

  @override
  State<ShopBannerCarousel> createState() => _ShopBannerCarouselState();
}

class _ShopBannerCarouselState extends State<ShopBannerCarousel> {
  static const _interval = Duration(seconds: 5);

  final PageController _controller = PageController();
  final Set<String> _failed = {};
  Timer? _timer;
  int _index = 0;

  List<ShopBanner> get _visible => widget.banners
      .where((b) => !_failed.contains(_failKey(widget.banners.indexOf(b), b)))
      .toList();

  static String _failKey(int index, ShopBanner b) => '$index:${b.id}';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant ShopBannerCarousel old) {
    super.didUpdateWidget(old);
    if (!identical(old.banners, widget.banners)) {
      _failed.clear();
      _index = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = null;
    if (_visible.length < 2) return;
    _timer = Timer.periodic(_interval, (_) {
      final count = _visible.length;
      if (!mounted || count < 2 || !_controller.hasClients) return;
      _controller.animateToPage(
        (_index + 1) % count,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
  }

  void _markFailed(String key) {
    if (_failed.contains(key)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _failed.contains(key)) return;
      setState(() {
        _failed.add(key);
        if (_index >= _visible.length) {
          _index = 0;
          if (_controller.hasClients) _controller.jumpToPage(0);
        }
      });
      _startTimer();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    if (visible.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: AspectRatio(
        aspectRatio: kShopBannerAspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n is ScrollStartNotification && n.dragDetails != null) {
                    _pause();
                  } else if (n is ScrollEndNotification && _timer == null) {
                    _startTimer();
                  }
                  return false;
                },
                child: PageView.builder(
                  controller: _controller,
                  itemCount: visible.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final b = visible[i];
                    final fk = _failKey(widget.banners.indexOf(b), b);
                    return _BannerSlide(
                      key: ValueKey(fk),
                      banner: b,
                      onTap: () => widget.onTap(b),
                      onImageFailed: () => _markFailed(fk),
                    );
                  },
                ),
              ),
              if (visible.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 6,
                  child: ExcludeSemantics(
                    child: IgnorePointer(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < visible.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 2.5),
                              width: i == _index ? 14 : 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                    alpha: i == _index ? 0.95 : 0.5),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerSlide extends StatelessWidget {
  final ShopBanner banner;
  final VoidCallback onTap;
  final VoidCallback onImageFailed;

  const _BannerSlide({
    super.key,
    required this.banner,
    required this.onTap,
    required this.onImageFailed,
  });

  bool get _hasText =>
      banner.title.trim().isNotEmpty || banner.subtitle.trim().isNotEmpty;

  static String _resolve(String url) {
    final u = url.trim();
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    return u.startsWith('/')
        ? 'https://kiosk.cropsync.in$u'
        : 'https://kiosk.cropsync.in/$u';
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (banner.isImageBanner) {
      content = CachedNetworkImage(
        imageUrl: _resolve(banner.imageUrl!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: 1000,
        placeholder: (_, __) => const ColoredBox(color: Color(0xFFEFF3F6)),
        errorWidget: (_, __, ___) {
          if (_hasText) return _TextBanner(banner: banner);
          onImageFailed();
          return const ColoredBox(color: Color(0xFFEFF3F6));
        },
      );
    } else {
      content = _TextBanner(banner: banner);
    }
    final tappable = banner.targetType != ShopBannerTarget.none;
    final title = banner.title.trim();
    final slide = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: tappable ? onTap : null,
        child: content,
      ),
    );
    if (!banner.isImageBanner) return slide; // text banners self-describe
    return Semantics(
      label: title.isNotEmpty ? title : context.tr('shop_banner_label'),
      button: tappable,
      image: true,
      excludeSemantics: true,
      onTap: tappable ? onTap : null,
      child: slide,
    );
  }
}

class _TextBanner extends StatelessWidget {
  final ShopBanner banner;
  const _TextBanner({required this.banner});

  @override
  Widget build(BuildContext context) {
    final b = banner;
    TextStyle st(String t, double size, FontWeight w, Color c, double h) =>
        appStyle(context, text: t, size: size, weight: w, color: c, height: h);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [b.bgColor1, b.bgColor2],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 10,
            bottom: 10,
            child: Icon(
              b.icon,
              size: 64,
              color: Colors.white.withValues(alpha: 0.22),
            ),
          ),
          if (b.badge.trim().isNotEmpty)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  b.badge,
                  maxLines: 1,
                  style: st(b.badge, 10.5, FontWeight.w800, b.bgColor1, 1.4),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 72, 16),
            child: LayoutBuilder(
              builder: (context, c) => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: c.maxWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (b.tag.trim().isNotEmpty)
                        Text(
                          b.tag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: st(
                            b.tag,
                            10.5,
                            FontWeight.w700,
                            Colors.white.withValues(alpha: 0.85),
                            1.4,
                          ),
                        ),
                      if (b.title.trim().isNotEmpty)
                        Text(
                          b.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: st(
                              b.title, 17, FontWeight.w800, Colors.white, 1.3),
                        ),
                      if (b.subtitle.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            b.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: st(
                              b.subtitle,
                              12,
                              FontWeight.w500,
                              Colors.white.withValues(alpha: 0.9),
                              1.35,
                            ),
                          ),
                        ),
                      if (b.ctaText.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              b.ctaText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: st(b.ctaText, 11.5, FontWeight.w800,
                                  b.bgColor1, 1.4),
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
