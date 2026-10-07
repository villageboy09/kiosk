import 'package:cropsync/models/market_price.dart';
import 'package:cropsync/widgets/market/detail_text.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' show DateFormat;

String _shortDate(BuildContext context, DateTime d) {
  try {
    return DateFormat('d MMM', Localizations.localeOf(context).toString())
        .format(d);
  } catch (_) {
    return '${d.day}/${d.month}';
  }
}

/// Line chart of REAL trend points only. Never pads or synthesises data; the
/// caller must only build it with at least two points (it renders nothing
/// otherwise).
class CommodityTrendChart extends StatelessWidget {
  final List<TrendPoint> points;
  final double height;
  final Color color;

  const CommodityTrendChart({
    super.key,
    required this.points,
    this.height = 180,
    this.color = const Color(0xFF15803D),
  });

  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].avgPrice),
    ];
    var lo = points.map((p) => p.avgPrice).reduce((a, b) => a < b ? a : b);
    var hi = points.map((p) => p.avgPrice).reduce((a, b) => a > b ? a : b);
    var pad = (hi - lo) * 0.18;
    if (pad < hi * 0.01) pad = hi * 0.02 + 1;
    final minY = (lo - pad).clamp(0.0, double.infinity);
    final maxY = hi + pad;
    final last = points.length - 1;
    final labelStep = last <= 3 ? 1 : (last / 3).ceil();

    TextStyle axis() => detailUi(
        context, const TextStyle(fontSize: 10.5, color: _muted, height: 1.2));

    return SizedBox(
      key: const ValueKey('commodity_trend_chart'),
      height: height,
      child: Padding(
        padding: const EdgeInsets.only(right: 8, top: 6),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: last.toDouble(),
            minY: minY,
            maxY: maxY,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (maxY - minY) / 3,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: Color(0xFFE2E8F0), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 58,
                  interval: (maxY - minY) / 3,
                  getTitlesWidget: (v, meta) {
                    if (v == meta.min || v == meta.max) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        MarketPrice.formatRupees(v, compact: true),
                        textAlign: TextAlign.right,
                        style: axis(),
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  interval: 1,
                  getTitlesWidget: (v, meta) {
                    final i = v.round();
                    if ((v - i).abs() > 0.001 || i < 0 || i > last) {
                      return const SizedBox.shrink();
                    }
                    final d = points[i].date;
                    if (d == null || (i % labelStep != 0 && i != last)) {
                      return const SizedBox.shrink();
                    }
                    // Skip a mid label that would crowd the final one.
                    if (i != last && last - i < labelStep * 0.6) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      space: 6,
                      fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                      child: Text(_shortDate(context, d), style: axis()),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => _ink,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItems: (touched) => [
                  for (final s in touched)
                    LineTooltipItem(
                      _tip(context, points[s.spotIndex]),
                      detailUi(
                        context,
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: points.length > 3,
                curveSmoothness: 0.2,
                preventCurveOverShooting: true,
                color: color,
                barWidth: 2.6,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: points.length <= 16,
                  getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                    radius: 3,
                    color: Colors.white,
                    strokeColor: color,
                    strokeWidth: 2,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: 0.18),
                      color.withValues(alpha: 0.0),
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

  String _tip(BuildContext context, TrendPoint p) {
    final price = MarketPrice.formatRupees(p.avgPrice);
    final d = p.date;
    return d == null ? price : '${_shortDate(context, d)}\n$price';
  }
}
