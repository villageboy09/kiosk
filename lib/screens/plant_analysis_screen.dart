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
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlantAnalysisScreen extends StatefulWidget {
  final String? imagePath;
  final ImageSource? initialSource;
  final Map<String, dynamic>? preloadedResult;

  const PlantAnalysisScreen({
    super.key,
    this.imagePath,
    this.initialSource,
    this.preloadedResult,
  });

  @override
  State<PlantAnalysisScreen> createState() => _PlantAnalysisScreenState();
}

class _PlantAnalysisScreenState extends State<PlantAnalysisScreen> {
  // AI Diagnosis State
  bool _isLoading = false;
  String? _errorMsg;
  Map<String, dynamic>? _analysisResult;
  List<Map<String, dynamic>>? _problemsList;
  bool _hasVerifiedAdvisory = false;
  String? _activeImagePath;
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

  @override
  void initState() {
    super.initState();
    _activeImagePath = widget.imagePath;
    _analysisResult = widget.preloadedResult;
    _razorpayService = RazorpayPaymentService();
    _ttsService = TextToSpeechService();
    _loadCreditStatus();

    if (_analysisResult != null) {
      _checkIfSaved();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialSource != null &&
          widget.preloadedResult == null &&
          widget.imagePath == null) {
        _localPickImage(widget.initialSource!);
      }
    });
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _razorpayService.dispose();
    _ttsService.stop();
    super.dispose();
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

      // Call DeepSeek Plant Doctor with prompt caching and weather tool execution
      final parsed = await DeepSeekPlantDoctorService.diagnoseCrop(
        imageFile: file,
        latitude: position?.latitude,
        longitude: position?.longitude,
        language: locale,
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
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 75,
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
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _ttsService.stop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text('plant_doctor_title'.tr(), style: AppTheme.appBarTitle),
          backgroundColor: Colors.white,
          leading: AppTheme.backButton(context, color: AppTheme.appBarText),
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          actions: [
            if (_analysisResult != null &&
                (_analysisResult!['is_plant'] as bool? ?? false)) ...[
              IconButton(
                icon: Icon(
                  _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: _isSaved ? const Color(0xFF16A34A) : AppTheme.textPrimary,
                  size: 22,
                ),
                tooltip: _isSaved ? 'diag_saved'.tr() : 'diag_save'.tr(),
                onPressed: _toggleSaveAdvisory,
              ),
              IconButton(
                icon: const Icon(
                  Icons.share_rounded,
                  color: AppTheme.textPrimary,
                  size: 20,
                ),
                tooltip: 'diag_share'.tr(),
                onPressed: _shareAdvisory,
              ),
            ],
            _buildCreditBadge(),
          ],
        ),
        body: _buildDiagnosisBody(),
      ),
    );
  }

  Widget _buildDiagnosisBody() {
    // If no active photo and no preloaded result, show clean landing screen
    if (_activeImagePath == null && _analysisResult == null) {
      return _buildLandingState();
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Crop Image Card
          if (_activeImagePath != null && File(_activeImagePath!).existsSync())
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(_activeImagePath!),
                        fit: BoxFit.cover,
                      ),
                      if (_isLoading) const LaserScannerOverlay(),
                    ],
                  ),
                ),
              ),
            ),

          // Analyze Button if image is loaded but not yet analyzed and not loading
          if (!_isLoading && _analysisResult == null && _errorMsg == null)
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

          // Loading Progress Card
          if (_isLoading)
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: 140,
                    child: LinearProgressIndicator(
                      backgroundColor: const Color(0xFFDCFCE7),
                      color: const Color(0xFF16A34A),
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _loadingTexts[_loadingTextIndex],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      fontSize: 14.5,
                      height: 1.4,
                    ),
                  ),
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

  Widget _buildLandingState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  size: 46,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'diag_sheet_title'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 21,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'diag_sheet_subtitle'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),

              // Action 1: Camera
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => _localPickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                  label: Text(
                    'diag_sheet_camera'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Action 2: Gallery
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => _localPickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, color: Color(0xFF16A34A), size: 20),
                  label: Text(
                    'diag_sheet_gallery'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Action 3: Saved Diagnoses
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SavedAdvisoriesScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.bookmark_outline_rounded, color: Color(0xFF64748B), size: 19),
                  label: Text(
                    'diag_sheet_saved'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Tips Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline_rounded, size: 15, color: Color(0xFFD97706)),
                        const SizedBox(width: 6),
                        Text(
                          'diag_tips_title'.tr(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildLandingTip(Icons.wb_sunny_outlined, 'diag_tip_light'.tr()),
                    const SizedBox(height: 6),
                    _buildLandingTip(Icons.center_focus_strong_outlined, 'diag_tip_focus'.tr()),
                    const SizedBox(height: 6),
                    _buildLandingTip(Icons.vibration_rounded, 'diag_tip_steady'.tr()),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              _buildCreditQuotaWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLandingTip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Reusable Speech Button for Diagnosis Sections
  Widget _buildSpeechButton({
    required String sectionKey,
    required String text,
    Color? color,
  }) {
    final langCode = context.locale.languageCode;
    final effectiveColor = color ?? AppTheme.primary;

    return ValueListenableBuilder<String?>(
      valueListenable: _ttsService.currentSpeakingKey,
      builder: (context, currentKey, _) {
        final isSpeaking = currentKey == sectionKey;
        return Tooltip(
          message: isSpeaking ? 'diag_stop_audio'.tr() : 'diag_listen_advisory'.tr(),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                  const SizedBox(width: 4),
                  Text(
                    isSpeaking ? 'diag_stop_audio'.tr() : 'diag_listen_advisory'.tr(),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: effectiveColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultSection() {
    final result = _analysisResult!;
    final isPlant = result['is_plant'] as bool? ?? false;

    if (!isPlant) {
      final reason =
          result['reason']?.toString() ?? 'diag_not_plant'.tr();
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
                  'diag_not_plant'.tr(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF92400E)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF92400E), height: 1.4),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _localPickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
              label: Text(
                'diag_scan_again'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    final matchedId = SafeParser.toNullableInt(result['matched_problem_id']);
    final problemName =
        result['matched_problem_name']?.toString() ?? 'Unknown';
    final confidence =
        ((result['confidence'] as num? ?? 0.88) * 100).round();
    final rawAnalysis = result['ai_analysis']?.toString() ?? '';
    String analysis = rawAnalysis;
    if (analysis.trim().startsWith('{') ||
        analysis.contains('"is_plant"') ||
        analysis.contains('"detected_crop_name"')) {
      analysis =
          "${result['detected_crop_name'] ?? 'Crop'} exhibits symptoms of $problemName. "
          "Follow the weather spray advisory and control measures below.";
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

    Color statusColor;
    String statusTextKey;
    IconData statusIcon;

    switch (healthStatus) {
      case 'healthy':
        statusColor = const Color(0xFF16A34A);
        statusTextKey = 'diag_status_healthy';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'diseased':
        statusColor = const Color(0xFFDC2626);
        statusTextKey = 'diag_status_diseased';
        statusIcon = Icons.coronavirus_rounded;
        break;
      case 'deficiency':
        statusColor = const Color(0xFFD97706);
        statusTextKey = 'diag_status_deficiency';
        statusIcon = Icons.science_rounded;
        break;
      case 'physical_damage':
        statusColor = const Color(0xFFEA580C);
        statusTextKey = 'diag_status_physical';
        statusIcon = Icons.handyman_rounded;
        break;
      case 'pest_infestation':
        statusColor = const Color(0xFFEF4444);
        statusTextKey = 'diag_status_pest';
        statusIcon = Icons.bug_report_rounded;
        break;
      default:
        statusColor = const Color(0xFF16A34A);
        statusTextKey = 'diag_status_healthy';
        statusIcon = Icons.check_circle_rounded;
    }

    Map<String, dynamic>? matchingProblemMap;
    if (matchedId != null && _problemsList != null) {
      try {
        matchingProblemMap =
            _problemsList!.firstWhere((p) => p['id'] == matchedId);
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Diagnosis Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Badges Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            statusTextKey.tr(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'diag_accuracy_match'.tr(args: ['$confidence']),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Issue Title
                Text(
                  problemName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),

                if (detectedCropName != null && detectedCropName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFDCFCE7)),
                    ),
                    child: Text(
                      'diag_crop_label'.tr(args: [detectedCropName]),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                Text(
                  analysis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppTheme.textSecondary,
                    height: 1.45,
                  ),
                ),

                const SizedBox(height: 14),
                // Audio Readout Pill
                _buildSpeechButton(
                  sectionKey: 'diagnosis_overview',
                  text: [
                    if (detectedCropName != null && detectedCropName.isNotEmpty)
                      detectedCropName,
                    problemName,
                    statusTextKey.tr(),
                    analysis,
                  ].join('. '),
                  color: statusColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Weather Spray Advisory Card
          if (result['weather_impact'] != null &&
              result['weather_impact'].toString().trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(18),
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
                          'diag_weather_spray_title'.tr(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                      ),
                      _buildSpeechButton(
                        sectionKey: 'weather_advice',
                        text:
                            "${'diag_weather_spray_title'.tr()}. ${result['weather_impact']}",
                        color: const Color(0xFF0284C7),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result['weather_impact'].toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0C4A6E),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Prescribed Treatment Sections
          if (controls != null && healthStatus != 'healthy') ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'diag_ai_controls'.tr(),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 1. Biological & Organic
            _buildTreatmentCard(
              title: 'diag_biological'.tr(),
              items: controls['biological'],
              color: const Color(0xFF16A34A),
              bgColor: const Color(0xFFF0FDF4),
              borderColor: const Color(0xFFBBF7D0),
              icon: Icons.eco_rounded,
              subtitle: 'diag_dosage_hint'.tr(),
              speechSectionKey: 'biological',
            ),
            const SizedBox(height: 10),

            // 2. Chemical Spray
            _buildTreatmentCard(
              title: 'diag_chemical'.tr(),
              items: controls['chemical'],
              color: const Color(0xFFDC2626),
              bgColor: const Color(0xFFFEF2F2),
              borderColor: const Color(0xFFFECACA),
              icon: Icons.science_rounded,
              subtitle: 'diag_dosage_hint'.tr(),
              speechSectionKey: 'chemical',
            ),
            const SizedBox(height: 10),

            // 3. Preventative Practices
            _buildTreatmentCard(
              title: 'diag_preventative'.tr(),
              items: controls['preventative'],
              color: const Color(0xFF0D9488),
              bgColor: const Color(0xFFF0FDFA),
              borderColor: const Color(0xFF99F6E4),
              icon: Icons.verified_user_rounded,
              speechSectionKey: 'preventative',
            ),
            const SizedBox(height: 14),
          ],

          // Observed Symptoms
          if (observedSymptoms.isNotEmpty) ...[
            _buildTreatmentCard(
              title: 'diag_observed_symptoms'.tr(),
              items: observedSymptoms,
              color: const Color(0xFF475569),
              bgColor: const Color(0xFFF8FAFC),
              borderColor: const Color(0xFFE2E8F0),
              icon: Icons.search_rounded,
              speechSectionKey: 'symptoms',
            ),
            const SizedBox(height: 10),
          ],

          // Recovery Tips
          if (recoveryTips.isNotEmpty) ...[
            _buildTreatmentCard(
              title: 'diag_recovery_tips'.tr(),
              items: recoveryTips,
              color: const Color(0xFF0284C7),
              bgColor: const Color(0xFFF0F9FF),
              borderColor: const Color(0xFFBAE6FD),
              icon: Icons.tips_and_updates_rounded,
              speechSectionKey: 'recovery',
            ),
            const SizedBox(height: 14),
          ],

          // Verified Advisory Navigation Button
          if (matchedId != null && _hasVerifiedAdvisory) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdvisoryDetailScreen(
                        problem: CropProblem(
                          id: matchedId,
                          name: problemName,
                          category: matchingProblemMap?['category'] as String?,
                          imageUrl1:
                              matchingProblemMap?['image_url1'] as String?,
                          imageUrl2:
                              matchingProblemMap?['image_url2'] as String?,
                          imageUrl3:
                              matchingProblemMap?['image_url3'] as String?,
                        ),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                label: Text(
                  'diag_view_verified'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Bottom Quick Actions Bar (Save, Share, Scan Again)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                // Save Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _toggleSaveAdvisory,
                    icon: Icon(
                      _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      size: 18,
                      color: _isSaved ? const Color(0xFF16A34A) : AppTheme.textPrimary,
                    ),
                    label: Text(
                      _isSaved ? 'diag_saved'.tr() : 'diag_save'.tr(),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _isSaved ? const Color(0xFF16A34A) : AppTheme.textPrimary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      side: BorderSide(
                        color: _isSaved ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Share Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _shareAdvisory,
                    icon: const Icon(Icons.share_rounded, size: 18, color: Colors.white),
                    label: Text(
                      'diag_share'.tr(),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Scan Again Button
                IconButton(
                  onPressed: () => _localPickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, color: AppTheme.primary),
                  tooltip: 'diag_scan_again'.tr(),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF0FDF4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFBBF7D0)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildTreatmentCard({
    required String title,
    required dynamic items,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required IconData icon,
    String? subtitle,
    String? speechSectionKey,
  }) {
    final list = items is List ? List<String>.from(items) : <String>[];
    if (list.isEmpty) return const SizedBox.shrink();

    return Container(
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
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: color,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (speechSectionKey != null)
                _buildSpeechButton(
                  sectionKey: speechSectionKey,
                  text: "$title. ${list.join('. ')}",
                  color: color,
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...list.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5.0),
                    child: Icon(Icons.circle, size: 5.5, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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

  Widget _buildCreditBadge() {
    if (_creditStatus == null) return const SizedBox.shrink();
    final remaining = _creditStatus!.totalAvailable;
    final isLow = remaining <= 2;
    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showPurchaseCreditsModal(),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isLow ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isLow ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLow ? Icons.bolt_rounded : Icons.eco_rounded,
                  size: 14,
                  color: isLow ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                ),
                const SizedBox(width: 4),
                Text(
                  _creditStatus!.isUsingPurchasedCredits
                      ? "$remaining"
                      : "${_creditStatus!.dailyRemaining}/10",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isLow ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.add_circle_outline_rounded,
                  size: 13,
                  color: isLow ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                ),
              ],
            ),
          ),
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
