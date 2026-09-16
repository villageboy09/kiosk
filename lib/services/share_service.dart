import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:easy_localization/easy_localization.dart';

/// Centralized CropSync Sharing Service
/// Handles downloading of item images and formatting clean, localized share messages
/// with universal deep links that open in-app or fall back to the Play Store.
class ShareService {
  static const String baseShareUrl = 'https://kiosk.cropsync.in/api/share.php';

  /// Downloads and caches an image to the temporary directory for native sharing.
  /// Returns null if the image URL is empty, invalid, or fails to download.
  static Future<File?> downloadImageForShare(String? imageUrl) async {
    if (imageUrl == null || imageUrl.trim().isEmpty) return null;
    String url = imageUrl.trim();

    // Resolve relative URLs
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.startsWith('/')) {
        url = 'https://kiosk.cropsync.in$url';
      } else {
        url = 'https://kiosk.cropsync.in/$url';
      }
    }

    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;

      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        
        // Extract extension or default to .jpg
        String ext = '.jpg';
        final lowerUrl = url.toLowerCase();
        if (lowerUrl.contains('.png')) {
          ext = '.png';
        } else if (lowerUrl.contains('.webp')) {
          ext = '.webp';
        }

        final file = File('${tempDir.path}/cropsync_share_${DateTime.now().millisecondsSinceEpoch}$ext');
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
    } catch (e) {
      debugPrint('ShareService: Image download failed or timed out: $e');
    }
    return null;
  }

  /// Builds universal web share URL with query parameters
  static String buildWebShareUrl({
    required String type,
    String? id,
    String? crop,
    String? commodity,
    String? title,
    String? desc,
    String? imageUrl,
    String? price,
    String? lang,
    Map<String, String>? extra,
  }) {
    final params = <String, String>{
      'type': type,
      if (id != null && id.isNotEmpty) 'id': id,
      if (crop != null && crop.isNotEmpty) 'crop': crop,
      if (commodity != null && commodity.isNotEmpty) 'commodity': commodity,
      if (title != null && title.isNotEmpty) 'title': title,
      if (desc != null && desc.isNotEmpty) 'desc': desc,
      if (imageUrl != null && imageUrl.isNotEmpty) 'img': imageUrl,
      if (price != null && price.isNotEmpty) 'price': price,
      if (lang != null && lang.isNotEmpty) 'lang': lang,
      if (extra != null) ...extra,
    };

    final uri = Uri.parse(baseShareUrl).replace(queryParameters: params);
    return uri.toString();
  }

  /// Universal share method with image attachment, localized text, and deep link
  static Future<void> shareItem({
    required BuildContext context,
    required String type, // 'shop', 'advisory', 'market', 'seed', 'news', 'reel'
    required String title,
    String? description,
    String? price,
    String? imageUrl,
    String? id,
    String? crop,
    String? commodity,
    Map<String, String>? extraParams,
  }) async {
    final lang = context.locale.languageCode;

    // Generate universal link
    final shareUrl = buildWebShareUrl(
      type: type,
      id: id,
      crop: crop,
      commodity: commodity,
      title: title,
      desc: description,
      imageUrl: imageUrl,
      price: price,
      lang: lang,
      extra: extraParams,
    );

    // Build clean, non-clumsy share message
    final buffer = StringBuffer();
    buffer.writeln(title);
    
    if (price != null && price.trim().isNotEmpty) {
      buffer.writeln('Price: $price');
    }

    if (description != null && description.trim().isNotEmpty) {
      // Shorten description if too long
      final cleanDesc = description.trim();
      final snippet = cleanDesc.length > 140 ? '${cleanDesc.substring(0, 137)}...' : cleanDesc;
      buffer.writeln(snippet);
    }

    buffer.writeln();
    buffer.writeln(context.tr('share_view_on_cropsync'));
    buffer.write(shareUrl);

    final shareText = buffer.toString();

    // Fetch respective image
    File? imageFile;
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      imageFile = await downloadImageForShare(imageUrl);
    }

    try {
      if (imageFile != null && await imageFile.exists()) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(imageFile.path)],
            text: shareText,
            subject: title,
          ),
        );
      } else {
        await SharePlus.instance.share(
          ShareParams(
            text: shareText,
            subject: title,
          ),
        );
      }
    } catch (e) {
      debugPrint('ShareService error: $e');
      // Fallback
      await SharePlus.instance.share(ShareParams(text: shareText, subject: title));
    }
  }
}
