// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

// Design System
class CHCTheme {
  static const primary = Color(0xFF1E3A8A);
  static const primaryLight = Color(0xFF3B82F6);
  static const accent = Color(0xFF10B981);
  static const surface = Color(0xFFFAFAFA);
  static const surfaceCard = Colors.white;
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const memberBadge = Color(0xFF22C55E);
  static const slotBooked = Color(0xFFFF9800);
}

// Unit types enum matching database
enum UnitType {
  hour('Hour', 'గంట'),
  acre('Acre', 'ఎకరం'),
  bale('Bale', 'బేల్'),
  trip('Trip', 'ట్రిప్'),
  ton('Ton', 'టన్');

  final String nameEn;
  final String nameTe;
  const UnitType(this.nameEn, this.nameTe);

  String getLocalizedName(String locale) {
    return locale == 'te' ? nameTe : nameEn;
  }
}

// Billing type enum
enum BillingType {
  fixed, // For acre-based equipment - total calculated upfront
  variable // For hour/bale/trip/ton - bill after service completion
}

// Equipment Model - Updated to match database structure
class Equipment {
  final int id;
  final String nameEn;
  final String? nameTe;
  final String imageUrl;
  final String? description;
  final double priceMember;
  final double priceNonMember;
  final UnitType unit;
  final int quantity;
  final bool isActive;
  final Color accentColor;
  final bool requiresCropSelection;

  const Equipment({
    required this.id,
    required this.nameEn,
    this.nameTe,
    required this.imageUrl,
    this.description,
    required this.priceMember,
    required this.priceNonMember,
    required this.unit,
    this.quantity = 1,
    this.isActive = true,
    required this.accentColor,
    this.requiresCropSelection = false,
  });

  // Determine billing type based on unit
  BillingType get billingType {
    switch (unit) {
      case UnitType.acre:
        return BillingType.fixed;
      case UnitType.hour:
      case UnitType.bale:
      case UnitType.trip:
      case UnitType.ton:
        return BillingType.variable;
    }
  }

  // Get price based on membership
  double getPrice(bool isMember) {
    return isMember ? priceMember : priceNonMember;
  }

  // Get localized name
  String getLocalizedName(String locale) {
    if (locale == 'te' && nameTe != null && nameTe!.isNotEmpty) {
      return nameTe!;
    }
    return nameEn;
  }
}

// Crop options for equipment that requires crop selection
class CropOption {
  final String nameEn;
  final String nameTe;
  final String? imageUrl;

  const CropOption({
    required this.nameEn,
    required this.nameTe,
    this.imageUrl,
  });

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
    if (equipment!.billingType == BillingType.fixed && landSizeAcres <= 0) return false;
    return true;
  }

  // Get booking status based on billing type
  String get bookingStatus {
    if (equipment == null) return 'Pending';
    return equipment!.billingType == BillingType.variable ? 'Slot Booked' : 'Confirmed';
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
    );
  }
}

// Main Screen
class CHCBookingScreen extends StatefulWidget {
  const CHCBookingScreen({super.key});

  @override
  State<CHCBookingScreen> createState() => _CHCBookingScreenState();
}

