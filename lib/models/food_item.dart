/// Ukuran satu takaran saji (mis. centong kecil / sedang / besar).
class TakaranSaji {
  final String ukuran; // "kecil" | "sedang" | "besar"
  final String label; // "Centong Kecil" dsb.
  final double gram; // gram per satu takaran

  const TakaranSaji({
    required this.ukuran,
    required this.label,
    required this.gram,
  });

  factory TakaranSaji.fromJson(Map<String, dynamic> json) => TakaranSaji(
    ukuran: json['ukuran'] as String,
    label: json['label'] as String,
    gram: (json['gram'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() {
    return {'ukuran': ukuran, 'label': label, 'gram': gram};
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Data bahan makanan dari database TKPI
/// (Tabel Komposisi Pangan Indonesia) — semua nilai per 100 gram BDD.
class FoodItem {
  final String id;
  final String nama;
  final String kategori;
  final String urt;
  final double indeksGlikemik;
  final double energi; // kkal
  final double protein; // g
  final double lemak; // g
  final double karbohidrat; // g
  final double natrium; // mg
  final double kalium; // mg
  final double fosfor; // mg
  final double air; // ml
  final List<TakaranSaji> takaranSaji; // ukuran saji (opsional)
  final String emoji; // placeholder sampai asset designer tersedia
  final String satuanNama; // nama satuan: Centong, Potong, Butir, Sendok, dll
  final double serat; // g per 100g
  final double kalsium; // mg per 100g
  final double magnesium; // mg per 100g

  const FoodItem({
    required this.id,
    required this.nama,
    required this.kategori,
    this.urt = '',
    this.indeksGlikemik = 0.0,
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
    this.kalsium = 0.0,
    this.magnesium = 0.0,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    return FoodItem(
      id: json['id'] as String,
      nama: json['nama'] as String,
      kategori: (json['kategori'] as String).trim(),
      urt: json['urt'] as String? ?? '',
      indeksGlikemik: toDouble(json['indeksGlikemik']),
      energi: toDouble(json['energi']),
      protein: toDouble(json['protein']),
      lemak: toDouble(json['lemak']),
      karbohidrat: toDouble(json['karbohidrat']),
      natrium: toDouble(json['natrium']),
      kalium: toDouble(json['kalium']),
      fosfor: toDouble(json['fosfor']),
      air: toDouble(json['air']),
      serat: toDouble(json['serat']),
      kalsium: toDouble(json['kalsium']),
      magnesium: toDouble(json['magnesium']),
      takaranSaji: (json['takaranSaji'] as List<dynamic>? ?? [])
          .map((e) => TakaranSaji.fromJson(e as Map<String, dynamic>))
          .toList(),
      emoji: json['emoji'] as String? ?? '🍽️',
      satuanNama: json['satuanNama'] as String? ?? 'Takaran',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama': nama,
      'kategori': kategori,
      'urt': urt,
      'indeksGlikemik': indeksGlikemik,
      'emoji': emoji,
      'satuanNama': satuanNama,
      'takaranSaji': takaranSaji.map((e) => e.toJson()).toList(),
      'energi': energi,
      'protein': protein,
      'lemak': lemak,
      'karbohidrat': karbohidrat,
      'natrium': natrium,
      'kalium': kalium,
      'fosfor': fosfor,
      'air': air,
      'serat': serat,
      'kalsium': kalsium,
      'magnesium': magnesium,
    };
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
      'kalsium': kalsium * r,
      'magnesium': magnesium * r,
    };
  }
}
