import 'package:flutter/material.dart';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';

import 'package:cropsync/models/chc_operator.dart';
import 'package:cropsync/services/api_service.dart';

class ManualOrderSheet extends StatefulWidget {
  final ChcOperator operator;
  final Map<String, dynamic>? prefillBooking;
  const ManualOrderSheet(
      {super.key, required this.operator, this.prefillBooking});

  @override
  State<ManualOrderSheet> createState() => _ManualOrderSheetState();
}

class _ManualOrderSheetState extends State<ManualOrderSheet> {
  final _pageController = PageController();
  int _currentStep = 1; // 1: Farmer, 2: Usage, 3: Receipt

  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _villageController = TextEditingController();
  final _qtyController = TextEditingController();
  final _distanceController = TextEditingController();
  final _cropController = TextEditingController();
  final _landSizeController = TextEditingController();
  final _rateController = TextEditingController();

  Map<String, dynamic>? _selectedEquipment;
  List<Map<String, dynamic>> _equipmentList = [];
  bool _isFetchingUser = false;
  bool _isFetchingEquipments = false;
  bool _isFoundMember = false;
  bool _isCrossClientMember = false;
  bool _isNewUser = true;
  DateTime? _serviceDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  double _ratePerUnit = 0.0;
  bool _isLoading = false;
  String? _errorMsg;
  Map<String, dynamic>? _submissionResult;
  Timer? _phoneDebounce;

  static const Color _accent = Color(0xFF111827);
  static const Color _bg = Color(0xFFFAFAFA);
  static const Color _slate = Color(0xFF475569);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
    _rateController.addListener(() => setState(() {}));
    _qtyController.addListener(() => setState(() {}));
    _distanceController.addListener(() => setState(() {}));
    _serviceDate = DateTime.now();
    _startTime = TimeOfDay.now();
    _endTime = TimeOfDay.now();

