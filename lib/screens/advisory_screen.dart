// lib/screens/advisory_screen.dart

// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/models/crop_problem.dart';
import 'package:cropsync/screens/advisory_details.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cropsync/services/global_notifiers.dart';
import 'package:easy_localization/easy_localization.dart';

// ... (existing imports)

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

class AdvisoriesScreen extends StatefulWidget {
  const AdvisoriesScreen({super.key});

  @override
  State<AdvisoriesScreen> createState() => _AdvisoriesScreenState();
}

class _AdvisoriesScreenState extends State<AdvisoriesScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  // Data
  List<FarmerCropSelection> _farmerCrops = [];
  List<CropStage> _stages = [];
  List<CropProblem> _problems = [];

  FarmerCropSelection? _selectedFarmerCrop;
  CropStage? _selectedStage;

  // Initialization state
  bool _isInit = true;

  // Animation
  late AnimationController _feedAnimationController;
  late AnimationController _filterAnimationController;

  @override
  void initState() {
    super.initState();
    _feedAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _filterAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Listen for global refreshes
    // Listen for global refreshes and optimistic updates
    GlobalNotifiers.shouldRefreshAdvisory.addListener(_handleRefresh);
    GlobalNotifiers.selectionAdded.addListener(_onSelectionAdded);
    GlobalNotifiers.selectionDeleted.addListener(_onSelectionDeleted);
    GlobalNotifiers.selectionUpdated.addListener(_onSelectionUpdated);
  }

  void _handleRefresh() {
    if (mounted) {
      _fetchInitialData();
    }
  }

  void _onSelectionAdded() {
    final payload = GlobalNotifiers.selectionAdded.value;
    if (payload == null || !mounted) return;

    final newSelection = FarmerCropSelection(
      id: int.parse(payload['id'].toString()),
      fieldName: payload['field_name'],
      cropName: payload['crop_name'],
      cropImageUrl: payload['crop_image_url'],
      cropId: payload['crop_id'],
      varietyId: payload['variety_id'],
      sowingDate: DateTime.parse(payload['sowing_date']),
    );

    setState(() {
      _farmerCrops.insert(0, newSelection);
      // Automatically select the new crop
      _selectFarmerCrop(newSelection);
    });
  }

  void _onSelectionUpdated() {
    final payload = GlobalNotifiers.selectionUpdated.value;
    if (payload == null || !mounted) return;

    final id = int.parse(payload['id'].toString());
    final index = _farmerCrops.indexWhere((c) => c.id == id);

    if (index != -1) {
      final updatedSelection = FarmerCropSelection(
        id: id,
        fieldName: payload['field_name'],
        cropName: payload['crop_name'],
        cropImageUrl: payload['crop_image_url'],
        cropId: payload['crop_id'],
        varietyId: payload['variety_id'],
        sowingDate: DateTime.parse(payload['sowing_date']),
      );

      setState(() {
        _farmerCrops[index] = updatedSelection;
        if (_selectedFarmerCrop?.id == id) {
          _selectedFarmerCrop =
              updatedSelection; // Update current selection if it matches
        }
      });
    }
  }

  void _onSelectionDeleted() {
    final id = GlobalNotifiers.selectionDeleted.value;
    if (id == null || !mounted) return;

    setState(() {
      _farmerCrops.removeWhere((c) => c.id == id);

      // If we deleted the currently selected crop, select the first available one
      if (_selectedFarmerCrop?.id == id) {
        if (_farmerCrops.isNotEmpty) {
          _selectFarmerCrop(_farmerCrops.first);
        } else {
          _selectedFarmerCrop = null;
          _stages = [];
          _problems = [];
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _fetchInitialData();
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _feedAnimationController.dispose();
    _filterAnimationController.dispose();
    _scrollController.dispose();
    GlobalNotifiers.shouldRefreshAdvisory.removeListener(_handleRefresh);
    GlobalNotifiers.selectionAdded.removeListener(_onSelectionAdded);
    GlobalNotifiers.selectionDeleted.removeListener(_onSelectionDeleted);
    GlobalNotifiers.selectionUpdated.removeListener(_onSelectionUpdated);
    super.dispose();
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

  Future<void> _fetchInitialData() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        _showErrorSnackbar(context.tr('login_required'));
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final userId = currentUser.userId;

      final locale = _getLocaleField(context.locale.languageCode);

      // Fetch user's crop selections from MySQL API
      final selectionsData =
          await ApiService.getUserSelections(userId, lang: locale);

      if (selectionsData.isEmpty) {
        if (mounted) {
          setState(() {
            _farmerCrops = [];
            _isLoading = false;
          });
        }
        return;
      }

      final List<FarmerCropSelection> loadedCrops = selectionsData.map((s) {
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

      if (mounted) {
        setState(() {
          _farmerCrops = loadedCrops;
          if (_farmerCrops.isNotEmpty) {
            _selectFarmerCrop(_farmerCrops.first);
          }
          _isLoading = false;
        });
        _filterAnimationController.forward();
      }
    } catch (e) {
      _showErrorSnackbar(
          'Could not load your crops. Please check your connection.');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectFarmerCrop(FarmerCropSelection farmerCrop) async {
    setState(() {
      _selectedFarmerCrop = farmerCrop;
      _stages = [];
      _problems = [];
      _selectedStage = null;
    });
    _feedAnimationController.reverse();

    try {
      final locale = _getLocaleField(context.locale.languageCode);

      // Fetch crop stages from MySQL API
      final stagesData =
          await ApiService.getCropStages(farmerCrop.cropId, lang: locale);

      final List<CropStage> loadedStages = stagesData.map((s) {
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
            currentStage = loadedStages.firstWhere(
              (s) => s.id == stageId,
              orElse: () => loadedStages.first,
            );
            break;
          }
        }
      } catch (e) {
        debugPrint(
            'Could not determine current stage automatically. Defaulting to first stage.');
      }

      if (mounted) {
        setState(() {
          _stages = loadedStages;
          if (_stages.isNotEmpty) {
            _selectStage(currentStage ?? _stages.first);
          }
        });
      }
    } catch (e) {
      _showErrorSnackbar('Could not load crop stages. Please try again.');
    }
  }

  Future<void> _selectStage(CropStage stage) async {
    // DEBUG: Log the stage selection
    print('DEBUG _selectStage: Selected stage: ${stage.name} (id=${stage.id})');
    print(
        'DEBUG _selectStage: Current crop: ${_selectedFarmerCrop?.cropName} (cropId=${_selectedFarmerCrop?.cropId})');

    setState(() {
      _selectedStage = stage;
      _problems = [];
    });
    _feedAnimationController.reverse();

    try {
      final locale = _getLocaleField(context.locale.languageCode);
      print('DEBUG _selectStage: Locale: $locale');

      // Fetch problems from MySQL API using the problem_stages junction table
      print(
          'DEBUG _selectStage: Calling ApiService.getProblems(cropId=${_selectedFarmerCrop!.cropId}, stageId=${stage.id}, lang=$locale)');
      final problemsData = await ApiService.getProblems(
        cropId: _selectedFarmerCrop!.cropId,
        stageId: stage.id,
        lang: locale,
      );
      print(
          'DEBUG _selectStage: Received ${problemsData.length} problems from API');

      final List<CropProblem> loadedProblems = problemsData.map((p) {
        return CropProblem.fromJson(p);
      }).toList();
      print(
          'DEBUG _selectStage: Parsed ${loadedProblems.length} CropProblem objects');

      if (mounted) {
        setState(() {
          _problems = loadedProblems;
        });
        print(
            'DEBUG _selectStage: Set _problems with ${_problems.length} items');
        _feedAnimationController.forward();
      }
    } catch (e, st) {
      print('DEBUG _selectStage: ERROR: $e');
      print('DEBUG _selectStage: Stack trace: $st');
      _showErrorSnackbar(
          'Could not load problems. Please check your connection.');
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                context.tr('filter_title'),
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  Text(
                    context.tr('my_crops'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._farmerCrops.map((crop) => _buildCropTile(crop)),
                  const SizedBox(height: 24),
                  if (_stages.isNotEmpty) ...[
                    Text(
                      context.tr('crop_stage'),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._stages.map((stage) => _buildStageTile(stage)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageTile(CropStage stage) {
    final isSelected = _selectedStage?.id == stage.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? Colors.green[50] : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            _selectStage(stage);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? Colors.green : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                if (stage.imageUrl != null && stage.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: stage.imageUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.eco, color: Colors.grey),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.eco, color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.eco, color: Colors.green[700]),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    stage.name,
                    style: GoogleFonts.poppins(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 15,
                      color: isSelected ? Colors.green[700] : Colors.grey[800],
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: Colors.green[700], size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCropTile(FarmerCropSelection crop) {
    final isSelected = _selectedFarmerCrop?.id == crop.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? Colors.green[50] : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            _selectFarmerCrop(crop);
            if (_stages.isEmpty) Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? Colors.green : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: (crop.cropImageUrl != null &&
                          crop.cropImageUrl!.isNotEmpty &&
                          (crop.cropImageUrl!.startsWith('http') ||
                              crop.cropImageUrl!.startsWith('https')))
                      ? CachedNetworkImage(
                          imageUrl: crop.cropImageUrl!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.grass, color: Colors.grey),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.grass, color: Colors.grey),
                          ),
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey[200],
                          child: const Icon(Icons.grass, color: Colors.grey),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        crop.fieldName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        crop.cropName,
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: Colors.green[700], size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: _isLoading
            ? _buildShimmerEffect()
            : Column(
                children: [
                  _buildCompactHeader(),
                  // Stage selector horizontal list
                  if (_stages.isNotEmpty) _buildStageSelector(),
                  Expanded(child: _buildProblemFeed()),
                ],
              ),
      ),
    );
  }

  Widget _buildStageSelector() {
    return Container(
      height: 110,
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _stages.length,
        itemBuilder: (context, index) {
          final stage = _stages[index];
          final isSelected = _selectedStage?.id == stage.id;
          return GestureDetector(
            onTap: () => _selectStage(stage),
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: isSelected ? 68 : 60,
                    height: isSelected ? 68 : 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF1B5E20)
                            : Colors.grey[300]!,
                        width: isSelected ? 4 : 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF1B5E20)
                                    .withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3.0), // Space for border
                      child: ClipOval(
                        child: stage.imageUrl != null &&
                                stage.imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: stage.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.green[50],
                                  child: Icon(Icons.eco,
                                      color: Colors.green[300], size: 30),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.green[50],
                                  child: Icon(Icons.eco,
                                      color: Colors.green[300], size: 30),
                                ),
                              )
                            : Container(
                                color: isSelected
                                    ? Colors.green[100]
                                    : Colors.grey[100],
                                child: Icon(
                                  Icons.eco,
                                  color: isSelected
                                      ? Colors.green[700]
                                      : Colors.grey[400],
                                  size: 30,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stage.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF1B5E20)
                          : Colors.grey[600],
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

  Widget _buildCompactHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('advisories_title'),
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_selectedFarmerCrop != null)
                        FadeTransition(
                          opacity: _filterAnimationController,
                          child: Text(
                            '${_selectedFarmerCrop!.cropName} • ${_selectedFarmerCrop!.fieldName}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[600]!, Colors.green[700]!],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showFilterBottomSheet,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.filter_list,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              context.tr('filter_button'),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildProblemFeed() {
    if (_problems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.agriculture,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('no_problems_found'),
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('select_another_stage'),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    // Group problems by category
    final Map<String, List<CropProblem>> groupedProblems = {};
    for (var problem in _problems) {
      final category = problem.category ?? 'Other';
      if (!groupedProblems.containsKey(category)) {
        groupedProblems[category] = [];
      }
      groupedProblems[category]!.add(problem);
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (_selectedStage != null) {
          await _selectStage(_selectedStage!);
        }
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _problems.length,
        itemBuilder: (context, index) {
          final problem = _problems[index];
          return FadeTransition(
            opacity: _feedAnimationController,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _feedAnimationController,
                curve: Interval(
                  index * 0.1,
                  1.0,
                  curve: Curves.easeOutCubic,
                ),
              )),
              child: _buildEnhancedProblemCard(problem),
            ),
          );
        },
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'fungal disease':
        return Colors.brown;
      case 'insect pest':
        return Colors.orange;
      case 'bacterial disease':
        return Colors.red;
      case 'viral disease':
        return Colors.purple;
      case 'nutrient deficiency':
        return Colors.amber;
      case 'abiotic disorder':
        return Colors.blue;
      case 'nematode':
        return Colors.teal;
      case 'pest':
        return Colors.orange;
      case 'disease':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildEnhancedProblemCard(CropProblem problem) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AdvisoryDetailScreen(problem: problem),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Gallery Section
                if (problem.imageUrl1 != null && problem.imageUrl1!.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        children: [
                          if (problem.imageUrl1!.startsWith('http') ||
                              problem.imageUrl1!.startsWith('https'))
                            CachedNetworkImage(
                              imageUrl: problem.imageUrl1!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.green[700],
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.broken_image,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          // Gradient overlay for better text visibility
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.7),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Category badge
                          if (problem.category != null)
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(problem.category!),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  problem.category!,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          // Image count indicator
                          if (problem.imageUrl2 != null ||
                              problem.imageUrl3 != null)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.photo_library,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${[
                                        problem.imageUrl1,
                                        problem.imageUrl2,
                                        problem.imageUrl3
                                      ].where((img) => img != null && img.isNotEmpty).length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                // Content Section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        problem.name,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 16,
                                    color: Colors.orange[700],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    context.tr('problem_detected'),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green[600]!,
                                  Colors.green[700]!
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          AdvisoryDetailScreen(
                                              problem: problem),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        context.tr('view_advice'),
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.arrow_forward,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
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
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Shimmer
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 150,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 200,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            // Stage Circles Shimmer
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 5,
                itemBuilder: (context, index) => Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 50,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Feed Items Shimmer
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: 3,
              itemBuilder: (context, index) => Container(
                height: 200,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
