import 'package:flutter/material.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cropsync/models/chc_operator.dart';
import 'package:cropsync/services/api_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';

class OperatorAnalyticsTab extends StatefulWidget {
  final ChcOperator? operator;

  const OperatorAnalyticsTab({super.key, required this.operator});

  @override
  State<OperatorAnalyticsTab> createState() => _OperatorAnalyticsTabState();
}

class _OperatorAnalyticsTabState extends State<OperatorAnalyticsTab> {
  bool _isLoading = true;
  Map<String, dynamic>? _analyticsData;
  String _timeframe = 'month'; // 'week', 'month', 'all'

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.operator == null) return;
    if (_analyticsData == null) {
      setState(() => _isLoading = true);
    }

    final data = await ApiService.getOperatorAnalytics(
      widget.operator!.operatorId,
      timeframe: _timeframe,
    );

    if (mounted) {
      setState(() {
        _analyticsData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildShimmer();
    }

    if (_analyticsData == null) {
      return Center(
        child: Text(
          'operator_analytics_error'.tr(),
          style: AppTheme.getTextStyle(context, color: Colors.red),
        ),
      );
    }

    final double todayEarnings = _toDouble(_analyticsData!['today_earnings']);
    final double todayJobs = _toDouble(_analyticsData!['today_jobs']);
    final double todayCollected = _toDouble(_analyticsData!['today_collected']);
    final double todayPending = _toDouble(_analyticsData!['today_pending']);
    final double todayHours = _toDouble(_analyticsData!['today_hours']);
    final double weeklyHours = _toDouble(_analyticsData!['weekly_hours']);
    final double monthlyHours = _toDouble(_analyticsData!['monthly_hours']);
    final double seasonHours = _toDouble(_analyticsData!['season_hours']);
    final double totalEarnings = _toDouble(_analyticsData!['total_earnings']);
    final double totalJobs = _toDouble(_analyticsData!['total_completed_jobs']);
    final double totalCollected = _toDouble(_analyticsData!['total_collected']);
    final double totalPending = _toDouble(_analyticsData!['total_pending']);
    final dailyEarnings = List<Map<String, dynamic>>.from(
        _analyticsData!['daily_earnings'] ?? []);
    final equipmentUsage = List<Map<String, dynamic>>.from(
        _analyticsData!['equipment_usage'] ?? []);

    return RefreshIndicator(
      color: const Color(0xFF111827),
      onRefresh: _loadData,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'operator_analytics_title'.tr(),
                    style: AppTheme.getTextStyle(
                      context,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildTimeframeFilter(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'operator_today_overview'.tr(),
                    style: AppTheme.getTextStyle(
                      context,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          title: 'operator_today_earnings'.tr(),
                          value: todayEarnings,
                          prefix: '₹',
                          icon: Icons.flash_on_rounded,
                          color: const Color(0xFFD97706),
                          bgColor: const Color(0xFFFEF3C7),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          title: 'operator_today_jobs'.tr(),
                          value: todayJobs,
                          icon: Icons.work_history_rounded,
                          color: const Color(0xFF9333EA),
                          bgColor: const Color(0xFFF3E8FF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          title: 'operator_collected'.tr(),
                          value: todayCollected,
                          prefix: '₹',
                          icon: Icons.check_circle_rounded,
                          color: const Color(0xFF059669),
                          bgColor: const Color(0xFFD1FAE5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          title: 'operator_pending'.tr(),
                          value: todayPending,
                          prefix: '₹',
                          icon: Icons.pending_actions_rounded,
                          color: const Color(0xFFDC2626),
                          bgColor: const Color(0xFFFEE2E2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _timeframe == 'week' 
                        ? "This Week's Total" 
                        : _timeframe == 'month' ? "This Month's Total" : "All Time Total",
                    style: AppTheme.getTextStyle(
                      context,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          title: 'operator_total_earnings'.tr(),
                          value: totalEarnings,
                          prefix: '₹',
                          icon: Icons.currency_rupee_rounded,
                          color: const Color(0xFF047857),
                          bgColor: const Color(0xFFD1FAE5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          title: 'operator_completed_jobs'.tr(),
                          value: totalJobs,
                          icon: Icons.check_circle_outline_rounded,
                          color: const Color(0xFF1D4ED8),
                          bgColor: const Color(0xFFDBEAFE),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          title: 'operator_collected'.tr(),
                          value: totalCollected,
                          prefix: '₹',
                          icon: Icons.check_circle_rounded,
                          color: const Color(0xFF059669),
                          bgColor: const Color(0xFFD1FAE5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          title: 'operator_pending'.tr(),
                          value: totalPending,
                          prefix: '₹',
                          icon: Icons.pending_actions_rounded,
                          color: const Color(0xFFDC2626),
                          bgColor: const Color(0xFFFEE2E2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildWorkingHoursSection(
                today: todayHours,
                week: weeklyHours,
                month: monthlyHours,
                season: seasonHours,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          if (dailyEarnings.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildEarningsChart(dailyEarnings),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          if (equipmentUsage.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildEquipmentChart(equipmentUsage),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildTimeframeFilter() {
    final tabs = [
      {'id': 'week', 'label': 'operator_filter_week'.tr()},
      {'id': 'month', 'label': 'operator_filter_month'.tr()},
      {'id': 'all', 'label': 'operator_filter_all_time'.tr()},
    ];
    
    final selectedIndex = tabs.indexWhere((t) => t['id'] == _timeframe);

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / tabs.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                left: selectedIndex >= 0 ? selectedIndex * tabWidth : 0,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                ),
              ),
              Row(
                children: tabs.map((tab) {
                  final isSelected = tab['id'] == _timeframe;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (!isSelected) {
                          setState(() {
                            _timeframe = tab['id']!;
                          });
                          _loadData();
                        }
                      },
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: AppTheme.getTextStyle(
                            context,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? const Color(0xFF111827) : const Color(0xFF6B7280),
                          ),
                          child: Text(tab['label']!),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double value,
    String prefix = '',
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTheme.getTextStyle(
              context,
              fontSize: 13,
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutQuart,
            builder: (context, val, child) {
              return Text(
                '$prefix${val.toInt()}',
                style: AppTheme.getTextStyle(
                  context,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsChart(List<Map<String, dynamic>> dailyEarnings) {
    // Convert to spots
    List<FlSpot> spots = [];
    double maxY = 0;

    // For a simple view, let's just plot the last N days where there's data, or sort by date.
    // The data is ordered ASC by date in the backend
    for (int i = 0; i < dailyEarnings.length; i++) {
      final val = double.parse(dailyEarnings[i]['daily_earnings'].toString());
      if (val > maxY) maxY = val;
      spots.add(FlSpot(i.toDouble(), val));
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'operator_earnings_trend'.tr(),
            style: AppTheme.getTextStyle(
              context,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutCubic,
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => const Color(0xFF1F2937),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((touchedSpot) {
                        return LineTooltipItem(
                          touchedSpot.y.toInt().toString(),
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return const FlLine(
                      color: Color(0xFFE5E7EB),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: dailyEarnings.length > 7 
                          ? (dailyEarnings.length / 5).ceilToDouble() 
                          : 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < dailyEarnings.length) {
                          // Format date to DD/MM
                          final dateStr =
                              dailyEarnings[value.toInt()]['date'] as String;
                          final date = DateTime.tryParse(dateStr);
                          if (date != null) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                '${date.day}/${date.month}',
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: maxY > 0 ? (maxY / 4).ceilToDouble() : 1,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: dailyEarnings.length > 1
                    ? (dailyEarnings.length - 1).toDouble()
                    : 1,
                minY: 0,
                maxY: maxY * 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF047857),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF047857).withValues(alpha: 0.1),
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

  Widget _buildEquipmentChart(List<Map<String, dynamic>> equipmentUsage) {
    List<PieChartSectionData> sections = [];
    final colors = [
      const Color(0xFF047857),
      const Color(0xFF1D4ED8),
      const Color(0xFFB45309),
      const Color(0xFF6D28D9),
      const Color(0xFFBE123C),
    ];

    for (int i = 0; i < equipmentUsage.length; i++) {
      final val = double.parse(equipmentUsage[i]['usage_count'].toString());
      sections.add(
        PieChartSectionData(
          color: colors[i % colors.length],
          value: val,
          title: '${val.toInt()}',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'operator_equipment_usage'.tr(),
            style: AppTheme.getTextStyle(
              context,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                height: 150,
                width: 150,
                child: PieChart(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOutCubic,
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                    sections: sections,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(equipmentUsage.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: colors[i % colors.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              equipmentUsage[i]['equipment_type'] ?? '',
                              style: AppTheme.getTextStyle(
                                context,
                                fontSize: 13,
                                color: const Color(0xFF374151),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFF1F5F9),
      highlightColor: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingHoursSection({
    required double today,
    required double week,
    required double month,
    required double season,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'operator_working_hours_title'.tr(),
          style: AppTheme.getTextStyle(
            context,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildHoursItem(
                      label: 'operator_hours_today'.tr(),
                      hours: today,
                      icon: Icons.today_rounded,
                      color: const Color(0xFF0D9488),
                    ),
                  ),
                  Container(
                    width: 1.5,
                    height: 50,
                    color: const Color(0xFFE5E7EB),
                  ),
                  Expanded(
                    child: _buildHoursItem(
                      label: 'operator_hours_week'.tr(),
                      hours: week,
                      icon: Icons.date_range_rounded,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildHoursItem(
                      label: 'operator_hours_month'.tr(),
                      hours: month,
                      icon: Icons.calendar_month_rounded,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                  Container(
                    width: 1.5,
                    height: 50,
                    color: const Color(0xFFE5E7EB),
                  ),
                  Expanded(
                    child: _buildHoursItem(
                      label: 'operator_hours_season'.tr(),
                      hours: season,
                      icon: Icons.all_inclusive_rounded,
                      color: const Color(0xFFEA580C),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHoursItem({
    required String label,
    required double hours,
    required IconData icon,
    required Color color,
  }) {
    final String formattedHours = hours % 1 == 0 ? hours.toInt().toString() : hours.toStringAsFixed(1);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$formattedHours hrs',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
