/// Kebutuhan nutrisi harian pasien (target/batas asupan).
/// Dihitung dari BBI (Berat Badan Ideal) berdasarkan jenis penyakit.
class NutritionNeeds {
  final double energi;      // kkal/hari
  final double protein;     // g/hari
  final double lemak;       // g/hari
  final double karbohidrat; // g/hari
  final double natrium;     // mg/hari (0 = tidak dipantau)
  final double kalium;      // mg/hari (0 = tidak dipantau)
  final double fosfor;      // mg/hari (0 = tidak dipantau)
  final double cairan;      // ml/hari (0 = tidak dipantau)
  final double serat;       // g/hari  (0 = tidak dipantau)

  const NutritionNeeds({
    required this.energi,
    required this.protein,
    required this.lemak,
    required this.karbohidrat,
    this.natrium = 0,
    this.kalium = 0,
    this.fosfor = 0,
    this.cairan = 0,
    this.serat = 0,
  });

  /// Rumus kebutuhan gizi untuk pasien Gagal Ginjal Kronik.
  ///
  /// Energi       = 33 × BBI          (kkal/hari)
  /// Protein      = 1.2 × BBI         (g/hari)
  /// Lemak        = 0.99 × BBI        (g/hari)
  /// Karbohidrat  = 4.82 × BBI        (g/hari)
  /// Natrium      = 6.000             (mg/hari — tetap)
  /// Kalium       = 13 × BBI          (mg/hari)
  /// Fosfor       = 600               (mg/hari — tetap)
  /// Cairan       = 500 + urinOutput  (ml/hari)
  factory NutritionNeeds.kidneyDisease({
    required double bbi,
    required double urinOutput,
  }) {
    return NutritionNeeds(
      energi: 33 * bbi,
      protein: 1.2 * bbi,
      lemak: 0.99 * bbi,
      karbohidrat: 4.82 * bbi,
      natrium: 6000,
      kalium: 13 * bbi,
      fosfor: 600,
      cairan: 500 + urinOutput,
      serat: 0, // tidak dipantau untuk ginjal
    );
  }

  /// Rumus kebutuhan gizi untuk pasien Diabetes Mellitus Tipe 2 (PERKENI).
  ///
  /// Energi basal = 25 kkal × BBI (perempuan) | 30 kkal × BBI (laki-laki)
  /// + Koreksi umur (>40: -5%, >60: -10%, >70: -20% dari basal)
  /// + Koreksi aktivitas (+20% s.d. +50% dari basal)
  /// + Koreksi BB (-20% gemuk | +20% kurus dari basal)
  ///
  /// Protein      = 1.0 × BBI   (g/hari)
  /// Lemak        = 0.89 × BBI  (g/hari)
  /// Karbohidrat  = 4.5 × BBI   (g/hari)
  /// Serat        = 25 g/hari    (tetap)
  factory NutritionNeeds.diabetes({
    required double bbi,
    required String gender,       // 'laki-laki' | 'perempuan'
    required int age,             // usia dalam tahun
    required double koreksiFraksiAktivitas, // dari ActivityLevel.koreksiFraction
    required String bmiCategory,  // dari UserModel.bmiCategory
  }) {
    // Kalori basal berdasarkan gender
    final basal = gender == 'perempuan' ? 25.0 * bbi : 30.0 * bbi;

    // Koreksi umur (dihitung dari basal, bukan kumulatif)
    double koreksiUmur = 0;
    if (age > 70) {
      koreksiUmur = -0.20 * basal;
    } else if (age > 60) {
      koreksiUmur = -0.10 * basal;
    } else if (age > 40) {
      koreksiUmur = -0.05 * basal;
    }

    // Koreksi aktivitas
    final koreksiAktivitas = koreksiFraksiAktivitas * basal;

    // Koreksi berat badan (DM: 3 kategori)
    double koreksiBB = 0;
    if (bmiCategory == 'Gemuk') {
      koreksiBB = -0.20 * basal;  // -20% untuk gemuk
    } else if (bmiCategory == 'Kurus') {
      koreksiBB = 0.20 * basal;   // +20% untuk kurus
    }
    // Normal: koreksiBB = 0 (no change)

    final energiTotal = basal + koreksiUmur + koreksiAktivitas + koreksiBB;

    return NutritionNeeds(
      energi: energiTotal,
      protein: 1.0 * bbi,
      lemak: 0.89 * bbi,
      karbohidrat: 4.5 * bbi,
      serat: 25.0,
      natrium: 0, // tidak dipantau untuk DM
      kalium: 0,
      fosfor: 0,
      cairan: 0,
    );
  }
}

/// Total asupan nutrisi aktual dari makanan yang dikonsumsi hari ini.
class NutritionIntake {
  final double energi;
  final double protein;
  final double lemak;
  final double karbohidrat;
  final double natrium;
  final double kalium;
  final double fosfor;
  final double cairan; // dari kolom 'air' di TKPI
  final double serat;

  const NutritionIntake({
    this.energi = 0,
    this.protein = 0,
    this.lemak = 0,
    this.karbohidrat = 0,
    this.natrium = 0,
    this.kalium = 0,
    this.fosfor = 0,
    this.cairan = 0,
    this.serat = 0,
  });
}
