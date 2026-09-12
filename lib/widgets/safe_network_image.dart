import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// High-performance, memory-safe network image widget.
/// Drastically cuts GPU memory usage by decoding images directly to the target
/// display dimensions rather than caching 4K/full-resolution camera bitmaps in RAM.
class SafeNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.width,
    this.height,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  Widget _buildPlaceholder() {
    return placeholder ??
        Container(
          color: const Color(0xFFF1F5F9),
          alignment: Alignment.center,
          child: Icon(
            Icons.image_outlined,
            color: Colors.grey.shade400,
            size: 28,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty || (!url.startsWith('http://') && !url.startsWith('https://'))) {
      return SizedBox(
        width: width,
        height: height,
        child: _buildPlaceholder(),
      );
    }

    // Auto-compute memory cache boundaries (2x display size for retina displays, capped to 800)
    final int calculatedMemWidth = memCacheWidth ??
        ((width != null && width! > 0) ? (width! * 2).round().clamp(100, 800) : 600);
    final int? calculatedMemHeight = memCacheHeight ??
        ((height != null && height! > 0) ? (height! * 2).round().clamp(100, 800) : null);

    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: calculatedMemWidth,
      memCacheHeight: calculatedMemHeight,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, __) => SizedBox(
        width: width,
        height: height,
        child: _buildPlaceholder(),
      ),
      errorWidget: (_, __, ___) => SizedBox(
        width: width,
        height: height,
        child: _buildPlaceholder(),
      ),
    );
  }
}
