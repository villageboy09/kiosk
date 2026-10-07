import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Model representing a verified copyright-free / open-license reference image.
class CopyrightFreeReferencePhoto {
  final String url;
  final String title;
  final String license; // e.g., "Public Domain", "Creative Commons CC-BY 4.0"
  final String source; // e.g., "Wikimedia Commons", "PlantVillage Open Dataset"
  final bool isHealthy;
  final String? credit; // Per-file author/artist when known (HTML stripped).

  const CopyrightFreeReferencePhoto({
    required this.url,
    required this.title,
    this.license = 'Open License (CC-BY / Public Domain)',
    this.source = 'Wikimedia Commons / Open Access',
    this.isHealthy = false,
    this.credit,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'license': license,
        'source': source,
        'isHealthy': isHealthy,
        if (credit != null) 'credit': credit,
      };
}

/// Service to fetch real, copyright-free plant pathology reference images
/// from the live Wikimedia Commons API.
class CopyrightFreeReferenceService {
  // In-memory cache to prevent duplicate network calls during the user's session.
  // Only non-empty results are stored.
  static final Map<String, List<CopyrightFreeReferencePhoto>> _cache = {};

  static const String _userAgent = 'CropSync/1.0 (https://kiosk.cropsync.in)';
  static const int _maxResults = 4;
  static const Set<String> _allowedMimes = {'image/jpeg', 'image/png', 'image/webp'};
  static const Set<String> _stopWords = {'the', 'and', 'of', 'on', 'in', 'a', 'plant', 'leaf', 'disease'};

  /// Retrieves reference images via the Wikimedia Commons search API.
  /// Tries "<crop> <problem>", then "<crop> <problem> leaf disease", then crop-only
  /// (the crop-only query requires the crop in the title). If [problemName] is
  /// empty only the crop is searched; if [cropName] is empty nothing is searched.
  /// Returns an empty list if nothing valid is found (no fabricated fallbacks).
  /// [client] may be injected for testing.
  static Future<List<CopyrightFreeReferencePhoto>> fetchReferences({
    String? cropName,
    String? problemName,
    bool isHealthy = false,
    http.Client? client,
  }) async {
    final crop = cropName?.trim() ?? '';
    final problem = problemName?.trim() ?? '';
    if (crop.isEmpty) return const [];

    final cacheKey = '${crop.toLowerCase()}_${problem.toLowerCase()}_$isHealthy';
    final cached = _cache[cacheKey];
    if (cached != null && cached.isNotEmpty) return cached;

    final List<String> queries;
    if (isHealthy) {
      queries = ['$crop healthy leaf', '$crop plant'];
    } else if (problem.isEmpty) {
      queries = [crop];
    } else {
      queries = ['$crop $problem', '$crop $problem leaf disease', crop];
    }

    final cropKeywords = _keywords(crop);
    final keywords = _keywords(problem.isEmpty ? crop : '$crop $problem');
    final hasProblemKeywords = keywords.length > cropKeywords.length;
    final httpClient = client ?? http.Client();
    try {
      for (var i = 0; i < queries.length; i++) {
        // The last (broadest) query must at least match the crop in the title.
        final isBroadest = i == queries.length - 1 && queries.length > 1;
        final photos = await _searchCommons(
          httpClient,
          queries[i],
          keywords,
          isHealthy,
          cropKeywords: isBroadest ? cropKeywords : const [],
          preferHigherScore: hasProblemKeywords,
        );
        if (photos.isNotEmpty) {
          _cache[cacheKey] = photos;
          return photos;
        }
      }
    } finally {
      if (client == null) httpClient.close();
    }
    return const [];
  }

  static Future<List<CopyrightFreeReferencePhoto>> _searchCommons(
    http.Client client,
    String query,
    List<String> keywords,
    bool isHealthy, {
    List<String> cropKeywords = const [],
    bool preferHigherScore = false,
  }) async {
    try {
      final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {
        'action': 'query',
        'format': 'json',
        'generator': 'search',
        'gsrnamespace': '6',
        'gsrsearch': query,
        'gsrlimit': '8',
        'prop': 'imageinfo',
        'iiprop': 'url|mime|extmetadata',
        'iiextmetadatafilter': 'LicenseShortName|Artist',
        'iiurlwidth': '720',
      });

      final response = await client
          .get(uri, headers: const {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        debugPrint('CopyrightFreeReferenceService: HTTP ${response.statusCode} for "$query"');
        return const [];
      }

      final data = jsonDecode(response.body);
      final pages = data['query']?['pages'] as Map<String, dynamic>?;
      if (pages == null) return const [];

      final ranked = <_Candidate>[];
      for (final page in pages.values) {
        final imageInfoList = page['imageinfo'] as List?;
        if (imageInfoList == null || imageInfoList.isEmpty) continue;
        final info = imageInfoList.first as Map<String, dynamic>;
        final mime = info['mime']?.toString() ?? '';
        final thumbUrl = info['thumburl']?.toString() ?? info['url']?.toString();
        if (thumbUrl == null || !_allowedMimes.contains(mime)) continue;

        final title = (page['title']?.toString() ?? '')
            .replaceFirst('File:', '')
            .replaceAll('_', ' ');
        final lowerTitle = title.toLowerCase();
        final score = _score(lowerTitle, keywords);
        if (score < 1) continue;
        if (cropKeywords.isNotEmpty && _score(lowerTitle, cropKeywords) < 1) continue;
        final index = (page['index'] as num?)?.toInt() ?? 1 << 20;

        final meta = info['extmetadata'];
        final licenseName = _metaValue(meta, 'LicenseShortName');
        final artist = _metaValue(meta, 'Artist');

        ranked.add(_Candidate(
          score,
          index,
          CopyrightFreeReferencePhoto(
            url: thumbUrl,
            title: title.isEmpty ? query : title,
            license: licenseName ?? 'Creative Commons / Public Domain',
            source: 'Wikimedia Commons',
            isHealthy: isHealthy,
            credit: artist,
          ),
        ));
      }

      // Prefer score >= 2 when the problem has keywords, if that leaves results.
      var accepted = ranked;
      if (preferHigherScore) {
        final strong = ranked.where((c) => c.score >= 2).toList();
        if (strong.isNotEmpty) accepted = strong;
      }
      // Higher keyword score first, then Commons search relevance order.
      accepted.sort((a, b) =>
          a.score != b.score ? b.score.compareTo(a.score) : a.index.compareTo(b.index));
      return accepted.take(_maxResults).map((e) => e.photo).toList();
    } catch (e) {
      debugPrint('CopyrightFreeReferenceService: search "$query" failed: $e');
      return const [];
    }
  }

  static int _score(String lowerTitle, List<String> keywords) => keywords
      .where((w) => RegExp(r'\b' + RegExp.escape(w) + r'\b').hasMatch(lowerTitle))
      .length;

  /// Reads `extmetadata[key].value`, strips HTML tags; null if absent/empty.
  static String? _metaValue(dynamic meta, String key) {
    if (meta is! Map) return null;
    final raw = meta[key];
    final value = raw is Map ? raw['value']?.toString() : null;
    if (value == null) return null;
    final cleaned = value
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  static List<String> _keywords(String text) {
    final words = text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length > 2 && !_stopWords.contains(w))
        .toSet()
        .toList();
    // Rice and paddy are used interchangeably in titles.
    if (words.contains('paddy') && !words.contains('rice')) words.add('rice');
    return words;
  }
}

class _Candidate {
  final int score;
  final int index;
  final CopyrightFreeReferencePhoto photo;
  const _Candidate(this.score, this.index, this.photo);
}
