// Data METs dikurasi dari tabel referensi klinis DiReKa
// Sumber: Ainsworth BE, et al. 2011 compendium of physical activities.

class MetsActivity {
  final int no;
  final String name;
  final double metsPerHour;
  final double metsPerMin;
  final String category;

  const MetsActivity({
    required this.no,
    required this.name,
    required this.metsPerHour,
    required this.metsPerMin,
    required this.category,
  });
}

// Intensitas IPAQ-SF
// Berat: METs >= 6, Sedang: METs 3-5.9, Ringan: METs < 3
// Skor IPAQ = hari x menit x METs/menit
// Kategori: Rendah < 600, Sedang 600-2999, Tinggi >= 3000 MET-min/minggu

const List<MetsActivity> kMetsActivities = [
  // ---- Olahraga ----
  MetsActivity(no: 1,  name: 'Badminton, biasa',                          metsPerHour: 4.5,  metsPerMin: 0.08, category: 'Olahraga'),
  MetsActivity(no: 2,  name: 'Berenang, santai',                          metsPerHour: 6.0,  metsPerMin: 0.10, category: 'Olahraga'),
  MetsActivity(no: 3,  name: 'Berenang, gaya bebas, pelan',               metsPerHour: 7.0,  metsPerMin: 0.12, category: 'Olahraga'),
  MetsActivity(no: 4,  name: 'Berlari kurang dari 10 menit',              metsPerHour: 6.0,  metsPerMin: 0.10, category: 'Olahraga'),
  MetsActivity(no: 5,  name: 'Bersepeda, umum',                           metsPerHour: 8.0,  metsPerMin: 0.13, category: 'Olahraga'),
  MetsActivity(no: 6,  name: 'Bola voli',                                 metsPerHour: 4.0,  metsPerMin: 0.07, category: 'Olahraga'),
  MetsActivity(no: 7,  name: 'Golf',                                      metsPerHour: 4.5,  metsPerMin: 0.08, category: 'Olahraga'),
  MetsActivity(no: 8,  name: 'Jogging',                                   metsPerHour: 7.0,  metsPerMin: 0.12, category: 'Olahraga'),
  MetsActivity(no: 9,  name: 'Lari, naik turun tangga',                   metsPerHour: 15.0, metsPerMin: 0.25, category: 'Olahraga'),
  MetsActivity(no: 10, name: 'Senam aerobik',                             metsPerHour: 6.5,  metsPerMin: 0.11, category: 'Olahraga'),

  // ---- Berjalan ----
  MetsActivity(no: 11, name: 'Berjalan, santai, 3 km/jam',                metsPerHour: 2.0,  metsPerMin: 0.03, category: 'Berjalan'),
  MetsActivity(no: 12, name: 'Berjalan, santai, 4 km/jam',                metsPerHour: 3.3,  metsPerMin: 0.06, category: 'Berjalan'),
  MetsActivity(no: 13, name: 'Berjalan, santai, 5 km/jam',                metsPerHour: 3.8,  metsPerMin: 0.06, category: 'Berjalan'),
  MetsActivity(no: 14, name: 'Berjalan, 8 km/jam',                        metsPerHour: 8.0,  metsPerMin: 0.13, category: 'Berjalan'),
  MetsActivity(no: 15, name: 'Berjalan, di luar atau menuju rumah',       metsPerHour: 2.5,  metsPerMin: 0.04, category: 'Berjalan'),
  MetsActivity(no: 16, name: 'Berjalan, sekitar rumah',                   metsPerHour: 2.0,  metsPerMin: 0.03, category: 'Berjalan'),
  MetsActivity(no: 17, name: 'Berjalan, pulang kerja',                    metsPerHour: 3.0,  metsPerMin: 0.05, category: 'Berjalan'),
  MetsActivity(no: 18, name: 'Berjalan atau berlari, bermain dengan anak', metsPerHour: 4.0,  metsPerMin: 0.07, category: 'Berjalan'),

  // ---- Pekerjaan Rumah Tangga ----
  MetsActivity(no: 19, name: 'Berkebun, biasa',                           metsPerHour: 4.0,  metsPerMin: 0.07, category: 'Pekerjaan Rumah Tangga'),
  MetsActivity(no: 20, name: 'Bersih-bersih (cuci mobil, jendela, garasi)', metsPerHour: 3.0, metsPerMin: 0.05, category: 'Pekerjaan Rumah Tangga'),
  MetsActivity(no: 21, name: 'Berdiri, mencuci pakaian, mengeringkan pakaian', metsPerHour: 2.0, metsPerMin: 0.03, category: 'Pekerjaan Rumah Tangga'),
  MetsActivity(no: 22, name: 'Mencuci piring, berdiri',                   metsPerHour: 2.3,  metsPerMin: 0.04, category: 'Pekerjaan Rumah Tangga'),
  MetsActivity(no: 23, name: 'Menyapu lantai',                            metsPerHour: 3.3,  metsPerMin: 0.06, category: 'Pekerjaan Rumah Tangga'),
  MetsActivity(no: 24, name: 'Menyetrika',                                metsPerHour: 2.3,  metsPerMin: 0.04, category: 'Pekerjaan Rumah Tangga'),
  MetsActivity(no: 25, name: 'Menyirami tanaman',                         metsPerHour: 2.5,  metsPerMin: 0.04, category: 'Pekerjaan Rumah Tangga'),
  MetsActivity(no: 26, name: 'Merapikan tempat tidur',                    metsPerHour: 2.5,  metsPerMin: 0.04, category: 'Pekerjaan Rumah Tangga'),

  // ---- Pertanian dan Pekerjaan ----
  MetsActivity(no: 27, name: 'Bertani, mengangkut air',                   metsPerHour: 4.5,  metsPerMin: 0.08, category: 'Pertanian dan Pekerjaan'),
  MetsActivity(no: 28, name: 'Bertani, mencangkul, membersihkan ladang',  metsPerHour: 8.0,  metsPerMin: 0.13, category: 'Pertanian dan Pekerjaan'),

  // ---- Aktivitas Ringan ----
  MetsActivity(no: 29, name: 'Berdiri, berbicara di tempat kerja',        metsPerHour: 2.3,  metsPerMin: 0.04, category: 'Aktivitas Ringan'),
  MetsActivity(no: 30, name: 'Berdiri, berbicara dengan handphone',       metsPerHour: 1.5,  metsPerMin: 0.03, category: 'Aktivitas Ringan'),
  MetsActivity(no: 31, name: 'Duduk, di kantor, mengerjakan tugas',       metsPerHour: 2.5,  metsPerMin: 0.04, category: 'Aktivitas Ringan'),
  MetsActivity(no: 32, name: 'Memancing',                                 metsPerHour: 3.0,  metsPerMin: 0.05, category: 'Aktivitas Ringan'),

  // ---- Aktivitas Sangat Ringan ----
  MetsActivity(no: 33, name: 'Berbaring',                                 metsPerHour: 1.0,  metsPerMin: 0.02, category: 'Aktivitas Sangat Ringan'),
  MetsActivity(no: 34, name: 'Berdiri',                                   metsPerHour: 1.2,  metsPerMin: 0.02, category: 'Aktivitas Sangat Ringan'),
  MetsActivity(no: 35, name: 'Duduk, santai',                             metsPerHour: 1.0,  metsPerMin: 0.02, category: 'Aktivitas Sangat Ringan'),
  MetsActivity(no: 36, name: 'Duduk, di kelas, belajar (membaca, menulis)', metsPerHour: 1.8, metsPerMin: 0.03, category: 'Aktivitas Sangat Ringan'),
  MetsActivity(no: 37, name: 'Duduk, membaca koran',                      metsPerHour: 1.3,  metsPerMin: 0.02, category: 'Aktivitas Sangat Ringan'),
  MetsActivity(no: 38, name: 'Duduk, di tempat kerja',                    metsPerHour: 1.5,  metsPerMin: 0.03, category: 'Aktivitas Sangat Ringan'),
  MetsActivity(no: 39, name: 'Gosok gigi, cuci tangan, mandi',            metsPerHour: 2.0,  metsPerMin: 0.03, category: 'Aktivitas Sangat Ringan'),
  MetsActivity(no: 40, name: 'Makan, duduk',                              metsPerHour: 1.5,  metsPerMin: 0.03, category: 'Aktivitas Sangat Ringan'),
  MetsActivity(no: 41, name: 'Mandi',                                     metsPerHour: 1.5,  metsPerMin: 0.03, category: 'Aktivitas Sangat Ringan'),
  MetsActivity(no: 42, name: 'Tidur',                                     metsPerHour: 0.9,  metsPerMin: 0.02, category: 'Aktivitas Sangat Ringan'),
];

