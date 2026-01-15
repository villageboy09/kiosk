// lib/services/advisory_state.dart

import 'package:flutter/foundation.dart';
import 'package:cropsync/models/crop_problem.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/auth_service.dart';

/// Data class for farmer crop selection
class FarmerCropSelection {
  final int id;
  final String fieldName;
  final String cropName;
  final String? cropImageUrl;
  final int cropId;
  final int varietyId;
  final DateTime sowingDate;

  FarmerCropSelection({
    required this.id,
    required this.fieldName,
    required this.cropName,
    this.cropImageUrl,
    required this.cropId,
    required this.varietyId,
    required this.sowingDate,
  });
}

/// Data class for crop stage
class CropStage {
  final int id;
  final String name;
  final String? imageUrl;
  final String? description;

  CropStage({
    required this.id,
    required this.name,
    this.imageUrl,
    this.description,
  });
}

/// Singleton state manager for advisory data
/// This ensures real-time synchronization between home screen and advisory screen
class AdvisoryState extends ChangeNotifier {
  // Singleton instance
  static final AdvisoryState _instance = AdvisoryState._internal();
  factory AdvisoryState() => _instance;
  AdvisoryState._internal();

  // State variables
  bool _isLoading = true;
  List<FarmerCropSelection> _farmerCrops = [];
  List<CropStage> _stages = [];
  List<CropProblem> _problems = [];
  FarmerCropSelection? _selectedFarmerCrop;
  CropStage? _selectedStage;
  String _currentLocale = 'te';
  bool _isInitialized = false;

  // Getters
  bool get isLoading => _isLoading;
  List<FarmerCropSelection> get farmerCrops => _farmerCrops;
  List<CropStage> get stages => _stages;
  List<CropProblem> get problems => _problems;
  FarmerCropSelection? get selectedFarmerCrop => _selectedFarmerCrop;
  CropStage? get selectedStage => _selectedStage;
  bool get isInitialized => _isInitialized;

  /// Get the current stage name for display
  String get currentStageName => _selectedStage?.name ?? '';

  /// Get the current crop name for display
  String get currentCropName => _selectedFarmerCrop?.cropName ?? '';

  /// Get the current field name for display
  String get currentFieldName => _selectedFarmerCrop?.fieldName ?? '';

  /// Get the count of problems for the current stage
  int get problemCount => _problems.length;

  /// Check if there are any problems detected
  bool get hasProblems => _problems.isNotEmpty;

  /// Set the current locale for API calls
  void setLocale(String locale) {
    if (_currentLocale != locale) {
      _currentLocale = locale;
      // Refresh data with new locale if already initialized
      if (_isInitialized) {
        refreshData();
      }
    }
  }

  /// Initialize or refresh all advisory data
  Future<void> initializeData({String? locale}) async {
    if (locale != null) {
      _currentLocale = locale;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final userId = currentUser.userId;

      // Fetch user's crop selections
      final selectionsData =
          await ApiService.getUserSelections(userId, lang: _currentLocale);

      if (selectionsData.isEmpty) {
        _farmerCrops = [];
        _stages = [];
        _problems = [];
        _selectedFarmerCrop = null;
        _selectedStage = null;
        _isLoading = false;
        _isInitialized = true;
        notifyListeners();
        return;
      }

      _farmerCrops = selectionsData.map((s) {
        return FarmerCropSelection(
          id: int.tryParse(s['selection_id'].toString()) ?? 0,
          fieldName: s['field_name']?.toString() ?? 'Unknown Field',
          cropName: s['crop_name']?.toString() ?? 'Unknown Crop',
          cropImageUrl: s['crop_image_url']?.toString(),
          cropId: int.tryParse(s['crop_id'].toString()) ?? 1,
          varietyId: int.tryParse(s['variety_id'].toString()) ?? 1,
          sowingDate:
              DateTime.tryParse(s['sowing_date'].toString()) ?? DateTime.now(),
        );
      }).toList();

      // Auto-select first crop if none selected
      if (_farmerCrops.isNotEmpty && _selectedFarmerCrop == null) {
        await selectFarmerCrop(_farmerCrops.first);
      } else if (_selectedFarmerCrop != null) {
        // Refresh stages and problems for current selection
        await _loadStagesForCrop(_selectedFarmerCrop!);
      }

      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing advisory data: $e');
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Refresh all data
  Future<void> refreshData() async {
    await initializeData(locale: _currentLocale);
  }

  /// Select a farmer crop and load its stages
  Future<void> selectFarmerCrop(FarmerCropSelection farmerCrop) async {
    _selectedFarmerCrop = farmerCrop;
    _stages = [];
    _problems = [];
    _selectedStage = null;
    notifyListeners();

    await _loadStagesForCrop(farmerCrop);
  }

  /// Load stages for a specific crop
  Future<void> _loadStagesForCrop(FarmerCropSelection farmerCrop) async {
    try {
      // Fetch crop stages
      final stagesData =
          await ApiService.getCropStages(farmerCrop.cropId, lang: _currentLocale);

      _stages = stagesData.map((s) {
        return CropStage(
          id: s['id'] as int,
          name: s['name'] as String? ?? 'Unknown',
          imageUrl: s['image_url'] as String?,
          description: s['description'] as String?,
        );
      }).toList();

      // Calculate days since sowing to find the current stage
      final daysSinceSowing =
          DateTime.now().difference(farmerCrop.sowingDate).inDays;

      CropStage? currentStage;
      try {
        // Query crop_stage_durations to get the current stage's ID
        final durationData = await ApiService.getStageDuration(
          farmerCrop.cropId,
          varietyId: farmerCrop.varietyId,
        );

        for (var duration in durationData) {
          final startDay = duration['start_day_from_sowing'] as int? ?? 0;
          final endDay = duration['end_day_from_sowing'] as int? ?? 999;
          if (daysSinceSowing >= startDay && daysSinceSowing <= endDay) {
            final stageId = duration['stage_id'] as int;
            currentStage = _stages.firstWhere(
              (s) => s.id == stageId,
              orElse: () => _stages.first,
            );
            break;
          }
        }
      } catch (e) {
        debugPrint('Could not determine current stage automatically.');
      }

      // Auto-select the current stage or first stage
      if (_stages.isNotEmpty) {
        await selectStage(currentStage ?? _stages.first);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading stages: $e');
      notifyListeners();
    }
  }

  /// Select a stage and load its problems
  Future<void> selectStage(CropStage stage) async {
    _selectedStage = stage;
    _problems = [];
    notifyListeners();

    try {
      // Fetch problems for this stage
      final problemsData = await ApiService.getProblems(
        cropId: _selectedFarmerCrop!.cropId,
        stageId: stage.id,
        lang: _currentLocale,
      );

      _problems = problemsData.map((p) {
        return CropProblem.fromJson(p);
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading problems: $e');
      notifyListeners();
    }
  }

  /// Clear all state (e.g., on logout)
  void clear() {
    _isLoading = true;
    _farmerCrops = [];
    _stages = [];
    _problems = [];
    _selectedFarmerCrop = null;
    _selectedStage = null;
    _isInitialized = false;
    notifyListeners();
  }
}
