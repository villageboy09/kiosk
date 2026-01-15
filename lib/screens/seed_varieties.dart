// lib/screens/seed_varieties.dart

// ignore_for_file: avoid_print

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

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
  });

  factory SeedVariety.fromJson(Map<String, dynamic> json) {
    return SeedVariety(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      cropName: json['crop_name']?.toString() ?? 'Unknown',
      varietyName: json['variety_name']?.toString() ?? 'Unknown',
      varietyNameSecondary: json['variety_name_secondary']?.toString(),
      imageUrl: json['image_url']?.toString(),
      details: json['details']?.toString(),
      region: json['region']?.toString(),
      sowingPeriod: json['sowing_period']?.toString(),
      testimonialVideoUrl: json['testimonial_video_url']?.toString(),
      price: json['price']?.toString(),
      priceUnit: json['price_unit']?.toString(),
      averageYield: double.tryParse(json['average_yield']?.toString() ?? ''),
      growthDuration: int.tryParse(json['growth_duration']?.toString() ?? ''),
    );
  }
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
  bool _isInit = true;

  @override
  void initState() {
    super.initState();
  }

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

      // Fetch seed varieties from MySQL API
      final response = await ApiService.getSeedVarieties(lang: locale);

      _allVarieties = response.map((v) => SeedVariety.fromJson(v)).toList();

      if (mounted) {
        setState(() {
          _filteredVarieties = _allVarieties;
        });
      }
      return _filteredVarieties;
    } catch (e) {
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
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
            itemCount: _filteredVarieties.length + 1,
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
                    borderRadius: BorderRadius.circular(12),
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

  Widget _buildVarietyCard(SeedVariety variety) {
    return GestureDetector(
      onTap: () => _showVarietyDetails(variety),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
                  if (variety.varietyNameSecondary != null &&
                      variety.varietyNameSecondary != variety.varietyName)
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
                  if (variety.growthDuration != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            '${variety.growthDuration} ${context.tr('days')}',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (variety.price != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '₹${variety.price}${variety.priceUnit != null ? ' / ${_formatPriceUnit(variety.priceUnit!)}' : ''}',
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
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  String _formatPriceUnit(String unit) {
    switch (unit) {
      case 'per_kg':
        return context.tr('per_kg');
      case 'per_packet':
        return context.tr('per_packet');
      case 'per_450g_packet':
        return context.tr('per_450g_packet');
      default:
        return unit;
    }
  }

  void _showVarietyDetails(SeedVariety variety) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: variety.imageUrl ?? '',
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: Colors.grey[100],
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 200,
                          color: Colors.grey[100],
                          child: Icon(Icons.eco_outlined,
                              color: Colors.grey[400], size: 60),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Variety name
                    Text(
                      variety.varietyName,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (variety.varietyNameSecondary != null &&
                        variety.varietyNameSecondary != variety.varietyName)
                      Text(
                        variety.varietyNameSecondary!,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),

                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        variety.cropName,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Price
                    if (variety.price != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.tr('price'),
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              '₹${variety.price}${variety.priceUnit != null ? ' / ${_formatPriceUnit(variety.priceUnit!)}' : ''}',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Details grid
                    _buildDetailsGrid(variety),

                    const SizedBox(height: 20),

                    // Description
                    if (variety.details != null && variety.details!.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('details'),
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            variety.details!,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 20),

                    // Video button
                    if (variety.testimonialVideoUrl != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final url = Uri.parse(variety.testimonialVideoUrl!);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.play_circle_outline,
                              color: Colors.white),
                          label: Text(
                            context.tr('watch_video'),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailsGrid(SeedVariety variety) {
    final details = <Map<String, String>>[];

    if (variety.region != null) {
      details.add({
        'icon': 'location',
        'label': context.tr('region'),
        'value': variety.region!,
      });
    }
    if (variety.sowingPeriod != null) {
      details.add({
        'icon': 'calendar',
        'label': context.tr('sowing_period'),
        'value': variety.sowingPeriod!,
      });
    }
    if (variety.growthDuration != null) {
      details.add({
        'icon': 'time',
        'label': context.tr('growth_duration'),
        'value': '${variety.growthDuration} ${context.tr('days')}',
      });
    }
    if (variety.averageYield != null) {
      details.add({
        'icon': 'yield',
        'label': context.tr('average_yield'),
        'value': '${variety.averageYield} ${context.tr('quintals_per_acre')}',
      });
    }

    if (details.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: details.map((detail) {
        IconData icon;
        switch (detail['icon']) {
          case 'location':
            icon = Icons.location_on_outlined;
            break;
          case 'calendar':
            icon = Icons.calendar_today_outlined;
            break;
          case 'time':
            icon = Icons.schedule_outlined;
            break;
          case 'yield':
            icon = Icons.eco_outlined;
            break;
          default:
            icon = Icons.info_outline;
        }

        return Container(
          width: (MediaQuery.of(context).size.width - 64) / 2,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    detail['label']!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                detail['value']!,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildShimmerEffect() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (context, index) {
          if (index == 0) {
            return SizedBox(
              height: 72,
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
