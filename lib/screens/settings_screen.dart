// ignore_for_file: deprecated_member_use

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:cropsync/main.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

// Updated data models to include image URLs
class Crop {
  final int id;
  final String name;
  final String? imageUrl;
  Crop({required this.id, required this.name, this.imageUrl});
}

class CropVariety {
  final int id;
  final String name;
  final String? imageUrl;
  CropVariety({required this.id, required this.name, this.imageUrl});
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  bool _isSaving = false;
  bool _isFetchingInitialData = true;

  // Data
  List<Crop> _crops = [];
  List<CropVariety> _varieties = [];
  final List<String> _fieldNames = ['పొలం 1', 'పొలం 2', 'పొలం 3', 'పొలం 4'];

  // Selections
  Crop? _selectedCrop;
  CropVariety? _selectedVariety;
  DateTime _selectedDate = DateTime.now();
  String? _selectedFieldName;

  // Animation
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fetchInitialData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    try {
      final cropsData =
          await supabase.from('crops').select('id, name_te, image_url');
      final List<Crop> loadedCrops = (cropsData as List)
          .map((c) =>
              Crop(id: c['id'], name: c['name_te'], imageUrl: c['image_url']))
          .toList();

      if (mounted) {
        setState(() {
          _crops = loadedCrops;
          _isFetchingInitialData = false;
        });
        _animationController.forward(from: 0.0);
      }
    } catch (e) {
      _showErrorSnackbar('పంటల డేటాను లోడ్ చేయడంలో విఫలమైంది.');
      if (mounted) {
        setState(() {
          _isFetchingInitialData = false;
        });
      }
    }
  }

  Future<void> _fetchVarietiesForCrop(int cropId) async {
    setState(() {
      _varieties = [];
      _selectedVariety = null;
    });
    try {
      final varietiesData = await supabase
          .from('crop_varieties')
          .select('id, variety_name, packet_image_url')
          .eq('crop_id', cropId);

      final List<CropVariety> loadedVarieties = (varietiesData as List)
          .map((v) => CropVariety(
              id: v['id'],
              name: v['variety_name'],
              imageUrl: v['packet_image_url']))
          .toList();

      if (mounted) {
        setState(() {
          _varieties = loadedVarieties;
        });
      }
    } catch (e) {
      _showErrorSnackbar('రకాలను లోడ్ చేయడంలో విఫలమైంది.');
    }
  }

  Future<void> _saveCropSelection() async {
    if (_selectedCrop == null ||
        _selectedVariety == null ||
        _selectedFieldName == null) {
      _showErrorSnackbar('దయచేసి అన్ని వివరాలను ఎంచుకోండి.');
      return;
    }
    setState(() {
      _isSaving = true;
    });

    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final sowingDateResponse = await supabase
          .from('sowing_dates')
          .upsert({'sowing_date': formattedDate}, onConflict: 'sowing_date')
          .select('id')
          .single();
      final sowingDateId = sowingDateResponse['id'];

      final farmerResponse = await supabase
          .from('farmers')
          .select('id')
          .eq('user_id', supabase.auth.currentUser!.id)
          .single();
      final farmerId = farmerResponse['id'];

      await supabase.from('farmer_crop_selections').insert({
        'farmer_id': farmerId,
        'crop_id': _selectedCrop!.id,
        'variety_id': _selectedVariety!.id,
        'sowing_date_id': sowingDateId,
        'field_name': _selectedFieldName,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('పంట ఎంపిక విజయవంతంగా సేవ్ చేయబడింది!'),
              backgroundColor: Colors.green),
        );
        setState(() {
          _selectedCrop = null;
          _selectedVariety = null;
          _selectedFieldName = null;
          _varieties = [];
        });
      }
    } catch (e) {
      _showErrorSnackbar('ఎంపికను సేవ్ చేయడంలో విఫలమైంది: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message, style: GoogleFonts.lexend()),
          backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: _isFetchingInitialData
            ? _buildShimmerEffect()
            : CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(20.0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildAnimatedHeader(
                            index: 0, title: 'పంటను ఎంచుకోండి'),
                        _buildCropSelectionList(),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                          child: _selectedCrop != null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildAnimatedHeader(
                                        index: 1, title: 'రకాన్ని ఎంచుకోండి'),
                                    _buildVarietySelectionList(),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                        _buildAnimatedHeader(index: 2, title: 'పొలం ఎంచుకోండి'),
                        _buildFieldSelectionList(),
                        _buildAnimatedHeader(
                            index: 3, title: 'విత్తే తేదీని ఎంచుకోండి'),
                        _buildDateSelectionCard(),
                        const SizedBox(height: 20),
                        _buildAnimatedSaveButton(index: 4),
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // --- Builder Widgets ---

  Widget _buildAnimatedHeader({required int index, required String title}) {
    return FadeTransition(
      opacity: _animationController,
      child: Padding(
        padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
        child: Text(title,
            style:
                GoogleFonts.lexend(fontSize: 22, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCropSelectionList() {
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _crops.length,
        itemBuilder: (context, index) {
          final crop = _crops[index];
          final isSelected = _selectedCrop?.id == crop.id;
          return _buildSelectionCard(
            title: crop.name,
            imageUrl: crop.imageUrl,
            isSelected: isSelected,
            onTap: () {
              setState(() => _selectedCrop = crop);
              _fetchVarietiesForCrop(crop.id);
            },
          );
        },
      ),
    );
  }

  Widget _buildVarietySelectionList() {
    if (_varieties.isEmpty) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('రకాలు లోడ్ అవుతున్నాయి...')));
    }
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _varieties.length,
        itemBuilder: (context, index) {
          final variety = _varieties[index];
          final isSelected = _selectedVariety?.id == variety.id;
          return _buildSelectionCard(
            title: variety.name,
            imageUrl: variety.imageUrl,
            isSelected: isSelected,
            onTap: () => setState(() => _selectedVariety = variety),
          );
        },
      ),
    );
  }

  Widget _buildFieldSelectionList() {
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _fieldNames.length,
        itemBuilder: (context, index) {
          final fieldName = _fieldNames[index];
          final isSelected = _selectedFieldName == fieldName;
          return _buildSelectionCard(
            title: fieldName,
            isSelected: isSelected,
            onTap: () => setState(() => _selectedFieldName = fieldName),
          );
        },
      ),
    );
  }

  Widget _buildSelectionCard(
      {required String title,
      String? imageUrl,
      required bool isSelected,
      VoidCallback? onTap}) {
    return AspectRatio(
      aspectRatio: 1,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: isSelected ? 8 : 2,
        shadowColor: isSelected
            ? Colors.green.withValues(alpha: 0.5)
            : Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: isSelected ? Colors.green : Colors.grey[300]!, width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          child: GridTile(
            footer: Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.black.withValues(alpha: 0.5),
              child: Text(
                title,
                style: GoogleFonts.lexend(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            child: (imageUrl != null && imageUrl.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(color: Colors.white)),
                    errorWidget: (context, url, error) => const Icon(
                        Icons.agriculture,
                        size: 40,
                        color: Colors.grey),
                  )
                : const Icon(Icons.landscape, size: 40, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelectionCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: EasyDateTimeLine(
          initialDate: _selectedDate,
          onDateChange: (date) => setState(() => _selectedDate = date),
          activeColor: Colors.green[700],
          dayProps: EasyDayProps(
            height: 56.0,
            width: 56.0,
            dayStructure: DayStructure.dayNumDayStr,
            inactiveDayStyle: DayStyle(
              borderRadius: 48.0,
              dayNumStyle: GoogleFonts.lexend(fontSize: 18.0),
              dayStrStyle: GoogleFonts.lexend(),
            ),
            activeDayStyle: DayStyle(
              dayNumStyle: GoogleFonts.lexend(
                  fontSize: 18.0, fontWeight: FontWeight.bold),
              dayStrStyle: GoogleFonts.lexend(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedSaveButton({required int index}) {
    return FadeTransition(
      opacity: _animationController,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: Interval(0.2 * index, 1.0, curve: Curves.easeOut),
        )),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveCropSelection,
            icon: _isSaving ? Container() : const Icon(Icons.save),
            label: _isSaving
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Colors.white))
                : Text('ఎంపికను సేవ్ చేయండి',
                    style: GoogleFonts.lexend(
                        fontSize: 18, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          Container(
              height: 20,
              width: 200,
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 12)),
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              itemBuilder: (context, index) =>
                  const Card(child: AspectRatio(aspectRatio: 1)),
            ),
          ),
          Container(
              height: 20,
              width: 200,
              color: Colors.white,
              margin: const EdgeInsets.only(top: 24, bottom: 12)),
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              itemBuilder: (context, index) =>
                  const Card(child: AspectRatio(aspectRatio: 1)),
            ),
          ),
        ],
      ),
    );
  }
}