class _CHCBookingScreenState extends State<CHCBookingScreen>
    with SingleTickerProviderStateMixin {
  late CHCBookingState _state;
  bool _isSubmitting = false;
  late AnimationController _animationController;

  // Crop options for equipment that requires crop selection
  static const List<CropOption> _cropOptions = [
    CropOption(
      nameEn: 'Paddy',
      nameTe: 'వరి',
      imageUrl: 'https://kiosk.cropsync.in/custom_hiring_center/crops/paddy.png',
    ),
    CropOption(
      nameEn: 'Cotton',
      nameTe: 'పత్తి',
      imageUrl: 'https://kiosk.cropsync.in/custom_hiring_center/crops/cotton.png',
    ),
    CropOption(
      nameEn: 'Sunflower',
      nameTe: 'పొద్దుతిరుగుడు',
      imageUrl: 'https://kiosk.cropsync.in/custom_hiring_center/crops/sunflower.png',
    ),
    CropOption(
      nameEn: 'Banana',
      nameTe: 'అరటి',
      imageUrl: 'https://kiosk.cropsync.in/custom_hiring_center/crops/banana.png',
    ),
    CropOption(
      nameEn: 'Turmeric',
      nameTe: 'పసుపు',
      imageUrl: 'https://kiosk.cropsync.in/custom_hiring_center/crops/turmeric.png',
    ),
    CropOption(
      nameEn: 'Chilli',
      nameTe: 'మిర్చి',
      imageUrl: 'https://kiosk.cropsync.in/custom_hiring_center/crops/chilli.png',
    ),
    CropOption(
      nameEn: 'Maize',
      nameTe: 'మొక్కజొన్న',
      imageUrl: 'https://kiosk.cropsync.in/custom_hiring_center/crops/maize.png',
    ),
    CropOption(
      nameEn: 'Groundnut',
      nameTe: 'వేరుశెనగ',
      imageUrl: 'https://kiosk.cropsync.in/custom_hiring_center/crops/groundnut.png',
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
  ];

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getEquipmentName(Equipment equipment) {
    final locale = context.locale.languageCode;
    return equipment.getLocalizedName(locale);
  }

  void _updateState(CHCBookingState newState) {
    setState(() => _state = newState);
    HapticFeedback.lightImpact();
  }

  Future<void> _submitBooking() async {
    if (!_state.isValid) {
      _showSnackBar(context.tr('chc_validation_message'), isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final currentUser = AuthService.currentUser;
      final userId = currentUser?.userId ?? '';

      if (userId.isEmpty) {
        _showSnackBar(context.tr('login_required'), isError: true);
        setState(() => _isSubmitting = false);
        return;
      }

      // Generate booking ID with format: CSC-DDMM-XXX
      final now = DateTime.now();
      final bookingId =
          'CSC-${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}-${(now.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0')}';

      final result = await ApiService.createCHCBooking(
        bookingId: bookingId,
        userId: userId,
        equipmentType: _state.equipment!.nameEn,
        cropType: _state.selectedCrop?.nameEn,
        acres: _state.landSizeAcres,
        serviceDate: _state.serviceDate,
        ratePerAcre: _state.equipment!.getPrice(_state.isMember),
        totalCost: _state.equipment!.billingType == BillingType.fixed 
            ? _state.totalCost 
            : 0, // Variable billing has 0 total until service completion
      );

      if (!mounted) return;

      if (result['success'] == true) {
        await _showSuccessDialog(bookingId);
        setState(() {
          _state = CHCBookingState(
            serviceDate: DateTime.now().add(const Duration(days: 1)),
            isMember: _state.isMember,
          );
        });
      } else {
        _showSnackBar(result['error'] ?? context.tr('error_booking'),
            isError: true);
      }
    } catch (e) {
      _showSnackBar(context.tr('error_booking'), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

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
    
    final isVariableBilling = _state.equipment!.billingType == BillingType.variable;
    final totalValue = isVariableBilling 
        ? context.tr('chc_bill_pending')
        : '₹${_state.totalCost.toStringAsFixed(0)}';

    return showDialog(
      context: context,
      barrierDismissible: false,
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
                  color: isVariableBilling 
                      ? CHCTheme.slotBooked.withOpacity(0.1)
                      : CHCTheme.accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVariableBilling ? Icons.event_available : Icons.check_circle,
                  size: 48,
                  color: isVariableBilling ? CHCTheme.slotBooked : CHCTheme.accent,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isVariableBilling 
                    ? context.tr('chc_slot_booked_title')
                    : context.tr('chc_success_title'),
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: CHCTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isVariableBilling
                    ? context.tr('chc_slot_booked_subtitle')
                    : context.tr('chc_success_subtitle'),
                style: const TextStyle(
                    fontSize: 14, color: CHCTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
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
                        style: TextStyle(
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
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: isVariableBilling 
                        ? CHCTheme.slotBooked 
                        : CHCTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    context.tr('done'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.currentUser;
    final locale = context.locale.languageCode;

    return Scaffold(
      backgroundColor: CHCTheme.surface,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: _buildHeader(currentUser),
              ),
              // Equipment Grid
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.grid_view_rounded,
                              size: 20, color: CHCTheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            context.tr('chc_select_equipment'),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: CHCTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final equipment = _equipmentList[index];
                      return _EquipmentCard(
                        equipment: equipment,
                        isSelected: _state.equipment?.id == equipment.id,
                        isMember: _state.isMember,
                        onTap: () => _updateState(
                          _state.copyWith(
                            equipment: equipment,
                            clearCrop: true,
                          ),
                        ),
                        equipmentName: _getEquipmentName(equipment),
                        locale: locale,
                      );
                    },
                    childCount: _equipmentList.length,
                  ),
                ),
              ),
              // Crop Selection (if required)
              if (_state.equipment?.requiresCropSelection == true)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _CropSelector(
                      crops: _cropOptions,
                      selectedCrop: _state.selectedCrop,
                      onSelect: (crop) => _updateState(
                        _state.copyWith(selectedCrop: crop),
                      ),
                      locale: locale,
                    ),
                  ),
                ),
              // Land Size / Quantity Slider
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _QuantitySlider(
                    value: _state.landSizeAcres,
                    equipment: _state.equipment,
                    isMember: _state.isMember,
                    onChanged: (v) =>
                        _updateState(_state.copyWith(landSizeAcres: v)),
                    locale: locale,
                  ),
                ),
              ),
              // Date Selector
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 20, color: CHCTheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            context.tr('chc_select_date'),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: CHCTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _DateSelector(
                        selected: _state.serviceDate,
                        onSelect: (d) =>
                            _updateState(_state.copyWith(serviceDate: d)),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom spacing for fixed bottom bar
              const SliverPadding(padding: EdgeInsets.only(bottom: 180)),
            ],
          ),
          // Bottom Bar
          _BottomBar(
            state: _state,
            isSubmitting: _isSubmitting,
            onSubmit: _submitBooking,
            getEquipmentName: _getEquipmentName,
            locale: locale,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(dynamic currentUser) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('chc_title'),
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${context.tr('farmer')}: ${currentUser?.name ?? 'Guest'}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              // Membership badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _state.isMember 
                      ? CHCTheme.memberBadge.withOpacity(0.2)
                      : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _state.isMember 
                        ? CHCTheme.memberBadge 
                        : Colors.white70,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _state.isMember 
                            ? CHCTheme.memberBadge 
                            : Colors.white70,
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
}

