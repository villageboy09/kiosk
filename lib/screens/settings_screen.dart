// lib/screens/settings_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/auth_service.dart';
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
              opacity: value.clamp(0.0, 1.0),
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
                      'crop_details'.tr(),
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
              label: Text('add_crop'.tr(),
                  style: GoogleFonts.lexend(fontSize: 15)),
              icon: const Icon(Icons.add_circle_outline, size: 22),
            ),
            ButtonSegment<int>(
              value: 1,
              label: Text('my_fields'.tr(),
                  style: GoogleFonts.lexend(fontSize: 15)),
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
  final List<String> _fieldNames = ['పొలం 1', 'పొలం 2', 'పొలం 3', 'పొలం 4'];
  Set<String> _usedFieldNames = {};
  Crop? _selectedCrop;
  CropVariety? _selectedVariety;
  DateTime _selectedDate = DateTime.now();
  String? _selectedFieldName;
  late AnimationController _sectionEntranceController;
  late AnimationController _saveButtonController;

  bool _didFetchInitialData = false;

  @override
  void initState() {
    super.initState();
    _sectionEntranceController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _saveButtonController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didFetchInitialData) {
      _fetchInitialData();
      _didFetchInitialData = true;
    }
  }

  @override
  void dispose() {
    _sectionEntranceController.dispose();
    _saveButtonController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    try {
      if (!mounted) return;
      final langCode = context.locale.languageCode;

      await Future.delayed(const Duration(milliseconds: 600));

      // Fetch crops from MySQL API
      final cropsData = await ApiService.getCrops(lang: langCode);
      final List<Crop> loadedCrops = cropsData
          .map((c) => Crop(
              id: c['id'] as int,
              name: c['name'] as String,
              imageUrl: c['image_url'] as String?))
          .toList();

      // Get used field names for current user
      final userId = AuthService.currentUser?.userId;
      if (userId != null) {
        _usedFieldNames = await ApiService.getUsedFieldNames(userId);
      }

      if (mounted) {
        setState(() {
          _crops = loadedCrops;
          _isFetchingInitialData = false;
        });
        _sectionEntranceController.forward();
      }
    } catch (e) {
      _showFeedbackSnackbar('load_initial_error'.tr(), false);
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
      final varietiesData = await ApiService.getVarieties(cropId);
      final List<CropVariety> loadedVarieties = varietiesData
          .map((v) => CropVariety(
              id: v['id'] as int,
              name: v['variety_name'] as String,
              imageUrl: v['packet_image_url'] as String?))
          .toList();
      if (mounted) {
        setState(() {
          _varieties = loadedVarieties;
        });
      }
    } catch (e) {
      _showFeedbackSnackbar('load_varieties_error'.tr(), false);
    }
  }

  Future<void> _saveCropSelection() async {
    if (_selectedCrop == null ||
        _selectedVariety == null ||
        _selectedFieldName == null) {
      _showFeedbackSnackbar('select_all_details'.tr(), false);
      return;
    }
    if (_usedFieldNames.contains(_selectedFieldName)) {
      _showFeedbackSnackbar('field_in_use'.tr(), false);
      return;
    }
    _saveButtonController.forward();
    setState(() => _isSaving = true);
    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final userId = AuthService.currentUser?.userId;

      if (userId == null) {
        _showFeedbackSnackbar('User not logged in', false);
        return;
      }

      final result = await ApiService.saveSelection(
        userId: userId,
        cropId: _selectedCrop!.id,
        varietyId: _selectedVariety!.id,
        sowingDate: formattedDate,
        fieldName: _selectedFieldName!,
      );

      if (result['success'] == true) {
        if (mounted) {
          _showFeedbackSnackbar('save_success'.tr(), true);
          setState(() {
            _usedFieldNames.add(_selectedFieldName!);
            _selectedCrop = null;
            _selectedVariety = null;
            _selectedFieldName = null;
            _varieties = [];
          });
          await _saveButtonController.reverse();
        }
      } else {
        _showFeedbackSnackbar(result['error'] ?? 'Save failed', false);
        _saveButtonController.reverse();
      }
    } catch (e) {
      _showFeedbackSnackbar(
          'save_error'.tr(namedArgs: {'error': e.toString()}), false);
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
        content: Text(message, style: GoogleFonts.lexend()),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetchingInitialData) {
      return _buildLoadingState();
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('crop_label'.tr(), Icons.eco_outlined, 0),
          const SizedBox(height: 12),
          _buildCropGrid(),
          const SizedBox(height: 24),
          if (_selectedCrop != null) ...[
            _buildSectionHeader('variety_label'.tr(), Icons.grain_outlined, 1),
            const SizedBox(height: 12),
            _buildVarietyGrid(),
            const SizedBox(height: 24),
          ],
          _buildSectionHeader('select_field'.tr(), Icons.landscape_outlined, 2),
          const SizedBox(height: 12),
          _buildFieldGrid(),
          const SizedBox(height: 24),
          _buildSectionHeader(
              'sowing_date_label'.tr(), Icons.calendar_today_outlined, 3),
          const SizedBox(height: 12),
          _buildSimpleDateSelector(),
          const SizedBox(height: 40),
          _buildSaveButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 24,
              width: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                itemBuilder: (context, index) => Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, int index) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(-0.2, 0), end: Offset.zero)
          .animate(CurvedAnimation(
              parent: _sectionEntranceController,
              curve: Interval(index * 0.1, (index * 0.1 + 0.4).clamp(0.0, 1.0),
                  curve: Curves.easeOutCubic))),
      child: FadeTransition(
        opacity: CurvedAnimation(
            parent: _sectionEntranceController,
            curve: Interval(index * 0.1, (index * 0.1 + 0.5).clamp(0.0, 1.0),
                curve: Curves.easeOut)),
        child: Row(
          children: [
            Icon(icon, color: Colors.green[700], size: 22),
            const SizedBox(width: 8),
            Text(title,
                style: GoogleFonts.lexend(
                    fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
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
            },
          );
        },
      ),
    );
  }

  Widget _buildVarietyGrid() {
    if (_varieties.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text('no_varieties_found'.tr(), style: GoogleFonts.lexend()),
        ),
      );
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
            onTap: () => setState(() => _selectedVariety = variety),
          );
        },
      ),
    );
  }

  Widget _buildFieldGrid() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _fieldNames.length,
        itemBuilder: (context, index) {
          final fieldName = _fieldNames[index];
          final isUsed = _usedFieldNames.contains(fieldName);
          return _buildSelectionCard(
            title: fieldName,
            isSelected: _selectedFieldName == fieldName,
            isSmall: true,
            isDisabled: isUsed,
            onTap: isUsed
                ? null
                : () => setState(() => _selectedFieldName = fieldName),
          );
        },
      ),
    );
  }

  Widget _buildSimpleDateSelector() {
    return EasyDateTimeLine(
      locale: context.locale.toString(),
      initialDate: _selectedDate,
      onDateChange: (date) => setState(() => _selectedDate = date),
      activeColor: Colors.green[600],
    );
  }

  Widget _buildSaveButton() {
    final isReady = _selectedCrop != null &&
        _selectedVariety != null &&
        _selectedFieldName != null;
    return AnimatedBuilder(
      animation: _saveButtonController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_saveButtonController.value * 0.05),
          child: ElevatedButton.icon(
            onPressed: isReady && !_isSaving ? _saveCropSelection : null,
            icon: _isSaving
                ? Container(
                    width: 24,
                    height: 24,
                    padding: const EdgeInsets.all(2.0),
                    child: const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3))
                : const Icon(Icons.save_outlined),
            label: Text('save_selection'.tr(),
                style: GoogleFonts.lexend(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[400],
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectionCard({
    required String title,
    String? imageUrl,
    required bool isSelected,
    VoidCallback? onTap,
    bool isSmall = false,
    bool isDisabled = false,
  }) {
    return Container(
      width: isSmall ? 100 : 120,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isDisabled
                ? Colors.grey[200]
                : isSelected
                    ? Colors.green[50]
                    : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDisabled
                  ? Colors.grey[400]!
                  : isSelected
                      ? Colors.green[600]!
                      : Colors.grey[300]!,
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (imageUrl != null) ...[
                CircleAvatar(
                  radius: isSmall ? 20 : 30,
                  backgroundImage: CachedNetworkImageProvider(imageUrl),
                  backgroundColor: Colors.grey[200],
                ),
                const SizedBox(height: 8),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lexend(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                    color: isDisabled ? Colors.grey[600] : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- TAB 2: MY FIELDS VIEW ---
class MyFieldsView extends StatefulWidget {
  const MyFieldsView({super.key});
  @override
  State<MyFieldsView> createState() => _MyFieldsViewState();
}

class _MyFieldsViewState extends State<MyFieldsView>
    with SingleTickerProviderStateMixin {
  List<FarmerSelection> _selections = [];
  bool _isLoading = true;
  String? _error;
  late AnimationController _listEntranceController;
  bool _didFetchSelections = false;

  @override
  void initState() {
    super.initState();
    _listEntranceController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didFetchSelections) {
      _fetchSelections();
      _didFetchSelections = true;
    }
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
      final langCode = context.locale.languageCode;
      final userId = AuthService.currentUser?.userId;

      if (userId == null) {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      final response = await ApiService.getUserSelections(userId, lang: langCode);

      final selections = response
          .map((item) => FarmerSelection(
                selectionId: item['selection_id'] as int,
                fieldName: item['field_name'] as String,
                cropName: item['crop_name'] as String,
                cropImageUrl: item['crop_image_url'] as String?,
                varietyName: item['variety_name'] as String? ?? '',
                sowingDate: DateTime.parse(item['sowing_date'] as String),
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

  void _showEditSheet(FarmerSelection selection) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return EditSelectionSheet(
          initialSelection: selection,
          onCompleted: () {
            _fetchSelections();
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
    final formattedSownDate =
        DateFormat('dd MMM yyyy', context.locale.toString())
            .format(selection.sowingDate);

    return Container(
        margin: const EdgeInsets.only(bottom: 20),
        child: Material(
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            child: Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!)),
                child: InkWell(
                    onTap: () => _showEditSheet(selection),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.green[50],
                              backgroundImage: selection.cropImageUrl != null
                                  ? CachedNetworkImageProvider(
                                      selection.cropImageUrl!)
                                  : null,
                              child: selection.cropImageUrl == null
                                  ? Icon(Icons.eco,
                                      color: Colors.green[600], size: 30)
                                  : null),
                          const SizedBox(width: 16),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(selection.fieldName,
                                    style: GoogleFonts.lexend(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green[800])),
                                const SizedBox(height: 4),
                                Text(
                                    '${selection.cropName} - ${selection.varietyName}',
                                    style: GoogleFonts.lexend(
                                        fontSize: 14, color: Colors.grey[700])),
                                const SizedBox(height: 4),
                                Text('${'sown_on'.tr()}: $formattedSownDate',
                                    style: GoogleFonts.lexend(
                                        fontSize: 12, color: Colors.grey[500]))
                              ])),
                          Icon(Icons.chevron_right, color: Colors.grey[400])
                        ]))))));
  }

  Widget _buildSimpleLoadingList() {
    return Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: 3,
            itemBuilder: (context, index) => Container(
                margin: const EdgeInsets.only(bottom: 20),
                height: 100,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16)))));
  }

  Widget _buildSimpleErrorState(String error) {
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text('error_loading'.tr(),
                  style: GoogleFonts.lexend(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(error,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(color: Colors.grey[600])),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                  onPressed: _fetchSelections,
                  icon: const Icon(Icons.refresh),
                  label: Text('retry'.tr(), style: GoogleFonts.lexend()),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white))
            ])));
  }

  Widget _buildSimpleEmptyState() {
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: Colors.green[50], shape: BoxShape.circle),
                  child: Icon(Icons.agriculture_outlined,
                      size: 64, color: Colors.green[400])),
              const SizedBox(height: 24),
              Text('no_fields_yet'.tr(),
                  style: GoogleFonts.lexend(
                      fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('add_first_field'.tr(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(color: Colors.grey[600]))
            ])));
  }
}

