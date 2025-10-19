// lib/screens/seed_varieties_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cropsync/main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

class SeedVariety {
  final String cropName;
  final String varietyNameTe;
  final String? varietyNameEn;
  final String? imageUrl;
  final String? detailsTe;
  final String? region;
  final String? sowingPeriod;
  final String? price;

  SeedVariety({
    required this.cropName,
    required this.varietyNameTe,
    this.varietyNameEn,
    this.imageUrl,
    this.detailsTe,
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

  @override
  void initState() {
    super.initState();
    _varietiesFuture = _fetchVarieties();
  }

  Future<List<SeedVariety>> _fetchVarieties() async {
    final response = await supabase.from('seed_varieties').select();
    _allVarieties = (response as List).map((v) {
      return SeedVariety(
        cropName: v['crop_name'],
        varietyNameTe: v['variety_name_te'],
        varietyNameEn: v['variety_name_en'],
        imageUrl: v['image_url'],
        detailsTe: v['details_te'],
        region: v['region'],
        sowingPeriod: v['sowing_period'],
        price: v['price']?.toString(),
      );
    }).toList();
    _filteredVarieties = _allVarieties;
    return _filteredVarieties;
  }

  void _filterVarieties(String? cropName) {
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
          'Seed Varieties',
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
            return const Center(
              child: Text('విత్తన రకాలను లోడ్ చేయడంలో విఫలమైంది.'),
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
    List<String> allFilters = ['అన్నీ', ...cropTypes];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: allFilters.length,
          itemBuilder: (context, index) {
            final crop = allFilters[index];
            final isSelected =
                (_selectedCropFilter == null && crop == 'అన్నీ') ||
                    _selectedCropFilter == crop;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: GestureDetector(
                onTap: () => _filterVarieties(crop == 'అన్నీ' ? null : crop),
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
                  variety.varietyNameTe,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (variety.varietyNameEn != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      variety.varietyNameEn!,
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
                      '₹${variety.price}',
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
