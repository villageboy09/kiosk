import 'package:flutter/material.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shimmer/shimmer.dart';

import 'package:cropsync/models/chc_operator.dart';
import 'package:cropsync/services/api_service.dart';

class OperatorHistoryScreen extends StatefulWidget {
  final ChcOperator? operator;
  const OperatorHistoryScreen({super.key, required this.operator});

  @override
  State<OperatorHistoryScreen> createState() => _OperatorHistoryScreenState();
}

class _OperatorHistoryScreenState extends State<OperatorHistoryScreen> {
  List<Map<String, dynamic>> _all = [];
  bool _isLoading = true;
  String _filter = 'operator_filter_all';
  final _searchController = TextEditingController();

  static const Color _accent = Color(0xFF111827);

  bool _isStatus(Map<String, dynamic> b, String key, List<String> values) {
    final raw = b[key]?.toString().trim().toLowerCase() ?? '';
    return values.contains(raw);
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(OperatorHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.operator != null) {
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.operator == null) return;
    setState(() => _isLoading = true);
    final all =
        await ApiService.getOperatorBookings(widget.operator!.operatorId);
    if (mounted) {
      setState(() {
        _all = all;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    List<Map<String, dynamic>> list = _all;
    if (_filter == 'operator_filter_completed') {
      list = _all
          .where((b) =>
              _isStatus(b, 'booking_status', const ['completed']) ||
              _isStatus(b, 'assignment_status', const ['completed']))
          .toList();
    } else if (_filter == 'operator_filter_cancelled') {
      list = _all
          .where((b) =>
              _isStatus(b, 'booking_status', const ['cancelled']) ||
              _isStatus(b, 'assignment_status', const ['cancelled']))
          .toList();
    }

    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      list = list.where((b) {
        final phone = b['farmer_phone']?.toString() ?? '';
        return phone.contains(query);
      }).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _accent,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('operator_booking_history'.tr(),
                      style: AppTheme.getTextStyle(context,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827))),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() {}),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                decoration: InputDecoration(
                  hintText: 'operator_search_hint'.tr(),
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 22),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Color(0xFF64748B), size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(child: _buildFilterChips()),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (_isLoading)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => Shimmer.fromColors(
                    baseColor: const Color(0xFFF1F5F9),
                    highlightColor: Colors.white,
                    child: Container(
                      height: 100,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  childCount: 4,
                ),
              ),
            )
          else if (_filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 60, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text('operator_no_history_found'.tr(),
                        style: AppTheme.getTextStyle(context,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF9CA3AF))),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _buildHistoryCard(_filtered[i]),
                  childCount: _filtered.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          'operator_filter_all',
          'operator_filter_completed',
          'operator_filter_cancelled'
        ].map((f) {
          final active = _filter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? _accent : Colors.white,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: active ? _accent : const Color(0xFFE5E7EB),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  f.tr(),
                  style: AppTheme.getTextStyle(
                    context,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : const Color(0xFF4B5563),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showUpdatePaymentSheet(Map<String, dynamic> booking) {
    final double totalCost = _toDouble(booking['total_cost']);
    final double currentPaid = _toDouble(booking['amount_paid']);
    final double pending = totalCost - currentPaid;

    final controller = TextEditingController(text: pending.toStringAsFixed(0));
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.payment_rounded, color: _accent, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'operator_update_payment'.tr(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildPaymentSummaryRow('operator_total_cost'.tr(), '₹${totalCost.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    _buildPaymentSummaryRow('operator_amount_paid_label'.tr(), '₹${currentPaid.toStringAsFixed(2)}', color: const Color(0xFF059669)),
                    const SizedBox(height: 8),
                    _buildPaymentSummaryRow('operator_pending_balance'.tr(), '₹${pending.toStringAsFixed(2)}', color: pending > 0 ? const Color(0xFFDC2626) : const Color(0xFF6B7280)),
                    const Divider(height: 32, thickness: 1),
                    if (pending > 0) ...[
                      Text(
                        'operator_collect_amount_label'.tr(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 20),
                          hintText: '0.00',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final double collectVal = double.tryParse(controller.text.trim()) ?? 0.0;
                                  if (collectVal <= 0) return;
                                  
                                  setSheetState(() => isSaving = true);
                                  
                                  final double newPaid = currentPaid + collectVal;
                                  final navigator = Navigator.of(context);
                                  final messenger = ScaffoldMessenger.of(context);

                                  try {
                                    final res = await ApiService.updateOperatorBookingStatus(
                                      bookingId: booking['booking_id'],
                                      amountPaid: newPaid,
                                    );
                                    
                                    if (res['success'] == true) {
                                      if (mounted) {
                                        navigator.pop();
                                        _load();
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text('operator_payment_updated'.tr()),
                                            backgroundColor: const Color(0xFF059669),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    } else {
                                      throw Exception(res['error'] ?? 'Update failed');
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(e.toString()),
                                          backgroundColor: const Color(0xFFDC2626),
                                        ),
                                      );
                                    }
                                  } finally {
                                    setSheetState(() => isSaving = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                          child: isSaving
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('operator_confirm_payment'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ] else ...[
                      Center(
                        child: Column(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'operator_fully_paid'.tr(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF059669)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentSummaryRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color ?? const Color(0xFF111827))),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> b) {
    final status = b['booking_status'] ?? '';
    final bookingStatus = (b['booking_status']?.toString() ?? '').toLowerCase().trim();
    final assignmentStatus = (b['assignment_status']?.toString() ?? '').toLowerCase().trim();
    final isCompleted = bookingStatus == 'completed' || assignmentStatus == 'completed';
    final statusColor =
        isCompleted ? const Color(0xFF0F172A) : const Color(0xFF475569);
    final statusBg =
        isCompleted ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC);

    final farmerName = b['farmer_name']?.toString().isNotEmpty == true
        ? b['farmer_name'].toString()
        : 'Unknown Farmer';
    final village = b['farmer_village']?.toString().isNotEmpty == true
        ? b['farmer_village'].toString()
        : 'Unknown Location';
    final billedQty = b['billed_qty']?.toString() ?? '-';
    final unitType = b['unit_type']?.toString() ?? '';

    final double totalCost = _toDouble(b['total_cost']);
    final double amountPaid = _toDouble(b['amount_paid']);
    final String paymentStatusRaw = b['payment_status']?.toString() ?? 'Pending';
    final bool isPaid = paymentStatusRaw.toLowerCase().trim() == 'paid';
    final double pendingAmount = totalCost - amountPaid;

    return GestureDetector(
      onTap: isCompleted ? () => _showUpdatePaymentSheet(b) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
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
                        color: _accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b['equipment_type'] ??
                              'operator_equipment_fallback'.tr(),
                          style: AppTheme.getTextStyle(
                            context,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                size: 12, color: Color(0xFF9CA3AF)),
                            const SizedBox(width: 4),
                            Text(
                              b['service_date']?.toString() ?? '—',
                              style: AppTheme.getTextStyle(
                                context,
                                fontSize: 12,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
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
                    child: Text(status,
                        style: AppTheme.getTextStyle(
                          context,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        )),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded,
                                size: 14, color: Color(0xFF9CA3AF)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                farmerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.getTextStyle(context,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 14, color: Color(0xFF9CA3AF)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                village,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.getTextStyle(context,
                                    fontSize: 13, color: const Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                      width: 1,
                      height: 32,
                      color: const Color(0xFFE2E8F0),
                      margin: const EdgeInsets.symmetric(horizontal: 16)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$billedQty $unitType',
                        style: AppTheme.getTextStyle(context,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${b['final_amount'] ?? b['total_cost'] ?? '0'}',
                        style: AppTheme.getTextStyle(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      if (isCompleted) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPaid ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isPaid
                                ? 'operator_paid'.tr()
                                : 'operator_pending_amount'.tr().replaceFirst('{}', pendingAmount.toStringAsFixed(0)),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isPaid ? const Color(0xFF065F46) : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


