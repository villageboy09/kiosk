import 'dart:async';
import 'dart:io';
import 'package:cropsync/models/crop_problem.dart';
import 'package:cropsync/screens/advisory_details.dart';
import 'package:cropsync/screens/saved_advisories_screen.dart';
import 'package:cropsync/services/ai_credit_service.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/deepseek_plant_doctor_service.dart';
import 'package:cropsync/services/location_service.dart';
import 'package:cropsync/services/razorpay_payment_service.dart';
import 'package:cropsync/services/saved_advisories_service.dart';
import 'package:cropsync/services/text_to_speech_service.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:cropsync/utils/safe_parser.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropsync/widgets/language_selector.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cropsync/services/copyright_free_reference_service.dart';

class PlantDoctorScreen extends StatefulWidget {
  static const List<Map<String, dynamic>> supportedCrops = [
    {
      'id': 1,
      'name_en': 'Paddy',
      'name_te': 'వరి',
      'emoji': '🌾',
      'image_url': 'https://app.cropsync.in/Paddy.jpg',
      'color': Color(0xFF16A34A),
    },
    {
      'id': 2,
      'name_en': 'Cotton',
      'name_te': 'పత్తి',
      'emoji': '☁️',
      'image_url': 'https://app.cropsync.in/Cotton.jpg',
      'color': Color(0xFF0284C7),
    },
    {
      'id': 18,
      'name_en': 'Chilli',
      'name_te': 'మిరప',
      'emoji': '🌶️',
      'image_url': 'https://kiosk.cropsync.in/crops/chilli.jpg',
      'color': Color(0xFFDC2626),
    },
    {
      'id': 19,
      'name_en': 'Tomato',
      'name_te': 'టమాటా',
      'emoji': '🍅',
      'image_url': 'https://kiosk.cropsync.in/crops/tomato.jpg',
      'color': Color(0xFFE11D48),
    },
    {
      'id': 17,
      'name_en': 'Maize',
      'name_te': 'మొక్కజొన్న',
      'emoji': '🌽',
      'image_url': 'https://kiosk.cropsync.in/crops/maize.png',
      'color': Color(0xFFD97706),
    },
    {
      'id': 26,
      'name_en': 'Groundnut',
      'name_te': 'వేరుశనగ',
      'emoji': '🥜',
      'image_url': 'https://kiosk.cropsync.in/crops/groundnut.jpg',
      'color': Color(0xFFB45309),
    },
    {
      'id': 14,
      'name_en': 'Turmeric',
      'name_te': 'పసుపు',
      'emoji': '🌱',
      'image_url': 'https://kiosk.cropsync.in/crops/turmeric.jpg',
      'color': Color(0xFFF59E0B),
    },
    {
      'id': 12,
      'name_en': 'Sunflower',
      'name_te': 'పొద్దుతిరుగుడు',
      'emoji': '🌻',
      'image_url': 'https://kiosk.cropsync.in/crops/sunflower.jpg',
      'color': Color(0xFFEAB308),
    },
    {
      'id': 13,
      'name_en': 'Banana',
      'name_te': 'అరటి',
      'emoji': '🍌',
      'image_url': 'https://kiosk.cropsync.in/crops/banana.jpg',
      'color': Color(0xFFCA8A04),
    },
    {
      'id': 23,
      'name_en': 'Sugarcane',
      'name_te': 'చెరకు',
      'emoji': '🎋',
      'image_url': 'https://kiosk.cropsync.in/crops/sugarcane.jpg',
      'color': Color(0xFF059669),
    },
    {
      'id': 28,
      'name_en': 'Onion',
      'name_te': 'ఉల్లిపాయ',
      'emoji': '🧅',
      'image_url': 'https://kiosk.cropsync.in/crops/onion.jpg',
      'color': Color(0xFF9333EA),
    },
    {
      'id': 29,
      'name_en': 'Soybean',
      'name_te': 'సోయాబీన్',
      'emoji': '🌿',
      'image_url': 'https://kiosk.cropsync.in/crops/soybean.jpg',
      'color': Color(0xFF15803D),
    },
    {
      'id': 30,
      'name_en': 'Wheat',
      'name_te': 'గోధుమ',
      'emoji': '🌾',
      'image_url': 'https://kiosk.cropsync.in/crops/wheat.jpg',
      'color': Color(0xFFD97706),
    },
    {
      'id': 27,
      'name_en': 'Mango',
      'name_te': 'మామిడి',
      'emoji': '🥭',
      'image_url': 'https://kiosk.cropsync.in/crops/mango.jpg',
      'color': Color(0xFFEA580C),
    },
    {
      'id': 34,
      'name_en': 'Pomegranate',
      'name_te': 'దానిమ్మ',
      'emoji': '🍎',
      'image_url': 'https://kiosk.cropsync.in/crops/pomegranate.jpg',
      'color': Color(0xFFBE123C),
    },
    {
      'id': 35,
      'name_en': 'Grapes',
      'name_te': 'ద్రాక్ష',
      'emoji': '🍇',
      'image_url': 'https://kiosk.cropsync.in/crops/grapes.jpg',
      'color': Color(0xFF7E22CE),
    },
    {
      'id': 24,
      'name_en': 'Brinjal',
      'name_te': 'వంకాయ',
      'emoji': '🍆',
      'image_url': 'https://kiosk.cropsync.in/crops/brinjal.jpg',
      'color': Color(0xFF6B21A8),
    },
    {
      'id': 32,
      'name_en': 'Okra',
      'name_te': 'బెండకాయ',
      'emoji': '🥬',
      'image_url': 'https://kiosk.cropsync.in/crops/okra.jpg',
      'color': Color(0xFF166534),
    },
    {
      'id': 33,
      'name_en': 'Potato',
      'name_te': 'బంగాళాదుంప',
      'emoji': '🥔',
      'image_url': 'https://kiosk.cropsync.in/crops/potato.jpg',
      'color': Color(0xFF78350F),
    },
    {
      'id': 31,
      'name_en': 'Garlic',
      'name_te': 'వెల్లుల్లి',
      'emoji': '🧄',
      'image_url': 'https://kiosk.cropsync.in/crops/garlic.jpg',
      'color': Color(0xFF64748B),
    },
    {
      'id': 20,
      'name_en': 'Bitter Gourd',
      'name_te': 'కాకర',
      'emoji': '🥒',
      'image_url': 'https://kiosk.cropsync.in/crops/bitter_gourd.jpg',
      'color': Color(0xFF15803D),
    },
    {
      'id': 25,
      'name_en': 'Cumin',
      'name_te': 'జీలకర్ర',
      'emoji': '🌾',
      'image_url': 'https://kiosk.cropsync.in/crops/cumin.jpg',
      'color': Color(0xFF92400E),
    },
    {
      'id': 22,
      'name_en': 'Apple',
      'name_te': 'ఆపిల్',
      'emoji': '🍏',
      'image_url': 'https://kiosk.cropsync.in/crops/apple.jpg',
      'color': Color(0xFFDC2626),
    },
    {
      'id': 21,
      'name_en': 'Tea',
      'name_te': 'టీ',
      'emoji': '🍵',
      'image_url': 'https://kiosk.cropsync.in/crops/tea.jpg',
      'color': Color(0xFF15803D),
    },
  ];
  final String? imagePath;
  final ImageSource? initialSource;
  final Map<String, dynamic>? preloadedResult;
  final int? selectedCropId;
  final String? selectedCropName;

  const PlantDoctorScreen({
    super.key,
    this.imagePath,
    this.initialSource,
    this.preloadedResult,
    this.selectedCropId,
    this.selectedCropName,
  });

  @override
  State<PlantDoctorScreen> createState() => _PlantDoctorScreenState();
}

class _PlantDoctorScreenState extends State<PlantDoctorScreen> {
  static List<Map<String, dynamic>> get _supportedCrops => PlantDoctorScreen.supportedCrops;
  // AI Diagnosis State
  bool _isLoading = false;
  String? _errorMsg;
  Map<String, dynamic>? _analysisResult;
  List<Map<String, dynamic>>? _problemsList;
  bool _hasVerifiedAdvisory = false;
  String? _activeImagePath;
  int? _activeCropId;
  String? _activeCropName;
  final ImagePicker _picker = ImagePicker();
  bool _isSaved = false;

  // Dynamic loading texts — resolved at runtime so locale is respected
  int _loadingTextIndex = 0;
  Timer? _loadingTimer;
  List<String> get _loadingTexts => [
        'diag_loading_1'.tr(),
        'diag_loading_2'.tr(),
        'diag_loading_3'.tr(),
        'diag_loading_4'.tr(),
        'diag_loading_5'.tr(),
      ];

  // Credit & Razorpay State
  CreditStatus? _creditStatus;
  late final RazorpayPaymentService _razorpayService;
  late final TextToSpeechService _ttsService;
  bool _isPaymentProcessing = false;

  // New Design UI State (Matches Reference Images)
  int _selectedTabIndex = 0; // 0: Treatment, 1: About the Problem, 2: Prevention
  int _currentImagePage = 0;
  late final PageController _imagePageController;
  List<SavedAdvisory> _recentDiagnoses = [];
  List<CopyrightFreeReferencePhoto> _copyrightFreePhotos = [];