// Kategori intensitas berdasarkan METs/jam
// Berat: >= 6, Sedang: 3 - <6, Ringan: <3
enum IpaqIntensity { berat, sedang, ringan }

extension IpaqIntensityExt on IpaqIntensity {
  String get label {
    switch (this) {
      case IpaqIntensity.berat:
        return 'Berat';
      case IpaqIntensity.sedang:
        return 'Sedang';
      case IpaqIntensity.ringan:
        return 'Ringan';
    }
  }

  double get metsMultiplier {
    switch (this) {
      case IpaqIntensity.berat:
        return 8.0;
      case IpaqIntensity.sedang:
        return 4.0;
      case IpaqIntensity.ringan:
        return 3.3;
    }
  }
}

// Kategori total skor METs mingguan (IPAQ scoring)
enum PhysicalActivityCategory { rendah, sedang, tinggi }

extension PhysicalActivityCategoryExt on PhysicalActivityCategory {
  String get label {
    switch (this) {
      case PhysicalActivityCategory.rendah:
        return 'Sedenter (Rendah)';
      case PhysicalActivityCategory.sedang:
        return 'Cukup Aktif (Sedang)';
      case PhysicalActivityCategory.tinggi:
        return 'Sangat Aktif (Tinggi)';
    }
  }

  String get saranDM {
    switch (this) {
      case PhysicalActivityCategory.rendah:
        return 'Aktivitas fisik Anda masih sangat kurang. Untuk manajemen DM, '
            'dianjurkan minimal 150 menit aktivitas aerobik sedang per minggu. '
            'Mulailah dengan jalan kaki 10-15 menit setelah makan, lakukan '
            'secara bertahap dan konsisten setiap hari.';
      case PhysicalActivityCategory.sedang:
        return 'Aktivitas fisik Anda cukup baik. Pertahankan minimal 150 menit '
            'aktivitas sedang per minggu untuk kontrol gula darah optimal. '
            'Tambahkan latihan kekuatan otot 2-3 kali seminggu agar '
            'sensitivitas insulin semakin meningkat.';
      case PhysicalActivityCategory.tinggi:
        return 'Aktivitas fisik Anda sangat aktif. Pertahankan pola ini karena '
            'sangat membantu kontrol gula darah, penurunan HbA1c, dan '
            'menurunkan risiko komplikasi DM. Pantau gula darah sebelum dan '
            'sesudah olahraga untuk mencegah hipoglikemia.';
    }
  }

