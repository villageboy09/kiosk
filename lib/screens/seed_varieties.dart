// ignore_for_file: avoid_print

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cropsync/main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:easy_localization/easy_localization.dart';

class SeedVariety {
  final String cropName;
  final String varietyName;
  final String? varietyNameSecondary;
  final String? imageUrl;
  final String? details;
  final String? region;
  final String? sowingPeriod;
  final String? price;

  SeedVariety({
    required this.cropName,
    required this.varietyName,
    this.varietyNameSecondary,
    this.imageUrl,
    this.details,
    this.region,
    this.sowingPeriod,
    this.price,
  });
}

class SeedVarietiesScreen extends StatefulWidget {
  const SeedVarietiesScreen({super.key});

  @override
  State<SeedVarietiesScreen> createState() => _SeedVarietiesScreenState();
}

class _SeedVarietiesScreenState extends State<SeedVarietiesScreen> {
  late Future<List<SeedVariety>> _varietiesFuture;
  List<SeedVariety> _allVarieties = [];
  List<SeedVariety> _filteredVarieties = [];
  String? _selectedCropFilter;
  bool _isInit = true; // Flag for didChangeDependencies

  @override
  void initState() {
    super.initState();
    // Do not fetch here, context is not ready
  }

  // FIX 1: Use didChangeDependencies to safely access context
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _varietiesFuture = _fetchVarieties();
      _isInit = false;
    }
  }

  String _getLocaleField(String locale) {
    switch (locale) {
      case 'hi':
        return 'hi';
      case 'te':
        return 'te';
      default:
        return 'en';
    }
  }

  Future<List<SeedVariety>> _fetchVarieties() async {
    try {
      final locale = _getLocaleField(context.locale.languageCode);
      final varietyNameField = 'variety_name_$locale';
      final detailsField = 'details_$locale';

      // --- FIX: We must use two queries ---

      // 1. Fetch all crops and put them in a Map for easy lookup.
      // We assume the join key is the English name.
      final cropsResponse =
          await supabase.from('crops').select('name_te, name_en, name_hi');

      final Map<String, dynamic> cropDataMap = {
        for (var crop in cropsResponse as List)
          // Key: 'Rice', Value: {name_te: 'వరి', name_en: 'Rice', ...}
          (crop['name_en'] as String): crop,
      };

      // 2. Fetch all seed varieties
      final response = await supabase.from('seed_varieties').select(
          '$varietyNameField, variety_name_en, variety_name_hi, image_url, $detailsField, details_en, details_hi, region, sowing_period, price, crop_name'); // We must select 'crop_name' to use as our key

      _allVarieties = (response as List).map((v) {
        // 3. Manually "join" the data using our Map
        final cropData =
            cropDataMap[v['crop_name']]; // e.g., cropDataMap['Rice']

        String cropName = 'Unknown'; // Default

        if (cropData != null) {
          cropName = cropData['name_en'] ?? 'Unknown';
          if (locale == 'hi' && cropData['name_hi'] != null) {
            cropName = cropData['name_hi'];
          } else if (locale == 'te' && cropData['name_te'] != null) {
            cropName = cropData['name_te'];
          }
        }

        // Get localized variety name, with secondary as fallback
        String varietyName =
            v[varietyNameField] ?? v['variety_name_en'] ?? 'Unknown';
        String? varietyNameSecondary;
        if (locale == 'te' && v['variety_name_en'] != null) {
          varietyNameSecondary = v['variety_name_en'];
        } else if (locale == 'hi' && v['variety_name_en'] != null) {
          varietyNameSecondary = v['variety_name_en'];
        }

        return SeedVariety(
          cropName: cropName, // The localized name
          varietyName: varietyName,
          varietyNameSecondary: varietyNameSecondary,
          imageUrl: v['image_url'],
          details: v[detailsField] ?? v['details_en'],
          region: v['region'],
          sowingPeriod: v['sowing_period'],
          price: v['price']?.toString(),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _filteredVarieties = _allVarieties;
        });
      }
      return _filteredVarieties;
    } catch (e) {
      // Add a print here to see the actual error in your console
      print('Error fetching varieties: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('load_error'))),
        );
      }
      rethrow;
    }
  }

  void _filterVarieties(String? cropName) {
    if (mounted) {
      setState(() {
        _selectedCropFilter = cropName;
        if (cropName == null) {
          _filteredVarieties = _allVarieties;
        } else {
          _filteredVarieties =
              _allVarieties.where((v) => v.cropName == cropName).toList();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // A slightly off-white background
      appBar: AppBar(
        // ### REDESIGNED APPBAR ###
        elevation: 0,
        backgroundColor: Colors.grey[100],
        centerTitle: true,
        title: Text(
          context.tr('seed_varieties_title'),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        // ### CUSTOM BACK BUTTON ###
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.black87,
                size: 18,
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<SeedVariety>>(
        future: _varietiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerEffect();
          }
          if (snapshot.hasError) {
            // Log the error to console for debugging
            print('Error in FutureBuilder: ${snapshot.error}');
            return Center(
              child: Text(
                context.tr('load_error'),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.red),
              ),
            );
          }

          final cropTypes =
              _allVarieties.map((v) => v.cropName).toSet().toList();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filteredVarieties.length + 1, // +1 for the filter bar
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildFilterChips(cropTypes);
              }
              final variety = _filteredVarieties[index - 1];
              return _buildVarietyCard(variety);
            },
          );
        },
      ),
    );
  }

  // ### REDESIGNED FILTER SECTION ###
  Widget _buildFilterChips(List<String> cropTypes) {
    List<String> allFilters = [context.tr('all_filter'), ...cropTypes];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: allFilters.length,
          itemBuilder: (context, index) {
            final crop = allFilters[index];
            final isSelected = (_selectedCropFilter == null &&
                    crop == context.tr('all_filter')) ||
                _selectedCropFilter == crop;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: GestureDetector(
                onTap: () => _filterVarieties(
                    crop == context.tr('all_filter') ? null : crop),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.black87 : Colors.white,
                    borderRadius:
                        BorderRadius.circular(12), // Consistent rounding
                    border: Border.all(
                      color: isSelected ? Colors.black87 : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    crop,
                    style: GoogleFonts.poppins(
                      color: isSelected ? Colors.white : Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ### REDESIGNED FLAT CARD ###
  Widget _buildVarietyCard(SeedVariety variety) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // Consistent rounding
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: variety.imageUrl ?? '',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  Container(width: 80, height: 80, color: Colors.grey[100]),
              errorWidget: (context, url, error) => Container(
                width: 80,
                height: 80,
                color: Colors.grey[100],
                child: Icon(Icons.eco_outlined, color: Colors.grey[400]),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  variety.varietyName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (variety.varietyNameSecondary != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      variety.varietyNameSecondary!,
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ),
                if (variety.price != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      context.tr('price_label',
                          namedArgs: {'price': variety.price!}),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ### UPDATED SHIMMER EFFECT ###
  Widget _buildShimmerEffect() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6, // Show more shimmer items
        itemBuilder: (context, index) {
          // Shimmer for filter chips
          if (index == 0) {
            return SizedBox(
              height: 72, // Approximates padding + chip height
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                itemBuilder: (_, __) => Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 100,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            );
          }
          // Shimmer for cards
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: double.infinity,
                          height: 18,
                          color: Colors.white),
                      const SizedBox(height: 8),
                      Container(width: 120, height: 14, color: Colors.white),
                      const SizedBox(height: 10),
                      Container(width: 60, height: 16, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