// --- EDIT SELECTION SHEET ---
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
  final List<String> _fieldNames = ['పొలం 1', 'పొలం 2', 'పొలం 3', 'పొలం 4'];
  Crop? _selectedCrop;
  CropVariety? _selectedVariety;
  DateTime? _selectedDate;
  String? _selectedFieldName;

  bool _didLoadSheetData = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoadSheetData) {
      _loadInitialData();
      _didLoadSheetData = true;
    }
  }

  Future<void> _loadInitialData() async {
    _selectedFieldName = widget.initialSelection.fieldName;
    _selectedDate = widget.initialSelection.sowingDate;

    try {
      if (!mounted) return;
      final langCode = context.locale.languageCode;

      final cropsData = await ApiService.getCrops(lang: langCode);
      _crops = cropsData
          .map((c) => Crop(
              id: c['id'] as int,
              name: c['name'] as String,
              imageUrl: c['image_url'] as String?))
          .toList();

      _selectedCrop = _crops.firstWhere(
          (c) => c.name == widget.initialSelection.cropName,
          orElse: () => _crops.first);

      await _fetchVarietiesForCrop(_selectedCrop!.id, initialLoad: true);

      _selectedVariety = _varieties.firstWhere(
          (v) => v.name == widget.initialSelection.varietyName,
          orElse: () => _varieties.first);
    } catch (e) {
      _showFeedbackSnackbar(
          'load_data_error'.tr(namedArgs: {'error': e.toString()}), false);
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
      final varietiesData = await ApiService.getVarieties(cropId);
      _varieties = varietiesData
          .map((v) => CropVariety(
              id: v['id'] as int,
              name: v['variety_name'] as String,
              imageUrl: v['packet_image_url'] as String?))
          .toList();
    } catch (e) {
      _showFeedbackSnackbar(
          'fetch_varieties_error'.tr(namedArgs: {'error': e.toString()}),
          false);
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
      _showFeedbackSnackbar('ensure_all_selected'.tr(), false);
      return;
    }
    setState(() => _isUpdating = true);
    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      final result = await ApiService.updateSelection(
        id: widget.initialSelection.selectionId,
        cropId: _selectedCrop!.id,
        varietyId: _selectedVariety!.id,
        sowingDate: formattedDate,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.pop(context);
        widget.onCompleted();
      } else {
        _showFeedbackSnackbar(result['error'] ?? 'Update failed', false);
      }
    } catch (e) {
      _showFeedbackSnackbar(
          'update_error'.tr(namedArgs: {'error': e.toString()}), false);
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
                title: Text('confirm_deletion'.tr(), style: GoogleFonts.lexend()),
                content:
                    Text('delete_warning'.tr(), style: GoogleFonts.lexend()),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('cancel'.tr(), style: GoogleFonts.lexend())),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: Text('delete'.tr(), style: GoogleFonts.lexend()))
                ]));

    if (!mounted) return;

    if (confirmed == true) {
      setState(() => _isDeleting = true);
      try {
        final result =
            await ApiService.deleteSelection(widget.initialSelection.selectionId);

        if (!mounted) return;

        if (result['success'] == true) {
          Navigator.pop(context);
          widget.onCompleted();
        } else {
          _showFeedbackSnackbar(result['error'] ?? 'Delete failed', false);
        }
      } catch (e) {
        _showFeedbackSnackbar(
            'delete_error'.tr(namedArgs: {'error': e.toString()}), false);
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
      heightFactor: 0.9,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Scaffold(
          appBar: AppBar(
            title: Text('edit_field_selection'.tr(), style: GoogleFonts.lexend()),
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
                        _buildSectionHeader('crop_label'.tr(), Icons.eco_outlined),
                        const SizedBox(height: 12),
                        _buildCropGrid(),
                        const SizedBox(height: 24),
                        if (_selectedCrop != null) ...[
                          _buildSectionHeader(
                              'variety_label'.tr(), Icons.grain_outlined),
                          const SizedBox(height: 12),
                          _buildVarietyGrid(),
                          const SizedBox(height: 24)
                        ],
                        _buildSectionHeader(
                            'select_field'.tr(), Icons.landscape_outlined),
                        const SizedBox(height: 12),
                        _buildFieldGrid(),
                        const SizedBox(height: 24),
                        _buildSectionHeader('sowing_date_label'.tr(),
                            Icons.calendar_today_outlined),
                        const SizedBox(height: 12),
                        _buildSimpleDateSelector(),
                        const SizedBox(height: 40),
                        ElevatedButton.icon(
                            onPressed: _isUpdating ? null : _updateCropSelection,
                            icon: _isUpdating
                                ? Container(
                                    width: 24,
                                    height: 24,
                                    padding: const EdgeInsets.all(2.0),
                                    child: const CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 3))
                                : const Icon(Icons.update),
                            label: Text('update_selection'.tr(),
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
                            label: Text('delete_entry'.tr(),
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
      return SizedBox(
          height: 120,
          child: Center(
              child: Text("no_varieties_found".tr(), style: GoogleFonts.lexend())));
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
        locale: context.locale.toString(),
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
