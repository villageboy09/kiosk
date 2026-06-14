// lib/screens/settings_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/services/global_notifiers.dart';
import 'package:cropsync/services/notification_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cropsync/theme/app_theme.dart';

String _getDisplayFieldName(String name) {
  if (name == 'Field 1' || name == 'పొలం 1') return 'field_1'.tr();
  if (name == 'Field 2' || name == 'పొలం 2') return 'field_2'.tr();
  if (name == 'Field 3' || name == 'పొలం 3') return 'field_3'.tr();
  if (name == 'Field 4' || name == 'పొలం 4') return 'field_4'.tr();
  return name;
}

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
  late AnimationController _viewSwitchController;
  late List<Widget> _views;

  @override
  void initState() {
    super.initState();
    _views = [
      const AddNewCropSelectionView(key: ValueKey('add_crop')),
      const MyFieldsView(key: ValueKey('my_fields')),
    ];
    _viewSwitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _viewSwitchController.forward();
  }

  @override
  void dispose() {
    _viewSwitchController.dispose();
    super.dispose();
  }

  void _onTabChanged(int newIndex) {
    if (_selectedIndex != newIndex) {
      setState(() {
        _selectedIndex = newIndex;
        // Always force refresh when switching to My Fields tab
        if (newIndex == 1) {
          _MyFieldsViewState._shouldForceRefresh = true;
        }
      });
      _viewSwitchController.reset();
      _viewSwitchController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                const SizedBox(height: 20),
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
        ),
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            alignment: _selectedIndex == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onTabChanged(0),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline_rounded,
                            size: 18,
                            color: _selectedIndex == 0
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'add_crop'.tr(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _selectedIndex == 0
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: _selectedIndex == 0
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onTabChanged(1),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome_mosaic_rounded,
                            size: 18,
                            color: _selectedIndex == 1
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'my_fields'.tr(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _selectedIndex == 1
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: _selectedIndex == 1
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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

  // Static cache to prevent shimmer on revisit
  static List<Crop>? _cachedCrops;
  static Set<String>? _cachedUsedFields;
  static String? _cachedUserId;

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

    // Listen for global updates (e.g. deletion from My Fields)
    GlobalNotifiers.shouldRefreshAdvisory.addListener(_handleGlobalRefresh);
  }

  void _handleGlobalRefresh() {
    if (mounted) {
      // Force refresh to update used fields list
      _fetchInitialData(forceRefresh: true);
    }
  }

  Locale? _lastLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = context.locale;
    if (_lastLocale != currentLocale) {
      _lastLocale = currentLocale;
      _fetchInitialData(forceRefresh: true);
      _didFetchInitialData = true;
    } else if (!_didFetchInitialData) {
      _fetchInitialData();
      _didFetchInitialData = true;
    }
  }

  @override
  void dispose() {
    _sectionEntranceController.dispose();
    _saveButtonController.dispose();
    GlobalNotifiers.shouldRefreshAdvisory.removeListener(_handleGlobalRefresh);
    super.dispose();
  }

  Future<void> _fetchInitialData({bool forceRefresh = false}) async {
    // Invalidate cache if forced
    if (forceRefresh) {
      _cachedCrops = null;
      _cachedUsedFields = null;
    }

    final currentUserId = AuthService.currentUser?.userId;

    // Check cache first
    if (!forceRefresh &&
        _cachedCrops != null &&
        _cachedUsedFields != null &&
        _cachedUserId == currentUserId) {
      if (mounted) {
        setState(() {
          _crops = _cachedCrops!;
          _usedFieldNames = _cachedUsedFields!;
          _isFetchingInitialData = false;
        });
        _sectionEntranceController.forward();
      }
      return;
    }

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
        // Update cache
        _cachedCrops = loadedCrops;
        _cachedUsedFields = _usedFieldNames;
        _cachedUserId = currentUserId;

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
        _showFeedbackSnackbar('Please login to save your selection.', false);
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
        if (AuthService.currentUser != null) {
          NotificationService.synchronizeCropSubscriptions(AuthService.currentUser!);
        }
        if (mounted) {
          _showFeedbackSnackbar('save_success'.tr(), true);

          // Optimistic Update: Add to 'My Fields' cache if ID is available
          final newId = result['id'] ?? result['selection_id'];
          // Force refresh My Fields on next tab switch
          _MyFieldsViewState._shouldForceRefresh = true;

          _usedFieldNames.add(_selectedFieldName!);
          _cachedUsedFields = _usedFieldNames;

          // Emit optimistic add event
          GlobalNotifiers.selectionAdded.value = {
            'id': newId,
            'field_name': _selectedFieldName,
            'crop_name': _selectedCrop!.name,
            'crop_image_url': _selectedCrop!.imageUrl,
            'crop_id': _selectedCrop!.id,
            'variety_id': _selectedVariety!.id,
            'sowing_date': formattedDate,
            'variety_name': _selectedVariety!.name,
          };

          setState(() {
            _selectedCrop = null;
            _selectedVariety = null;
            _selectedFieldName = null;
            _varieties = [];
          });
          await _saveButtonController.reverse();
        }
      } else {
        _showFeedbackSnackbar(
            result['error'] ?? 'Could not save selection. Please try again.',
            false);
        _saveButtonController.reverse();
      }
    } catch (e) {
      _showFeedbackSnackbar(
          'Something went wrong. Please check your connection.', false);
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
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isSuccess ? AppTheme.textPrimary : AppTheme.error,
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
          _buildSectionHeader('crop_label'.tr(), Icons.eco_rounded, 0),
          const SizedBox(height: 12),
          _buildCropGrid(),
          const SizedBox(height: 24),
          if (_selectedCrop != null) ...[
            _buildSectionHeader('variety_label'.tr(), Icons.grain_rounded, 1),
            const SizedBox(height: 12),
            _buildVarietyGrid(),
            const SizedBox(height: 24),
          ],
          _buildSectionHeader('select_field'.tr(), Icons.landscape_rounded, 2),
          const SizedBox(height: 12),
          _buildFieldGrid(),
          const SizedBox(height: 24),
          _buildSectionHeader(
              'sowing_date_label'.tr(), Icons.calendar_today_rounded, 3),
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Shimmer.fromColors(
          baseColor: const Color(0xFFE5E7EB),
          highlightColor: const Color(0xFFF3F4F6),
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
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textPrimary, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ],
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
          child: Text('no_varieties_found'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
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
            title: _getDisplayFieldName(fieldName),
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
    return _buildEnhancedDateSelector(
      selectedDate: _selectedDate,
      onDateChanged: (date) => setState(() => _selectedDate = date),
    );
  }

  Widget _buildEnhancedDateSelector({
    required DateTime selectedDate,
    required ValueChanged<DateTime> onDateChanged,
  }) {
    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: _buildYearSelector(selectedDate, onDateChanged),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: SizedBox(
              height: 170,
              child: EasyDateTimeLine(
                key: ValueKey(context.locale.toString()),
                locale: context.locale.toString(),
                initialDate: selectedDate,
                onDateChange: onDateChanged,
                activeColor: AppTheme.textPrimary,
                headerProps: const EasyHeaderProps(
                  monthPickerType: MonthPickerType.switcher,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelector(
      DateTime selectedDate, ValueChanged<DateTime> onDateChanged) {
    final currentYear = DateTime.now().year;
    final startYear = currentYear - 1;
    final endYear = currentYear + 2;
    final yearCount = endYear - startYear;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Column(
        children: [
          Text('year_label'.tr(),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textHint)),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.vertical,
              shrinkWrap: true,
              itemCount: yearCount,
              itemBuilder: (context, index) {
                final year = startYear + index;
                final isSelected = year == selectedDate.year;
                return GestureDetector(
                  onTap: () {
                    final newDate =
                        DateTime(year, selectedDate.month, selectedDate.day);
                    onDateChanged(newDate);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? AppTheme.textPrimary : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            isSelected ? AppTheme.textPrimary : const Color(0xFFE5E7EB),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '$year',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color:
                            isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3))
                : const Icon(Icons.save_rounded),
            label: Text('save_selection'.tr()),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 64),
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
      width: isSmall ? 80 : 100,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isDisabled ? null : onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            decoration: BoxDecoration(
              color: isDisabled
                  ? const Color(0xFFF3F4F6)
                  : isSelected
                      ? AppTheme.textPrimary
                      : Colors.white,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isDisabled
                    ? const Color(0xFFE5E7EB)
                    : isSelected
                        ? AppTheme.textPrimary
                        : const Color(0xFFE5E7EB),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(isSmall ? 18 : 28),
                    child: SizedBox(
                      width: isSmall ? 36 : 56,
                      height: isSmall ? 36 : 56,
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.image_not_supported,
                              size: 16, color: Colors.grey[400]),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.landscape,
                              size: isSmall ? 12 : 20, color: Colors.grey[400]),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else if (isSmall) ...[
                  Icon(
                    Icons.landscape,
                    size: 24,
                    color:
                        isSelected ? Colors.white : AppTheme.textHint,
                  ),
                  const SizedBox(height: 4),
                ] else ...[
                  Icon(
                    Icons.image_not_supported,
                    size: 28,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                ],
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w900 : FontWeight.w700,
                        fontSize: 12,
                        color: isDisabled
                            ? AppTheme.textHint
                            : isSelected
                                ? Colors.white
                                : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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

  // Flag to force refresh on tab switch
  static bool _shouldForceRefresh = false;

  @override
  void initState() {
    super.initState();
    _listEntranceController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    GlobalNotifiers.selectionAdded.addListener(_onSelectionChanged);
    GlobalNotifiers.selectionDeleted.addListener(_onSelectionChanged);
    GlobalNotifiers.selectionUpdated.addListener(_onSelectionChanged);
  }

  void _onSelectionChanged() {
    if (mounted) {
      _fetchSelections();
    }
  }

  Locale? _lastLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = context.locale;
    if (_lastLocale != currentLocale) {
      _lastLocale = currentLocale;
      _fetchSelections();
      _didFetchSelections = true;
      _shouldForceRefresh = false;
    } else if (!_didFetchSelections || _shouldForceRefresh) {
      _fetchSelections();
      _didFetchSelections = true;
      _shouldForceRefresh = false;
    }
  }

  @override
  void dispose() {
    GlobalNotifiers.selectionAdded.removeListener(_onSelectionChanged);
    GlobalNotifiers.selectionDeleted.removeListener(_onSelectionChanged);
    GlobalNotifiers.selectionUpdated.removeListener(_onSelectionChanged);
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

      final response =
          await ApiService.getUserSelections(userId, lang: langCode);

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
            if (mounted) {
              _fetchSelections();
            }
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
              cacheExtent: 300,
              itemCount: selections.length,
              itemBuilder: (context, index) {
                final selection = selections[index];
                return RepaintBoundary(
                  child: SlideTransition(
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
                        child: _buildSimpleFieldCard(selection)),
                  ),
                );
              });
        });
  }

  Widget _buildSimpleFieldCard(FarmerSelection selection) {
    final formattedSownDate =
        DateFormat('dd MMM yyyy', context.locale.toString())
            .format(selection.sowingDate);

    return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ]),
        child: Material(
            color: Colors.transparent,
            child: InkWell(
                onTap: () => _showEditSheet(selection),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      if (selection.cropImageUrl != null &&
                          selection.cropImageUrl!.isNotEmpty)
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: CachedNetworkImage(
                                imageUrl: selection.cropImageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: const Color(0xFFF3F4F6),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.eco_rounded,
                                      color: AppTheme.textHint, size: 28),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: const Color(0xFFF3F4F6),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.eco_rounded,
                                      color: AppTheme.textHint, size: 28),
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        const CircleAvatar(
                          radius: 28,
                          backgroundColor: Color(0xFFF3F4F6),
                          child: Icon(Icons.eco_rounded,
                              color: AppTheme.textHint, size: 28),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(_getDisplayFieldName(selection.fieldName),
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                    letterSpacing: -0.3)),
                            const SizedBox(height: 4),
                            Text(
                                '${selection.cropName} - ${selection.varietyName}',
                                style: const TextStyle(
                                    fontSize: 14, 
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(formattedSownDate,
                                  style: const TextStyle(
                                      fontSize: 11, 
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textSecondary)),
                            )
                          ])),
                      const Icon(Icons.chevron_right_rounded, color: AppTheme.textHint)
                    ])))));
  }

  Widget _buildSimpleLoadingList() {
    return Shimmer.fromColors(
        baseColor: const Color(0xFFE5E7EB),
        highlightColor: const Color(0xFFF3F4F6),
        child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: 3,
            itemBuilder: (context, index) => Container(
                margin: const EdgeInsets.only(bottom: 20),
                height: 100,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20)))));
  }

  Widget _buildSimpleErrorState(String error) {
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline_rounded, size: 64, color: Color(0xFFEF4444)),
              const SizedBox(height: 20),
              Text('error_loading'.tr(),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                  onPressed: _fetchSelections,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text('retry'.tr()),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.textPrimary,
                      minimumSize: const Size(200, 56))),
            ])));
  }

  Widget _buildSimpleEmptyState() {
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  padding: const EdgeInsets.all(32),
                  decoration: const BoxDecoration(
                      color: Color(0xFFF3F4F6), shape: BoxShape.circle),
                  child: const Icon(Icons.agriculture_rounded,
                      size: 64, color: AppTheme.textHint)),
              const SizedBox(height: 24),
              Text('no_fields_yet'.tr(),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text('add_first_field'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 15))
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
        if (AuthService.currentUser != null) {
          NotificationService.synchronizeCropSubscriptions(AuthService.currentUser!);
        }
        _MyFieldsViewState._shouldForceRefresh = true;

        GlobalNotifiers.selectionUpdated.value = {
          'id': widget.initialSelection.selectionId,
          'field_name': _selectedFieldName,
          'crop_name': _selectedCrop!.name,
          'crop_image_url': _selectedCrop!.imageUrl,
          'crop_id': _selectedCrop!.id,
          'variety_id': _selectedVariety!.id,
          'sowing_date': formattedDate,
          'variety_name': _selectedVariety!.name,
        };

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
                title:
                    Text('confirm_deletion'.tr(), style: const TextStyle(fontWeight: FontWeight.w800)),
                content:
                    Text('delete_warning'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('cancel'.tr())),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                      child: Text('delete'.tr(), style: const TextStyle(fontWeight: FontWeight.w900)))
                ]));

    if (!mounted) return;

    if (confirmed == true) {
      setState(() => _isDeleting = true);
      try {
        final result = await ApiService.deleteSelection(
            widget.initialSelection.selectionId);

        if (!mounted) return;

        if (result['success'] == true) {
          if (AuthService.currentUser != null) {
            NotificationService.synchronizeCropSubscriptions(AuthService.currentUser!);
          }
          if (_AddNewCropSelectionViewState._cachedUsedFields != null) {
            _AddNewCropSelectionViewState._cachedUsedFields!
                .remove(widget.initialSelection.fieldName);
          }
          _MyFieldsViewState._shouldForceRefresh = true;
          GlobalNotifiers.selectionDeleted.value =
              widget.initialSelection.selectionId;

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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title:
                Text('edit_field_selection'.tr(), style: AppTheme.appBarTitle),
            automaticallyImplyLeading: false,
            centerTitle: false,
            backgroundColor: AppTheme.appBarBg,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 28, color: AppTheme.appBarText)),
              )
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                            'crop_label'.tr(), Icons.eco_rounded),
                        const SizedBox(height: 12),
                        _buildCropGrid(),
                        const SizedBox(height: 24),
                        if (_selectedCrop != null) ...[
                          _buildSectionHeader(
                              'variety_label'.tr(), Icons.grain_rounded),
                          const SizedBox(height: 12),
                          _buildVarietyGrid(),
                          const SizedBox(height: 24)
                        ],
                        _buildSectionHeader(
                            'select_field'.tr(), Icons.landscape_rounded),
                        const SizedBox(height: 12),
                        _buildFieldGrid(),
                        const SizedBox(height: 24),
                        _buildSectionHeader('sowing_date_label'.tr(),
                            Icons.calendar_today_rounded),
                        const SizedBox(height: 12),
                        _buildSimpleDateSelector(),
                        const SizedBox(height: 48),
                        ElevatedButton.icon(
                            onPressed:
                                _isUpdating ? null : _updateCropSelection,
                            icon: _isUpdating
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 3))
                                : const Icon(Icons.check_circle_rounded),
                            label: Text('update_selection'.tr()),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.textPrimary,
                                minimumSize: const Size(double.infinity, 64))),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                            onPressed: _isDeleting ? null : _deleteSelection,
                            icon: _isDeleting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        color: Color(0xFFEF4444), strokeWidth: 3))
                                : const Icon(Icons.delete_outline_rounded),
                            label: Text('delete_entry'.tr()),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.error,
                                side: const BorderSide(color: AppTheme.error, width: 2),
                                minimumSize: const Size(double.infinity, 64))),
                        const SizedBox(height: 32),
                      ])),
        ),
      ),
    );
  }

  void _showFeedbackSnackbar(String message, bool isSuccess) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isSuccess ? AppTheme.textPrimary : AppTheme.error,
        behavior: SnackBarBehavior.floating));
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(children: [
      Icon(icon, color: AppTheme.textPrimary, size: 20),
      const SizedBox(width: 8),
      Text(title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3))
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
          child: Text(
            "no_varieties_found".tr(),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
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
                  title: _getDisplayFieldName(fieldName),
                  isSelected: _selectedFieldName == fieldName,
                  isSmall: true,
                  onTap: () => setState(() => _selectedFieldName = fieldName));
            }));
  }

  Widget _buildSimpleDateSelector() {
    return _buildEnhancedDateSelectorSheet(
      selectedDate: _selectedDate ?? DateTime.now(),
      onDateChanged: (date) => setState(() => _selectedDate = date),
    );
  }

  Widget _buildEnhancedDateSelectorSheet({
    required DateTime selectedDate,
    required ValueChanged<DateTime> onDateChanged,
  }) {
    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: _buildYearSelectorSheet(selectedDate, onDateChanged),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: SizedBox(
              height: 170,
              child: EasyDateTimeLine(
                key: ValueKey(context.locale.toString()),
                locale: context.locale.toString(),
                initialDate: selectedDate,
                onDateChange: onDateChanged,
                activeColor: AppTheme.textPrimary,
                headerProps: const EasyHeaderProps(
                  monthPickerType: MonthPickerType.switcher,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelectorSheet(
      DateTime selectedDate, ValueChanged<DateTime> onDateChanged) {
    final currentYear = DateTime.now().year;
    final startYear = currentYear - 1;
    final endYear = currentYear + 2;
    final yearCount = endYear - startYear;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Column(
        children: [
          Text('year_label'.tr(),
              style: AppTheme.getTextStyle(context, 
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600])),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.vertical,
              shrinkWrap: true,
              itemCount: yearCount,
              itemBuilder: (context, index) {
                final year = startYear + index;
                final isSelected = year == selectedDate.year;
                return GestureDetector(
                  onTap: () {
                    final newDate =
                        DateTime(year, selectedDate.month, selectedDate.day);
                    onDateChanged(newDate);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? AppTheme.textPrimary.withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            isSelected ? AppTheme.textPrimary : const Color(0xFFE5E7EB),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      '$year',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color:
                            isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard(
      {required String title,
      String? imageUrl,
      required bool isSelected,
      VoidCallback? onTap,
      bool isSmall = false}) {
    return Container(
      width: isSmall ? 80 : 100,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF1B5E20).withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
                color: isSelected ? const Color(0xFF1B5E20) : Colors.grey[300]!,
                width: isSelected ? 2.0 : 1.0),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty) ...[
                    CircleAvatar(
                        radius: isSmall ? 18 : 28,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: CachedNetworkImageProvider(imageUrl)),
                    const SizedBox(height: 8)
                  ] else if (isSmall) ...[
                    Icon(
                      Icons.landscape,
                      size: 24,
                      color: isSelected
                          ? const Color(0xFF1B5E20)
                          : Colors.grey[400],
                    ),
                    const SizedBox(height: 4),
                  ] else ...[
                    Icon(
                      Icons.image_not_supported,
                      size: 24,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Flexible(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.getTextStyle(context, 
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 11,
                        height: 1.1,
                        color: isSelected
                            ? const Color(0xFF1B5E20)
                            : const Color(0xFF4A4A4A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
