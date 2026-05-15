// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// google_fonts import removed — AppTheme.getTextStyle() handles font selection
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'package:cropsync/theme/app_theme.dart';

// ============================================================================
// DESIGN SYSTEM
// ============================================================================

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
    if (crop == null) return false;
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
    final currentUser = AuthService.currentUser;
    // Check membership via card_uid: if null/empty, user has no membership
    final isMember =
        currentUser?.cardUid != null && currentUser!.cardUid!.isNotEmpty;
    _state = CHCBookingState(isMember: isMember);
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = AuthService.currentUser;
      final equipmentsData = await ApiService.getCHCEquipments(
          isMember: _state.isMember, clientCode: user?.clientCode);
      _equipments = equipmentsData.map((e) => Equipment.fromJson(e)).toList();
      final cropsData = await ApiService.getCrops();
      _crops = cropsData.map((c) => Crop.fromJson(c)).toList();
    } catch (e) {
      // Silent error handling
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
      ).timeout(const Duration(seconds: 10), onTimeout: () => []);
      final fullyBooked = <String, bool>{};
      for (final d in dates) {
        if (d['is_full'] == true) fullyBooked[d['date']] = true;
      }
      if (mounted) {
        setState(() => _state = _state.copyWith(fullyBookedDates: fullyBooked));
      }
    } catch (e) {
      // Silent error handling
    }
  }

  void _showBookingsBottomSheet() {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CHCBookingsBottomSheet(userId: currentUser.userId),
    );
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
    // Round to nearest 0.25 to avoid floating point drift
    final raw = _state.acres + delta;
    final newValue = (raw * 4).round() / 4.0;
    if (newValue >= 0.25 && newValue <= 100) {
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
      ).timeout(const Duration(seconds: 10));

      if (availability['can_book'] != true) {
        if (!mounted) return;
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
      ).timeout(const Duration(seconds: 12));

      if (!mounted) return;

      if (result['success'] == true) {
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
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.all(24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _CHCScreenSkeleton();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;
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
                  child: _CHCHeader(
                      state: _state,
                      currentUser: currentUser,
                      onBookingsPressed: _showBookingsBottomSheet)),
              _buildEquipmentSection(locale),
              _buildCropSection(),
              _buildAcresSection(),
              _buildCalendarSection(),
              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
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
                  child: _CHCHeader(
                      state: _state,
                      currentUser: currentUser,
                      onBookingsPressed: _showBookingsBottomSheet)),
              _buildEquipmentSection(locale),
              _buildCropSection(),
              _buildAcresSection(),
              _buildCalendarSection(),
              const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
            ],
          ),
        ),
        // Right panel - Summary
        Container(
          width: 360,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(
                left: BorderSide(color: AppTheme.border.withOpacity(0.5))),
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
      padding: const EdgeInsets.all(24),
      sliver: SliverToBoxAdapter(
        child: _CHCCard(
          title: context.tr('chc_select_equipment'),
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverToBoxAdapter(
        child: _CHCCard(
          title: context.tr('chc_select_crop'),
          icon: Icons.grass_rounded,
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
      padding: const EdgeInsets.all(24),
      sliver: SliverToBoxAdapter(
        child: _CHCCard(
          title: context.tr('chc_land_size'),
          icon: Icons.straighten_rounded,
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverToBoxAdapter(
        child: _CHCCard(
          title: context.tr('chc_select_date'),
          icon: Icons.calendar_today_rounded,
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

  // ==================== SKELETON LOADING ====================
}

// ============================================================================
// SHIMMER LOADING WIDGET
// ============================================================================
class _CHCScreenSkeleton extends StatelessWidget {
  const _CHCScreenSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Header Skeleton — compact single row
            Container(
              padding: EdgeInsets.fromLTRB(
                12,
                MediaQuery.of(context).padding.top + 8,
                12,
                12,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF111827),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: const Row(
                children: [
                  // Back button placeholder
                  _ShimmerBox(
                      width: 36, height: 36, borderRadius: 18, isDark: true),
                  SizedBox(width: 10),
                  // Avatar
                  _ShimmerBox(
                      width: 34, height: 34, borderRadius: 17, isDark: true),
                  SizedBox(width: 10),
                  // Name + village
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ShimmerBox(
                            width: 130,
                            height: 14,
                            borderRadius: 4,
                            isDark: true),
                        SizedBox(height: 6),
                        _ShimmerBox(
                            width: 80,
                            height: 11,
                            borderRadius: 4,
                            isDark: true),
                      ],
                    ),
                  ),
                  // Member badge + bookings button
                  _ShimmerBox(
                      width: 72, height: 28, borderRadius: 14, isDark: true),
                  SizedBox(width: 8),
                  _ShimmerBox(
                      width: 90, height: 32, borderRadius: 12, isDark: true),
                ],
              ),
            ),

            // 2. Equipment Grid Skeleton
            Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        _ShimmerBox(width: 24, height: 24, borderRadius: 6),
                        SizedBox(width: 12),
                        _ShimmerBox(width: 140, height: 18, borderRadius: 4),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: 4,
                      // Dark card skeleton matching new full-bleed design
                      itemBuilder: (_, __) => ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Dark background
                            Container(color: const Color(0xFF1F2937)),
                            // Shimmer overlay covering the whole card
                            const _ShimmerBox(
                                width: double.infinity,
                                height: double.infinity,
                                borderRadius: 0,
                                isDark: true),
                            // Bottom label strip placeholder
                            const Positioned(
                              left: 10,
                              right: 10,
                              bottom: 10,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _ShimmerBox(
                                      width: 80,
                                      height: 12,
                                      borderRadius: 4,
                                      isDark: true),
                                  SizedBox(height: 6),
                                  _ShimmerBox(
                                      width: 52,
                                      height: 22,
                                      borderRadius: 11,
                                      isDark: true),
                                ],
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

            // 3. Section Skeletons
            _buildSectionSkeleton(),
            _buildSectionSkeleton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionSkeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ShimmerBox(width: 24, height: 24, borderRadius: 6),
                SizedBox(width: 12),
                _ShimmerBox(width: 120, height: 18, borderRadius: 4),
              ],
            ),
            SizedBox(height: 24),
            _ShimmerBox(width: double.infinity, height: 100, borderRadius: 16),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final bool isDark;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.isDark = false,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.isDark
        ? [
            const Color(0xFF1F2937),
            const Color(0xFF374151),
            const Color(0xFF1F2937),
          ]
        : [
            const Color(0xFFE8E8E8),
            const Color(0xFFF5F5F5),
            const Color(0xFFE8E8E8),
          ];

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: colors,
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
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
  final VoidCallback? onBookingsPressed;

  const _CHCHeader({
    required this.state,
    required this.currentUser,
    this.onBookingsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final name = currentUser?.name ?? 'Guest';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'G';
    final village = currentUser?.village as String?;

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.of(context).padding.top + 8,
        12,
        16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
      ),
      child: Row(
        children: [
          // Back button
          AppTheme.backButton(context, color: AppTheme.textPrimary),
          // Avatar
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFFE5E7EB), width: 1.5),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          // Name + village
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: AppTheme.getTextStyle(
                    context,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (village != null && village.isNotEmpty)
                  Text(
                    village,
                    style: AppTheme.getTextStyle(
                      context,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Member badge
          _MemberBadge(isMember: state.isMember),
          const SizedBox(width: 8),
          // My Bookings button — icon only on tight screens
          if (onBookingsPressed != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onBookingsPressed,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_rounded,
                          color: AppTheme.textPrimary, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        context.tr('chc_my_bookings'),
                        style: AppTheme.getTextStyle(
                          context,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMember)
            const Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 16),
          if (isMember) const SizedBox(width: 6),
          Text(
            isMember ? context.tr('member') : context.tr('non_member'),
            style: AppTheme.getTextStyle(
              context,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
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
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.textPrimary, size: 22),
              const SizedBox(width: 12),
              Text(title,
                  style: AppTheme.getTextStyle(
                    context,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.4,
                  )),
            ],
          ),
          const SizedBox(height: 24),
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
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
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
    final imageUrl = equipment.image.startsWith('http')
        ? equipment.image
        : 'https://kiosk.cropsync.in/custom_hiring_center/${equipment.image}';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.9)
                : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.1),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Full-bleed equipment image ──
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheHeight: 400,
                placeholder: (_, __) => Container(
                  color: const Color(0xFF1F2937),
                  child: const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white30),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFF1F2937),
                  child: const Center(
                    child: Icon(Icons.agriculture_rounded,
                        size: 48, color: Colors.white24),
                  ),
                ),
              ),

              // ── Gradient overlay — top (subtle dark for badges) ──
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.45, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.15),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Selected checkmark ──
              if (isSelected)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 16, color: Color(0xFF111827)),
                  ),
                ),

              // ── Member badge ──
              if (isMember)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded,
                            size: 10, color: Colors.black87),
                        const SizedBox(width: 3),
                        Text(
                          context.tr('member').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Bottom label strip ──
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        equipment.getDisplayName(locale),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                          shadows: [
                            Shadow(
                                color: Colors.black54,
                                blurRadius: 4,
                                offset: Offset(0, 1))
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '₹${equipment.displayPrice.toStringAsFixed(0)}/${equipment.unit}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
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
      ),
    );
  }
}

