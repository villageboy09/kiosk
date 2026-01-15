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
}

// Equipment Model
class Equipment {
  final String id;
  final String nameEn;
  final String nameHi;
  final String nameTe;
  final String imageUrl;
  final double ratePerAcre;
  final Color accentColor;

  const Equipment({
    required this.id,
    required this.nameEn,
    required this.nameHi,
    required this.nameTe,
    required this.imageUrl,
    required this.ratePerAcre,
    required this.accentColor,
  });
}

// Booking State
class CHCBookingState {
  final Equipment? equipment;
  final double acres;
  final DateTime serviceDate;

  CHCBookingState({
    this.equipment,
    this.acres = 1.0,
    DateTime? serviceDate,
  }) : serviceDate = serviceDate ?? DateTime.now().add(const Duration(days: 1));

  double get totalCost =>
      equipment != null ? acres * equipment!.ratePerAcre : 0;

  bool get isValid => equipment != null && acres > 0;

  CHCBookingState copyWith({
    Equipment? equipment,
    double? acres,
    DateTime? serviceDate,
  }) {
    return CHCBookingState(
      equipment: equipment ?? this.equipment,
      acres: acres ?? this.acres,
      serviceDate: serviceDate ?? this.serviceDate,
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

  // Equipment list with image URLs from kiosk.cropsync.in
  static final List<Equipment> _equipmentList = [
    const Equipment(
      id: 'combined_harvester',
      nameEn: 'Combined Harvester',
      nameHi: 'कंबाइंड हार्वेस्टर',
      nameTe: 'కంబైన్డ్ హార్వెస్టర్',
      imageUrl:
          'https://kiosk.cropsync.in/custom_hiring_center/Combined_Harvester.png',
      ratePerAcre: 2500.0,
      accentColor: Color(0xFFEF4444),
    ),
    const Equipment(
      id: 'tractor',
      nameEn: 'Tractor',
      nameHi: 'ट्रैक्टर',
      nameTe: 'ట్రాక్టర్',
      imageUrl: 'https://kiosk.cropsync.in/custom_hiring_center/Tractor.png',
      ratePerAcre: 1500.0,
      accentColor: Color(0xFF3B82F6),
    ),
    const Equipment(
      id: 'balers',
      nameEn: 'Balers',
      nameHi: 'बेलर',
      nameTe: 'బేలర్స్',
      imageUrl: 'https://kiosk.cropsync.in/custom_hiring_center/Balers.png',
      ratePerAcre: 1200.0,
      accentColor: Color(0xFF10B981),
    ),
    const Equipment(
      id: 'boomer_spray',
      nameEn: 'Boomer Spray',
      nameHi: 'बूमर स्प्रे',
      nameTe: 'బూమర్ స్ప్రే',
      imageUrl:
          'https://kiosk.cropsync.in/custom_hiring_center/Boomer_Spray.png',
      ratePerAcre: 800.0,
      accentColor: Color(0xFF8B5CF6),
    ),
    const Equipment(
      id: 'shredder',
      nameEn: 'Shredder',
      nameHi: 'श्रेडर',
      nameTe: 'ష్రెడ్డర్',
      imageUrl: 'https://kiosk.cropsync.in/custom_hiring_center/Shredder.png',
      ratePerAcre: 1000.0,
      accentColor: Color(0xFFF59E0B),
    ),
    const Equipment(
      id: 'tractor_trolley',
      nameEn: 'Tractor Trolley',
      nameHi: 'ट्रैक्टर ट्रॉली',
      nameTe: 'ట్రాక్టర్ ట్రాలీ',
      imageUrl:
          'https://kiosk.cropsync.in/custom_hiring_center/Tractor_Trolley.png',
      ratePerAcre: 600.0,
      accentColor: Color(0xFF06B6D4),
    ),
    const Equipment(
      id: 'mobile_grain_dryer',
      nameEn: 'Mobile Grain Dryer',
      nameHi: 'मोबाइल ग्रेन ड्रायर',
      nameTe: 'మొబైల్ గ్రెయిన్ డ్రయ్యర్',
      imageUrl:
          'https://kiosk.cropsync.in/custom_hiring_center/Mobile_Grain_Dryer.png',
      ratePerAcre: 1800.0,
      accentColor: Color(0xFFEC4899),
    ),
    const Equipment(
      id: 'seed_cum_fertilizer_drill',
      nameEn: 'Seed Cum Fertilizer Drill',
      nameHi: 'सीड कम फर्टिलाइजर ड्रिल',
      nameTe: 'సీడ్ కమ్ ఫెర్టిలైజర్ డ్రిల్',
      imageUrl:
          'https://kiosk.cropsync.in/custom_hiring_center/Seed_Cum_Fertilizer_Drill.png',
      ratePerAcre: 900.0,
      accentColor: Color(0xFF14B8A6),
    ),
    const Equipment(
      id: 'drone',
      nameEn: 'Drone',
      nameHi: 'ड्रोन',
      nameTe: 'డ్రోన్',
      imageUrl: 'https://kiosk.cropsync.in/custom_hiring_center/Drone.png',
      ratePerAcre: 600.0,
      accentColor: Color(0xFF6366F1),
    ),
    const Equipment(
      id: 'manual_seed_drill_maize',
      nameEn: 'Manual Seed Drill (Maize)',
      nameHi: 'मैनुअल सीड ड्रिल (मक्का)',
      nameTe: 'మాన్యువల్ సీడ్ డ్రిల్ (మొక్కజొన్న)',
      imageUrl:
          'https://kiosk.cropsync.in/custom_hiring_center/Manual_Seed_Drill_Maize.png',
      ratePerAcre: 400.0,
      accentColor: Color(0xFF84CC16),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _state = CHCBookingState(
      serviceDate: DateTime.now().add(const Duration(days: 1)),
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
    return switch (locale) {
      'hi' => equipment.nameHi,
      'te' => equipment.nameTe,
      _ => equipment.nameEn,
    };
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

      final bookingId =
          'CHC-${DateFormat('yyyyMMdd').format(DateTime.now())}-${DateTime.now().millisecondsSinceEpoch % 10000}';

      final result = await ApiService.createCHCBooking(
        bookingId: bookingId,
        userId: userId,
        equipmentType: _state.equipment!.nameEn,
        acres: _state.acres,
        serviceDate: _state.serviceDate,
        ratePerAcre: _state.equipment!.ratePerAcre,
        totalCost: _state.totalCost,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        await _showSuccessDialog(bookingId);
        setState(() {
          _state = CHCBookingState(
            serviceDate: DateTime.now().add(const Duration(days: 1)),
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
    final totalValue = '₹${_state.totalCost.toStringAsFixed(0)}';

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
                  color: CHCTheme.accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    size: 48, color: CHCTheme.accent),
              ),
              const SizedBox(height: 24),
              Text(
                context.tr('chc_success_title'),
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: CHCTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('chc_success_subtitle'),
                style: const TextStyle(
                    fontSize: 14, color: CHCTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CHCTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _DetailRow(context.tr('detail_booking_id'), bookingId),
                    const Divider(height: 20),
                    _DetailRow(context.tr('chc_equipment'), equipmentName),
                    const Divider(height: 20),
                    _DetailRow(context.tr('detail_acres'),
                        _state.acres.toStringAsFixed(1)),
                    const Divider(height: 20),
                    _DetailRow(context.tr('detail_date'), formattedDate),
                    const Divider(height: 20),
                    _DetailRow(context.tr('detail_total'), totalValue),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: CHCTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(context.tr('done_button'),
                      style: const TextStyle(fontSize: 16)),
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
    return Scaffold(
      backgroundColor: CHCTheme.surface,
      appBar: AppBar(
        backgroundColor: CHCTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('chc_title'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Equipment Selection Section
                    _SectionHeader(context.tr('chc_select_equipment')),
                    const SizedBox(height: 16),
                    _EquipmentGrid(
                      equipmentList: _equipmentList,
                      selected: _state.equipment,
                      onSelect: (equipment) =>
                          _updateState(_state.copyWith(equipment: equipment)),
                      getEquipmentName: _getEquipmentName,
                    ),
                    const SizedBox(height: 32),

                    // Acres Section
                    _SectionHeader(context.tr('section_acres')),
                    const SizedBox(height: 16),
                    _AcreSlider(
                      value: _state.acres,
                      ratePerAcre: _state.equipment?.ratePerAcre ?? 0,
                      onChanged: (acres) =>
                          _updateState(_state.copyWith(acres: acres)),
                    ),
                    const SizedBox(height: 32),

                    // Date Section
                    _SectionHeader(context.tr('section_date')),
                    const SizedBox(height: 16),
                    _DateSelector(
                      selected: _state.serviceDate,
                      onSelect: (date) =>
                          _updateState(_state.copyWith(serviceDate: date)),
                    ),
                  ]),
                ),
              ),
            ],
          ),
          _BottomBar(
            state: _state,
            isSubmitting: _isSubmitting,
            onSubmit: _submitBooking,
            getEquipmentName: _getEquipmentName,
          ),
        ],
      ),
    );
  }
}

// Section Header Widget
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: CHCTheme.textPrimary,
      ),
    );
  }
}

