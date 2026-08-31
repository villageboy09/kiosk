import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SafeNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final double? width;
  final double? height;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.width,
    this.height,
  });

  Widget _buildPlaceholder() {
    return placeholder ??
        Container(
          color: const Color(0xFFF1F5F9),
          alignment: Alignment.center,
          child: Icon(
            Icons.image_outlined,
            color: Colors.grey.shade400,
            size: 32,
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

    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
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