    if (widget.prefillBooking != null) {
      final b = widget.prefillBooking!;
      if (b['farmer_phone'] != null) {
        _phoneController.text = b['farmer_phone'].toString();
      }
      if (b['farmer_name'] != null) {
        _nameController.text = b['farmer_name'].toString();
      }
      if (b['farmer_village'] != null) {
        _villageController.text = b['farmer_village'].toString();
      }
      if (b['service_date'] != null) {
        try {
          _serviceDate = DateTime.parse(b['service_date'].toString());
        } catch (_) {}
      }
      if (b['crop_type'] != null) {
        _cropController.text = b['crop_type'].toString();
      }
      if (b['land_size_acres'] != null) {
        _landSizeController.text = b['land_size_acres'].toString();
      }

      unawaited(_loadEquipments().then((_) {
        if (b['equipment_type'] != null && mounted) {
          try {
            final eq = _equipmentList.firstWhere(
              (e) =>
                  e['name_en'] == b['equipment_type'] ||
                  e['name_te'] == b['equipment_type'],
            );
            setState(() {
              _selectedEquipment = eq;
              if (b['billed_qty'] != null) {
                _qtyController.text = b['billed_qty'].toString();
              }
            });
            _updateRate();
          } catch (_) {}
        }
      }));
    } else {
      unawaited(_loadEquipments());
    }
  }

  void _onPhoneChanged() {
    if (!mounted) return;
    _phoneDebounce?.cancel();
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      if (_isFetchingUser || _isFoundMember || !_isNewUser) {
        setState(() {
          _isFetchingUser = false;
          _isFoundMember = false;
          _isCrossClientMember = false;
          _isNewUser = true;
        });
        unawaited(_loadEquipments());
      }
      return;
    }
    _phoneDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }
      unawaited(_lookupUserByPhone(phone));
    });
  }

  Future<void> _lookupUserByPhone(String phone) async {
    if (!mounted) return;
    setState(() => _isFetchingUser = true);
    try {
      final user = await ApiService.checkUser(phone);
      if (!mounted || _phoneController.text.trim() != phone) return;
      final bool matchesClient =
          user != null && user['client_code'] == widget.operator.clientCode;
      setState(() {
        _isFoundMember = matchesClient;
        _isCrossClientMember = user != null && !matchesClient;
        _isNewUser = user == null;
        _isFetchingUser = false;
        if (user != null) {
          _nameController.text = (user['name'] ?? '').toString().trim();
          _villageController.text =
              (user['village'] ?? user['region'] ?? '').toString();
        }
      });
      await _loadEquipments();
      await _updateRate();
    } catch (_) {
      setState(() => _isFetchingUser = false);
    }
  }

  Future<void> _loadEquipments() async {
    if (!mounted) return;
    setState(() => _isFetchingEquipments = true);
    try {
      final list = await ApiService.getCHCEquipments(
        isMember: _isFoundMember,
        clientCode: widget.operator.clientCode,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _equipmentList = list;
        if (_selectedEquipment == null ||
            !_equipmentList.any((e) => e['id'] == _selectedEquipment?['id'])) {
          _selectedEquipment =
              _equipmentList.isNotEmpty ? _equipmentList.first : null;
        }
        _isFetchingEquipments = false;
      });
      _updateRate();
    } catch (_) {
      setState(() => _isFetchingEquipments = false);
    }
  }

  Future<void> _updateRate() async {
    if (_selectedEquipment == null) return;
    if (widget.operator.clientCode != 'SDP001' ||
        _isCrossClientMember ||
        _isNewUser) {
      setState(() => _ratePerUnit = 0.0);
      return;
    }

    if (_isTractorTrolley) {
      if (_distance <= 0) {
        setState(() => _ratePerUnit = 0.0);
        return;
      }
      try {
        final res = await ApiService.calculateTrolleyPrice(
          equipmentId: _selectedEquipment!['id'],
          clientCode: widget.operator.clientCode,
          distance: _distance,
          isMember: _isFoundMember,
        );
        if (mounted) {
          setState(() {
            _ratePerUnit = res['success'] == true
                ? (double.tryParse(res['price']?.toString() ?? '0') ?? 0.0)
                : 0.0;
            if (_ratePerUnit > 0) {
              _rateController.text = _ratePerUnit.toStringAsFixed(0);
            }
          });
        }
      } catch (_) {}
    } else {
      final newRate = double.tryParse((_isFoundMember
                      ? _selectedEquipment!['price_member']
                      : _selectedEquipment!['price_non_member'])
                  ?.toString() ??
              '0') ??
          0.0;
      setState(() {
        _ratePerUnit = newRate;
        if (_ratePerUnit > 0) {
          _rateController.text = _ratePerUnit.toStringAsFixed(0);
        }
      });
    }
  }

  bool get _isTimeBased => (_selectedEquipment?['unit'] ?? '')
      .toString()
      .toLowerCase()
      .contains('hour');
  bool get _isTractorTrolley => (_selectedEquipment?['name_en'] ?? '')
      .toString()
      .toLowerCase()
      .contains('trolley');
  double get _distance =>
      double.tryParse(_distanceController.text.trim()) ?? 0.0;
  double get _quantity => double.tryParse(_qtyController.text.trim()) ?? 0.0;
  double get _totalHours {
    if (_startTime == null || _endTime == null) return 0.0;
    final start = _startTime!.hour * 60 + _startTime!.minute;
    final end = _endTime!.hour * 60 + _endTime!.minute;
    final diff = end >= start ? end - start : (end + 1440) - start;
    return diff / 60.0;
  }

  double get _billedQty => _isTimeBased ? _totalHours : _quantity;
  double get _finalAmount {
    final rate = _ratePerUnit > 0
        ? _ratePerUnit
        : (double.tryParse(_rateController.text) ?? 0.0);
    return rate * _billedQty;
  }

  String get _measuredUnit => _isTimeBased
      ? 'hour'
      : (_isTractorTrolley
          ? 'trip'
          : (_selectedEquipment?['unit'] ?? 'unit').toString());

  bool get _canGoToStep2 =>
      _phoneController.text.length == 10 &&
      _nameController.text.isNotEmpty &&
      _villageController.text.isNotEmpty;
  bool get _canSubmit {
    if (!_canGoToStep2 || _selectedEquipment == null) {
      return false;
    }
    // If rate is still 0, operator MUST enter it manually
    final manualRate = double.tryParse(_rateController.text) ?? 0.0;
    if (_ratePerUnit <= 0 && manualRate <= 0) {
      return false;
    }

    if (_isTimeBased) return _totalHours > 0;
    if (_isTractorTrolley) return _distance > 0 && _quantity > 0;
    return _quantity > 0;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.completeBookingManual(
        operatorId: widget.operator.operatorId,
        bookingId: widget.prefillBooking?['booking_id']?.toString(),
        farmerPhone: _phoneController.text.trim(),
        farmerName: _nameController.text.trim(),
        village: _villageController.text.trim(),
        equipmentUsed: _selectedEquipment!['name_en'] ?? 'Equipment',
        equipmentId: _selectedEquipment!['id'],
        startTime: _isTimeBased
            ? '${_startTime!.hour}:${_startTime!.minute}'
            : '00:00',
        endTime:
            _isTimeBased ? '${_endTime!.hour}:${_endTime!.minute}' : '00:00',
        distance: _isTractorTrolley ? _distance : 0,
        serviceDate:
            '${_serviceDate!.year}-${_serviceDate!.month}-${_serviceDate!.day}',
        cropType: _cropController.text.isNotEmpty ? _cropController.text : null,
        landSizeAcres: double.tryParse(_landSizeController.text) ?? 0,
        billedQty: _billedQty,
        unitType: _measuredUnit,
        rate: _ratePerUnit > 0
            ? _ratePerUnit
            : (double.tryParse(_rateController.text) ?? 0.0),
        finalAmount: _finalAmount,
      );

      if (res['success'] == true) {
        setState(() {
          _submissionResult = res;
          _currentStep = 4;
          _isLoading = false;
        });
        _pageController.animateToPage(3,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut);
      } else {
        setState(() {
          _errorMsg = res['error'] ?? 'operator_log_job_failed'.tr();
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _errorMsg = 'operator_network_error_try_again'.tr();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _currentStep == 4
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: _accent, size: 20),
                onPressed: () {
                  if (_currentStep > 1) {
                    _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut);
                    setState(() => _currentStep--);
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
              title: Column(
                children: [
                  Text(_currentStep == 3
                      ? 'operator_review_bill'.tr()
                      : 'operator_job_completion_title'.tr(),
                      style: const TextStyle(
                          color: _accent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  if (_currentStep < 3)
                    Text('${'step'.tr()} $_currentStep ${'of'.tr()} 2',
                        style: const TextStyle(color: _slate, fontSize: 11)),
                ],
              ),
              centerTitle: true,
            ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildStep1(),
          _buildStep2(),
          _buildStep3(),
          _buildStep4(),
        ],
      ),
      bottomNavigationBar: _currentStep < 3 ? _buildBottomNav() : null,
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle(
                  Icons.person_pin_circle_rounded, 'operator_farmer'.tr()),
              if (_phoneController.text.length == 10 && !_isFetchingUser)
                _memberBadge(
                    _isFoundMember ? 1 : (_isCrossClientMember ? 2 : 0)),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(_phoneController, 'operator_phone_number_label'.tr(),
              Icons.phone_rounded, TextInputType.phone,
              suffixIcon: _isFetchingUser
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _accent)),
                    )
                  : null),
          const SizedBox(height: 16),
          _buildTextField(_nameController, 'operator_farmer_name_label'.tr(),
              Icons.person_rounded, TextInputType.name),
          const SizedBox(height: 16),
          _buildTextField(_villageController, 'village'.tr(),
              Icons.location_on_rounded, TextInputType.text),
          const SizedBox(height: 24),
          _sectionTitle(
              Icons.calendar_today_rounded, 'operator_service_date'.tr()),
          const SizedBox(height: 12),
          _buildDateButton(),
          const SizedBox(height: 24),
          _sectionTitle(Icons.grass_rounded, 'operator_crop_type_label'.tr()),
          const SizedBox(height: 12),
          _buildTextField(_cropController, 'operator_crop_type_optional'.tr(),
              Icons.spa_rounded, TextInputType.text),
          const SizedBox(height: 16),
          _buildTextField(
              _landSizeController,
              'operator_land_size_acres_label'.tr(),
              Icons.square_foot_rounded,
              TextInputType.number,
              suffix: 'acres'.tr()),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(
            Icons.agriculture_rounded, 'operator_equipment_used_label'.tr()),
        const SizedBox(height: 16),
        _buildEquipmentGrid(),
        const SizedBox(height: 24),
        _sectionTitle(Icons.speed_rounded, 'operator_usage'.tr()),
        const SizedBox(height: 16),
        if (_isTimeBased)
          _buildTimeSelectors()
        else if (_isTractorTrolley) ...[
          _buildTextField(
              _distanceController,
              'operator_distance_per_trip_label'.tr(),
              Icons.add_road_rounded,
              TextInputType.number,
              suffix: 'KM'),
          const SizedBox(height: 16),
          _buildTextField(_qtyController, 'operator_total_trips_label'.tr(),
              Icons.repeat_rounded, TextInputType.number),
        ] else ...[
          _buildTextField(
              _qtyController,
              'operator_quantity_label'.tr(namedArgs: {'unit': _measuredUnit}),
              Icons.calculate_rounded,
              TextInputType.number),
        ],
        const SizedBox(height: 24),
        _sectionTitle(Icons.payments_rounded, 'chc_rate_label'.tr()),
        const SizedBox(height: 16),
        _buildTextField(
          _rateController,
          'chc_rate_label'.tr(),
          Icons.currency_rupee_rounded,
          TextInputType.number,
          suffix: '/ ${_measuredUnit.tr()}',
        ),
        if (_errorMsg != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_errorMsg!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _buildStep3() {
    final rate = _ratePerUnit > 0
        ? _ratePerUnit
        : (double.tryParse(_rateController.text) ?? 0.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
              Icons.receipt_long_rounded, 'operator_review_bill'.tr()),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              children: [
                _receiptRow('operator_farmer'.tr(), _nameController.text),
                _receiptRow('village'.tr(), _villageController.text),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('operator_label'.tr(),
                        style: const TextStyle(color: _slate, fontSize: 14)),
                    _memberBadge(
                        _isFoundMember ? 1 : (_isCrossClientMember ? 2 : 0)),
                  ],
                ),
                const Divider(height: 32, color: Color(0xFFF1F5F9)),
                _receiptRow('operator_equipment_used_label'.tr(),
                    _selectedEquipment?['name_en'] ?? ''),
                if (_isTimeBased)
                  _receiptRow('operator_duration'.tr(),
                      '${_startTime?.format(context) ?? '--:--'} → ${_endTime?.format(context) ?? '--:--'} (${_totalHours.toStringAsFixed(1)} hrs)')
                else if (_isTractorTrolley) ...[
                  _receiptRow('operator_distance'.tr(), '$_distance KM'),
                  _receiptRow('operator_trips'.tr(), _qtyController.text),
                ] else
                  _receiptRow('operator_quantity'.tr(),
                      '${_qtyController.text} $_measuredUnit'),
                _receiptRow('chc_rate_label'.tr(),
                    '₹${rate.toStringAsFixed(0)} / ${_measuredUnit.tr()}'),
                const Divider(height: 32, color: _border),
                _receiptRow('operator_total_bill'.tr(),
                    '₹${_finalAmount.toStringAsFixed(0)}',
                    isTotal: true),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('operator_confirm_complete'.tr(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut);
                setState(() => _currentStep = 2);
              },
              child: Text('cancel'.tr(),
                  style: const TextStyle(
                      color: _slate, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    return Container(
      color: _accent,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 60),
              const Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white, size: 80),
              const SizedBox(height: 16),
              Text('success'.tr(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_submissionResult?['booking_id'] != null) ...[
                        _receiptRow('detail_booking_id'.tr(),
                            '#${_submissionResult!['booking_id']}'),
                        const Divider(height: 24, color: Color(0xFFF1F5F9)),
                      ],
                      _receiptRow('operator_farmer'.tr(), _nameController.text),
                      _receiptRow('village'.tr(), _villageController.text),
                      _receiptRow('operator_equipment_used_label'.tr(),
                          _selectedEquipment?['name_en'] ?? ''),
                      const Divider(height: 32),
                      _receiptRow('operator_total_bill'.tr(),
                          '₹${_finalAmount.toStringAsFixed(0)}',
                          isTotal: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('done_button'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final canNext = _currentStep == 1 ? _canGoToStep2 : _canSubmit;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
          color: Colors.white, border: Border(top: BorderSide(color: _border))),
      child: SizedBox(
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            disabledBackgroundColor: _border,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: !canNext || _isLoading
              ? null
              : () {
                  if (_currentStep == 1) {
                    _pageController.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut);
                    setState(() => _currentStep = 2);
                  } else if (_currentStep == 2) {
                    _pageController.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut);
                    setState(() => _currentStep = 3);
                  }
                },
          child: Text(
            _currentStep == 1
                ? 'operator_next_usage'.tr()
                : 'operator_preview_bill'.tr(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      IconData icon, TextInputType type,
      {String? suffix, Widget? suffixIcon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: _slate, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: type,
          style: const TextStyle(fontWeight: FontWeight.w600),
          onChanged: (_) {
            if (controller == _distanceController) {
              _updateRate();
            }
            setState(() {});
          },
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: _slate, size: 20),
            suffixText: suffix,
            suffixIcon: suffixIcon,
            hintText: 'enter_field'.tr(namedArgs: {'field': label}),
            hintStyle: const TextStyle(
                color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _accent, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: _accent, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: _accent)),
      ],
    );
  }

  Widget _buildDateButton() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
            context: context,
            initialDate: _serviceDate ?? DateTime.now(),
            firstDate: DateTime.now().subtract(const Duration(days: 30)),
            lastDate: DateTime.now().add(const Duration(days: 30)));
        if (picked != null) setState(() => _serviceDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border)),
        child: Row(
          children: [
            const Icon(Icons.event_note_rounded, color: _slate, size: 20),
            const SizedBox(width: 12),
            Text(DateFormat('dd MMM, yyyy').format(_serviceDate!),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_down_rounded, color: _slate),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentGrid() {
    return _isFetchingEquipments
        ? const Center(child: CircularProgressIndicator())
        : GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85),
            itemCount: _equipmentList.length,
            itemBuilder: (ctx, i) {
              final eq = _equipmentList[i];
              final isSel =
                  _selectedEquipment?['id']?.toString() == eq['id']?.toString();
              return InkWell(
                onTap: () {
                  setState(() => _selectedEquipment = eq);
                  _updateRate();
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: isSel ? _accent : _border, width: isSel ? 2 : 1),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                                color: _accent.withValues(alpha: 0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4))
                          ]
                        : [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2))
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSel ? _accent.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                            border: const Border(bottom: BorderSide(color: _border, width: 1)),
                          ),
                          child: Image.asset(
                            _getImagePath(eq['name_en']),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          child: Text(eq['name_en'] ?? '',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: _accent,
                                  fontSize: 13,
                                  height: 1.1,
                                  fontWeight: isSel ? FontWeight.w800 : FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  String _getImagePath(String? name) {
    name = name?.toLowerCase() ?? '';
    if (name.contains('trolley')) return 'assets/chc_equipments/tractor_trolley.webp';
    if (name.contains('tractor')) return 'assets/chc_equipments/tractor.webp';
    if (name.contains('drone')) return 'assets/chc_equipments/agri_drone.webp';
    if (name.contains('harvester')) return 'assets/chc_equipments/combined_harvester.webp';
    if (name.contains('baler')) return 'assets/chc_equipments/balers.webp';
    if (name.contains('sprayer')) return 'assets/chc_equipments/boom_sprayer.webp';
    if (name.contains('seeder')) return 'assets/chc_equipments/manual_seeder.png';
    if (name.contains('dryer')) return 'assets/chc_equipments/mobile_grain_dryer.webp';
    if (name.contains('drill')) return 'assets/chc_equipments/seed_cum_fertilizer_drill.webp';
    if (name.contains('shredder')) return 'assets/chc_equipments/shredder.webp';
    return 'assets/chc_equipments/tractor.webp';
  }

  Widget _buildTimeSelectors() {
    return Row(
      children: [
        Expanded(child: _timeBtn(true)),
        const SizedBox(width: 12),
        Expanded(child: _timeBtn(false)),
      ],
    );
  }

  Widget _timeBtn(bool isStart) {
    final time = isStart ? _startTime : _endTime;
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time ?? TimeOfDay.now(),
          builder: (context, child) {
            return Localizations.override(
              context: context,
              locale: const Locale('en', 'US'),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
                child: child!,
              ),
            );
          },
        );
        if (picked != null) {
          setState(() {
            if (isStart) {
              _startTime = picked;
            } else {
              _endTime = picked;
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isStart ? 'START' : 'END',
                style: const TextStyle(
                    fontSize: 10, color: _slate, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 16, color: _accent),
                const SizedBox(width: 8),
                Text(
                    time == null
                        ? '--:--'
                        : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _receiptRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: isTotal ? _accent : _slate,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  fontSize: isTotal ? 16 : 14)),
          Text(value,
              style: TextStyle(
                  color: _accent,
                  fontWeight: FontWeight.bold,
                  fontSize: isTotal ? 20 : 14)),
        ],
      ),
    );
  }

  Widget _memberBadge(int state) {
    final isMember = state == 1;
    final isCross = state == 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isMember
            ? const Color(0xFFF1F5F9)
            : (isCross ? const Color(0xFFFFFBEB) : const Color(0xFFF9FAFB)),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isMember
              ? const Color(0xFFCBD5E1)
              : (isCross ? const Color(0xFFFDE68A) : const Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMember
                ? Icons.verified_user_rounded
                : (isCross
                    ? Icons.share_location_rounded
                    : Icons.person_add_rounded),
            size: 14,
            color: isMember
                ? const Color(0xFF475569)
                : (isCross ? const Color(0xFFB45309) : const Color(0xFF6B7280)),
          ),
          const SizedBox(width: 4),
          Text(
            isMember
                ? 'member'.tr()
                : (isCross
                    ? 'operator_other_client'.tr()
                    : 'operator_new_user'.tr()),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isMember
                  ? const Color(0xFF475569)
                  : (isCross
                      ? const Color(0xFFB45309)
                      : const Color(0xFF6B7280)),
            ),
          ),
        ],
      ),
    );
  }
}