// Equipment Grid Widget
class _EquipmentGrid extends StatelessWidget {
  final List<Equipment> equipmentList;
  final Equipment? selected;
  final ValueChanged<Equipment> onSelect;
  final String Function(Equipment) getEquipmentName;

  const _EquipmentGrid({
    required this.equipmentList,
    required this.selected,
    required this.onSelect,
    required this.getEquipmentName,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: equipmentList.length,
      itemBuilder: (context, index) {
        final equipment = equipmentList[index];
        final isSelected = selected?.id == equipment.id;
        return _EquipmentCard(
          equipment: equipment,
          isSelected: isSelected,
          onTap: () => onSelect(equipment),
          equipmentName: getEquipmentName(equipment),
        );
      },
    );
  }
}

// Equipment Card Widget
class _EquipmentCard extends StatelessWidget {
  final Equipment equipment;
  final bool isSelected;
  final VoidCallback onTap;
  final String equipmentName;

  const _EquipmentCard({
    required this.equipment,
    required this.isSelected,
    required this.onTap,
    required this.equipmentName,
  });

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Equipment Image
            Container(
              width: 80,
              height: 80,
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
                    size: 40,
                    color: equipment.accentColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Equipment Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                equipmentName,
                style: TextStyle(
                  fontSize: 13,
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
            // Rate per acre
            Text(
              '₹${equipment.ratePerAcre.toStringAsFixed(0)}/acre',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? equipment.accentColor.withOpacity(0.8)
                    : CHCTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Acre Slider Widget
class _AcreSlider extends StatelessWidget {
  final double value;
  final double ratePerAcre;
  final ValueChanged<double> onChanged;

  const _AcreSlider({
    required this.value,
    required this.ratePerAcre,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
        children: [
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: CHCTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '₹${(value * ratePerAcre).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CHCTheme.accent,
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

// Bottom Bar Widget
class _BottomBar extends StatelessWidget {
  final CHCBookingState state;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final String Function(Equipment) getEquipmentName;

  const _BottomBar({
    required this.state,
    required this.isSubmitting,
    required this.onSubmit,
    required this.getEquipmentName,
  });

  @override
  Widget build(BuildContext context) {
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
                  color: Colors.black.withOpacity(0.1),
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
                                  '${state.acres.toStringAsFixed(1)} ${context.tr('acres')} × ₹${state.equipment!.ratePerAcre.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 12,
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
                            Text(
                              '₹${state.totalCost.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: CHCTheme.textPrimary,
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
                              backgroundColor: CHCTheme.primary,
                              disabledBackgroundColor:
                                  CHCTheme.primary.withOpacity(0.5),
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
                                    context.tr('chc_book_now'),
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
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: CHCTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
