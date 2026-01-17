// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

// ============================================================================
// DESIGN SYSTEM - Matching Web CSS Variables
// ============================================================================
class CHCTheme {
  static const primary = Color(0xFF00A699);
  static const primaryDark = Color(0xFF008C81);
  static const accent = Color(0xFFFF385C);
  static const bg = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A1A);
  static const border = Color(0xFFE0E0E0);
  static const warning = Color(0xFF856404);
  static const warningBg = Color(0xFFFFF3CD);
  static const errorBg = Color(0xFFFFEBEE);
  static const errorText = Color(0xFFC62828);
  static const memberBadge = Color(0xFFFFD700);
}

// ============================================================================
// EQUIPMENT MODEL - Dynamic from Database
// ============================================================================
class Equipment {
  final int id;
  final String nameEn;
  final String? nameTe;
  final String image;
  final String? description;
  final double priceMember;
  final double priceNonMember;
  final double displayPrice;
  final String unit;
  final int quantity;

  Equipment({
    required this.id,
    required this.nameEn,
    this.nameTe,
    required this.image,
    this.description,
    required this.priceMember,
    required this.priceNonMember,
    required this.displayPrice,
    required this.unit,
    required this.quantity,
  });

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: int.tryParse(json['id'].toString()) ?? 0,
      nameEn: json['name_en'] ?? '',
      nameTe: json['name_te'],
      image: json['image'] ?? '',
      description: json['description'],
      priceMember: double.tryParse(json['price_member'].toString()) ?? 0,
      priceNonMember: double.tryParse(json['price_non_member'].toString()) ?? 0,
      displayPrice: double.tryParse(json['display_price'].toString()) ?? 0,
      unit: json['unit'] ?? 'Acre',
      quantity: int.tryParse(json['quantity'].toString()) ?? 0,
    );
  }

  // Check if this equipment requires crop selection (Drone or Spray)
  bool get requiresCropSelection {
    return nameEn.toLowerCase().contains('drone') ||
        nameEn.toLowerCase().contains('spray');
  }

  // Check if this is a trolley (needs 5km warning)
  bool get isTrolley {
    return unit == 'Trip' || nameEn.toLowerCase().contains('trolley');
  }

  // Get billing type based on unit
  String get billingType => unit == 'Acre' ? 'Fixed' : 'Variable';

  // Get booking status based on billing type and equipment type
  String getBookingStatus() {
    if (billingType == 'Variable') {
      return 'Slot Booked';
    }
    // For Acre-based: Drones & Sprays still get "Slot Booked"
    if (requiresCropSelection) {
      return 'Slot Booked';
    }
    return 'Confirmed';
  }

  // Get display name based on locale
  String getDisplayName(String locale) {
    if (locale == 'te' && nameTe != null && nameTe!.isNotEmpty) {
      return nameTe!;
    }
    return nameEn;
  }
}

// ============================================================================
// CROP MODEL - Dynamic from Database
// ============================================================================
class Crop {
  final int id;
  final String name;
  final String? imageUrl;

  Crop({required this.id, required this.name, this.imageUrl});

<<<<<<< HEAD
  String getLocalizedName(String locale) {
    return locale == 'te' ? nameTe : nameEn;
  }
}

// Booking State - Updated with new fields
class CHCBookingState {
  final Equipment? equipment;
  final double landSizeAcres;
  final double billedQty;
  final DateTime serviceDate;
  final CropOption? selectedCrop;
  final bool isMember;

  CHCBookingState({
    this.equipment,
    this.landSizeAcres = 1.0,
    this.billedQty = 1.0,
    DateTime? serviceDate,
    this.selectedCrop,
    this.isMember = true,
  }) : serviceDate = serviceDate ?? DateTime.now().add(const Duration(days: 1));

  // Calculate total cost based on billing type
  double get totalCost {
    if (equipment == null) return 0;

    final rate = equipment!.getPrice(isMember);

    if (equipment!.billingType == BillingType.fixed) {
      // For acre-based: landSize * rate
      return landSizeAcres * rate;
    } else {
      // For variable billing: billedQty * rate (but shown as pending)
      return billedQty * rate;
    }
  }

  // Check if booking is valid
  bool get isValid {
    if (equipment == null) return false;
    if (equipment!.requiresCropSelection && selectedCrop == null) return false;
    if (equipment!.billingType == BillingType.fixed && landSizeAcres <= 0) {
      return false;
    }
    return true;
  }

  // Get booking status based on billing type
  String get bookingStatus {
    if (equipment == null) return 'Pending';
    return equipment!.billingType == BillingType.variable
        ? 'Slot Booked'
        : 'Confirmed';
  }

