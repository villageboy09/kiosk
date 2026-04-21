import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SafeNetworkImage extends StatefulWidget {
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

  @override
  State<SafeNetworkImage> createState() => _SafeNetworkImageState();
}

class _SafeNetworkImageState extends State<SafeNetworkImage> {
  Future<Uint8List?>? _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _loadImageBytes(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant SafeNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _imageFuture = _loadImageBytes(widget.imageUrl);
    }
  }

  Future<Uint8List?> _loadImageBytes(String? imageUrl) async {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) return null;

    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final contentType = response.headers['content-type'];
      if (contentType != null &&
          !contentType.toLowerCase().startsWith('image/')) {
        return null;
      }

      final bytes = response.bodyBytes;
      await ui.instantiateImageCodec(bytes);
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Widget _buildPlaceholder() {
    return widget.placeholder ??
        Container(
          color: Colors.grey.shade100,
          alignment: Alignment.center,
          child: Icon(
            Icons.image_outlined,
            color: Colors.grey.shade400,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done || bytes == null) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: _buildPlaceholder(),
          );
        }

        return Image.memory(
          bytes,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          gaplessPlayback: true,
        );
      },
    );
  }
}
