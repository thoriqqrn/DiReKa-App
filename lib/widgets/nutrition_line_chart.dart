import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/nutrition_history_service.dart';
import '../../core/app_colors.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    if (weeklyData.isEmpty) {
      return const SizedBox(
        height: 260,
        child: Center(child: CircularProgressIndicator()),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    // Actual legend
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: lineColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Aktual',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Target legend
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Target',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
                        color: Colors.grey.withValues(alpha: 0.08),
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
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
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
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary,
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
                        color: Colors.grey.withValues(alpha: 0.2),
                        width: 0.8,
                      ),
                      bottom: BorderSide(
                        color: Colors.grey.withValues(alpha: 0.2),
                        width: 0.8,
                      ),
                    ),
                  ),
                  minX: 0,
                  maxX: 6,
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    // Actual line (solid, thicker)
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
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: lineColor.withValues(alpha: 0.08),
                      ),
                    ),
                    // Target line (dashed, red, thinner)
                    LineChartBarData(
                      spots: targetSpots,
                      isCurved: false,
                      color: Colors.red.shade400,
                      barWidth: 1.8,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 3.5,
                            color: Colors.red.shade400,
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
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
