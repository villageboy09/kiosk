import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cropsync/models/chc_official.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/services/official_auth_service.dart';
import 'package:cropsync/auth/login_screen.dart';

// ==============================================================================
// FORMATTING & NUMBER UTILITIES (Indian Digit Grouping with Commas)
// ==============================================================================

String _formatNumber(dynamic number, {int decimalPlaces = 0}) {
  if (number == null) {
    return '0';
  }
  double val = 0.0;
  if (number is num) {
    val = number.toDouble();
  } else if (number is String) {
    val = double.tryParse(number) ?? 0.0;
  }
  if (val == 0.0) {
    return '0';
  }

  bool isNegative = val < 0;
  val = val.abs();

  String fixed = val.toStringAsFixed(decimalPlaces);
  List<String> parts = fixed.split('.');
  String integerPart = parts[0];
  String decimalPart = parts.length > 1 && decimalPlaces > 0 ? '.${parts[1]}' : '';

  if (integerPart.length > 3) {
    String lastThree = integerPart.substring(integerPart.length - 3);
    String remaining = integerPart.substring(0, integerPart.length - 3);
    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < remaining.length; i++) {
      if (i > 0 && (remaining.length - i) % 2 == 0) {
        buffer.write(',');
      }
      buffer.write(remaining[i]);
    }
    integerPart = '${buffer.toString()},$lastThree';
  }

  return '${isNegative ? '-' : ''}$integerPart$decimalPart';
}

String _formatCurrency(dynamic amount, {int decimalPlaces = 0}) {
  return '₹${_formatNumber(amount, decimalPlaces: decimalPlaces)}';
}

String _formatAcres(dynamic acres) {
  if (acres == null) {
    return '0 ac';
  }
  double val = 0.0;
  if (acres is num) {
    val = acres.toDouble();
  } else if (acres is String) {
    val = double.tryParse(acres) ?? 0.0;
  }
  final dec = (val.truncateToDouble() == val) ? 0 : 1;
  return '${_formatNumber(val, decimalPlaces: dec)} ac';
}

class ChcOfficialDashboardScreen extends StatefulWidget {
  const ChcOfficialDashboardScreen({super.key});

  @override
  State<ChcOfficialDashboardScreen> createState() => _ChcOfficialDashboardScreenState();
}

class _ChcOfficialDashboardScreenState extends State<ChcOfficialDashboardScreen> with SingleTickerProviderStateMixin {
  ChcOfficial? _official;
  int _currentTabIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;

  // Chart interactivity states
  int _touchedPieIndex = -1;
  int _touchedDemographicsPieIndex = -1;
  bool _showRevenueTrend = true;

  // Active filters
  String _selectedClientCode = 'ALL';
  String _selectedDateRange = 'all_time'; // 'all_time', 'today', '7_days', '30_days'
  String _startDate = '2000-01-01';
  String _endDate = DateTime.now().toIso8601String().split('T')[0];

  // Dashboard Data
  Map<String, dynamic>? _dashboardData;
  List<String> _availableClientCodes = ['ALL'];

  // Bookings Tab Data
  List<Map<String, dynamic>> _bookingsList = [];
  bool _isBookingsLoading = false;
  String _selectedBookingStatus = 'All';
  final TextEditingController _bookingSearchController = TextEditingController();

  // Cancelled Orders Data
  List<Map<String, dynamic>> _cancelledOrders = [];
  bool _isCancelledLoading = false;

