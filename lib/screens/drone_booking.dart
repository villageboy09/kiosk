// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cropsync/main.dart';
import 'package:intl/intl.dart';
import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:confetti/confetti.dart';

class DroneBookingScreen extends StatefulWidget {
  const DroneBookingScreen({super.key});

  @override
  State<DroneBookingScreen> createState() => _DroneBookingScreenState();
}

class _DroneBookingScreenState extends State<DroneBookingScreen>
    with TickerProviderStateMixin {
  String? _selectedCropType;
  int _selectedAcres = 1;
  DateTime _selectedDate = DateTime.now();
  double _totalCost = 0.0;
  bool _isSaving = false;
  final double _costPerAcre = 300.0;

  late ConfettiController _confettiController;
  late AnimationController _ticketController;
  late Animation<double> _ticketAnimation;

  String? _bookingId;
  bool _showSuccessPopup = false;

  final List<CropType> _cropTypes = [
    CropType('వరి', 'Rice', Icons.grass, const Color(0xFF4CAF50)),
    CropType('మొక్కజొన్న', 'Corn', Icons.agriculture, const Color(0xFFFFC107)),
    CropType('దుంప', 'Potato', Icons.local_florist, const Color(0xFF8BC34A)),
    CropType(
        'టమాటో', 'Tomato', Icons.local_grocery_store, const Color(0xFFF44336)),
    CropType('కాపర్', 'Cotton', Icons.cloud, const Color(0xFF9C27B0)),
    CropType('వేరుశెనగ', 'Groundnut', Icons.eco, const Color(0xFF795548)),
  ];

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _ticketController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _ticketAnimation = CurvedAnimation(
      parent: _ticketController,
      curve: Curves.elasticOut,
    );
    _calculateCost();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _ticketController.dispose();
    super.dispose();
  }

  void _calculateCost() {
    setState(() {
      _totalCost = _selectedAcres * _costPerAcre;
    });
  }

  void _selectCropType(String cropType) {
    setState(() {
      _selectedCropType = cropType;
    });
  }

  void _updateAcres(int change) {
    setState(() {
      _selectedAcres = (_selectedAcres + change).clamp(1, 100);
      _calculateCost();
    });
  }

  Future<void> _submitBooking() async {
    if (_selectedCropType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('దయచేసి పంట రకాన్ని ఎంచుకోండి')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final farmerResponse = await supabase
          .from('farmers')
          .select('id')
          .eq('user_id', supabase.auth.currentUser!.id)
          .single();
      final farmerId = farmerResponse['id'];

      _bookingId =
          'DRN-${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}';

      await supabase.from('drone_service_bookings').insert({
        'farmer_id': farmerId,
        'booking_id_text': _bookingId,
        'crop_type': _selectedCropType,
        'acres': _selectedAcres,
        'total_cost': _totalCost,
        'service_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'booking_status': 'Successful',
      });

      if (mounted) {
        setState(() {
          _showSuccessPopup = true;
        });
        _confettiController.play();
        _ticketController.forward();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('బుకింగ్ విఫలమైంది: ${e.toString()}'),
            backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _closeSuccessPopup() {
    setState(() {
      _showSuccessPopup = false;
      _selectedCropType = null;
      _selectedAcres = 1;
      _selectedDate = DateTime.now();
      _totalCost = 0;
    });
    _ticketController.reset();
    _calculateCost();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'డ్రోన్ సేవ బుకింగ్',
          style: GoogleFonts.poppins(
            color: const Color(0xFF222222),
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF222222)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('పంట రకం ఎంచుకోండి'),
                const SizedBox(height: 16),
                _buildCropTypeGrid(),
                const SizedBox(height: 32),
                _buildSectionTitle('ఎకరాలు'),
                const SizedBox(height: 16),
                _buildAcreSelector(),
                const SizedBox(height: 32),
                _buildSectionTitle('సేవ తేదీ'),
                const SizedBox(height: 16),
                _buildDatePicker(),
                const SizedBox(height: 32),
                _buildPricingSummary(),
                const SizedBox(height: 32),
                _buildBookingButton(),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 1.57,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.05,
              shouldLoop: false,
            ),
          ),

          // Success popup
          if (_showSuccessPopup) _buildSuccessPopup(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF222222),
      ),
    );
  }

  Widget _buildCropTypeGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: _cropTypes.length,
      itemBuilder: (context, index) {
        final crop = _cropTypes[index];
        final isSelected = _selectedCropType == crop.telugu;

        return GestureDetector(
          onTap: () => _selectCropType(crop.telugu),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? crop.color.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? crop.color : const Color(0xFFE0E0E0),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  crop.icon,
                  size: 32,
                  color: isSelected ? crop.color : const Color(0xFF666666),
                ),
                const SizedBox(height: 8),
                Text(
                  crop.telugu,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? crop.color : const Color(0xFF222222),
                  ),
                ),
                Text(
                  crop.english,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAcreSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'ఎకరాలు',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF222222),
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => _updateAcres(-1),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: const Icon(Icons.remove,
                      size: 20, color: Color(0xFF666666)),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$_selectedAcres',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF222222),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _updateAcres(1),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F4C75),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, size: 20, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: EasyDateTimeLine(
        initialDate: _selectedDate,
        onDateChange: (selectedDate) {
          setState(() {
            _selectedDate = selectedDate;
          });
        },
        dayProps: const EasyDayProps(
          height: 80,
          width: 64,
        ),
        headerProps: const EasyHeaderProps(
          monthPickerType: MonthPickerType.switcher,
          dateFormatter: DateFormatter.fullDateDMY(),
        ),
        activeColor: const Color(0xFF0F4C75),
        locale: 'te_IN',
      ),
    );
  }

  Widget _buildPricingSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F4C75), Color(0xFF3282B8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F4C75).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ఎకరాలకు రేటు',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              Text(
                '₹$_costPerAcre / ఎకరం',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'మొత్తం ఎకరాలు',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              Text(
                '$_selectedAcres ఎకరాలు',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'మొత్తం ఖర్చు',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                '₹${_totalCost.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _submitBooking,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF385C),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'బుకింగ్ నిర్ధారించండి',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildSuccessPopup() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: ScaleTransition(
          scale: _ticketAnimation,
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'బుకింగ్ విజయవంతమైంది!',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF222222),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'మీ డ్రోన్ సేవ బుకింగ్ నిర్ధారించబడింది',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF666666),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Ticket-style booking details
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Column(
                    children: [
                      _buildTicketRow('బుకింగ్ ID', _bookingId ?? ''),
                      _buildTicketRow('పంట రకం', _selectedCropType ?? ''),
                      _buildTicketRow('ఎకరాలు', '$_selectedAcres ఎకరాలు'),
                      _buildTicketRow('సేవ తేదీ',
                          DateFormat('dd MMMM yyyy').format(_selectedDate)),
                      _buildTicketRow(
                          'మొత్తం ఖర్చు', '₹${_totalCost.toStringAsFixed(0)}'),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _closeSuccessPopup,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFFF385C)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'మరో బుకింగ్',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFFF385C),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF385C),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'హోమ్‌కు వెళ్లు',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildTicketRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF666666),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF222222),
            ),
          ),
        ],
      ),
    );
  }
}

class CropType {
  final String telugu;
  final String english;
  final IconData icon;
  final Color color;

  CropType(this.telugu, this.english, this.icon, this.color);
}