  @override
  void initState() {
    super.initState();
    _imagePageController = PageController(viewportFraction: 0.82);
    _activeImagePath = widget.imagePath;
    _analysisResult = widget.preloadedResult;
    _activeCropId = widget.selectedCropId;
    _activeCropName = widget.selectedCropName;
    _razorpayService = RazorpayPaymentService();
    _ttsService = TextToSpeechService();
    _loadCreditStatus();
    _loadRecentDiagnoses();

    if (_analysisResult != null) {
      _checkIfSaved();
      final crop = _analysisResult!['detected_crop_name']?.toString() ?? widget.selectedCropName;
      final prob = _analysisResult!['matched_problem_name']?.toString();
      final isH = _analysisResult!['health_status']?.toString().toLowerCase() == 'healthy';
      _fetchCopyrightFreeReferences(cropName: crop, problemName: prob, isHealthy: isH);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialSource != null &&
          widget.preloadedResult == null &&
          widget.imagePath == null) {
        _localPickImage(widget.initialSource!);
      }
    });
  }

  void _cancelScan() {
    _loadingTimer?.cancel();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMsg = null;
      });
    }
  }

  Future<void> _fetchCopyrightFreeReferences({
    String? cropName,
    String? problemName,
    bool isHealthy = false,
  }) async {
    try {
      final photos = await CopyrightFreeReferenceService.fetchReferences(
        cropName: cropName,
        problemName: problemName,
        isHealthy: isHealthy,
      );
      if (mounted) {
        setState(() {
          _copyrightFreePhotos = photos;
        });
      }
    } catch (e) {
      debugPrint("Error fetching copyright-free reference photos: $e");
    }
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    _loadingTimer?.cancel();
    _razorpayService.dispose();
    _ttsService.stop();
    super.dispose();
  }

  Future<void> _loadRecentDiagnoses() async {
    try {
      final list = await SavedAdvisoriesService.getSavedAdvisories();
      if (mounted) {
        setState(() {
          _recentDiagnoses = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCreditStatus() async {
    final status = await AiCreditService.getCreditStatus();
    if (mounted) {
      setState(() {
        _creditStatus = status;
      });
    }
  }

  Future<void> _checkIfSaved() async {
    if (_analysisResult == null) return;
    final problemName =
        _analysisResult!['matched_problem_name']?.toString() ?? '';
    final cropName = _analysisResult!['detected_crop_name']?.toString();
    if (problemName.isNotEmpty) {
      final saved = await SavedAdvisoriesService.isAdvisorySaved(
        problemName,
        cropName: cropName,
      );
      if (mounted) {
        setState(() => _isSaved = saved);
      }
    }
  }

  Future<void> _toggleSaveAdvisory() async {
    if (_analysisResult == null) return;
    HapticFeedback.selectionClick();
    final result = _analysisResult!;
    final problemName =
        result['matched_problem_name']?.toString() ?? 'Crop Issue';
    final cropName = result['detected_crop_name']?.toString();
    final healthStatus =
        result['health_status']?.toString().toLowerCase() ?? 'healthy';
    final confidence =
        ((result['confidence'] as num? ?? 0.88) * 100).round();
    final rawAnalysis = result['ai_analysis']?.toString() ?? '';
    final weatherImpact = result['weather_impact']?.toString();
    final controls = result['ai_control_measures'] as Map<String, dynamic>?;

    final chemicalControls = controls?['chemical'] is List
        ? List<String>.from(controls!['chemical'])
        : <String>[];
    final biologicalControls = controls?['biological'] is List
        ? List<String>.from(controls!['biological'])
        : <String>[];
    final preventativeControls = controls?['preventative'] is List
        ? List<String>.from(controls!['preventative'])
        : <String>[];
    final symptoms = result['observed_symptoms'] is List
        ? List<String>.from(result['observed_symptoms'])
        : <String>[];
    final recoveryTips = result['recovery_recommendations'] is List
        ? List<String>.from(result['recovery_recommendations'])
        : <String>[];
    final matchedId = SafeParser.toNullableInt(result['matched_problem_id']);

    if (_isSaved) {
      final list = await SavedAdvisoriesService.getSavedAdvisories();
      final item = list.firstWhere(
        (it) => it.problemName.toLowerCase() == problemName.toLowerCase(),
        orElse: () => list.first,
      );
      await SavedAdvisoriesService.deleteAdvisory(item.id);
      if (mounted) {
        setState(() => _isSaved = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('diag_saved_removed'.tr()),
            backgroundColor: const Color(0xFF334155),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      await SavedAdvisoriesService.saveAdvisory(
        cropName: cropName,
        problemName: problemName,
        healthStatus: healthStatus,
        confidence: confidence,
        sourceImagePath: _activeImagePath,
        summary: rawAnalysis,
        weatherImpact: weatherImpact,
        chemicalControls: chemicalControls,
        biologicalControls: biologicalControls,
        preventativeControls: preventativeControls,
        symptoms: symptoms,
        recoveryTips: recoveryTips,
        matchedProblemId: matchedId,
      );
      if (mounted) {
        setState(() => _isSaved = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('diag_saved_success'.tr()),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _shareAdvisory() {
    if (_analysisResult == null) return;
    HapticFeedback.selectionClick();
    final result = _analysisResult!;
    final problemName =
        result['matched_problem_name']?.toString() ?? 'Unknown Issue';
    final cropName = result['detected_crop_name']?.toString();
    final confidence =
        ((result['confidence'] as num? ?? 0.88) * 100).round();
    final rawAnalysis = result['ai_analysis']?.toString() ?? '';
    final controls = result['ai_control_measures'] as Map<String, dynamic>?;
    final weatherImpact = result['weather_impact']?.toString();

    final buffer = StringBuffer();
    buffer.writeln("🌿 CropSync Plant Doctor Advisory");
    if (cropName != null && cropName.isNotEmpty) {
      buffer.writeln("🌾 Crop: $cropName");
    }
    buffer.writeln("⚠️ Issue: $problemName ($confidence% Match)");
    if (rawAnalysis.isNotEmpty) {
      buffer.writeln("\n📋 Diagnosis:\n$rawAnalysis");
    }

    if (controls != null) {
      final chem = controls['chemical'] is List
          ? List<String>.from(controls['chemical'])
          : <String>[];
      final bio = controls['biological'] is List
          ? List<String>.from(controls['biological'])
          : <String>[];
      if (chem.isNotEmpty) {
        buffer.writeln("\n🧪 Recommended Chemical Spray (Per Acre):");
        for (final c in chem) {
          buffer.writeln("• $c");
        }
      }
      if (bio.isNotEmpty) {
        buffer.writeln("\n🌱 Organic & Biological Treatment:");
        for (final b in bio) {
          buffer.writeln("• $b");
        }
      }
    }

    if (weatherImpact != null && weatherImpact.trim().isNotEmpty) {
      buffer.writeln("\n🌦️ Weather Spray Advice:\n$weatherImpact");
    }

    buffer.writeln("\n📲 Diagnosed via CropSync App • Smart Farming Partner");
    buffer.writeln("https://cropsync.in");

    final text = buffer.toString();
    if (_activeImagePath != null && File(_activeImagePath!).existsSync()) {
      SharePlus.instance.share(
        ShareParams(
          files: [XFile(_activeImagePath!)],
          text: text,
          subject: "CropSync: $problemName",
        ),
      );
    } else {
      SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: "CropSync: $problemName",
        ),
      );
    }
  }

  Future<void> _analyzeImage() async {
    if (_activeImagePath == null) return;
    _ttsService.stop();
    final locale = context.locale.languageCode;

    // Verify user has remaining credits
    final canScan = await AiCreditService.canPerformAnalysis();
    if (!canScan) {
      if (mounted) {
        _showPurchaseCreditsModal(onSuccess: () => _analyzeImage());
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
      _analysisResult = null;
      _isSaved = false;
      _loadingTextIndex = 0;
    });

    _loadingTimer?.cancel();
    _loadingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted && _isLoading) {
        setState(() {
          _loadingTextIndex = (_loadingTextIndex + 1) % _loadingTexts.length;
        });
      } else {
        timer.cancel();
      }
    });

    final deepseekKey = dotenv.env['DEEPSEEK_API_KEY'];
    if (deepseekKey == null || deepseekKey.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMsg =
            "DeepSeek API Key is missing. Please add DEEPSEEK_API_KEY to your .env file.";
      });
      _loadingTimer?.cancel();
      return;
    }

    try {
      final cropsList = await ApiService.getCrops(lang: locale);
      final formattedCrops = cropsList
          .map((c) => {
                'id': c['id'],
                'name': c['name'],
              })
          .toList();

      final problemsList = await ApiService.getProblems(lang: locale);
      _problemsList = problemsList;

      final formattedProblems = problemsList
          .map((p) => {
                'id': p['id'],
                'name': p['name'],
                'category': p['category'],
                'crop_id': p['crop_id'],
              })
          .toList();

      final file = File(_activeImagePath!);
      if (!await file.exists()) {
        setState(() {
          _isLoading = false;
          _errorMsg = "Captured image file not found.";
        });
        _loadingTimer?.cancel();
        return;
      }

      // Fetch user GPS position for hyper-local weather tool execution
      final position = await LocationService.getCurrentPosition();

      // Call DeepSeek Plant Doctor with prompt caching, 24-crop whitelist, and weather tool execution
      final parsed = await DeepSeekPlantDoctorService.diagnoseCrop(
        imageFile: file,
        latitude: position?.latitude,
        longitude: position?.longitude,
        language: locale,
        selectedCropId: _activeCropId,
        selectedCropName: _activeCropName,
        knownCrops: formattedCrops,
        knownProblems: formattedProblems,
      );

      // Deduct 1 credit for successful analysis
      await AiCreditService.consumeCredit();
      await _loadCreditStatus();

      final matchedId = SafeParser.toNullableInt(parsed['matched_problem_id']);
      bool hasVerifiedAdvisory = false;
      if (matchedId != null) {
        try {
          final advisory = await ApiService.getAdvisories(matchedId, lang: locale)
              .timeout(const Duration(seconds: 5));
          if (advisory != null) {
            hasVerifiedAdvisory = true;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _analysisResult = parsed;
          _hasVerifiedAdvisory = hasVerifiedAdvisory;
          _isLoading = false;
        });
        _checkIfSaved();
      }
      _loadingTimer?.cancel();

      // Fetch authentic copyright-free reference photos for foliar comparison
      final detectedCrop = parsed['detected_crop_name']?.toString() ?? _activeCropName;
      final matchedProb = parsed['matched_problem_name']?.toString();
      final isHealthyCrop = parsed['health_status']?.toString().toLowerCase() == 'healthy';
      _fetchCopyrightFreeReferences(
        cropName: detectedCrop,
        problemName: matchedProb,
        isHealthy: isHealthyCrop,
      );
    } on DeepSeekException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = e.message;
        });
      }
      _loadingTimer?.cancel();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = "Diagnosis failed: $e";
        });
      }
      _loadingTimer?.cancel();
      debugPrint("DeepSeek Vision API error: $e");
    }
  }

  Future<void> _localPickImage(ImageSource source) async {
    _ttsService.stop();
    final canScan = await AiCreditService.canPerformAnalysis();
    if (!canScan) {
      if (mounted) {
        _showPurchaseCreditsModal(onSuccess: () => _localPickImage(source));
      }
      return;
    }

    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 1440,
        maxHeight: 1440,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (photo != null && mounted) {
        setState(() {
          _activeImagePath = photo.path;
          _analysisResult = null;
          _errorMsg = null;
          _isSaved = false;
        });
        _analyzeImage();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = "Error picking image: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.locale.languageCode;
    final isTelugu = langCode == 'te';
    final isHindi = langCode == 'hi';

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _ttsService.stop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Center(
              child: InkWell(
                onTap: () {
                  if (_analysisResult != null && widget.preloadedResult == null) {
                    setState(() {
                      _analysisResult = null;
                      _activeImagePath = null;
                      _errorMsg = null;
                      _isLoading = false;
                    });
                  } else {
                    Navigator.maybePop(context);
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 15,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
          ),
          titleSpacing: 8,
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  color: Color(0xFF16A34A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _analysisResult == null ? 'AI Plant Doctor' : 'Plant Doctor',
                      style: GoogleFonts.googleSans(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      _analysisResult == null
                          ? (isTelugu
                              ? 'పంట ఆరోగ్య పరీక్ష'
                              : (isHindi
                                  ? 'फसल स्वास्थ्य निदान'
                                  : 'AI Crop Diagnosis'))
                          : (isTelugu
                              ? 'AI పంట నిర్ధారణ'
                              : (isHindi
                                  ? 'AI फसल निदान'
                                  : 'AI powered crop diagnosis')),
                      style: GoogleFonts.googleSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (_analysisResult == null) ...[
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(
                  child: InkWell(
                    onTap: () => LanguageSelector.show(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.language_rounded, size: 15, color: Color(0xFF475569)),
                          const SizedBox(width: 4),
                          Text(
                            langCode.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              if (_analysisResult!['is_plant'] as bool? ?? false) ...[
                IconButton(
                  icon: Icon(
                    _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: _isSaved ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
                    size: 22,
                  ),
                  tooltip: _isSaved ? 'diag_saved'.tr() : 'diag_save'.tr(),
                  onPressed: _toggleSaveAdvisory,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.share_rounded,
                    color: Color(0xFF0F172A),
                    size: 20,
                  ),
                  tooltip: 'diag_share'.tr(),
                  onPressed: _shareAdvisory,
                ),
              ],
            ],
          ],
        ),
        body: _buildDiagnosisBody(),
        bottomNavigationBar: _analysisResult != null &&
                (_analysisResult!['is_plant'] as bool? ?? false)
            ? _buildStickyBottomActionBar()
            : null,
      ),
    );
  }

  Widget _buildDiagnosisBody() {
    // If no active photo and no preloaded result, show clean landing screen
    if (_activeImagePath == null && _analysisResult == null && !_isLoading) {
      return _buildLandingState();
    }

    // High-Tech AI Scanning HUD Screen during active analysis
    if (_isLoading) {
      return _buildScanningState();
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Crop Image Card (Shown before user starts analysis)
          if (_activeImagePath != null &&
              File(_activeImagePath!).existsSync() &&
              _analysisResult == null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.file(
                    File(_activeImagePath!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

          // Analyze Button if image is loaded but not yet analyzed
          if (_analysisResult == null && _errorMsg == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _analyzeImage,
                      icon: const Icon(Icons.psychology_rounded, color: Colors.white, size: 22),
                      label: Text(
                        'diag_btn_analyze'.tr(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCreditQuotaWidget(),
                ],
              ),
            ),

          // Error Card
          if (_errorMsg != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMsg!,
                      style: const TextStyle(
                        color: Color(0xFF991B1B),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFFDC2626)),
                    onPressed: _analyzeImage,
                    tooltip: 'Retry',
                  ),
                ],
              ),
            ),

          // Results Section
          if (_analysisResult != null) _buildResultSection(),
        ],
      ),
    );
  }

  // ===========================================================================
  // AI SCANNING & ANALYSIS HUD STATE (Modern, Communicative, Dynamic)
  // ===========================================================================

  Widget _buildScanningState() {
    final langCode = context.locale.languageCode;
    final isTe = langCode == 'te';
    final isHi = langCode == 'hi';

    // Step-mapped progress percentages (28% -> 52% -> 76% -> 92% -> 97%)
    final progressValues = [0.28, 0.52, 0.76, 0.92, 0.97];
    final currentProgress = progressValues[_loadingTextIndex.clamp(0, progressValues.length - 1)];
    final percentText = '${(currentProgress * 100).toInt()}%';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Futuristic Camera Viewfinder Card with Glowing HUD Corner Brackets & Laser
          _buildScanningViewfinder(isTe: isTe, isHi: isHi),
          const SizedBox(height: 18),

          // 2. Progress & Step Indicator Card
          _buildScanningProgressCard(
            progressPercent: currentProgress,
            percentText: percentText,
            isTe: isTe,
            isHi: isHi,
          ),
          const SizedBox(height: 16),

          // 3. 4-Stage Progressive Inspection Checklist
          _buildScanningStagesChecklist(isTe: isTe, isHi: isHi),
          const SizedBox(height: 16),

          // 4. Rotating Agronomic Wisdom / Tips Card
          _buildScanningTipCard(isTe: isTe, isHi: isHi),
          const SizedBox(height: 20),

          // 5. Cancel / Retake Action Button
          Center(
            child: OutlinedButton.icon(
              onPressed: _cancelScan,
              icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
              label: Text(
                'diag_cancel'.tr(),
                style: GoogleFonts.googleSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningViewfinder({required bool isTe, required bool isHi}) {
    final cropLabel = _activeCropName != null
        ? _getLocalizedCropName(_activeCropName)
        : (isTe ? 'స్వయంచాలక గుర్తింపు' : (isHi ? 'ऑटो-डिटेक्ट' : 'Auto-Targeting'));

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_activeImagePath != null && File(_activeImagePath!).existsSync())
                Image.file(File(_activeImagePath!), fit: BoxFit.cover)
              else
                Container(
                  color: const Color(0xFF0F172A),
                  child: const Center(
                    child: Icon(Icons.image_rounded, color: Color(0xFF64748B), size: 40),
                  ),
                ),

              // Animated Laser Scanner Overlay
              const LaserScannerOverlay(),

              // Glowing HUD Corner Brackets
              const ViewfinderCornerBrackets(),

              // Center Target Reticle Crosshair
              Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.add_rounded, size: 22, color: Color(0xFF10B981)),
                  ),
                ),
              ),

              // Top Status Badges Row
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Live AI Vision Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'AI VISION ACTIVE',
                            style: GoogleFonts.robotoMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF34D399),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Crop Target Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.center_focus_strong_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(
                            cropLabel,
                            style: GoogleFonts.googleSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Resolution & Status Ticker
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '1440x1440 HD • DEEPSEEK VISION',
                        style: GoogleFonts.robotoMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      Text(
                        '24-CROP WHITELIST',
                        style: GoogleFonts.robotoMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF34D399),
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
    );
  }

  Widget _buildScanningProgressCard({
    required double progressPercent,
    required String percentText,
    required bool isTe,
    required bool isHi,
  }) {
    final title = isTe
        ? 'పంట ఆరోగ్యాన్ని విశ్లేషిస్తోంది...'
        : (isHi ? 'फसल का विश्लेषण हो रहा है...' : 'Analyzing Crop Foliage...');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.googleSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  percentText,
                  style: GoogleFonts.googleSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _loadingTexts[_loadingTextIndex % _loadingTexts.length],
              key: ValueKey<int>(_loadingTextIndex),
              style: GoogleFonts.googleSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.15, end: progressPercent),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
                  minHeight: 7,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningStagesChecklist({required bool isTe, required bool isHi}) {
    final stages = [
      {
        'title': isTe
            ? 'ఆకు కొలతలు & పంట గుర్తింపు'
            : (isHi ? 'पत्ती की पहचान और फसल प्रकार' : 'Leaf Geometry & Crop Detection'),
        'desc': isTe
            ? 'ఆకు ఆకారం, రంగు మరియు క్లోరోఫిల్ స్థాయిలను లెక్కిస్తోంది'
            : (isHi ? 'पत्ती के आकार और क्लोरोफिल का विश्लेषण' : 'Mapping leaf contours, veins, and chlorophyll levels'),
      },
      {
        'title': isTe
            ? 'తెగులు మచ్చలు & లక్షణాల శోధన'
            : (isHi ? 'रोग के धब्बे और लक्षणों की पहचान' : 'Foliar Lesion & Pathogen Recognition'),
        'desc': isTe
            ? 'శిలీంద్రపు మచ్చలు, బూడిద, లేదా రంధ్రాలను గుర్తిస్తోంది'
            : (isHi ? 'फंगल धब्बे, मोज़ेक या कीट के निशानों की जांच' : 'Detecting fungal spots, blight, chlorosis, or pest bites'),
      },
      {
        'title': isTe
            ? '24 పంటల రోగనిరోధక సరిపోలిక'
            : (isHi ? '24 फसलों के रोग डेटाबेस से मिलान' : '24-Crop Pathology Cross-Referencing'),
        'desc': isTe
            ? 'ICAR & PlantVillage రోగనిర్థారణ డేటాతో సరిపోలుస్తోంది'
            : (isHi ? 'ICAR एवं आधिकारिक कृषि डेटाबेस से सत्यापन' : 'Cross-checking with ICAR & PlantVillage pathology registry'),
      },
      {
        'title': isTe
            ? 'వాతావరణ స్ప్రే & నివారణ ప్రణాళిక'
            : (isHi ? 'मौसम अनुसार छिड़काव और उपचार' : 'Weather-Smart Treatment Formulation'),
        'desc': isTe
            ? 'వర్షం ముప్పును లెక్కించి ఎకరాకు సరైన మోతాదును నిర్ణయిస్తోంది'
            : (isHi ? 'वर्षा की संभावना और प्रति एकड़ सटीक खुराक तैयार' : 'Evaluating rain risk & formulating CIBRC dosage per acre'),
      },
    ];

    final currentStep = _loadingTextIndex.clamp(0, 3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_rounded, size: 18, color: Color(0xFF16A34A)),
              const SizedBox(width: 8),
              Text(
                isTe
                    ? 'AI విశ్లేషణ దశలు'
                    : (isHi ? 'AI विश्लेषण चरण' : 'AI Diagnostic Stages'),
                style: GoogleFonts.googleSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(stages.length, (idx) {
            final stage = stages[idx];
            final isDone = idx < currentStep;
            final isActive = idx == currentStep;

            return Padding(
              padding: EdgeInsets.only(bottom: idx == stages.length - 1 ? 0 : 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? const Color(0xFFDCFCE7)
                          : (isActive ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC)),
                      border: Border.all(
                        color: isDone
                            ? const Color(0xFF16A34A)
                            : (isActive ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0)),
                        width: isActive ? 2.0 : 1.2,
                      ),
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check_rounded, size: 16, color: Color(0xFF16A34A))
                          : (isActive
                              ? const SizedBox(
                                  width: 13,
                                  height: 13,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
                                  ),
                                )
                              : Text(
                                  '${idx + 1}',
                                  style: GoogleFonts.googleSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                )),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stage['title'] as String,
                          style: GoogleFonts.googleSans(
                            fontSize: 13,
                            fontWeight: isActive ? FontWeight.w800 : (isDone ? FontWeight.w700 : FontWeight.w600),
                            color: isActive
                                ? const Color(0xFF0F172A)
                                : (isDone ? const Color(0xFF334155) : const Color(0xFF94A3B8)),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stage['desc'] as String,
                          style: GoogleFonts.googleSans(
                            fontSize: 11.5,
                            color: isActive
                                ? const Color(0xFF16A34A)
                                : (isDone ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildScanningTipCard({required bool isTe, required bool isHi}) {
    final tips = [
      isTe
          ? 'ఖచ్చితమైన ఫలితాల కోసం పంట ఆకుపై సహజ పగటి వెలుతురులో ఫోటో తీయండి.'
          : (isHi
              ? 'सटीक परिणाम के लिए दिन के प्राकृतिक उजाले में प्रभावित पत्ती की साफ फोटो लें।'
              : 'Hold phone steady in bright daylight for 98%+ foliar disease accuracy.'),
      isTe
          ? 'CropSync వాతావరణాన్ని పరిశీలించి వర్షానికి కొట్టుకుపోకుండా స్ప్రే సమయాన్ని నిర్ణయిస్తుంది.'
          : (isHi
              ? 'क्रॉपसिंक मौसम देखकर छिड़काव का समय बताता है ताकि बारिश में दवा बर्बाद न हो।'
              : 'CropSync correlates live radar weather so rain won\'t wash away your costly sprays.'),
      isTe
          ? 'రసాయన విషప్రభావాన్ని నివారించడానికి CropSync కేవలం 24 ప్రధాన పంటలకు మాత్రమే నిర్ధారణ చేస్తుంది.'
          : (isHi
              ? 'क्रॉपसिंक रासायनिक विषाक्तता रोकने के लिए 24 मुख्य फसलों पर ही सटीक सलाह देता है।'
              : 'Strict 24-crop whitelist prevents chemical toxicity and inappropriate pesticide use.'),
    ];

    final currentTip = tips[_loadingTextIndex % tips.length];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, size: 18, color: Color(0xFFD97706)),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                currentTip,
                key: ValueKey<String>(currentTip),
                style: GoogleFonts.googleSans(
                  fontSize: 12,
                  color: const Color(0xFF92400E),
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandingState() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Crop Selection Header & Row
          _buildVisualCropSelector(),
          const SizedBox(height: 18),

          // 2. Hero "Take a Photo" Card (Matches Reference Image 2)
          _buildHeroCameraCard(),
          const SizedBox(height: 22),

          // 3. Recent Diagnoses Section (Matches Reference Image 2)
          _buildRecentDiagnosesSection(),
          const SizedBox(height: 20),

          // 4. Tips for accurate results Card (Matches Reference Image 2)
          _buildTipsCard(),
          const SizedBox(height: 16),

          // 5. Daily Credit Quota Pill
          _buildCreditQuotaWidget(),
        ],
      ),
    );
  }

  /// 1. Crop Selector with horizontal list and "24 Crops >" button
  Widget _buildVisualCropSelector() {
    final langCode = context.locale.languageCode;
    final isTelugu = langCode == 'te';
    final isHindi = langCode == 'hi';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isTelugu ? 'Crop (పంట)' : (isHindi ? 'Crop (फसल)' : 'Crop'),
                style: GoogleFonts.googleSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: _showAll24CropsModal,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '24 Crops',
                        style: GoogleFonts.googleSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded, size: 17, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _supportedCrops.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                final isSelected = _activeCropId == null;
                return _buildAutoDetectCard(isSelected);
              }
              final crop = _supportedCrops[index - 1];
              final isSelected = _activeCropId == crop['id'];
              return _buildCropPhotoCard(crop, isSelected);
            },
          ),
        ),
      ],
    );
  }

  /// Auto-Detect Option Card
  Widget _buildAutoDetectCard(bool isSelected) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _activeCropId = null;
          _activeCropName = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 82,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
            width: isSelected ? 2.0 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF16A34A), size: 20),
            ),
            const SizedBox(height: 7),
            Text(
              'Auto',
              textAlign: TextAlign.center,
              maxLines: 1,
              style: GoogleFonts.googleSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                color: isSelected ? const Color(0xFF15803D) : const Color(0xFF0F172A),
              ),
            ),
            Text(
              'AI Detect',
              textAlign: TextAlign.center,
              maxLines: 1,
              style: GoogleFonts.googleSans(
                fontSize: 10,
                color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Individual Crop Photo Card
  Widget _buildCropPhotoCard(Map<String, dynamic> crop, bool isSelected) {
    final langCode = context.locale.languageCode;
    final isTelugu = langCode == 'te';
    final nameTe = crop['name_te'] as String? ?? '';
    final nameEn = crop['name_en'] as String? ?? '';
    final imageUrl = crop['image_url'] as String? ?? '';
    final emoji = crop['emoji'] as String? ?? '🌱';

    final displayName = isTelugu && nameTe.isNotEmpty ? nameTe : nameEn;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (_activeCropId == crop['id']) {
            _activeCropId = null;
            _activeCropName = null;
          } else {
            _activeCropId = crop['id'] as int;
            _activeCropName = nameEn;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 82,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
            width: isSelected ? 2.0 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 44,
                height: 44,
                color: const Color(0xFFF8FAFC),
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Center(
                          child: Text(emoji, style: const TextStyle(fontSize: 22)),
                        ),
                      )
                    : Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 22)),
                      ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              displayName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.googleSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                color: isSelected ? const Color(0xFF15803D) : const Color(0xFF0F172A),
              ),
            ),
            if (isTelugu && nameEn.isNotEmpty)
              Text(
                nameEn,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.googleSans(
                  fontSize: 9.5,
                  color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 2. Hero "Take a Photo" Card (Matches Reference Image 2)
  Widget _buildHeroCameraCard() {
    final langCode = context.locale.languageCode;
    final isTelugu = langCode == 'te';
    final isHindi = langCode == 'hi';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Center circular badge with dark green camera icon
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              color: Color(0xFF059669),
              size: 34,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            isTelugu ? 'ఫోటో తీయండి' : (isHindi ? 'फोटो लें' : 'Take a Photo'),
            style: GoogleFonts.googleSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),

          // Subtitle
          Text(
            isTelugu
                ? 'బాధిత ఆకు, కాండం లేదా కాయ ఫోటో తీయండి'
                : (isHindi
                    ? 'प्रभावित पत्ती, तने या फल की फोटो लें'
                    : 'Snap the affected leaf, stem or fruit'),
            textAlign: TextAlign.center,
            style: GoogleFonts.googleSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 22),

          // Primary "Take Photo" Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _localPickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
              label: Text(
                isTelugu ? 'ఫోటో తీయండి' : (isHindi ? 'फोटो लें' : 'Take Photo'),
                style: GoogleFonts.googleSans(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // "or" Divider
          Row(
            children: [
              Expanded(child: Container(height: 1, color: const Color(0xFFF1F5F9))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'or',
                  style: GoogleFonts.googleSans(
                    fontSize: 12.5,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Container(height: 1, color: const Color(0xFFF1F5F9))),
            ],
          ),
          const SizedBox(height: 14),

          // Secondary "Choose from Gallery" Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _localPickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_rounded, color: Color(0xFF334155), size: 20),
              label: Text(
                isTelugu ? 'గ్యాలరీ నుండి ఎంచుకోండి' : (isHindi ? 'गैलरी से चुनें' : 'Choose from Gallery'),
                style: GoogleFonts.googleSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFF8FAFC),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Recent Diagnoses Section (Matches Reference Image 2)
  Widget _buildRecentDiagnosesSection() {
    final langCode = context.locale.languageCode;
    final isTelugu = langCode == 'te';
    final isHindi = langCode == 'hi';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isTelugu ? 'ఇటీవలి నిర్ధారణలు' : (isHindi ? 'हाल के निदान' : 'Recent Diagnoses'),
                style: GoogleFonts.googleSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SavedAdvisoriesScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        isTelugu ? 'అన్నీ చూడండి' : (isHindi ? 'सभी देखें' : 'See all'),
                        style: GoogleFonts.googleSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded, size: 17, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        if (_recentDiagnoses.isNotEmpty)
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _recentDiagnoses.length > 5 ? 5 : _recentDiagnoses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final adv = _recentDiagnoses[index];
                return _buildRecentDiagnosisCard(
                  cropName: adv.cropName ?? 'Crop',
                  problemName: adv.problemName,
                  timeText: _formatTimeAgo(adv.createdAt),
                  imagePath: adv.imagePath,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlantDoctorScreen(
                          preloadedResult: {
                            'is_plant': true,
                            'is_crop_supported': true,
                            'detected_crop_name': adv.cropName,
                            'matched_problem_name': adv.problemName,
                            'matched_problem_id': adv.matchedProblemId,
                            'confidence': adv.confidence / 100.0,
                            'health_status': adv.healthStatus,
                            'ai_analysis': adv.summary,
                            'weather_impact': adv.weatherImpact,
                            'observed_symptoms': adv.symptoms,
                            'recovery_recommendations': adv.recoveryTips,
                            'ai_control_measures': {
                              'chemical': adv.chemicalControls,
                              'biological': adv.biologicalControls,
                              'preventative': adv.preventativeControls,
                            },
                          },
                          imagePath: adv.imagePath,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        else
          // Show realistic sample cards matching Image 2 mockup if user hasn't saved scans yet
          Row(
            children: [
              Expanded(
                child: _buildRecentDiagnosisCard(
                  cropName: 'Paddy',
                  problemName: 'Brown Spot',
                  timeText: '2 hours ago',
                  sampleAssetPath: 'assets/images/placeholder.png',
                  onTap: () => _localPickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildRecentDiagnosisCard(
                  cropName: 'Chilli',
                  problemName: 'Leaf Curl',
                  timeText: 'Yesterday',
                  sampleAssetPath: 'assets/images/placeholder.png',
                  onTap: () => _localPickImage(ImageSource.camera),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildRecentDiagnosisCard({
    required String cropName,
    required String problemName,
    required String timeText,
    String? imagePath,
    String? sampleAssetPath,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 50,
                height: 50,
                color: const Color(0xFFF1F5F9),
                child: imagePath != null && File(imagePath).existsSync()
                    ? Image.file(File(imagePath), fit: BoxFit.cover)
                    : const Icon(Icons.eco_rounded, color: Color(0xFF16A34A), size: 24),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    cropName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.googleSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    problemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.googleSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeText,
                    style: GoogleFonts.googleSans(
                      fontSize: 10,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  /// 4. Tips for accurate results Card (Matches Reference Image 2)
  Widget _buildTipsCard() {
    final langCode = context.locale.languageCode;
    final isTelugu = langCode == 'te';
    final isHindi = langCode == 'hi';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFEF3C7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isTelugu
                    ? 'ఖచ్చితమైన ఫలితాల కోసం చిట్కాలు'
                    : (isHindi ? 'सटीक परिणामों के लिए सुझाव' : 'Tips for accurate results'),
                style: GoogleFonts.googleSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF78350F),
                ),
              ),
              InkWell(
                onTap: _showTipsModal,
                child: Row(
                  children: [
                    Text(
                      isTelugu ? 'అన్నీ' : 'View all',
                      style: GoogleFonts.googleSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded, size: 15, color: Color(0xFF92400E)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildTipColumn(
                  icon: Icons.wb_sunny_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  label: isTelugu ? 'సహజ కాంతి' : 'Good natural light',
                ),
              ),
              Container(width: 1, height: 36, color: const Color(0xFFFDE68A)),
              Expanded(
                child: _buildTipColumn(
                  icon: Icons.crop_free_rounded,
                  iconColor: const Color(0xFF0284C7),
                  label: isTelugu ? 'దగ్గరి ఫోటో' : 'Close-up of affected area',
                ),
              ),
              Container(width: 1, height: 36, color: const Color(0xFFFDE68A)),
              Expanded(
                child: _buildTipColumn(
                  icon: Icons.front_hand_rounded,
                  iconColor: const Color(0xFF64748B),
                  label: isTelugu ? 'స్థిరంగా ఉంచండి' : 'Keep camera steady',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTipColumn({
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: GoogleFonts.googleSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF451A03),
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  void _showTipsModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Photography Tips for 95%+ Accuracy',
                style: GoogleFonts.googleSans(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              _buildTipRow(Icons.wb_sunny_rounded, 'diag_tip_light'.tr()),
              const SizedBox(height: 12),
              _buildTipRow(Icons.center_focus_strong_rounded, 'diag_tip_focus'.tr()),
              const SizedBox(height: 12),
              _buildTipRow(Icons.back_hand_rounded, 'diag_tip_steady'.tr()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF16A34A)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.googleSans(
              fontSize: 13.5,
              color: const Color(0xFF475569),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  void _showAll24CropsModal() {
    HapticFeedback.selectionClick();
    final langCode = context.locale.languageCode;
    final isTelugu = langCode == 'te';
    const crops = PlantDoctorScreen.supportedCrops;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '24 Supported Crops',
                        style: GoogleFonts.googleSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        isTelugu ? 'మీ పంటను ఎంచుకోండి' : 'Select your crop for accurate diagnosis',
                        style: GoogleFonts.googleSans(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Auto Detect Tile
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _activeCropId = null;
                    _activeCropName = null;
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _activeCropId == null ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _activeCropId == null ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF16A34A), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto-Detect Crop',
                              style: GoogleFonts.googleSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'AI automatically recognizes which crop is shown',
                              style: GoogleFonts.googleSans(
                                fontSize: 11.5,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_activeCropId == null)
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.88,
                  ),
                  itemCount: crops.length,
                  itemBuilder: (context, index) {
                    final crop = crops[index];
                    final cropId = crop['id'] as int;
                    final nameEn = crop['name_en'] as String;
                    final nameTe = crop['name_te'] as String;
                    final imageUrl = crop['image_url'] as String;
                    final emoji = crop['emoji'] as String;
                    final isSelected = _activeCropId == cropId;

                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(ctx);
                        setState(() {
                          _activeCropId = cropId;
                          _activeCropName = nameEn;
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 44,
                                height: 44,
                                color: const Color(0xFFF8FAFC),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Center(
                                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isTelugu && nameTe.isNotEmpty ? nameTe : nameEn,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.googleSans(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
                              ),
                            ),
                            if (isTelugu && nameEn.isNotEmpty)
                              Text(
                                nameEn,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.googleSans(
                                  fontSize: 10,
                                  color: const Color(0xFF64748B),
                                ),
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
        );
      },
    );
  }

  Widget _buildSpeechButton({
    required String sectionKey,
    required String text,
    Color? color,
    String? customLabel,
    bool iconOnly = false,
  }) {
    final langCode = context.locale.languageCode;
    final effectiveColor = color ?? AppTheme.primary;

    return ValueListenableBuilder<String?>(
      valueListenable: _ttsService.currentSpeakingKey,
      builder: (context, currentKey, _) {
        final isSpeaking = currentKey == sectionKey;
        final tooltip =
            isSpeaking ? 'diag_stop_audio'.tr() : 'diag_listen_advisory'.tr();
        final labelText = isSpeaking
            ? 'diag_stop_audio'.tr()
            : (customLabel ?? 'diag_listen_advisory'.tr());

        return Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: () {
              _ttsService.toggleSpeakSection(
                sectionKey: sectionKey,
                text: text,
                languageCode: langCode,
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: iconOnly ? 7 : 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: isSpeaking
                    ? effectiveColor.withValues(alpha: 0.18)
                    : effectiveColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSpeaking
                      ? effectiveColor
                      : effectiveColor.withValues(alpha: 0.25),
                  width: isSpeaking ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                    size: 15,
                    color: effectiveColor,
                  ),
                  if (!iconOnly) ...[
                    const SizedBox(width: 4),
                    Text(
                      labelText,
                      style: GoogleFonts.googleSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: effectiveColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // DYNAMIC LOCALIZATION HELPERS (Respects User Language Preference)
  // ===========================================================================

  String _getLocalizedCropName(String? rawCropName) {
    if (rawCropName == null || rawCropName.isEmpty) return 'Crop';
    final locale = context.locale.languageCode;
    try {
      final crop = PlantDoctorScreen.supportedCrops.firstWhere(
        (c) =>
            (c['name_en'] as String).toLowerCase() == rawCropName.toLowerCase() ||
            (c['name_te'] as String) == rawCropName ||
            rawCropName.toLowerCase().contains((c['name_en'] as String).toLowerCase()),
      );
      if (locale == 'te') return crop['name_te'] as String;
      if (locale == 'hi') return (crop['name_hi'] as String?) ?? (crop['name_en'] as String);
      return crop['name_en'] as String;
    } catch (_) {
      return rawCropName;
    }
  }

  String _getLocalizedSeverity(String? rawSeverity) {
    final locale = context.locale.languageCode;
    final sev = (rawSeverity ?? 'moderate').toLowerCase();
    if (locale == 'te') {
      if (sev.contains('severe') || sev.contains('high')) return 'తీవ్రమైనది';
      if (sev.contains('mild') || sev.contains('low') || sev.contains('early')) return 'తేలికపాటి';
      return 'మధ్యస్థం';
    } else if (locale == 'hi') {
      if (sev.contains('severe') || sev.contains('high')) return 'गंभीर';
      if (sev.contains('mild') || sev.contains('low') || sev.contains('early')) return 'हल्का';
      return 'मध्यम';
    } else {
      if (sev.contains('severe') || sev.contains('high')) return 'Severe';
      if (sev.contains('mild') || sev.contains('low') || sev.contains('early')) return 'Mild';
      return 'Moderate';
    }
  }

  String _getLocalizedStage(String? rawStage) {
    final locale = context.locale.languageCode;
    final stg = (rawStage ?? 'Early').toLowerCase();
    if (locale == 'te') {
      if (stg.contains('late') || stg.contains('mature')) return 'చివరి దశ';
      if (stg.contains('vegetative') || stg.contains('mid')) return 'మధ్య దశ';
      return 'ప్రారంభ దశ';
    } else if (locale == 'hi') {
      if (stg.contains('late') || stg.contains('mature')) return 'अंतिम चरण';
      if (stg.contains('vegetative') || stg.contains('mid')) return 'मध्य चरण';
      return 'प्रारंभिक चरण';
    } else {
      if (stg.contains('late') || stg.contains('mature')) return 'Late';
      if (stg.contains('vegetative') || stg.contains('mid')) return 'Mid';
      return 'Early';
    }
  }

  String _getLocalizedProblemName(
      String? rawName, Map<String, dynamic>? matchingProblemMap) {
    final locale = context.locale.languageCode;
    if (matchingProblemMap != null) {
      if (locale == 'te' &&
          matchingProblemMap['name_te'] != null &&
          (matchingProblemMap['name_te'] as String).isNotEmpty) {
        return matchingProblemMap['name_te'] as String;
      }
      if (locale == 'hi' &&
          matchingProblemMap['name_hi'] != null &&
          (matchingProblemMap['name_hi'] as String).isNotEmpty) {
        return matchingProblemMap['name_hi'] as String;
      }
    }
    return rawName ?? 'Unknown Issue';
  }

  void _openFullScreenImage({
    required ImageProvider imageProvider,
    required String title,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(
              title,
              style: GoogleFonts.googleSans(color: Colors.white, fontSize: 16),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.8,
              maxScale: 4.0,
              child: Image(image: imageProvider),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // DIAGNOSIS RESULT SECTION (Matches Reference Image 1)
  // ===========================================================================

  Widget _buildResultSection() {
    final result = _analysisResult!;
    final isPlant = result['is_plant'] as bool? ?? false;
    final isCropSupported = result['is_crop_supported'] as bool? ?? true;
    final isClearImage = result['is_clear_image'] as bool? ?? true;
    final locale = context.locale.languageCode;
    final isTe = locale == 'te';
    final isHi = locale == 'hi';

    // 1. Non-Plant State
    if (!isPlant) {
      final reason = result['reason']?.toString() ?? 'diag_not_plant'.tr();
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 28, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Text(
                  isTe
                      ? 'మొక్కను గుర్తించలేదు'
                      : (isHi ? 'पौधा नहीं पहचाना गया' : 'Plant Not Detected'),
                  style: GoogleFonts.googleSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF92400E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: GoogleFonts.googleSans(
                color: const Color(0xFF92400E),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _localPickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_rounded,
                  size: 16, color: Colors.white),
              label: Text(
                isTe
                    ? 'మళ్లీ స్కాన్ చేయండి'
                    : (isHi ? 'फिर से स्कैन करें' : 'Scan Again'),
                style: GoogleFonts.googleSans(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    // 2. Blurry / Low-Light Photo State
    if (!isClearImage) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.blur_on_rounded,
                    size: 28, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Text(
                  isTe
                      ? 'అస్పష్టమైన ఫోటో'
                      : (isHi ? 'धुंधली फोटो' : 'Low Clarity / Blurry Photo'),
                  style: GoogleFonts.googleSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: const Color(0xFF92400E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              result['reason']?.toString() ??
                  (isTe
                      ? 'ఫోటోలో స్పష్టత లేదా తగినంత కాంతి లేదు. దయచేసి సహజమైన పగటి వెలుతురులో ఆకు దగ్గరగా ఫోటో తీయండి.'
                      : (isHi
                          ? 'फोटो धुंधली या कम रोशनी वाली है। कृपया प्राकृतिक दिन के उजाले में प्रभावित पत्ती की स्पष्ट फोटो लें।'
                          : 'The photo lacks sharpness or lighting to identify foliar lesions accurately. Please capture a close-up photo of the affected leaf in bright natural daylight.')),
              textAlign: TextAlign.center,
              style: GoogleFonts.googleSans(
                color: const Color(0xFF92400E),
                height: 1.4,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _localPickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_rounded,
                  size: 16, color: Colors.white),
              label: Text(
                isTe
                    ? 'మళ్లీ ఫోటో తీయండి'
                    : (isHi ? 'फिर से फोटो लें' : 'Retake Photo'),
                style: GoogleFonts.googleSans(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    // 3. Unsupported Crop State
    if (!isCropSupported) {
      final detectedPlant = result['unsupported_crop_name']?.toString() ??
          result['detected_crop_name']?.toString() ??
          'This plant';
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.eco_rounded,
                      size: 20, color: Color(0xFFDC2626)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isTe
                        ? 'మద్దతు లేని పంట'
                        : (isHi ? 'असमर्थित फसल' : 'Crop Not Supported'),
                    style: GoogleFonts.googleSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Detected: $detectedPlant',
                style: GoogleFonts.googleSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: const Color(0xFF334155),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isTe
                  ? 'రసాయన విషప్రభావాన్ని నివారించడానికి మరియు 100% సురక్షితమైన CIBRC ఆమోదిత సిఫార్సులను అందించడానికి CropSync కేవలం 24 ప్రధాన పంటలకు మాత్రమే నిర్ధారణలను అందిస్తుంది.'
                  : (isHi
                      ? 'रासायनिक विषाक्तता को रोकने और 100% सुरक्षित CIBRC-अनुमोदित सिफारिशें सुनिश्चित करने के लिए क्रॉपसिंक केवल 24 मुख्य फसलों के लिए निदान सत्यापित करता है।'
                      : 'CropSync Plant Doctor verifies diagnoses strictly for our 24 staple crops to ensure 100% safe, CIBRC-approved agricultural recommendations and prevent chemical toxicity.'),
              style: GoogleFonts.googleSans(
                color: const Color(0xFF64748B),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isTe
                  ? 'మీ పంట మా 24 పంటల్లో ఒకటా? నిర్ధారించడానికి క్రింద నొక్కండి:'
                  : (isHi
                      ? 'क्या आपकी फसल हमारी 24 फसलों में से एक है? निदान के लिए नीचे टैप करें:'
                      : 'Is your crop one of our 24 supported crops? Tap below:'),
              style: GoogleFonts.googleSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            _buildSupportedCropsPickerGrid(),
          ],
        ),
      );
    }

    // 4. Valid Diagnosis State
    final matchedId = SafeParser.toNullableInt(result['matched_problem_id']);
    final rawProblemName =
        result['matched_problem_name']?.toString() ?? 'Unknown';
    final confidence =
        ((result['confidence'] as num? ?? 0.88) * 100).round();
    final rawAnalysis = result['ai_analysis']?.toString() ?? '';
    String analysis = rawAnalysis;
    if (analysis.trim().startsWith('{') ||
        analysis.contains('"is_plant"') ||
        analysis.contains('"detected_crop_name"')) {
      analysis =
          "${result['detected_crop_name'] ?? 'Crop'} exhibits symptoms of $rawProblemName. "
          "Follow the weather spray advisory and prescribed control measures below.";
    }
    final controls = result['ai_control_measures'] as Map<String, dynamic>?;
    final healthStatus =
        result['health_status']?.toString().toLowerCase() ?? 'healthy';
    final observedSymptoms = result['observed_symptoms'] is List
        ? List<String>.from(result['observed_symptoms'])
        : <String>[];
    final recoveryTips = result['recovery_recommendations'] is List
        ? List<String>.from(result['recovery_recommendations'])
        : <String>[];
    final detectedCropName = result['detected_crop_name']?.toString();

    Map<String, dynamic>? matchingProblemMap;
    if (matchedId != null && _problemsList != null) {
      try {
        matchingProblemMap =
            _problemsList!.firstWhere((p) => p['id'] == matchedId);
      } catch (_) {}
    }

    Map<String, dynamic>? matchingCropMap;
    if (detectedCropName != null && detectedCropName.isNotEmpty) {
      try {
        matchingCropMap = PlantDoctorScreen.supportedCrops.firstWhere(
          (c) =>
              (c['name_en'] as String).toLowerCase() ==
                  detectedCropName.toLowerCase() ||
              (c['name_te'] as String) == detectedCropName ||
              detectedCropName
                  .toLowerCase()
                  .contains((c['name_en'] as String).toLowerCase()),
        );
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Dual Photo Comparison Section (Matches Reference Image 1)
        _buildComparisonPhotosSection(
          matchingProblemMap: matchingProblemMap,
          matchingCropMap: matchingCropMap,
          healthStatus: healthStatus,
          isTe: isTe,
          isHi: isHi,
        ),
        const SizedBox(height: 16),

        // 2. Diagnosis Summary Card (Matches Reference Image 1)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildDiagnosisSummaryCard(
            result: result,
            matchingProblemMap: matchingProblemMap,
            matchingCropMap: matchingCropMap,
            rawProblemName: rawProblemName,
            confidence: confidence,
            analysis: analysis,
            healthStatus: healthStatus,
            detectedCropName: detectedCropName,
            isTe: isTe,
            isHi: isHi,
          ),
        ),
        const SizedBox(height: 20),

        // 3. Tab Bar (Treatment | About the Problem | Prevention)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildResultTabs(isTe: isTe, isHi: isHi),
        ),
        const SizedBox(height: 16),

        // 4. Tab Body Content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _selectedTabIndex == 0
              ? _buildTreatmentTabContent(
                  result: result,
                  controls: controls,
                  matchingProblemMap: matchingProblemMap,
                  matchedId: matchedId,
                  rawProblemName: rawProblemName,
                  healthStatus: healthStatus,
                  isTe: isTe,
                  isHi: isHi,
                )
              : _selectedTabIndex == 1
                  ? _buildAboutProblemTabContent(
                      observedSymptoms: observedSymptoms,
                      analysis: analysis,
                      result: result,
                      rawProblemName: rawProblemName,
                      isTe: isTe,
                      isHi: isHi,
                    )
                  : _buildPreventionTabContent(
                      controls: controls,
                      recoveryTips: recoveryTips,
                      isTe: isTe,
                      isHi: isHi,
                    ),
        ),
        const SizedBox(height: 36),
      ],
    );
  }

  // ===========================================================================
  // COMPARISON PHOTOS SECTION (Slide 0: User's Photo, Slide 1: Reference Photo)
  // ===========================================================================

  Widget _buildComparisonPhotosSection({
    required Map<String, dynamic>? matchingProblemMap,
    required Map<String, dynamic>? matchingCropMap,
    required String healthStatus,
    required bool isTe,
    required bool isHi,
  }) {
    final refImageUrl = matchingProblemMap?['image_url1'] as String? ??
        matchingProblemMap?['image_url2'] as String? ??
        matchingProblemMap?['image_url3'] as String? ??
        matchingCropMap?['image_url'] as String? ??
        'https://images.unsplash.com/photo-1592417817098-8f3d6eb22513?w=500';

    final isHealthy = healthStatus == 'healthy';
    final yourPhotoLabel =
        isTe ? 'మీ ఫోటో' : (isHi ? 'आपकी फोटो' : 'Your Photo');
    final refPhotoLabel = isHealthy
        ? (isTe
            ? 'ఆరోగ్యకరమైన ఆకు (ఆధారం)'
            : (isHi ? 'स्वस्थ पत्ती (संदर्भ)' : 'Healthy Leaf (Reference)'))
        : (isTe
            ? 'ఆధారిత ఫోటో'
            : (isHi ? 'संदर्भ फोटो' : 'Reference Photo'));

    // Build dynamic slides: Slide 0 is always user's photo, followed by authentic copyright-free reference photos
    final List<Widget> slides = [];

    // Slide 0: Your Photo
    slides.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: GestureDetector(
          onTap: () {
            if (_activeImagePath != null &&
                File(_activeImagePath!).existsSync()) {
              _openFullScreenImage(
                imageProvider: FileImage(File(_activeImagePath!)),
                title: yourPhotoLabel,
              );
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_activeImagePath != null &&
                    File(_activeImagePath!).existsSync())
                  Image.file(File(_activeImagePath!), fit: BoxFit.cover)
                else
                  Container(
                    color: const Color(0xFFF1F5F9),
                    child: const Center(
                      child: Icon(Icons.broken_image_rounded,
                          color: Color(0xFF94A3B8), size: 36),
                    ),
                  ),
                // Badge Pill Top Left
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          yourPhotoLabel,
                          style: GoogleFonts.googleSans(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Zoom icon hint
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.fullscreen_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Reference Slides: Authenticated Copyright-Free Photos
    if (_copyrightFreePhotos.isNotEmpty) {
      for (int i = 0; i < _copyrightFreePhotos.length; i++) {
        final photo = _copyrightFreePhotos[i];
        slides.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: GestureDetector(
              onTap: () {
                _openFullScreenImage(
                  imageProvider: CachedNetworkImageProvider(photo.url),
                  title: "${photo.title} (${photo.source})",
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: photo.url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF16A34A)),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: Icon(Icons.eco_rounded,
                              color: Color(0xFF16A34A), size: 36),
                        ),
                      ),
                    ),

                    // Badge Pill Top Left: License Provenance
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.68),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: photo.isHealthy
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              photo.isHealthy
                                  ? (isTe ? 'ఆధార ఫోటో' : (isHi ? 'संदर्भ फोटो' : 'Reference Photo'))
                                  : (isTe
                                      ? 'ఆధార ఫోటో (${i + 1})'
                                      : (isHi ? 'संदर्भ फोटो (${i + 1})' : 'Reference Photo ${i + 1}')),
                              style: GoogleFonts.googleSans(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Badge Top Right: Verified Copyright-Free
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF15803D).withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, size: 11, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Open License',
                              style: GoogleFonts.googleSans(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Attribution Banner
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.85),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              photo.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.googleSans(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.public_rounded, size: 11, color: Color(0xFFCBD5E1)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    "${photo.source} • ${photo.license}",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.googleSans(
                                      color: const Color(0xFFE2E8F0),
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.fullscreen_rounded,
                                    color: Colors.white, size: 14),
                              ],
                            ),
                          ],
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
    } else {
      // Fallback Reference Photo Slide
      slides.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: GestureDetector(
            onTap: () {
              _openFullScreenImage(
                imageProvider: CachedNetworkImageProvider(refImageUrl),
                title: refPhotoLabel,
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: refImageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: const Color(0xFFF1F5F9),
                      child: const Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF16A34A)),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFFF1F5F9),
                      child: const Center(
                        child: Icon(Icons.eco_rounded,
                            color: Color(0xFF16A34A), size: 36),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: isHealthy
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            refPhotoLabel,
                            style: GoogleFonts.googleSans(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.fullscreen_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView(
            controller: _imagePageController,
            onPageChanged: (idx) => setState(() => _currentImagePage = idx),
            physics: const BouncingScrollPhysics(),
            children: slides,
          ),
        ),
        const SizedBox(height: 10),

        // Dots Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(slides.length, (idx) {
            final isActive = _currentImagePage == idx;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),

        // Quick Switcher Chips Row
        if (slides.length > 1) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(slides.length, (idx) {
                final isSelected = _currentImagePage == idx;
                String label;
                if (idx == 0) {
                  label = yourPhotoLabel;
                } else if (_copyrightFreePhotos.isNotEmpty && idx - 1 < _copyrightFreePhotos.length) {
                  label = 'Ref $idx: ${_copyrightFreePhotos[idx - 1].source.split(' ').first}';
                } else {
                  label = isTe ? 'ఆధారం' : 'Reference';
                }

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _imagePageController.animateToPage(
                      idx,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFDCFCE7) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          idx == 0 ? Icons.camera_alt_rounded : Icons.eco_rounded,
                          size: 13,
                          color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          label,
                          style: GoogleFonts.googleSans(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // DIAGNOSIS SUMMARY CARD (Icon, Localized Title, Confidence, 3 Metric Chips)
  // ===========================================================================

  Widget _buildDiagnosisSummaryCard({
    required Map<String, dynamic> result,
    required Map<String, dynamic>? matchingProblemMap,
    required Map<String, dynamic>? matchingCropMap,
    required String rawProblemName,
    required int confidence,
    required String analysis,
    required String healthStatus,
    required String? detectedCropName,
    required bool isTe,
    required bool isHi,
  }) {
    final localizedProblemTitle =
        _getLocalizedProblemName(rawProblemName, matchingProblemMap);
    final localizedCrop = _getLocalizedCropName(detectedCropName);
    final localizedSeverity =
        _getLocalizedSeverity(result['severity_level']?.toString());
    final localizedStage =
        _getLocalizedStage(result['infection_stage']?.toString());

    Color statusColor;
    IconData statusIcon;

    switch (healthStatus) {
      case 'healthy':
        statusColor = const Color(0xFF16A34A);
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'diseased':
        statusColor = const Color(0xFFDC2626);
        statusIcon = Icons.coronavirus_rounded;
        break;
      case 'deficiency':
        statusColor = const Color(0xFFD97706);
        statusIcon = Icons.science_rounded;
        break;
      case 'physical_damage':
        statusColor = const Color(0xFFEA580C);
        statusIcon = Icons.handyman_rounded;
        break;
      case 'pest_infestation':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.pest_control_rounded;
        break;
      default:
        statusColor = const Color(0xFF16A34A);
        statusIcon = Icons.check_circle_rounded;
    }

    final cropChipLabel = isTe ? 'పంట' : (isHi ? 'फसल' : 'Crop');
    final severityChipLabel = isTe ? 'తీవ్రత' : (isHi ? 'तीव्रता' : 'Severity');
    final stageChipLabel = isTe ? 'దశ' : (isHi ? 'चरण' : 'Stage');
    final aiConfidenceLabel = isTe
        ? '$confidence% AI ఖచ్చితత్వం'
        : (isHi ? '$confidence% AI सटीकता' : '$confidence% AI Confidence');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Icon, Title, and Confidence Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(statusIcon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizedProblemTitle,
                      style: GoogleFonts.googleSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (isTe &&
                        rawProblemName.isNotEmpty &&
                        rawProblemName != localizedProblemTitle)
                      Text(
                        rawProblemName,
                        style: GoogleFonts.googleSans(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded,
                        size: 13, color: Color(0xFF16A34A)),
                    const SizedBox(width: 4),
                    Text(
                      aiConfidenceLabel,
                      style: GoogleFonts.googleSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Clinical Summary Text
          Text(
            analysis,
            style: GoogleFonts.googleSans(
              fontSize: 13.5,
              color: const Color(0xFF475569),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),

          // Divider
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // 3 Metric Chips (Crop, Severity, Stage)
          Row(
            children: [
              // Chip 1: Crop (Tap to change crop)
              Expanded(
                child: InkWell(
                  onTap: _showChangeCropModal,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.eco_rounded,
                            size: 15, color: Color(0xFF16A34A)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    cropChipLabel,
                                    style: GoogleFonts.googleSans(
                                      fontSize: 10,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.keyboard_arrow_down_rounded,
                                      size: 12, color: Color(0xFF94A3B8)),
                                ],
                              ),
                              Text(
                                localizedCrop,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.googleSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Chip 2: Severity
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.speed_rounded,
                          size: 15, color: statusColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              severityChipLabel,
                              style: GoogleFonts.googleSans(
                                fontSize: 10,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              localizedSeverity,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.googleSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Chip 3: Stage
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 15, color: Color(0xFF0284C7)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stageChipLabel,
                              style: GoogleFonts.googleSans(
                                fontSize: 10,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              localizedStage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.googleSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // RESULT TABS SECTION (Treatment | About the Problem | Prevention)
  // ===========================================================================

  Widget _buildResultTabs({required bool isTe, required bool isHi}) {
    final tabs = [
      isTe ? 'చికిత్స' : (isHi ? 'उपचार' : 'Treatment'),
      isTe ? 'సమస్య గురించి' : (isHi ? 'समस्या विवरण' : 'About the Problem'),
      isTe ? 'నివారణ' : (isHi ? 'रोकथाम' : 'Prevention'),
    ];

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
      ),
      child: Row(
        children: List.generate(tabs.length, (idx) {
          final isSelected = _selectedTabIndex == idx;
          return Expanded(
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTabIndex = idx);
              },
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      tabs[idx],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.googleSans(
                        fontSize: 13.5,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF16A34A)
                          : Colors.transparent,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ===========================================================================
  // TAB 0: TREATMENT CONTENT (Cards with Dosage & Water Volume Badges)
  // ===========================================================================

  Widget _buildTreatmentTabContent({
    required Map<String, dynamic> result,
    required Map<String, dynamic>? controls,
    required Map<String, dynamic>? matchingProblemMap,
    required int? matchedId,
    required String rawProblemName,
    required String healthStatus,
    required bool isTe,
    required bool isHi,
  }) {
    final recommendedHeader = isTe
        ? 'సిఫార్సు చేసిన చికిత్సలు'
        : (isHi ? 'अनुशंसित उपचार' : 'Recommended Treatments');
    final listenAllLabel =
        isTe ? 'అన్నీ వినండి' : (isHi ? 'सब सुनें' : 'Listen to all');

    final chemicalList = controls?['chemical'] is List
        ? List<String>.from(controls!['chemical'])
        : <String>[];
    final biologicalList = controls?['biological'] is List
        ? List<String>.from(controls!['biological'])
        : <String>[];

    // Build all speech text
    final allSpeechText = [
      recommendedHeader,
      if (chemicalList.isNotEmpty) 'Chemical: ${chemicalList.join(". ")}',
      if (biologicalList.isNotEmpty) 'Biological: ${biologicalList.join(". ")}',
      if (result['weather_impact'] != null)
        'Weather advisory: ${result['weather_impact']}',
    ].join('. ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with "Recommended Treatments" & "Listen to all"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              recommendedHeader,
              style: GoogleFonts.googleSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            _buildSpeechButton(
              sectionKey: 'all_treatments',
              text: allSpeechText,
              color: const Color(0xFF16A34A),
              customLabel: listenAllLabel,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Chemical Treatments
        if (chemicalList.isNotEmpty)
          ...chemicalList.map((item) => _buildTreatmentCardDetailed(
                item: item,
                isChemical: true,
                isTe: isTe,
                isHi: isHi,
              )),

        // Biological Treatments
        if (biologicalList.isNotEmpty)
          ...biologicalList.map((item) => _buildTreatmentCardDetailed(
                item: item,
                isChemical: false,
                isTe: isTe,
                isHi: isHi,
              )),

        if (chemicalList.isEmpty && biologicalList.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF16A34A), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isTe
                        ? 'ఈ మొక్క ఆరోగ్యంగా ఉంది. ప్రత్యేక చికిత్స అవసరం లేదు.'
                        : (isHi
                            ? 'यह पौधा स्वस्थ है। किसी विशेष उपचार की आवश्यकता नहीं है।'
                            : 'This plant is healthy. No chemical or biological treatment required.'),
                    style: GoogleFonts.googleSans(
                      fontSize: 13,
                      color: const Color(0xFF166534),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 14),

        // Weather & Spray Advisory Card (Sky Blue)
        _buildWeatherSprayAdvisoryCard(
          weatherImpact: result['weather_impact']?.toString(),
          isTe: isTe,
          isHi: isHi,
        ),

        // Verified Advisory Navigation Button
        if (matchedId != null && _hasVerifiedAdvisory) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdvisoryDetailScreen(
                      problem: CropProblem(
                        id: matchedId,
                        name: rawProblemName,
                        category: matchingProblemMap?['category'] as String?,
                        imageUrl1: matchingProblemMap?['image_url1'] as String?,
                        imageUrl2: matchingProblemMap?['image_url2'] as String?,
                        imageUrl3: matchingProblemMap?['image_url3'] as String?,
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.verified_rounded,
                  color: Colors.white, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              label: Text(
                isTe
                    ? 'ధృవీకరించబడిన సలహాను చూడండి'
                    : (isHi
                        ? 'सत्यापित सलाह देखें'
                        : 'View Verified Advisory'),
                style: GoogleFonts.googleSans(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTreatmentCardDetailed({
    required String item,
    required bool isChemical,
    required bool isTe,
    required bool isHi,
  }) {
    final tagLabel = isChemical
        ? (isTe ? 'రసాయన మందు' : (isHi ? 'रासायनिक' : 'CHEMICAL'))
        : (isTe ? 'జీవ నియంత్రణ' : (isHi ? 'जैविक' : 'BIOLOGICAL'));

    final tagBg =
        isChemical ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4);
    final tagBorder =
        isChemical ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0);
    final tagColor =
        isChemical ? const Color(0xFFDC2626) : const Color(0xFF16A34A);

    // Parse chemical name, dosage, water volume
    String name = item;
    String dosage = '2 ml/L of water';
    String? waterVolume;
    String note = isChemical
        ? (isTe
            ? 'ఉదయం లేదా సాయంత్రం వేళల్లో పిచికారీ చేయండి. ఆకుల రెండు వైపులా సమానంగా తడిసేలా చూడండి.'
            : (isHi
                ? 'सुबह या शाम के समय छिड़काव करें। पत्तियों के दोनों किनारों को समान रूप से गीला करें।'
                : 'Spray in early morning or late evening. Ensure complete coverage on both leaf surfaces.'))
        : (isTe
            ? 'విత్తన శుద్ధి లేదా నేల ద్వారా తడిసేలా వేయడం మంచిది.'
            : (isHi
                ? 'बीज उपचार या मिट्टी में प्रयोग के लिए अत्यधिक प्रभावी।'
                : 'Highly effective for seed dressing or soil application.'));

    final atIndex = item.indexOf('@');
    if (atIndex != -1) {
      name = item.substring(0, atIndex).trim();
      final dosagePart = item.substring(atIndex + 1).trim();
      dosage = dosagePart;

      final waterMatch = RegExp(
        r'(?:in|with)\s+(\d+[-–]?\d*\s*(?:L|liters|litres|l)\s*(?:of\s*)?water)',
        caseSensitive: false,
      ).firstMatch(dosagePart);

      if (waterMatch != null) {
        waterVolume = waterMatch.group(1);
        dosage = dosage
            .replaceAll(waterMatch.group(0)!, '')
            .replaceAll(RegExp(r'\s*\(\s*\)\s*'), '')
            .trim();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Tag Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tagBorder),
                ),
                child: Text(
                  tagLabel,
                  style: GoogleFonts.googleSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: tagColor,
                  ),
                ),
              ),
              _buildSpeechButton(
                sectionKey: 'item_${name.hashCode}',
                text: '$name. Dosage: $dosage. $note',
                color: tagColor,
                iconOnly: true,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Remedy Name
          Text(
            name,
            style: GoogleFonts.googleSans(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),

          // Badges Row (Dosage + Water Volume)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              // Dosage Bag Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shopping_bag_outlined,
                        size: 13, color: Color(0xFF475569)),
                    const SizedBox(width: 5),
                    Text(
                      dosage,
                      style: GoogleFonts.googleSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),

              // Water Volume Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.water_drop_rounded,
                        size: 13, color: Color(0xFF0284C7)),
                    const SizedBox(width: 5),
                    Text(
                      waterVolume ??
                          (isChemical ? '200 L/acre' : '15 L/sprayer'),
                      style: GoogleFonts.googleSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0369A1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Application Guidance
          Text(
            note,
            style: GoogleFonts.googleSans(
              fontSize: 12.5,
              color: const Color(0xFF64748B),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // WEATHER & SPRAY ADVISORY CARD (Sky Blue Box)
  // ===========================================================================

  Widget _buildWeatherSprayAdvisoryCard({
    required String? weatherImpact,
    required bool isTe,
    required bool isHi,
  }) {
    final title = isTe
        ? 'వాతావరణం & పిచికారీ సలహా'
        : (isHi ? 'मौसम व छिड़काव सलाह' : 'Weather & Spray Advisory');

    final text = (weatherImpact != null && weatherImpact.trim().isNotEmpty)
        ? weatherImpact
        : (isTe
            ? 'ప్రస్తుతం గాలి వేగం సాధారణంగా ఉంది. పిచికారీకి అనుకూలం. రాబోయే 4 గంటల్లో వర్షం లేకపోతే పిచికారీ కొనసాగించవచ్చు.'
            : (isHi
                ? 'वर्तमान हवा की गति सामान्य है। छिड़काव के लिए उपयुक्त। यदि 4 घंटे में बारिश की संभावना न हो तो छिड़काव करें।'
                : 'Current wind conditions are suitable for foliar spraying. Avoid spraying if rain is forecasted within 4 hours.'));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_sync_rounded,
                  color: Color(0xFF0284C7), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.googleSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                    color: const Color(0xFF0369A1),
                  ),
                ),
              ),
              _buildSpeechButton(
                sectionKey: 'weather_advice',
                text: "$title. $text",
                color: const Color(0xFF0284C7),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: GoogleFonts.googleSans(
              fontSize: 13,
              color: const Color(0xFF0C4A6E),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: ABOUT THE PROBLEM (Symptoms & Favorable Conditions)
  // ===========================================================================

  Widget _buildAboutProblemTabContent({
    required List<String> observedSymptoms,
    required String analysis,
    required Map<String, dynamic> result,
    required String rawProblemName,
    required bool isTe,
    required bool isHi,
  }) {
    final symptomsTitle = isTe
        ? 'గుర్తించిన లక్షణాలు'
        : (isHi ? 'पहचाने गए लक्षण' : 'Observed Symptoms');
    final conditionsTitle = isTe
        ? 'అనుకూల పరిస్థితులు & కారణాలు'
        : (isHi ? 'अनुकूल परिस्थितियां व कारण' : 'Favorable Conditions & Causes');

    final favorableConditions = result['favorable_conditions']?.toString() ??
        (isTe
            ? 'అధిక తేమ (>80%), ఉష్ణోగ్రత 25-32°C మధ్య ఉన్నప్పుడు ఈ తెగులు వేగంగా వ్యాపిస్తుంది. పొలంలో నీరు నిలవడం మరియు గాలి ప్రసరణ లోపించడం దీనికి కారణం.'
            : (isHi
                ? 'उच्च आर्द्रता (>80%) और 25-32°C तापमान इस रोग के प्रसार को बढ़ाते हैं। खेत में जलभराव व हवा का अभाव मुख्य कारण हैं।'
                : 'High relative humidity (>80%) and temperatures between 25-32°C favor rapid symptom progression. Water stagnation and inadequate air circulation accelerate disease spread.'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Symptoms Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.search_rounded,
                          size: 18, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Text(
                        symptomsTitle,
                        style: GoogleFonts.googleSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  _buildSpeechButton(
                    sectionKey: 'symptoms',
                    text:
                        "$symptomsTitle. ${observedSymptoms.join('. ')}. $analysis",
                    color: const Color(0xFF16A34A),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (observedSymptoms.isNotEmpty)
                ...observedSymptoms.map(
                  (symptom) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3.0),
                          child: Icon(Icons.check_circle_rounded,
                              size: 15, color: Color(0xFF16A34A)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            symptom,
                            style: GoogleFonts.googleSans(
                              fontSize: 13,
                              color: const Color(0xFF334155),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Text(
                  analysis,
                  style: GoogleFonts.googleSans(
                    fontSize: 13,
                    color: const Color(0xFF334155),
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Favorable Conditions Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.thermostat_rounded,
                          size: 18, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Text(
                        conditionsTitle,
                        style: GoogleFonts.googleSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  _buildSpeechButton(
                    sectionKey: 'conditions',
                    text: "$conditionsTitle. $favorableConditions",
                    color: const Color(0xFFD97706),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                favorableConditions,
                style: GoogleFonts.googleSans(
                  fontSize: 13,
                  color: const Color(0xFF334155),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 2: PREVENTION (Practices & Recovery Recommendations)
  // ===========================================================================

  Widget _buildPreventionTabContent({
    required Map<String, dynamic>? controls,
    required List<String> recoveryTips,
    required bool isTe,
    required bool isHi,
  }) {
    final preventativeTitle = isTe
        ? 'ముందస్తు సాగు పద్ధతులు'
        : (isHi ? 'निवारक कृषि पद्धतियां' : 'Preventative Cultural Practices');
    final recoveryTitle = isTe
        ? 'కోలుకునేందుకు సూచనలు'
        : (isHi ? 'पुनर्प्राप्ति युक्तियां' : 'Recovery Recommendations');

    final preventativeList = controls?['preventative'] is List
        ? List<String>.from(controls!['preventative'])
        : <String>[];

    final defaultPreventative = [
      isTe
          ? 'పంట మార్పిడిని పాటించండి మరియు సిఫార్సు చేసిన మోతాదులోనే ఎరువులను వాడండి.'
          : (isHi
              ? 'फसल चक्र अपनाएं और संतुलित उर्वरकों का उपयोग करें।'
              : 'Practice regular crop rotation and maintain balanced NPK fertilization.'),
      isTe
          ? 'నాణ్యమైన మరియు ధృవీకరించబడిన విత్తనాలను మాత్రమే విత్తుకోవడానికి ఉపయోగించండి.'
          : (isHi
              ? 'केवल प्रमाणित एवं उपचारित बीजों का उपयोग करें।'
              : 'Use only certified, disease-free treated seeds.'),
      isTe
          ? 'పొలంలో నీరు నిల్వ ఉండకుండా మురుగు నీటి కాలువలను సరిగ్గా నిర్వహించండి.'
          : (isHi
              ? 'खेत में उचित जल निकासी सुनिश्चित करें।'
              : 'Ensure proper field drainage to avoid root rot and damp conditions.'),
    ];

    final effectivePreventative =
        preventativeList.isNotEmpty ? preventativeList : defaultPreventative;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preventative Cultural Practices Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_rounded,
                          size: 18, color: Color(0xFF0D9488)),
                      const SizedBox(width: 8),
                      Text(
                        preventativeTitle,
                        style: GoogleFonts.googleSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  _buildSpeechButton(
                    sectionKey: 'preventative',
                    text:
                        "$preventativeTitle. ${effectivePreventative.join('. ')}",
                    color: const Color(0xFF0D9488),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...effectivePreventative.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3.0),
                        child: Icon(Icons.check_circle_outline_rounded,
                            size: 15, color: Color(0xFF0D9488)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: GoogleFonts.googleSans(
                            fontSize: 13,
                            color: const Color(0xFF334155),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Recovery Recommendations Card
        if (recoveryTips.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tips_and_updates_rounded,
                            size: 18, color: Color(0xFF0284C7)),
                        const SizedBox(width: 8),
                        Text(
                          recoveryTitle,
                          style: GoogleFonts.googleSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    _buildSpeechButton(
                      sectionKey: 'recovery',
                      text: "$recoveryTitle. ${recoveryTips.join('. ')}",
                      color: const Color(0xFF0284C7),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...recoveryTips.map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3.0),
                          child: Icon(Icons.arrow_right_rounded,
                              size: 18, color: Color(0xFF0284C7)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tip,
                            style: GoogleFonts.googleSans(
                              fontSize: 13,
                              color: const Color(0xFF334155),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ===========================================================================
  // STICKY BOTTOM ACTION BAR (Save Result & New Diagnosis)
  // ===========================================================================

  Widget _buildStickyBottomActionBar() {
    final locale = context.locale.languageCode;
    final isTe = locale == 'te';
    final isHi = locale == 'hi';

    final saveLabel = _isSaved
        ? (isTe ? 'సేవ్ చేయబడింది' : (isHi ? 'सहेजा गया' : 'Saved'))
        : (isTe ? 'సేవ్ చేయండి' : (isHi ? 'सहेजें' : 'Save Result'));
    final newDiagnosisLabel =
        isTe ? 'కొత్త నిర్ధారణ' : (isHi ? 'नया निदान' : 'New Diagnosis');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // 1. Save Result Button (Outlined)
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _toggleSaveAdvisory,
                    icon: Icon(
                      _isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 18,
                      color: _isSaved
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF334155),
                    ),
                    label: Text(
                      saveLabel,
                      style: GoogleFonts.googleSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _isSaved
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF334155),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _isSaved
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFCBD5E1),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 2. New Diagnosis Button (Filled Primary Green)
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      setState(() {
                        _activeImagePath = null;
                        _analysisResult = null;
                        _errorMsg = null;
                        _isSaved = false;
                        _selectedTabIndex = 0;
                        _currentImagePage = 0;
                      });
                    },
                    icon: const Icon(Icons.camera_alt_rounded,
                        size: 18, color: Colors.white),
                    label: Text(
                      newDiagnosisLabel,
                      style: GoogleFonts.googleSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportedCropsPickerGrid() {
    const crops = PlantDoctorScreen.supportedCrops;
    final locale = context.locale.languageCode;
    final isTelugu = locale == 'te';

    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: crops.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final crop = crops[index];
          final cropId = crop['id'] as int;
          final nameEn = crop['name_en'] as String;
          final nameTe = crop['name_te'] as String;
          final imageUrl = crop['image_url'] as String;
          final emoji = crop['emoji'] as String;
          final color = crop['color'] as Color;

          return InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _activeCropId = cropId;
                _activeCropName = nameEn;
              });
              _analyzeImage();
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 96,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.network(
                      imageUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isTelugu ? nameTe : nameEn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    isTelugu ? nameEn : nameTe,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
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

  void _showChangeCropModal() {
    HapticFeedback.selectionClick();
    final locale = context.locale.languageCode;
    final isTelugu = locale == 'te';
    const crops = PlantDoctorScreen.supportedCrops;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Crop for Diagnosis',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'సరైన పంటను ఎంచుకోండి (24 Crops Supported)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Auto-detect option
                  InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _activeCropId = null;
                        _activeCropName = null;
                      });
                      _analyzeImage();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _activeCropId == null
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _activeCropId == null
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFE2E8F0),
                          width: _activeCropId == null ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.auto_awesome_rounded,
                                size: 20, color: Color(0xFF16A34A)),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Auto-Detect Crop (స్వయంచాలక గుర్తింపు)',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'AI automatically identifies which of the 24 crops is present',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_activeCropId == null)
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF16A34A), size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'All 24 Supported Crops',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.88,
                      ),
                      itemCount: crops.length,
                      itemBuilder: (context, index) {
                        final crop = crops[index];
                        final cropId = crop['id'] as int;
                        final nameEn = crop['name_en'] as String;
                        final nameTe = crop['name_te'] as String;
                        final imageUrl = crop['image_url'] as String;
                        final emoji = crop['emoji'] as String;
                        final color = crop['color'] as Color;
                        final isSelected = _activeCropId == cropId;

                        return InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(ctx);
                            setState(() {
                              _activeCropId = cropId;
                              _activeCropName = nameEn;
                            });
                            _analyzeImage();
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withValues(alpha: 0.08)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? color : const Color(0xFFE2E8F0),
                                width: isSelected ? 2.0 : 1.0,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: Image.network(
                                        imageUrl,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 48,
                                          height: 48,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(emoji,
                                              style: const TextStyle(fontSize: 24)),
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        right: -4,
                                        bottom: -4,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.check,
                                              size: 12, color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isTelugu ? nameTe : nameEn,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight:
                                        isSelected ? FontWeight.w800 : FontWeight.w700,
                                    color: isSelected ? color : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  isTelugu ? nameEn : nameTe,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500,
                                  ),
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
            );
          },
        );
      },
    );
  }

  Widget _buildCreditQuotaWidget() {
    final status = _creditStatus;
    final remaining = status?.totalAvailable ?? 10;
    final hasCredits = remaining > 0;
    final isUsingPurchased = status?.isUsingPurchasedCredits ?? false;

    return InkWell(
      onTap: () => _showPurchaseCreditsModal(),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: hasCredits ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasCredits ? const Color(0xFFBBF7D0) : const Color(0xFFFCA5A5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasCredits ? Icons.eco_rounded : Icons.bolt_rounded,
              size: 16,
              color: hasCredits ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            ),
            const SizedBox(width: 8),
            Text(
              hasCredits
                  ? (isUsingPurchased
                      ? "$remaining scans available (${status!.purchasedCredits} purchased)"
                      : "${status?.dailyRemaining ?? 10}/10 free scans today")
                  : "Daily limit reached (0/10) • Add 10 scans for ₹1",
              style: TextStyle(
                fontSize: 12.5,
                color: hasCredits ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 11,
              color: hasCredits ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            ),
          ],
        ),
      ),
    );
  }



  void _showPurchaseCreditsModal({VoidCallback? onSuccess}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.stars_rounded,
                      size: 36,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "AI Crop Doctor Credits",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _creditStatus != null && _creditStatus!.dailyRemaining == 0
                        ? "You've completed your 10 free daily scans. Top up 10 extra scans to continue instant diagnosis."
                        : "Add 10 extra scans to your CropSync account. Credits never expire!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.bolt_rounded, color: Color(0xFF2E7D32), size: 22),
                                SizedBox(width: 6),
                                Text(
                                  "10 Scans Pack",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                "₹1 ONLY",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureItem(Icons.check_circle_rounded, "10 High-Precision Plant Doctor Diagnoses"),
                        const SizedBox(height: 6),
                        _buildFeatureItem(Icons.check_circle_rounded, "Real-time & 7-Day Weather Risk Analytics"),
                        const SizedBox(height: 6),
                        _buildFeatureItem(Icons.check_circle_rounded, "CIBRC Chemical & Biological IPM Prescriptions"),
                        const SizedBox(height: 6),
                        _buildFeatureItem(Icons.check_circle_rounded, "Never expires • Rolls over automatically"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isPaymentProcessing
                          ? null
                          : () {
                              _triggerRazorpayPurchase(
                                onSuccess: onSuccess,
                                setModalState: setModalState,
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isPaymentProcessing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.payment_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  "Pay ₹1 via Razorpay",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        "100% Secure via Razorpay (UPI, GPay, PhonePe, Cards)",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _triggerRazorpayPurchase({
    VoidCallback? onSuccess,
    void Function(void Function())? setModalState,
  }) async {
    final phone = await RazorpayPaymentService.resolveUserPhoneNumber();
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ??
        prefs.getString('userId') ??
        (phone.isNotEmpty ? phone : 'guest_farmer');
    final email = prefs.getString('email') ?? '';

    setState(() => _isPaymentProcessing = true);
    setModalState?.call(() => _isPaymentProcessing = true);

    await _razorpayService.purchaseCredits(
      amountInr: AiCreditService.costPerPurchaseInr,
      userId: userId,
      userPhone: phone,
      userEmail: email,
      description: "10 AI Crop Doctor Scans",
      onResult: (result) async {
        if (!mounted) return;
        setState(() => _isPaymentProcessing = false);
        setModalState?.call(() => _isPaymentProcessing = false);

        if (result.isSuccess) {
          if (result.totalPurchased != null) {
            await AiCreditService.syncPurchasedCredits(
              result.totalPurchased!,
              userId: userId,
              paymentId: result.paymentId,
            );
          } else {
            await AiCreditService.addPurchasedCredits(
              result.creditsAdded ?? AiCreditService.creditsPerPurchase,
              userId: userId,
              paymentId: result.paymentId,
            );
          }
          await _loadCreditStatus();

          if (mounted) {
            Navigator.of(context, rootNavigator: true).maybePop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("🎉 10 Crop Doctor credits verified & added successfully!"),
                backgroundColor: Color(0xFF2E7D32),
                behavior: SnackBarBehavior.floating,
              ),
            );
            onSuccess?.call();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.errorMessage ?? "Payment cancelled or failed."),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
    );
  }

  static Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF16A34A)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class LaserScannerOverlay extends StatefulWidget {
  const LaserScannerOverlay({super.key});

  @override
  State<LaserScannerOverlay> createState() => _LaserScannerOverlayState();
}

class _LaserScannerOverlayState extends State<LaserScannerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: Colors.green.withValues(alpha: 0.08),
              ),
            ),
            Align(
              alignment: Alignment(0, (_animation.value * 2.0) - 1.0),
              child: Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.8),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                  gradient: const LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color(0xFF34D399),
                      Color(0xFF059669),
                      Color(0xFF34D399),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ViewfinderCornerBrackets extends StatelessWidget {
  const ViewfinderCornerBrackets({super.key});

  @override
  Widget build(BuildContext context) {
    const double size = 22;
    const double thickness = 2.5;
    const Color color = Color(0xFF10B981);

    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            // Top-Left
            Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: color, width: thickness),
                    left: BorderSide(color: color, width: thickness),
                  ),
                ),
              ),
            ),
            // Top-Right
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: color, width: thickness),
                    right: BorderSide(color: color, width: thickness),
                  ),
                ),
              ),
            ),
            // Bottom-Left
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: color, width: thickness),
                    left: BorderSide(color: color, width: thickness),
                  ),
                ),
              ),
            ),
            // Bottom-Right
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: color, width: thickness),
                    right: BorderSide(color: color, width: thickness),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
