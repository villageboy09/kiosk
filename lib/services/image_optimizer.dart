import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

/// Production-grade Image Optimizer for Agricultural Multimodal Vision AI
/// Preserves high-fidelity foliar pathology details (up to 1024x1024)
/// while eliminating multi-megabyte payloads for low latency.
class ImageOptimizer {
  static const int maxBoundingDimension = 1024;

  /// Optimizes an image file for AI Vision inference
  static Future<OptimizedImageData> optimizeImage(File file) async {
    final rawBytes = await file.readAsBytes();
    return optimizeBytes(rawBytes);
  }

  /// Optimizes raw image bytes for AI Vision inference
  static Future<OptimizedImageData> optimizeBytes(Uint8List bytes) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);

      final origWidth = descriptor.width;
      final origHeight = descriptor.height;

      // Check if resizing is needed
      if (origWidth <= maxBoundingDimension && origHeight <= maxBoundingDimension) {
        return OptimizedImageData(
          bytes: bytes,
          mimeType: _detectMimeType(bytes),
          wasResized: false,
        );
      }

      // Calculate aspect-ratio-preserving dimensions
      int targetWidth;
      int targetHeight;

      if (origWidth >= origHeight) {
        targetWidth = maxBoundingDimension;
        targetHeight = (origHeight * maxBoundingDimension / origWidth).round().clamp(1, maxBoundingDimension);
      } else {
        targetHeight = maxBoundingDimension;
        targetWidth = (origWidth * maxBoundingDimension / origHeight).round().clamp(1, maxBoundingDimension);
      }

      // Hardware-accelerated downsampling via Flutter engine
      final codec = await descriptor.instantiateCodec(
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final resizedBytes = byteData.buffer.asUint8List();
        debugPrint("🖼️ ImageOptimizer: Downscaled from ${origWidth}x$origHeight (${(bytes.length / 1024).toStringAsFixed(1)} KB) "
            "to ${targetWidth}x$targetHeight (${(resizedBytes.length / 1024).toStringAsFixed(1)} KB) -> Locked to 1 Vision Tile (256 tokens)");
        return OptimizedImageData(
          bytes: resizedBytes,
          mimeType: 'image/png',
          wasResized: true,
        );
      }
    } catch (e) {
      debugPrint("ImageOptimizer warning: $e");
    }

    return OptimizedImageData(
      bytes: bytes,
      mimeType: _detectMimeType(bytes),
      wasResized: false,
    );
  }

  static String _detectMimeType(Uint8List bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }
}

class OptimizedImageData {
  final Uint8List bytes;
  final String mimeType;
  final bool wasResized;

  OptimizedImageData({
    required this.bytes,
    required this.mimeType,
    required this.wasResized,
  });

  String get dataUriScheme => 'data:$mimeType;base64,${base64Encode(bytes)}';
}
