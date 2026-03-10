/// Ukuran satu takaran saji (mis. centong kecil / sedang / besar).
class TakaranSaji {
  final String ukuran; // "kecil" | "sedang" | "besar"
  final String label;  // "Centong Kecil" dsb.
  final double gram;   // gram per satu takaran

  const TakaranSaji(
      {required this.ukuran, required this.label, required this.gram});

  factory TakaranSaji.fromJson(Map<String, dynamic> json) => TakaranSaji(
        ukuran: json['ukuran'] as String,
        label: json['label'] as String,
        gram: (json['gram'] as num).toDouble(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

/// Data bahan makanan dari database TKPI
/// (Tabel Komposisi Pangan Indonesia) — semua nilai per 100 gram BDD.
class FoodItem {
  final String id;
  final String nama;
  final String kategori;
  final double energi;      // kkal
  final double protein;     // g
  final double lemak;       // g
  final double karbohidrat; // g
  final double natrium;     // mg
  final double kalium;      // mg
  final double fosfor;      // mg
  final double air;         // ml
  final List<TakaranSaji> takaranSaji; // ukuran saji (opsional)
  final String emoji;       // placeholder sampai asset designer tersedia
  final String satuanNama;  // nama satuan: Centong, Potong, Butir, Sendok, dll
  final double serat;       // g per 100g

  const FoodItem({
    required this.id,
    required this.nama,
    required this.kategori,
    required this.energi,
    required this.protein,
    required this.lemak,
    required this.karbohidrat,
    required this.natrium,
    required this.kalium,
    required this.fosfor,
    required this.air,
    this.takaranSaji = const [],
    this.emoji = '🍽️',
    this.satuanNama = 'Takaran',
    this.serat = 0.0,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'] as String,
      nama: json['nama'] as String,
      kategori: json['kategori'] as String,
      energi: (json['energi'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      lemak: (json['lemak'] as num).toDouble(),
      karbohidrat: (json['karbohidrat'] as num).toDouble(),
      natrium: (json['natrium'] as num).toDouble(),
      kalium: (json['kalium'] as num).toDouble(),
      fosfor: (json['fosfor'] as num).toDouble(),
      air: (json['air'] as num).toDouble(),
      serat: (json['serat'] as num? ?? 0).toDouble(),
      takaranSaji: (json['takaranSaji'] as List<dynamic>? ?? [])
          .map((e) => TakaranSaji.fromJson(e as Map<String, dynamic>))
          .toList(),
      emoji: json['emoji'] as String? ?? '🍽️',
      satuanNama: json['satuanNama'] as String? ?? 'Takaran',
    );
  }

  /// Hitung kandungan nutrisi untuk [grams] gram bahan ini.
  /// Rumus: (grams / 100) × nilai_per_100g
  Map<String, double> calcFor(double grams) {
    final r = grams / 100.0;
    return {
      'energi': energi * r,
      'protein': protein * r,
      'lemak': lemak * r,
      'karbohidrat': karbohidrat * r,
      'natrium': natrium * r,
      'kalium': kalium * r,
      'fosfor': fosfor * r,
      'air': air * r,
      'serat': serat * r,
    };
  }
}