  // Fleet & Inventory Data
  int _fleetSubTab = 0; // 0 = Operators, 1 = Machinery
  List<Map<String, dynamic>> _operatorsList = [];
  List<Map<String, dynamic>> _inventoryList = [];
  bool _isFleetLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeOfficial();
  }

  @override
  void dispose() {
    _bookingSearchController.dispose();
    super.dispose();
  }

  Future<void> _initializeOfficial() async {
    final official = await OfficialAuthService.getCurrentOfficial();
    if (official == null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    setState(() {
      _official = official;
      _selectedClientCode = official.currentClientCode.isNotEmpty ? official.currentClientCode : 'ALL';
      _availableClientCodes = official.allowedClientCodes.isNotEmpty ? official.allowedClientCodes : ['ALL'];
    });

    _loadDashboardData();
  }

  void _setDateRange(String rangeKey) {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T')[0];
    String start = '2000-01-01';

    if (rangeKey == 'today') {
      start = todayStr;
    } else if (rangeKey == '7_days') {
      start = now.subtract(const Duration(days: 7)).toIso8601String().split('T')[0];
    } else if (rangeKey == '30_days') {
      start = now.subtract(const Duration(days: 30)).toIso8601String().split('T')[0];
    }

    setState(() {
      _selectedDateRange = rangeKey;
      _startDate = start;
      _endDate = todayStr;
    });

    _loadDashboardData();
    if (_currentTabIndex == 2) {
      _loadBookings();
    }
  }

  Future<void> _switchClientCode(String newCode) async {
    if (_selectedClientCode == newCode) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedClientCode = newCode;
    });
    await OfficialAuthService.switchClientCode(newCode);
    _loadDashboardData();
    if (_currentTabIndex == 2) _loadBookings();
    if (_currentTabIndex == 3) _loadCancelledOrders();
    if (_currentTabIndex == 4) _loadFleetAndInventory();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.getChcOfficialDashboard(
        clientCode: _selectedClientCode,
        region: _official?.region,
        startDate: _startDate,
        endDate: _endDate,
      );

      final List<String> codes = [];
      if (res['available_client_codes'] is List) {
        for (var c in res['available_client_codes']) {
          final s = c.toString().trim();
          if (s.isNotEmpty && !codes.contains(s)) codes.add(s);
        }
      }
      if (!codes.contains('ALL')) codes.insert(0, 'ALL');

      if (mounted) {
        setState(() {
          _dashboardData = res;
          if (codes.isNotEmpty) {
            _availableClientCodes = codes;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadBookings() async {
    setState(() => _isBookingsLoading = true);
    try {
      final list = await ApiService.getChcOfficialBookings(
        clientCode: _selectedClientCode,
        region: _official?.region,
        status: _selectedBookingStatus,
        search: _bookingSearchController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) {
        setState(() {
          _bookingsList = list;
          _isBookingsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isBookingsLoading = false);
    }
  }

  Future<void> _loadCancelledOrders() async {
    setState(() => _isCancelledLoading = true);
    try {
      final list = await ApiService.getChcCancelledOrders(
        clientCode: _selectedClientCode,
        region: _official?.region,
      );
      if (mounted) {
        setState(() {
          _cancelledOrders = list;
          _isCancelledLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isCancelledLoading = false);
    }
  }

  Future<void> _loadFleetAndInventory() async {
    setState(() => _isFleetLoading = true);
    try {
      final ops = await ApiService.getChcOperators(
        clientCode: _selectedClientCode,
        region: _official?.region,
      );
      final inv = await ApiService.getChcInventory(
        clientCode: _selectedClientCode,
        region: _official?.region,
      );
      if (mounted) {
        setState(() {
          _operatorsList = ops;
          _inventoryList = inv;
          _isFleetLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isFleetLoading = false);
    }
  }

  void _onTabChanged(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentTabIndex = index);
    if (index == 1) {
      // Today Tab: already in _dashboardData['today_schedule']
    } else if (index == 2) {
      _loadBookings();
    } else if (index == 3) {
      _loadCancelledOrders();
    } else if (index == 4) {
      _loadFleetAndInventory();
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Sign out of Official Portal (${_official?.email})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await OfficialAuthService.logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _openEquipmentFarmersBottomSheet(String equipmentName, String? imageUrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 46,
                            height: 46,
                            color: const Color(0xFFF1F5F9),
                            child: _buildEquipmentCoverImage(imageUrl, equipmentName),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                equipmentName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _selectedClientCode == 'ALL' ? 'ALL CENTERS' : _selectedClientCode,
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Farmers List',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Farmers List via FutureBuilder
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: ApiService.getChcOfficialBookings(
                        clientCode: _selectedClientCode,
                        region: _official?.region,
                        equipmentType: equipmentName,
                        startDate: _startDate,
                        endDate: _endDate,
                        limit: 100,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: Color(0xFF0284C7)),
                                SizedBox(height: 12),
                                Text(
                                  'Loading farmers list...',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFEF4444)),
                                  const SizedBox(height: 8),
                                  Text(
                                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final bookings = snapshot.data ?? [];
                        if (bookings.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.people_outline_rounded, size: 48, color: Color(0xFFCBD5E1)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No bookings found for $equipmentName',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'No farmers have booked this machinery in the selected center.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: bookings.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final b = bookings[index];
                            final farmerName = b['farmer_name']?.toString() ?? 'Farmer';
                            final phone = b['farmer_phone']?.toString() ?? '';
                            final village = b['farmer_village']?.toString() ?? '';
                            final bookingId = b['booking_id']?.toString() ?? '';
                            final date = b['service_date']?.toString() ?? '';
                            final cost = b['total_cost'] ?? 0;
                            final acres = b['total_acres'] ?? b['land_size_acres'] ?? 0;
                            final crop = b['crop_type']?.toString() ?? '';

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFFE0F2FE),
                                    child: Text(
                                      farmerName.isNotEmpty ? farmerName[0].toUpperCase() : 'F',
                                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0284C7), fontSize: 14),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                farmerName,
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              _formatCurrency(cost),
                                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            if (village.isNotEmpty) ...[
                                              const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF64748B)),
                                              const SizedBox(width: 2),
                                              Text(village, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                              const SizedBox(width: 8),
                                            ],
                                            if (crop.isNotEmpty) ...[
                                              const Icon(Icons.eco_rounded, size: 12, color: Color(0xFF16A34A)),
                                              const SizedBox(width: 2),
                                              Text(crop, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                              const SizedBox(width: 8),
                                            ],
                                            Text(
                                              _formatAcres(acres),
                                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w700),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  '#$bookingId',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                                                ),
                                                if (date.isNotEmpty) ...[
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '• $date',
                                                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFDCFCE7),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'Completed',
                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (phone.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.phone_rounded, color: Color(0xFF16A34A), size: 20),
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Call Farmer',
                                      onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openProfileBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFE0F2FE),
                  child: Text(
                    _official?.email.isNotEmpty == true ? _official!.email[0].toUpperCase() : 'O',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _official?.email ?? 'Official',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ROLE: OFFICIAL OBSERVER',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF2563EB), letterSpacing: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),

            if (_official?.region.isNotEmpty == true) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.location_on_rounded, size: 20, color: Color(0xFF0284C7)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Assigned Region / District', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text(
                            _official!.region,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.hub_rounded, size: 16, color: Color(0xFF0284C7)),
                      const SizedBox(width: 6),
                      Text(
                        'Accessible Centers (${_availableClientCodes.length - 1})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _availableClientCodes.where((c) => c != 'ALL').map((c) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(c, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFEF4444)),
                label: const Text('Sign Out from Dashboard', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 13.5)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: const Color(0xFFFEF2F2),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showLogoutDialog();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
          : _errorMessage != null
              ? _buildErrorView()
              : _buildCurrentTab(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 16,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CHC Operations & Analytics',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
          ),
          if (_official?.region.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _official!.region,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF374151)),
          tooltip: 'Refresh Dashboard',
          onPressed: () {
            _loadDashboardData();
            if (_currentTabIndex == 2) _loadBookings();
            if (_currentTabIndex == 3) _loadCancelledOrders();
            if (_currentTabIndex == 4) _loadFleetAndInventory();
          },
        ),
        InkWell(
          onTap: _openProfileBottomSheet,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFFE0F2FE),
              child: Text(
                _official?.email.isNotEmpty == true ? _official!.email[0].toUpperCase() : 'O',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _availableClientCodes.map((code) {
                final isSelected = code == _selectedClientCode;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(code == 'ALL' ? 'ALL CENTERS' : code),
                    selected: isSelected,
                    onSelected: (_) => _switchClientCode(code),
                    selectedColor: const Color(0xFF0284C7),
                    backgroundColor: const Color(0xFFF1F5F9),
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    side: BorderSide(color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0)),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 54, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadDashboardData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentTabIndex) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildTodayTab();
      case 2:
        return _buildBookingsTab();
      case 3:
        return _buildCancelledTab();
      case 4:
        return _buildFleetTab();
      default:
        return _buildOverviewTab();
    }
  }

  // ==============================================================================
  // TAB 1: OVERVIEW TAB
  // ==============================================================================
  Widget _buildOverviewTab() {
    final kpis = _dashboardData?['kpis'] as Map<String, dynamic>? ?? {};
    final eqBreakdown = (_dashboardData?['equipment_breakdown'] as List?) ?? [];
    final cropStats = (_dashboardData?['crop_stats'] as List?) ?? [];
    final villageStats = (_dashboardData?['village_stats'] as List?) ?? [];
    final farmerCategories = (_dashboardData?['farmer_categories'] as List?) ?? [];
    final liveAssignments = (_dashboardData?['live_assignments'] as List?) ?? [];
    final trendData = (_dashboardData?['trend_data'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: const Color(0xFF0284C7),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date Filter bar
          _buildDateFilterPills(),
          const SizedBox(height: 16),

          // Primary KPI Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.45,
            children: [
              _buildKpiCard(
                title: 'Total Bookings',
                value: _formatNumber(kpis['total_bookings'] ?? 0),
                subtitle: 'Service requests',
                icon: Icons.assignment_turned_in_rounded,
                iconColor: const Color(0xFF2563EB),
                bgTint: const Color(0xFFEFF6FF),
              ),
              _buildKpiCard(
                title: 'Realized Revenue',
                value: _formatCurrency(kpis['revenue_realized'] ?? 0),
                subtitle: 'Completed jobs',
                icon: Icons.currency_rupee_rounded,
                iconColor: const Color(0xFF16A34A),
                bgTint: const Color(0xFFF0FDF4),
              ),
              _buildKpiCard(
                title: 'Total Acres',
                value: _formatAcres(kpis['total_acres'] ?? 0),
                subtitle: 'Land serviced',
                icon: Icons.landscape_rounded,
                iconColor: const Color(0xFFD97706),
                bgTint: const Color(0xFFFEF3C7),
              ),
              _buildKpiCard(
                title: 'Active Farmers',
                value: _formatNumber(kpis['active_farmers'] ?? 0),
                subtitle: 'Registered users',
                icon: Icons.people_alt_rounded,
                iconColor: const Color(0xFF7C3AED),
                bgTint: const Color(0xFFF5F3FF),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Working Now Banner (Live Assignments)
          if (liveAssignments.isNotEmpty) ...[
            _buildSectionHeader('Live Working Operators', count: liveAssignments.length),
            const SizedBox(height: 10),
            SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: liveAssignments.length,
                itemBuilder: (ctx, idx) {
                  final item = liveAssignments[idx];
                  return Container(
                    width: 260,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.engineering_rounded, size: 16, color: Color(0xFFD97706)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item['operator_name']?.toString() ?? 'Operator',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                              child: const Text('ACTIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          '${item['equipment_type'] ?? ''} • ${item['crop_type'] ?? 'Crop'}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Farmer: ${item['farmer_name'] ?? 'N/A'} (${item['farmer_village'] ?? ''})',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Operations & Revenue Trend Chart
          _buildOperationsTrendChart(trendData),
          const SizedBox(height: 20),

          // Booking Status Lifecycle Donut Chart
          _buildBookingStatusDonutChart(kpis),
          const SizedBox(height: 24),

          // Equipment Breakdown (Rich Cards with Actual Images)
          _buildSectionHeader('Equipment Breakdown'),
          const SizedBox(height: 10),
          _buildEquipmentBreakdownCards(eqBreakdown),
          const SizedBox(height: 24),

          // Crop Distribution with Actual Crop Photos
          _buildCropDistributionSection(cropStats),
          const SizedBox(height: 24),

          // Village Performance Breakdown (Graph & Table)
          if (villageStats.isNotEmpty) ...[
            _buildVillagePerformanceSection(villageStats),
            const SizedBox(height: 24),
          ],

          // Farmer Demographics (Land size) Pie Chart
          _buildFarmerDemographicsPieChart(farmerCategories),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ==============================================================================
  // TAB 2: TODAY'S SCHEDULE TAB
  // ==============================================================================
  Widget _buildTodayTab() {
    final kpis = _dashboardData?['kpis'] as Map<String, dynamic>? ?? {};
    final todaySchedule = (_dashboardData?['today_schedule'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: const Color(0xFF0284C7),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Today Metrics Summary Row
          Row(
            children: [
              Expanded(
                child: _buildTodayChip('Today Orders', _formatNumber(kpis['today_count'] ?? 0), Icons.today_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTodayChip('Villages', _formatNumber(kpis['today_village_count'] ?? 0), Icons.location_on_rounded, const Color(0xFFD97706), const Color(0xFFFEF3C7)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTodayChip('Equipment', _formatNumber(kpis['today_equipment_type_count'] ?? 0), Icons.agriculture_rounded, const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _buildSectionHeader("Today's Field Schedule", count: todaySchedule.length),
          const SizedBox(height: 12),

          if (todaySchedule.isEmpty)
            Container(
              padding: const EdgeInsets.all(36),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 48, color: Color(0xFFD1D5DB)),
                  SizedBox(height: 12),
                  Text('No bookings scheduled for today.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF))),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: todaySchedule.length,
              itemBuilder: (ctx, idx) {
                final row = todaySchedule[idx] as Map<String, dynamic>;
                return _buildBookingCard(row);
              },
            ),
        ],
      ),
    );
  }

  // ==============================================================================
  // TAB 3: ALL BOOKINGS TAB
  // ==============================================================================
  Widget _buildBookingsTab() {
    final statuses = ['All', 'Slot Booked', 'Assigned', 'In Progress', 'Completed', 'Pending', 'Cancelled'];

    return Column(
      children: [
        // Search & Filter Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              TextField(
                controller: _bookingSearchController,
                onSubmitted: (_) => _loadBookings(),
                decoration: InputDecoration(
                  hintText: 'Search by Booking #, Farmer, Village...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF6B7280)),
                  suffixIcon: _bookingSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _bookingSearchController.clear();
                            _loadBookings();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: statuses.map((st) {
                    final isSel = _selectedBookingStatus == st;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(st),
                        selected: isSel,
                        onSelected: (_) {
                          setState(() => _selectedBookingStatus = st);
                          _loadBookings();
                        },
                        selectedColor: const Color(0xFF0284C7),
                        backgroundColor: const Color(0xFFF9FAFB),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSel ? Colors.white : const Color(0xFF4B5563),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Bookings List
        Expanded(
          child: _isBookingsLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
              : _bookingsList.isEmpty
                  ? const Center(child: Text('No bookings found matching filters.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)))
                  : RefreshIndicator(
                      onRefresh: _loadBookings,
                      color: const Color(0xFF0284C7),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _bookingsList.length,
                        itemBuilder: (ctx, idx) => _buildBookingCard(_bookingsList[idx]),
                      ),
                    ),
        ),
      ],
    );
  }

  // ==============================================================================
  // TAB 4: CANCELLED ORDERS AUDIT TAB
  // ==============================================================================
  Widget _buildCancelledTab() {
    final kpi = _dashboardData?['operator_cancelled_kpi'] as Map<String, dynamic>? ?? {};

    return RefreshIndicator(
      onRefresh: _loadCancelledOrders,
      color: const Color(0xFF0284C7),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTodayChip('Pending Action', _formatNumber(kpi['pending'] ?? 0), Icons.pending_actions_rounded, const Color(0xFFD97706), const Color(0xFFFEF3C7)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTodayChip('Reassigned', _formatNumber(kpi['reassigned'] ?? 0), Icons.check_circle_rounded, const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTodayChip('Total Audit', _formatNumber(kpi['total'] ?? 0), Icons.history_rounded, const Color(0xFF4B5563), const Color(0xFFF3F4F6)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _buildSectionHeader('Operator Cancelled Orders', count: _cancelledOrders.length),
          const SizedBox(height: 12),

          if (_isCancelledLoading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Color(0xFF0284C7))))
          else if (_cancelledOrders.isEmpty)
            Container(
              padding: const EdgeInsets.all(36),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.thumb_up_alt_rounded, size: 48, color: Color(0xFFD1D5DB)),
                  SizedBox(height: 12),
                  Text('No operator cancellations recorded.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF))),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _cancelledOrders.length,
              itemBuilder: (ctx, idx) {
                final c = _cancelledOrders[idx];
                final isPending = c['reassigned_to_operator'] == null || c['reassigned_to_operator'].toString().isEmpty;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isPending ? const Color(0xFFFDE68A) : const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('#${c['booking_id'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0284C7))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPending ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isPending ? 'Pending Reassignment' : 'Reassigned',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isPending ? const Color(0xFFD97706) : const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${c['equipment_type'] ?? ''} • ${c['farmer_name'] ?? 'Farmer'} (${c['farmer_village'] ?? ''})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      const SizedBox(height: 4),
                      Text('Cancelled By: ${c['cancelled_by_operator'] ?? 'Operator'}', style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                      if (c['reason'] != null && c['reason'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Reason: ${c['reason']}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                        ),
                      if (!isPending)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Reassigned to: ${c['reassigned_to_operator']}', style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==============================================================================
  // TAB 5: FLEET & MACHINERY TAB
  // ==============================================================================
  Widget _buildFleetTab() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.people_alt_rounded, size: 18),
                  label: const Text('Operators'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _fleetSubTab == 0 ? const Color(0xFF0284C7) : const Color(0xFFF3F4F6),
                    foregroundColor: _fleetSubTab == 0 ? Colors.white : const Color(0xFF374151),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _fleetSubTab = 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.precision_manufacturing_rounded, size: 18),
                  label: const Text('Machinery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _fleetSubTab == 1 ? const Color(0xFF0284C7) : const Color(0xFFF3F4F6),
                    foregroundColor: _fleetSubTab == 1 ? Colors.white : const Color(0xFF374151),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _fleetSubTab = 1),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isFleetLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
              : _fleetSubTab == 0
                  ? _buildOperatorsList()
                  : _buildMachineryList(),
        ),
      ],
    );
  }

  Widget _buildOperatorsList() {
    if (_operatorsList.isEmpty) {
      return const Center(child: Text('No active operators registered.', style: TextStyle(color: Color(0xFF9CA3AF))));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _operatorsList.length,
      itemBuilder: (ctx, idx) {
        final op = _operatorsList[idx];
        final isBusy = op['availability'] == 'Busy';
        final phone = op['phone_number']?.toString() ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: isBusy ? const Color(0xFFFEF3C7) : const Color(0xFFF0FDF4),
                child: Text(
                  op['name']?.toString().isNotEmpty == true ? op['name'][0].toUpperCase() : 'O',
                  style: TextStyle(fontWeight: FontWeight.w800, color: isBusy ? const Color(0xFFD97706) : const Color(0xFF16A34A)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(op['name']?.toString() ?? 'Operator', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isBusy ? const Color(0xFFFEF3C7) : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isBusy ? 'BUSY' : 'AVAILABLE',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isBusy ? const Color(0xFFD97706) : const Color(0xFF16A34A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Base: ${op['base_village'] ?? 'N/A'} • Jobs: ${_formatNumber(op['jobs_completed'] ?? 0)}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    if (op['skills'] != null && op['skills'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Skills: ${op['skills']}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF0284C7), fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
              if (phone.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.phone_rounded, color: Color(0xFF16A34A), size: 20),
                  onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMachineryList() {
    if (_inventoryList.isEmpty) {
      return const Center(child: Text('No machinery items registered.', style: TextStyle(color: Color(0xFF9CA3AF))));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.65,
      ),
      itemCount: _inventoryList.length,
      itemBuilder: (ctx, idx) {
        return _buildEquipmentGridCard(_inventoryList[idx]);
      },
    );
  }

  Widget _buildEquipmentGridCard(Map<String, dynamic> item) {
    final nameEn = item['name_en']?.toString() ?? item['name']?.toString() ?? 'Machinery';
    final nameTe = item['name_te']?.toString() ?? '';
    final imageUrl = item['image']?.toString();
    final unit = item['unit']?.toString() ?? 'Acre';
    final priceMember = item['price_member'] ?? item['base_price_member'] ?? 0;
    final quantity = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
    final status = item['status']?.toString() ?? 'Active';
    final isActive = status.toLowerCase() == 'active';
    final capacity = item['capacity_per_hour'] ?? item['capacity'] ?? '1.0';
    final totalBookings = item['total_bookings'] ?? 0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _openEquipmentFarmersBottomSheet(nameEn, imageUrl),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Equipment Image Covered Fully
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                    child: SizedBox(
                      height: 125,
                      width: double.infinity,
                      child: _buildEquipmentCoverImage(imageUrl, nameEn),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isActive ? 'ACTIVE' : 'INACTIVE',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$quantity units',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              // Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nameEn,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      if (nameTe.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            nameTe,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                          ),
                        ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.speed_rounded, size: 12, color: Color(0xFF0284C7)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '$capacity $unit/hr',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                          ),
                          Text(
                            'Jobs: ${_formatNumber(totalBookings)}',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFDCFCE7)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Member Rate',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                            ),
                            Text(
                              '${_formatCurrency(priceMember)}/$unit',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                            ),
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
    );
  }

  Widget _buildEquipmentCoverImage(String? imageUrl, String name) {
    final fallbackAsset = _getFallbackEquipmentAsset(name);
    final validUrl = imageUrl != null && (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));

    if (validUrl) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Image.asset(
          fallbackAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFF1F5F9),
            child: const Center(child: Icon(Icons.agriculture_rounded, size: 36, color: Color(0xFF94A3B8))),
          ),
        ),
      );
    }
    return Image.asset(
      fallbackAsset,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFFF1F5F9),
        child: const Center(child: Icon(Icons.agriculture_rounded, size: 36, color: Color(0xFF94A3B8))),
      ),
    );
  }

  // ==============================================================================
  // EQUIPMENT IMAGES & MODERN CARDS
  // ==============================================================================

  String _getFallbackEquipmentAsset(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('drone')) return 'assets/chc_equipments/agri_drone.webp';
    if (lower.contains('harvester') || lower.contains('harvestor')) return 'assets/chc_equipments/combined_harvester.webp';
    if (lower.contains('baler')) return 'assets/chc_equipments/balers.webp';
    if (lower.contains('spray') || lower.contains('boomer')) return 'assets/chc_equipments/boom_sprayer.webp';
    if (lower.contains('shredder') || lower.contains('shredor')) return 'assets/chc_equipments/shredder.webp';
    if (lower.contains('trolley')) return 'assets/chc_equipments/tractor_trolley.webp';
    if (lower.contains('dryer')) return 'assets/chc_equipments/mobile_grain_dryer.webp';
    if (lower.contains('fertilizer') || lower.contains('drill') || lower.contains('seeder')) {
      if (lower.contains('manual')) return 'assets/chc_equipments/manual_seeder.png';
      return 'assets/chc_equipments/seed_cum_fertilizer_drill.webp';
    }
    return 'assets/chc_equipments/tractor.webp';
  }

  Widget _buildEquipmentImage(
    String? imageUrl,
    String name, {
    double height = 165,
    double width = double.infinity,
    BoxFit fit = BoxFit.contain,
    EdgeInsetsGeometry? padding,
  }) {
    final fallbackAsset = _getFallbackEquipmentAsset(name);
    final validUrl = imageUrl != null && (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: Container(
        height: height,
        width: width,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: const Color(0xFFF8FAFC),
        child: validUrl
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                height: height,
                width: width,
                fit: fit,
                placeholder: (context, url) => Container(
                  color: const Color(0xFFF1F5F9),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Image.asset(
                  fallbackAsset,
                  height: height,
                  width: width,
                  fit: fit,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.agriculture_rounded, size: 48, color: Color(0xFF94A3B8)),
                  ),
                ),
              )
            : Image.asset(
                fallbackAsset,
                height: height,
                width: width,
                fit: fit,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.agriculture_rounded, size: 48, color: Color(0xFF94A3B8)),
                ),
              ),
      ),
      );
  }

  // ==============================================================================
  // INTERACTIVE GRAPHS & CHARTS
  // ==============================================================================

  Widget _buildOperationsTrendChart(List<dynamic> trendData) {
    if (trendData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text('No trend activity in selected range.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        ),
      );
    }

    List<FlSpot> spots = [];
    double maxY = 0;
    for (int i = 0; i < trendData.length; i++) {
      final item = trendData[i];
      final double val = _showRevenueTrend
          ? (double.tryParse(item['daily_revenue']?.toString() ?? '0') ?? 0.0)
          : (double.tryParse(item['bookings_count']?.toString() ?? '0') ?? 0.0);
      if (val > maxY) maxY = val;
      spots.add(FlSpot(i.toDouble(), val));
    }
    if (maxY == 0) maxY = 10;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _showRevenueTrend ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _showRevenueTrend ? Icons.trending_up_rounded : Icons.calendar_month_rounded,
                      size: 16,
                      color: _showRevenueTrend ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _showRevenueTrend ? 'Revenue Trajectory' : 'Orders Trajectory',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _showRevenueTrend = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _showRevenueTrend ? const Color(0xFF0F172A) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '₹ Revenue',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _showRevenueTrend ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _showRevenueTrend = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: !_showRevenueTrend ? const Color(0xFF0F172A) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Orders',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: !_showRevenueTrend ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF0F172A),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.toInt();
                        final dateStr = (idx >= 0 && idx < trendData.length)
                            ? (trendData[idx]['service_date']?.toString() ?? '')
                            : '';
                        return LineTooltipItem(
                          '$dateStr\n${_showRevenueTrend ? _formatCurrency(spot.y) : '${_formatNumber(spot.y)} orders'}',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF1F5F9), strokeWidth: 1),
                ),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (spots.length - 1).toDouble() > 0 ? (spots.length - 1).toDouble() : 1,
                minY: 0,
                maxY: maxY * 1.15,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: _showRevenueTrend ? const Color(0xFF16A34A) : const Color(0xFF0284C7),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          (_showRevenueTrend ? const Color(0xFF16A34A) : const Color(0xFF0284C7)).withValues(alpha: 0.22),
                          (_showRevenueTrend ? const Color(0xFF16A34A) : const Color(0xFF0284C7)).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingStatusDonutChart(Map<String, dynamic> kpis) {
    final total = int.tryParse(kpis['total_bookings']?.toString() ?? '0') ?? 0;
    if (total == 0) return const SizedBox.shrink();

    final List<Map<String, dynamic>> slices = [
      {'label': 'Completed', 'count': total, 'color': const Color(0xFF16A34A)},
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.pie_chart_rounded, size: 16, color: Color(0xFF0F172A)),
              ),
              const SizedBox(width: 8),
              const Text(
                'Booking Status Lifecycle',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                _touchedPieIndex = -1;
                                return;
                              }
                              _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        sectionsSpace: 3,
                        centerSpaceRadius: 38,
                        sections: slices.asMap().entries.map((entry) {
                          final i = entry.key;
                          final s = entry.value;
                          final isTouched = i == _touchedPieIndex;
                          final count = s['count'] as int;
                          final double radius = isTouched ? 28 : 22;
                          return PieChartSectionData(
                            color: s['color'] as Color,
                            value: count.toDouble(),
                            title: '',
                            radius: radius,
                          );
                        }).toList(),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatNumber(total),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                        const Text('Orders', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: slices.map((s) {
                    final count = s['count'] as int;
                    final pct = total > 0 ? ((count / total) * 100).toStringAsFixed(0) : '0';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: s['color'] as Color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s['label'] as String,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                          ),
                          Text(
                            '${_formatNumber(count)} ($pct%)',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerDemographicsPieChart(List<dynamic> farmerCategories) {
    if (farmerCategories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text('No demographic data in selected range.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        ),
      );
    }

    int totalRequests = 0;
    for (final fc in farmerCategories) {
      totalRequests += int.tryParse(fc['total_bookings']?.toString() ?? '0') ?? 0;
    }
    if (totalRequests == 0) totalRequests = 1;

    final colorPalette = [
      const Color(0xFF10B981),
      const Color(0xFF0284C7),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
    ];

    final slices = <Map<String, dynamic>>[];
    for (int i = 0; i < farmerCategories.length; i++) {
      final item = farmerCategories[i];
      final catName = item['category']?.toString() ?? 'Landholding';
      final count = int.tryParse(item['total_bookings']?.toString() ?? '0') ?? 0;
      final color = colorPalette[i % colorPalette.length];
      slices.add({
        'label': catName,
        'count': count,
        'color': color,
      });
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.landscape_rounded, size: 16, color: Color(0xFF16A34A)),
              ),
              const SizedBox(width: 8),
              const Text(
                'Farmer Landholding Demographics',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                _touchedDemographicsPieIndex = -1;
                                return;
                              }
                              _touchedDemographicsPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        sectionsSpace: 3,
                        centerSpaceRadius: 38,
                        sections: slices.asMap().entries.map((entry) {
                          final i = entry.key;
                          final s = entry.value;
                          final isTouched = i == _touchedDemographicsPieIndex;
                          final count = s['count'] as int;
                          final double radius = isTouched ? 28 : 22;
                          return PieChartSectionData(
                            color: s['color'] as Color,
                            value: count.toDouble(),
                            title: '',
                            radius: radius,
                          );
                        }).toList(),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatNumber(totalRequests),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                        const Text('Farmers', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: slices.map((s) {
                    final count = s['count'] as int;
                    final pct = totalRequests > 0 ? ((count / totalRequests) * 100).toStringAsFixed(0) : '0';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: s['color'] as Color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s['label'] as String,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${_formatNumber(count)} ($pct%)',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getCropImageUrl(String? rawUrl, String crop) {
    if (rawUrl != null && rawUrl.startsWith('http')) return rawUrl;
    final lower = crop.toLowerCase();
    if (lower.contains('cotton')) {
      return 'https://images.unsplash.com/photo-1594897030560-6921b72e59df?w=300&auto=format&fit=crop&q=80';
    } else if (lower.contains('paddy') || lower.contains('rice')) {
      return 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=300&auto=format&fit=crop&q=80';
    } else if (lower.contains('maize') || lower.contains('corn')) {
      return 'https://images.unsplash.com/photo-1551754655-cd27e38d2076?w=300&auto=format&fit=crop&q=80';
    } else if (lower.contains('chilli') || lower.contains('chili')) {
      return 'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=300&auto=format&fit=crop&q=80';
    } else if (lower.contains('soybean') || lower.contains('soya')) {
      return 'https://images.unsplash.com/photo-1599420186946-7b6fb4e297f0?w=300&auto=format&fit=crop&q=80';
    } else if (lower.contains('groundnut') || lower.contains('peanut')) {
      return 'https://images.unsplash.com/photo-1567894340315-735d7c361db0?w=300&auto=format&fit=crop&q=80';
    } else if (lower.contains('sugarcane')) {
      return 'https://images.unsplash.com/photo-1627920769842-6887c6df05ca?w=300&auto=format&fit=crop&q=80';
    } else if (lower.contains('wheat')) {
      return 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=300&auto=format&fit=crop&q=80';
    } else if (lower.contains('turmeric')) {
      return 'https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=300&auto=format&fit=crop&q=80';
    } else if (lower.contains('pulses') || lower.contains('gram') || lower.contains('dal')) {
      return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=300&auto=format&fit=crop&q=80';
    }
    return 'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?w=300&auto=format&fit=crop&q=80';
  }

  Widget _buildCropDistributionSection(List<dynamic> cropStats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Bookings by Crop', count: cropStats.length),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: cropStats.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No crop booking data in selected range.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.3,
                  ),
                  itemCount: cropStats.length,
                  itemBuilder: (ctx, idx) {
                    final cs = cropStats[idx];
                    final crop = cs['crop']?.toString() ?? 'Crop';
                    final count = cs['total_bookings'] ?? 0;
                    final rawImg = cs['image_url']?.toString();
                    final cropImgUrl = _getCropImageUrl(rawImg, crop);

                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: CachedNetworkImage(
                                imageUrl: cropImgUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: const Color(0xFFE2E8F0)),
                                errorWidget: (_, __, ___) => Container(
                                  color: const Color(0xFFDCFCE7),
                                  child: const Icon(Icons.eco_rounded, color: Color(0xFF16A34A), size: 22),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  crop,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$count orders',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildVillagePerformanceSection(List<dynamic> villageStats) {
    if (villageStats.isEmpty) return const SizedBox.shrink();

    int maxBookings = 1;
    for (final v in villageStats) {
      final bCount = int.tryParse(v['bookings_count']?.toString() ?? '0') ?? 0;
      if (bCount > maxBookings) maxBookings = bCount;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.location_city_rounded, size: 16, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Village Operations & Activity',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${villageStats.length} villages',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Order Volume by Village',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 10),
          ...villageStats.take(6).map((v) {
            final name = v['village']?.toString() ?? 'Village';
            final count = int.tryParse(v['bookings_count']?.toString() ?? '0') ?? 0;
            final double ratio = maxBookings > 0 ? (count / maxBookings).clamp(0.05, 1.0) : 0.05;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        '$count orders',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 7,
                      child: LinearProgressIndicator(
                        value: ratio,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          const Text(
            'Village Data Table',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.2),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(1.2),
                  3: FlexColumnWidth(1.8),
                },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                    children: [
                      _buildTableHeaderCell('Village'),
                      _buildTableHeaderCell('Orders', align: TextAlign.center),
                      _buildTableHeaderCell('Acres', align: TextAlign.center),
                      _buildTableHeaderCell('Revenue', align: TextAlign.end),
                    ],
                  ),
                  ...villageStats.map((v) {
                    final vName = v['village']?.toString() ?? '-';
                    final vOrders = _formatNumber(v['bookings_count'] ?? 0);
                    final vAcres = (double.tryParse(v['total_acres']?.toString() ?? '0') ?? 0.0).toStringAsFixed(1);
                    final vRev = _formatCurrency(v['village_revenue'] ?? 0);

                    return TableRow(
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Text(
                            vName,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: Text(
                            vOrders,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: Text(
                            vAcres,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Text(
                            vRev,
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderCell(String text, {TextAlign align = TextAlign.start}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
      ),
    );
  }

  Widget _buildEquipmentBreakdownCards(List<dynamic> eqBreakdown) {
    if (eqBreakdown.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text('No equipment booking data in range.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        ),
      );
    }

    return Column(
      children: eqBreakdown.map((eq) {
        final name = eq['equipment_type']?.toString() ?? 'Machinery';
        final count = int.tryParse(eq['total_bookings']?.toString() ?? '0') ?? 0;
        final rev = eq['total_revenue'] ?? 0;
        final acres = eq['total_acres'] ?? 0;
        final imageUrl = eq['image']?.toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: () => _openEquipmentFarmersBottomSheet(name, imageUrl),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(17)),
                      child: SizedBox(
                        width: 95,
                        height: 90,
                        child: _buildEquipmentImage(imageUrl, name, height: 90, width: 95, fit: BoxFit.contain, padding: const EdgeInsets.all(8)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${_formatNumber(count)} orders',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatAcres(acres),
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatCurrency(rev),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ==============================================================================
  // HELPER WIDGETS
  // ==============================================================================

  Widget _buildDateFilterPills() {
    final options = [
      {'key': 'all_time', 'label': 'All Time'},
      {'key': 'today', 'label': 'Today'},
      {'key': '7_days', 'label': 'Last 7 Days'},
      {'key': '30_days', 'label': 'Last 30 Days'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((opt) {
          final isSelected = _selectedDateRange == opt['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => _setDateRange(opt['key']!),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF111827) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? const Color(0xFF111827) : const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  opt['label']!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF4B5563),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgTint,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bgTint, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTodayChip(String label, String value, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)), maxLines: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {int? count}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
        if (count != null)
          Text('$count total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0284C7))),
      ],
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> row) {
    final bId = row['booking_id']?.toString() ?? '';
    final farmerName = row['farmer_name']?.toString() ?? 'Farmer';
    final village = row['farmer_village']?.toString() ?? '';
    final eq = row['equipment_type']?.toString() ?? 'Equipment';
    final date = row['service_date']?.toString() ?? '';
    final cost = _formatCurrency(row['total_cost'] ?? 0);
    final opName = row['op_name']?.toString();
    final status = row['booking_status']?.toString() ?? 'Pending';

    Color statusBg = const Color(0xFFF3F4F6);
    Color statusColor = const Color(0xFF4B5563);
    if (status == 'Completed') {
      statusBg = const Color(0xFFDCFCE7);
      statusColor = const Color(0xFF16A34A);
    } else if (status == 'Cancelled') {
      statusBg = const Color(0xFFFEE2E2);
      statusColor = const Color(0xFFEF4444);
    } else if (status == 'In Progress' || status == 'Slot Booked') {
      statusBg = const Color(0xFFE0F2FE);
      statusColor = const Color(0xFF0284C7);
    }

    return InkWell(
      onTap: () => _openBookingDetails(bId),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('#$bId', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0284C7))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                  child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFF3F4F6),
                  child: Text(farmerName.isNotEmpty ? farmerName[0].toUpperCase() : 'F', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF374151), fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(farmerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      Text(village.isNotEmpty ? village : 'Village not specified', style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
                Text(cost, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
              ],
            ),
            const Divider(height: 16, color: Color(0xFFF3F4F6)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.precision_manufacturing_rounded, size: 14, color: Color(0xFF6B7280)),
                    const SizedBox(width: 4),
                    Text(eq, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  ],
                ),
                Text(date, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
                if (opName != null && opName.isNotEmpty)
                  Text('Op: $opName', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0284C7))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openBookingDetails(String bookingId) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BookingDetailsModal(bookingId: bookingId),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: _onTabChanged,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF0284C7),
        unselectedItemColor: const Color(0xFF9CA3AF),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10.5),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Overview'),
          BottomNavigationBarItem(icon: Icon(Icons.today_rounded), label: 'Today'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.cancel_schedule_send_rounded), label: 'Cancelled'),
          BottomNavigationBarItem(icon: Icon(Icons.agriculture_rounded), label: 'Fleet'),
        ],
      ),
    );
  }
}

// ==============================================================================
// MODAL: TASK / BOOKING DETAILS MODAL
// ==============================================================================
class _BookingDetailsModal extends StatefulWidget {
  final String bookingId;
  const _BookingDetailsModal({required this.bookingId});

  @override
  State<_BookingDetailsModal> createState() => _BookingDetailsModalState();
}

class _BookingDetailsModalState extends State<_BookingDetailsModal> {
  bool _loading = true;
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final res = await ApiService.getChcBookingDetails(widget.bookingId);
      if (mounted) {
        setState(() {
          _data = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Booking #${widget.bookingId}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444))))
                    : _buildDetailsContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsContent() {
    final d = _data!;
    final farmerPhone = d['farmer_phone']?.toString() ?? '';
    final opPhone = d['op_phone']?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Status & Equipment Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d['equipment_type']?.toString() ?? 'Equipment', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text('Service Date: ${d['service_date'] ?? ''}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
              Text(_formatCurrency(d['total_cost'] ?? 0), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Farmer Contact Info
        _buildInfoCard(
          title: 'Farmer Details',
          name: d['farmer_name']?.toString() ?? 'N/A',
          subtitle: 'Village: ${d['farmer_village'] ?? 'N/A'}',
          phone: farmerPhone,
          icon: Icons.person_rounded,
          iconColor: const Color(0xFF2563EB),
        ),
        const SizedBox(height: 12),

        // Operator Info
        _buildInfoCard(
          title: 'Assigned Operator',
          name: d['op_name']?.toString() ?? 'Unassigned',
          subtitle: 'Base: ${d['op_village'] ?? 'N/A'}',
          phone: opPhone,
          icon: Icons.engineering_rounded,
          iconColor: const Color(0xFFD97706),
        ),
        const SizedBox(height: 16),

        // Execution Timings & Meter Readings
        if (d['work_start_time'] != null || d['transit_start_time'] != null || d['start_reading'] != null) ...[
          const Text('Field Operations Timeline', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                if (d['transit_start_time'] != null)
                  _buildTimelineRow('Transit Started', d['transit_start_time'].toString()),
                if (d['work_start_time'] != null)
                  _buildTimelineRow('Work Commenced', d['work_start_time'].toString()),
                if (d['work_end_time'] != null)
                  _buildTimelineRow('Work Completed', d['work_end_time'].toString()),
                if (d['start_reading'] != null)
                  _buildTimelineRow('Meter Readings', '${d['start_reading']} → ${d['end_reading'] ?? 'Running'}'),
                if (d['breakdown_reason'] != null && d['breakdown_reason'].toString().isNotEmpty)
                  _buildTimelineRow('Breakdown Note', d['breakdown_reason'].toString(), isAlert: true),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String name,
    required String subtitle,
    required String phone,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: iconColor.withValues(alpha: 0.12),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.4)),
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          if (phone.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.phone_rounded, color: Color(0xFF16A34A)),
              onPressed: () => launchUrl(Uri.parse('tel:$phone')),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(String label, String value, {bool isAlert = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isAlert ? const Color(0xFFEF4444) : const Color(0xFF6B7280), fontWeight: isAlert ? FontWeight.w700 : FontWeight.w500)),
          Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isAlert ? const Color(0xFFEF4444) : const Color(0xFF111827))),
        ],
      ),
    );
  }
}
