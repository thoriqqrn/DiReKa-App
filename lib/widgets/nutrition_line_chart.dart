import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/nutrition_history_service.dart';

/// Reusable line chart widget untuk nutrition tracking.
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
        height: 300,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title + Legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Row(
                children: [
                  // Actual color
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: lineColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Aktual',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(width: 12),
                  // Target color
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Target',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Chart
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final days = ['1', '2', '3', '4', '5', '6', '7'];
                        if (value.toInt() < days.length) {
                          return Text(days[value.toInt()],
                              style: const TextStyle(fontSize: 11));
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 11),
                        );
                      },
                      reservedSize: 32,
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: true),
                minX: 0,
                maxX: 6,
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  // Actual line
                  LineChartBarData(
                    spots: actualSpots,
                    isCurved: true,
                    color: lineColor,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  ),
                  // Target line (dashed, red)
                  LineChartBarData(
                    spots: targetSpots,
                    isCurved: false,
                    color: Colors.red,
                    barWidth: 2,
                    dotData: const FlDotData(show: true),
                    dashArray: [5, 5],
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Unit info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Satuan: $unit',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
