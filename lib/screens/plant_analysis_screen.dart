import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cropsync/models/crop_problem.dart';
import 'package:cropsync/screens/advisory_details.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
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

  @override
  void initState() {
    super.initState();
    _activeImagePath = widget.imagePath;
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
    super.dispose();
  }

  void _startPrepareTimer(ImageSource source) {
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
    _prepareTimer?.cancel();
    setState(() {
      _isPreparingPicker = false;
      _selectedSource = null;
    });
    if (_activeImagePath == null) {
      Navigator.of(context).pop();
    }
  }

  Future<int> _getAvailableRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final times = prefs.getStringList('nvidia_request_timestamps') ?? [];

    final validTimes = times.where((t) {
      final dt = DateTime.tryParse(t);
      if (dt == null) return false;
      return now.difference(dt).inSeconds < 60;
    }).toList();

    return (40 - validTimes.length).clamp(0, 40).toInt();
  }

  Future<void> _recordRequest() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final times = prefs.getStringList('nvidia_request_timestamps') ?? [];

    final validTimes = times.where((t) {
      final dt = DateTime.tryParse(t);
      if (dt == null) return false;
      return now.difference(dt).inSeconds < 60;
    }).toList();

    validTimes.add(now.toIso8601String());
    await prefs.setStringList('nvidia_request_timestamps', validTimes);
  }

  Future<void> _analyzeImage() async {
    if (_activeImagePath == null) return;
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

    final nvidiaKey = dotenv.env['NVIDIA_API_KEY'];
    if (nvidiaKey == null || nvidiaKey.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMsg =
            "NVIDIA API Key is missing. Please add it to your .env file.";
      });
      return;
    }

    try {
      final locale = context.locale.languageCode;
      final langName = locale == 'te'
          ? 'Telugu'
          : locale == 'hi'
              ? 'Hindi'
              : 'English';

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
        return;
      }
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      final prompt = """
You are a highly capable AI Plant Pathologist and Agronomist.
Your task is to perform an advanced plant health diagnosis and visual analysis on the uploaded image.

Follow these strict rules:
1. First, verify if the image shows a plant, crop, leaf, stem, fruit, or root. If the image is of something else (like a person, a room, a household object, or text), you must set "is_plant" to false and explain why in the "reason" field.
2. If it is a plant:
   - Identify the crop shown in the image from the database list of crops: ${jsonEncode(formattedCrops)}. Set "detected_crop_id" to its exact integer ID and "detected_crop_name" to its name. If the crop in the image is not in this database list, set "detected_crop_id" to null and "detected_crop_name" to the name of the crop you identify.
   - Identify if the plant is completely **healthy**. If so, set "health_status" to "healthy" and "matched_problem_name" to "Healthy Plant".
   - Check for **physical damages** (e.g. stem breakage, lodging, wilting, torn leaves, animal damage). If detected, set "health_status" to "physical_damage".
   - Check for **nutrient deficiencies** (e.g. chlorosis/yellowing, necrosis, purpling leaves, stunted growth). If detected, set "health_status" to "deficiency".
   - Check for **diseases or insect pest infestations**. If detected, set "health_status" to "diseased" or "pest_infestation".
3. List the visual symptoms and damages observed in the image (e.g., "broken main stem at lower branch", "wilting leaves due to moisture stress", "interveinal chlorosis") inside "observed_symptoms".
4. Suggest a list of actionable recovery actions (e.g., physical staking, fertilizer application adjustments, watering schedule change) in "recovery_recommendations".
5. Compare your diagnosis with our database of known problems to find matches. Here is the database list:
${jsonEncode(formattedProblems)}

Crucially, make sure that the matched problem's "crop_id" matches the "detected_crop_id" of the crop you identified in step 2. For example, if you detect Rice/Paddy Blast, match it with the Blast problem that is associated with the Paddy/Rice crop (detected_crop_id matching its crop_id), NOT wheat, maize, or other crops. If it matches one of these database items, set "matched_problem_id" to its exact integer ID, and "matched_problem_name" to its name.
6. Provide general fallback AI control measures in "ai_control_measures".

You MUST output the JSON values (specifically "matched_problem_name", "detected_crop_name", "health_status", "observed_symptoms", "ai_analysis", "recovery_recommendations", "reason", and "ai_control_measures") in the $langName language. Ensure that the JSON keys remain exactly as defined (in English) but the string values are translated/written in $langName.

Output RAW JSON ONLY. Do not wrap in markdown or any conversational text.
Format:
{
  "is_plant": true,
  "reason": "",
  "detected_crop_id": null or number,
  "detected_crop_name": "Paddy" or similar,
  "matched_problem_id": null or number,
  "matched_problem_name": "identified problem name or 'Healthy Plant'",
  "health_status": "healthy" or "diseased" or "deficiency" or "physical_damage" or "pest_infestation",
  "confidence": 0.95,
  "observed_symptoms": ["symptom 1", "symptom 2"],
  "ai_analysis": "Provide a descriptive analysis of the plant's health and damage localization details.",
  "recovery_recommendations": ["recommendation 1", "recommendation 2"],
  "ai_control_measures": {
    "chemical": ["Apply chemical control step 1"],
    "biological": ["Apply biological control/organic step 1"],
    "preventative": ["Apply preventative step 1"]
  }
}
""";

      final response = await http
          .post(
            Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $nvidiaKey',
            },
            body: jsonEncode({
              'model': 'google/diffusiongemma-26b-a4b-it',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'text',
                      'text': prompt,
                    },
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:image/jpeg;base64,$base64Image',
                      },
                    }
                  ],
                }
              ],
              'temperature': 0.1,
              'max_tokens': 1500,
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        await _recordRequest();

        final resData = jsonDecode(utf8.decode(response.bodyBytes));
        final content = resData['choices'][0]['message']['content'] as String;

        String cleaned = content;
        if (cleaned.contains('```json')) {
          cleaned = cleaned.split('```json').last;
        }
        if (cleaned.contains('```')) {
          cleaned = cleaned.split('```').first;
        }

        final parsed = jsonDecode(cleaned.trim()) as Map<String, dynamic>;
        final matchedId = parsed['matched_problem_id'] as int?;
        bool hasVerifiedAdvisory = false;
        if (matchedId != null) {
          try {
            final advisory =
                await ApiService.getAdvisories(matchedId, lang: locale)
                    .timeout(const Duration(seconds: 5));
            if (advisory != null) {
              hasVerifiedAdvisory = true;
            }
          } catch (_) {}
        }

        setState(() {
          _analysisResult = parsed;
          _hasVerifiedAdvisory = hasVerifiedAdvisory;
          _isLoading = false;
        });
        _loadingTimer?.cancel();
      } else {
        setState(() {
          _isLoading = false;
          _errorMsg = response.statusCode == 503
              ? "The AI model is currently busy or starting up. Please try again in a few moments."
              : response.statusCode == 429
                  ? "Too many requests. Please wait a moment before trying again."
                  : "API Error: ${response.statusCode}. Please try again.";
        });
        _loadingTimer?.cancel();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = "Connection error. Please check your internet connection.";
      });
      _loadingTimer?.cancel();
      debugPrint("Vision API error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('diag_title'.tr(), style: AppTheme.appBarTitle),
        backgroundColor: Colors.white,
        leading: AppTheme.backButton(context, color: AppTheme.appBarText),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _buildDiagnosisTab(),
    );
  }

  Future<void> _localPickImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
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
                const SizedBox(height: 24),
                FutureBuilder<int>(
                  future: _getAvailableRequests(),
                  builder: (context, snapshot) {
                    final reqs = snapshot.data ?? 40;
                    return Text(
                      'diag_rate_limit'.tr(args: [reqs.toString()]),
                      style: TextStyle(
                        fontSize: 13,
                        color: reqs < 5 ? Colors.red : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
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
                FutureBuilder<int>(
                  future: _getAvailableRequests(),
                  builder: (context, snapshot) {
                    final reqs = snapshot.data ?? 40;
                    return Text(
                      'diag_rate_limit'.tr(args: [reqs.toString()]),
                      style: TextStyle(
                        fontSize: 13,
                        color: reqs < 5 ? Colors.red : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
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
            const Icon(Icons.warning_amber_rounded,
                size: 44, color: Color(0xFFD97706)),
            const SizedBox(height: 12),
            Text(
              'diag_not_plant'.tr(),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF92400E)),
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
    final confidence = ((result['confidence'] as num? ?? 0.0) * 100).round();
    final analysis = result['ai_analysis']?.toString() ?? "";
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
          const SizedBox(height: 20),
          if (observedSymptoms.isNotEmpty)
            _buildControlList('diag_observed_symptoms'.tr(), observedSymptoms,
                const Color(0xFF475569), Icons.search_rounded),
          if (recoveryTips.isNotEmpty)
            _buildControlList('diag_recovery_tips'.tr(), recoveryTips,
                const Color(0xFF0D9488), Icons.tips_and_updates_rounded),
          if (matchedId != null && _hasVerifiedAdvisory) ...[
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
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
          if ((matchedId == null || !_hasVerifiedAdvisory) &&
              controls != null &&
              healthStatus != 'healthy') ...[
            Text(
              'diag_ai_controls'.tr(),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            _buildControlList(
                'diag_preventative'.tr(),
                controls['preventative'],
                const Color(0xFF0F766E),
                Icons.verified_user_rounded),
            const SizedBox(height: 12),
            _buildControlList('diag_biological'.tr(), controls['biological'],
                const Color(0xFF16A34A), Icons.eco_rounded),
            const SizedBox(height: 12),
            _buildControlList('diag_chemical'.tr(), controls['chemical'],
                const Color(0xFFDC2626), Icons.science_rounded),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildControlList(
      String title, dynamic items, Color color, IconData icon) {
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
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15, color: color)),
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