  CHCBookingState copyWith({
    Equipment? equipment,
    double? landSizeAcres,
    double? billedQty,
    DateTime? serviceDate,
    CropOption? selectedCrop,
    bool? isMember,
    bool clearCrop = false,
  }) {
    return CHCBookingState(
      equipment: equipment ?? this.equipment,
      landSizeAcres: landSizeAcres ?? this.landSizeAcres,
      billedQty: billedQty ?? this.billedQty,
      serviceDate: serviceDate ?? this.serviceDate,
      selectedCrop: clearCrop ? null : (selectedCrop ?? this.selectedCrop),
      isMember: isMember ?? this.isMember,
=======
  factory Crop.fromJson(Map<String, dynamic> json) {
    return Crop(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      imageUrl: json['image_url'],
>>>>>>> d8e9c924f9c729b98cffbd28123c7d397c8a260d
    );
  }
}

// ============================================================================
// BOOKING STATE
// ============================================================================
class CHCBookingState {
  Equipment? equipment;
  Crop? crop;
  double acres;
  DateTime? serviceDate;
  bool isMember;
  Map<String, bool> fullyBookedDates;

  CHCBookingState({
    this.equipment,
    this.crop,
    this.acres = 1.0,
    this.serviceDate,
    this.isMember = false,
    Map<String, bool>? fullyBookedDates,
  }) : fullyBookedDates = fullyBookedDates ?? {};

  // Calculate total cost (only for Fixed billing)
  double get totalCost {
    if (equipment == null) return 0;
    if (equipment!.billingType == 'Variable') return 0;
    return acres * equipment!.displayPrice;
  }

  // Validation
  bool get isValid {
    if (equipment == null) return false;
    if (serviceDate == null) return false;
    if (equipment!.requiresCropSelection && crop == null) return false;
    if (acres <= 0) return false;
    return true;
  }

  // Get operator notes
  String getOperatorNotes() {
    if (equipment == null) return '';
    if (equipment!.billingType == 'Variable') {
      String note = 'Variable Billing: Final bill based on actual ${equipment!.unit}';
      if (equipment!.isTrolley) {
        note += ' (Note: Valid up to 5km only)';
      }
      return note;
    }
    return 'Fixed Rate Booking';
  }

  CHCBookingState copyWith({
    Equipment? equipment,
    Crop? crop,
    double? acres,
    DateTime? serviceDate,
    bool? isMember,
    Map<String, bool>? fullyBookedDates,
    bool clearCrop = false,
    bool clearDate = false,
  }) {
    return CHCBookingState(
      equipment: equipment ?? this.equipment,
      crop: clearCrop ? null : (crop ?? this.crop),
      acres: acres ?? this.acres,
      serviceDate: clearDate ? null : (serviceDate ?? this.serviceDate),
      isMember: isMember ?? this.isMember,
      fullyBookedDates: fullyBookedDates ?? this.fullyBookedDates,
    );
  }
}

// ============================================================================
// MAIN SCREEN
// ============================================================================
class CHCBookingScreen extends StatefulWidget {
  const CHCBookingScreen({super.key});

  @override
  State<CHCBookingScreen> createState() => _CHCBookingScreenState();
}

class _CHCBookingScreenState extends State<CHCBookingScreen> {
  late CHCBookingState _state;
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Equipment> _equipments = [];
  List<Crop> _crops = [];
  DateTime _calendarMonth = DateTime.now();
  late ConfettiController _confettiController;

<<<<<<< HEAD
  // Crop options for equipment that requires crop selection
  static const List<CropOption> _cropOptions = [
    CropOption(
      nameEn: 'Paddy',
      nameTe: 'వరి',
      imageUrl:
          'https://kiosk.cropsync.in/custom_hiring_center/crops/paddy.png',
    ),
    CropOption(
      nameEn: 'Cotton',
      nameTe: 'పత్తి',
      imageUrl:
          'https://kiosk.cropsync.in/custom_hiring_center/crops/cotton.png',
    ),
    CropOption(
      nameEn: 'Sunflower',
      nameTe: 'పొద్దుతిరుగుడు',
      imageUrl:
          'https://kiosk.cropsync.in/custom_hiring_center/crops/sunflower.png',
    ),
    CropOption(
      nameEn: 'Banana',
      nameTe: 'అరటి',
      imageUrl:
          'https://kiosk.cropsync.in/custom_hiring_center/crops/banana.png',
    ),
    CropOption(
      nameEn: 'Turmeric',
      nameTe: 'పసుపు',
      imageUrl:
          'https://kiosk.cropsync.in/custom_hiring_center/crops/turmeric.png',
    ),
    CropOption(
      nameEn: 'Chilli',
      nameTe: 'మిర్చి',
      imageUrl:
          'https://kiosk.cropsync.in/custom_hiring_center/crops/chilli.png',
    ),
    CropOption(
      nameEn: 'Maize',
      nameTe: 'మొక్కజొన్న',
      imageUrl:
          'https://kiosk.cropsync.in/custom_hiring_center/crops/maize.png',
    ),
    CropOption(
      nameEn: 'Groundnut',
      nameTe: 'వేరుశెనగ',
      imageUrl:
          'https://kiosk.cropsync.in/custom_hiring_center/crops/groundnut.png',
    ),
  ];

  // Equipment list matching database structure
  static const List<Equipment> _equipmentList = [
    Equipment(
      id: 1,
      nameEn: 'Combined Harvester',
      nameTe: 'కంబైన్డ్ హార్వెస్టర్',
      imageUrl: 'https://kiosk.cropsync.in/custom_hiring_center/Harvestor.png',
      description: 'Ideal for harvesting paddy and grain crops quickly.',
      priceMember: 2000.00,
      priceNonMember: 2200.00,
      unit: UnitType.hour,
      quantity: 2,
      accentColor: Color(0xFFEF4444),
    ),
    Equipment(
      id: 2,
      nameEn: 'Tractor',
      nameTe: 'ట్రాక్టర్',
      imageUrl: 'https://kiosk.cropsync.in/custom_hiring_center/Tractor.png',
      description: 'For ploughing and general transportation.',
      priceMember: 1200.00,
      priceNonMember: 1400.00,
      unit: UnitType.hour,
      quantity: 5,
      accentColor: Color(0xFF3B82F6),
    ),
    Equipment(
      id: 3,
      nameEn: 'Balers',
      nameTe: 'బేలర్స్',
      imageUrl: 'https://kiosk.cropsync.in/custom_hiring_center/Baler.jpg',
      description: 'Compresses cut crops into compact bales.',
      priceMember: 30.00,
      priceNonMember: 40.00,
      unit: UnitType.bale,
      quantity: 3,
      accentColor: Color(0xFF10B981),
    ),
    Equipment(
      id: 4,
      nameEn: 'Boomer Spray',
      nameTe: 'బూమర్ స్ప్రే',
      imageUrl: 'https://kiosk.cropsync.in/custom_hiring_center/Sprayer.png',
      description: 'High efficiency spraying for large fields.',
      priceMember: 400.00,
      priceNonMember: 500.00,
      unit: UnitType.acre,
      quantity: 4,
      accentColor: Color(0xFF8B5CF6),
      requiresCropSelection: true,
    ),
    Equipment(
      id: 5,
      nameEn: 'Shredder',
      nameTe: 'ష్రెడ్డర్',
      imageUrl: 'https://kiosk.cropsync.in/custom_hiring_center/Shredor.png',
      description: 'Shreds crop residue to mix back into soil.',
      priceMember: 1000.00,
      priceNonMember: 1200.00,
      unit: UnitType.hour,
      quantity: 2,
      accentColor: Color(0xFFF59E0B),
    ),
    Equipment(
      id: 6,
      nameEn: 'Tractor Trolley',
      nameTe: 'ట్రాక్టర్ ట్రాలీ',
      imageUrl: 'https://kiosk.cropsync.in/custom_hiring_center/Trolley.png',
      description: 'Transport for goods up to 5KM.',
      priceMember: 500.00,
      priceNonMember: 500.00,
      unit: UnitType.trip,
      quantity: 10,
      accentColor: Color(0xFF06B6D4),
    ),
    Equipment(
      id: 7,
      nameEn: 'Mobile Grain Dryer',
      nameTe: 'మొబైల్ గ్రెయిన్ డ్రయ్యర్',
      imageUrl: 'https://kiosk.cropsync.in/custom_hiring_center/Graindryer.png',
      description: 'Reduces moisture content in grains.',
      priceMember: 1500.00,
      priceNonMember: 1700.00,
      unit: UnitType.ton,
      quantity: 1,
      accentColor: Color(0xFFEC4899),
    ),
    Equipment(
      id: 8,
      nameEn: 'Seed Cum Fertilizer Drill',
      nameTe: 'సీడ్ కమ్ ఫెర్టిలైజర్ డ్రిల్',
      imageUrl: 'https://kiosk.cropsync.in/custom_hiring_center/Seeddrill.png',
      description: 'Sows seeds and fertilizer simultaneously.',
      priceMember: 1200.00,
      priceNonMember: 1400.00,
      unit: UnitType.hour,
      quantity: 3,
      accentColor: Color(0xFF14B8A6),
    ),
    Equipment(
      id: 9,
      nameEn: 'Agri Drone',
      nameTe: 'అగ్రి డ్రోన్',
      imageUrl: 'https://kiosk.cropsync.in/custom_hiring_center/Drone.png',
      description: 'Aerial spraying for precise application.',
      priceMember: 400.00,
      priceNonMember: 500.00,
      unit: UnitType.acre,
      quantity: 6,
      accentColor: Color(0xFF6366F1),
      requiresCropSelection: true,
    ),
    Equipment(
      id: 10,
      nameEn: 'Manual Seed Drill (Maize)',
      nameTe: 'మాన్యువల్ సీడ్ డ్రిల్ (మొక్కజొన్న)',
      imageUrl: 'https://kiosk.cropsync.in/custom_hiring_center/Seed_Drill.png',
      description: 'Manual sowing specifically for Maize.',
      priceMember: 450.00,
      priceNonMember: 550.00,
      unit: UnitType.acre,
      quantity: 5,
      accentColor: Color(0xFF84CC16),
    ),
=======
  // Telugu month names (matching web)
  static const List<String> _monthNamesTe = [
    'జనవరి', 'ఫిబ్రవరి', 'మార్చి', 'ఏప్రిల్', 'మే', 'జూన్',
    'జూలై', 'ఆగస్టు', 'సెప్టెంబర్', 'అక్టోబర్', 'నవంబర్', 'డిసెంబర్'
>>>>>>> d8e9c924f9c729b98cffbd28123c7d397c8a260d
  ];

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    final currentUser = AuthService.currentUser;
    final isMember = currentUser?.membershipType?.toLowerCase() == 'member' ||
        currentUser?.membershipType?.toLowerCase() == 'prp';

    _state = CHCBookingState(
      serviceDate: DateTime.now().add(const Duration(days: 1)),
      isMember: isMember,
    );
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
=======
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    
    // Check membership from user profile
    final currentUser = AuthService.currentUser;
    final isMember = currentUser?.cardUid != null && currentUser!.cardUid!.isNotEmpty;
    
    _state = CHCBookingState(isMember: isMember);
    _loadData();
>>>>>>> d8e9c924f9c729b98cffbd28123c7d397c8a260d
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load equipments with membership pricing
      final equipmentsData = await ApiService.getCHCEquipments(isMember: _state.isMember);
      _equipments = equipmentsData.map((e) => Equipment.fromJson(e)).toList();
      
      // Load crops
      final cropsData = await ApiService.getCrops();
      _crops = cropsData.map((c) => Crop.fromJson(c)).toList();
    } catch (e) {
      debugPrint('Error loading CHC data: $e');
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadBookedDates() async {
    if (_state.equipment == null) return;
    
    try {
      final dates = await ApiService.getBookedDates(
        equipmentName: _state.equipment!.nameEn,
        month: _calendarMonth.month,
        year: _calendarMonth.year,
      );
      
      final fullyBooked = <String, bool>{};
      for (final d in dates) {
        if (d['is_full'] == true) {
          fullyBooked[d['date']] = true;
        }
      }
      
      if (mounted) {
        setState(() {
          _state = _state.copyWith(fullyBookedDates: fullyBooked);
        });
      }
    } catch (e) {
      debugPrint('Error loading booked dates: $e');
    }
  }

  void _selectEquipment(Equipment equipment) {
    HapticFeedback.lightImpact();
    setState(() {
      _state = _state.copyWith(
        equipment: equipment,
        clearCrop: true,
        clearDate: true,
      );
    });
    _loadBookedDates();
  }

  void _selectCrop(Crop crop) {
    HapticFeedback.lightImpact();
    setState(() {
      _state = _state.copyWith(crop: crop);
    });
  }

  void _selectDate(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    if (_state.fullyBookedDates[dateStr] == true) {
      _showFullyBookedError();
      return;
    }
    
    HapticFeedback.lightImpact();
    setState(() {
      _state = _state.copyWith(serviceDate: date);
    });
  }

  void _changeAcres(double delta) {
    final newValue = _state.acres + delta;
    if (newValue >= 0.5 && newValue <= 100) {
      HapticFeedback.lightImpact();
      setState(() {
        _state = _state.copyWith(acres: newValue);
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + delta);
    });
    _loadBookedDates();
  }

  Future<void> _submitBooking() async {
    if (!_state.isValid) return;
    
    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();
    
    try {
      final currentUser = AuthService.currentUser;
      final userId = currentUser?.userId ?? 'guest';
      final dateStr = DateFormat('yyyy-MM-dd').format(_state.serviceDate!);
      
      // Check availability first (overbooking prevention)
      final availability = await ApiService.checkEquipmentAvailability(
        equipmentName: _state.equipment!.nameEn,
        serviceDate: dateStr,
      );
      
      if (availability['can_book'] != true) {
        setState(() => _isSubmitting = false);
        _showFullyBookedError(message: availability['message']);
        return;
      }
      
      // Generate booking ID: CSC-DDMM-XXX
      final now = DateTime.now();
      final bookingId = 'CSC-${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}-${(now.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0')}';
      
      // Determine billing values
      final billingType = _state.equipment!.billingType;
      final bookingStatus = _state.equipment!.getBookingStatus();
      final billedQty = billingType == 'Fixed' ? _state.acres : 0.0;
      final totalCost = billingType == 'Fixed' ? _state.totalCost : 0.0;
      
      final result = await ApiService.createCHCBooking(
        bookingId: bookingId,
        userId: userId,
        equipmentType: _state.equipment!.nameEn,
<<<<<<< HEAD
        cropType: _state.selectedCrop?.nameEn,
        acres: _state.landSizeAcres,
        serviceDate: _state.serviceDate,
        ratePerAcre: _state.equipment!.getPrice(_state.isMember),
        totalCost: _state.equipment!.billingType == BillingType.fixed
            ? _state.totalCost
            : 0, // Variable billing has 0 total until service completion
=======
        cropType: _state.crop?.name,
        acres: _state.acres,
        serviceDate: _state.serviceDate!,
        ratePerAcre: _state.equipment!.displayPrice,
        totalCost: totalCost,
        billingType: billingType,
        unitType: _state.equipment!.unit,
        billedQty: billedQty,
        notes: _state.getOperatorNotes(),
        bookingStatus: bookingStatus,
>>>>>>> d8e9c924f9c729b98cffbd28123c7d397c8a260d
      );
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        _confettiController.play();
        await _showSuccessDialog(
          bookingId: bookingId,
          billingType: billingType,
          totalCost: totalCost,
        );
        
        // Reset state
        setState(() {
          _state = CHCBookingState(isMember: _state.isMember);
        });
      } else {
        _showErrorSnackBar(result['error'] ?? 'Booking failed');
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

<<<<<<< HEAD
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        backgroundColor: isError ? CHCTheme.error : CHCTheme.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _showSuccessDialog(String bookingId) async {
    HapticFeedback.heavyImpact();

    final locale = context.locale.languageCode;
    final equipmentName = _getEquipmentName(_state.equipment!);
    final formattedDate =
        DateFormat('dd MMM yyyy', locale).format(_state.serviceDate);
    final rate = _state.equipment!.getPrice(_state.isMember);
    final unitName = _state.equipment!.unit.getLocalizedName(locale);

    final isVariableBilling =
        _state.equipment!.billingType == BillingType.variable;
    final totalValue = isVariableBilling
        ? context.tr('chc_bill_pending')
        : '₹${_state.totalCost.toStringAsFixed(0)}';

    return showDialog(
=======
  void _showFullyBookedError({String? message}) {
    showDialog(
>>>>>>> d8e9c924f9c729b98cffbd28123c7d397c8a260d
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
<<<<<<< HEAD
                  color: isVariableBilling
                      ? CHCTheme.slotBooked.withOpacity(0.1)
                      : CHCTheme.accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVariableBilling
                      ? Icons.event_available
                      : Icons.check_circle,
                  size: 48,
                  color:
                      isVariableBilling ? CHCTheme.slotBooked : CHCTheme.accent,
                ),
=======
                  color: CHCTheme.errorBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline, size: 48, color: CHCTheme.errorText),
>>>>>>> d8e9c924f9c729b98cffbd28123c7d397c8a260d
              ),
              const SizedBox(height: 20),
              Text(
<<<<<<< HEAD
                isVariableBilling
                    ? context.tr('chc_slot_booked_title')
                    : context.tr('chc_success_title'),
                style: GoogleFonts.inter(
                  fontSize: 24,
=======
                _state.equipment?.getDisplayName(context.locale.languageCode) ?? '',
                style: GoogleFonts.notoSansTelugu(
                  fontSize: 20,
>>>>>>> d8e9c924f9c729b98cffbd28123c7d397c8a260d
                  fontWeight: FontWeight.bold,
                  color: CHCTheme.text,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message ?? 'క్షమించండి, ఈ తేదీలో స్లాట్లు అన్నీ బుక్ అయిపోయాయి.\n(Fully Booked)',
                style: GoogleFonts.notoSansTelugu(
                  fontSize: 14,
                  color: CHCTheme.errorText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
<<<<<<< HEAD
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CHCTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _DetailRow(context.tr('booking_id'), bookingId),
                    const SizedBox(height: 8),
                    _DetailRow(context.tr('equipment'), equipmentName),
                    if (_state.selectedCrop != null) ...[
                      const SizedBox(height: 8),
                      _DetailRow(
                        context.tr('crop'),
                        _state.selectedCrop!.getLocalizedName(locale),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _DetailRow(
                      context.tr('rate'),
                      '₹${rate.toStringAsFixed(0)} / $unitName',
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      context.tr('land_size'),
                      '${_state.landSizeAcres.toStringAsFixed(1)} ${context.tr('acres')}',
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(context.tr('service_date'), formattedDate),
                    const SizedBox(height: 8),
                    _DetailRow(context.tr('total_cost_label'), totalValue),
                    if (isVariableBilling) ...[
                      const SizedBox(height: 8),
                      Text(
                        context.tr('chc_variable_billing_note'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: CHCTheme.slotBooked,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
=======
>>>>>>> d8e9c924f9c729b98cffbd28123c7d397c8a260d
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
<<<<<<< HEAD
                    backgroundColor: isVariableBilling
                        ? CHCTheme.slotBooked
                        : CHCTheme.primary,
=======
                    backgroundColor: CHCTheme.primary,
>>>>>>> d8e9c924f9c729b98cffbd28123c7d397c8a260d
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'వేరే తేదీ ఎంచుకోండి (Select Another Date)',
                    style: GoogleFonts.notoSansTelugu(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSuccessDialog({
    required String bookingId,
    required String billingType,
    required double totalCost,
  }) async {
    final locale = context.locale.languageCode;
    final equipmentName = _state.equipment!.getDisplayName(locale);
    final dateStr = DateFormat('yyyy-MM-dd').format(_state.serviceDate!);
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Stack(
        children: [
          Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: CHCTheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 48, color: CHCTheme.primary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'బుకింగ్ విజయవంతమైంది!',
                    style: GoogleFonts.notoSansTelugu(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: CHCTheme.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Booking ID:', style: TextStyle(color: Colors.grey)),
                  Text(
                    bookingId,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  
                  // Receipt details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CHCTheme.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _ReceiptRow('యంత్రం:', equipmentName),
                        if (_state.crop != null)
                          _ReceiptRow('పంట:', _state.crop!.name),
                        _ReceiptRow('విస్తీర్ణం:', '${_state.acres} ఎకరాలు'),
                        _ReceiptRow('తేదీ:', dateStr),
                        const Divider(),
                        _ReceiptRow(
                          'మొత్తం:',
                          billingType == 'Fixed' 
                              ? '₹${totalCost.toStringAsFixed(0)}'
                              : 'బిల్లు పెండింగ్',
                          isTotal: true,
                          isPending: billingType != 'Fixed',
                        ),
                        if (billingType != 'Fixed')
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '* సేవ పూర్తయ్యాక బిల్లు వస్తుంది',
                              style: GoogleFonts.notoSansTelugu(
                                fontSize: 11,
                                color: CHCTheme.warning,
                              ),
                            ),
                          ),
                        if (_state.equipment!.isTrolley)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: CHCTheme.warningBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '⚠️ 5 కి.మీ పరిధి వరకు మాత్రమే',
                              style: GoogleFonts.notoSansTelugu(
                                fontSize: 11,
                                color: CHCTheme.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: FilledButton.styleFrom(
                        backgroundColor: CHCTheme.text,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'సరే (Done)',
                        style: GoogleFonts.notoSansTelugu(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              colors: const [
                CHCTheme.primary,
                CHCTheme.accent,
                CHCTheme.memberBadge,
                Colors.blue,
                Colors.green,
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: CHCTheme.errorText,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.currentUser;
    final locale = context.locale.languageCode;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: CHCTheme.bg,
        body: const Center(child: CircularProgressIndicator(color: CHCTheme.primary)),
      );
    }

    return Scaffold(
      backgroundColor: CHCTheme.bg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(child: _buildHeader(currentUser)),
              
              // Equipment Grid
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: _buildCard(
                    title: 'యంత్రాన్ని ఎంచుకోండి (Select Equipment)',
                    icon: Icons.grid_view_rounded,
                    child: _buildEquipmentGrid(locale),
                  ),
                ),
              ),
              
              // Crop Selection (conditional)
              if (_state.equipment?.requiresCropSelection == true)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: _buildCard(
                      title: 'పంట రకం (Select Crop)',
                      icon: Icons.grass,
                      child: _buildCropGrid(),
                    ),
                  ),
                ),
              
              // Land Size Counter
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: _buildCard(
                    title: 'పొలం విస్తీర్ణం (Land Size in Acres)',
                    icon: Icons.straighten,
                    child: _buildCounter(),
                  ),
                ),
              ),
              
              // Calendar
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _buildCard(
                    title: 'తేదీని ఎంచుకోండి (Date)',
                    icon: Icons.calendar_today,
                    child: _buildCalendar(),
                  ),
                ),
              ),
              
              // Bottom spacing
              const SliverPadding(padding: EdgeInsets.only(bottom: 200)),
            ],
          ),
          
          // Summary Panel (Bottom)
          _buildSummaryPanel(locale),
        ],
      ),
    );
  }

  Widget _buildHeader(dynamic currentUser) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 25),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [CHCTheme.primary, CHCTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Stack(
        children: [
          if (_state.isMember)
            Positioned(
              right: -10,
              bottom: -40,
              child: Icon(
                Icons.workspace_premium,
                size: 140,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.agriculture, color: Colors.white, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'క్రాప్సింక్ CHC',
                    style: GoogleFonts.notoSansTelugu(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'రైతు: ${currentUser?.name ?? 'Guest'} (${currentUser?.village ?? ''})',
                style: GoogleFonts.notoSansTelugu(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 8),
              Container(
<<<<<<< HEAD
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _state.isMember
                      ? CHCTheme.memberBadge.withOpacity(0.2)
                      : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        _state.isMember ? CHCTheme.memberBadge : Colors.white70,
                  ),
=======
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
>>>>>>> d8e9c924f9c729b98cffbd28123c7d397c8a260d
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
<<<<<<< HEAD
                    Icon(
                      _state.isMember ? Icons.star : Icons.person,
                      size: 16,
                      color: _state.isMember
                          ? CHCTheme.memberBadge
                          : Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _state.isMember
                          ? context.tr('member')
                          : context.tr('non_member'),
                      style: TextStyle(
=======
                    if (_state.isMember)
                      const Icon(Icons.star, color: CHCTheme.memberBadge, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      _state.isMember ? 'సభ్యులు (Member)' : 'సభ్యత్వం లేదు (Non-Member)',
                      style: GoogleFonts.notoSansTelugu(
>>>>>>> d8e9c924f9c729b98cffbd28123c7d397c8a260d
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
<<<<<<< HEAD
                        color: _state.isMember
                            ? CHCTheme.memberBadge
                            : Colors.white70,
=======
>>>>>>> d8e9c924f9c729b98cffbd28123c7d397c8a260d
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CHCTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CHCTheme.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: CHCTheme.primaryDark, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.notoSansTelugu(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: CHCTheme.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildEquipmentGrid(String locale) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _equipments.length,
      itemBuilder: (ctx, i) {
        final eq = _equipments[i];
        final isSelected = _state.equipment?.id == eq.id;
        
        return GestureDetector(
          onTap: () => _selectEquipment(eq),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE6FCF9) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? CHCTheme.primary : CHCTheme.border,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: CHCTheme.primary.withOpacity(0.2), blurRadius: 10, spreadRadius: 2)]
                  : null,
            ),
            child: Stack(
              children: [
                // Member badge
                if (_state.isMember)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: CHCTheme.memberBadge,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                      ),
                      child: Text(
                        'సభ్యుల ధర',
                        style: GoogleFonts.notoSansTelugu(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF333333),
                        ),
                      ),
                    ),
                  ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Equipment image
                    SizedBox(
                      height: 80,
                      child: CachedNetworkImage(
                        imageUrl: eq.image.startsWith('http') 
                            ? eq.image 
                            : 'https://kiosk.cropsync.in/custom_hiring_center/${eq.image}',
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const CircularProgressIndicator(strokeWidth: 2),
                        errorWidget: (_, __, ___) => const Icon(Icons.agriculture, size: 50),
                      ),
                    ),
<<<<<<< HEAD
                  ),
                ),
                const SizedBox(height: 10),
                // Equipment Name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    equipmentName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? equipment.accentColor
                          : CHCTheme.textPrimary,
=======
                    const SizedBox(height: 8),
                    // Name
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        eq.getDisplayName(locale),
                        style: GoogleFonts.notoSansTelugu(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? CHCTheme.primary : CHCTheme.text,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
>>>>>>> d8e9c924f9c729b98cffbd28123c7d397c8a260d
                    ),
                    const SizedBox(height: 6),
                    // Price
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: CHCTheme.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '₹${eq.displayPrice.toStringAsFixed(0)} / ${eq.unit}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: CHCTheme.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCropGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _crops.length,
      itemBuilder: (ctx, i) {
        final crop = _crops[i];
        final isSelected = _state.crop?.id == crop.id;
        
        return GestureDetector(
          onTap: () => _selectCrop(crop),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? CHCTheme.primary : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? CHCTheme.primary : CHCTheme.border,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (crop.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: crop.imageUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Icon(
                        Icons.grass,
                        color: isSelected ? Colors.white : CHCTheme.primary,
                      ),
                    ),
                  )
                else
                  Icon(Icons.grass, color: isSelected ? Colors.white : CHCTheme.primary),
                const SizedBox(height: 4),
                Text(
                  crop.name,
                  style: GoogleFonts.notoSansTelugu(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : CHCTheme.text,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCounter() {
    return Column(
      children: [
        // Warning boxes (matching web)
        if (_state.equipment != null && _state.equipment!.billingType == 'Variable')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: CHCTheme.warningBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFEEBA)),
            ),
            child: Column(
              children: [
                Text(
                  _getUnitRateText(),
                  style: GoogleFonts.notoSansTelugu(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CHCTheme.warning,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  _getUnitSubtext(),
                  style: GoogleFonts.notoSansTelugu(
                    fontSize: 12,
                    color: CHCTheme.warning,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        
        // Trolley warning
        if (_state.equipment?.isTrolley == true)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: CHCTheme.errorBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFCDD2)),
            ),
            child: Text(
              '⚠️ గమనిక:\nఈ ధర 5 కి.మీ పరిధి వరకు మాత్రమే వర్తిస్తుంది. ఆపై దూరాన్ని బట్టి ధర మారుతుంది.',
              style: GoogleFonts.notoSansTelugu(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CHCTheme.errorText,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        
        // Counter
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CounterButton(
              icon: Icons.remove,
              onTap: () => _changeAcres(-0.5),
            ),
            const SizedBox(width: 24),
            Column(
              children: [
                Text(
                  _state.acres.toStringAsFixed(1),
                  style: GoogleFonts.poppins(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: CHCTheme.text,
                  ),
                ),
                Text(
                  'ఎకరాలు (Acres)',
                  style: GoogleFonts.notoSansTelugu(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 24),
            _CounterButton(
              icon: Icons.add,
              onTap: () => _changeAcres(0.5),
            ),
          ],
        ),
      ],
    );
  }

  String _getUnitRateText() {
    if (_state.equipment == null) return '';
    final unit = _state.equipment!.unit;
    final rate = _state.equipment!.displayPrice.toStringAsFixed(0);
    
    switch (unit) {
      case 'Hour':
        return 'గంటకు ఛార్జీ (Rate: ₹$rate/hr)';
      case 'Bale':
        return 'బేల్ కు ఛార్జీ (Rate: ₹$rate/bale)';
      case 'Trip':
        return 'ట్రిప్పు కు ఛార్జీ (Rate: ₹$rate/trip)';
      case 'Ton':
        return 'టన్ కు ఛార్జీ (Rate: ₹$rate/ton)';
      default:
        return '';
    }
  }

  String _getUnitSubtext() {
    if (_state.equipment == null) return '';
    final unit = _state.equipment!.unit;
    
    switch (unit) {
      case 'Hour':
        return 'సేవ పూర్తయ్యాక గంటల ఆధారంగా బిల్లు';
      case 'Bale':
        return 'సుమారు 60 బేల్స్/ఎకరా';
      default:
        return 'సేవ పూర్తయ్యాక బిల్లు వస్తుంది';
    }
  }

  Widget _buildCalendar() {
    final now = DateTime.now();
    final daysInMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0
    
    return Column(
      children: [
        // Month navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_monthNamesTe[_calendarMonth.month - 1]} ${_calendarMonth.year}',
              style: GoogleFonts.notoSansTelugu(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Day headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['ఆ', 'సో', 'మం', 'బు', 'గు', 'శు', 'శ']
              .map((d) => SizedBox(
                    width: 40,
                    child: Text(d, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        
        // Calendar grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
<<<<<<< HEAD
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            itemCount: crops.length,
            itemBuilder: (ctx, i) {
              final crop = crops[i];
              final isSelected = selectedCrop?.nameEn == crop.nameEn;
              return GestureDetector(
                onTap: () => onSelect(crop),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 12),
                  width: 70,
                  decoration: BoxDecoration(
                    color: isSelected ? CHCTheme.primary : CHCTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isSelected ? CHCTheme.primary : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (crop.imageUrl != null)
                        CachedNetworkImage(
                          imageUrl: crop.imageUrl!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.contain,
                          errorWidget: (context, url, error) => Icon(
                            Icons.grass,
                            size: 24,
                            color: isSelected ? Colors.white : CHCTheme.primary,
                          ),
                        )
                      else
                        Icon(
                          Icons.grass,
                          size: 24,
                          color: isSelected ? Colors.white : CHCTheme.primary,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        crop.getLocalizedName(locale),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color:
                              isSelected ? Colors.white : CHCTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
=======
          itemCount: startingWeekday + daysInMonth,
          itemBuilder: (ctx, index) {
            if (index < startingWeekday) {
              return const SizedBox();
            }
            
            final day = index - startingWeekday + 1;
            final date = DateTime(_calendarMonth.year, _calendarMonth.month, day);
            final dateStr = DateFormat('yyyy-MM-dd').format(date);
            final isPast = date.isBefore(DateTime(now.year, now.month, now.day));
            final isSelected = _state.serviceDate != null &&
                date.year == _state.serviceDate!.year &&
                date.month == _state.serviceDate!.month &&
                date.day == _state.serviceDate!.day;
            final isFullyBooked = _state.fullyBookedDates[dateStr] == true;
            
            return GestureDetector(
              onTap: isPast ? null : () => _selectDate(date),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? CHCTheme.primary
                      : isPast
                          ? const Color(0xFFF9F9F9)
                          : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isFullyBooked
                        ? CHCTheme.accent
                        : isSelected
                            ? CHCTheme.primary
                            : const Color(0xFFF0F0F0),
                    width: isFullyBooked ? 2 : 1,
                    style: isFullyBooked ? BorderStyle.solid : BorderStyle.solid,
>>>>>>> d8e9c924f9c729b98cffbd28123c7d397c8a260d
                  ),
                ),
                child: Center(
                  child: Text(
                    day.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? Colors.white
                          : isPast
                              ? Colors.grey.shade400
                              : isFullyBooked
                                  ? CHCTheme.accent
                                  : CHCTheme.text,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
<<<<<<< HEAD
}

// Quantity/Land Size Slider Widget - Updated for different unit types
class _QuantitySlider extends StatelessWidget {
  final double value;
  final Equipment? equipment;
  final bool isMember;
  final ValueChanged<double> onChanged;
  final String locale;

  const _QuantitySlider({
    required this.value,
    required this.equipment,
    required this.isMember,
    required this.onChanged,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final rate = equipment?.getPrice(isMember) ?? 0;
    final unitName =
        equipment?.unit.getLocalizedName(locale) ?? context.tr('acres');
    final isVariableBilling = equipment?.billingType == BillingType.variable;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CHCTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.straighten, size: 20, color: CHCTheme.primary),
              const SizedBox(width: 8),
              Text(
                context.tr('chc_land_size'),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CHCTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Rate info
          if (equipment != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isVariableBilling
                    ? CHCTheme.slotBooked.withOpacity(0.1)
                    : CHCTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    '${context.tr('rate')}: ₹${rate.toStringAsFixed(0)}/$unitName',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isVariableBilling
                          ? CHCTheme.slotBooked
                          : CHCTheme.accent,
                    ),
                  ),
                  if (isVariableBilling) ...[
                    const SizedBox(height: 4),
                    Text(
                      context.tr('chc_variable_billing_info'),
                      style: TextStyle(
                        fontSize: 11,
                        color: CHCTheme.slotBooked.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${value.toStringAsFixed(1)} ${context.tr('acres')}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: CHCTheme.primary,
                ),
              ),
              if (!isVariableBilling && equipment != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: CHCTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '₹${(value * rate).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CHCTheme.accent,
                    ),
                  ),
                )
              else if (isVariableBilling)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: CHCTheme.slotBooked.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.tr('chc_bill_pending'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CHCTheme.slotBooked,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              activeTrackColor: CHCTheme.primary,
              inactiveTrackColor: CHCTheme.surface,
              thumbColor: CHCTheme.primary,
              overlayColor: CHCTheme.primary.withOpacity(0.1),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            ),
            child: Slider(
              value: value,
              min: 0.5,
              max: 100,
              divisions: 199,
              onChanged: onChanged,
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0.5',
                  style:
                      TextStyle(fontSize: 12, color: CHCTheme.textSecondary)),
              Text('100',
                  style:
                      TextStyle(fontSize: 12, color: CHCTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// Date Selector Widget
class _DateSelector extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  const _DateSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final dates =
        List.generate(14, (i) => DateTime.now().add(Duration(days: i + 1)));

    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: CHCTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        itemCount: dates.length,
        itemBuilder: (ctx, i) => _DateCard(
          date: dates[i],
          locale: locale,
          isSelected: DateUtils.isSameDay(dates[i], selected),
          onTap: () => onSelect(dates[i]),
        ),
      ),
    );
  }
}

// Date Card Widget
class _DateCard extends StatelessWidget {
  final DateTime date;
  final String locale;
  final bool isSelected;
  final VoidCallback onTap;

  const _DateCard({
    required this.date,
    required this.locale,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12),
        width: 70,
        decoration: BoxDecoration(
          color: isSelected ? CHCTheme.primary : CHCTheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('EEE', locale).format(date),
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white70 : CHCTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd').format(date),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : CHCTheme.textPrimary,
              ),
            ),
            Text(
              DateFormat('MMM', locale).format(date),
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white70 : CHCTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Bottom Bar Widget - Updated with variable billing support
class _BottomBar extends StatelessWidget {
  final CHCBookingState state;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final String Function(Equipment) getEquipmentName;
  final String locale;

  const _BottomBar({
    required this.state,
    required this.isSubmitting,
    required this.onSubmit,
    required this.getEquipmentName,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final isVariableBilling =
        state.equipment?.billingType == BillingType.variable;
    final rate = state.equipment?.getPrice(state.isMember) ?? 0;
    final unitName = state.equipment?.unit.getLocalizedName(locale) ?? '';
=======
>>>>>>> d8e9c924f9c729b98cffbd28123c7d397c8a260d

  Widget _buildSummaryPanel(String locale) {
    final equipmentName = _state.equipment?.getDisplayName(locale) ?? 'ఎంచుకోండి';
    final rate = _state.equipment != null
        ? '₹${_state.equipment!.displayPrice.toStringAsFixed(0)} / ${_state.equipment!.unit}'
        : '-';
    final dateStr = _state.serviceDate != null
        ? DateFormat('yyyy-MM-dd').format(_state.serviceDate!)
        : 'ఎంచుకోండి';
    
    final isVariableBilling = _state.equipment?.billingType == 'Variable';
    final totalDisplay = isVariableBilling ? 'బిల్లు పెండింగ్' : '₹${_state.totalCost.toStringAsFixed(0)}';
    
    // Button text based on billing type (matching web)
    String buttonText;
    if (_state.equipment == null) {
      buttonText = 'యంత్రాన్ని ఎంచుకోండి';
    } else if (_state.equipment!.billingType == 'Acre') {
      buttonText = 'బుకింగ్ నిర్ధారించండి (Confirm)';
    } else {
      buttonText = 'స్లాట్ బుక్ చేయండి (Book Slot)';
    }
    
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: CHCTheme.surface.withOpacity(0.95),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Summary rows
                  _SummaryRow('యంత్రం:', equipmentName, highlight: true),
                  if (_state.equipment?.requiresCropSelection == true)
                    _SummaryRow('పంట:', _state.crop?.name ?? '-'),
                  _SummaryRow('ధర (Rate):', rate),
                  _SummaryRow('విస్తీర్ణం:', '${_state.acres} ఎకరాలు'),
                  _SummaryRow('తేదీ:', dateStr),
                  const Divider(height: 24),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'మొత్తం (Total):',
                        style: GoogleFonts.notoSansTelugu(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
<<<<<<< HEAD
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: isSubmitting ? null : onSubmit,
                            style: FilledButton.styleFrom(
                              backgroundColor: isVariableBilling
                                  ? CHCTheme.slotBooked
                                  : CHCTheme.primary,
                              disabledBackgroundColor: isVariableBilling
                                  ? CHCTheme.slotBooked.withOpacity(0.5)
                                  : CHCTheme.primary.withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    isVariableBilling
                                        ? context.tr('chc_book_slot')
                                        : context.tr('chc_book_now'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
=======
                      Text(
                        totalDisplay,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isVariableBilling ? CHCTheme.warning : CHCTheme.primary,
>>>>>>> d8e9c924f9c729b98cffbd28123c7d397c8a260d
                        ),
                      ),
                    ],
                  ),
                  
                  if (isVariableBilling)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '* సేవ పూర్తయ్యాక బిల్లు వస్తుంది',
                        style: GoogleFonts.notoSansTelugu(
                          fontSize: 11,
                          color: CHCTheme.warning,
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Book button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _state.isValid && !_isSubmitting ? _submitBooking : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: CHCTheme.primary,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              buttonText,
                              style: GoogleFonts.notoSansTelugu(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// HELPER WIDGETS
// ============================================================================

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CounterButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
        ),
        child: Icon(icon, color: CHCTheme.primary, size: 24),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _SummaryRow(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.notoSansTelugu(fontSize: 14, color: Colors.grey.shade600)),
          Text(
            value,
            style: GoogleFonts.notoSansTelugu(
              fontSize: 14,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
              color: highlight ? CHCTheme.primary : CHCTheme.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;
  final bool isPending;

  const _ReceiptRow(this.label, this.value, {this.isTotal = false, this.isPending = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.notoSansTelugu(
              fontSize: isTotal ? 16 : 13,
              color: Colors.grey.shade600,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.notoSansTelugu(
              fontSize: isTotal ? 20 : 14,
              fontWeight: FontWeight.w700,
              color: isPending ? CHCTheme.warning : (isTotal ? CHCTheme.primary : CHCTheme.text),
            ),
          ),
        ],
      ),
    );
  }
}
