import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';

import 'package:cropsync/models/chc_operator.dart';
import 'package:cropsync/services/api_service.dart';

class ManualOrderSheet extends StatefulWidget {
  final ChcOperator operator;
  const ManualOrderSheet({super.key, required this.operator});

  @override
  State<ManualOrderSheet> createState() => _ManualOrderSheetState();
}

class _ManualOrderSheetState extends State<ManualOrderSheet> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _villageController = TextEditingController();
  final _qtyController = TextEditingController();
  final _distanceController = TextEditingController();
  final _cropController = TextEditingController();
  final _landSizeController = TextEditingController();

  Map<String, dynamic>? _selectedEquipment;
  List<Map<String, dynamic>> _equipmentList = [];
  bool _isFetchingUser = false;
  bool _isFetchingEquipments = false;
  bool _isFetchingRate = false;
  bool _isFoundMember = false;
  DateTime? _serviceDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  double _ratePerUnit = 0.0;
  bool _isLoading = false;
  bool _showPreview = false;
  String? _errorMsg;
  String? _successMsg;

  static const Color _green = Color(0xFF059669);
  static const Color _surface = Color(0xFFF4F6FA);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSub = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _loadEquipments();
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    final phone = _phoneController.text.trim();
    if (phone.length == 10 && !_isFetchingUser) {
      _fetchUser(phone);
    } else if (phone.length < 10 && _isFoundMember) {
      setState(() {
        _isFoundMember = false;
        _nameController.clear();
        _villageController.clear();
        _showPreview = false;
      });
      unawaited(_updateRate());
    }
  }

  Future<void> _fetchUser(String phone) async {
    setState(() => _isFetchingUser = true);
    final user = await ApiService.checkUser(phone);

    if (!mounted) return;

    setState(() {
      if (user != null) {
        _isFoundMember =
            user['card_uid'] != null && user['card_uid'].toString().isNotEmpty;
        _nameController.text = user['name']?.toString() ?? '';
        _villageController.text = user['village']?.toString() ?? '';
      } else {
        _isFoundMember = false;
        _nameController.clear();
        _villageController.clear();
      }
      _isFetchingUser = false;
      _showPreview = false;
    });

    unawaited(_updateRate());
  }

  Future<void> _loadEquipments() async {
    setState(() => _isFetchingEquipments = true);
    final list = await ApiService.getCHCEquipments(
      clientCode: widget.operator.clientCode,
    );
    if (!mounted) return;

    setState(() {
      _equipmentList = list;
      if (_equipmentList.isNotEmpty) {
        _selectedEquipment = _equipmentList.first;
        _ratePerUnit = 0.0;
      }
      _isFetchingEquipments = false;
    });

    unawaited(_updateRate());
  }

  double get _totalHours {
    if (_startTime == null || _endTime == null) return 0;
    final startMins = _startTime!.hour * 60 + _startTime!.minute;
    final endMins = _endTime!.hour * 60 + _endTime!.minute;
    final diff = endMins - startMins;
    return diff > 0 ? diff / 60.0 : 0;
  }

  double get _quantity => double.tryParse(_qtyController.text) ?? 0;
  double get _distance => double.tryParse(_distanceController.text) ?? 0;
  double get _totalTrips => double.tryParse(_qtyController.text) ?? 0;
  double get _landSizeAcres => double.tryParse(_landSizeController.text) ?? 0;

  double get _billedQty {
    if (_isTimeBased) return _totalHours;
    if (_isTractorTrolley) return _totalTrips;
    return _quantity;
  }

  String get _measuredUnit {
    if (_isTimeBased) return 'Hour';
    if (_isTractorTrolley) return 'Trip';

    final unit = _selectedEquipment?['unit']?.toString().trim() ?? '';
    return unit.isEmpty ? 'Unit' : unit;
  }

  bool get _isTimeBased =>
      _selectedEquipment?['unit']?.toString().toLowerCase().contains('hour') ??
      true;

  bool get _isTractorTrolley {
    final equipment = _selectedEquipment;
    if (equipment == null) return false;

    final name = equipment['name_en']?.toString().toLowerCase() ?? '';
    final normalizedName = name.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    final hasTrolleySlabs =
        equipment['slabs'] is List && (equipment['slabs'] as List).isNotEmpty;

    return hasTrolleySlabs ||
        (normalizedName.contains('tractor') &&
            normalizedName.contains('trolley'));
  }

  double get _finalAmount {
    if (_isTimeBased) {
      return _totalHours * _ratePerUnit;
    }

    if (_isTractorTrolley) {
      return _totalTrips * _ratePerUnit;
    }

    return _quantity * _ratePerUnit;
  }

  String _formatTime(TimeOfDay? t) {
    if (t == null) return '--:--';
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'operator_select_service_date'.tr();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  String _formatApiDate(DateTime? d) {
    if (d == null) return '';
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '${d.year}-$month-$day';
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      if (isError) {
        _errorMsg = msg;
        _successMsg = null;
      } else {
        _successMsg = msg;
        _errorMsg = null;
      }
    });
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _errorMsg = null;
          _successMsg = null;
        });
      }
    });
  }

  Future<void> _pickServiceDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _serviceDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );

    if (picked != null && mounted) {
      setState(() {
        _serviceDate = picked;
        _showPreview = false;
      });
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? TimeOfDay.now())
          : (_endTime ?? TimeOfDay.now()),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF059669)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      if (isStart) {
        setState(() {
          _startTime = picked;
          _showPreview = false;
        });
      } else {
        setState(() {
          _endTime = picked;
          _showPreview = false;
        });
      }
    }
  }

  bool get _canPreview {
    final baseValid = _phoneController.text.length == 10 &&
        _nameController.text.trim().isNotEmpty &&
        _villageController.text.trim().isNotEmpty &&
        _serviceDate != null &&
        _selectedEquipment != null;

    if (!baseValid) return false;

    if (_isTimeBased) {
      return _startTime != null && _endTime != null && _totalHours > 0;
    } else if (_isTractorTrolley) {
      return _distance > 0 &&
          _totalTrips > 0 &&
          !_isFetchingRate &&
          _ratePerUnit > 0;
    } else {
      return _quantity > 0;
    }
  }

  Future<void> _updateRate() async {
    if (_selectedEquipment == null) return;

    if (_isTractorTrolley) {
      final equipmentId = _selectedEquipment!['id'];
      final distance = _distance;
      final isMember = _isFoundMember;

      if (distance <= 0) {
        if (!mounted) return;
        setState(() {
          _ratePerUnit = 0.0;
          _isFetchingRate = false;
        });
        return;
      }

      setState(() => _isFetchingRate = true);

      try {
        final res = await ApiService.calculateTrolleyPrice(
          equipmentId: equipmentId,
          clientCode: widget.operator.clientCode,
          distance: distance,
          isMember: isMember,
        );

        if (!mounted) return;
        if (_selectedEquipment?['id'] != equipmentId ||
            _distance != distance ||
            _isFoundMember != isMember) {
          return;
        }

        setState(() {
          _ratePerUnit = res['success'] == true
              ? (double.tryParse(res['price']?.toString() ?? '0') ?? 0.0)
              : 0.0;
          _isFetchingRate = false;
        });
      } catch (_) {
        if (!mounted) return;
        if (_selectedEquipment?['id'] != equipmentId ||
            _distance != distance ||
            _isFoundMember != isMember) {
          return;
        }

        setState(() {
          _ratePerUnit = 0.0;
          _isFetchingRate = false;
        });
      }
      return;
    }

    final newRate = double.tryParse((_isFoundMember
                    ? _selectedEquipment!['price_member']
                    : _selectedEquipment!['price_non_member'])
                ?.toString() ??
            '0') ??
        0.0;

    if (!mounted) return;
    setState(() {
      _ratePerUnit = newRate;
      _isFetchingRate = false;
    });
  }

  Future<void> _submit() async {
    if (!_canPreview) {
      _showMsg('operator_fill_required_fields'.tr(), isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await ApiService.completeBookingManual(
        operatorId: widget.operator.operatorId,
        farmerPhone: _phoneController.text.trim(),
        farmerName: _nameController.text.trim(),
        village: _villageController.text.trim(),
        equipmentUsed: _selectedEquipment!['name_en'] ?? 'Equipment',
        equipmentId: _selectedEquipment!['id'],
        startTime: _isTimeBased ? _formatTime(_startTime) : '00:00',
        endTime: _isTimeBased ? _formatTime(_endTime) : '00:00',
        distance: _isTractorTrolley ? _distance : 0,
        serviceDate: _formatApiDate(_serviceDate),
        cropType: _cropController.text.trim().isEmpty
            ? null
            : _cropController.text.trim(),
        landSizeAcres: _landSizeAcres,
        billedQty: _billedQty,
        unitType: _measuredUnit,
        rate: _ratePerUnit,
        finalAmount: _finalAmount,
      );

      if (res['success'] == true) {
        _showMsg('operator_job_logged_success'.tr());
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) Navigator.pop(context);
      } else {
        _showMsg(res['error'] ?? 'operator_log_job_failed'.tr(), isError: true);
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      _showMsg('operator_network_error_try_again'.tr(), isError: true);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _nameController.dispose();
    _villageController.dispose();
    _qtyController.dispose();
    _distanceController.dispose();
    _cropController.dispose();
    _landSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: keyboardH),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_task_rounded,
                      color: Color(0xFF059669), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'operator_log_walk_in_job'.tr(),
                        style: const TextStyle(
                          fontFamily: 'Google Sans',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                      Text(
                        'operator_log_walk_in_subtitle'.tr(),
                        style: const TextStyle(
                          fontFamily: 'Google Sans',
                          fontSize: 12,
                          color: _textSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMsg != null || _successMsg != null) ...[
                    _buildBanner(),
                    const SizedBox(height: 14),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _fieldLabel('operator_phone_number_label'.tr()),
                      if (_isFoundMember)
                        _memberBadge(true)
                      else if (_phoneController.text.length == 10 &&
                          !_isFetchingUser)
                        _memberBadge(false),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _phoneController,
                    hint: 'signup_phone_hint'.tr(),
                    icon: Icons.phone_rounded,
                    type: TextInputType.phone,
                    suffixIcon: _isFetchingUser
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _green)),
                          )
                        : null,
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('operator_farmer_name_label'.tr()),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _nameController,
                    hint: 'signup_name_hint'.tr(),
                    icon: Icons.person_rounded,
                    type: TextInputType.name,
                    onChanged: (_) => setState(() => _showPreview = false),
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('village'.tr()),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _villageController,
                    hint: 'village'.tr(),
                    icon: Icons.location_on_rounded,
                    type: TextInputType.text,
                    onChanged: (_) => setState(() => _showPreview = false),
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('operator_service_date_label'.tr()),
                  const SizedBox(height: 6),
                  _buildDateField(),
                  const SizedBox(height: 16),
                  _fieldLabel('operator_crop_type_label'.tr()),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _cropController,
                    hint: 'operator_crop_type_optional'.tr(),
                    icon: Icons.grass_rounded,
                    type: TextInputType.text,
                    onChanged: (_) => setState(() => _showPreview = false),
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('operator_land_size_acres_label'.tr()),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _landSizeController,
                    hint: 'operator_enter_land_size'.tr(),
                    icon: Icons.square_foot_rounded,
                    type: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() => _showPreview = false),
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('operator_equipment_used_label'.tr()),
                  const SizedBox(height: 6),
                  _buildEquipmentPicker(),
                  const SizedBox(height: 16),
                  if (_selectedEquipment != null) ...[
                    if (_isTimeBased) ...[
                      _fieldLabel('operator_operation_time_label'.tr()),
                      const SizedBox(height: 6),
                      _buildTimePickers(),
                    ] else if (_isTractorTrolley) ...[
                      _fieldLabel('operator_distance_per_trip_label'.tr()),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _distanceController,
                        hint: 'operator_enter_distance_km'.tr(),
                        icon: Icons.add_road_rounded,
                        type: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) {
                          unawaited(_updateRate());
                          setState(() => _showPreview = false);
                        },
                      ),
                      const SizedBox(height: 16),
                      _fieldLabel('operator_total_trips_label'.tr()),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _qtyController,
                        hint: 'operator_enter_total_trips'.tr(),
                        icon: Icons.repeat_rounded,
                        type: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) {
                          setState(() => _showPreview = false);
                        },
                      ),
                    ] else ...[
                      _fieldLabel('operator_quantity_label'.tr(namedArgs: {
                        'unit':
                            '${_selectedEquipment!['unit'] ?? 'operator_units'.tr()}'
                      })),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _qtyController,
                        hint: 'operator_enter_quantity'.tr(),
                        icon: Icons.calculate_rounded,
                        type: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) {
                          unawaited(_updateRate());
                          setState(() => _showPreview = false);
                        },
                      ),
                    ],
                    if ((_isTractorTrolley &&
                            (_distance > 0 || _totalTrips > 0)) ||
                        (!_isTractorTrolley && _finalAmount > 0)) ...[
                      const SizedBox(height: 12),
                      _buildRateRow(),
                    ],
                    const SizedBox(height: 20),
                  ],
                  if (_showPreview && _canPreview) ...[
                    _buildBillPreview(),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: _buildBottomActions(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _memberBadge(bool isMember) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isMember ? const Color(0xFFF0FDF4) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isMember ? const Color(0xFFA7F3D0) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMember ? Icons.verified_rounded : Icons.person_outline_rounded,
            size: 14,
            color: isMember ? const Color(0xFF059669) : const Color(0xFF6B7280),
          ),
          const SizedBox(width: 6),
          Text(
            isMember ? 'member'.tr() : 'non_member'.tr(),
            style: TextStyle(
              fontFamily: 'Google Sans',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color:
                  isMember ? const Color(0xFF047857) : const Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Google Sans',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF9CA3AF),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required TextInputType type,
    List<TextInputFormatter>? formatters,
    Function(String)? onChanged,
    Widget? suffixIcon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border, width: 1.5),
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        inputFormatters: formatters,
        onChanged: onChanged,
        minLines: maxLines > 1 ? maxLines : 1,
        maxLines: maxLines,
        style: const TextStyle(
            fontFamily: 'Google Sans',
            fontSize: 15,
            color: _textPrimary,
            fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              fontFamily: 'Google Sans',
              fontSize: 15,
              color: Color(0xFF9CA3AF)),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(icon, color: _green, size: 20),
          ),
          suffixIcon: suffixIcon,
          prefixIconConstraints: const BoxConstraints(minWidth: 46),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _pickServiceDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, color: _green, size: 20),
            const SizedBox(width: 12),
            Text(
              _formatDate(_serviceDate),
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _serviceDate != null
                    ? _textPrimary
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEquipmentPicker() {
    var tempSelected = _selectedEquipment ??
        (_equipmentList.isNotEmpty ? _equipmentList.first : null);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 300,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'operator_select_equipment'.tr(),
                style: const TextStyle(
                  fontFamily: 'Google Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ),
            Expanded(
              child: _equipmentList.isEmpty
                  ? Center(
                      child: Text(
                        'operator_no_equipment_found'.tr(),
                        style: const TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 16,
                            color: _textSub),
                      ),
                    )
                  : CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: _equipmentList.isEmpty
                            ? 0
                            : (_selectedEquipment != null
                                    ? _equipmentList.indexWhere((e) =>
                                        e['id'] == _selectedEquipment!['id'])
                                    : 0)
                                .clamp(0, _equipmentList.length - 1),
                      ),
                      itemExtent: 45,
                      useMagnifier: true,
                      magnification: 1.1,
                      onSelectedItemChanged: (index) {
                        tempSelected = _equipmentList[index];
                      },
                      children: _equipmentList.map((e) {
                        return Center(
                          child: Text(
                            e['name_en'] ?? 'operator_equipment_fallback'.tr(),
                            style: const TextStyle(
                              fontFamily: 'Google Sans',
                              fontSize: 18,
                              color: _textPrimary, // Explicitly use dark color
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildActionButton(
                  text: 'operator_confirm'.tr(),
                  onTap: () {
                    if (tempSelected != null) {
                      setState(() {
                        _selectedEquipment = tempSelected;
                        _showPreview = false;
                        _qtyController.clear();
                        _distanceController.clear();
                        _startTime = null;
                        _endTime = null;
                        _ratePerUnit = 0.0;
                      });
                      unawaited(_updateRate());
                    }
                    Navigator.pop(context);
                  },
                  color: _green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentPicker() {
    if (_isFetchingEquipments) {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border, width: 1.5),
        ),
        child: const Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: _green))),
      );
    }

    return GestureDetector(
      onTap: _showEquipmentPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.precision_manufacturing_rounded,
                color: _green, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedEquipment?['name_en'] ??
                    'operator_select_equipment'.tr(),
                style: const TextStyle(
                    fontFamily: 'Google Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePickers() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('operator_start_time'.tr(),
                        style: const TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 11,
                            color: _textSub,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _pickTime(true),
                      child: Row(
                        children: [
                          Text(
                            _formatTime(_startTime),
                            style: TextStyle(
                              fontFamily: 'Google Sans',
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: _startTime != null
                                  ? _textPrimary
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.access_time_rounded,
                              size: 18, color: _green),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: const Color(0xFFE5E7EB)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('operator_end_time'.tr(),
                          style: const TextStyle(
                              fontFamily: 'Google Sans',
                              fontSize: 11,
                              color: _textSub,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => _pickTime(false),
                        child: Row(
                          children: [
                            Text(
                              _formatTime(_endTime),
                              style: TextStyle(
                                fontFamily: 'Google Sans',
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: _endTime != null
                                    ? _textPrimary
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.access_time_rounded,
                                size: 18, color: _green),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRateRow() {
    return Row(
      children: [
        const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF9CA3AF)),
        const SizedBox(width: 6),
        Text(
          _isTimeBased
              ? 'operator_rate_row_time'.tr(namedArgs: {
                  'hours': _totalHours.toStringAsFixed(1),
                  'rate': _ratePerUnit.toInt().toString(),
                })
              : _isTractorTrolley
                  ? _isFetchingRate
                      ? 'operator_fetching_price_for_distance'.tr(namedArgs: {
                          'distance': _distance.toStringAsFixed(1),
                        })
                      : 'operator_rate_row_trip'.tr(namedArgs: {
                          'distance': _distance.toStringAsFixed(1),
                          'trips': _totalTrips.toStringAsFixed(0),
                          'rate': _ratePerUnit.toInt().toString(),
                        })
                  : 'operator_rate_row_quantity'.tr(namedArgs: {
                      'qty': _quantity.toStringAsFixed(1),
                      'unit': '${_selectedEquipment?['unit'] ?? ''}',
                      'rate': _ratePerUnit.toInt().toString(),
                      'rateUnit':
                          '${_selectedEquipment?['unit'] ?? 'operator_unit'.tr()}',
                    }),
          style: const TextStyle(
              fontFamily: 'Google Sans',
              fontSize: 13,
              color: _textSub,
              fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            final val = await showDialog<double>(
              context: context,
              builder: (ctx) => _RateDialog(initial: _ratePerUnit),
            );
            if (val != null) {
              setState(() {
                _ratePerUnit = val;
                _showPreview = false;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('operator_edit_rate'.tr(),
                style: const TextStyle(
                    fontFamily: 'Google Sans',
                    fontSize: 12,
                    color: _green,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildBillPreview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('operator_bill_preview'.tr(),
                  style: const TextStyle(
                      fontFamily: 'Google Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          _billRow('operator_farmer'.tr(), _nameController.text.trim()),
          _billRow('village'.tr(), _villageController.text.trim()),
          _billRow('operator_service_date'.tr(), _formatDate(_serviceDate)),
          if (_cropController.text.trim().isNotEmpty)
            _billRow('detail_crop'.tr(), _cropController.text.trim()),
          if (_landSizeAcres > 0)
            _billRow('operator_land_size'.tr(),
                '${_landSizeAcres.toStringAsFixed(2)} ${'acres'.tr()}'),
          _billRow('chc_equipment'.tr(), _selectedEquipment?['name_en'] ?? ''),
          if (_isTimeBased)
            _billRow(
                'operator_duration'.tr(),
                'operator_duration_value'.tr(namedArgs: {
                  'start': _formatTime(_startTime),
                  'end': _formatTime(_endTime),
                  'hours': _totalHours.toStringAsFixed(1),
                }))
          else if (_isTractorTrolley) ...[
            _billRow('operator_distance'.tr(),
                '${_distance.toStringAsFixed(1)} ${'operator_km_per_trip'.tr()}'),
            _billRow('operator_trips'.tr(), _totalTrips.toStringAsFixed(0)),
          ] else
            _billRow('operator_quantity'.tr(),
                '${_quantity.toStringAsFixed(1)} ${_selectedEquipment?['unit'] ?? ''}'),
          _billRow(
            'chc_rate'.tr(),
            _isTractorTrolley
                ? 'operator_rate_trip_value'.tr(namedArgs: {
                    'rate': _ratePerUnit.toInt().toString(),
                    'distance': _distance.toStringAsFixed(1),
                  })
                : 'operator_rate_unit_value'.tr(namedArgs: {
                    'rate': _ratePerUnit.toInt().toString(),
                    'unit':
                        '${_selectedEquipment?['unit'] ?? 'operator_unit'.tr()}',
                  }),
          ),
          Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              height: 1,
              color: Colors.white.withValues(alpha: 0.3)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('operator_total_amount'.tr(),
                  style: const TextStyle(
                      fontFamily: 'Google Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70)),
              Text('₹${_finalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontFamily: 'Google Sans',
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _billRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    fontFamily: 'Google Sans',
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontFamily: 'Google Sans',
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_showPreview)
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: _canPreview
                  ? const Color(0xFF111827)
                  : const Color(0xFF94A3B8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _canPreview
                    ? () => setState(() => _showPreview = true)
                    : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.visibility_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text('operator_preview_bill'.tr(),
                        style: const TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
          )
        else
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: _isLoading ? const Color(0xFF94A3B8) : _green,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isLoading
                  ? []
                  : [
                      BoxShadow(
                        color: _green.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _isLoading ? null : _submit,
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Text('operator_confirm_submit'.tr(),
                                style: const TextStyle(
                                    fontFamily: 'Google Sans',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ],
                        ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr(),
                style: const TextStyle(
                    fontFamily: 'Google Sans',
                    fontSize: 15,
                    color: _textSub,
                    fontWeight: FontWeight.w500)),
          ),
        ),
      ],
    );
  }

  Widget _buildBanner() {
    final isError = _errorMsg != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError ? const Color(0xFFFCA5A5) : const Color(0xFFA7F3D0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 18,
            color: isError ? const Color(0xFFDC2626) : const Color(0xFF059669),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMsg ?? _successMsg ?? '',
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                    isError ? const Color(0xFFDC2626) : const Color(0xFF059669),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback onTap,
    required Color color,
    bool isLoading = false,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isLoading ? const Color(0xFF94A3B8) : color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isLoading
            ? []
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isLoading ? null : onTap,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(
                    text,
                    style: const TextStyle(
                      fontFamily: 'Google Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Small dialog for editing rate per hour
class _RateDialog extends StatefulWidget {
  final double initial;
  const _RateDialog({required this.initial});

  @override
  State<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends State<_RateDialog> {
  late TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial.toInt().toString());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('operator_set_rate_per_hour'.tr(),
          style: const TextStyle(
              fontFamily: 'Google Sans', fontWeight: FontWeight.w700)),
      content: TextField(
        controller: _c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          prefixText: '₹ ',
          suffixText: '/${'operator_hour'.tr()}',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF059669), width: 2),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr(),
              style: const TextStyle(
                  fontFamily: 'Google Sans', color: Color(0xFF6B7280))),
        ),
        TextButton(
          onPressed: () {
            final v = double.tryParse(_c.text);
            if (v != null && v > 0) Navigator.pop(context, v);
          },
          child: Text('operator_set'.tr(),
              style: const TextStyle(
                  fontFamily: 'Google Sans',
                  color: Color(0xFF059669),
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
