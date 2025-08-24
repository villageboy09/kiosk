// lib/settings_screen_airbnb_style.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cropsync/main.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:math' as math;

// --- DATA MODELS ---
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

class FarmerSelection {
  final int selectionId;
  final String fieldName;
  final String cropName;
  final String? cropImageUrl;
  final String varietyName;
  final DateTime sowingDate;
  FarmerSelection({
    required this.selectionId,
    required this.fieldName,
    required this.cropName,
    this.cropImageUrl,
    required this.varietyName,
    required this.sowingDate,
  });
}

// --- MAIN WIDGET ---
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;

  late AnimationController _backgroundController;
  late AnimationController _viewSwitchController;
  late Animation<double> _backgroundAnimation;

  late List<Widget> _views;

  @override
  void initState() {
    super.initState();

    _views = [
      const AddNewCropSelectionView(key: ValueKey('add_crop')),
      MyFieldsView(key: UniqueKey()),
    ];

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _viewSwitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _backgroundAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_backgroundController);
    _viewSwitchController.forward();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _viewSwitchController.dispose();
    super.dispose();
  }

  void _onTabChanged(int newIndex) {
    if (_selectedIndex != newIndex) {
      setState(() {
        _selectedIndex = newIndex;
        if (newIndex == 1) {
          _views[1] = MyFieldsView(key: UniqueKey());
        } else if (newIndex == 0) {
          _views[0] = const AddNewCropSelectionView(key: ValueKey('add_crop'));
        }
      });
      _viewSwitchController.reset();
      _viewSwitchController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                          const Color(0xFFE8F5E8),
                          const Color(0xFFF0F8F0),
                          math.sin(_backgroundAnimation.value * 2 * math.pi) *
                                  0.5 +
                              0.5)!
                      .withOpacity(0.8),
                  Color.lerp(
                          const Color(0xFFF8F9FA),
                          const Color(0xFFE6F7E6),
                          math.cos(_backgroundAnimation.value * 2 * math.pi) *
                                  0.5 +
                              0.5)!
                      .withOpacity(0.8),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildCleanAppBar(),
                  _buildSegmentedControl(),
                  Expanded(
                    child: FadeTransition(
                      opacity: _viewSwitchController,
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: _views,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCleanAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, (1 - value) * -30),
            child: Opacity(
              opacity: value,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[600],
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.agriculture,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Crop Details',
                      style: GoogleFonts.lexend(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          segments: [
            ButtonSegment<int>(
              value: 0,
              label: Text('Add Crop', style: GoogleFonts.lexend(fontSize: 15)),
              icon: const Icon(Icons.add_circle_outline, size: 22),
            ),
            ButtonSegment<int>(
              value: 1,
              label: Text('My Fields', style: GoogleFonts.lexend(fontSize: 15)),
              icon: Icon(
                _selectedIndex == 1
                    ? Icons.check_circle
                    : Icons.grid_view_rounded,
                size: 22,
              ),
            ),
          ],
          selected: {_selectedIndex},
          onSelectionChanged: (Set<int> newSelection) {
            _onTabChanged(newSelection.first);
          },
          style: SegmentedButton.styleFrom(
            backgroundColor: Colors.green.withOpacity(0.1),
            foregroundColor: Colors.green[800],
            selectedBackgroundColor: Colors.green[600],
            selectedForegroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: BorderSide(color: Colors.green.withOpacity(0.2)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

// --- TAB 1: ADD NEW CROP VIEW ---
class AddNewCropSelectionView extends StatefulWidget {
  const AddNewCropSelectionView({super.key});
  @override
  State<AddNewCropSelectionView> createState() =>
      _AddNewCropSelectionViewState();
}

class _AddNewCropSelectionViewState extends State<AddNewCropSelectionView>
    with TickerProviderStateMixin {
  bool _isSaving = false;
  bool _isFetchingInitialData = true;
  List<Crop> _crops = [];
  List<CropVariety> _varieties = [];
  final List<String> _fieldNames = ['Field 1', 'Field 2', 'Field 3', 'Field 4'];
  Set<String> _usedFieldNames = {};
  Crop? _selectedCrop;
  CropVariety? _selectedVariety;
  DateTime _selectedDate = DateTime.now();
  String? _selectedFieldName;
  late AnimationController _sectionEntranceController;
  late AnimationController _saveButtonController;
  @override
  void initState() {
    super.initState();
    _sectionEntranceController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _saveButtonController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fetchInitialData();
  }

  @override
  void dispose() {
    _sectionEntranceController.dispose();
    _saveButtonController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    try {
      await Future.delayed(const Duration(milliseconds: 600));
      final cropsData =
          await supabase.from('crops').select('id, name_te, image_url');
      final List<Crop> loadedCrops = (cropsData as List)
          .map((c) =>
              Crop(id: c['id'], name: c['name_te'], imageUrl: c['image_url']))
          .toList();
      final farmerResponse = await supabase
          .from('farmers')
          .select('id')
          .eq('user_id', supabase.auth.currentUser!.id)
          .single();
      final farmerId = farmerResponse['id'];
      final usedFieldsData = await supabase
          .from('farmer_crop_selections')
          .select('field_name')
          .eq('farmer_id', farmerId);
      final Set<String> usedNames = (usedFieldsData as List)
          .map((row) => row['field_name'] as String)
          .toSet();

      if (mounted) {
        setState(() {
          _crops = loadedCrops;
          _usedFieldNames = usedNames;
          _isFetchingInitialData = false;
        });
        _sectionEntranceController.forward();
      }
    } catch (e) {
      _showFeedbackSnackbar('Failed to load initial data.', false);
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
      _showFeedbackSnackbar('Failed to load varieties.', false);
    }
  }

  Future<void> _saveCropSelection() async {
    if (_selectedCrop == null ||
        _selectedVariety == null ||
        _selectedFieldName == null) {
      _showFeedbackSnackbar('Please select all details.', false);
      return;
    }
    if (_usedFieldNames.contains(_selectedFieldName)) {
      _showFeedbackSnackbar(
          'This field is already in use. Please select another field.', false);
      return;
    }
    _saveButtonController.forward();
    setState(() => _isSaving = true);
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
        _showFeedbackSnackbar('Crop selection saved successfully!', true);
        setState(() {
          _usedFieldNames.add(_selectedFieldName!);
          _selectedCrop = null;
          _selectedVariety = null;
          _selectedFieldName = null;
          _varieties = [];
        });
        await _saveButtonController.reverse();
      }
    } catch (e) {
      _showFeedbackSnackbar('Failed to save selection: ${e.toString()}', false);
      _saveButtonController.reverse();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showFeedbackSnackbar(String message, bool isSuccess) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          Icon(isSuccess ? Icons.check_circle : Icons.error_outline,
              color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message,
                  style: GoogleFonts.lexend(fontSize: 14, color: Colors.white)))
        ]),
        backgroundColor: isSuccess ? Colors.green[600] : Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetchingInitialData) {
      return _buildSimpleShimmer();
    }
    return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSection(
              index: 0,
              title: 'Select Crop',
              icon: Icons.eco_outlined,
              child: _buildCropGrid()),
          AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: _selectedCrop != null
                  ? _buildSection(
                      index: 1,
                      title: 'Select Variety',
                      icon: Icons.grain_outlined,
                      child: _buildVarietyGrid())
                  : const SizedBox.shrink()),
          _buildSection(
              index: 2,
              title: 'Select Field',
              icon: Icons.landscape_outlined,
              child: _buildFieldGrid()),
          _buildSection(
              index: 3,
              title: 'Select Sowing Date',
              icon: Icons.calendar_today_outlined,
              child: _buildSimpleDateSelector()),
          const SizedBox(height: 20),
          _buildPrimarySaveButton(),
          const SizedBox(height: 20)
        ]));
  }

  Widget _buildFieldGrid() {
    return SizedBox(
        height: 160,
        child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _fieldNames.length,
            itemBuilder: (context, index) {
              final fieldName = _fieldNames[index];
              final bool isUsed = _usedFieldNames.contains(fieldName);
              return _buildSelectionCard(
                  title: fieldName,
                  isSelected: _selectedFieldName == fieldName,
                  isUsed: isUsed,
                  onTap: isUsed
                      ? null
                      : () {
                          setState(() => _selectedFieldName = fieldName);
                        });
            }));
  }

  Widget _buildSelectionCard(
      {required String title,
      String? imageUrl,
      required bool isSelected,
      VoidCallback? onTap,
      bool isUsed = false}) {
    return Container(
        width: 130,
        margin: const EdgeInsets.only(right: 16),
        child: Opacity(
            opacity: isUsed ? 0.6 : 1.0,
            child: Material(
                elevation: isSelected ? 6 : 2,
                borderRadius: BorderRadius.circular(16),
                shadowColor:
                    isSelected ? Colors.green.withOpacity(0.3) : Colors.black12,
                child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: isSelected
                            ? Colors.green[50]
                            : (isUsed ? Colors.grey[200] : Colors.white),
                        border: Border.all(
                            color: isSelected
                                ? Colors.green[300]!
                                : (isUsed
                                    ? Colors.grey[400]!
                                    : Colors.grey[200]!),
                            width: 1.5)),
                    child: InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(alignment: Alignment.center, children: [
                          ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                  width: double.infinity,
                                  height: double.infinity,
                                  child: (imageUrl != null && imageUrl.isNotEmpty)
                                      ? CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                              color: Colors.grey[100],
                                              child: const Center(
                                                  child: CircularProgressIndicator(
                                                      strokeWidth: 1.5,
                                                      color: Colors.green))),
                                          errorWidget: (context, url, error) =>
                                              Container(
                                                  color: Colors.grey[100],
                                                  child: const Icon(
                                                      Icons.agriculture,
                                                      size: 30,
                                                      color: Colors.grey)))
                                      : Container(
                                          color: isSelected
                                              ? Colors.green[50]
                                              : (isUsed
                                                  ? Colors.grey[200]
                                                  : Colors.white),
                                          child: Icon(Icons.landscape, size: 40, color: isUsed ? Colors.grey[600] : Colors.green[600])))),
                          Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            isSelected
                                                ? Colors.green.withOpacity(0.7)
                                                : Colors.black.withOpacity(0.5)
                                          ]),
                                      borderRadius: const BorderRadius.vertical(
                                          bottom: Radius.circular(16))),
                                  child: Text(title,
                                      style: GoogleFonts.lexend(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis))),
                          if (isSelected)
                            const Positioned(
                                top: 8,
                                right: 8,
                                child: Icon(Icons.check_circle,
                                    color: Colors.green, size: 22)),
                          if (isUsed && !isSelected)
                            Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(15)),
                                child: Text('In Use',
                                    style: GoogleFonts.lexend(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)))
                        ]))))));
  }

  Widget _buildPrimarySaveButton() {
    bool allFieldsUsed = _usedFieldNames.length >= _fieldNames.length;
    return AnimatedBuilder(
        animation: _saveButtonController,
        builder: (context, child) {
          return SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
                  .animate(CurvedAnimation(
                      parent: _sectionEntranceController,
                      curve:
                          const Interval(0.7, 1.0, curve: Curves.easeOutBack))),
              child: FadeTransition(
                  opacity: CurvedAnimation(
                      parent: _sectionEntranceController,
                      curve: const Interval(0.6, 1.0)),
                  child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          color: _isSaving || allFieldsUsed
                              ? Colors.grey[400]
                              : Colors.green[600]),
                      child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                              onTap: _isSaving || allFieldsUsed
                                  ? null
                                  : _saveCropSelection,
                              borderRadius: BorderRadius.circular(25),
                              child: Center(
                                  child: _isSaving
                                      ? const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation(Colors.white))
                                      : Text(allFieldsUsed ? 'All Fields In Use' : 'Save Selection', style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white))))))));
        });
  }

  Widget _buildSection(
      {required int index,
      required String title,
      required IconData icon,
      required Widget child}) {
    return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _sectionEntranceController,
                curve: Interval(index * 0.1, (index + 1) * 0.1 + 0.5,
                    curve: Curves.easeOutCubic))),
        child: FadeTransition(
            opacity: CurvedAnimation(
                parent: _sectionEntranceController,
                curve: Interval(index * 0.05, (index + 1) * 0.05 + 0.6,
                    curve: Curves.easeOut)),
            child: Container(
                margin: const EdgeInsets.only(bottom: 24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(title, icon),
                      const SizedBox(height: 12),
                      child
                    ]))));
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(children: [
      Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.green[700], size: 20)),
      const SizedBox(width: 12),
      Text(title,
          style: GoogleFonts.lexend(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.green[800]))
    ]);
  }

  Widget _buildCropGrid() {
    return SizedBox(
        height: 160,
        child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _crops.length,
            itemBuilder: (context, index) {
              return _buildSelectionCard(
                  title: _crops[index].name,
                  imageUrl: _crops[index].imageUrl,
                  isSelected: _selectedCrop?.id == _crops[index].id,
                  onTap: () {
                    setState(() => _selectedCrop = _crops[index]);
                    _fetchVarietiesForCrop(_crops[index].id);
                  });
            }));
  }

  Widget _buildVarietyGrid() {
    if (_varieties.isEmpty) {
      return SizedBox(
          height: 160,
          child: Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.green[400])));
    }
    return SizedBox(
        height: 160,
        child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _varieties.length,
            itemBuilder: (context, index) {
              return _buildSelectionCard(
                  title: _varieties[index].name,
                  imageUrl: _varieties[index].imageUrl,
                  isSelected: _selectedVariety?.id == _varieties[index].id,
                  onTap: () {
                    setState(() => _selectedVariety = _varieties[index]);
                  });
            }));
  }

  Widget _buildSimpleDateSelector() {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: EasyDateTimeLine(
            initialDate: _selectedDate,
            onDateChange: (date) => setState(() => _selectedDate = date),
            activeColor: Colors.green[600],
            dayProps: EasyDayProps(
                height: 56.0,
                width: 56.0,
                dayStructure: DayStructure.dayNumDayStr,
                inactiveDayStyle: DayStyle(
                    borderRadius: 12.0,
                    dayNumStyle: GoogleFonts.lexend(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700]),
                    dayStrStyle: GoogleFonts.lexend(
                        fontSize: 10.0, color: Colors.grey[600]),
                    decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!))),
                activeDayStyle: DayStyle(
                    borderRadius: 12.0,
                    dayNumStyle: GoogleFonts.lexend(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    dayStrStyle:
                        GoogleFonts.lexend(fontSize: 10.0, color: Colors.white),
                    decoration: BoxDecoration(
                        color: Colors.green[600],
                        borderRadius: BorderRadius.circular(12))))));
  }

  Widget _buildSimpleShimmer() {
    return Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: const SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              /* Shimmer content */
            ])));
  }
}

