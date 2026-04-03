import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/food_log_entry.dart';
import '../models/nutrition_needs.dart';

/// Data gizi harian untuk satu hari.
class DailyNutrition {
  final DateTime date;
  final double energi;
  final double lemak;
  final double natrium;
  final double cairan;
  final double targetEnergi;
  final double targetLemak;
  final double targetNatrium;
  final double targetCairan;

  DailyNutrition({
    required this.date,
    required this.energi,
    required this.lemak,
    required this.natrium,
    required this.cairan,
    required this.targetEnergi,
    required this.targetLemak,
    required this.targetNatrium,
    required this.targetCairan,
  });
}

/// Service untuk fetch nutrisi history dari Firestore.
/// Digunakan untuk membuat weekly charts.
class NutritionHistoryService {
  static final _db = FirebaseFirestore.instance;

  static String _docId(String uid, DateTime date) {
    final d =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return '${uid}_$d';
  }

  /// Fetch nutrisi harian untuk 7 hari terakhir (dari endDate, mundur 7 hari).
  /// Menggabungkan actual consumption dari food_logs + target dari nutritionNeeds.
  static Future<List<DailyNutrition>> getWeeklyNutrition({
    required String uid,
    required DateTime endDate,
    required NutritionNeeds targets,
  }) async {
    final result = <DailyNutrition>[];

    // Loop 7 hari (dari endDate ke belakang)
    for (int i = 6; i >= 0; i--) {
      final date = endDate.subtract(Duration(days: i));
      final docId = _docId(uid, date);

      try {
        final doc = await _db.collection('food_logs').doc(docId).get();
        final entries = <FoodLogEntry>[];

        if (doc.exists) {
          final entriesData = doc.data()!['entries'] as List<dynamic>? ?? [];
          entries.addAll(
            entriesData
                .map((e) => FoodLogEntry.fromMap(e as Map<String, dynamic>))
                .toList(),
          );
        }

        // Sum nutrients untuk hari ini
        final energi = entries.fold(0.0, (sum, e) => sum + e.energi);
        final lemak = entries.fold(0.0, (sum, e) => sum + e.lemak);
        final natrium = entries.fold(0.0, (sum, e) => sum + e.natrium);
        final cairan = entries.fold(0.0, (sum, e) => sum + e.air);

        result.add(
          DailyNutrition(
            date: date,
            energi: energi,
            lemak: lemak,
            natrium: natrium,
            cairan: cairan,
            targetEnergi: targets.energi,
            targetLemak: targets.lemak,
            targetNatrium: targets.natrium,
            targetCairan: targets.cairan,
          ),
        );
      } catch (e) {
        // Jika error, asumsikan 0 consumption untuk hari itu
        result.add(
          DailyNutrition(
            date: date,
            energi: 0,
            lemak: 0,
            natrium: 0,
            cairan: 0,
            targetEnergi: targets.energi,
            targetLemak: targets.lemak,
            targetNatrium: targets.natrium,
            targetCairan: targets.cairan,
          ),
        );
      }
    }

    return result;
  }
}
