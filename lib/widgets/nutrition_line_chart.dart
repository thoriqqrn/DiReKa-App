import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/nutrition_history_service.dart';

/// Reusable line chart widget untuk nutrition tracking HF patients.
/// Menampilkan actual consumption vs target dengan 2 garis.
class NutritionLineChart extends StatelessWidget {
  final String title;
  final String unit;
  final List<DailyNutrition> weeklyData;
  final Color lineColor;
  final double Function(DailyNutrition) getActual;
  final double Function(DailyNutrition) getTarget;
  final double minY;
  final double maxY;
  final bool showTargetLine;

  const NutritionLineChart({
    super.key,
    required this.title,
    required this.unit,
    required this.weeklyData,
    required this.lineColor,
    required this.getActual,
    required this.getTarget,
    this.minY = 0,
    this.maxY = 100,
    this.showTargetLine = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (weeklyData.isEmpty) {
      return SizedBox(
        height: 260,
        child: Center(child: CircularProgressIndicator(color: theme.primaryColor)),
      );
    }

    // Build FlSpots untuk actual dan target
    final actualSpots = <FlSpot>[];
    final targetSpots = <FlSpot>[];

    for (int i = 0; i < weeklyData.length; i++) {
      final data = weeklyData[i];
      actualSpots.add(FlSpot(i.toDouble(), getActual(data)));
      targetSpots.add(FlSpot(i.toDouble(), getTarget(data)));
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: isDark ? Border.all(color: theme.dividerColor) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Legend (header section)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: lineColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Aktual',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.hintColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (showTargetLine) ...[
                      const SizedBox(width: 12),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.redAccent.shade100 : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Target',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.hintColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Chart
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 12),
            child: SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    drawVerticalLine: false,
                    horizontalInterval: (maxY - minY) / 4,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: theme.dividerColor.withValues(alpha: 0.2),
                        strokeWidth: 0.8,
                        dashArray: [5, 5],
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 &&
                              value.toInt() < weeklyData.length) {
                            final date = weeklyData[value.toInt()].date;
                            final dayLabel = [
                              'Min',
                              'Sen',
                              'Sel',
                              'Rab',
                              'Kam',
                              'Jum',
                              'Sab',
                            ][date.weekday % 7];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                dayLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.hintColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              fontSize: 9,
                              color: theme.hintColor,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      left: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                      bottom: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                  ),
                  minX: 0,
                  maxX: 6,
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: actualSpots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: lineColor,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: lineColor,
                            strokeWidth: 2,
                            strokeColor: isDark ? const Color(0xFF000621) : Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: lineColor.withValues(alpha: 0.08),
                      ),
                    ),
                    if (showTargetLine)
                      LineChartBarData(
                        spots: targetSpots,
                        isCurved: false,
                        color: isDark ? Colors.redAccent.shade100 : Colors.red.shade400,
                        barWidth: 1.8,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 3.5,
                              color: isDark ? Colors.redAccent.shade100 : Colors.red.shade400,
                              strokeWidth: 0,
                            );
                          },
                        ),
                        dashArray: [4, 3],
                        belowBarData: BarAreaData(show: false),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Unit info (bottom)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Text(
              'Satuan: $unit',
              style: TextStyle(
                fontSize: 11,
                color: theme.hintColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
