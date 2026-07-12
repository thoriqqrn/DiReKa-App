// ─────────────────────────────────────────────────────────────────────────────
// CookingMethod — dari koleksi Firestore cooking_methods
// ─────────────────────────────────────────────────────────────────────────────
enum CookingNutritionMode { addition, factor }

class CookingMethod {
  final String id;
  final String name;
  final String category;
  final String description;

  /// 'addition' = tambah gizi dari minyak/bumbu
  /// 'factor'   = kalikan FK konversi mentah-matang
  final CookingNutritionMode mode;

  // ── Mode addition: tambahan gizi per 100g bahan baku ──────────────────
  final double extraCalPer100g;
  final double extraFatPer100g;
  final double extraKarboPer100g;
  final double extraProteinPer100g;
  final double extraNatriumPer100g;

  // ── Mode factor: faktor konversi mentah-matang (FK) ───────────────────
  final double defaultFk;

  const CookingMethod({
    required this.id,
    required this.name,
    required this.category,
    this.description = '',
    this.mode = CookingNutritionMode.factor,
    this.extraCalPer100g = 0,
    this.extraFatPer100g = 0,
    this.extraKarboPer100g = 0,
    this.extraProteinPer100g = 0,
    this.extraNatriumPer100g = 0,
    this.defaultFk = 1.0,
  });

  factory CookingMethod.fromMap(String docId, Map<String, dynamic> m) {
    double td(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }
    return CookingMethod(
      id: docId,
      name: m['name']?.toString() ?? '',
      category: m['category']?.toString() ?? '',
      description: m['description']?.toString() ?? '',
      mode: m['affectsNutritionBy'] == 'addition'
          ? CookingNutritionMode.addition
          : CookingNutritionMode.factor,
      extraCalPer100g: td(m['extraCalPer100g']),
      extraFatPer100g: td(m['extraFatPer100g']),
      extraKarboPer100g: td(m['extraKarboPer100g']),
      extraProteinPer100g: td(m['extraProteinPer100g']),
      extraNatriumPer100g: td(m['extraNatriumPer100g']),
      defaultFk: td(m['defaultFk']) == 0 ? 1.0 : td(m['defaultFk']),
    );
  }

  /// Hitung efek pengolahan pada gizi berdasarkan porsi (gram) bahan baku.
  ///
  /// Mengembalikan Map delta gizi yang harus ditambahkan ke gizi bahan dasar.
  /// Untuk mode 'factor', return Map dengan key 'fk' saja — kalkulasi FK
  /// dilakukan di luar (karena perlu gizi per 100g dari FoodItem).
  Map<String, double> deltaFor(double gramsBase) {
    final ratio = gramsBase / 100.0;
    if (mode == CookingNutritionMode.addition) {
      return {
        'energi': extraCalPer100g * ratio,
        'lemak': extraFatPer100g * ratio,
        'karbohidrat': extraKarboPer100g * ratio,
        'protein': extraProteinPer100g * ratio,
        'natrium': extraNatriumPer100g * ratio,
      };
    } else {
      // Factor mode — kembalikan FK, caller yang hitung
      return {'fk': defaultFk};
    }
  }

  /// Nama pendek untuk ditampilkan di log
  String get shortLabel => name;

  static const CookingMethod mentah = CookingMethod(
    id: 'mentah',
    name: 'Mentah (Tidak Diolah)',
    category: 'Mentah',
    mode: CookingNutritionMode.factor,
    defaultFk: 1.0,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FoodAdditive — dari koleksi Firestore food_additives
// ─────────────────────────────────────────────────────────────────────────────
class FoodAdditive {
  final String id;
  final String name;
  final String category;
  final String unitLabel;   // cth: "Sendok Makan"
  final double gramPerUnit; // gram per 1 unitLabel

  // Nilai gizi per 1 satuan (unitLabel)
  final double calPerUnit;
  final double fatPerUnit;
  final double karboPerUnit;
  final double proteinPerUnit;
  final double natriumPerUnit;
  final double kaliumPerUnit;
  final double fosforPerUnit;
  final double seratPerUnit;

  final String description;

  const FoodAdditive({
    required this.id,
    required this.name,
    required this.category,
    required this.unitLabel,
    this.gramPerUnit = 0,
    this.calPerUnit = 0,
    this.fatPerUnit = 0,
    this.karboPerUnit = 0,
    this.proteinPerUnit = 0,
    this.natriumPerUnit = 0,
    this.kaliumPerUnit = 0,
    this.fosforPerUnit = 0,
    this.seratPerUnit = 0,
    this.description = '',
  });

  factory FoodAdditive.fromMap(String docId, Map<String, dynamic> m) {
    double td(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }
    return FoodAdditive(
      id: docId,
      name: m['name']?.toString() ?? '',
      category: m['category']?.toString() ?? '',
      unitLabel: m['unitLabel']?.toString() ?? 'Satuan',
      gramPerUnit: td(m['gramPerUnit']),
      calPerUnit: td(m['calPerUnit']),
      fatPerUnit: td(m['fatPerUnit']),
      karboPerUnit: td(m['karboPerUnit']),
      proteinPerUnit: td(m['proteinPerUnit']),
      natriumPerUnit: td(m['natriumPerUnit']),
      kaliumPerUnit: td(m['kaliumPerUnit']),
      fosforPerUnit: td(m['fosforPerUnit']),
      seratPerUnit: td(m['seratPerUnit']),
      description: m['description']?.toString() ?? '',
    );
  }

  /// Hitung total gizi untuk [jumlahUnit] satuan.
  Map<String, double> nutrisiUntuk(double jumlahUnit) {
    return {
      'energi': calPerUnit * jumlahUnit,
      'lemak': fatPerUnit * jumlahUnit,
      'karbohidrat': karboPerUnit * jumlahUnit,
      'protein': proteinPerUnit * jumlahUnit,
      'natrium': natriumPerUnit * jumlahUnit,
      'kalium': kaliumPerUnit * jumlahUnit,
      'fosfor': fosforPerUnit * jumlahUnit,
      'serat': seratPerUnit * jumlahUnit,
      'grams': gramPerUnit * jumlahUnit,
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SelectedAdditive — bahan tambahan yang dipilih user + jumlahnya
// ─────────────────────────────────────────────────────────────────────────────
class SelectedAdditive {
  final FoodAdditive additive;
  final double jumlahUnit; // berapa satuan yang dipakai

  const SelectedAdditive({required this.additive, required this.jumlahUnit});

  Map<String, double> get totalNutrisi => additive.nutrisiUntuk(jumlahUnit);

  Map<String, dynamic> toMap() => {
    'additiveId': additive.id,
    'additiveName': additive.name,
    'unitLabel': additive.unitLabel,
    'jumlahUnit': jumlahUnit,
    'gramTotal': additive.gramPerUnit * jumlahUnit,
    'calTotal': additive.calPerUnit * jumlahUnit,
    'fatTotal': additive.fatPerUnit * jumlahUnit,
    'karboTotal': additive.karboPerUnit * jumlahUnit,
    'proteinTotal': additive.proteinPerUnit * jumlahUnit,
    'natriumTotal': additive.natriumPerUnit * jumlahUnit,
  };
}
