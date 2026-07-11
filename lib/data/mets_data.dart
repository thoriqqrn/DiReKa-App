// METs reference data from: Ainsworth BE, et al. 2011 compendium of physical activities.
// Medicine & Science in Sports & Exercise. 2011;43:1575

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
// Berat: METs >= 6, Sedang: METs 3-5.9, Ringan/Jalan: METs < 3
// Skor IPAQ = hari × menit × MET_value_per_menit
// Kategori: Rendah < 600, Sedang 600-2999, Tinggi >= 3000 MET-min/week

const List<MetsActivity> kMetsActivities = [
  // ---- Latihan ditempat ----
  MetsActivity(no: 1, name: 'Angkat berat / Body building, berat', metsPerHour: 6, metsPerMin: 0.10, category: 'Latihan ditempat'),
  MetsActivity(no: 2, name: 'Angkat berat / Body building, ringan/sedang', metsPerHour: 3, metsPerMin: 0.05, category: 'Latihan ditempat'),
  MetsActivity(no: 134, name: 'Bersepeda statis, 100 watts, ringan', metsPerHour: 5.5, metsPerMin: 0.09, category: 'Latihan ditempat'),
  MetsActivity(no: 135, name: 'Bersepeda statis, 150 watts, sedang', metsPerHour: 7, metsPerMin: 0.12, category: 'Latihan ditempat'),
  MetsActivity(no: 136, name: 'Bersepeda statis, 200 watts, berat', metsPerHour: 10, metsPerMin: 0.17, category: 'Latihan ditempat'),
  MetsActivity(no: 139, name: 'Bersepeda statis, spinning bike', metsPerHour: 7, metsPerMin: 0.12, category: 'Latihan ditempat'),
  MetsActivity(no: 224, name: 'Health club exercise / Senam kebugaran', metsPerHour: 5.5, metsPerMin: 0.09, category: 'Latihan ditempat'),
  MetsActivity(no: 562, name: 'Water aerobik / Akuarobik', metsPerHour: 4, metsPerMin: 0.07, category: 'Latihan ditempat'),

  // ---- Sepeda / Bersepeda ----
  MetsActivity(no: 133, name: 'Bersepeda roda 1', metsPerHour: 5, metsPerMin: 0.08, category: 'Sepeda'),
  MetsActivity(no: 140, name: 'Bersepeda, <16 km/jam, santai / berangkat kerja', metsPerHour: 4, metsPerMin: 0.07, category: 'Sepeda'),
  MetsActivity(no: 141, name: 'Bersepeda, 16-19 km/jam, latihan ringan', metsPerHour: 6, metsPerMin: 0.10, category: 'Sepeda'),
  MetsActivity(no: 142, name: 'Bersepeda, 19-22 km/jam, latihan sedang', metsPerHour: 8, metsPerMin: 0.13, category: 'Sepeda'),
  MetsActivity(no: 143, name: 'Bersepeda, 22-25 km/jam, latihan berat', metsPerHour: 10, metsPerMin: 0.17, category: 'Sepeda'),
  MetsActivity(no: 144, name: 'Bersepeda, 25-30 km/jam, sangat cepat', metsPerHour: 12, metsPerMin: 0.20, category: 'Sepeda'),
  MetsActivity(no: 145, name: 'Bersepeda BMX / sepeda gunung', metsPerHour: 8.5, metsPerMin: 0.14, category: 'Sepeda'),
  MetsActivity(no: 146, name: 'Bersepeda umum', metsPerHour: 8, metsPerMin: 0.13, category: 'Sepeda'),
  MetsActivity(no: 147, name: 'Bersepeda, >30 km/jam, balapan', metsPerHour: 16, metsPerMin: 0.27, category: 'Sepeda'),

  // ---- Lari ----
  MetsActivity(no: 121, name: 'Berlari / Jogging', metsPerHour: 8, metsPerMin: 0.13, category: 'Lari'),
  MetsActivity(no: 122, name: 'Berlari <10 menit, sisanya berjalan', metsPerHour: 6, metsPerMin: 0.10, category: 'Lari'),
  MetsActivity(no: 563, name: 'Water jogging', metsPerHour: 8, metsPerMin: 0.13, category: 'Lari'),

  // ---- Berjalan ----
  MetsActivity(no: 79, name: 'Berjalan, <3 km/jam, sangat pelan', metsPerHour: 2, metsPerMin: 0.03, category: 'Berjalan'),
  MetsActivity(no: 80, name: 'Berjalan, 3 km/jam, pelan', metsPerHour: 2.5, metsPerMin: 0.04, category: 'Berjalan'),
  MetsActivity(no: 73, name: 'Berjalan, 4 km/jam, di tanah rata', metsPerHour: 3, metsPerMin: 0.05, category: 'Berjalan'),
  MetsActivity(no: 81, name: 'Berjalan, 4.5 km/jam, permukaan datar', metsPerHour: 3.3, metsPerMin: 0.06, category: 'Berjalan'),
  MetsActivity(no: 83, name: 'Berjalan, 5 km/jam, olahraga', metsPerHour: 3.8, metsPerMin: 0.06, category: 'Berjalan'),
  MetsActivity(no: 84, name: 'Berjalan, 6 km/jam, langkah cepat', metsPerHour: 5, metsPerMin: 0.08, category: 'Berjalan'),
  MetsActivity(no: 85, name: 'Berjalan, 7 km/jam, langkah sangat cepat', metsPerHour: 6.3, metsPerMin: 0.11, category: 'Berjalan'),
  MetsActivity(no: 86, name: 'Berjalan, 8 km/jam', metsPerHour: 8, metsPerMin: 0.13, category: 'Berjalan'),
  MetsActivity(no: 87, name: 'Berjalan, berangkat kerja atau sekolah', metsPerHour: 4, metsPerMin: 0.07, category: 'Berjalan'),
  MetsActivity(no: 5, name: 'Backpacking / Hiking berbeban', metsPerHour: 7, metsPerMin: 0.12, category: 'Berjalan'),
  MetsActivity(no: 12, name: 'Baris-berbaris, cepat, ala militer', metsPerHour: 6.5, metsPerMin: 0.11, category: 'Berjalan'),
  MetsActivity(no: 75, name: 'Berjalan dengan hewan peliharaan', metsPerHour: 3, metsPerMin: 0.05, category: 'Berjalan'),
  MetsActivity(no: 225, name: 'Hiking, lintas negara', metsPerHour: 6, metsPerMin: 0.10, category: 'Berjalan'),
  MetsActivity(no: 108, name: 'Berjalan, track berumput', metsPerHour: 5, metsPerMin: 0.08, category: 'Berjalan'),

  // ---- Olahraga ----
  MetsActivity(no: 6, name: 'Badminton, biasa', metsPerHour: 4.5, metsPerMin: 0.08, category: 'Olahraga'),
  MetsActivity(no: 7, name: 'Badminton, kompetisi', metsPerHour: 7, metsPerMin: 0.12, category: 'Olahraga'),
  MetsActivity(no: 13, name: 'Baseball', metsPerHour: 2.5, metsPerMin: 0.04, category: 'Olahraga'),
  MetsActivity(no: 14, name: 'Basket ball, pertandingan', metsPerHour: 8, metsPerMin: 0.13, category: 'Olahraga'),
  MetsActivity(no: 15, name: 'Basket ball, biasa', metsPerHour: 6, metsPerMin: 0.10, category: 'Olahraga'),
  MetsActivity(no: 17, name: 'Basket ball, shooting bola', metsPerHour: 4.5, metsPerMin: 0.08, category: 'Olahraga'),
  MetsActivity(no: 163, name: 'Biliards', metsPerHour: 2.5, metsPerMin: 0.04, category: 'Olahraga'),
  MetsActivity(no: 164, name: 'Bola tangan', metsPerHour: 12, metsPerMin: 0.20, category: 'Olahraga'),
  MetsActivity(no: 165, name: 'Bola tangan, team', metsPerHour: 8, metsPerMin: 0.13, category: 'Olahraga'),
  MetsActivity(no: 166, name: 'Bola tenis', metsPerHour: 7, metsPerMin: 0.12, category: 'Olahraga'),
  MetsActivity(no: 167, name: 'Bola tenis, ganda', metsPerHour: 6, metsPerMin: 0.10, category: 'Olahraga'),
  MetsActivity(no: 168, name: 'Bola tenis, single', metsPerHour: 8, metsPerMin: 0.13, category: 'Olahraga'),
  MetsActivity(no: 169, name: 'Bola voli', metsPerHour: 4, metsPerMin: 0.07, category: 'Olahraga'),
  MetsActivity(no: 171, name: 'Bola voli, kompetisi', metsPerHour: 8, metsPerMin: 0.13, category: 'Olahraga'),
  MetsActivity(no: 172, name: 'Bolling', metsPerHour: 3, metsPerMin: 0.05, category: 'Olahraga'),
  MetsActivity(no: 173, name: 'Boxing, duel', metsPerHour: 9, metsPerMin: 0.15, category: 'Olahraga'),
  MetsActivity(no: 209, name: 'Fencing / Anggar', metsPerHour: 6, metsPerMin: 0.10, category: 'Olahraga'),
  MetsActivity(no: 210, name: 'Frisbee', metsPerHour: 3, metsPerMin: 0.05, category: 'Olahraga'),
  MetsActivity(no: 211, name: 'Frisbee, kompetisi', metsPerHour: 8, metsPerMin: 0.13, category: 'Olahraga'),
  MetsActivity(no: 213, name: 'Golf', metsPerHour: 4.5, metsPerMin: 0.08, category: 'Olahraga'),
  MetsActivity(no: 214, name: 'Golf, berjalan', metsPerHour: 4.5, metsPerMin: 0.08, category: 'Olahraga'),
  MetsActivity(no: 219, name: 'Gulat', metsPerHour: 6, metsPerMin: 0.10, category: 'Olahraga'),
  MetsActivity(no: 220, name: 'Gymnastics / Senam', metsPerHour: 4, metsPerMin: 0.07, category: 'Olahraga'),
  MetsActivity(no: 117, name: 'Berkuda', metsPerHour: 4, metsPerMin: 0.07, category: 'Olahraga'),
  MetsActivity(no: 118, name: 'Berkuda, cepat', metsPerHour: 6.5, metsPerMin: 0.11, category: 'Olahraga'),

  // ---- Aktifitas air ----
  MetsActivity(no: 3, name: 'Arum jeram', metsPerHour: 5, metsPerMin: 0.08, category: 'Aktifitas air'),
  MetsActivity(no: 58, name: 'Berenang gaya dada', metsPerHour: 10, metsPerMin: 0.17, category: 'Aktifitas air'),
  MetsActivity(no: 59, name: 'Berenang gaya kupu-kupu', metsPerHour: 11, metsPerMin: 0.18, category: 'Aktifitas air'),
  MetsActivity(no: 60, name: 'Berenang gaya punggung', metsPerHour: 7, metsPerMin: 0.12, category: 'Aktifitas air'),
  MetsActivity(no: 61, name: 'Berenang, cepat, 68 meter/min', metsPerHour: 11, metsPerMin: 0.18, category: 'Aktifitas air'),
  MetsActivity(no: 62, name: 'Berenang, di laut/danau/sungai', metsPerHour: 6, metsPerMin: 0.10, category: 'Aktifitas air'),
  MetsActivity(no: 63, name: 'Berenang gaya bebas, cepat', metsPerHour: 10, metsPerMin: 0.17, category: 'Aktifitas air'),
  MetsActivity(no: 64, name: 'Berenang gaya bebas, pelan', metsPerHour: 7, metsPerMin: 0.12, category: 'Aktifitas air'),
  MetsActivity(no: 69, name: 'Berenang, santai', metsPerHour: 6, metsPerMin: 0.10, category: 'Aktifitas air'),
  MetsActivity(no: 66, name: 'Berenang, menginjak air', metsPerHour: 4, metsPerMin: 0.07, category: 'Aktifitas air'),

  // ---- Dancing ----
  MetsActivity(no: 8, name: 'Ballet / Modern balet, twist, jazz, tap', metsPerHour: 4.8, metsPerMin: 0.08, category: 'Dancing'),
  MetsActivity(no: 9, name: 'Ballroom, cepat (disco, folk, line dancing)', metsPerHour: 4.5, metsPerMin: 0.08, category: 'Dancing'),
  MetsActivity(no: 10, name: 'Ballroom, menari dengan cepat', metsPerHour: 5.5, metsPerMin: 0.09, category: 'Dancing'),
  MetsActivity(no: 11, name: 'Ballroom, pelan (waltz, foxtrot, tango)', metsPerHour: 3, metsPerMin: 0.05, category: 'Dancing'),

  // ---- Pekerjaan Rumah Tangga ----
  MetsActivity(no: 21, name: 'Belanja barang, berdiri atau jalan', metsPerHour: 2.3, metsPerMin: 0.04, category: 'Pekerjaan Rumah tangga'),
  MetsActivity(no: 22, name: 'Belanja makanan, berdiri atau jalan', metsPerHour: 2.3, metsPerMin: 0.04, category: 'Pekerjaan Rumah tangga'),
  MetsActivity(no: 38, name: 'Berdiri, bermain dengan anak, ringan', metsPerHour: 2.8, metsPerMin: 0.05, category: 'Pekerjaan Rumah tangga'),
  MetsActivity(no: 48, name: 'Berdiri, mencuci/mengeringkan pakaian', metsPerHour: 2, metsPerMin: 0.03, category: 'Pekerjaan Rumah tangga'),
  MetsActivity(no: 50, name: 'Berdiri, mengepack box / angkat barang', metsPerHour: 3.5, metsPerMin: 0.06, category: 'Pekerjaan Rumah tangga'),
  MetsActivity(no: 148, name: 'Bersih-bersih (cuci mobil, jendela, garasi)', metsPerHour: 3, metsPerMin: 0.05, category: 'Pekerjaan Rumah tangga'),
  MetsActivity(no: 110, name: 'Berjalan/berlari, bermain dengan anak-anak, berat', metsPerHour: 5, metsPerMin: 0.08, category: 'Pekerjaan Rumah tangga'),
  MetsActivity(no: 111, name: 'Berjalan/berlari, bermain dengan anak-anak, sedang', metsPerHour: 4, metsPerMin: 0.07, category: 'Pekerjaan Rumah tangga'),
  MetsActivity(no: 90, name: 'Berjalan, melipat/menjemur pakaian', metsPerHour: 2.3, metsPerMin: 0.04, category: 'Pekerjaan Rumah tangga'),

  // ---- Halaman dan Kebun ----
  MetsActivity(no: 55, name: 'Berdiri/berjalan, memetik bunga atau sayur', metsPerHour: 3, metsPerMin: 0.05, category: 'Halaman dan Kebun'),
  MetsActivity(no: 115, name: 'Berkebun', metsPerHour: 6, metsPerMin: 0.10, category: 'Halaman dan Kebun'),
  MetsActivity(no: 116, name: 'Berkebun, biasa', metsPerHour: 4, metsPerMin: 0.07, category: 'Halaman dan Kebun'),
  MetsActivity(no: 98, name: 'Mengumpulkan perkakas kebun', metsPerHour: 3, metsPerMin: 0.05, category: 'Halaman dan Kebun'),

  // ---- Pekerjaan / Pertanian ----
  MetsActivity(no: 19, name: 'Bekerja di pabrik baja', metsPerHour: 8, metsPerMin: 0.13, category: 'Pekerjaan'),
  MetsActivity(no: 149, name: 'Bertani, merawat ternak (grooming, memandikan)', metsPerHour: 6, metsPerMin: 0.10, category: 'Pekerjaan'),
  MetsActivity(no: 152, name: 'Bertani, membersihkan kandang', metsPerHour: 8, metsPerMin: 0.13, category: 'Pekerjaan'),
  MetsActivity(no: 155, name: 'Bertani, mencangkul / membersihkan ladang, berat', metsPerHour: 8, metsPerMin: 0.13, category: 'Pekerjaan'),
  MetsActivity(no: 159, name: 'Bertani, menggembala ternak, berjalan', metsPerHour: 3.5, metsPerMin: 0.06, category: 'Pekerjaan'),
  MetsActivity(no: 162, name: 'Bertani, menyekop biji-bijian', metsPerHour: 5.5, metsPerMin: 0.09, category: 'Pekerjaan'),
  MetsActivity(no: 49, name: 'Berdiri, mengecat / memecah batu / angkat barang >20 kg', metsPerHour: 4, metsPerMin: 0.07, category: 'Pekerjaan'),
  MetsActivity(no: 52, name: 'Berdiri, merakit sesuatu, angkat barang 20 kg', metsPerHour: 3.5, metsPerMin: 0.06, category: 'Pekerjaan'),

  // ---- Aktifitas sangat Ringan / Duduk ----
  MetsActivity(no: 192, name: 'Duduk, santai', metsPerHour: 1, metsPerMin: 0.02, category: 'Aktifitas sangat Ringan'),
  MetsActivity(no: 202, name: 'Duduk, menonton televisi / gadget', metsPerHour: 1, metsPerMin: 0.02, category: 'Aktifitas sangat Ringan'),
  MetsActivity(no: 187, name: 'Duduk, belajar / membaca / menulis', metsPerHour: 1.8, metsPerMin: 0.03, category: 'Aktifitas sangat Ringan'),
  MetsActivity(no: 35, name: 'Berdiri', metsPerHour: 1.2, metsPerMin: 0.02, category: 'Aktifitas sangat Ringan'),
  MetsActivity(no: 23, name: 'Berbaring, membaca', metsPerHour: 1, metsPerMin: 0.02, category: 'Aktifitas sangat Ringan'),
  MetsActivity(no: 27, name: 'Berbaring, menonton TV/gadget', metsPerHour: 1, metsPerMin: 0.02, category: 'Aktifitas sangat Ringan'),

  // ---- Lain-lain ----
  MetsActivity(no: 57, name: 'Berdoa dengan menari atau lari', metsPerHour: 5, metsPerMin: 0.08, category: 'Keagamaan'),
  MetsActivity(no: 176, name: 'Camping, berdiri/duduk/jalan', metsPerHour: 2.5, metsPerMin: 0.04, category: 'lain-lain'),
  MetsActivity(no: 4, name: 'Mengendarai motor/mobil', metsPerHour: 2, metsPerMin: 0.03, category: 'Transportasi'),
  MetsActivity(no: 218, name: 'Grooming (gosok gigi, mandi, dll)', metsPerHour: 2, metsPerMin: 0.03, category: 'Merawat diri'),
];

