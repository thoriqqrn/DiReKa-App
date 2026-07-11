import 'package:cloud_firestore/cloud_firestore.dart';
import 'food_item.dart';
import 'meal_type.dart';

/// Satu entri makanan yang dicatat user dalam satu hari.
/// Menyimpan hasil kalkulasi nutrisi agar tidak perlu recalculate saat baca.
class FoodLogEntry {
  final String id;
  final String foodId;
  final String foodName;
  final double grams;
  final DateTime loggedAt;
  final MealType mealType; // ← NEW: Which meal category

  // Nilai nutrisi sudah dihitung untuk [grams] gram
  final double energi;
  final double protein;
  final double lemak;
  final double karbohidrat;
  final double natrium;
  final double kalium;
  final double fosfor;
  final double air; // cairan dari makanan ini
  final double serat; // g
  final double indeksGlikemik; // Samakan dengan FoodItem
  final double kalsium; // mg
  final double magnesium; // mg

  const FoodLogEntry({
    required this.id,
    required this.foodId,
    required this.foodName,
    required this.grams,
    required this.loggedAt,
    required this.mealType,
    required this.energi,
    required this.protein,
    required this.lemak,
    required this.karbohidrat,
    required this.natrium,
    required this.kalium,
    required this.fosfor,
    required this.air,
    this.serat = 0.0,
    this.indeksGlikemik = 0.0,
    this.kalsium = 0.0,
    this.magnesium = 0.0,
  });

  /// Hitung Glycemic Load (GL) untuk entri ini: (GI * Karbohidrat) / 100
  double get glycemicLoad {
    return (indeksGlikemik * karbohidrat) / 100.0;
  }

  /// Buat entri baru dari [food] dan jumlah [grams].
  /// [loggedAt] opsional — jika tidak diisi pakai DateTime.now().
  factory FoodLogEntry.create({
    required FoodItem food,
    required double grams,
    required MealType mealType,
    DateTime? loggedAt,
  }) {
    final n = food.calcFor(grams);
    final now = loggedAt ?? DateTime.now();
    return FoodLogEntry(
      id: now.microsecondsSinceEpoch.toString(),
      foodId: food.id,
      foodName: food.nama,
      grams: grams,
      loggedAt: now,
      mealType: mealType,
      energi: (n['energi'] ?? 0.0).toDouble(),
      protein: (n['protein'] ?? 0.0).toDouble(),
      lemak: (n['lemak'] ?? 0.0).toDouble(),
      karbohidrat: (n['karbohidrat'] ?? 0.0).toDouble(),
      natrium: (n['natrium'] ?? 0.0).toDouble(),
      kalium: (n['kalium'] ?? 0.0).toDouble(),
      fosfor: (n['fosfor'] ?? 0.0).toDouble(),
      air: (n['air'] ?? 0.0).toDouble(),
      serat: (n['serat'] ?? 0.0).toDouble(),
      indeksGlikemik: food.indeksGlikemik.toDouble(),
      kalsium: (n['kalsium'] ?? 0.0).toDouble(),
      magnesium: (n['magnesium'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'foodId': foodId,
      'foodName': foodName,
      'grams': grams,
      'loggedAt': Timestamp.fromDate(loggedAt),
      'mealType': mealType.value,
      'energi': energi,
      'protein': protein,
      'lemak': lemak,
      'karbohidrat': karbohidrat,
      'natrium': natrium,
      'kalium': kalium,
      'fosfor': fosfor,
      'air': air,
      'serat': serat,
      'indeksGlikemik': indeksGlikemik,
      'kalsium': kalsium,
      'magnesium': magnesium,
    };
  }

  factory FoodLogEntry.fromMap(Map<String, dynamic> map) {
    double toDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    return FoodLogEntry(
      id: (map['id'] ?? '').toString(),
      foodId: (map['foodId'] ?? '').toString(),
      foodName: (map['foodName'] ?? '').toString(),
      grams: toDouble(map['grams']),
      loggedAt: map['loggedAt'] != null
          ? (map['loggedAt'] as Timestamp).toDate()
          : DateTime.now(),
      mealType: MealTypeExtension.fromValue(
        map['mealType'] as String? ?? 'makan_siang',
      ),
      energi: toDouble(map['energi']),
      protein: toDouble(map['protein']),
      lemak: toDouble(map['lemak']),
      karbohidrat: toDouble(map['karbohidrat']),
      natrium: toDouble(map['natrium']),
      kalium: toDouble(map['kalium']),
      fosfor: toDouble(map['fosfor']),
      air: toDouble(map['air']),
      serat: toDouble(map['serat']),
      indeksGlikemik: toDouble(map['indeksGlikemik'] ?? map['glycemicIndex']),
      kalsium: toDouble(map['kalsium']),
      magnesium: toDouble(map['magnesium']),
    );
  }
}
