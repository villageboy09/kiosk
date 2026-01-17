// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

// ============================================================================
// DESIGN SYSTEM
// ============================================================================
class CHCTheme {
  static const primary = Color(0xFF00A699);
  static const primaryDark = Color(0xFF008C81);
  static const accent = Color(0xFFFF385C);
  static const bg = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE0E0E0);
  static const warning = Color(0xFF856404);
  static const warningBg = Color(0xFFFFF3CD);
  static const errorBg = Color(0xFFFFEBEE);
  static const errorText = Color(0xFFC62828);
  static const memberBadge = Color(0xFFFFD700);
  static const slotBooked = Color(0xFFFFA000);

  // Responsive breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;

  // Spacing
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;

  // Border radius
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
}

// ============================================================================
// EQUIPMENT MODEL
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

  bool get requiresCropSelection =>
      nameEn.toLowerCase().contains('drone') ||
      nameEn.toLowerCase().contains('spray');

  bool get isTrolley =>
      unit == 'Trip' || nameEn.toLowerCase().contains('trolley');

  String get billingType => unit == 'Acre' ? 'Fixed' : 'Variable';

  String getBookingStatus() {
    if (billingType == 'Variable') return 'Slot Booked';
    if (requiresCropSelection) return 'Slot Booked';
    return 'Confirmed';
  }

  String getDisplayName(String locale) {
    if (locale == 'te' && nameTe != null && nameTe!.isNotEmpty) return nameTe!;
    return nameEn;
  }
}

// ============================================================================
// CROP MODEL
// ============================================================================
class Crop {
  final int id;
  final String name;
  final String? imageUrl;

  Crop({required this.id, required this.name, this.imageUrl});

  factory Crop.fromJson(Map<String, dynamic> json) {
    return Crop(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      imageUrl: json['image_url'],
    );
  }
}

// ============================================================================
// BOOKING STATE
// ============================================================================
class CHCBookingState {
  final Equipment? equipment;
  final Crop? crop;
  final double acres;
  final DateTime? serviceDate;
  final bool isMember;
  final Map<String, bool> fullyBookedDates;

  CHCBookingState({
    this.equipment,
    this.crop,
    this.acres = 1.0,
    this.serviceDate,
    this.isMember = false,
    Map<String, bool>? fullyBookedDates,
  }) : fullyBookedDates = fullyBookedDates ?? {};

  double get totalCost {
    if (equipment == null) return 0;
    if (equipment!.billingType == 'Variable') return 0;
    return acres * equipment!.displayPrice;
  }

  bool get isValid {
    if (equipment == null) return false;
    if (serviceDate == null) return false;
    if (equipment!.requiresCropSelection && crop == null) return false;
    if (acres <= 0) return false;
    return true;
  }