// Kategori aktivitas berdasarkan METs/jam
// Berat: >= 6 METs/jam
// Sedang: 3 - <6 METs/jam
// Ringan: < 3 METs/jam
enum IpaqIntensity { berat, sedang, ringan }

extension IpaqIntensityExt on IpaqIntensity {
  String get label {
    switch (this) {
      case IpaqIntensity.berat:
        return 'Berat';
      case IpaqIntensity.sedang:
        return 'Sedang';
      case IpaqIntensity.ringan:
        return 'Ringan/Jalan';
    }
  }

  double get metsMultiplier {
    // Nilai METs standar IPAQ per menit untuk masing-masing intensitas
    switch (this) {
      case IpaqIntensity.berat:
        return 8.0; // IPAQ standar: vigorous = 8 MET
      case IpaqIntensity.sedang:
        return 4.0; // IPAQ standar: moderate = 4 MET
      case IpaqIntensity.ringan:
        return 3.3; // IPAQ standar: walking = 3.3 MET
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
        return '⚠️';
      case PhysicalActivityCategory.sedang:
        return '✅';
      case PhysicalActivityCategory.tinggi:
        return '🏆';
    }
  }
}

PhysicalActivityCategory categorizeWeeklyMets(double totalMetsMin) {
  if (totalMetsMin < 600) return PhysicalActivityCategory.rendah;
  if (totalMetsMin < 3000) return PhysicalActivityCategory.sedang;
  return PhysicalActivityCategory.tinggi;
}

/// Cari MetsActivity dari nama (exact match first, then contains)
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

/// Filter by category
List<MetsActivity> getMetsActivitiesByCategory(String category) =>
    kMetsActivities.where((a) => a.category == category).toList();