  String get emoji {
    switch (this) {
      case PhysicalActivityCategory.rendah:
        return 'Kurang';
      case PhysicalActivityCategory.sedang:
        return 'Cukup';
      case PhysicalActivityCategory.tinggi:
        return 'Bagus';
    }
  }
}

PhysicalActivityCategory categorizeWeeklyMets(double totalMetsMin) {
  if (totalMetsMin < 600) return PhysicalActivityCategory.rendah;
  if (totalMetsMin < 3000) return PhysicalActivityCategory.sedang;
  return PhysicalActivityCategory.tinggi;
}

/// Cari MetsActivity dari nama (exact match dulu, lalu contains)
MetsActivity? findMetsActivity(String name) {
  try {
    return kMetsActivities.firstWhere(
      (a) => a.name.toLowerCase() == name.toLowerCase(),
    );
  } catch (_) {}
  try {
    return kMetsActivities.firstWhere(
      (a) => a.name.toLowerCase().contains(name.toLowerCase()),
    );
  } catch (_) {}
  return null;
}

/// Semua kategori unik
List<String> get kMetsCategories =>
    kMetsActivities.map((a) => a.category).toSet().toList()..sort();

/// Filter berdasarkan kategori
List<MetsActivity> getMetsActivitiesByCategory(String category) =>
    kMetsActivities.where((a) => a.category == category).toList();
