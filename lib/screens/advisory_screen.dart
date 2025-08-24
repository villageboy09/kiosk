import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/main.dart';
import 'package:cropsync/screens/advisory_details.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

// Data Models
class FarmerCropSelection {
  final int id;
  final String fieldName;
  final String cropName;
  final String? cropImageUrl;
  final int cropId;
  FarmerCropSelection(
      {required this.id,
      required this.fieldName,
      required this.cropName,
      this.cropImageUrl,
      required this.cropId});
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

  // Data
  List<FarmerCropSelection> _farmerCrops = [];
  List<CropStage> _stages = [];
  List<CropProblem> _problems = [];

  // Selections
  FarmerCropSelection? _selectedFarmerCrop;
  CropStage? _selectedStage;

  // Animation
  late AnimationController _feedAnimationController;

  @override
  void initState() {
    super.initState();
    _feedAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fetchInitialData();
  }

  @override
  void dispose() {
    _feedAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    try {
      final farmerResponse = await supabase
          .from('farmers')
          .select('id')
          .eq('user_id', supabase.auth.currentUser!.id)
          .single();
      final farmerId = farmerResponse['id'];

      final selectionsData = await supabase
          .from('farmer_crop_selections')
          .select('id, field_name, crops(id, name_te, image_url)')
          .eq('farmer_id', farmerId);

      final List<FarmerCropSelection> loadedCrops =
          (selectionsData as List).map((s) {
        final cropData = s['crops'];
        return FarmerCropSelection(
          id: s['id'],
          fieldName: s['field_name'],
          cropName: cropData['name_te'],
          cropImageUrl: cropData['image_url'],
          cropId: cropData['id'],
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
      }
    } catch (e) {
      _showErrorSnackbar('మీ పంటల వివరాలను లోడ్ చేయడంలో విఫలమైంది.');
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
      final stagesData = await supabase
          .from('crop_stages')
          .select('id, stage_name_te')
          .eq('crop_id', farmerCrop.cropId);
      final List<CropStage> loadedStages = (stagesData as List)
          .map((s) => CropStage(id: s['id'], name: s['stage_name_te']))
          .toList();

      if (mounted) {
        setState(() {
          _stages = loadedStages;
          if (_stages.isNotEmpty) {
            _selectStage(_stages.first);
          }
        });
      }
    } catch (e) {
      _showErrorSnackbar('పంట దశలను లోడ్ చేయడంలో విఫలమైంది.');
    }
  }

  Future<void> _selectStage(CropStage stage) async {
    setState(() {
      _selectedStage = stage;
      _problems = [];
    });
    _feedAnimationController.reverse();

    try {
      final problemsData = await supabase
          .from('crop_problems')
          .select('id, problem_name_te, image_url1, image_url2, image_url3')
          .eq('crop_id', _selectedFarmerCrop!.cropId)
          .eq('stage_id', stage.id);

      final List<CropProblem> loadedProblems = (problemsData as List).map((p) {
        return CropProblem(
          id: p['id'],
          name: p['problem_name_te'],
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
      _showErrorSnackbar('సమస్యలను లోడ్ చేయడంలో విఫలమైంది.');
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
        child: _isLoading
            ? _buildShimmerEffect()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader('నా పంటలు (My Crops)'),
                  _buildFarmerCropFilter(),
                  _buildHeader('పంట దశ (Crop Stage)'),
                  _buildStageFilter(),
                  const Divider(height: 1),
                  Expanded(child: _buildProblemFeed()),
                ],
              ),
      ),
    );
  }

  // --- UI Builder Widgets ---

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Text(title,
          style: GoogleFonts.lexend(fontSize: 22, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFarmerCropFilter() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _farmerCrops.length,
        itemBuilder: (context, index) {
          final crop = _farmerCrops[index];
          final isSelected = _selectedFarmerCrop?.id == crop.id;
          return _buildFilterCard(
            title: crop.fieldName,
            subtitle: crop.cropName,
            imageUrl: crop.cropImageUrl,
            isSelected: isSelected,
            onTap: () => _selectFarmerCrop(crop),
          );
        },
      ),
    );
  }

  Widget _buildStageFilter() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _stages.length,
        itemBuilder: (context, index) {
          final stage = _stages[index];
          final isSelected = _selectedStage?.id == stage.id;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(stage.name, style: GoogleFonts.lexend()),
              selected: isSelected,
              onSelected: (_) => _selectStage(stage),
              selectedColor: Colors.green[100],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProblemFeed() {
    if (_problems.isEmpty) {
      return Center(
          child: Text('ఈ దశకు సమస్యలు కనుగొనబడలేదు.',
              style: GoogleFonts.lexend()));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _problems.length,
      itemBuilder: (context, index) {
        final problem = _problems[index];
        return FadeTransition(
          opacity: _feedAnimationController,
          child: _buildProblemCard(problem),
        );
      },
    );
  }

  Widget _buildFilterCard(
      {required String title,
      String? subtitle,
      String? imageUrl,
      required bool isSelected,
      VoidCallback? onTap}) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: isSelected ? 6 : 2,
      shadowColor: isSelected
          ? Colors.green.withValues(alpha: 0.5)
          : Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: isSelected ? Colors.green : Colors.grey[300]!, width: 2.5),
      ),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 150,
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: (imageUrl != null && imageUrl.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity)
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.grass,
                            size: 40, color: Colors.grey)),
              ),
              Expanded(
                flex: 1,
                child: Center(
                  child: Text(title,
                      style: GoogleFonts.lexend(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProblemCard(CropProblem problem) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Column(
        children: [
          if (problem.imageUrl1 != null && problem.imageUrl1!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: problem.imageUrl1!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  Container(height: 180, color: Colors.grey[200]),
              errorWidget: (context, url, error) => Container(
                  height: 180,
                  color: Colors.grey[200],
                  child: const Icon(Icons.error)),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(problem.name,
                      style: GoogleFonts.lexend(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) =>
                          AdvisoryDetailScreen(problem: problem),
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                  child: Text('సలహా చూడండి', style: GoogleFonts.lexend()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Container(height: 24, width: 200, color: Colors.white),
          ),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 3,
              itemBuilder: (context, index) =>
                  Card(child: Container(width: 150, color: Colors.white)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Container(height: 24, width: 150, color: Colors.white),
          ),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 4,
              itemBuilder: (context, index) => Container(
                  width: 100,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20))),
            ),
          ),
        ],
      ),
    );
  }
}
