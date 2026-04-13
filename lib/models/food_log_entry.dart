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

  const FoodLogEntry({
    required this.id,
    required this.foodId,
    required this.foodName,
    required this.grams,
    required this.loggedAt,
    required this.mealType, // ← NEW
    required this.energi,
    required this.protein,
    required this.lemak,
    required this.karbohidrat,
    required this.natrium,
    required this.kalium,
    required this.fosfor,
    required this.air,
    this.serat = 0.0,
  });

  /// Buat entri baru dari [food] dan jumlah [grams].
  factory FoodLogEntry.create({
    required FoodItem food,
    required double grams,
    required MealType mealType, // ← NEW
  }) {
    final n = food.calcFor(grams);
    return FoodLogEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      foodId: food.id,
      foodName: food.nama,
      grams: grams,
      loggedAt: DateTime.now(),
      mealType: mealType, // ← SET
      energi: n['energi']!,
      protein: n['protein']!,
      lemak: n['lemak']!,
      karbohidrat: n['karbohidrat']!,
      natrium: n['natrium']!,
      kalium: n['kalium']!,
      fosfor: n['fosfor']!,
      air: n['air']!,
      serat: n['serat'] ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'foodId': foodId,
      'foodName': foodName,
      'grams': grams,
      'loggedAt': Timestamp.fromDate(loggedAt),
      'mealType': mealType.value, // ← NEW
      'energi': energi,
      'protein': protein,
      'lemak': lemak,
      'karbohidrat': karbohidrat,
      'natrium': natrium,
      'kalium': kalium,
      'fosfor': fosfor,
      'air': air,
      'serat': serat,
    };
  }

  factory FoodLogEntry.fromMap(Map<String, dynamic> map) {
    return FoodLogEntry(
      id: map['id'] as String,
      foodId: map['foodId'] as String,
      foodName: map['foodName'] as String,
      grams: (map['grams'] as num).toDouble(),
      loggedAt: (map['loggedAt'] as Timestamp).toDate(),
      mealType: MealTypeExtension.fromValue(
        map['mealType'] as String? ?? 'makan_siang',
      ), // ← NEW
      energi: (map['energi'] as num).toDouble(),
      protein: (map['protein'] as num).toDouble(),
      lemak: (map['lemak'] as num).toDouble(),
      karbohidrat: (map['karbohidrat'] as num).toDouble(),
      natrium: (map['natrium'] as num).toDouble(),
      kalium: (map['kalium'] as num).toDouble(),
      fosfor: (map['fosfor'] as num).toDouble(),
      air: (map['air'] as num).toDouble(),
      serat: (map['serat'] as num? ?? 0).toDouble(),
    );
  }
}
