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

  static const Color _accent = Color(0xFF111827);

  bool _isStatus(Map<String, dynamic> b, String key, List<String> values) {
    final raw = b[key]?.toString().trim().toLowerCase() ?? '';
    return values.contains(raw);
  }

  @override
  void initState() {
    super.initState();
    _load();
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
    if (_filter == 'operator_filter_all') return _all;
    if (_filter == 'operator_filter_completed') {
      return _all
          .where((b) =>
              _isStatus(b, 'booking_status', const ['completed']) ||
              _isStatus(b, 'assignment_status', const ['completed']))
          .toList();
    }
    return _all
        .where((b) =>
            _isStatus(b, 'booking_status', const ['cancelled']) ||
            _isStatus(b, 'assignment_status', const ['cancelled']))
        .toList();
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
                  style: AppTheme.getTextStyle(context, 
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

  Widget _buildHistoryCard(Map<String, dynamic> b) {
    final status = b['booking_status'] ?? '';
    final isCompleted = status == 'Completed';
    final statusColor =
        isCompleted ? const Color(0xFF0F172A) : const Color(0xFF475569);
    final statusBg =
        isCompleted ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC);

    final farmerName = b['farmer_name']?.toString().isNotEmpty == true ? b['farmer_name'].toString() : 'operator_unknown_farmer'.tr();
    final village = b['farmer_village']?.toString().isNotEmpty == true ? b['farmer_village'].toString() : 'operator_unknown_location'.tr();
    final billedQty = b['billed_qty']?.toString() ?? '-';
    final unitType = b['unit_type']?.toString() ?? '';

    return Container(
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
                        b['equipment_type'] ?? 'operator_equipment_fallback'.tr(),
                        style: AppTheme.getTextStyle(context, 
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF9CA3AF)),
                          const SizedBox(width: 4),
                          Text(
                            b['service_date']?.toString() ?? '—',
                            style: AppTheme.getTextStyle(context, 
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
                      style: AppTheme.getTextStyle(context, 
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
                          const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF9CA3AF)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              farmerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.getTextStyle(context, fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF9CA3AF)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              village,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.getTextStyle(context, fontSize: 13, color: const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(horizontal: 16)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$billedQty $unitType',
                      style: AppTheme.getTextStyle(context, fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${b['final_amount'] ?? b['total_cost'] ?? '0'}',
                      style: AppTheme.getTextStyle(context, 
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
