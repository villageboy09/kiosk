// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/main.dart';
import 'package:cropsync/models/crop_problem.dart';
import 'package:cropsync/screens/advisory_details.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:easy_localization/easy_localization.dart';

// Data Models
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
  CropStage({required this.id, required this.name});
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

  // Selections
  FarmerCropSelection? _selectedFarmerCrop;
  CropStage? _selectedStage;

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
    _fetchInitialData();
  }

  @override
  void dispose() {
    _feedAnimationController.dispose();
    _filterAnimationController.dispose();
    _scrollController.dispose();
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
      print('1. Starting _fetchInitialData...');

      if (supabase.auth.currentUser == null) {
        print('ERROR: User is not logged in. Aborting.');
        _showErrorSnackbar(context.tr('login_required'));
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final userId = supabase.auth.currentUser!.id;
      print('2. Current User ID: $userId');

      final farmerResponse = await supabase
          .from('farmers')
          .select('id')
          .eq('user_id', userId)
          .single();
      final farmerId = farmerResponse['id'];
      print('3. Found Farmer ID: $farmerId');

      final locale = _getLocaleField(context.locale.languageCode);
      List<String> cropFields = ['id', 'image_url', 'name_en'];
      if (locale == 'te') cropFields.add('name_te');
      if (locale == 'hi') cropFields.add('name_hi');
      String cropSelectStr = cropFields.join(', ');

      // FIX 1: Dynamic select for crops to avoid missing column errors
      final selectionsData = await supabase
          .from('farmer_crop_selections')
          .select(
              'id, field_name, variety_id, sowing_dates(sowing_date), crops($cropSelectStr)')
          .eq('farmer_id', farmerId);

      print(
          '4. Fetched Selections Data: Found ${selectionsData.length} crop(s).');

      if (selectionsData.isEmpty) {
        print(
            'WARNING: No crop selections found for this farmer in the database.');
        if (mounted) {
          setState(() {
            _farmerCrops = [];
            _isLoading = false;
          });
        }
        return;
      }

      final List<FarmerCropSelection> loadedCrops = (selectionsData as List)
          .map((s) {
            final cropData = s['crops'];
            final sowingDateData = s['sowing_dates'];

            if (sowingDateData == null ||
                sowingDateData['sowing_date'] == null ||
                s['variety_id'] == null ||
                cropData == null) {
              print(
                  'ERROR: Found null data for a crop selection. ID: ${s['id']}');
              return null;
            }

            // FIX 2: Get the correct localized name based on current locale with fallback
            String cropName = cropData['name_en'] ?? 'Unknown';
            if (locale == 'hi' && cropData.containsKey('name_hi')) {
              cropName = cropData['name_hi'] ?? cropName;
            } else if (locale == 'te' && cropData.containsKey('name_te')) {
              cropName = cropData['name_te'] ?? cropName;
            }

            return FarmerCropSelection(
              id: s['id'],
              fieldName: s['field_name'],
              cropName: cropName,
              cropImageUrl: cropData['image_url'],
              cropId: cropData['id'],
              varietyId: s['variety_id'],
              sowingDate: DateTime.parse(sowingDateData['sowing_date']),
            );
          })
          .where((crop) => crop != null)
          .cast<FarmerCropSelection>()
          .toList();

      print('5. Successfully parsed ${loadedCrops.length} crops.');

      if (mounted) {
        setState(() {
          _farmerCrops = loadedCrops;
          if (_farmerCrops.isNotEmpty) {
            _selectFarmerCrop(_farmerCrops.first);
          }
          _isLoading = false;
        });
        _filterAnimationController.forward();
        print('6. State updated successfully.');
      }
    } catch (e, st) {
      print('--- AN ERROR OCCURRED ---');
      print('Error Type: ${e.runtimeType}');
      print('Error Message: $e');
      print('Stack Trace: $st');
      print('-------------------------');
      _showErrorSnackbar(context.tr('load_crops_error'));
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
      List<String> stageFields = ['id', 'stage_name_en'];
      if (locale == 'te') stageFields.add('stage_name_te');
      if (locale == 'hi') stageFields.add('stage_name_hi');
      String stageSelectStr = stageFields.join(', ');

      // FIX 3: Dynamic select for stages
      final stagesData = await supabase
          .from('crop_stages')
          .select(stageSelectStr)
          .eq('crop_id', farmerCrop.cropId);

      final List<CropStage> loadedStages = (stagesData as List).map((s) {
        // Get the correct localized stage name with fallback
        String stageName = s['stage_name_en'] ?? 'Unknown';
        if (locale == 'hi' && s.containsKey('stage_name_hi')) {
          stageName = s['stage_name_hi'] ?? stageName;
        } else if (locale == 'te' && s.containsKey('stage_name_te')) {
          stageName = s['stage_name_te'] ?? stageName;
        }

        return CropStage(id: s['id'], name: stageName);
      }).toList();

      // Calculate days since sowing to find the current stage
      final daysSinceSowing =
          DateTime.now().difference(farmerCrop.sowingDate).inDays;

      CropStage? currentStage;
      try {
        // Query crop_stage_durations to get the current stage's ID
        final durationData = await supabase
            .from('crop_stage_durations')
            .select('stage_id')
            .eq('variety_id', farmerCrop.varietyId)
            .lte('start_day_from_sowing', daysSinceSowing)
            .gte('end_day_from_sowing', daysSinceSowing)
            .single();

        final currentStageId = durationData['stage_id'];
        currentStage = loadedStages.firstWhere((s) => s.id == currentStageId);
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
      _showErrorSnackbar(context.tr('load_stages_error'));
    }
  }

  Future<void> _selectStage(CropStage stage) async {
    setState(() {
      _selectedStage = stage;
      _problems = [];
    });
    _feedAnimationController.reverse();

    try {
      final locale = _getLocaleField(context.locale.languageCode);
      List<String> problemFields = [
        'id',
        'image_url1',
        'image_url2',
        'image_url3',
        'problem_name_en'
      ];
      if (locale == 'te') problemFields.add('problem_name_te');
      if (locale == 'hi') problemFields.add('problem_name_hi');
      String problemSelectStr = problemFields.join(', ');

      // FIX 4: Dynamic select for problems
      final problemsData = await supabase
          .from('crop_problems')
          .select(problemSelectStr)
          .eq('crop_id', _selectedFarmerCrop!.cropId)
          .eq('stage_id', stage.id);

      final List<CropProblem> loadedProblems = (problemsData as List).map((p) {
        // Get the correct localized problem name with fallback
        String problemName = p['problem_name_en'] ?? 'Unknown';
        if (locale == 'hi' && p.containsKey('problem_name_hi')) {
          problemName = p['problem_name_hi'] ?? problemName;
        } else if (locale == 'te' && p.containsKey('problem_name_te')) {
          problemName = p['problem_name_te'] ?? problemName;
        }

        return CropProblem(
          id: p['id'],
          name: problemName,
          imageUrl1: p['image_url1'],
          imageUrl2: p['image_url2'],
          imageUrl3: p['image_url3'],
        );
      }).toList();

      if (mounted) {
        setState(() {
          _problems = loadedProblems;
        });
        _feedAnimationController.forward();
      }
    } catch (e) {
      _showErrorSnackbar(context.tr('load_problems_error'));
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.lexend()),
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
                style: GoogleFonts.lexend(
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
                    style: GoogleFonts.lexend(
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
                      style: GoogleFonts.lexend(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _stages.map((stage) {
                        final isSelected = _selectedStage?.id == stage.id;
                        return FilterChip(
                          label: Text(stage.name),
                          selected: isSelected,
                          onSelected: (_) {
                            _selectStage(stage);
                            Navigator.pop(context);
                          },
                          selectedColor: Colors.green[100],
                          checkmarkColor: Colors.green[700],
                          labelStyle: GoogleFonts.lexend(
                            color:
                                isSelected ? Colors.green[700] : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
                          crop.cropImageUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: crop.cropImageUrl!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
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
                        style: GoogleFonts.lexend(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        crop.cropName,
                        style: GoogleFonts.lexend(
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
                  Expanded(child: _buildProblemFeed()),
                ],
              ),
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
                        style: GoogleFonts.lexend(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_selectedFarmerCrop != null && _selectedStage != null)
                        FadeTransition(
                          opacity: _filterAnimationController,
                          child: Text(
                            '${_selectedFarmerCrop!.cropName} • ${_selectedStage!.name}',
                            style: GoogleFonts.lexend(
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
                              style: GoogleFonts.lexend(
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
              style: GoogleFonts.lexend(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('select_another_stage'),
              style: GoogleFonts.lexend(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
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
                          // Image indicators if multiple images exist
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
                        style: GoogleFonts.lexend(
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
                                    style: GoogleFonts.lexend(
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
                                        style: GoogleFonts.lexend(
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
      child: Column(
        children: [
          Container(
            height: 100,
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 16),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 3,
              itemBuilder: (context, index) => Container(
                height: 280,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
