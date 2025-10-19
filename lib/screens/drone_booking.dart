// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// Design System
class AppTheme {
  static const primary = Color(0xFF1E3A8A);
  static const primaryLight = Color(0xFF3B82F6);
  static const accent = Color(0xFF10B981);
  static const surface = Color(0xFFFAFAFA);
  static const surfaceCard = Colors.white;
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const error = Color(0xFFEF4444);

  static final theme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ),
    textTheme: GoogleFonts.interTextTheme(),
  );
}

// Models
class CropOption {
  final String id;
  final String nameEn;
  final String nameTe;
  final IconData icon;
  final Color color;

  const CropOption(this.id, this.nameEn, this.nameTe, this.icon, this.color);
}

class BookingState {
  final CropOption? crop;
  final double acres;
  final DateTime serviceDate;
  final double costPerAcre;

  BookingState({
    this.crop,
    this.acres = 1.0,
    DateTime? serviceDate,
    this.costPerAcre = 300.0,
  }) : serviceDate = serviceDate ?? DateTime.now();

  double get totalCost => acres * costPerAcre;

  bool get isValid => crop != null && acres > 0;

  BookingState copyWith({
    CropOption? crop,
    double? acres,
    DateTime? serviceDate,
  }) {
    return BookingState(
      crop: crop ?? this.crop,
      acres: acres ?? this.acres,
      serviceDate: serviceDate ?? this.serviceDate,
      costPerAcre: costPerAcre,
    );
  }
}

// Main Screen
class DroneBookingScreen extends StatefulWidget {
  const DroneBookingScreen({super.key});

  @override
  State<DroneBookingScreen> createState() => _DroneBookingScreenState();
}

class _DroneBookingScreenState extends State<DroneBookingScreen> {
  late BookingState _state;
  bool _isSubmitting = false;

  static const _crops = [
    CropOption('rice', 'Rice', 'వరి', Icons.grass, Color(0xFF10B981)),
    CropOption(
        'corn', 'Corn', 'మొక్కజొన్న', Icons.agriculture, Color(0xFFF59E0B)),
    CropOption(
        'cotton', 'Cotton', 'పత్తి', Icons.spa_outlined, Color(0xFF8B5CF6)),
    CropOption(
        'tomato', 'Tomato', 'టమాటో', Icons.local_florist, Color(0xFFEF4444)),
    CropOption(
        'groundnut', 'Groundnut', 'వేరుశెనగ', Icons.eco, Color(0xFF78716C)),
    CropOption('chilli', 'Chilli', 'మిర్చి', Icons.local_fire_department,
        Color(0xFFDC2626)),
  ];

  @override
  void initState() {
    super.initState();
    _state =
        BookingState(serviceDate: DateTime.now().add(const Duration(days: 1)));
  }

  void _updateState(BookingState newState) {
    setState(() => _state = newState);
    HapticFeedback.lightImpact();
  }