// ---------------------------- Crop Selector ----------------------------

class _CHCCropSelector extends StatelessWidget {
  final List<Crop> crops;
  final Crop? selected;
  final ValueChanged<Crop> onSelect;

  // Base URL for crop images from the crops table
  static const String _cropImageBaseUrl = 'https://kiosk.cropsync.in/';

  const _CHCCropSelector(
      {required this.crops, required this.selected, required this.onSelect});

  String _getCropImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return '';
    if (imageUrl.startsWith('http')) return imageUrl;
    return '$_cropImageBaseUrl$imageUrl';
  }

  @override
  Widget build(BuildContext context) {
    if (crops.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'No crops available',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hint text
        if (selected == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('chc_crop_required'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ),
        // Horizontal scrollable crop tabs
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 4),
            itemCount: crops.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) {
              final crop = crops[i];
              final isSelected = selected?.id == crop.id;
              final imageUrl = _getCropImageUrl(crop.imageUrl);

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(crop);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: 88,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF111827)
                        : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF111827)
                          : const Color(0xFFE5E7EB),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF111827).withOpacity(0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Image / icon
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.12)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? Colors.white.withOpacity(0.2)
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: imageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  width: 52,
                                  height: 52,
                                  memCacheHeight: 104,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: isSelected
                                            ? Colors.white54
                                            : AppTheme.textHint,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Icon(
                                    Icons.grass_rounded,
                                    size: 28,
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.grass_rounded,
                                size: 28,
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textPrimary,
                              ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          crop.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textPrimary,
                            letterSpacing: -0.1,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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

  String _formatAcres(double v) {
    // Show as integer when whole number, else show 2 decimal places
    if (v == v.roundToDouble()) return v.toInt().toString();
    // Show up to 2 decimal places, stripping trailing zeros
    final s = v.toStringAsFixed(2);
    return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (equipment != null && equipment!.billingType == 'Variable')
          _VariableBillingWarning(equipment: equipment!),
        if (equipment?.isTrolley == true) _TrolleyWarning(),
        // Quick-select chips: 0.25, 0.5, 1, 2, 5
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [0.25, 0.5, 1.0, 2.0, 5.0].map((v) {
              final isActive = acres == v;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => onChanged(v - acres),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.textPrimary
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: isActive
                            ? AppTheme.textPrimary
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Text(
                      _formatAcres(v),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isActive ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CounterButton(
                icon: Icons.remove_rounded, onTap: () => onChanged(-0.25)),
            const SizedBox(width: 32),
            Column(
              children: [
                Text(_formatAcres(acres),
                    style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        letterSpacing: -1)),
                Text(context.tr('acres'),
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(width: 32),
            _CounterButton(
                icon: Icons.add_rounded, onTap: () => onChanged(0.25)),
          ],
        ),
      ],
    );
  }
}

class _VariableBillingWarning extends StatelessWidget {
  final Equipment equipment;
  const _VariableBillingWarning({required this.equipment});

  String _getRateText(BuildContext context) {
    final rate = equipment.displayPrice.toStringAsFixed(0);
    switch (equipment.unit) {
      case 'Hour':
        return context.tr('chc_per_hour', namedArgs: {'rate': rate});
      case 'Bale':
        return context.tr('chc_per_bale', namedArgs: {'rate': rate});
      case 'Trip':
        return context.tr('chc_per_trip', namedArgs: {'rate': rate});
      case 'Ton':
        return context.tr('chc_per_ton', namedArgs: {'rate': rate});
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFEF3C7))),
      child: Text(_getRateText(context),
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFFB45309)),
          textAlign: TextAlign.center),
    );
  }
}