  String getOperatorNotes() {
    if (equipment == null) return '';
    if (equipment!.billingType == 'Variable') {
      String note =
          'Variable Billing: Final bill based on actual ${equipment!.unit}';
      if (equipment!.isTrolley) note += ' (Note: Valid up to 5km only)';
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

  static const List<String> _monthNamesTe = [
    'జనవరి',
    'ఫిబ్రవరి',
    'మార్చి',
    'ఏప్రిల్',
    'మే',
    'జూన్',
    'జూలై',
    'ఆగస్టు',
    'సెప్టెంబర్',
    'అక్టోబర్',
    'నవంబర్',
    'డిసెంబర్'
  ];

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    final currentUser = AuthService.currentUser;
    // Check membership via card_uid: if null/empty, user has no membership
    final isMember =
        currentUser?.cardUid != null && currentUser!.cardUid!.isNotEmpty;
    _state = CHCBookingState(isMember: isMember);
    _loadData();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final equipmentsData =
          await ApiService.getCHCEquipments(isMember: _state.isMember);
      _equipments = equipmentsData.map((e) => Equipment.fromJson(e)).toList();
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
        if (d['is_full'] == true) fullyBooked[d['date']] = true;
      }
      if (mounted) {
        setState(() => _state = _state.copyWith(fullyBookedDates: fullyBooked));
      }
    } catch (e) {
      debugPrint('Error loading booked dates: $e');
    }
  }

  void _selectEquipment(Equipment equipment) {
    HapticFeedback.lightImpact();
    setState(() {
      _state = _state.copyWith(
          equipment: equipment, clearCrop: true, clearDate: true);
    });
    _loadBookedDates();
  }

  void _selectCrop(Crop crop) {
    HapticFeedback.lightImpact();
    setState(() => _state = _state.copyWith(crop: crop));
  }

  void _selectDate(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    if (_state.fullyBookedDates[dateStr] == true) {
      _showFullyBookedError();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _state = _state.copyWith(serviceDate: date));
  }

  void _changeAcres(double delta) {
    final newValue = _state.acres + delta;
    if (newValue >= 0.5 && newValue <= 100) {
      HapticFeedback.lightImpact();
      setState(() => _state = _state.copyWith(acres: newValue));
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _calendarMonth =
          DateTime(_calendarMonth.year, _calendarMonth.month + delta);
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

      final availability = await ApiService.checkEquipmentAvailability(
        equipmentName: _state.equipment!.nameEn,
        serviceDate: dateStr,
      );

      if (availability['can_book'] != true) {
        setState(() => _isSubmitting = false);
        _showFullyBookedError(message: availability['message']);
        return;
      }

      final now = DateTime.now();
      final bookingId =
          'CSC-${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}-${(now.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0')}';

      final billingType = _state.equipment!.billingType;
      final bookingStatus = _state.equipment!.getBookingStatus();
      final billedQty = billingType == 'Fixed' ? _state.acres : 0.0;
      final totalCost = billingType == 'Fixed' ? _state.totalCost : 0.0;

      final result = await ApiService.createCHCBooking(
        bookingId: bookingId,
        userId: userId,
        equipmentType: _state.equipment!.nameEn,
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
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _confettiController.play();
        await _showSuccessDialog(
            bookingId: bookingId,
            billingType: billingType,
            totalCost: totalCost);
        setState(() => _state = CHCBookingState(isMember: _state.isMember));
      } else {
        _showErrorSnackBar(result['error'] ?? 'Booking failed');
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showFullyBookedError({String? message}) {
    showDialog(
      context: context,
      builder: (ctx) => _ErrorDialog(
        equipment: _state.equipment,
        locale: context.locale.languageCode,
        message: message,
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }

  Future<void> _showSuccessDialog({
    required String bookingId,
    required String billingType,
    required double totalCost,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SuccessDialog(
        bookingId: bookingId,
        billingType: billingType,
        totalCost: totalCost,
        state: _state,
        confettiController: _confettiController,
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: CHCTheme.errorText,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CHCTheme.radiusMd)),
        margin: const EdgeInsets.all(CHCTheme.spacingMd),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: CHCTheme.bg,
        body: Center(child: CircularProgressIndicator(color: CHCTheme.primary)),
      );
    }

    return Scaffold(
      backgroundColor: CHCTheme.bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= CHCTheme.mobileBreakpoint;
          return isWide ? _buildWideLayout(constraints) : _buildNarrowLayout();
        },
      ),
    );
  }

  // ==================== NARROW LAYOUT (Mobile) ====================
  Widget _buildNarrowLayout() {
    final locale = context.locale.languageCode;
    final currentUser = AuthService.currentUser;

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                  child: _CHCHeader(state: _state, currentUser: currentUser)),
              _buildEquipmentSection(locale),
              if (_state.equipment?.requiresCropSelection == true)
                _buildCropSection(),
              _buildAcresSection(),
              _buildCalendarSection(),
              const SliverPadding(
                  padding: EdgeInsets.only(bottom: CHCTheme.spacingMd)),
            ],
          ),
        ),
        _CHCSummaryBar(
          state: _state,
          isSubmitting: _isSubmitting,
          onSubmit: _submitBooking,
        ),
      ],
    );
  }

  // ==================== WIDE LAYOUT (Tablet/Desktop) ====================
  Widget _buildWideLayout(BoxConstraints constraints) {
    final locale = context.locale.languageCode;
    final currentUser = AuthService.currentUser;

    return Row(
      children: [
        // Left panel - Equipment & Date selection
        Expanded(
          flex: 3,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                  child: _CHCHeader(state: _state, currentUser: currentUser)),
              _buildEquipmentSection(locale),
              if (_state.equipment?.requiresCropSelection == true)
                _buildCropSection(),
              _buildAcresSection(),
              _buildCalendarSection(),
              const SliverPadding(
                  padding: EdgeInsets.only(bottom: CHCTheme.spacingXl)),
            ],
          ),
        ),
        // Right panel - Summary
        Container(
          width: 360,
          decoration: BoxDecoration(
            color: CHCTheme.surface,
            border: Border(
                left: BorderSide(color: CHCTheme.border.withOpacity(0.5))),
          ),
          child: _CHCSummaryPanel(
            state: _state,
            isSubmitting: _isSubmitting,
            onSubmit: _submitBooking,
          ),
        ),
      ],
    );
  }

  // ==================== SECTION BUILDERS ====================
  SliverPadding _buildEquipmentSection(String locale) {
    return SliverPadding(
      padding: const EdgeInsets.all(CHCTheme.spacingMd),
      sliver: SliverToBoxAdapter(
        child: _CHCCard(
          title: 'యంత్రాన్ని ఎంచుకోండి (Select Equipment)',
          icon: Icons.grid_view_rounded,
          child: _CHCEquipmentGrid(
            equipments: _equipments,
            selected: _state.equipment,
            isMember: _state.isMember,
            locale: locale,
            onSelect: _selectEquipment,
          ),
        ),
      ),
    );
  }

  SliverPadding _buildCropSection() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: CHCTheme.spacingMd),
      sliver: SliverToBoxAdapter(
        child: _CHCCard(
          title: 'పంట రకం (Select Crop)',
          icon: Icons.grass,
          child: _CHCCropSelector(
            crops: _crops,
            selected: _state.crop,
            onSelect: _selectCrop,
          ),
        ),
      ),
    );
  }

  SliverPadding _buildAcresSection() {
    return SliverPadding(
      padding: const EdgeInsets.all(CHCTheme.spacingMd),
      sliver: SliverToBoxAdapter(
        child: _CHCCard(
          title: 'పొలం విస్తీర్ణం (Land Size)',
          icon: Icons.straighten,
          child: _CHCAcresCounter(
            acres: _state.acres,
            equipment: _state.equipment,
            onChanged: _changeAcres,
          ),
        ),
      ),
    );
  }

  SliverPadding _buildCalendarSection() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: CHCTheme.spacingMd),
      sliver: SliverToBoxAdapter(
        child: _CHCCard(
          title: 'తేదీని ఎంచుకోండి (Select Date)',
          icon: Icons.calendar_today,
          child: _CHCCalendar(
            calendarMonth: _calendarMonth,
            serviceDate: _state.serviceDate,
            fullyBookedDates: _state.fullyBookedDates,
            monthNamesTe: _monthNamesTe,
            onSelectDate: _selectDate,
            onChangeMonth: _changeMonth,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// REUSABLE COMPONENTS
// ============================================================================

// ---------------------------- Header ----------------------------
class _CHCHeader extends StatelessWidget {
  final CHCBookingState state;
  final dynamic currentUser;

  const _CHCHeader({required this.state, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        CHCTheme.spacingLg,
        MediaQuery.of(context).padding.top + CHCTheme.spacingMd,
        CHCTheme.spacingLg,
        CHCTheme.spacingLg,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [CHCTheme.primary, CHCTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(CHCTheme.radiusXl),
          bottomRight: Radius.circular(CHCTheme.radiusXl),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _BackButton(),
              const SizedBox(width: CHCTheme.spacingMd),
              const Icon(Icons.agriculture, color: Colors.white, size: 28),
              const SizedBox(width: CHCTheme.spacingSm),
              Expanded(
                child: Text(
                  'క్రాప్సింక్ CHC',
                  style: GoogleFonts.notoSansTelugu(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: CHCTheme.spacingSm),
          Text(
            'రైతు: ${currentUser?.name ?? 'Guest'} (${currentUser?.village ?? ''})',
            style:
                GoogleFonts.notoSansTelugu(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: CHCTheme.spacingSm),
          _MemberBadge(isMember: state.isMember),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.all(CHCTheme.spacingSm),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(CHCTheme.radiusMd),
        ),
        child: const Icon(Icons.arrow_back, color: Colors.white),
      ),
    );
  }
}

class _MemberBadge extends StatelessWidget {
  final bool isMember;
  const _MemberBadge({required this.isMember});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(CHCTheme.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMember)
            const Icon(Icons.star, color: CHCTheme.memberBadge, size: 16),
          if (isMember) const SizedBox(width: 4),
          Text(
            isMember ? 'సభ్యులు (Member)' : 'సభ్యత్వం లేదు',
            style: GoogleFonts.notoSansTelugu(
                fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ---------------------------- Card ----------------------------
class _CHCCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _CHCCard(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: CHCTheme.spacingMd),
      padding: const EdgeInsets.all(CHCTheme.spacingLg),
      decoration: BoxDecoration(
        color: CHCTheme.surface,
        borderRadius: BorderRadius.circular(CHCTheme.radiusLg),
        border: Border.all(color: CHCTheme.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: CHCTheme.primaryDark, size: 20),
              const SizedBox(width: 10),
              Text(title,
                  style: GoogleFonts.notoSansTelugu(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: CHCTheme.primaryDark)),
            ],
          ),
          const SizedBox(height: CHCTheme.spacingMd),
          child,
        ],
      ),
    );
  }
}

// ---------------------------- Equipment Grid ----------------------------
class _CHCEquipmentGrid extends StatelessWidget {
  final List<Equipment> equipments;
  final Equipment? selected;
  final bool isMember;
  final String locale;
  final ValueChanged<Equipment> onSelect;

  const _CHCEquipmentGrid({
    required this.equipments,
    required this.selected,
    required this.isMember,
    required this.locale,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive: max 180px per item, adapts 2-5 columns
        final crossAxisCount = (constraints.maxWidth / 160).floor().clamp(2, 5);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: CHCTheme.spacingMd,
            crossAxisSpacing: CHCTheme.spacingMd,
            childAspectRatio: 0.82,
          ),
          itemCount: equipments.length,
          itemBuilder: (ctx, i) {
            final eq = equipments[i];
            final isSelected = selected?.id == eq.id;
            return _EquipmentCard(
              equipment: eq,
              isSelected: isSelected,
              isMember: isMember,
              locale: locale,
              onTap: () => onSelect(eq),
            );
          },
        );
      },
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  final Equipment equipment;
  final bool isSelected;
  final bool isMember;
  final String locale;
  final VoidCallback onTap;

  const _EquipmentCard({
    required this.equipment,
    required this.isSelected,
    required this.isMember,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE6FCF9) : Colors.white,
          borderRadius: BorderRadius.circular(CHCTheme.radiusLg),
          border: Border.all(
              color: isSelected ? CHCTheme.primary : CHCTheme.border,
              width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: CHCTheme.primary.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2)
                ]
              : null,
        ),
        child: Stack(
          children: [
            if (isMember)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                      color: CHCTheme.memberBadge,
                      borderRadius: BorderRadius.circular(6)),
                  child: Text('సభ్యుల ధర',
                      style: GoogleFonts.notoSansTelugu(
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF333333))),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(CHCTheme.spacingSm),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: CachedNetworkImage(
                      imageUrl: equipment.image.startsWith('http')
                          ? equipment.image
                          : 'https://kiosk.cropsync.in/custom_hiring_center/${equipment.image}',
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      errorWidget: (_, __, ___) => const Icon(Icons.agriculture,
                          size: 40, color: CHCTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: CHCTheme.spacingXs),
                  Text(
                    equipment.getDisplayName(locale),
                    style: GoogleFonts.notoSansTelugu(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? CHCTheme.primary : CHCTheme.text),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: CHCTheme.spacingXs),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: CHCTheme.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                        '₹${equipment.displayPrice.toStringAsFixed(0)}/${equipment.unit}',
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: CHCTheme.accent)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------- Crop Selector ----------------------------
class _CHCCropSelector extends StatelessWidget {
  final List<Crop> crops;
  final Crop? selected;
  final ValueChanged<Crop> onSelect;

  const _CHCCropSelector(
      {required this.crops, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: crops.length,
        separatorBuilder: (_, __) => const SizedBox(width: CHCTheme.spacingSm),
        itemBuilder: (ctx, i) {
          final crop = crops[i];
          final isSelected = selected?.id == crop.id;
          return GestureDetector(
            onTap: () => onSelect(crop),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 75,
              decoration: BoxDecoration(
                color: isSelected ? CHCTheme.primary : Colors.white,
                borderRadius: BorderRadius.circular(CHCTheme.radiusMd),
                border: Border.all(
                    color: isSelected ? CHCTheme.primary : CHCTheme.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (crop.imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(CHCTheme.radiusSm),
                      child: CachedNetworkImage(
                          imageUrl: crop.imageUrl!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Icon(Icons.grass,
                              color: isSelected
                                  ? Colors.white
                                  : CHCTheme.primary)),
                    )
                  else
                    Icon(Icons.grass,
                        color: isSelected ? Colors.white : CHCTheme.primary,
                        size: 32),
                  const SizedBox(height: 4),
                  Text(crop.name,
                      style: GoogleFonts.notoSansTelugu(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : CHCTheme.text),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------- Acres Counter ----------------------------
class _CHCAcresCounter extends StatelessWidget {
  final double acres;
  final Equipment? equipment;
  final ValueChanged<double> onChanged;

  const _CHCAcresCounter(
      {required this.acres, this.equipment, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (equipment != null && equipment!.billingType == 'Variable')
          _VariableBillingWarning(equipment: equipment!),
        if (equipment?.isTrolley == true) _TrolleyWarning(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CounterButton(icon: Icons.remove, onTap: () => onChanged(-0.5)),
            const SizedBox(width: CHCTheme.spacingLg),
            Column(
              children: [
                Text(acres.toStringAsFixed(1),
                    style: GoogleFonts.poppins(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: CHCTheme.text)),
                Text('ఎకరాలు (Acres)',
                    style: GoogleFonts.notoSansTelugu(
                        fontSize: 12, color: CHCTheme.textSecondary)),
              ],
            ),
            const SizedBox(width: CHCTheme.spacingLg),
            _CounterButton(icon: Icons.add, onTap: () => onChanged(0.5)),
          ],
        ),
      ],
    );
  }
}

class _VariableBillingWarning extends StatelessWidget {
  final Equipment equipment;
  const _VariableBillingWarning({required this.equipment});

  String _getRateText() {
    final rate = equipment.displayPrice.toStringAsFixed(0);
    switch (equipment.unit) {
      case 'Hour':
        return 'గంటకు ఛార్జీ (₹$rate/hr)';
      case 'Bale':
        return 'బేల్ కు ఛార్జీ (₹$rate/bale)';
      case 'Trip':
        return 'ట్రిప్పు కు ఛార్జీ (₹$rate/trip)';
      case 'Ton':
        return 'టన్ కు ఛార్జీ (₹$rate/ton)';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CHCTheme.spacingSm),
      margin: const EdgeInsets.only(bottom: CHCTheme.spacingMd),
      decoration: BoxDecoration(
          color: CHCTheme.warningBg,
          borderRadius: BorderRadius.circular(CHCTheme.radiusSm),
          border: Border.all(color: const Color(0xFFFFEEBA))),
      child: Text(_getRateText(),
          style: GoogleFonts.notoSansTelugu(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CHCTheme.warning),
          textAlign: TextAlign.center),
    );
  }
}

class _TrolleyWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CHCTheme.spacingSm),
      margin: const EdgeInsets.only(bottom: CHCTheme.spacingMd),
      decoration: BoxDecoration(
          color: CHCTheme.errorBg,
          borderRadius: BorderRadius.circular(CHCTheme.radiusSm),
          border: Border.all(color: const Color(0xFFFFCDD2))),
      child: Text('⚠️ 5 కి.మీ పరిధి వరకు మాత్రమే వర్తిస్తుంది',
          style: GoogleFonts.notoSansTelugu(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CHCTheme.errorText),
          textAlign: TextAlign.center),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CounterButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8)
            ]),
        child: Icon(icon, color: CHCTheme.primary, size: 22),
      ),
    );
  }
}