// --- TAB 2: MY FIELDS VIEW ---
class MyFieldsView extends StatefulWidget {
  const MyFieldsView({super.key});
  @override
  State<MyFieldsView> createState() => _MyFieldsViewState();
}

class _MyFieldsViewState extends State<MyFieldsView>
    with TickerProviderStateMixin {
  List<FarmerSelection> _selections = [];
  bool _isLoading = true;
  String? _error;
  late AnimationController _listEntranceController;
  @override
  void initState() {
    super.initState();
    _listEntranceController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _fetchSelections();
  }

  @override
  void dispose() {
    _listEntranceController.dispose();
    super.dispose();
  }

  Future<void> _fetchSelections() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final farmerResponse = await supabase
          .from('farmers')
          .select('id')
          .eq('user_id', supabase.auth.currentUser!.id)
          .single();
      final farmerId = farmerResponse['id'];
      final response = await supabase
          .from('farmer_crop_selections')
          .select(
              'id, field_name, crops(name_te, image_url), crop_varieties(variety_name), sowing_dates(sowing_date)')
          .eq('farmer_id', farmerId);
      final selections = (response as List)
          .map((item) => FarmerSelection(
                selectionId: item['id'],
                fieldName: item['field_name'],
                cropName: item['crops']['name_te'],
                cropImageUrl: item['crops']['image_url'],
                varietyName: item['crop_varieties']['variety_name'],
                sowingDate: DateTime.parse(item['sowing_dates']['sowing_date']),
              ))
          .toList();
      if (mounted) {
        setState(() {
          _selections = selections;
          _isLoading = false;
        });
        _listEntranceController.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // NEW: Method to show the edit bottom sheet
  void _showEditSheet(FarmerSelection selection) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Important for forms
      builder: (context) {
        return EditSelectionSheet(
          initialSelection: selection,
          onCompleted: () {
            _fetchSelections(); // This will refresh the list
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildSimpleLoadingList();
    }
    if (_error != null) {
      return _buildSimpleErrorState(_error!);
    }
    if (_selections.isEmpty) {
      return _buildSimpleEmptyState();
    }
    return _buildFieldsListView(_selections);
  }

  Widget _buildFieldsListView(List<FarmerSelection> selections) {
    return AnimatedBuilder(
        animation: _listEntranceController,
        builder: (context, child) {
          return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: selections.length,
              itemBuilder: (context, index) {
                final selection = selections[index];
                return SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0.2, 0), end: Offset.zero)
                        .animate(CurvedAnimation(
                            parent: _listEntranceController,
                            curve: Interval(index * 0.05,
                                (index * 0.05 + 0.6).clamp(0.0, 1.0),
                                curve: Curves.easeOutCubic))),
                    child: FadeTransition(
                        opacity: CurvedAnimation(
                            parent: _listEntranceController,
                            curve: Interval(index * 0.03,
                                (index * 0.03 + 0.7).clamp(0.0, 1.0),
                                curve: Curves.easeOut)),
                        child: _buildSimpleFieldCard(selection)));
              });
        });
  }

  Widget _buildSimpleFieldCard(FarmerSelection selection) {
    return Container(
        margin: const EdgeInsets.only(bottom: 20),
        child: Material(
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            child: Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    border: Border.all(
                        color: Colors.green.withOpacity(0.1), width: 1)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: Colors.green[500],
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16))),
                          child: Row(children: [
                            Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.5),
                                        width: 2)),
                                child: ClipOval(
                                    child: CachedNetworkImage(
                                        imageUrl: selection.cropImageUrl ?? '',
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            const Icon(Icons.agriculture,
                                                color: Colors.grey, size: 25),
                                        errorWidget: (context, url, error) =>
                                            const Icon(Icons.agriculture,
                                                color: Colors.grey,
                                                size: 25)))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(selection.fieldName,
                                      style: GoogleFonts.lexend(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white)),
                                  const SizedBox(height: 2),
                                  Text(
                                      'Sown on ${DateFormat('dd MMM yyyy').format(selection.sowingDate)}',
                                      style: GoogleFonts.lexend(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.9)))
                                ])),
                            InkWell(
                                onTap: () =>
                                    _showEditSheet(selection), // MODIFIED
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.edit_outlined,
                                        color: Colors.white, size: 20)))
                          ])),
                      Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(children: [
                            _buildSimpleInfoRow(Icons.eco_rounded, 'Crop',
                                selection.cropName, Colors.green[600]!),
                            const SizedBox(height: 10),
                            _buildSimpleInfoRow(Icons.grain_rounded, 'Variety',
                                selection.varietyName, Colors.orange[600]!),
                            const SizedBox(height: 10),
                            _buildSimpleInfoRow(
                                Icons.calendar_today_rounded,
                                'Sowing Date',
                                DateFormat('dd MMMM yyyy')
                                    .format(selection.sowingDate),
                                Colors.blue[600]!)
                          ]))
                    ]))));
  }

  Widget _buildSimpleInfoRow(
      IconData icon, String label, String value, Color color) {
    return Row(children: [
      Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18)),
      const SizedBox(width: 12),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.lexend(
                fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800]))
      ]))
    ]);
  }

  Widget _buildSimpleEmptyState() {
    return Center(
        child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                  scale: 0.9 + (value * 0.1),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                                color: Colors.green[100],
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.green[200]!, width: 1)),
                            child: const Icon(Icons.agriculture,
                                size: 50, color: Colors.green)),
                        const SizedBox(height: 20),
                        Text('No fields added yet',
                            style: GoogleFonts.lexend(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700])),
                        const SizedBox(height: 8),
                        Text('Add your first crop in the first tab',
                            style: GoogleFonts.lexend(
                                fontSize: 13, color: Colors.grey[600]),
                            textAlign: TextAlign.center)
                      ]));
            }));
  }

  Widget _buildSimpleErrorState(String error) {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
              color: Colors.red[100],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.red[200]!, width: 1)),
          child: const Icon(Icons.error_outline, size: 40, color: Colors.red)),
      const SizedBox(height: 20),
      Text('Error loading details',
          style: GoogleFonts.lexend(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.red[700])),
      const SizedBox(height: 8),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(error,
              style: GoogleFonts.lexend(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center))
    ]));
  }

  Widget _buildSimpleLoadingList() {
    return Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: 3,
            itemBuilder: (context, index) {
              return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  height: 220,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!)));
            }));
  }
}