  Future<void> _submitBooking() async {
    if (!_state.isValid) {
      _showSnackBar('దయచేసి అన్ని వివరాలను నింపండి', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      await Future.delayed(const Duration(seconds: 2)); // Simulate API call

      if (!mounted) return;

      final bookingId = 'DRN${DateTime.now().millisecondsSinceEpoch ~/ 1000}';

      await _showSuccessDialog(bookingId);

      // Reset state
      setState(() {
        _state = BookingState(
            serviceDate: DateTime.now().add(const Duration(days: 1)));
      });
    } catch (e) {
      _showSnackBar('బుకింగ్ విఫలమైంది. మళ్లీ ప్రయత్నించండి', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        backgroundColor: isError ? AppTheme.error : AppTheme.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _showSuccessDialog(String bookingId) async {
    HapticFeedback.heavyImpact();

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
                  color: AppTheme.accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    size: 48, color: AppTheme.accent),
              ),
              const SizedBox(height: 24),
              Text(
                'బుకింగ్ విజయవంతమైంది!',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'మీ డ్రోన్ సేవ నిర్ధారించబడింది',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _DetailRow('బుకింగ్ ID', bookingId),
                    const Divider(height: 20),
                    _DetailRow('పంట', _state.crop!.nameTe),
                    const Divider(height: 20),
                    _DetailRow('ఎకరాలు', _state.acres.toStringAsFixed(1)),
                    const Divider(height: 20),
                    _DetailRow('తేదీ',
                        DateFormat('dd MMM yyyy').format(_state.serviceDate)),
                    const Divider(height: 20),
                    _DetailRow(
                        'మొత్తం', '₹${_state.totalCost.toStringAsFixed(0)}'),
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
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child:
                      const Text('పూర్తయింది', style: TextStyle(fontSize: 16)),
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
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'డ్రోన్ సేవ బుకింగ్',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const _SectionHeader('పంట రకం ఎంచుకోండి'),
                    const SizedBox(height: 16),
                    _CropSelector(
                      crops: _crops,
                      selected: _state.crop,
                      onSelect: (crop) =>
                          _updateState(_state.copyWith(crop: crop)),
                    ),
                    const SizedBox(height: 32),
                    const _SectionHeader('విస్తీర్ణం (ఎకరాలు)'),
                    const SizedBox(height: 16),
                    _AcreSlider(
                      value: _state.acres,
                      onChanged: (acres) =>
                          _updateState(_state.copyWith(acres: acres)),
                    ),
                    const SizedBox(height: 32),
                    const _SectionHeader('సేవ తేదీ'),
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
        color: AppTheme.textPrimary,
      ),
    );
  }
}

// Crop Selector Widget
class _CropSelector extends StatelessWidget {
  final List<CropOption> crops;
  final CropOption? selected;
  final ValueChanged<CropOption> onSelect;

  const _CropSelector({
    required this.crops,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 32) / 3;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: crops.map((crop) {
            final isSelected = selected?.id == crop.id;
            return SizedBox(
              width: width,
              child: _CropCard(
                crop: crop,
                isSelected: isSelected,
                onTap: () => onSelect(crop),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _CropCard extends StatelessWidget {
  final CropOption crop;
  final bool isSelected;
  final VoidCallback onTap;

  const _CropCard({
    required this.crop,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected ? crop.color.withOpacity(0.1) : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? crop.color : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: crop.color.withOpacity(0.2),
                      blurRadius: 12,
                      spreadRadius: 2)
                ]
              : [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04), blurRadius: 8)
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(crop.icon,
                size: 32,
                color: isSelected ? crop.color : AppTheme.textSecondary),
            const SizedBox(height: 8),
            Text(
              crop.nameTe,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? crop.color : AppTheme.textPrimary,
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
  final ValueChanged<double> onChanged;

  const _AcreSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
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
                '${value.toStringAsFixed(1)} ఎకరాలు',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '₹${(value * 300).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              activeTrackColor: AppTheme.primary,
              inactiveTrackColor: AppTheme.surface,
              thumbColor: AppTheme.primary,
              overlayColor: AppTheme.primary.withOpacity(0.1),
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
                      TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              Text('100',
                  style:
                      TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
    final dates =
        List.generate(14, (i) => DateTime.now().add(Duration(days: i + 1)));

    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
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
          isSelected: DateUtils.isSameDay(dates[i], selected),
          onTap: () => onSelect(dates[i]),
        ),
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final VoidCallback onTap;

  const _DateCard({
    required this.date,
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
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('EEE').format(date),
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white70 : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd').format(date),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            Text(
              DateFormat('MMM').format(date),
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white70 : AppTheme.textSecondary,
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
  final BookingState state;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _BottomBar({
    required this.state,
    required this.isSubmitting,
    required this.onSubmit,
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
              color: AppTheme.surfaceCard.withOpacity(0.95),
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'మొత్తం ఖర్చు',
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${state.totalCost.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 160,
                    height: 56,
                    child: FilledButton(
                      onPressed:
                          isSubmitting || !state.isValid ? null : onSubmit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        disabledBackgroundColor: AppTheme.textSecondary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check, size: 20),
                                SizedBox(width: 8),
                                Text('బుక్ చేయండి',
                                    style: TextStyle(fontSize: 16)),
                              ],
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

// Detail Row for Success Dialog
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