// ---------------------------- Calendar ----------------------------
class _CHCCalendar extends StatelessWidget {
  final DateTime calendarMonth;
  final DateTime? serviceDate;
  final Map<String, bool> fullyBookedDates;
  final List<String> monthNamesTe;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<int> onChangeMonth;

  const _CHCCalendar({
    required this.calendarMonth,
    this.serviceDate,
    required this.fullyBookedDates,
    required this.monthNamesTe,
    required this.onSelectDate,
    required this.onChangeMonth,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth =
        DateTime(calendarMonth.year, calendarMonth.month + 1, 0).day;
    final firstDayOfMonth =
        DateTime(calendarMonth.year, calendarMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday % 7;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                '${monthNamesTe[calendarMonth.month - 1]} ${calendarMonth.year}',
                style: GoogleFonts.notoSansTelugu(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            Row(
              children: [
                IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => onChangeMonth(-1)),
                IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => onChangeMonth(1)),
              ],
            ),
          ],
        ),
        const SizedBox(height: CHCTheme.spacingSm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['ఆ', 'సో', 'మం', 'బు', 'గు', 'శు', 'శ']
              .map((d) => Expanded(
                  child: Text(d,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12))))
              .toList(),
        ),
        const SizedBox(height: CHCTheme.spacingSm),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6),
          itemCount: startingWeekday + daysInMonth,
          itemBuilder: (ctx, index) {
            if (index < startingWeekday) return const SizedBox();
            final day = index - startingWeekday + 1;
            final date = DateTime(calendarMonth.year, calendarMonth.month, day);
            final dateStr = DateFormat('yyyy-MM-dd').format(date);
            final isPast =
                date.isBefore(DateTime(now.year, now.month, now.day));
            final isSelected = serviceDate != null &&
                date.year == serviceDate!.year &&
                date.month == serviceDate!.month &&
                date.day == serviceDate!.day;
            final isFullyBooked = fullyBookedDates[dateStr] == true;

            return GestureDetector(
              onTap: isPast ? null : () => onSelectDate(date),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? CHCTheme.primary
                      : isPast
                          ? const Color(0xFFF5F5F5)
                          : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: isFullyBooked
                          ? CHCTheme.accent
                          : isSelected
                              ? CHCTheme.primary
                              : const Color(0xFFEEEEEE),
                      width: isFullyBooked ? 2 : 1),
                ),
                child: Center(
                  child: Text(
                    day.toString(),
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? Colors.white
                          : isPast
                              ? Colors.grey.shade400
                              : isFullyBooked
                                  ? CHCTheme.accent
                                  : CHCTheme.text,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
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
}

// ---------------------------- Summary Bar (Mobile) ----------------------------
class _CHCSummaryBar extends StatelessWidget {
  final CHCBookingState state;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _CHCSummaryBar(
      {required this.state,
      required this.isSubmitting,
      required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final isVariableBilling = state.equipment?.billingType == 'Variable';
    final totalDisplay = isVariableBilling
        ? 'పెండింగ్'
        : '₹${state.totalCost.toStringAsFixed(0)}';
    final buttonText = state.equipment == null
        ? 'యంత్రం ఎంచుకోండి'
        : (state.equipment!.billingType == 'Fixed'
            ? 'బుకింగ్ నిర్ధారించండి'
            : 'స్లాట్ బుక్ చేయండి');

    return Container(
      padding: EdgeInsets.fromLTRB(
          CHCTheme.spacingMd,
          CHCTheme.spacingSm,
          CHCTheme.spacingMd,
          MediaQuery.of(context).padding.bottom + CHCTheme.spacingSm),
      decoration: BoxDecoration(
        color: CHCTheme.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('మొత్తం:',
                    style: GoogleFonts.notoSansTelugu(
                        fontSize: 12, color: CHCTheme.textSecondary)),
                Text(totalDisplay,
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isVariableBilling
                            ? CHCTheme.warning
                            : CHCTheme.primary)),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: state.isValid && !isSubmitting ? onSubmit : null,
              style: FilledButton.styleFrom(
                backgroundColor: CHCTheme.primary,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CHCTheme.radiusMd)),
                padding:
                    const EdgeInsets.symmetric(horizontal: CHCTheme.spacingLg),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(buttonText,
                      style: GoogleFonts.notoSansTelugu(
                          fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------- Summary Panel (Desktop) ----------------------------
class _CHCSummaryPanel extends StatelessWidget {
  final CHCBookingState state;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _CHCSummaryPanel(
      {required this.state,
      required this.isSubmitting,
      required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final equipmentName =
        state.equipment?.getDisplayName(locale) ?? 'ఎంచుకోండి';
    final rate = state.equipment != null
        ? '₹${state.equipment!.displayPrice.toStringAsFixed(0)}/${state.equipment!.unit}'
        : '-';
    final dateStr = state.serviceDate != null
        ? DateFormat('dd MMM yyyy').format(state.serviceDate!)
        : '-';
    final isVariableBilling = state.equipment?.billingType == 'Variable';
    final totalDisplay = isVariableBilling
        ? 'బిల్లు పెండింగ్'
        : '₹${state.totalCost.toStringAsFixed(0)}';
    final buttonText = state.equipment == null
        ? 'యంత్రం ఎంచుకోండి'
        : (state.equipment!.billingType == 'Fixed'
            ? 'బుకింగ్ నిర్ధారించండి (Confirm)'
            : 'స్లాట్ బుక్ చేయండి (Book Slot)');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(CHCTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('బుకింగ్ సమ్మరీ',
                style: GoogleFonts.notoSansTelugu(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: CHCTheme.primaryDark)),
            const SizedBox(height: CHCTheme.spacingLg),
            _SummaryRow(label: 'యంత్రం', value: equipmentName, highlight: true),
            if (state.equipment?.requiresCropSelection == true)
              _SummaryRow(label: 'పంట', value: state.crop?.name ?? '-'),
            _SummaryRow(label: 'ధర (Rate)', value: rate),
            _SummaryRow(label: 'విస్తీర్ణం', value: '${state.acres} ఎకరాలు'),
            _SummaryRow(label: 'సేవ తేదీ', value: dateStr),
            const Divider(height: CHCTheme.spacingXl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('మొత్తం:',
                    style: GoogleFonts.notoSansTelugu(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                Text(totalDisplay,
                    style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: isVariableBilling
                            ? CHCTheme.warning
                            : CHCTheme.primary)),
              ],
            ),
            if (isVariableBilling)
              Padding(
                padding: const EdgeInsets.only(top: CHCTheme.spacingXs),
                child: Text('* సేవ పూర్తయ్యాక బిల్లు వస్తుంది',
                    style: GoogleFonts.notoSansTelugu(
                        fontSize: 11, color: CHCTheme.warning)),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: state.isValid && !isSubmitting ? onSubmit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: CHCTheme.primary,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(CHCTheme.radiusMd)),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(buttonText,
                        style: GoogleFonts.notoSansTelugu(
                            fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _SummaryRow(
      {required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CHCTheme.spacingXs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.notoSansTelugu(
                  fontSize: 13, color: CHCTheme.textSecondary)),
          Flexible(
              child: Text(value,
                  style: GoogleFonts.notoSansTelugu(
                      fontSize: 13,
                      fontWeight:
                          highlight ? FontWeight.w600 : FontWeight.normal,
                      color: highlight ? CHCTheme.primary : CHCTheme.text),
                  textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

// ---------------------------- Dialogs ----------------------------
class _ErrorDialog extends StatelessWidget {
  final Equipment? equipment;
  final String locale;
  final String? message;
  final VoidCallback onClose;

  const _ErrorDialog(
      {this.equipment,
      required this.locale,
      this.message,
      required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CHCTheme.radiusXl)),
      child: Padding(
        padding: const EdgeInsets.all(CHCTheme.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                  color: CHCTheme.errorBg, shape: BoxShape.circle),
              child: const Icon(Icons.error_outline,
                  size: 40, color: CHCTheme.errorText),
            ),
            const SizedBox(height: CHCTheme.spacingMd),
            Text(equipment?.getDisplayName(locale) ?? '',
                style: GoogleFonts.notoSansTelugu(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: CHCTheme.text)),
            const SizedBox(height: CHCTheme.spacingSm),
            Text(
                message ??
                    'ఈ తేదీలో స్లాట్లు అన్నీ బుక్ అయిపోయాయి.\n(Fully Booked)',
                style: GoogleFonts.notoSansTelugu(
                    fontSize: 13, color: CHCTheme.errorText),
                textAlign: TextAlign.center),
            const SizedBox(height: CHCTheme.spacingLg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onClose,
                style: FilledButton.styleFrom(
                    backgroundColor: CHCTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(CHCTheme.radiusMd))),
                child: Text('వేరే తేదీ ఎంచుకోండి',
                    style: GoogleFonts.notoSansTelugu(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  final String bookingId;
  final String billingType;
  final double totalCost;
  final CHCBookingState state;
  final ConfettiController confettiController;
  final VoidCallback onClose;

  const _SuccessDialog({
    required this.bookingId,
    required this.billingType,
    required this.totalCost,
    required this.state,
    required this.confettiController,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final equipmentName = state.equipment!.getDisplayName(locale);
    final dateStr = DateFormat('dd MMM yyyy').format(state.serviceDate!);

    return Stack(
      children: [
        Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CHCTheme.radiusXl)),
          child: Padding(
            padding: const EdgeInsets.all(CHCTheme.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                      color: CHCTheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.check,
                      size: 40, color: CHCTheme.primary),
                ),
                const SizedBox(height: CHCTheme.spacingMd),
                Text('బుకింగ్ విజయవంతమైంది!',
                    style: GoogleFonts.notoSansTelugu(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: CHCTheme.primaryDark)),
                const SizedBox(height: CHCTheme.spacingSm),
                Text('Booking ID:',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Text(bookingId,
                    style: GoogleFonts.poppins(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: CHCTheme.spacingMd),
                Container(
                  padding: const EdgeInsets.all(CHCTheme.spacingMd),
                  decoration: BoxDecoration(
                      color: CHCTheme.bg,
                      borderRadius: BorderRadius.circular(CHCTheme.radiusMd)),
                  child: Column(
                    children: [
                      _ReceiptRow('యంత్రం:', equipmentName),
                      if (state.crop != null)
                        _ReceiptRow('పంట:', state.crop!.name),
                      _ReceiptRow('విస్తీర్ణం:', '${state.acres} ఎకరాలు'),
                      _ReceiptRow('తేదీ:', dateStr),
                      const Divider(height: CHCTheme.spacingMd),
                      _ReceiptRow(
                          'మొత్తం:',
                          billingType == 'Fixed'
                              ? '₹${totalCost.toStringAsFixed(0)}'
                              : 'బిల్లు పెండింగ్',
                          isTotal: true,
                          isPending: billingType != 'Fixed'),
                    ],
                  ),
                ),
                const SizedBox(height: CHCTheme.spacingLg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onClose,
                    style: FilledButton.styleFrom(
                        backgroundColor: CHCTheme.text,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(CHCTheme.radiusMd))),
                    child: Text('సరే (Done)',
                        style: GoogleFonts.notoSansTelugu(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: confettiController,
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
              Colors.green
            ],
          ),
        ),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;
  final bool isPending;

  const _ReceiptRow(this.label, this.value,
      {this.isTotal = false, this.isPending = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.notoSansTelugu(
                  fontSize: isTotal ? 14 : 12, color: Colors.grey.shade600)),
          Text(value,
              style: GoogleFonts.notoSansTelugu(
                  fontSize: isTotal ? 18 : 13,
                  fontWeight: FontWeight.w700,
                  color: isPending
                      ? CHCTheme.warning
                      : (isTotal ? CHCTheme.primary : CHCTheme.text))),
        ],
      ),
    );
  }
}
