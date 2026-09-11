import 'dart:async';
import 'dart:io';
import 'package:cropsync/models/crop_problem.dart';
import 'package:cropsync/screens/advisory_details.dart';
import 'package:cropsync/services/ai_credit_service.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/deepseek_plant_doctor_service.dart';
import 'package:cropsync/services/location_service.dart';
import 'package:cropsync/services/razorpay_payment_service.dart';
import 'package:cropsync/services/text_to_speech_service.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlantAnalysisScreen extends StatefulWidget {
  final String? imagePath;
  final ImageSource? initialSource;
  const PlantAnalysisScreen({super.key, this.imagePath, this.initialSource});

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

  // Preparation state for launching picker
  bool _isPreparingPicker = false;
  ImageSource? _selectedSource;
  Timer? _prepareTimer;
  int _prepareCountdown = 2;

  // Dynamic loading texts — resolved at runtime so locale is respected
  int _loadingTextIndex = 0;
  Timer? _loadingTimer;
  List<String> get _loadingTexts => [
    context.tr('diag_loading_1'),
    context.tr('diag_loading_2'),
    context.tr('diag_loading_3'),
    context.tr('diag_loading_4'),
    context.tr('diag_loading_5'),
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
    _razorpayService = RazorpayPaymentService();
    _ttsService = TextToSpeechService();
    _loadCreditStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialSource != null) {
        _startPrepareTimer(widget.initialSource!);
      }
    });
  }

  @override
  void dispose() {
    _prepareTimer?.cancel();
    _loadingTimer?.cancel();
    _razorpayService.dispose();
    _ttsService.stop();
    super.dispose();
  }

  void _startPrepareTimer(ImageSource source) {
    _ttsService.stop();
    _prepareTimer?.cancel();
    setState(() {
      _isPreparingPicker = true;
      _selectedSource = source;
      _prepareCountdown = 2;
    });

    _prepareTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_prepareCountdown > 1) {
          setState(() {
            _prepareCountdown--;
          });
        } else {
          timer.cancel();
          setState(() {
            _isPreparingPicker = false;
          });
          _localPickImage(_selectedSource!);
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _switchPrepareSource() {
    if (_selectedSource == ImageSource.camera) {
      _startPrepareTimer(ImageSource.gallery);
    } else {
      _startPrepareTimer(ImageSource.camera);
    }
  }

  void _cancelPrepare() {
    _ttsService.stop();
    _prepareTimer?.cancel();
    setState(() {
      _isPreparingPicker = false;
      _selectedSource = null;
    });
    if (_activeImagePath == null) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _loadCreditStatus() async {
    final status = await AiCreditService.getCreditStatus();
    if (mounted) {
      setState(() {
        _creditStatus = status;
      });
    }
  }

  Widget _buildCreditQuotaWidget() {
    final status = _creditStatus;
    final remaining = status?.totalAvailable ?? 10;
    final hasCredits = remaining > 0;
    final isUsingPurchased = status?.isUsingPurchasedCredits ?? false;

    return InkWell(
      onTap: () => _showPurchaseCreditsModal(),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasCredits ? Icons.eco_rounded : Icons.bolt_rounded,
              size: 16,
              color: hasCredits ? const Color(0xFF2E7D32) : const Color(0xFFDC2626),
            ),
            const SizedBox(width: 6),
            Text(
              hasCredits
                  ? (isUsingPurchased
                      ? "$remaining scans available (${status!.purchasedCredits} purchased)"
                      : "${status?.dailyRemaining ?? 10}/10 free scans left today")
                  : "Daily limit reached (0/10) • Add 10 scans for ₹1",
              style: TextStyle(
                fontSize: 13,
                color: hasCredits ? const Color(0xFF2E7D32) : const Color(0xFFDC2626),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!hasCredits) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 11,
                color: Color(0xFFDC2626),
              ),
            ],
          ],
        ),
      ),
    );
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
        _errorMsg = "DeepSeek API Key is missing. Please add DEEPSEEK_API_KEY to your .env file.";
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

      // Fetch user GPS position to allow hyper-local weather tool execution
      final position = await LocationService.getCurrentPosition();

      // Call DeepSeek Plant Doctor with automatic prompt caching and weather tool execution
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

      final matchedId = parsed['matched_problem_id'] as int?;
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
          title: Text('diag_title'.tr(), style: AppTheme.appBarTitle),
          backgroundColor: Colors.white,
          leading: AppTheme.backButton(context, color: AppTheme.appBarText),
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          actions: [
            _buildCreditBadge(),
          ],
        ),
        body: _buildDiagnosisTab(),
      ),
    );
  }

  Future<void> _localPickImage(ImageSource source) async {
    _ttsService.stop();
    // Check credit status before picking photo
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
        maxWidth: 384,
        maxHeight: 384,
        imageQuality: 65,
        requestFullMetadata: false,
      );
      if (photo != null && mounted) {
        setState(() {
          _activeImagePath = photo.path;
          _analysisResult = null;
          _errorMsg = null;
        });
        // Auto-run analysis
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted && _activeImagePath != null) {
            _analyzeImage();
          }
        });
      } else {
        // If cancelled and we don't have an active image path yet, go back
        if (mounted && _activeImagePath == null) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      setState(() {
        _errorMsg = "Error picking image: $e";
      });
    }
  }

  Widget _buildDiagnosisTab() {
    if (_isPreparingPicker) {
      final isCamera = _selectedSource == ImageSource.camera;
      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0FDF4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCamera ? Icons.camera_alt_rounded : Icons.photo_library_rounded,
                    size: 48,
                    color: const Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isCamera ? "Opening Camera..." : "Opening Gallery...",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Starting in $_prepareCountdown seconds. You can switch to the other option below.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 140,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                    color: Colors.green,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _cancelPrepare,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _switchPrepareSource,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            isCamera ? "Use Gallery" : "Use Camera",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_activeImagePath == null) {
      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0FDF4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_enhance_rounded,
                    size: 48,
                    color: Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Scan & Diagnose Crop",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Take a photo of your crop or upload one from the gallery to run instant AI scans for diseases, pests, or nutrient deficiencies.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () => _startPrepareTimer(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white),
                          label: const Text(
                            "Camera",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: () => _startPrepareTimer(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_rounded,
                              color: Color(0xFF16A34A)),
                          label: const Text(
                            "Upload",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF16A34A)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Color(0xFF16A34A), width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildCreditQuotaWidget(),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
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
          if (!_isLoading && _analysisResult == null && _errorMsg == null)
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _analyzeImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.psychology_rounded,
                              color: Colors.white),
                          const SizedBox(width: 12),
                          Text(
                            'diag_btn_analyze'.tr(),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildCreditQuotaWidget(),
                const SizedBox(height: 24),
              ],
            ),
          if (_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    SizedBox(
                      width: 140,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.green.withValues(alpha: 0.1),
                        color: Colors.green,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _loadingTexts[_loadingTextIndex],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_errorMsg != null)
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2FE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(_errorMsg!,
                          style: const TextStyle(color: Colors.red))),
                ],
              ),
            ),
          if (_analysisResult != null) _buildResultSection(),
        ],
      ),
    );
  }

  /// Reusable Speech Button for Diagnosis Sections
  /// Reads out text in user's active app language (Telugu, Hindi, or English)
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
          message: isSpeaking ? 'Stop reading' : 'Read aloud',
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
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSpeaking
                    ? effectiveColor.withValues(alpha: 0.18)
                    : effectiveColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSpeaking
                      ? effectiveColor
                      : effectiveColor.withValues(alpha: 0.25),
                  width: isSpeaking ? 1.5 : 1.0,
                ),
              ),
              child: Icon(
                isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                size: 18,
                color: isSpeaking
                    ? effectiveColor
                    : effectiveColor.withValues(alpha: 0.85),
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
          result['reason']?.toString() ?? "This does not appear to be a plant.";
      return Container(
        margin: const EdgeInsets.all(20),
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
                    size: 32, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Text(
                  'diag_not_plant'.tr(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF92400E)),
                ),
                const SizedBox(width: 8),
                _buildSpeechButton(
                  sectionKey: 'not_plant',
                  text: "${'diag_not_plant'.tr()}. $reason",
                  color: const Color(0xFFD97706),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF92400E), height: 1.4),
            ),
          ],
        ),
      );
    }

    final matchedId = result['matched_problem_id'] as int?;
    final problemName = result['matched_problem_name']?.toString() ?? "Unknown";
    final confidence = ((result['confidence'] as num? ?? 0.88) * 100).round();
    final rawAnalysis = result['ai_analysis']?.toString() ?? "";
    String analysis = rawAnalysis;
    if (analysis.trim().startsWith('{') ||
        analysis.contains('"is_plant"') ||
        analysis.contains('"detected_crop_name"')) {
      analysis = "${result['detected_crop_name'] ?? 'Crop'} exhibits symptoms of $problemName. "
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
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
                        Icon(statusIcon, color: statusColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          statusTextKey.tr(),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                              fontSize: 14),
                        ),
                      ],
                    ),
                    _buildSpeechButton(
                      sectionKey: 'diagnosis_overview',
                      text: [
                        if (detectedCropName != null && detectedCropName.isNotEmpty) detectedCropName,
                        problemName,
                        statusTextKey.tr(),
                        analysis,
                      ].join('. '),
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            problemName,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary),
                          ),
                          if (detectedCropName != null && detectedCropName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              "Crop: $detectedCropName",
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "$confidence% Match",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  analysis,
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (result['weather_impact'] != null &&
              result['weather_impact'].toString().trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
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
                      const Expanded(
                        child: Text(
                          "Agro-Weather Correlation & Spray Advice",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                      ),
                      _buildSpeechButton(
                        sectionKey: 'weather_advice',
                        text: "Agro-Weather Correlation & Spray Advice. ${result['weather_impact']}",
                        color: const Color(0xFF0284C7),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result['weather_impact'].toString(),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF0C4A6E),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (observedSymptoms.isNotEmpty)
            _buildControlList(
              'diag_observed_symptoms'.tr(),
              observedSymptoms,
              const Color(0xFF475569),
              Icons.search_rounded,
              speechSectionKey: 'symptoms',
            ),
          if (recoveryTips.isNotEmpty)
            _buildControlList(
              'diag_recovery_tips'.tr(),
              recoveryTips,
              const Color(0xFF0D9488),
              Icons.tips_and_updates_rounded,
              speechSectionKey: 'recovery',
            ),
          if (controls != null && healthStatus != 'healthy') ...[
            Text(
              'diag_ai_controls'.tr(),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            _buildControlList(
              'diag_chemical'.tr(),
              controls['chemical'],
              const Color(0xFFDC2626),
              Icons.science_rounded,
              subtitle: "Per Acre • Water Mix",
              speechSectionKey: 'chemical',
            ),
            const SizedBox(height: 12),
            _buildControlList(
              'diag_biological'.tr(),
              controls['biological'],
              const Color(0xFF16A34A),
              Icons.eco_rounded,
              subtitle: "Per Acre • Water Mix",
              speechSectionKey: 'biological',
            ),
            const SizedBox(height: 12),
            _buildControlList(
              'diag_preventative'.tr(),
              controls['preventative'],
              const Color(0xFF0F766E),
              Icons.verified_user_rounded,
              speechSectionKey: 'preventative',
            ),
            const SizedBox(height: 20),
          ],
          if (matchedId != null && _hasVerifiedAdvisory) ...[
            SizedBox(
              width: double.infinity,
              height: 54,
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
                icon: const Icon(Icons.verified_rounded, color: Colors.white),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                label: Text(
                  'diag_view_verified'.tr(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildControlList(
      String title, dynamic items, Color color, IconData icon,
      {String? subtitle, String? speechSectionKey}) {
    final list = items is List ? List<String>.from(items) : <String>[];
    if (list.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
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
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15, color: color)),
              ),
              if (subtitle != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.water_drop_rounded, size: 11, color: color),
                      const SizedBox(width: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
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
          const SizedBox(height: 10),
          ...list.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Icon(Icons.circle,
                          size: 6, color: color.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tip,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
        ],
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
                      ? "$remaining Credits"
                      : "${_creditStatus!.dailyRemaining}/10 Free",
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
            // Soft scanning green gradient overlay
            Positioned.fill(
              child: Container(
                color: Colors.green.withValues(alpha: 0.08),
              ),
            ),
            // Moving laser line
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


