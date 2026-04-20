import 'package:flutter/material.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shimmer/shimmer.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

import 'package:cropsync/models/chc_operator.dart';
import 'package:cropsync/services/operator_auth_service.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:cropsync/screens/operator/manual_order_sheet.dart';
import 'package:cropsync/screens/operator/operator_history_screen.dart';
import 'package:cropsync/screens/operator/operator_profile_screen.dart';
import 'package:cropsync/auth/signup_screen.dart';

class OperatorDashboard extends StatefulWidget {
  const OperatorDashboard({super.key});

  @override
  State<OperatorDashboard> createState() => _OperatorDashboardState();
}

class _OperatorDashboardState extends State<OperatorDashboard> {
  int _currentTab = 0;
  ChcOperator? _operator;
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;

  static const Color _accent = Color(0xFF111827);
  static const Color _bgLight = Color(0xFFFAFAFA);

  bool _isClosedStatus(dynamic value) {
    final status = value?.toString().trim().toLowerCase() ?? '';
    return status == 'completed' || status == 'cancelled';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _operator = await OperatorAuthService.getCurrentOperator();
    if (_operator != null) {
      _bookings = await ApiService.getOperatorBookings(
        _operator!.operatorId,
        assignmentStatuses: const ['Assigned', 'In Progress'],
      );
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFB91C1C) : const Color(0xFF065F46),
      ),
    );
  }

  Future<void> _updateAssignmentStatus(
      Map<String, dynamic> booking, String status) async {
    final bookingId = booking['booking_id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    final res = await ApiService.updateOperatorBookingStatus(
      bookingId: bookingId,
      assignmentStatus: status,
    );

    if (res['success'] == true) {
      _showSnack('Assignment status updated to $status');
      await _loadData();
    } else {
      _showSnack(res['error']?.toString() ?? 'Failed to update status',
          isError: true);
    }
  }

  Future<void> _updateBookingStatus(
      Map<String, dynamic> booking, String status) async {
    final bookingId = booking['booking_id']?.toString() ?? '';
    if (bookingId.isEmpty) return;

    String? rescheduledDate;
    String? assignmentStatus;

    if (status == 'Rescheduled') {
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (picked == null) return;
      rescheduledDate =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }

    if (status == 'Completed') {
      assignmentStatus = 'Completed';
    }

    final res = await ApiService.updateOperatorBookingStatus(
      bookingId: bookingId,
      bookingStatus: status,
      assignmentStatus: assignmentStatus,
      rescheduledDate: rescheduledDate,
    );

    if (res['success'] == true) {
      _showSnack('Booking status updated to $status');
      await _loadData();
    } else {
      _showSnack(res['error']?.toString() ?? 'Failed to update status',
          isError: true);
    }
  }

  void _showManualOrderSheet([Map<String, dynamic>? prefillBooking]) {
    if (_operator == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManualOrderSheet(
        operator: _operator!,
        prefillBooking: prefillBooking,
      ),
    ).then((_) => _loadData());
  }

  Future<void> _logout() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
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
              const SizedBox(height: 24),
              const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 40),
              const SizedBox(height: 16),
              Text('operator_sign_out'.tr(),
                  style: AppTheme.getTextStyle(context, fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF111827))),
              const SizedBox(height: 8),
              Text('operator_sign_out_confirm'.tr(),
                  style: AppTheme.getTextStyle(context, fontSize: 14, color: const Color(0xFF6B7280))),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFFF1F5F9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text('cancel'.tr(),
                            style: AppTheme.getTextStyle(context, fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFFFEF2F2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text('operator_sign_out'.tr(),
                            style: AppTheme.getTextStyle(context, fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626))),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) {
      await OperatorAuthService.logout();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SignupScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildHomeTab(),
      OperatorHistoryScreen(operator: _operator),
      OperatorProfileScreen(operator: _operator, onLogout: _logout),
    ];

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: _buildAppBar(),
      body: tabs[_currentTab],
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _currentTab == 0 ? _buildFab() : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final op = _operator;
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9), // Light slate instead of green gradient
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                image: op?.profileImage != null && op!.profileImage!.isNotEmpty
                    ? DecorationImage(
                        image: op.profileImage!.startsWith('http')
                            ? NetworkImage(op.profileImage!)
                            : NetworkImage('https://kiosk.cropsync.in/${op.profileImage!}'),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: op?.profileImage == null || op!.profileImage!.isEmpty
                  ? Text(
                      op?.initial ?? 'O',
                      style: AppTheme.getTextStyle(context, 
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            if (op != null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      op.name,
                      style: AppTheme.getTextStyle(context, 
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      'operator_zone'.tr(namedArgs: {'zone': op.zoneDisplay}),
                      style: AppTheme.getTextStyle(context, 
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: Text('operator_dashboard_title'.tr(),
                    style: AppTheme.getTextStyle(context, 
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: Color(0xFFEF4444), size: 20),
            ),
            onPressed: _logout,
          ),
        ),
      ],
    );
  }

  Widget _buildHomeTab() {
    if (_isLoading) {
      return Shimmer.fromColors(
        baseColor: const Color(0xFFF1F5F9),
        highlightColor: Colors.white,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: 4,
          itemBuilder: (_, __) => Container(
            height: 140,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      );
    }

    // Active bookings = any booking that is not closed (Completed/Cancelled)
    final active = _bookings
        .where((b) =>
            !_isClosedStatus(b['booking_status']) &&
            !_isClosedStatus(b['assignment_status']))
        .toList();

    return RefreshIndicator(
      color: _accent,
      onRefresh: _loadData,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'operator_active_tasks'.tr(),
                style: AppTheme.getTextStyle(context, 
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (active.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _buildBookingCard(active[i]),
                  childCount: active.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                color: _accent, size: 44),
          ),
          const SizedBox(height: 20),
          Text(
            'operator_all_caught_up'.tr(),
            style: AppTheme.getTextStyle(context, 
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'operator_no_pending_jobs'.tr(),
            textAlign: TextAlign.center,
            style: AppTheme.getTextStyle(context, 
              fontSize: 14,
              color: const Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> b) {
    final status = b['booking_status'] ?? 'Confirmed';
    Color statusColor;
    Color statusBg;
    switch (status) {
      case 'In Progress':
        statusColor = const Color(0xFF0F172A);
        statusBg = const Color(0xFFF1F5F9);
        break;
      case 'Confirmed':
        statusColor = const Color(0xFF111827);
        statusBg = const Color(0xFFF3F4F6);
        break;
      default:
        statusColor = const Color(0xFF6B7280);
        statusBg = const Color(0xFFF9FAFB);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.agriculture_rounded,
                      color: _accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b['equipment_type'] ??
                            'operator_equipment_fallback'.tr(),
                        style: AppTheme.getTextStyle(context, 
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      Text(
                        'operator_booking_number'
                            .tr(namedArgs: {'id': '${b['booking_id'] ?? ''}'}),
                        style: AppTheme.getTextStyle(context, 
                          fontSize: 12,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
                if (b['assignment_status'] == 'In Progress')
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF334155),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Active',
                          style: AppTheme.getTextStyle(context, 
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: AppTheme.getTextStyle(context, 
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _infoChip(
                    Icons.person_rounded,
                    b['farmer_name']?.toString().isNotEmpty == true
                        ? b['farmer_name'].toString()
                        : '—',
                  ),
                ),
                Expanded(
                  child: _infoChip(
                    Icons.phone_rounded,
                    b['farmer_phone']?.toString().isNotEmpty == true
                        ? b['farmer_phone'].toString()
                        : '—',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _infoChip(
                    Icons.location_on_rounded,
                    b['farmer_village']?.toString().isNotEmpty == true
                        ? b['farmer_village'].toString()
                        : 'not_set'.tr(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _infoChip(Icons.calendar_today_rounded,
                    b['service_date']?.toString() ?? '—'),
                const SizedBox(width: 12),
                _infoChip(
                    Icons.grass_rounded,
                    b['crop_type']?.toString().isNotEmpty == true
                        ? b['crop_type'].toString()
                        : 'not_set'.tr()),
                const Spacer(),
                Text(
                  '₹${b['total_cost'] ?? '—'}',
                  style: AppTheme.getTextStyle(context, 
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                            ),
                            child: SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 12),
                                  Container(
                                    height: 5,
                                    width: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE5E7EB),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Update Action',
                                        style: AppTheme.getTextStyle(context,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF111827),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildBottomSheetAction(
                                    context: ctx,
                                    icon: Icons.check_circle_rounded,
                                    label: 'Complete Booking',
                                    color: const Color(0xFF111827),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _showManualOrderSheet(b);
                                    },
                                  ),
                                  _buildBottomSheetAction(
                                    context: ctx,
                                    icon: Icons.event_repeat_rounded,
                                    label: 'Reschedule Booking',
                                    color: const Color(0xFF475569),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _updateBookingStatus(b, 'Rescheduled');
                                    },
                                  ),
                                  _buildBottomSheetAction(
                                    context: ctx,
                                    icon: Icons.cancel_rounded,
                                    label: 'Cancel Booking',
                                    color: const Color(0xFF94A3B8),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _updateBookingStatus(b, 'Cancelled');
                                    },
                                    isLast: true,
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Update Booking Status',
                              style: AppTheme.getTextStyle(context, 
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF374151),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                size: 20, color: Color(0xFF6B7280)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                            ),
                            child: SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 12),
                                  Container(
                                    height: 5,
                                    width: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE5E7EB),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Update Assignment',
                                        style: AppTheme.getTextStyle(context,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF111827),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildBottomSheetAction(
                                    context: ctx,
                                    icon: Icons.play_circle_fill_rounded,
                                    label: 'Mark In Progress',
                                    color: const Color(0xFF475569),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _updateAssignmentStatus(b, 'In Progress');
                                    },
                                  ),
                                  _buildBottomSheetAction(
                                    context: ctx,
                                    icon: Icons.check_circle_rounded,
                                    label: 'Mark Completed',
                                    color: const Color(0xFF111827),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _showManualOrderSheet(b);
                                    },
                                    isLast: true,
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Update Assignment',
                              style: AppTheme.getTextStyle(context, 
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                size: 18, color: Color(0xFF6B7280)),
                          ],
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
    );
  }

  Widget _buildBottomSheetAction({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: AppTheme.getTextStyle(context,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 4),
        Text(label,
            style: AppTheme.getTextStyle(context, 
                fontSize: 12,
                color: const Color(0xFF6B7280),
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SalomonBottomBar(
            currentIndex: _currentTab,
            onTap: (i) => setState(() => _currentTab = i),
            selectedItemColor: _accent,
            unselectedItemColor: const Color(0xFF9CA3AF),
            itemPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            items: [
              SalomonBottomBarItem(
                icon: const Icon(Icons.home_rounded),
                title: Text('operator_nav_home'.tr(), style: AppTheme.getTextStyle(context, fontWeight: FontWeight.w700)),
              ),
              SalomonBottomBarItem(
                icon: const Icon(Icons.history_rounded),
                title: Text('operator_nav_history'.tr(), style: AppTheme.getTextStyle(context, fontWeight: FontWeight.w700)),
              ),
              SalomonBottomBarItem(
                icon: const Icon(Icons.person_rounded),
                title: Text('operator_nav_profile'.tr(), style: AppTheme.getTextStyle(context, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton(
      onPressed: _showManualOrderSheet,
      backgroundColor: _accent,
      elevation: 4,
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
    );
  }
}