class _TrolleyWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFEE2E2))),
      child: Text(context.tr('chc_trolley_warning'),
          style: AppTheme.getTextStyle(
            context,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.error,
          ),
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
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ]),
        child: Icon(icon, color: AppTheme.textPrimary, size: 24),
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
                DateFormat.yMMMM(context.locale.languageCode)
                    .format(calendarMonth),
                style: AppTheme.getTextStyle(
                  context,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                )),
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
        const SizedBox(height: AppTheme.spacingSm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(7, (i) {
            final date = DateTime(2024, 1, 7 + i); // 2024-01-07 was a Sunday
            final dayName =
                DateFormat.E(context.locale.languageCode).format(date);
            // For Telugu, keep 2 characters for better readability (e.g., సో, మం)
            final display = context.locale.languageCode == 'te'
                ? (dayName.length > 2 ? dayName.substring(0, 2) : dayName)
                : dayName.substring(0, 1).toUpperCase();
            return Expanded(
              child: Text(
                display,
                textAlign: TextAlign.center,
                style: AppTheme.getTextStyle(
                  context,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: AppTheme.spacingSm),
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
                      ? AppTheme.textPrimary
                      : isPast
                          ? const Color(0xFFF9FAFB)
                          : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: isFullyBooked
                          ? AppTheme.error
                          : isSelected
                              ? AppTheme.textPrimary
                              : const Color(0xFFE5E7EB),
                      width: isFullyBooked ? 2 : 1),
                ),
                child: Center(
                  child: Text(
                    day.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? Colors.white
                          : isPast
                              ? const Color(0xFFD1D5DB)
                              : isFullyBooked
                                  ? AppTheme.error
                                  : AppTheme.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.w900 : FontWeight.w700,
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
        ? context.tr('chc_bill_pending')
        : '₹${state.totalCost.toStringAsFixed(0)}';
    final buttonText = state.equipment == null
        ? context.tr('chc_select_equipment')
        : (state.equipment!.billingType == 'Fixed'
            ? context.tr('chc_confirm_booking')
            : context.tr('chc_book_slot'));

    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
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
                Text(context.tr('total'),
                    style: AppTheme.getTextStyle(
                      context,
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    )),
                Text(totalDisplay,
                    style: AppTheme.getTextStyle(
                      context,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: isVariableBilling
                          ? const Color(0xFFB45309)
                          : AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    )),
              ],
            ),
          ),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: state.isValid && !isSubmitting ? onSubmit : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.textPrimary,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100)),
                padding: const EdgeInsets.symmetric(horizontal: 32),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: Colors.white))
                  : Text(buttonText,
                      style: AppTheme.getTextStyle(
                        context,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: Colors.white,
                      )),
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
    final equipmentName = state.equipment?.getDisplayName(locale) ??
        context.tr('select_equipment');
    final rate = state.equipment != null
        ? '₹${state.equipment!.displayPrice.toStringAsFixed(0)}/${state.equipment!.unit}'
        : '-';
    final dateStr = state.serviceDate != null
        ? DateFormat('dd MMM yyyy').format(state.serviceDate!)
        : '-';
    final isVariableBilling = state.equipment?.billingType == 'Variable';
    final totalDisplay = isVariableBilling
        ? context.tr('chc_bill_pending')
        : '₹${state.totalCost.toStringAsFixed(0)}';
    final buttonText = state.equipment == null
        ? context.tr('chc_select_equipment')
        : (state.equipment!.billingType == 'Fixed'
            ? context.tr('chc_confirm_booking')
            : context.tr('chc_book_slot'));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('chc_summary_title'),
                style: AppTheme.getTextStyle(
                  context,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                )),
            const SizedBox(height: AppTheme.spacingLg),
            _SummaryRow(
                label: context.tr('chc_equipment'),
                value: equipmentName,
                highlight: true),
            if (state.equipment?.requiresCropSelection == true)
              _SummaryRow(
                  label: context.tr('crop_label'),
                  value: state.crop?.name ?? '-'),
            _SummaryRow(label: context.tr('chc_rate_label'), value: rate),
            _SummaryRow(
                label: context.tr('chc_land_size'),
                value: '${state.acres} ${context.tr("acres")}'),
            _SummaryRow(label: context.tr('chc_service_date'), value: dateStr),
            const Divider(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.tr('total'),
                    style: AppTheme.getTextStyle(
                      context,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    )),
                Text(totalDisplay,
                    style: AppTheme.getTextStyle(
                      context,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: isVariableBilling
                          ? const Color(0xFFB45309)
                          : AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    )),
              ],
            ),
            if (isVariableBilling)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(context.tr('chc_bill_after_service'),
                    style: AppTheme.getTextStyle(
                      context,
                      fontSize: 12,
                      color: const Color(0xFFB45309),
                      fontWeight: FontWeight.w600,
                    )),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: state.isValid && !isSubmitting ? onSubmit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.textPrimary,
                  disabledBackgroundColor: const Color(0xFFE5E7EB),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100)),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(buttonText,
                        style: AppTheme.getTextStyle(
                          context,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        )),
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
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTheme.getTextStyle(
                context,
                fontSize: 13,
                color: AppTheme.textSecondary,
              )),
          Flexible(
              child: Text(value,
                  style: AppTheme.getTextStyle(
                    context,
                    fontSize: 13,
                    fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                    color:
                        highlight ? AppTheme.textPrimary : AppTheme.textPrimary,
                  ),
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
          borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                  color: AppTheme.errorBg, shape: BoxShape.circle),
              child: const Icon(Icons.error_outline,
                  size: 40, color: AppTheme.errorText),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(equipment?.getDisplayName(locale) ?? '',
                style: AppTheme.getTextStyle(
                  context,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.text,
                )),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
                message ??
                    'ఈ తేదీలో స్లాట్లు అన్నీ బుక్ అయిపోయాయి.\n(Fully Booked)',
                style: AppTheme.getTextStyle(
                  context,
                  fontSize: 13,
                  color: AppTheme.errorText,
                ),
                textAlign: TextAlign.center),
            const SizedBox(height: AppTheme.spacingLg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onClose,
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd))),
                child: Text(context.tr('chc_select_another_date'),
                    style: AppTheme.getTextStyle(
                      context,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    )),
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
  final VoidCallback onClose;

  const _SuccessDialog({
    required this.bookingId,
    required this.billingType,
    required this.totalCost,
    required this.state,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final equipmentName = state.equipment!.getDisplayName(locale);
    final dateStr = DateFormat('dd MMM yyyy').format(state.serviceDate!);

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check, size: 40, color: AppTheme.primary),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(context.tr('chc_success_title'),
                style: AppTheme.getTextStyle(
                  context,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                )),
            const SizedBox(height: AppTheme.spacingSm),
            Text(context.tr('detail_booking_id'),
                style: AppTheme.getTextStyle(context,
                    fontSize: 12, color: AppTheme.textSecondary)),
            Text(bookingId,
                style: AppTheme.getTextStyle(context,
                    fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: AppTheme.spacingMd),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                  color: AppTheme.bg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              child: Column(
                children: [
                  _ReceiptRow(context.tr('chc_equipment'), equipmentName),
                  if (state.crop != null)
                    _ReceiptRow(context.tr('crop_label'), state.crop!.name),
                  _ReceiptRow(context.tr('chc_land_size'),
                      '${state.acres} ${context.tr("acres")}'),
                  _ReceiptRow(context.tr('chc_service_date'), dateStr),
                  const Divider(height: AppTheme.spacingMd),
                  _ReceiptRow(
                      context.tr('total'),
                      billingType == 'Fixed'
                          ? '₹${totalCost.toStringAsFixed(0)}'
                          : context.tr('chc_bill_pending'),
                      isTotal: true,
                      isPending: billingType != 'Fixed'),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onClose,
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.text,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd))),
                child: Text(context.tr('ok'),
                    style: AppTheme.getTextStyle(
                      context,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BOOKINGS BOTTOM SHEET
// ============================================================================
class _CHCBookingsBottomSheet extends StatefulWidget {
  final String userId;
  const _CHCBookingsBottomSheet({required this.userId});

  @override
  State<_CHCBookingsBottomSheet> createState() =>
      _CHCBookingsBottomSheetState();
}

class _CHCBookingsBottomSheetState extends State<_CHCBookingsBottomSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _bookings = [];
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    try {
      final data = await ApiService.getCHCBookings(widget.userId);
      if (mounted) {
        setState(() {
          _bookings = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
        return const Color(0xFF4CAF50);
      case 'completed':
        return const Color(0xFF2196F3);
      case 'cancelled':
        return const Color(0xFFF44336);
      case 'slot booked':
        return AppTheme.slotBooked;
      default:
        return AppTheme.warning;
    }
  }

  Color _taskStatusColor(String? status) {
    switch (status) {
      case 'En Route':
        return const Color(0xFFFF9800);
      case 'Working':
        return const Color(0xFF9C27B0);
      case 'Halted':
        return const Color(0xFFF44336);
      case 'Completed':
        return const Color(0xFF4CAF50);
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _taskStatusIcon(String? status) {
    switch (status) {
      case 'En Route':
        return Icons.directions_car;
      case 'Working':
        return Icons.engineering;
      case 'Halted':
        return Icons.pause_circle;
      case 'Completed':
        return Icons.check_circle;
      default:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.bg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg,
                AppTheme.spacingMd, AppTheme.spacingLg, AppTheme.spacingSm),
            child: Row(
              children: [
                const Icon(Icons.receipt_long,
                    color: AppTheme.primaryDark, size: 24),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text(
                    context.tr('chc_my_bookings'),
                    style: AppTheme.getTextStyle(
                      context,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text,
                    ),
                  ),
                ),
                if (!_loading && _bookings.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_bookings.length}',
                      style: AppTheme.getTextStyle(
                        context,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          if (_loading)
            Flexible(
                child: SingleChildScrollView(child: _buildShimmerLoading()))
          else if (_bookings.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingXl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_busy, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text(
                    context.tr('chc_no_bookings'),
                    style: AppTheme.getTextStyle(
                      context,
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                itemCount: _bookings.length,
                itemBuilder: (ctx, i) => _buildBookingCard(_bookings[i], i),
              ),
            ),
        ],
      ),
    );
  }

  // ── Shimmer loading skeleton ──────────────────────────────────────
  Widget _buildShimmerLoading() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        children: List.generate(
          3,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.border.withOpacity(0.3)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ShimmerBox(width: 140, height: 16, borderRadius: 4),
                    Spacer(),
                    _ShimmerBox(width: 70, height: 22, borderRadius: 6),
                  ],
                ),
                SizedBox(height: 14),
                _ShimmerBox(
                    width: double.infinity, height: 14, borderRadius: 4),
                SizedBox(height: 10),
                _ShimmerBox(width: 200, height: 14, borderRadius: 4),
                SizedBox(height: 10),
                _ShimmerBox(width: 160, height: 14, borderRadius: 4),
                SizedBox(height: 14),
                Row(
                  children: [
                    _ShimmerBox(width: 32, height: 32, borderRadius: 16),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ShimmerBox(width: 100, height: 12, borderRadius: 4),
                        SizedBox(height: 6),
                        _ShimmerBox(width: 70, height: 10, borderRadius: 4),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Booking card ──────────────────────────────────────────────────
  Widget _buildBookingCard(Map<String, dynamic> booking, int index) {
    final status = booking['booking_status']?.toString() ?? 'Pending';
    final billingType = booking['billing_type']?.toString() ?? 'Fixed';
    final equipmentType = booking['equipment_type']?.toString() ?? '';
    final bookingId = booking['booking_id']?.toString() ?? '';
    final acres = booking['land_size_acres']?.toString() ?? '0';
    final rate = double.tryParse(booking['rate']?.toString() ?? '0') ?? 0;
    final totalCost =
        double.tryParse(booking['total_cost']?.toString() ?? '0') ?? 0;
    final unitType = booking['unit_type']?.toString() ?? 'Acre';
    final cropType = booking['crop_type']?.toString();
    final serviceDate = booking['service_date']?.toString() ?? '';
    final rescheduledDate = booking['rescheduled_date']?.toString();
    final createdAt = booking['created_at']?.toString() ?? '';
    final notes = booking['notes']?.toString();

    // Operator info
    final operatorName = booking['operator_name']?.toString();
    final operatorPhone = booking['operator_phone']?.toString();
    final operatorImage = booking['operator_image']?.toString();
    final operatorRating =
        double.tryParse(booking['operator_rating']?.toString() ?? '0');
    final operatorVillage = booking['operator_village']?.toString();
    final hasOperator = operatorName != null &&
        operatorName.isNotEmpty &&
        operatorName != 'null';

    // Task completion info
    final taskStatus = booking['task_status']?.toString();
    final finalAmount =
        double.tryParse(booking['final_amount']?.toString() ?? '0');
    final workStart = booking['work_start_time']?.toString();
    final workEnd = booking['work_end_time']?.toString();
    final transitStart = booking['transit_start_time']?.toString();
    final returnTime = booking['return_time']?.toString();
    final startReading = booking['start_reading']?.toString();
    final endReading = booking['end_reading']?.toString();
    final breakdownReason = booking['breakdown_reason']?.toString();
    final hasTaskInfo =
        taskStatus != null && taskStatus.isNotEmpty && taskStatus != 'null';

    final isExpanded = _expandedIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            onTap: () => setState(() {
              _expandedIndex = isExpanded ? null : index;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingSm),
              decoration: BoxDecoration(
                color: _statusColor(status).withOpacity(0.08),
              ),
              child: Row(
                children: [
                  Icon(Icons.agriculture,
                      size: 18, color: _statusColor(status)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(equipmentType,
                            style: AppTheme.getTextStyle(context,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.text)),
                        Text(bookingId,
                            style: AppTheme.getTextStyle(context,
                                fontSize: 10, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(status),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Text(status,
                        style: AppTheme.getTextStyle(context,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more,
                        size: 20, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable details ─────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: isExpanded
                ? _buildExpandedDetails(
                    booking,
                    serviceDate,
                    rescheduledDate,
                    cropType,
                    acres,
                    rate,
                    unitType,
                    totalCost,
                    billingType,
                    notes,
                    createdAt,
                    hasOperator,
                    operatorName,
                    operatorPhone,
                    operatorImage,
                    operatorRating,
                    operatorVillage,
                    hasTaskInfo,
                    taskStatus,
                    finalAmount,
                    workStart,
                    workEnd,
                    transitStart,
                    returnTime,
                    startReading,
                    endReading,
                    breakdownReason,
                  )
                : const SizedBox.shrink(),
          ),

          // ── Collapsed summary row ──────────────────────────────
          if (!isExpanded)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMd, vertical: 6),
              decoration: const BoxDecoration(
                color: AppTheme.bg,
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(_formatDate(serviceDate),
                      style: AppTheme.getTextStyle(context,
                          fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(width: 12),
                  Icon(Icons.straighten, size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text('$acres ${context.tr("acres")}',
                      style: AppTheme.getTextStyle(context,
                          fontSize: 11, color: AppTheme.textSecondary)),
                  const Spacer(),
                  if (hasOperator) ...[
                    Icon(Icons.person, size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                  ],
                  if (hasTaskInfo &&
                      status.toLowerCase() == 'completed' &&
                      finalAmount != null &&
                      finalAmount > 0)
                    Text(
                      '₹${finalAmount.toStringAsFixed(0)}',
                      style: AppTheme.getTextStyle(
                        context,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    )
                  else
                    Text(
                      billingType == 'Fixed'
                          ? '₹${totalCost.toStringAsFixed(0)}'
                          : context.tr('chc_bill_pending'),
                      style: AppTheme.getTextStyle(
                        context,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: billingType == 'Fixed'
                            ? AppTheme.primary
                            : AppTheme.warning,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Expanded booking details ──────────────────────────────────────
  Widget _buildExpandedDetails(
    Map<String, dynamic> booking,
    String serviceDate,
    String? rescheduledDate,
    String? cropType,
    String acres,
    double rate,
    String unitType,
    double totalCost,
    String billingType,
    String? notes,
    String createdAt,
    bool hasOperator,
    String? operatorName,
    String? operatorPhone,
    String? operatorImage,
    double? operatorRating,
    String? operatorVillage,
    bool hasTaskInfo,
    String? taskStatus,
    double? finalAmount,
    String? workStart,
    String? workEnd,
    String? transitStart,
    String? returnTime,
    String? startReading,
    String? endReading,
    String? breakdownReason,
  ) {
    return Column(
      children: [
        // Booking details
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            children: [
              _bookingDetailRow(Icons.calendar_today,
                  context.tr('chc_service_date'), _formatDate(serviceDate)),
              if (rescheduledDate != null &&
                  rescheduledDate.isNotEmpty &&
                  rescheduledDate != 'null')
                _bookingDetailRow(
                    Icons.event,
                    context.tr('chc_rescheduled_date'),
                    _formatDate(rescheduledDate)),
              if (cropType != null && cropType.isNotEmpty && cropType != 'null')
                _bookingDetailRow(
                    Icons.grass, context.tr('detail_crop'), cropType),
              _bookingDetailRow(Icons.straighten, context.tr('chc_land_size'),
                  '$acres ${context.tr("acres")}'),
              _bookingDetailRow(Icons.payments, context.tr('chc_rate'),
                  '₹${rate.toStringAsFixed(0)}/$unitType'),
              if (!hasTaskInfo || taskStatus?.toLowerCase() != 'completed')
                Row(
                  children: [
                    const Icon(Icons.receipt,
                        size: 16, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text(context.tr('total'),
                        style: AppTheme.getTextStyle(
                          context,
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        )),
                    const Spacer(),
                    Text(
                      billingType == 'Fixed'
                          ? '₹${totalCost.toStringAsFixed(0)}'
                          : context.tr('chc_bill_pending'),
                      style: AppTheme.getTextStyle(
                        context,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: billingType == 'Fixed'
                            ? AppTheme.primary
                            : AppTheme.warning,
                      ),
                    ),
                  ],
                ),
              if (notes != null && notes.isNotEmpty && notes != 'null') ...[
                const SizedBox(height: AppTheme.spacingSm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spacingSm),
                  decoration: BoxDecoration(
                    color: AppTheme.bg,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notes, size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(notes,
                              style: AppTheme.getTextStyle(
                                context,
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ))),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Operator card ─────────────────────────────────────────
        if (hasOperator) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('chc_operator_assigned'),
                    style: AppTheme.getTextStyle(context,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5)),
                const SizedBox(height: AppTheme.spacingSm),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingSm + 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                        color: const Color(0xFF2196F3).withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            const Color(0xFF2196F3).withOpacity(0.15),
                        backgroundImage: (_isValidStr(operatorImage))
                            ? NetworkImage(operatorImage!)
                            : null,
                        child: (!_isValidStr(operatorImage))
                            ? Text(operatorName![0].toUpperCase(),
                                style: AppTheme.getTextStyle(context,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF2196F3)))
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(operatorName!,
                                style: AppTheme.getTextStyle(context,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.text)),
                            if (_isValidStr(operatorVillage))
                              Text(operatorVillage!,
                                  style: AppTheme.getTextStyle(
                                    context,
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  )),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (operatorRating != null && operatorRating > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E1),
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusSm),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star,
                                        size: 12, color: Color(0xFFFF9800)),
                                    const SizedBox(width: 2),
                                    Text(operatorRating.toStringAsFixed(1),
                                        style: AppTheme.getTextStyle(context,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFFE65100))),
                                  ]),
                            ),
                          if (_isValidStr(operatorPhone))
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.phone,
                                        size: 11, color: Colors.grey.shade500),
                                    const SizedBox(width: 3),
                                    Text(operatorPhone!,
                                        style: AppTheme.getTextStyle(context,
                                            fontSize: 10,
                                            color: AppTheme.textSecondary)),
                                  ]),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── Task completion timeline ────────────────────────────────
        if (hasTaskInfo) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(context.tr('chc_work_progress'),
                        style: AppTheme.getTextStyle(context,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _taskStatusColor(taskStatus).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_taskStatusIcon(taskStatus),
                            size: 12, color: _taskStatusColor(taskStatus)),
                        const SizedBox(width: 4),
                        Text(taskStatus ?? '',
                            style: AppTheme.getTextStyle(context,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _taskStatusColor(taskStatus))),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingSm + 2),
                  decoration: BoxDecoration(
                    color: AppTheme.bg,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Column(
                    children: [
                      if (_isValidStr(transitStart))
                        _timelineRow(
                            Icons.directions_car,
                            context.tr('chc_departed'),
                            _formatTime(transitStart!),
                            const Color(0xFF2196F3)),
                      if (_isValidStr(workStart))
                        _timelineRow(
                            Icons.play_circle_fill,
                            context.tr('chc_work_started'),
                            _formatTime(workStart!),
                            const Color(0xFF4CAF50)),
                      if (_isValidStr(breakdownReason))
                        _timelineRow(
                            Icons.warning_amber,
                            context.tr('chc_breakdown'),
                            breakdownReason!,
                            const Color(0xFFF44336)),
                      if (_isValidStr(workEnd))
                        _timelineRow(
                            Icons.stop_circle,
                            context.tr('chc_work_ended'),
                            _formatTime(workEnd!),
                            const Color(0xFF9C27B0)),
                      if (_isValidStr(returnTime))
                        _timelineRow(Icons.home, context.tr('chc_returned'),
                            _formatTime(returnTime!), const Color(0xFF607D8B)),
                    ],
                  ),
                ),
                if (_isValidStr(startReading) || _isValidStr(endReading)) ...[
                  const SizedBox(height: AppTheme.spacingSm),
                  Row(
                    children: [
                      if (_isValidStr(startReading))
                        Expanded(
                            child: _readingChip(context.tr('chc_start_reading'),
                                startReading!)),
                      if (_isValidStr(startReading) && _isValidStr(endReading))
                        const SizedBox(width: AppTheme.spacingSm),
                      if (_isValidStr(endReading))
                        Expanded(
                            child: _readingChip(
                                context.tr('chc_end_reading'), endReading!)),
                    ],
                  ),
                ],
                if (finalAmount != null && finalAmount > 0) ...[
                  const SizedBox(height: AppTheme.spacingSm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMd,
                        vertical: AppTheme.spacingSm),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppTheme.primary.withOpacity(0.08),
                        AppTheme.primary.withOpacity(0.03),
                      ]),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border:
                          Border.all(color: AppTheme.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long,
                            size: 16, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(context.tr('chc_final_bill'),
                            style: AppTheme.getTextStyle(
                              context,
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            )),
                        const Spacer(),
                        Text('₹${finalAmount.toStringAsFixed(0)}',
                            style: AppTheme.getTextStyle(context,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        // ── Footer ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingXs),
          decoration: const BoxDecoration(
            color: AppTheme.bg,
            borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(AppTheme.radiusLg)),
          ),
          child: Row(
            children: [
              Icon(Icons.access_time, size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(
                  '${context.tr("chc_booked_on")} ${_formatDateTime(createdAt)}',
                  style: AppTheme.getTextStyle(context,
                      fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Timeline row ──────────────────────────────────────────────────
  Widget _timelineRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: AppTheme.getTextStyle(
                    context,
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ))),
          Text(value,
              style: AppTheme.getTextStyle(context,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.text)),
        ],
      ),
    );
  }

  // ── Reading chip (shows image if URL, else text) ─────────────────────
  bool _isUrl(String s) => s.startsWith('http://') || s.startsWith('https://');

  Widget _readingChip(String label, String value) {
    final isImage = _isUrl(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
      ),
      child: Column(children: [
        Text(label,
            style: AppTheme.getTextStyle(
              context,
              fontSize: 10,
              color: AppTheme.textSecondary,
            )),
        const SizedBox(height: 4),
        if (isImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CachedNetworkImage(
              imageUrl: value,
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => const SizedBox(
                height: 100,
                child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primary)),
              ),
              errorWidget: (_, __, ___) => const SizedBox(
                height: 60,
                child: Center(
                    child: Icon(Icons.broken_image,
                        color: AppTheme.textSecondary)),
              ),
            ),
          )
        else
          Text(value,
              style: AppTheme.getTextStyle(context,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.text)),
      ]),
    );
  }

  // ── Detail row helper ─────────────────────────────────────────────
  Widget _bookingDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(label,
              style: AppTheme.getTextStyle(
                context,
                fontSize: 12,
                color: AppTheme.textSecondary,
              )),
          const Spacer(),
          Text(value,
              style: AppTheme.getTextStyle(context,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.text)),
        ],
      ),
    );
  }

  bool _isValidStr(String? s) => s != null && s.isNotEmpty && s != 'null';

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('hh:mm a').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDateTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (_) {
      return dateStr;
    }
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
              style: AppTheme.getTextStyle(
                context,
                fontSize: isTotal ? 14 : 12,
                color: AppTheme.textSecondary,
              )),
          Text(value,
              style: AppTheme.getTextStyle(
                context,
                fontSize: isTotal ? 18 : 13,
                fontWeight: FontWeight.w700,
                color: isPending
                    ? AppTheme.warning
                    : (isTotal ? AppTheme.textPrimary : AppTheme.textPrimary),
              )),
        ],
      ),
    );
  }
}