// --- NEW WIDGET FOR THE EDITING BOTTOM SHEET ---
class EditSelectionSheet extends StatefulWidget {
  final FarmerSelection initialSelection;
  final VoidCallback onCompleted;

  const EditSelectionSheet(
      {super.key, required this.initialSelection, required this.onCompleted});

  @override
  State<EditSelectionSheet> createState() => _EditSelectionSheetState();
}

class _EditSelectionSheetState extends State<EditSelectionSheet> {
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _isDeleting = false;
  List<Crop> _crops = [];
  List<CropVariety> _varieties = [];
  final List<String> _fieldNames = ['Field 1', 'Field 2', 'Field 3', 'Field 4'];
  Crop? _selectedCrop;
  CropVariety? _selectedVariety;
  DateTime? _selectedDate;
  String? _selectedFieldName;
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _selectedFieldName = widget.initialSelection.fieldName;
    _selectedDate = widget.initialSelection.sowingDate;
    try {
      final cropsData =
          await supabase.from('crops').select('id, name_te, image_url');
      _crops = (cropsData as List)
          .map((c) =>
              Crop(id: c['id'], name: c['name_te'], imageUrl: c['image_url']))
          .toList();
      _selectedCrop = _crops.firstWhere(
          (c) => c.name == widget.initialSelection.cropName,
          orElse: () => _crops.first);
      await _fetchVarietiesForCrop(_selectedCrop!.id, initialLoad: true);
      _selectedVariety = _varieties.firstWhere(
          (v) => v.name == widget.initialSelection.varietyName,
          orElse: () => _varieties.first);
    } catch (e) {
      _showFeedbackSnackbar("Error loading data: ${e.toString()}", false);
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchVarietiesForCrop(int cropId,
      {bool initialLoad = false}) async {
    if (!initialLoad) {
      setState(() {
        _varieties = [];
        _selectedVariety = null;
      });
    }
    try {
      final varietiesData = await supabase
          .from('crop_varieties')
          .select('id, variety_name, packet_image_url')
          .eq('crop_id', cropId);
      _varieties = (varietiesData as List)
          .map((v) => CropVariety(
              id: v['id'],
              name: v['variety_name'],
              imageUrl: v['packet_image_url']))
          .toList();
    } catch (e) {
      _showFeedbackSnackbar("Error fetching varieties: ${e.toString()}", false);
    }
    if (mounted && !initialLoad) {
      setState(() {});
    }
  }

  Future<void> _updateCropSelection() async {
    if (_selectedCrop == null ||
        _selectedVariety == null ||
        _selectedFieldName == null ||
        _selectedDate == null) {
      _showFeedbackSnackbar('Please ensure all details are selected.', false);
      return;
    }
    setState(() => _isUpdating = true);
    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final sowingDateResponse = await supabase
          .from('sowing_dates')
          .upsert({'sowing_date': formattedDate}, onConflict: 'sowing_date')
          .select('id')
          .single();
      final sowingDateId = sowingDateResponse['id'];
      await supabase.from('farmer_crop_selections').update({
        'crop_id': _selectedCrop!.id,
        'variety_id': _selectedVariety!.id,
        'sowing_date_id': sowingDateId,
        'field_name': _selectedFieldName,
      }).eq('id', widget.initialSelection.selectionId);
      Navigator.pop(context);
      widget.onCompleted();
    } catch (e) {
      _showFeedbackSnackbar(
          'Failed to update selection: ${e.toString()}', false);
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _deleteSelection() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text('Confirm Deletion', style: GoogleFonts.lexend()),
                content: Text(
                    'Are you sure you want to delete this field entry? This action cannot be undone.',
                    style: GoogleFonts.lexend()),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Cancel', style: GoogleFonts.lexend())),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: Text('Delete', style: GoogleFonts.lexend()))
                ]));
    if (confirmed == true) {
      setState(() => _isDeleting = true);
      try {
        await supabase
            .from('farmer_crop_selections')
            .delete()
            .eq('id', widget.initialSelection.selectionId);
        Navigator.pop(context);
        widget.onCompleted();
      } catch (e) {
        _showFeedbackSnackbar('Failed to delete entry: ${e.toString()}', false);
      } finally {
        if (mounted) {
          setState(() => _isDeleting = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.9, // Make sheet almost full screen
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Scaffold(
          appBar: AppBar(
            title: Text('Edit Field Selection', style: GoogleFonts.lexend()),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close))
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Crop', Icons.eco_outlined),
                        const SizedBox(height: 12),
                        _buildCropGrid(),
                        const SizedBox(height: 24),
                        if (_selectedCrop != null) ...[
                          _buildSectionHeader('Variety', Icons.grain_outlined),
                          const SizedBox(height: 12),
                          _buildVarietyGrid(),
                          const SizedBox(height: 24)
                        ],
                        _buildSectionHeader('Field', Icons.landscape_outlined),
                        const SizedBox(height: 12),
                        _buildFieldGrid(),
                        const SizedBox(height: 24),
                        _buildSectionHeader(
                            'Sowing Date', Icons.calendar_today_outlined),
                        const SizedBox(height: 12),
                        _buildSimpleDateSelector(),
                        const SizedBox(height: 40),
                        ElevatedButton.icon(
                            onPressed:
                                _isUpdating ? null : _updateCropSelection,
                            icon: _isUpdating
                                ? Container(
                                    width: 24,
                                    height: 24,
                                    padding: const EdgeInsets.all(2.0),
                                    child: const CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 3))
                                : const Icon(Icons.update),
                            label: Text('Update Selection',
                                style: GoogleFonts.lexend(fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[600],
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)))),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                            onPressed: _isDeleting ? null : _deleteSelection,
                            icon: _isDeleting
                                ? Container(
                                    width: 24,
                                    height: 24,
                                    padding: const EdgeInsets.all(2.0),
                                    child: const CircularProgressIndicator(
                                        color: Colors.red, strokeWidth: 3))
                                : const Icon(Icons.delete_outline),
                            label: Text('Delete Entry',
                                style: GoogleFonts.lexend(fontSize: 16)),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))))
                      ])),
        ),
      ),
    );
  }

  void _showFeedbackSnackbar(String message, bool isSuccess) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message, style: GoogleFonts.lexend()),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating));
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(children: [
      Icon(icon, color: Colors.green[700], size: 22),
      const SizedBox(width: 8),
      Text(title,
          style: GoogleFonts.lexend(fontSize: 18, fontWeight: FontWeight.w600))
    ]);
  }

  Widget _buildCropGrid() {
    return SizedBox(
        height: 120,
        child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _crops.length,
            itemBuilder: (context, index) {
              final crop = _crops[index];
              return _buildSelectionCard(
                  title: crop.name,
                  imageUrl: crop.imageUrl,
                  isSelected: _selectedCrop?.id == crop.id,
                  onTap: () {
                    setState(() {
                      _selectedCrop = crop;
                      _fetchVarietiesForCrop(crop.id);
                    });
                  });
            }));
  }

  Widget _buildVarietyGrid() {
    if (_varieties.isEmpty) {
      return const SizedBox(
          height: 120, child: Center(child: Text("No varieties found.")));
    }
    return SizedBox(
        height: 120,
        child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _varieties.length,
            itemBuilder: (context, index) {
              final variety = _varieties[index];
              return _buildSelectionCard(
                  title: variety.name,
                  imageUrl: variety.imageUrl,
                  isSelected: _selectedVariety?.id == variety.id,
                  onTap: () => setState(() => _selectedVariety = variety));
            }));
  }

  Widget _buildFieldGrid() {
    return SizedBox(
        height: 80,
        child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _fieldNames.length,
            itemBuilder: (context, index) {
              final fieldName = _fieldNames[index];
              return _buildSelectionCard(
                  title: fieldName,
                  isSelected: _selectedFieldName == fieldName,
                  isSmall: true,
                  onTap: () => setState(() => _selectedFieldName = fieldName));
            }));
  }

  Widget _buildSimpleDateSelector() {
    return EasyDateTimeLine(
        initialDate: _selectedDate ?? DateTime.now(),
        onDateChange: (date) => setState(() => _selectedDate = date),
        activeColor: Colors.green[600]);
  }

  Widget _buildSelectionCard(
      {required String title,
      String? imageUrl,
      required bool isSelected,
      VoidCallback? onTap,
      bool isSmall = false}) {
    return Container(
        width: isSmall ? 100 : 120,
        margin: const EdgeInsets.only(right: 12),
        child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                    color: isSelected ? Colors.green[50] : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            isSelected ? Colors.green[600]! : Colors.grey[300]!,
                        width: isSelected ? 2.0 : 1.0)),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (imageUrl != null) ...[
                        CircleAvatar(
                            radius: isSmall ? 20 : 30,
                            backgroundImage:
                                CachedNetworkImageProvider(imageUrl),
                            backgroundColor: Colors.grey[200]),
                        const SizedBox(height: 8)
                      ],
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.lexend(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 13)))
                    ]))));
  }
}