// Equipment Card Widget - Updated with member price badge
class _EquipmentCard extends StatelessWidget {
  final Equipment equipment;
  final bool isSelected;
  final bool isMember;
  final VoidCallback onTap;
  final String equipmentName;
  final String locale;

  const _EquipmentCard({
    required this.equipment,
    required this.isSelected,
    required this.isMember,
    required this.onTap,
    required this.equipmentName,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final price = equipment.getPrice(isMember);
    final unitName = equipment.unit.getLocalizedName(locale);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected
              ? equipment.accentColor.withOpacity(0.1)
              : CHCTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? equipment.accentColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: equipment.accentColor.withOpacity(0.2),
                    blurRadius: 12,
                    spreadRadius: 2,
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                  )
                ],
        ),
        child: Stack(
          children: [
            // Member price badge
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: CHCTheme.memberBadge,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  context.tr('member_price'),
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Equipment Image
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? equipment.accentColor.withOpacity(0.1)
                        : CHCTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: equipment.imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: equipment.accentColor,
                        ),
                      ),
                      errorWidget: (context, url, error) => Icon(
                        Icons.agriculture,
                        size: 36,
                        color: equipment.accentColor,
                      ),
                    ),
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
                      color:
                          isSelected ? equipment.accentColor : CHCTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                // Rate per unit
                Text(
                  '₹${price.toStringAsFixed(0)} / $unitName',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? equipment.accentColor.withOpacity(0.8)
                        : CHCTheme.accent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Crop Selector Widget
class _CropSelector extends StatelessWidget {
  final List<CropOption> crops;
  final CropOption? selectedCrop;
  final ValueChanged<CropOption> onSelect;
  final String locale;

  const _CropSelector({
    required this.crops,
    required this.selectedCrop,
    required this.onSelect,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.grass, size: 20, color: CHCTheme.primary),
            const SizedBox(width: 8),
            Text(
              context.tr('chc_select_crop'),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CHCTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
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
                      color: isSelected ? CHCTheme.primary : Colors.grey.shade200,
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
                          color: isSelected ? Colors.white : CHCTheme.textPrimary,
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
          ),
        ),
      ],
    );
  }
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
    final unitName = equipment?.unit.getLocalizedName(locale) ?? context.tr('acres');
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
                      color: isVariableBilling ? CHCTheme.slotBooked : CHCTheme.accent,
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
    final isVariableBilling = state.equipment?.billingType == BillingType.variable;
    final rate = state.equipment?.getPrice(state.isMember) ?? 0;
    final unitName = state.equipment?.unit.getLocalizedName(locale) ?? '';

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
              color: CHCTheme.surfaceCard.withOpacity(0.95),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Selected equipment info
                  if (state.equipment != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: state.equipment!.accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: state.equipment!.imageUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.contain,
                              errorWidget: (context, url, error) => Icon(
                                Icons.agriculture,
                                color: state.equipment!.accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  getEquipmentName(state.equipment!),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: state.equipment!.accentColor,
                                  ),
                                ),
                                Text(
                                  '${state.landSizeAcres.toStringAsFixed(1)} ${context.tr('acres')} × ₹${rate.toStringAsFixed(0)}/$unitName',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: CHCTheme.textSecondary,
                                  ),
                                ),
                                if (state.selectedCrop != null)
                                  Text(
                                    '${context.tr('crop')}: ${state.selectedCrop!.getLocalizedName(locale)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: CHCTheme.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.tr('total_cost_label'),
                              style: const TextStyle(
                                  fontSize: 13, color: CHCTheme.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            if (isVariableBilling)
                              Text(
                                context.tr('chc_bill_pending'),
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: CHCTheme.slotBooked,
                                ),
                              )
                            else
                              Text(
                                '₹${state.totalCost.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: CHCTheme.textPrimary,
                                ),
                              ),
                            if (isVariableBilling)
                              Text(
                                context.tr('chc_after_service'),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: CHCTheme.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
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
                        ),
                      ),
                    ],
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

// Detail Row Widget for Success Dialog
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: CHCTheme.textSecondary),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: CHCTheme.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
