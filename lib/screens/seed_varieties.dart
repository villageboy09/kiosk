import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cropsync/main.dart';
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
      appBar: AppBar(
        title: Text('విత్తన రకాల కేటలాగ్', style: GoogleFonts.lexend()),
      ),
      body: FutureBuilder<List<SeedVariety>>(
        future: _varietiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerEffect();
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text('విత్తన రకాలను లోడ్ చేయడంలో విఫలమైంది.'));
          }

          final cropTypes =
              _allVarieties.map((v) => v.cropName).toSet().toList();

          return Column(
            children: [
              _buildFilterChips(cropTypes),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredVarieties.length,
                  itemBuilder: (context, index) {
                    return _buildVarietyCard(_filteredVarieties[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChips(List<String> cropTypes) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8.0,
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: _selectedCropFilter == null,
            onSelected: (_) => _filterVarieties(null),
          ),
          ...cropTypes.map((crop) => ChoiceChip(
                label: Text(crop),
                selected: _selectedCropFilter == crop,
                onSelected: (_) => _filterVarieties(crop),
              )),
        ],
      ),
    );
  }

  Widget _buildVarietyCard(SeedVariety variety) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (variety.imageUrl != null)
              CachedNetworkImage(
                imageUrl: variety.imageUrl!,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(width: 100, height: 100, color: Colors.grey[200]),
                errorWidget: (context, url, error) => Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey[200],
                    child: const Icon(Icons.eco)),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(variety.varietyNameTe,
                      style: GoogleFonts.lexend(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  if (variety.varietyNameEn != null)
                    Text(variety.varietyNameEn!,
                        style: GoogleFonts.lexend(color: Colors.grey[700])),
                  const SizedBox(height: 8),
                  if (variety.detailsTe != null)
                    Text(variety.detailsTe!,
                        style: GoogleFonts.lexend(fontSize: 14)),
                  const SizedBox(height: 8),
                  if (variety.price != null)
                    Text('ధర: ₹${variety.price}',
                        style: GoogleFonts.lexend(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Container(height: 120, color: Colors.white),
        ),
      ),
    );
  }
}
