import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:cropsync/services/creator_service.dart';
import 'package:cropsync/services/auth_service.dart';
import 'package:cropsync/widgets/modern_pill_toast.dart';

class UploadReelScreen extends StatefulWidget {
  const UploadReelScreen({super.key});

  @override
  State<UploadReelScreen> createState() => _UploadReelScreenState();
}

class _UploadReelScreenState extends State<UploadReelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _captionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _sourceUrlController = TextEditingController();
  String _selectedCrop = 'Paddy';
  String _selectedCategory = 'Pest & Disease';
  String _selectedLanguage = 'Telugu';
  bool _rightsDeclared = true;

  final ImagePicker _picker = ImagePicker();
  XFile? _pickedVideo;
  VideoPlayerController? _videoPlayerController;
  bool _isInitializingVideo = false;
  bool _isPublishing = false;

  final List<String> _suggestedTags = [
    '#PaddyCare',
    '#DroneSpray',
    '#OrganicFarming',
    '#FertilizerDose',
    '#PestControl',
    '#AgriTech',
    '#CottonYield',
    '#ChilliCare',
    '#MarketPrices',
  ];
  final Set<String> _selectedTags = {'#AgriTech'};

  @override
  void initState() {
    super.initState();
    _loadUserPhone();
    _captionController.addListener(() => setState(() {}));
  }

  Future<void> _loadUserPhone() async {
    final user = await AuthService.getCurrentUser();
    if (user != null) {
      final phone = (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
          ? user.phoneNumber!
          : user.userId;
      if (phone.isNotEmpty && mounted) {
        setState(() {
          _phoneController.text = phone;
        });
      }
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _phoneController.dispose();
    _sourceUrlController.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo(ImageSource source) async {
    HapticFeedback.lightImpact();
    try {
      final file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 3),
      );
      if (file != null) {
        setState(() {
          _pickedVideo = file;
        });
        _initializeVideoPlayer(File(file.path));
      }
    } catch (e) {
      if (mounted) {
        showModernPillToast(
          context,
          message: 'Could not select video: $e',
          icon: Icons.error_outline_rounded,
          isSuccess: false,
        );
      }
    }
  }

  Future<void> _initializeVideoPlayer(File file) async {
    setState(() => _isInitializingVideo = true);
    await _videoPlayerController?.dispose();

    try {
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      controller.setLooping(true);
      controller.play();
      if (mounted) {
        setState(() {
          _videoPlayerController = controller;
          _isInitializingVideo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitializingVideo = false);
      }
    }
  }

  void _toggleTag(String tag) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _insertQuickHook(String hook) {
    HapticFeedback.selectionClick();
    final current = _captionController.text;
    final updated = current.isEmpty ? hook : '$current $hook';
    _captionController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: updated.length),
    );
  }

  Future<void> _publishReel() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickedVideo == null) {
      HapticFeedback.heavyImpact();
      showModernPillToast(
        context,
        message: 'upload_reel_select_video'.tr(),
        icon: Icons.video_call_rounded,
        isSuccess: false,
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final safeBaseName = _pickedVideo!.name.isNotEmpty
        ? _pickedVideo!.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        : 'video.mp4';
    final fileName = 'reel_${DateTime.now().millisecondsSinceEpoch}_$safeBaseName';
    final videoUrl = _pickedVideo!.path.startsWith('http')
        ? _pickedVideo!.path
        : 'https://kiosk.cropsync.in/Reels/$fileName';

    setState(() => _isPublishing = true);

    final tags = _selectedTags.join(', ');
    final result = await CreatorService.uploadReelDetailed(
      videoUrl: videoUrl,
      videoFile: File(_pickedVideo!.path),
      caption: _captionController.text.trim(),
      musicTitle: 'Original Audio',
      phoneNumber: _phoneController.text.trim(),
      tags: tags,
      crop: _selectedCrop,
      category: _selectedCategory,
      language: _selectedLanguage,
      sourceUrl: _sourceUrlController.text.trim(),
      rightsDeclared: _rightsDeclared,
    );

    if (!mounted) return;
    setState(() => _isPublishing = false);

    if (result.success) {
      HapticFeedback.mediumImpact();
      showModernPillToast(
        context,
        message: result.message ?? 'upload_reel_success'.tr(),
        icon: Icons.check_circle_rounded,
        isSuccess: true,
      );
      Navigator.of(context).pop(true);
    } else {
      showModernPillToast(
        context,
        message: result.error ?? 'Failed to publish reel. Please try again.',
        icon: Icons.error_outline_rounded,
        isSuccess: false,
      );
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // --- PROGRAM DATA BOTTOM SHEETS ---

  void _showCropBottomSheet() {
    HapticFeedback.selectionClick();
    final crops = [
      {'name': 'Paddy', 'sub': 'Rice, Basmati, Sona Masoori', 'icon': Icons.grass_rounded},
      {'name': 'Cotton', 'sub': 'Bt Cotton, Raw Cotton', 'icon': Icons.cloud_outlined},
      {'name': 'Chilli', 'sub': 'Red & Green Chillies, Guntur Mirchi', 'icon': Icons.local_fire_department_rounded},
      {'name': 'Maize', 'sub': 'Corn, Sweet Corn, Fodder', 'icon': Icons.grain_rounded},
      {'name': 'Soybean', 'sub': 'Oilseed, Pulses', 'icon': Icons.eco_rounded},
      {'name': 'Wheat', 'sub': 'Rabi crop, Flour varieties', 'icon': Icons.bakery_dining_rounded},
      {'name': 'Groundnut', 'sub': 'Peanuts, Oilseed', 'icon': Icons.scatter_plot_rounded},
      {'name': 'Sugarcane', 'sub': 'Cane crops, Jaggery varieties', 'icon': Icons.forest_rounded},
      {'name': 'Vegetables', 'sub': 'Tomato, Onion, Brinjal, Okra', 'icon': Icons.local_florist_rounded},
      {'name': 'Fruits', 'sub': 'Mango, Banana, Guava, Citrus', 'icon': Icons.apple_rounded},
      {'name': 'Other', 'sub': 'Millets, Pulses & Mixed Crops', 'icon': Icons.more_horiz_rounded},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = crops.where((c) {
              final name = c['name'] as String;
              final sub = c['sub'] as String;
              return name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  sub.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.grass_rounded, color: Color(0xFF059669), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Target Crop',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                'Select the crop this reel is targeted for',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search crop...',
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF059669), size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: (val) {
                        setModalState(() => searchQuery = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final item = filtered[idx];
                          final isSelected = _selectedCrop == item['name'];
                          return InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedCrop = item['name'] as String);
                              Navigator.pop(ctx);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item['icon'] as IconData,
                                    color: isSelected ? const Color(0xFF059669) : const Color(0xFF64748B),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'] as String,
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected ? const Color(0xFF047857) : const Color(0xFF1E293B),
                                          ),
                                        ),
                                        Text(
                                          item['sub'] as String,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: isSelected ? const Color(0xFF059669) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    color: isSelected ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCategoryBottomSheet() {
    HapticFeedback.selectionClick();
    final categories = [
      {'name': 'Pest & Disease', 'sub': 'Pest remedies, fungal diseases, chemical sprays', 'icon': Icons.bug_report_rounded},
      {'name': 'Fertilizer', 'sub': 'NPK dosages, nano urea, micronutrients', 'icon': Icons.science_rounded},
      {'name': 'Soil Health', 'sub': 'Soil testing, composting, organic matter', 'icon': Icons.landscape_rounded},
      {'name': 'Harvesting', 'sub': 'Harvest timing, storage & handling', 'icon': Icons.content_cut_rounded},
      {'name': 'Farm Machinery', 'sub': 'Drones, tractors, weeders, tools', 'icon': Icons.agriculture_rounded},
      {'name': 'Market Rates', 'sub': 'Mandi prices, MSP updates, forecasts', 'icon': Icons.trending_up_rounded},
      {'name': 'Govt Schemes', 'sub': 'PM-KISAN, subsidies, crop insurance', 'icon': Icons.account_balance_rounded},
      {'name': 'General Advisory', 'sub': 'Seasonal tips, weather alerts, crop care', 'icon': Icons.lightbulb_rounded},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.category_rounded, color: Color(0xFF2563EB), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Advisory Category',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'Select the topic domain for this reel',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final item = categories[idx];
                      final isSelected = _selectedCategory == item['name'];
                      return InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedCategory = item['name'] as String);
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item['icon'] as IconData,
                                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                size: 22,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'] as String,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    Text(
                                      item['sub'] as String,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLanguageBottomSheet() {
    HapticFeedback.selectionClick();
    final languages = [
      {'name': 'Telugu', 'native': 'తెలుగు', 'badge': 'Recommended'},
      {'name': 'English', 'native': 'English', 'badge': 'Universal'},
      {'name': 'Hindi', 'native': 'हिन्दी', 'badge': 'National'},
      {'name': 'Kannada', 'native': 'ಕನ್ನಡ', 'badge': 'Regional'},
      {'name': 'Tamil', 'native': 'தமிழ்', 'badge': 'Regional'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.65,
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.translate_rounded, color: Color(0xFF9333EA), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Audio / Spoken Language',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'Select the primary language spoken in your video',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: languages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final item = languages[idx];
                      final isSelected = _selectedLanguage == item['name'];
                      return InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedLanguage = item['name'] as String);
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFAF5FF) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFA855F7) : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFF3E8FF) : const Color(0xFFE2E8F0),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    (item['name'] as String).substring(0, 2).toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: isSelected ? const Color(0xFF9333EA) : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          item['name'] as String,
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected ? const Color(0xFF7E22CE) : const Color(0xFF1E293B),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            item['badge'] as String,
                                            style: TextStyle(fontSize: 9.5, color: Colors.grey.shade700, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      item['native'] as String,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isSelected ? const Color(0xFF9333EA) : const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: isSelected ? const Color(0xFF9333EA) : const Color(0xFFCBD5E1),
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black12,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF1E293B), size: 22),
          onPressed: () => Navigator.of(context).pop(),
          splashRadius: 20,
          tooltip: 'Close',
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.video_library_rounded, color: Color(0xFF059669), size: 14),
                  const SizedBox(width: 5),
                  Text(
                    'upload_reel_title'.tr(),
                    style: const TextStyle(
                      color: Color(0xFF059669),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _isPublishing ? null : _publishReel,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
              icon: _isPublishing
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.rocket_launch_rounded, size: 14),
              label: Text(
                'upload_reel_publish_btn'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildModernHeroBanner(),
              const SizedBox(height: 18),
              _buildModernVideoCard(),
              const SizedBox(height: 18),
              _buildCaptionCard(),
              const SizedBox(height: 18),
              _buildHashtagCard(),
              const SizedBox(height: 18),
              _buildPartnerMetadataCard(),
              const SizedBox(height: 18),
              _buildContactPhoneCard(),
              const SizedBox(height: 18),
              _buildRightsDeclarationCard(),
              const SizedBox(height: 28),
              _buildBottomPublishButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeroBanner() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agri Creator Partner Program',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Earn monthly base payouts & reach 100K+ farmers across your region with verified advisory reels.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernVideoCard() {
    final hasVideo = _videoPlayerController != null && _videoPlayerController!.value.isInitialized;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hasVideo ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFF1E293B),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (_isInitializingVideo)
            Container(
              height: 280,
              color: const Color(0xFF0F172A),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF10B981)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Optimizing Video Preview...',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            )
          else if (hasVideo)
            Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: 9 / 16,
                  child: VideoPlayer(_videoPlayerController!),
                ),
                // Vignette overlays
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.5),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                // Center Play/Pause button
                IconButton(
                  icon: Icon(
                    _videoPlayerController!.value.isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_filled_rounded,
                    size: 68,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _videoPlayerController!.value.isPlaying
                          ? _videoPlayerController!.pause()
                          : _videoPlayerController!.play();
                    });
                  },
                ),
                // Top floating pills (duration & replace)
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, color: Color(0xFF10B981), size: 13),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(_videoPlayerController!.value.duration),
                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: InkWell(
                    onTap: () => _pickVideo(ImageSource.gallery),
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Change',
                            style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF10B981).withValues(alpha: 0.25),
                          const Color(0xFF059669).withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.video_call_rounded, color: Color(0xFF10B981), size: 40),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'upload_reel_select_video'.tr(),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Vertical 9:16 format recommended · Max 3 mins',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickVideo(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_rounded, size: 16),
                          label: Text('upload_reel_gallery'.tr(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickVideo(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_rounded, size: 16),
                          label: Text('upload_reel_camera'.tr(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    );
  }

  Widget _buildCaptionCard() {
    final charCount = _captionController.text.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF059669)),
                  SizedBox(width: 6),
                  Text(
                    'CAPTION',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Text(
                '$charCount / 500',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: charCount > 450 ? Colors.redAccent : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _captionController,
            maxLength: 500,
            maxLines: 3,
            buildCounter: (_, {currentLength = 0, isFocused = false, maxLength}) => null,
            decoration: InputDecoration(
              hintText: 'Share farming tips, variety reviews, or problem remedies...',
              hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please write a short caption for your reel';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          // Quick Hooks Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickHookChip('🌾 PaddyCare'),
                _buildQuickHookChip('🚜 DroneSpray'),
                _buildQuickHookChip('💧 Drip Irrigation'),
                _buildQuickHookChip('🐛 Pest Remedy'),
                _buildQuickHookChip('💰 High Yield Formula'),
                _buildQuickHookChip('🌱 Organic Farming'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickHookChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => _insertQuickHook(text),
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildHashtagCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tag_rounded, size: 18, color: Color(0xFF059669)),
              SizedBox(width: 6),
              Text(
                'TAGS & TOPICS',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestedTags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return FilterChip(
                label: Text(tag),
                selected: isSelected,
                selectedColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                checkmarkColor: const Color(0xFF059669),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFF059669) : const Color(0xFF334155),
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                ),
                backgroundColor: const Color(0xFFF1F5F9),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onSelected: (_) => _toggleTag(tag),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerMetadataCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.stars_rounded, color: Color(0xFF059669), size: 20),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Program Data & Targeting',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                  ),
                  Text(
                    'Helps match reels with relevant farmers',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 1. Target Crop Selector (Bottom Sheet trigger)
          _buildProgramSelectorTile(
            title: 'Target Crop',
            value: _selectedCrop,
            icon: Icons.grass_rounded,
            badgeColor: const Color(0xFF059669),
            badgeBg: const Color(0xFFECFDF5),
            onTap: _showCropBottomSheet,
          ),
          const SizedBox(height: 12),
          // 2. Advisory Category Selector (Bottom Sheet trigger)
          _buildProgramSelectorTile(
            title: 'Advisory Category',
            value: _selectedCategory,
            icon: Icons.category_rounded,
            badgeColor: const Color(0xFF2563EB),
            badgeBg: const Color(0xFFEFF6FF),
            onTap: _showCategoryBottomSheet,
          ),
          const SizedBox(height: 12),
          // 3. Language Selector (Bottom Sheet trigger)
          _buildProgramSelectorTile(
            title: 'Content Language',
            value: _selectedLanguage,
            icon: Icons.translate_rounded,
            badgeColor: const Color(0xFF9333EA),
            badgeBg: const Color(0xFFFAF5FF),
            onTap: _showLanguageBottomSheet,
          ),
          const SizedBox(height: 14),
          // Source URL (attribution)
          TextFormField(
            controller: _sourceUrlController,
            decoration: InputDecoration(
              labelText: 'Source / Attribution URL (Optional)',
              hintText: 'https://youtube.com/watch?v=... or reel link',
              prefixIcon: const Icon(Icons.link_rounded, size: 18, color: Color(0xFF059669)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramSelectorTile({
    required String title,
    required String value,
    required IconData icon,
    required Color badgeColor,
    required Color badgeBg,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: badgeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Change',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: badgeColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: badgeColor),
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

  Widget _buildContactPhoneCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.call_rounded, size: 16, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              const Text(
                'FARMER DIRECT CONTACT',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  '1-Tap Call',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.phone_rounded, color: Color(0xFF059669), size: 18),
              hintText: 'Enter phone number for farmer calls',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Farmers viewing your reel can tap "Call" directly to ask questions.',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildRightsDeclarationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _rightsDeclared,
            activeColor: const Color(0xFF059669),
            onChanged: (val) {
              setState(() => _rightsDeclared = val ?? true);
            },
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'I confirm that I own or hold valid commercial distribution rights to this agricultural media, that it does not infringe third-party IP, and complies with CropSync Partner Program guidelines.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF166534),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPublishButton() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isPublishing ? null : _publishReel,
          child: Center(
            child: _isPublishing
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Publishing Reel to CropSync...',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'upload_reel_publish_btn'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
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
