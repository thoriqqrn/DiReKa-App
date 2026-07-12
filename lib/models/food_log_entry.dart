import 'package:cloud_firestore/cloud_firestore.dart';
import 'food_item.dart';
import 'food_modifier.dart';
import 'meal_type.dart';

/// Satu entri makanan yang dicatat user dalam satu hari.
/// Menyimpan hasil kalkulasi nutrisi agar tidak perlu recalculate saat baca.
class FoodLogEntry {
  final String id;
  final String foodId;
  final String foodName;
  final double grams;
  final DateTime loggedAt;
  final MealType mealType;

  // ── Pengolahan ─────────────────────────────────────────────────────────
  final String? cookingMethodId;
  final String? cookingMethodName;

  // ── Bahan Tambahan ─────────────────────────────────────────────────────
  final List<Map<String, dynamic>> additives; // list SelectedAdditive.toMap()

  // Nilai nutrisi sudah dihitung untuk [grams] gram TERMASUK pengolahan & bahan tambahan
  final double energi;
  final double protein;
  final double lemak;
  final double karbohidrat;
  final double natrium;
  final double kalium;
  final double fosfor;
  final double air;
  final double serat;
  final double indeksGlikemik;
  final double kalsium;
  final double magnesium;

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
    this.cookingMethodId,
    this.cookingMethodName,
    this.additives = const [],
  });

  double get glycemicLoad => (indeksGlikemik * karbohidrat) / 100.0;

  // ── Nama tampilan lengkap di log ──────────────────────────────────────
  String get displayName {
    final parts = <String>[foodName];
    if (cookingMethodName != null && cookingMethodName!.isNotEmpty &&
        cookingMethodName != 'Mentah (Tidak Diolah)') {
      parts.add('(${cookingMethodName!})');
    }
    if (additives.isNotEmpty) {
      final addNames = additives
          .map((a) => '${a['additiveName']}')
          .join(', ');
      parts.add('+ $addNames');
    }
    return parts.join(' ');
  }

  /// Buat entri baru dari [food], [grams], metode masak, dan bahan tambahan.
  factory FoodLogEntry.create({
    required FoodItem food,
    required double grams,
    required MealType mealType,
    DateTime? loggedAt,
    CookingMethod? cookingMethod,
    List<SelectedAdditive> selectedAdditives = const [],
  }) {
    final baseNutrition = food.calcFor(grams);
    final now = loggedAt ?? DateTime.now();

    // ── Hitung gizi dari bahan dasar ──────────────────────────────────
    double energi  = (baseNutrition['energi']      ?? 0.0).toDouble();
    double protein = (baseNutrition['protein']     ?? 0.0).toDouble();
    double lemak   = (baseNutrition['lemak']       ?? 0.0).toDouble();
    double karbo   = (baseNutrition['karbohidrat'] ?? 0.0).toDouble();
    double natrium = (baseNutrition['natrium']     ?? 0.0).toDouble();
    double kalium  = (baseNutrition['kalium']      ?? 0.0).toDouble();
    double fosfor  = (baseNutrition['fosfor']      ?? 0.0).toDouble();
    double air     = (baseNutrition['air']         ?? 0.0).toDouble();
    double serat   = (baseNutrition['serat']       ?? 0.0).toDouble();
    double kalsium = (baseNutrition['kalsium']     ?? 0.0).toDouble();
    double magnesium = (baseNutrition['magnesium'] ?? 0.0).toDouble();

    // ── Terapkan metode pengolahan ────────────────────────────────────
    if (cookingMethod != null) {
      final delta = cookingMethod.deltaFor(grams);
      if (cookingMethod.mode == CookingNutritionMode.addition) {
        energi  += delta['energi']      ?? 0;
        lemak   += delta['lemak']       ?? 0;
        karbo   += delta['karbohidrat'] ?? 0;
        protein += delta['protein']     ?? 0;
        natrium += delta['natrium']     ?? 0;
      } else {
        // Factor mode: gizi dihitung ulang menggunakan FK
        final fk = delta['fk'] ?? 1.0;
        final beratMentah = grams * fk;
        final rawNutrition = food.calcFor(beratMentah);
        energi  = (rawNutrition['energi']      ?? 0.0).toDouble();
        protein = (rawNutrition['protein']     ?? 0.0).toDouble();
        lemak   = (rawNutrition['lemak']       ?? 0.0).toDouble();
        karbo   = (rawNutrition['karbohidrat'] ?? 0.0).toDouble();
        natrium = (rawNutrition['natrium']     ?? 0.0).toDouble();
        kalium  = (rawNutrition['kalium']      ?? 0.0).toDouble();
        fosfor  = (rawNutrition['fosfor']      ?? 0.0).toDouble();
        air     = (rawNutrition['air']         ?? 0.0).toDouble();
        serat   = (rawNutrition['serat']       ?? 0.0).toDouble();
        kalsium = (rawNutrition['kalsium']     ?? 0.0).toDouble();
        magnesium = (rawNutrition['magnesium'] ?? 0.0).toDouble();
      }
    }

    // ── Tambahkan gizi dari bahan tambahan ────────────────────────────
    for (final sa in selectedAdditives) {
      final n = sa.totalNutrisi;
      energi  += n['energi']      ?? 0;
      lemak   += n['lemak']       ?? 0;
      karbo   += n['karbohidrat'] ?? 0;
      protein += n['protein']     ?? 0;
      natrium += n['natrium']     ?? 0;
      kalium  += n['kalium']      ?? 0;
      fosfor  += n['fosfor']      ?? 0;
      serat   += n['serat']       ?? 0;
    }

    return FoodLogEntry(
      id: now.microsecondsSinceEpoch.toString(),
      foodId: food.id,
      foodName: food.nama,
      grams: grams,
      loggedAt: now,
      mealType: mealType,
      cookingMethodId: cookingMethod?.id,
      cookingMethodName: cookingMethod?.name,
      additives: selectedAdditives.map((a) => a.toMap()).toList(),
      energi: energi,
      protein: protein,
      lemak: lemak,
      karbohidrat: karbo,
      natrium: natrium,
      kalium: kalium,
      fosfor: fosfor,
      air: air,
      serat: serat,
      indeksGlikemik: food.indeksGlikemik.toDouble(),
      kalsium: kalsium,
      magnesium: magnesium,
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
      'cookingMethodId': cookingMethodId,
      'cookingMethodName': cookingMethodName,
      'additives': additives,
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

    List<Map<String, dynamic>> parseAdditives(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
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
      cookingMethodId: map['cookingMethodId']?.toString(),
      cookingMethodName: map['cookingMethodName']?.toString(),
      additives: parseAdditives(map['additives']),
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
