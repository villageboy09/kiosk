import 'package:flutter/foundation.dart' show debugPrint;

/// Seed variety data model and pure helpers (no Flutter dependencies).
class SeedVariety {
  final int id;
  final String cropName;
  final String varietyName;
  final String? varietyNameSecondary;
  final String? imageUrl;
  final String? details;
  final String? region;
  final String? sowingPeriod;
  final String? testimonialVideoUrl;
  final String? price;
  final String? priceUnit;
  final double? averageYield;
  final int? growthDuration;

  /// Per-language variety names (null when the backend did not send them).
  final String? varietyNameEn;
  final String? varietyNameTe;
  final String? varietyNameHi;

  /// Per-language region / sowing period text.
  final String? regionEn;
  final String? regionTe;
  final String? regionHi;
  final String? sowingPeriodEn;
  final String? sowingPeriodTe;
  final String? sowingPeriodHi;

  /// Optional creation time; null when the backend does not send it.
  final DateTime? createdAt;

  SeedVariety({
    required this.id,
    required this.cropName,
    required this.varietyName,
    this.varietyNameSecondary,
    this.imageUrl,
    this.details,
    this.region,
    this.sowingPeriod,
    this.testimonialVideoUrl,
    this.price,
    this.priceUnit,
    this.averageYield,
    this.growthDuration,
    this.varietyNameEn,
    this.varietyNameTe,
    this.varietyNameHi,
    this.regionEn,
    this.regionTe,
    this.regionHi,
    this.sowingPeriodEn,
    this.sowingPeriodTe,
    this.sowingPeriodHi,
    this.createdAt,
  });

  factory SeedVariety.fromJson(Map<String, dynamic> json) {
    String? s(String k) => json[k]?.toString();
    return SeedVariety(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      cropName: json['crop_name']?.toString() ?? '',
      varietyName: json['variety_name']?.toString() ?? '',
      varietyNameSecondary: json['variety_name_secondary']?.toString() ??
          (json['variety_name_en'] != null &&
                  json['variety_name_en'].toString().trim().isNotEmpty &&
                  json['variety_name_en'] != json['variety_name']
              ? json['variety_name_en']?.toString()
              : (json['variety_name_te'] != null &&
                      json['variety_name_te'].toString().trim().isNotEmpty &&
                      json['variety_name_te'] != json['variety_name']
                  ? json['variety_name_te']?.toString()
                  : null)),
      imageUrl: json['image_url']?.toString(),
      details: json['details']?.toString(),
      region: json['region']?.toString(),
      sowingPeriod: json['sowing_period']?.toString(),
      testimonialVideoUrl: json['testimonial_video_url']?.toString(),
      price: json['price']?.toString(),
      priceUnit: json['price_unit']?.toString(),
      averageYield: double.tryParse(json['average_yield']?.toString() ?? ''),
      growthDuration: int.tryParse(json['growth_duration']?.toString() ?? ''),
      varietyNameEn: s('variety_name_en'),
      varietyNameTe: s('variety_name_te'),
      varietyNameHi: s('variety_name_hi'),
      regionEn: s('region_en'),
      regionTe: s('region_te'),
      regionHi: s('region_hi'),
      sowingPeriodEn: s('sowing_period_en'),
      sowingPeriodTe: s('sowing_period_te'),
      sowingPeriodHi: s('sowing_period_hi'),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  /// Parsed price, or null when absent/unparseable.
  double? get priceValue {
    final p = double.tryParse((price ?? '').trim());
    if (p == null || p.isNaN || p.isInfinite) return null;
    return p;
  }

  /// True when a positive price exists (seed can be booked).
  bool get isBookable => (priceValue ?? 0) > 0;

  /// Image URL or empty string when none.
  String get primaryImage => (imageUrl ?? '').trim();

  bool get hasVideo => (testimonialVideoUrl ?? '').trim().isNotEmpty;

  /// Best name for [lang] ('en'/'te'/'hi'); falls back to the server-localised
  /// [varietyName], then English, then any other available name.
  String displayName(String lang) {
    String? pick(String? v) => (v ?? '').trim().isEmpty ? null : v!.trim();
    final byLang = switch (lang) {
      'en' => varietyNameEn,
      'te' => varietyNameTe,
      'hi' => varietyNameHi,
      _ => null,
    };
    return pick(byLang) ??
        pick(varietyName) ??
        pick(varietyNameEn) ??
        pick(varietyNameTe) ??
        pick(varietyNameHi) ??
        varietyName;
  }

  /// Lowercased concatenation of every searchable text field.
  late final String searchHaystack = [
    varietyName,
    varietyNameSecondary,
    varietyNameEn,
    varietyNameTe,
    varietyNameHi,
    cropName,
    region,
    regionEn,
    regionTe,
    regionHi,
    sowingPeriod,
    sowingPeriodEn,
    sowingPeriodTe,
    sowingPeriodHi,
  ].where((e) => e != null && e.trim().isNotEmpty).join(' ').toLowerCase();
}

/// Removes duplicate ids (SQL LEFT JOIN can repeat a variety). Keeps the first
/// row that has a price, else the first row seen. Order of first appearance is
/// preserved. Rows with an unparseable id (<= 0) are dropped.
List<SeedVariety> dedupeSeedVarieties(List<SeedVariety> items) {
  final byId = <int, SeedVariety>{};
  for (final v in items) {
    if (v.id <= 0) {
      // Id 0 means the id could not be parsed: such a row cannot be keyed,
      // wishlisted or booked, and must never be merged with another.
      debugPrint('dedupeSeedVarieties: dropping row with invalid id');
      continue;
    }
    final existing = byId[v.id];
    if (existing == null) {
      byId[v.id] = v;
    } else if (!existing.isBookable && v.isBookable) {
      byId[v.id] = v; // replaces value, keeps original insertion position
    }
  }
  return byId.values.toList();
}
