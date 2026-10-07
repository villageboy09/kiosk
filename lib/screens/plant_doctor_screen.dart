// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/ai_credit_service.dart';
import 'package:cropsync/services/deepseek_plant_doctor_service.dart';
import 'package:cropsync/services/location_service.dart';
import 'package:cropsync/services/razorpay_payment_service.dart';
import 'package:cropsync/services/saved_advisories_service.dart';
import 'package:cropsync/services/text_to_speech_service.dart';
import 'package:cropsync/utils/safe_parser.dart';
import 'package:cropsync/widgets/language_button.dart';
import 'package:cropsync/screens/agri_shop.dart';
import 'package:cropsync/screens/saved_advisories_screen.dart';

/// AI Plant Doctor: pick crop -> take photo -> diagnosis.
class PlantDoctorScreen extends StatefulWidget {
  static const List<Map<String, dynamic>> supportedCrops = [
    {
      'id': 1,
      'name_en': 'Paddy',
      'name_te': 'వరి',
      'name_hi': 'धान',
      'emoji': '🌾',
      'image_url': 'https://app.cropsync.in/Paddy.jpg',
      'color': Color(0xFF16A34A)
    },
    {
      'id': 2,
      'name_en': 'Cotton',
      'name_te': 'పత్తి',
      'name_hi': 'कपास',
      'emoji': '☁️',
      'image_url': 'https://app.cropsync.in/Cotton.jpg',
      'color': Color(0xFF0284C7)
    },
    {
      'id': 18,
      'name_en': 'Chilli',
      'name_te': 'మిరప',
      'name_hi': 'मिर्च',
      'emoji': '🌶️',
      'image_url': 'https://kiosk.cropsync.in/crops/chilli.jpg',
      'color': Color(0xFFDC2626)
    },
    {
      'id': 19,
      'name_en': 'Tomato',
      'name_te': 'టమాటా',
      'name_hi': 'टमाटर',
      'emoji': '🍅',
      'image_url': 'https://kiosk.cropsync.in/crops/tomato.jpg',
      'color': Color(0xFFE11D48)
    },
    {
      'id': 17,
      'name_en': 'Maize',
      'name_te': 'మొక్కజొన్న',
      'name_hi': 'मक्का',
      'emoji': '🌽',
      'image_url': 'https://kiosk.cropsync.in/crops/maize.jpg',
      'color': Color(0xFFD97706)
    },
    {
      'id': 26,
      'name_en': 'Groundnut',
      'name_te': 'వేరుశనగ',
      'name_hi': 'मूंगफली',
      'emoji': '🥜',
      'image_url': 'https://kiosk.cropsync.in/crops/groundnut.jpg',
      'color': Color(0xFFB45309)
    },
    {
      'id': 14,
      'name_en': 'Turmeric',
      'name_te': 'పసుపు',
      'name_hi': 'हल्दी',
      'emoji': '🌱',
      'image_url': 'https://kiosk.cropsync.in/crops/turmeric.jpg',
      'color': Color(0xFFF59E0B)
    },
    {
      'id': 12,
      'name_en': 'Sunflower',
      'name_te': 'పొద్దుతిరుగుడు',
      'name_hi': 'सूरजमुखी',
      'emoji': '🌻',
      'image_url': 'https://kiosk.cropsync.in/crops/sunflower.jpg',
      'color': Color(0xFFEAB308)
    },
    {
      'id': 13,
      'name_en': 'Banana',
      'name_te': 'అరటి',
      'name_hi': 'केला',
      'emoji': '🍌',
      'image_url': 'https://kiosk.cropsync.in/crops/banana.jpg',
      'color': Color(0xFFCA8A04)
    },
    {
      'id': 23,
      'name_en': 'Sugarcane',
      'name_te': 'చెరకు',
      'name_hi': 'गन्ना',
      'emoji': '🎋',
      'image_url': 'https://kiosk.cropsync.in/crops/sugarcane.jpg',
      'color': Color(0xFF059669)
    },
    {
      'id': 28,
      'name_en': 'Onion',
      'name_te': 'ఉల్లిపాయ',
      'name_hi': 'प्याज',
      'emoji': '🧅',
      'image_url': 'https://kiosk.cropsync.in/crops/onion.jpg',
      'color': Color(0xFF9333EA)
    },
    {
      'id': 29,
      'name_en': 'Soybean',
      'name_te': 'సోయాబీన్',
      'name_hi': 'सोयाबीन',
      'emoji': '🌿',
      'image_url': 'https://kiosk.cropsync.in/crops/soybean.jpg',
      'color': Color(0xFF15803D)
    },
    {
      'id': 30,
      'name_en': 'Wheat',
      'name_te': 'గోధుమ',
      'name_hi': 'गेहूं',
      'emoji': '🌾',
      'image_url': 'https://kiosk.cropsync.in/crops/wheat.jpg',
      'color': Color(0xFFD97706)
    },
    {
      'id': 27,
      'name_en': 'Mango',
      'name_te': 'మామిడి',
      'name_hi': 'आम',
      'emoji': '🥭',
      'image_url': 'https://kiosk.cropsync.in/crops/mango.jpg',
      'color': Color(0xFFEA580C)
    },
    {
      'id': 34,
      'name_en': 'Pomegranate',
      'name_te': 'దానిమ్మ',
      'name_hi': 'अनार',
      'emoji': '🍎',
      'image_url': 'https://kiosk.cropsync.in/crops/pomegranate.jpg',
      'color': Color(0xFFBE123C)
    },
    {
      'id': 35,
      'name_en': 'Grapes',
      'name_te': 'ద్రాక్ష',
      'name_hi': 'अंगूर',
      'emoji': '🍇',
      'image_url': 'https://kiosk.cropsync.in/crops/grapes.jpg',
      'color': Color(0xFF7E22CE)
    },
    {
      'id': 24,
      'name_en': 'Brinjal',
      'name_te': 'వంకాయ',
      'name_hi': 'बैंगन',
      'emoji': '🍆',
      'image_url': 'https://kiosk.cropsync.in/crops/brinjal.jpg',
      'color': Color(0xFF6B21A8)
    },
    {
      'id': 32,
      'name_en': 'Okra',
      'name_te': 'బెండకాయ',
      'name_hi': 'भिंडी',
      'emoji': '🥬',
      'image_url': 'https://kiosk.cropsync.in/crops/okra.jpg',
      'color': Color(0xFF166534)
    },
    {
      'id': 33,
      'name_en': 'Potato',
      'name_te': 'బంగాళాదుంప',
      'name_hi': 'आलू',
      'emoji': '🥔',
      'image_url': 'https://kiosk.cropsync.in/crops/potato.jpg',
      'color': Color(0xFF78350F)
    },
    {
      'id': 31,
      'name_en': 'Garlic',
      'name_te': 'వెల్లుల్లి',
      'name_hi': 'लहसुन',
      'emoji': '🧄',
      'image_url': 'https://kiosk.cropsync.in/crops/garlic.jpg',
      'color': Color(0xFF64748B)
    },
    {
      'id': 20,
      'name_en': 'Bitter Gourd',
      'name_te': 'కాకర',
      'name_hi': 'करेला',
      'emoji': '🥒',
      'image_url': 'https://kiosk.cropsync.in/crops/bitter_gourd.jpg',
      'color': Color(0xFF15803D)
    },
    {
      'id': 25,
      'name_en': 'Cumin',
      'name_te': 'జీలకర్ర',
      'name_hi': 'जीरा',
      'emoji': '🌾',
      'image_url': 'https://kiosk.cropsync.in/crops/cumin.jpg',
      'color': Color(0xFF92400E)
    },
    {
      'id': 22,
      'name_en': 'Apple',
      'name_te': 'ఆపిల్',
      'name_hi': 'सेब',
      'emoji': '🍏',
      'image_url': 'https://kiosk.cropsync.in/crops/apple.jpg',
      'color': Color(0xFFDC2626)
    },
    {
      'id': 21,
      'name_en': 'Tea',
      'name_te': 'టీ',
      'name_hi': 'चाय',
      'emoji': '🍵',
      'image_url': 'https://kiosk.cropsync.in/crops/tea.jpg',
      'color': Color(0xFF15803D)
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

enum _Stage { crop, analysing, result }

// Palette
const _ink = Color(0xFF111827);
const _muted = Color(0xFF6B7280);
const _line = Color(0xFFE5E7EB);
const _bg = Color(0xFFF9FAFB);
const _green = Color(0xFF15803D);
const _greenSoft = Color(0xFFF0FDF4);

class _PlantDoctorScreenState extends State<PlantDoctorScreen> {
  static const Map<String, List<String>> _strings = {
    'title': ['Plant Doctor', 'పంట డాక్టర్', 'फसल डॉक्टर'],
    'pick_crop_title': [
      'Which crop needs a check-up?',
      'ఏ పంటను పరీక్షించాలి?',
      'किस फसल की जांच करनी है?'
    ],
    'pick_crop_sub': [
      'Choose the crop, then take a clear photo of the affected leaf.',
      'పంటను ఎంచుకుని, సమస్య ఉన్న ఆకు ఫోటో తీయండి.',
      'फसल चुनें, फिर प्रभावित पत्ती की साफ फोटो लें।'
    ],
    'search': ['Search crops', 'పంటను వెతకండి', 'फसल खोजें'],
    'recent': ['Recent scans', 'ఇటీవలి పరీక్షలు', 'हाल की जांच'],
    'view_all': ['View all', 'అన్నీ చూడండి', 'सभी देखें'],
    'no_crop_found': ['No crop found', 'పంట కనబడలేదు', 'कोई फसल नहीं मिली'],
    'photo_title': [
      'Photo of the affected part',
      'సమస్య ఉన్న భాగం ఫోటో తీయండి',
      'प्रभावित हिस्से की फोटो लें'
    ],
    'tip1': [
      'Fill the frame with one affected leaf',
      'ఒక ఆకు ఫ్రేమ్ నిండా ఉండేలా తీయండి',
      'एक प्रभावित पत्ती से पूरा फ्रेम भरें'
    ],
    'tip2': [
      'Use daylight and avoid shadows',
      'పగటి వెలుతురులో, నీడ లేకుండా తీయండి',
      'दिन की रोशनी में, बिना छाया के लें'
    ],
    'tip3': [
      'Hold the camera steady',
      'కెమెరా కదలకుండా పట్టుకోండి',
      'कैमरा स्थिर रखें'
    ],
    'camera': ['Take photo', 'ఫోటో తీయండి', 'फोटो लें'],
    'gallery': ['Gallery', 'గ్యాలరీ', 'गैलरी'],
    'change': ['Change', 'మార్చండి', 'बदलें'],
    'scans_left': [
      '{n} scans available',
      '{n} పరీక్షలు అందుబాటులో ఉన్నాయి',
      '{n} जांच उपलब्ध'
    ],
    'analysing': [
      'Analysing your crop',
      'మీ పంటను పరిశీలిస్తోంది',
      'आपकी फसल की जांच हो रही है'
    ],
    'load1': [
      'Looking at leaf symptoms…',
      'ఆకుపై లక్షణాలను చూస్తోంది…',
      'पत्ती के लक्षण देख रहे हैं…'
    ],
    'load2': [
      'Comparing with known diseases and pests…',
      'తెలిసిన తెగుళ్లు, పురుగులతో పోలుస్తోంది…',
      'ज्ञात रोगों और कीटों से मिलान…'
    ],
    'load3': [
      'Checking local weather…',
      'స్థానిక వాతావరణం చూస్తోంది…',
      'स्थानीय मौसम देख रहे हैं…'
    ],
    'load4': [
      'Preparing your treatment plan…',
      'చికిత్స సలహా సిద్ధం చేస్తోంది…',
      'उपचार योजना तैयार हो रही है…'
    ],
    'cancel': ['Cancel', 'రద్దు చేయండి', 'रद्द करें'],
    'healthy_title': [
      'Your crop looks healthy',
      'మీ పంట ఆరోగ్యంగా ఉంది',
      'आपकी फसल स्वस्थ दिख रही है'
    ],
    'status_healthy': ['Healthy', 'ఆరోగ్యంగా ఉంది', 'स्वस्थ'],
    'status_diseased': ['Disease', 'తెగులు', 'रोग'],
    'status_pest_infestation': ['Pest attack', 'పురుగు దాడి', 'कीट प्रकोप'],
    'status_deficiency': [
      'Nutrient deficiency',
      'పోషక లోపం',
      'पोषक तत्व की कमी'
    ],
    'status_unknown': ['Needs attention', 'శ్రద్ధ అవసరం', 'ध्यान दें'],
    'sev_mild': ['Mild', 'తక్కువ', 'हल्का'],
    'sev_moderate': ['Moderate', 'మధ్యస్థం', 'मध्यम'],
    'sev_severe': ['Severe', 'తీవ్రం', 'गंभीर'],
    'confidence': ['Confidence', 'నమ్మకం', 'विश्वास'],
    'verified': ['Verified', 'ధృవీకరించబడింది', 'सत्यापित'],
    'listen': ['Listen', 'వినండి', 'सुनें'],
    'stop': ['Stop', 'ఆపండి', 'रोकें'],
    'save': ['Save', 'సేవ్', 'सेव'],
    'saved': ['Saved', 'సేవ్ అయింది', 'सेव हुआ'],
    'share': ['Share', 'షేర్', 'शेयर'],
    'summary': ['What we found', 'మేము గుర్తించినది', 'हमने क्या पाया'],
    'symptoms': ['Symptoms seen', 'కనిపించిన లక్షణాలు', 'दिखे लक्षण'],
    'treatment': ['Treatment', 'చికిత్స', 'उपचार'],
    'care': ['Care tips', 'సంరక్షణ సూచనలు', 'देखभाल सुझाव'],
    'tab_chem': ['Chemical', 'రసాయన', 'रासायनिक'],
    'tab_bio': ['Organic', 'సేంద్రీయ', 'जैविक'],
    'tab_prev': ['Prevention', 'నివారణ', 'रोकथाम'],
    'empty_list': [
      'Nothing needed for this condition.',
      'ఈ పరిస్థితికి అవసరం లేదు.',
      'इस स्थिति में आवश्यक नहीं।'
    ],
    'weather': ['Spray advice', 'పిచికారీ సలహా', 'छिड़काव सलाह'],
    'buy': ['Buy products', 'మందులు కొనండి', 'दवा खरीदें'],
    'helpline': ['Kisan helpline', 'కిసాన్ హెల్ప్‌లైన్', 'किसान हेल्पलाइन'],
    'new_scan': [
      'Scan another plant',
      'మరో మొక్కను పరీక్షించండి',
      'दूसरा पौधा जांचें'
    ],
    'disclaimer': [
      'AI-generated advice. Read the product label and consult your local agriculture officer before spraying.',
      'ఇది AI సలహా. పిచికారీ చేసే ముందు మందు లేబుల్ చదివి, స్థానిక వ్యవసాయ అధికారిని సంప్రదించండి.',
      'यह AI सलाह है। छिड़काव से पहले उत्पाद लेबल पढ़ें और स्थानीय कृषि अधिकारी से सलाह लें।',
    ],
    'not_plant_t': [
      'No crop found in photo',
      'ఫోటోలో పంట కనబడలేదు',
      'फोटो में फसल नहीं मिली'
    ],
    'not_plant_m': [
      'Point the camera at a leaf of your crop and try again.',
      'మీ పంట ఆకుపై కెమెరా ఉంచి మళ్లీ ప్రయత్నించండి.',
      'अपनी फसल की पत्ती पर कैमरा रखकर फिर से कोशिश करें।'
    ],
    'blurry_t': [
      'Photo is not clear',
      'ఫోటో స్పష్టంగా లేదు',
      'फोटो साफ नहीं है'
    ],
    'blurry_m': [
      'Move closer, use daylight and hold the phone steady.',
      'దగ్గరగా, పగటి వెలుతురులో, ఫోన్ కదలకుండా తీయండి.',
      'पास से, दिन की रोशनी में, फोन स्थिर रखकर फोटो लें।'
    ],
    'unsupported_t': [
      'This plant is not supported',
      'ఈ మొక్కకు సలహా అందుబాటులో లేదు',
      'इस पौधे के लिए सलाह उपलब्ध नहीं'
    ],
    'unsupported_m': [
      'The photo looks like {name}. Plant Doctor currently supports 24 major crops only.',
      'ఫోటోలో {name} ఉన్నట్లుంది. ప్రస్తుతం 24 ప్రధాన పంటలకు మాత్రమే సలహా ఇస్తాం.',
      'फोटो में {name} लगता है। अभी केवल 24 प्रमुख फसलों के लिए सलाह उपलब्ध है।'
    ],
    'unsupported_m2': [
      'Plant Doctor currently supports 24 major crops only.',
      'ప్రస్తుతం 24 ప్రధాన పంటలకు మాత్రమే సలహా ఇస్తాం.',
      'अभी केवल 24 प्रमुख फसलों के लिए सलाह उपलब्ध है।'
    ],
    'retake': ['Retake photo', 'మళ్లీ ఫోటో తీయండి', 'फिर से फोटो लें'],
    'change_crop': ['Change crop', 'పంట మార్చండి', 'फसल बदलें'],
    'saved_msg': [
      'Saved to your records',
      'మీ రికార్డులలో సేవ్ అయింది',
      'आपके रिकॉर्ड में सेव हुआ'
    ],
    'error_generic': [
      'Could not complete the diagnosis. Please try again.',
      'పరీక్ష పూర్తి కాలేదు. మళ్లీ ప్రయత్నించండి.',
      'जांच पूरी नहीं हो सकी। फिर से कोशिश करें।'
    ],
    'camera_error': [
      'Could not open camera or gallery.',
      'కెమెరా లేదా గ్యాలరీ తెరవలేకపోయాం.',
      'कैमरा या गैलरी नहीं खुल सकी।'
    ],
    'img_missing': [
      'Photo not found. Please take it again.',
      'ఫోటో కనబడలేదు. మళ్లీ తీయండి.',
      'फोटो नहीं मिली। फिर से लें।'
    ],
    'translating': ['Translating…', 'అనువదిస్తోంది…', 'अनुवाद हो रहा है…'],
    'share_crop': ['Crop', 'పంట', 'फसल'],
    'share_issue': ['Problem', 'సమస్య', 'समस्या'],
    'credits_title': [
      'Get more scans',
      'మరిన్ని పరీక్షలు పొందండి',
      'और जांच पाएं'
    ],
    'credits_desc': [
      'You have used today\'s free scans. Add 10 scans that never expire.',
      'ఈరోజు ఉచిత పరీక్షలు అయిపోయాయి. గడువు లేని 10 పరీక్షలు జోడించండి.',
      'आज की मुफ्त जांच खत्म। कभी समाप्त न होने वाली 10 जांच जोड़ें।'
    ],
    'credits_pack': ['10 scans', '10 పరీక్షలు', '10 जांच'],
    'credits_pay': [
      'Pay ₹{n} with UPI',
      'UPI ద్వారా ₹{n} చెల్లించండి',
      'UPI से ₹{n} भुगतान करें'
    ],
    'credits_added': [
      '10 scans added',
      '10 పరీక్షలు జోడించబడ్డాయి',
      '10 जांच जोड़ी गईं'
    ],
    'payment_failed': [
      'Payment was not completed.',
      'చెల్లింపు పూర్తి కాలేదు.',
      'भुगतान पूरा नहीं हुआ।'
    ],
  };

  String get _lang => context.locale.languageCode;

  String _t(String key, [Map<String, String> args = const {}]) {
    final v = _strings[key];
    if (v == null) return key;
    var s = _lang == 'te' ? v[1] : (_lang == 'hi' ? v[2] : v[0]);
    args.forEach((k, val) => s = s.replaceAll('{$k}', val));
    return s;
  }

  TextStyle _ts(double size,
          {FontWeight w = FontWeight.w400,
          Color c = _ink,
          double? h,
          FontStyle? style}) =>
      _plantTextStyle(_lang, size, w: w, c: c, h: h, style: style);

  _Stage _stage = _Stage.crop;
  Map<String, dynamic>? _selectedCrop;
  String _search = '';

  String? _imagePath;
  final ImagePicker _picker = ImagePicker();
  ImageSource? _pendingSource;
  String? _pendingImage;

  Map<String, dynamic>? _result;
  String? _resultLang;
  bool _translating = false;
  // Bumped on every new/loaded result so the treatment section resets to tab 0.
  int _treatmentEpoch = 0;
  int _loadingStep = 0;
  Timer? _loadingTimer;
  int _requestId = 0;

  bool _isSaved = false;
  late final bool _openedWithResult;

  late final TextToSpeechService _ttsService;
  bool _isPlayingAudio = false;

  CreditStatus? _creditStatus;
  late final RazorpayPaymentService _razorpayService;
  bool _isPaymentProcessing = false;

  List<SavedAdvisory> _recentDiagnoses = [];

  @override
  void initState() {
    super.initState();
    _ttsService = TextToSpeechService();
    _ttsService.currentSpeakingKey.addListener(_onTtsStateChanged);
    _razorpayService = RazorpayPaymentService();

    _openedWithResult = widget.preloadedResult != null;
    _pendingSource = widget.initialSource;
    _selectedCrop =
        _findCrop(id: widget.selectedCropId, name: widget.selectedCropName);

    if (widget.preloadedResult != null) {
      _result = Map<String, dynamic>.from(widget.preloadedResult!);
      _imagePath = widget.imagePath;
      _selectedCrop ??=
          _findCrop(name: _result!['detected_crop_name']?.toString());
      _stage = _Stage.result;
      _checkIfSaved();
    } else {
      _pendingImage = widget.imagePath;
    }

    _loadCreditStatus();
    _loadRecentDiagnoses();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = context.locale.languageCode;
    if (_result != null && _stage == _Stage.result && _resultLang != lang) {
      _ttsService.stop();
      // Defer: setState is not allowed during didChangeDependencies.
      scheduleMicrotask(() => _localizeResult(lang));
    }
  }

  void _onTtsStateChanged() {
    if (mounted)
      setState(
          () => _isPlayingAudio = _ttsService.currentSpeakingKey.value != null);
  }

  @override
  void dispose() {
    _requestId++;
    _loadingTimer?.cancel();
    _ttsService.currentSpeakingKey.removeListener(_onTtsStateChanged);
    _ttsService.stop();
    _razorpayService.dispose();
    super.dispose();
  }

  // ===========================================================================
  // DATA
  // ===========================================================================

  Map<String, dynamic>? _findCrop({int? id, String? name}) {
    for (final c in PlantDoctorScreen.supportedCrops) {
      if (id != null && c['id'] == id) return c;
    }
    final n = name?.trim().toLowerCase() ?? '';
    if (n.isEmpty) return null;
    for (final c in PlantDoctorScreen.supportedCrops) {
      for (final k in ['name_en', 'name_te', 'name_hi']) {
        final v = (c[k] as String).toLowerCase();
        if (n == v || n.contains(v) || (n.length >= 3 && v.contains(n)))
          return c;
      }
    }
    if (n.contains('rice')) return PlantDoctorScreen.supportedCrops.first;
    return null;
  }

  String _cropLabel(Map<String, dynamic> c) => (_lang == 'te'
      ? c['name_te']
      : (_lang == 'hi' ? c['name_hi'] : c['name_en'])) as String;

  Future<void> _loadCreditStatus() async {
    final status = await AiCreditService.getCreditStatus();
    if (mounted) setState(() => _creditStatus = status);
  }

  Future<void> _loadRecentDiagnoses() async {
    final list = await SavedAdvisoriesService.getSavedAdvisories();
    if (mounted) setState(() => _recentDiagnoses = list);
  }

  String get _displayCropName {
    if (_selectedCrop != null) return _cropLabel(_selectedCrop!);
    return _result?['detected_crop_name']?.toString() ?? '';
  }

  String get _displayProblemName {
    final res = _result;
    if (res == null) return '';
    if (res['health_status']?.toString() == 'healthy')
      return _t('healthy_title');
    final local = res['matched_problem_name']?.toString().trim() ?? '';
    if (local.isNotEmpty && local.toLowerCase() != 'null') return local;
    final en = res['problem_name_en']?.toString().trim() ?? '';
    return en.isNotEmpty ? en : _t('status_${_normalizedStatus(res)}');
  }

  String _normalizedStatus(Map<String, dynamic> res) {
    final s = res['health_status']?.toString().toLowerCase() ?? 'unknown';
    return const {'healthy', 'diseased', 'pest_infestation', 'deficiency'}
            .contains(s)
        ? s
        : 'unknown';
  }

  Future<void> _checkIfSaved() async {
    if (_result == null) return;
    final saved = await SavedAdvisoriesService.isAdvisorySaved(
        _displayProblemName,
        cropName: _displayCropName);
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _localizeResult(String lang) async {
    final current = _result;
    if (!mounted || current == null) return;
    _resultLang = lang;
    if (!DeepSeekPlantDoctorService.needsTranslation(current, lang)) return;

    setState(() => _translating = true);
    final out =
        await DeepSeekPlantDoctorService.translateDiagnosis(current, lang);
    if (!mounted || _resultLang != lang) return;
    setState(() {
      if (identical(current, _result)) _result = out;
      _translating = false;
    });
    _checkIfSaved();
  }

  // ===========================================================================
  // FLOW
  // ===========================================================================

  void _onCropTap(Map<String, dynamic> crop) {
    HapticFeedback.selectionClick();
    setState(() => _selectedCrop = crop);

    if (_pendingImage != null) {
      final p = _pendingImage!;
      _pendingImage = null;
      _analyse(p);
    } else if (_pendingSource != null) {
      final s = _pendingSource!;
      _pendingSource = null;
      _pickImage(s);
    } else {
      _showPhotoSheet();
    }
  }

  void _goToCropStage() {
    _ttsService.stop();
    _requestId++;
    _loadingTimer?.cancel();
    setState(() {
      _stage = _Stage.crop;
      _result = null;
      _imagePath = null;
      _existsPath = null;
      _translating = false;
      _isSaved = false;
    });
    _loadRecentDiagnoses();
  }

  Future<void> _pickImage(ImageSource source) async {
    _ttsService.stop();
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (file != null && mounted) _analyse(file.path);
    } catch (_) {
      _snack(_t('camera_error'), error: true);
    }
  }

  Future<void> _analyse(String path) async {
    final crop = _selectedCrop;
    if (crop == null) return;
    final lang = _lang;

    if (!await File(path).exists()) {
      _snack(_t('img_missing'), error: true);
      return;
    }
    if (!await AiCreditService.canPerformAnalysis()) {
      if (mounted) _showPurchaseCreditsModal(onSuccess: () => _analyse(path));
      return;
    }
    if (!mounted) return;

    final reqId = ++_requestId;
    setState(() {
      _imagePath = path;
      _existsPath = null;
      _stage = _Stage.analysing;
      _loadingStep = 0;
      _result = null;
      _isSaved = false;
      _treatmentEpoch++;
    });

    _loadingTimer?.cancel();
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (mounted) setState(() => _loadingStep = (_loadingStep + 1) % 4);
    });

    try {
      final cropId = crop['id'] as int;
      final problemsFuture = ApiService.getProblems(cropId: cropId, lang: lang);
      final positionFuture = LocationService.getCurrentPosition()
          .timeout(const Duration(seconds: 6), onTimeout: () => null);
      final problems = await problemsFuture;
      final position = await positionFuture;

      final result = await DeepSeekPlantDoctorService.diagnoseCrop(
        imageFile: File(path),
        latitude: position?.latitude,
        longitude: position?.longitude,
        language: lang,
        selectedCropId: cropId,
        selectedCropName: crop['name_en'] as String,
        knownProblems: problems
            .map((p) => {
                  'id': p['id'],
                  'name': p['name'],
                  'name_en': p['name_en'],
                  'category': p['category']
                })
            .toList(),
        forceFresh: true,
      );

      if (!mounted || reqId != _requestId) return;

      // Don't charge for photos we could not use.
      if (result['is_plant'] != false && result['is_clear_image'] != false) {
        await AiCreditService.consumeCredit();
        _loadCreditStatus();
      }
      if (!mounted || reqId != _requestId) return;

      setState(() {
        _result = result;
        _resultLang = lang;
        _stage = _Stage.result;
      });
      if (_lang != lang) _localizeResult(_lang);
      _checkIfSaved();
    } catch (e) {
      if (!mounted || reqId != _requestId) return;
      setState(() => _stage = _Stage.crop);
      _snack(e is DeepSeekException ? e.message : _t('error_generic'),
          error: true);
    } finally {
      if (reqId == _requestId) _loadingTimer?.cancel();
    }
  }

  void _cancelAnalysis() {
    HapticFeedback.lightImpact();
    _requestId++;
    _loadingTimer?.cancel();
    setState(() => _stage = _Stage.crop);
  }

  void _openSaved(SavedAdvisory adv) {
    HapticFeedback.selectionClick();
    _ttsService.stop();
    setState(() {
      _result = adv.toDiagnosisMap();
      _resultLang = null;
      _imagePath = adv.imagePath;
      _existsPath = null;
      _selectedCrop = _findCrop(name: adv.cropName);
      _stage = _Stage.result;
      _treatmentEpoch++;
      _isSaved = true;
    });
    _localizeResult(_lang);
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? const Color(0xFFB91C1C) : _ink,
    ));
  }

  // ===========================================================================
  // ACTIONS ON RESULT
  // ===========================================================================

  List<String> _list(dynamic v) => v is List
      ? v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
      : <String>[];

  // File.existsSync() is a sync disk hit; cache it per image path instead of
  // calling it on every build.
  String? _existsPath;
  bool _existsValue = false;
  bool get _hasImage {
    final path = _imagePath;
    if (path == null) return false;
    if (path != _existsPath) {
      _existsPath = path;
      _existsValue = File(path).existsSync();
    }
    return _existsValue;
  }

  // Prevention list is derived from the result; rebuild only when it changes.
  Map<String, dynamic>? _preventionFor;
  List<String> _preventionCache = const [];
  List<String> _preventionOf(Map<String, dynamic> res) {
    if (!identical(_preventionFor, res)) {
      _preventionFor = res;
      _preventionCache = <String>{
        ..._controls['preventative']!,
        ..._list(res['recovery_recommendations'])
      }.toList();
    }
    return _preventionCache;
  }

  Map<String, List<String>> get _controls {
    final c = _result?['ai_control_measures'];
    final m = c is Map ? c : const {};
    return {
      'chemical': _list(m['chemical']),
      'biological': _list(m['biological']),
      'preventative': _list(m['preventative']),
    };
  }

  void _toggleAudio() async {
    final res = _result;
    if (res == null) return;
    HapticFeedback.selectionClick();
    if (_isPlayingAudio) {
      await _ttsService.stop();
      return;
    }
    final isHealthy = res['health_status']?.toString() == 'healthy';
    final c = _controls;
    final parts = <String>[
      isHealthy
          ? _t('healthy_title')
          : '$_displayCropName: $_displayProblemName',
      if ((res['ai_analysis']?.toString() ?? '').isNotEmpty)
        res['ai_analysis'].toString(),
      if (c['chemical']!.isNotEmpty)
        '${_t('tab_chem')}: ${c['chemical']!.first}',
      if (c['biological']!.isNotEmpty)
        '${_t('tab_bio')}: ${c['biological']!.first}',
    ];
    await _ttsService.toggleSpeakSection(
        sectionKey: 'doctor_summary',
        text: parts.join('. '),
        languageCode: _lang);
  }

  Future<void> _toggleSave() async {
    final res = _result;
    if (res == null) return;
    HapticFeedback.selectionClick();
    final problem = _displayProblemName;
    final crop = _displayCropName;

    if (_isSaved) {
      final list = await SavedAdvisoriesService.getSavedAdvisories();
      for (final item in list) {
        if (item.problemName.trim().toLowerCase() ==
                problem.trim().toLowerCase() &&
            (item.cropName ?? '').trim().toLowerCase() ==
                crop.trim().toLowerCase()) {
          await SavedAdvisoriesService.deleteAdvisory(item.id);
          break;
        }
      }
      if (mounted) setState(() => _isSaved = false);
    } else {
      final c = _controls;
      await SavedAdvisoriesService.saveAdvisory(
        cropName: crop,
        problemName: problem,
        problemNameEn: res['problem_name_en']?.toString(),
        healthStatus: _normalizedStatus(res),
        confidence: ((res['confidence'] as num? ?? 0.7) * 100).round(),
        sourceImagePath: _imagePath,
        summary: res['ai_analysis']?.toString() ?? '',
        weatherImpact: res['weather_impact']?.toString(),
        chemicalControls: c['chemical']!,
        biologicalControls: c['biological']!,
        preventativeControls: c['preventative']!,
        symptoms: _list(res['observed_symptoms']),
        recoveryTips: _list(res['recovery_recommendations']),
        matchedProblemId: SafeParser.toNullableInt(res['matched_problem_id']),
      );
      if (mounted) {
        setState(() => _isSaved = true);
        _snack(_t('saved_msg'));
      }
    }
  }

  void _share() {
    final res = _result;
    if (res == null) return;
    HapticFeedback.selectionClick();
    final c = _controls;
    final b = StringBuffer()
      ..writeln('🌱 CropSync ${_t('title')}')
      ..writeln('${_t('share_crop')}: $_displayCropName')
      ..writeln('${_t('share_issue')}: $_displayProblemName');
    final analysis = res['ai_analysis']?.toString() ?? '';
    if (analysis.isNotEmpty) b.writeln('\n$analysis');
    if (c['chemical']!.isNotEmpty) {
      b.writeln('\n${_t('tab_chem')}:');
      for (final s in c['chemical']!) {
        b.writeln('• $s');
      }
    }
    if (c['biological']!.isNotEmpty) {
      b.writeln('\n${_t('tab_bio')}:');
      for (final s in c['biological']!) {
        b.writeln('• $s');
      }
    }
    b.writeln('\n— CropSync');

    final hasImage = _hasImage;
    SharePlus.instance.share(ShareParams(
      files: hasImage ? [XFile(_imagePath!)] : null,
      text: b.toString(),
      subject: 'CropSync: $_displayProblemName',
    ));
  }

  Future<void> _callHelpline() async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse('tel:18001801551');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  bool get _canPop =>
      _stage == _Stage.crop || (_openedWithResult && _stage == _Stage.result);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _ttsService.stop();
          return;
        }
        if (_stage == _Stage.analysing) {
          _cancelAnalysis();
        } else {
          _goToCropStage();
        }
      },
      child: Scaffold(
        backgroundColor: _stage == _Stage.result ? Colors.white : _bg,
        appBar: AppBar(
          backgroundColor: _stage == _Stage.result ? Colors.white : _bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: _ink),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(_t('title'), style: _ts(18, w: FontWeight.w700)),
          actions: [
            const LanguageButton.pill(color: _ink),
            IconButton(
              icon: const Icon(Icons.history_rounded, color: _ink),
              tooltip: _t('recent'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SavedAdvisoriesScreen()),
              ).then((_) => _loadRecentDiagnoses()),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey(_stage),
            child: switch (_stage) {
              _Stage.crop => _buildCropStage(),
              _Stage.analysing => _buildAnalysing(),
              _Stage.result => _buildResult(),
            },
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // STAGE 1: CROP SELECTION
  // ===========================================================================

  Widget _buildCropStage() {
    final q = _search.trim().toLowerCase();
    final crops = PlantDoctorScreen.supportedCrops.where((c) {
      if (q.isEmpty) return true;
      return ['name_en', 'name_te', 'name_hi']
          .any((k) => (c[k] as String).toLowerCase().contains(q));
    }).toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('pick_crop_title'),
                    style: _ts(24, w: FontWeight.w700, h: 1.2)),
                const SizedBox(height: 6),
                Text(_t('pick_crop_sub'), style: _ts(14, c: _muted, h: 1.4)),
                if (_creditStatus != null) ...[
                  const SizedBox(height: 12),
                  _buildCreditsPill(),
                ],
                const SizedBox(height: 18),
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: _ts(15),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: _t('search'),
                    hintStyle: _ts(15, c: const Color(0xFF9CA3AF)),
                    prefixIcon: const Icon(Icons.search_rounded, color: _muted),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _line)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _line)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: _green, width: 1.5)),
                  ),
                ),
                if (_recentDiagnoses.isNotEmpty && q.isEmpty) ...[
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                          child: Text(_t('recent'),
                              style: _ts(15, w: FontWeight.w700))),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SavedAdvisoriesScreen()),
                        ).then((_) => _loadRecentDiagnoses()),
                        style: TextButton.styleFrom(
                            foregroundColor: _green,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(48, 36)),
                        child: Text(_t('view_all'),
                            style: _ts(13, w: FontWeight.w600, c: _green)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _recentDiagnoses.length.clamp(0, 6),
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) =>
                          _buildRecentChip(_recentDiagnoses[i]),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
        if (crops.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                  child: Text(_t('no_crop_found'), style: _ts(14, c: _muted))),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final c = crops[i];
                  return _CropTile(
                    crop: c,
                    label: _cropLabel(c),
                    subLabel: _lang == 'en' ? null : c['name_en'] as String,
                    selected: _selectedCrop?['id'] == c['id'],
                    onTap: () => _onCropTap(c),
                  );
                },
                childCount: crops.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCreditsPill() {
    final n = _creditStatus!.totalAvailable;
    return InkWell(
      onTap: n == 0 ? () => _showPurchaseCreditsModal() : null,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: _greenSoft, borderRadius: BorderRadius.circular(100)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, size: 15, color: _green),
            const SizedBox(width: 4),
            Text(_t('scans_left', {'n': '$n'}),
                style: _ts(12.5, w: FontWeight.w600, c: _green)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentChip(SavedAdvisory adv) {
    final hasImage = adv.imagePath != null && File(adv.imagePath!).existsSync();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _openSaved(adv),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 210,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _line)),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: hasImage
                      ? Image.file(File(adv.imagePath!),
                          fit: BoxFit.cover, cacheWidth: 140)
                      : Container(
                          color: _greenSoft,
                          child: const Icon(Icons.eco_rounded, color: _green)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(adv.problemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _ts(13, w: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${adv.cropName ?? ''} · ${DateFormat('d MMM').format(adv.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _ts(11.5, c: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhotoSheet() {
    final crop = _selectedCrop;
    if (crop == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                        width: 40,
                        height: 40,
                        child: _CropImage(crop: crop, emojiSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(_cropLabel(crop),
                          style: _ts(16, w: FontWeight.w700))),
                  TextButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    style: TextButton.styleFrom(foregroundColor: _green),
                    child: Text(_t('change'),
                        style: _ts(13.5, w: FontWeight.w600, c: _green)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(_t('photo_title'), style: _ts(20, w: FontWeight.w700)),
              const SizedBox(height: 12),
              _tipRow(Icons.crop_free_rounded, _t('tip1')),
              _tipRow(Icons.wb_sunny_outlined, _t('tip2')),
              _tipRow(Icons.back_hand_outlined, _t('tip3')),
              const SizedBox(height: 20),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    _pickImage(ImageSource.camera);
                  },
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: Text(_t('camera'),
                      style: _ts(16, w: FontWeight.w600, c: Colors.white)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    _pickImage(ImageSource.gallery);
                  },
                  icon: const Icon(Icons.photo_library_outlined, color: _ink),
                  label:
                      Text(_t('gallery'), style: _ts(16, w: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _line),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tipRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _green),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text, style: _ts(14, c: const Color(0xFF374151)))),
        ],
      ),
    );
  }

  // ===========================================================================
  // STAGE 2: ANALYSING
  // ===========================================================================

  Widget _buildAnalysing() {
    final steps = [_t('load1'), _t('load2'), _t('load3'), _t('load4')];
    final hasImage = _hasImage;

    return SafeArea(
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (hasImage)
                              Image.file(File(_imagePath!),
                                  fit: BoxFit.cover, cacheWidth: 600)
                            else
                              Container(color: _greenSoft),
                            Container(
                                color: Colors.black.withValues(alpha: 0.15)),
                            const _ScanLine(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(_t('analysing'),
                        textAlign: TextAlign.center,
                        style: _ts(20, w: FontWeight.w700)),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        steps[_loadingStep % steps.length],
                        key: ValueKey(_loadingStep),
                        textAlign: TextAlign.center,
                        style: _ts(14, c: _muted),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SizedBox(
                        width: 160,
                        child: LinearProgressIndicator(
                            minHeight: 3,
                            color: _green,
                            backgroundColor: _line)),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: TextButton(
                onPressed: _cancelAnalysis,
                style: TextButton.styleFrom(
                    foregroundColor: _muted, minimumSize: const Size(120, 48)),
                child: Text(_t('cancel'),
                    style: _ts(15, w: FontWeight.w600, c: _muted)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STAGE 3: RESULT
  // ===========================================================================

  Widget _buildResult() {
    final res = _result;
    if (res == null) return const SizedBox.shrink();

    final isPlant = res['is_plant'] != false;
    final isClear = res['is_clear_image'] != false;
    final isSupported = res['is_crop_supported'] != false;
    if (!isPlant || !isClear || !isSupported) {
      return _buildWarning(isPlant: isPlant, isClear: isClear, res: res);
    }

    final status = _normalizedStatus(res);
    final isHealthy = status == 'healthy';
    final severity = res['severity_level']?.toString() ?? 'moderate';
    final confidence =
        ((res['confidence'] as num? ?? 0.7) * 100).round().clamp(0, 100);
    final analysis = res['ai_analysis']?.toString().trim() ?? '';
    final weather = res['weather_impact']?.toString().trim() ?? '';
    final symptoms = _list(res['observed_symptoms']);
    final enName = res['problem_name_en']?.toString().trim() ?? '';
    final sciName = res['scientific_name']?.toString().trim() ?? '';
    final verified = res['official_database_verified'] == true;
    final c = _controls;
    final prevention = _preventionOf(res);
    final statusColor = _statusColor(status);
    final hasImage = _hasImage;

    return Column(
      children: [
        if (_translating)
          const LinearProgressIndicator(
              minHeight: 2, color: _green, backgroundColor: _greenSoft),
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              if (hasImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(_imagePath!),
                          fit: BoxFit.cover,
                          cacheWidth: 1000,
                          errorBuilder: (_, __, ___) =>
                              Container(color: _greenSoft),
                        ),
                        if (_displayCropName.isNotEmpty)
                          Positioned(
                            left: 12,
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(_displayCropName,
                                  style: _ts(12.5,
                                      w: FontWeight.w600, c: Colors.white)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // Status + severity
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _pill(_t('status_$status'), statusColor),
                  if (!isHealthy &&
                      const {'mild', 'moderate', 'severe'}.contains(severity))
                    _pill(_t('sev_$severity'),
                        severity == 'severe' ? const Color(0xFFB91C1C) : _muted,
                        outlined: true),
                  if (verified)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded,
                            size: 15, color: _green),
                        const SizedBox(width: 3),
                        Text(_t('verified'),
                            style: _ts(12, w: FontWeight.w600, c: _green)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(_displayProblemName,
                  style: _ts(26, w: FontWeight.w700, h: 1.2)),
              if (!isHealthy && (enName.isNotEmpty || sciName.isNotEmpty)) ...[
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(children: [
                    if (enName.isNotEmpty &&
                        enName.toLowerCase() !=
                            _displayProblemName.toLowerCase())
                      TextSpan(text: enName),
                    if (enName.isNotEmpty &&
                        enName.toLowerCase() !=
                            _displayProblemName.toLowerCase() &&
                        sciName.isNotEmpty &&
                        sciName.toLowerCase() != 'null')
                      const TextSpan(text: '  ·  '),
                    if (sciName.isNotEmpty && sciName.toLowerCase() != 'null')
                      TextSpan(
                          text: sciName,
                          style: const TextStyle(fontStyle: FontStyle.italic)),
                  ]),
                  style: _ts(14, c: _muted),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('${_t('confidence')} $confidence%',
                      style: _ts(12.5, w: FontWeight.w600, c: _muted)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: confidence / 100,
                        minHeight: 5,
                        color: statusColor,
                        backgroundColor: const Color(0xFFF3F4F6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Quick actions
              Row(
                children: [
                  Expanded(
                      child: _actionButton(
                          _isPlayingAudio
                              ? Icons.stop_rounded
                              : Icons.volume_up_rounded,
                          _isPlayingAudio ? _t('stop') : _t('listen'),
                          _toggleAudio,
                          active: _isPlayingAudio)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _actionButton(
                          _isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          _isSaved ? _t('saved') : _t('save'),
                          _toggleSave,
                          active: _isSaved)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _actionButton(
                          Icons.ios_share_rounded, _t('share'), _share)),
                ],
              ),

              if (analysis.isNotEmpty) ...[
                _sectionTitle(_t('summary')),
                Text(analysis,
                    style: _ts(15, h: 1.55, c: const Color(0xFF374151))),
              ],

              if (symptoms.isNotEmpty) ...[
                _sectionTitle(_t('symptoms')),
                ...symptoms.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(s,
                                  style: _ts(14.5,
                                      h: 1.45, c: const Color(0xFF374151)))),
                        ],
                      ),
                    )),
              ],

              if (weather.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.water_drop_outlined,
                          color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_t('weather'),
                                style: _ts(13.5,
                                    w: FontWeight.w700,
                                    c: const Color(0xFF1E3A8A))),
                            const SizedBox(height: 3),
                            Text(weather,
                                style: _ts(14,
                                    h: 1.45, c: const Color(0xFF1E40AF))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (isHealthy) ...[
                if (prevention.isNotEmpty) ...[
                  _sectionTitle(_t('care')),
                  _numberedList(prevention, _green),
                ],
              ] else ...[
                _sectionTitle(_t('treatment')),
                _TreatmentSection(
                  key: ValueKey(_treatmentEpoch),
                  lang: _lang,
                  labels: [_t('tab_chem'), _t('tab_bio'), _t('tab_prev')],
                  lists: [c['chemical']!, c['biological']!, prevention],
                  accents: const [
                    Color(0xFF0369A1),
                    _green,
                    Color(0xFFB45309),
                  ],
                  listBuilder: _numberedList,
                ),
              ],

              const SizedBox(height: 28),
              if (!isHealthy) ...[
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AgriShopScreen()));
                    },
                    icon: const Icon(Icons.storefront_outlined),
                    label: Text(_t('buy'),
                        style: _ts(15.5, w: FontWeight.w600, c: Colors.white)),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _callHelpline,
                        icon: const Icon(Icons.call_outlined,
                            size: 18, color: _ink),
                        label: Text(_t('helpline'),
                            style: _ts(14, w: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _line),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _goToCropStage,
                        icon: const Icon(Icons.add_a_photo_outlined,
                            size: 18, color: _ink),
                        label: Text(_t('new_scan'),
                            style: _ts(14, w: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _line),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(_t('disclaimer'),
                  textAlign: TextAlign.center,
                  style: _ts(12, c: const Color(0xFF9CA3AF), h: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'healthy':
        return _green;
      case 'diseased':
        return const Color(0xFFDC2626);
      case 'pest_infestation':
        return const Color(0xFFEA580C);
      case 'deficiency':
        return const Color(0xFFD97706);
      default:
        return _muted;
    }
  }

  Widget _pill(String text, Color color, {bool outlined = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: outlined ? Border.all(color: _line) : null,
      ),
      child: Text(text, style: _ts(12.5, w: FontWeight.w600, c: color)),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 10),
        child: Text(text, style: _ts(17, w: FontWeight.w700)),
      );

  Widget _actionButton(IconData icon, String label, VoidCallback onTap,
      {bool active = false}) {
    return Material(
      color: active ? _greenSoft : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: active ? _green : _ink),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ts(13.5,
                        w: FontWeight.w600, c: active ? _green : _ink)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numberedList(List<String> items, Color accent) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(_t('empty_list'), style: _ts(14, c: _muted)),
      );
    }
    return Column(
      children: List.generate(items.length, (i) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: i == items.length - 1
                ? null
                : const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: Text('${i + 1}',
                    style: _ts(12, w: FontWeight.w700, c: accent)),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(items[i],
                      style: _ts(14.5, h: 1.5, c: const Color(0xFF1F2937)))),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildWarning(
      {required bool isPlant,
      required bool isClear,
      required Map<String, dynamic> res}) {
    String title;
    String message;
    IconData icon;
    if (!isPlant) {
      title = _t('not_plant_t');
      message = _t('not_plant_m');
      icon = Icons.image_search_rounded;
    } else if (!isClear) {
      title = _t('blurry_t');
      message = _t('blurry_m');
      icon = Icons.blur_on_rounded;
    } else {
      final name =
          (res['unsupported_crop_name'] ?? res['detected_crop_name'] ?? '')
              .toString();
      title = _t('unsupported_t');
      message = name.isEmpty
          ? _t('unsupported_m2')
          : _t('unsupported_m', {'name': name});
      icon = Icons.eco_outlined;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                    color: Color(0xFFFEF3C7), shape: BoxShape.circle),
                child: Icon(icon, size: 34, color: const Color(0xFFB45309)),
              ),
            ),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center,
                style: _ts(20, w: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: _ts(14.5, c: _muted, h: 1.5)),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed:
                    _selectedCrop != null ? _showPhotoSheet : _goToCropStage,
                icon: const Icon(Icons.photo_camera_rounded),
                label: Text(_t('retake'),
                    style: _ts(15.5, w: FontWeight.w600, c: Colors.white)),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _goToCropStage,
              style: TextButton.styleFrom(
                  foregroundColor: _ink, minimumSize: const Size(0, 48)),
              child:
                  Text(_t('change_crop'), style: _ts(15, w: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // CREDITS
  // ===========================================================================

  void _showPurchaseCreditsModal({VoidCallback? onSuccess}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_t('credits_title'), style: _ts(20, w: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(_t('credits_desc'), style: _ts(14, c: _muted, h: 1.45)),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _greenSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: _green),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_t('credits_pack'),
                              style: _ts(16, w: FontWeight.w700))),
                      Text('₹${AiCreditService.costPerPurchaseInr}',
                          style: _ts(18, w: FontWeight.w700, c: _green)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _isPaymentProcessing
                        ? null
                        : () => _triggerRazorpayPurchase(
                            sheetCtx, setModalState, onSuccess),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isPaymentProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            _t('credits_pay',
                                {'n': '${AiCreditService.costPerPurchaseInr}'}),
                            style:
                                _ts(15.5, w: FontWeight.w600, c: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted && _isPaymentProcessing)
        setState(() => _isPaymentProcessing = false);
    });
  }

  Future<void> _triggerRazorpayPurchase(
    BuildContext sheetCtx,
    void Function(void Function()) setModalState,
    VoidCallback? onSuccess,
  ) async {
    final phone = await RazorpayPaymentService.resolveUserPhoneNumber();
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ??
        prefs.getString('userId') ??
        (phone.isNotEmpty ? phone : 'guest_farmer');
    final email = prefs.getString('email') ?? '';

    if (!mounted) return;
    setState(() => _isPaymentProcessing = true);
    if (sheetCtx.mounted) setModalState(() {});

    await _razorpayService.purchaseCredits(
      amountInr: AiCreditService.costPerPurchaseInr,
      userId: userId,
      userPhone: phone,
      userEmail: email,
      description: "10 AI Crop Doctor Scans",
      onResult: (result) async {
        if (!mounted) return;
        setState(() => _isPaymentProcessing = false);
        if (sheetCtx.mounted) setModalState(() {});

        if (result.isSuccess) {
          await AiCreditService.addPurchasedCredits(
            result.creditsAdded ?? AiCreditService.creditsPerPurchase,
            userId: userId,
            paymentId: result.paymentId,
          );
          await _loadCreditStatus();
          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
          _snack(_t('credits_added'));
          onSuccess?.call();
        } else {
          _snack(_t('payment_failed'), error: true);
        }
      },
    );
  }
}

// =============================================================================
// WIDGETS
// =============================================================================

class _CropImage extends StatelessWidget {
  final Map<String, dynamic> crop;
  final double emojiSize;
  const _CropImage({required this.crop, this.emojiSize = 34});

  @override
  Widget build(BuildContext context) {
    final color = crop['color'] as Color;
    final fallback = Container(
      color: color.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child:
          Text(crop['emoji'] as String, style: TextStyle(fontSize: emojiSize)),
    );
    return CachedNetworkImage(
      imageUrl: crop['image_url'] as String,
      fit: BoxFit.cover,
      memCacheWidth: 300,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
  }
}

/// Text style for the screen. Google Sans has no Telugu glyphs, so Telugu uses
/// Tiro Telugu instead of the app-wide Noto Sans Telugu fallback.
TextStyle _plantTextStyle(String lang, double size,
    {FontWeight w = FontWeight.w400,
    Color c = _ink,
    double? h,
    FontStyle? style}) {
  // GoogleFonts lookups are not free; memoize per distinct style.
  final key = '${lang == 'te'}|$size|${w.value}|${c.toARGB32()}|$h|$style';
  return _plantTextStyleCache.putIfAbsent(
      key, () => _buildPlantTextStyle(lang, size, w, c, h, style));
}

final Map<String, TextStyle> _plantTextStyleCache = {};

TextStyle _buildPlantTextStyle(String lang, double size, FontWeight w, Color c,
    double? h, FontStyle? style) {
  if (lang == 'te') {
    // Tiro Telugu ships only a regular weight (plus italic); the requested
    // weight is passed through so Flutter synthesises bold for headings.
    return GoogleFonts.tiroTelugu(
        fontSize: size,
        fontWeight: w,
        color: c,
        // Taller default line height so Telugu glyphs don't clip.
        height: h ?? 1.5,
        fontStyle: style);
  }
  return GoogleFonts.googleSans(
      fontSize: size, fontWeight: w, color: c, height: h, fontStyle: style);
}

/// Treatment pills + content. Holds the selected tab locally so a tap only
/// rebuilds this subtree instead of the whole result screen.
class _TreatmentSection extends StatefulWidget {
  final String lang;
  final List<String> labels;
  final List<List<String>> lists;
  final List<Color> accents;
  final Widget Function(List<String> items, Color accent) listBuilder;
  const _TreatmentSection({
    super.key,
    required this.lang,
    required this.labels,
    required this.lists,
    required this.accents,
    required this.listBuilder,
  });

  @override
  State<_TreatmentSection> createState() => _TreatmentSectionState();
}

class _TreatmentSectionState extends State<_TreatmentSection> {
  int _tab = 0;

  static const _slide = Duration(milliseconds: 220);

  Widget _segmented() {
    final n = widget.labels.length;
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          height: 40,
          child: Stack(
            children: [
              // Sliding white pill behind the labels.
              AnimatedAlign(
                duration: _slide,
                curve: Curves.easeOutCubic,
                alignment: Alignment(n <= 1 ? 0 : -1 + 2 * _tab / (n - 1), 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 1))
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: List.generate(n, (i) {
                  final sel = _tab == i;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_tab == i) return;
                        HapticFeedback.selectionClick();
                        setState(() => _tab = i);
                      },
                      child: Center(
                        // Constant weight so the label width never reflows.
                        child: AnimatedDefaultTextStyle(
                          duration: _slide,
                          curve: Curves.easeOutCubic,
                          style: _plantTextStyle(widget.lang, 13.5,
                              w: FontWeight.w600, c: sel ? _ink : _muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          child: Text(widget.labels[i]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tab = _tab.clamp(0, widget.lists.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _segmented(),
        const SizedBox(height: 14),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            // Outgoing child is pinned to the top and doesn't contribute to
            // the height, so the section never jumps mid-fade.
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [
                for (final p in previous)
                  Positioned(top: 0, left: 0, right: 0, child: p),
                if (current != null) current,
              ],
            ),
            child: KeyedSubtree(
              key: ValueKey(tab),
              child: widget.listBuilder(widget.lists[tab], widget.accents[tab]),
            ),
          ),
        ),
      ],
    );
  }
}

class _CropTile extends StatelessWidget {
  final Map<String, dynamic> crop;
  final String label;
  final String? subLabel;
  final bool selected;
  final VoidCallback onTap;

  const _CropTile({
    required this.crop,
    required this.label,
    required this.subLabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: selected ? _green : _line, width: selected ? 2 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _CropImage(crop: crop),
                          if (selected)
                            const Positioned(
                              top: 6,
                              right: 6,
                              child: CircleAvatar(
                                radius: 11,
                                backgroundColor: _green,
                                child: Icon(Icons.check_rounded,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                  child: Column(
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: _plantTextStyle(
                            context.locale.languageCode, 13.5,
                            w: FontWeight.w600),
                      ),
                      if (subLabel != null)
                        Text(
                          subLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: _plantTextStyle(
                              context.locale.languageCode, 11,
                              c: _muted),
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
}

class _ScanLine extends StatefulWidget {
  const _ScanLine();

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Align(
        alignment: Alignment(0, -1 + 2 * Curves.easeInOut.transform(_c.value)),
        child: Container(
          height: 3,
          decoration: BoxDecoration(
            color: const Color(0xFF4ADE80),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF4ADE80).withValues(alpha: 0.7),
                  blurRadius: 12,
                  spreadRadius: 2)
            ],
          ),
        ),
      ),
    );
  }
}
