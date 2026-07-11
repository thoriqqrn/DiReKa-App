/// Level aktivitas fisik pasien — digunakan untuk koreksi kalori DM (PERKENI)
/// dan Hipertensi (Mifflin-St Jeor).
enum ActivityLevel { baringTotal, lansiaPekerjaKantor, ibuRumahTangga, mahasiswaGuruPerawat, buruhTaniAtlet }

extension ActivityLevelExtension on ActivityLevel {
  /// Label untuk Hipertensi (sesuai spesifikasi DiReKa)
  String get label {
    switch (this) {
      case ActivityLevel.baringTotal:
        return 'Baring/istirahat total';
      case ActivityLevel.lansiaPekerjaKantor:
        return 'Lansia, pekerja kantoran';
      case ActivityLevel.ibuRumahTangga:
        return 'Ibu rumah tangga';
      case ActivityLevel.mahasiswaGuruPerawat:
        return 'Mahasiswa, guru, perawat';
      case ActivityLevel.buruhTaniAtlet:
        return 'Buruh bangunan, petani, atlet';
    }
  }

  String get description {
    switch (this) {
      case ActivityLevel.baringTotal:
        return 'Istirahat total, tidak ada aktivitas fisik';
      case ActivityLevel.lansiaPekerjaKantor:
        return 'Aktivitas ringan seperti pekerjaan kantor dan lansia';
      case ActivityLevel.ibuRumahTangga:
        return 'Aktivitas sedang seperti pekerjaan rumah tangga';
      case ActivityLevel.mahasiswaGuruPerawat:
        return 'Aktivitas aktif seperti belajar, mengajar, merawat pasien';
      case ActivityLevel.buruhTaniAtlet:
        return 'Aktivitas berat seperti buruh bangunan, bertani, atau berolahraga intensif';
    }
  }

  /// Faktor aktivitas untuk Hipertensi (Mifflin-St Jeor).
  double get hypertensionFactor {
    switch (this) {
      case ActivityLevel.baringTotal:
        return 1.2;
      case ActivityLevel.lansiaPekerjaKantor:
        return 1.3;
      case ActivityLevel.ibuRumahTangga:
        return 1.5;
      case ActivityLevel.mahasiswaGuruPerawat:
        return 1.7;
      case ActivityLevel.buruhTaniAtlet:
        return 2.0;
    }
  }

  /// Persentase koreksi terhadap kalori basal untuk DM (PERKENI) — legacy.
  /// Hipertensi tidak menggunakan ini; gunakan [hypertensionFactor].
  double get koreksiFraction {
    switch (this) {
      case ActivityLevel.baringTotal:
        return 0.0; // tidak aktif
      case ActivityLevel.lansiaPekerjaKantor:
        return 0.20;
      case ActivityLevel.ibuRumahTangga:
        return 0.30;
      case ActivityLevel.mahasiswaGuruPerawat:
        return 0.40;
      case ActivityLevel.buruhTaniAtlet:
        return 0.50;
    }
  }

  /// Faktor Aktivitas untuk Jantung Koroner (Harris Benedict) — legacy.
  double get activityFactor {
    switch (this) {
      case ActivityLevel.baringTotal:
        return 1.2;
      case ActivityLevel.lansiaPekerjaKantor:
        return 1.3;
      case ActivityLevel.ibuRumahTangga:
        return 1.4;
      case ActivityLevel.mahasiswaGuruPerawat:
        return 1.4;
      case ActivityLevel.buruhTaniAtlet:
        return 1.5;
    }
  }

  String get value {
    switch (this) {
      case ActivityLevel.baringTotal:
        return 'baring_total';
      case ActivityLevel.lansiaPekerjaKantor:
        return 'lansia_pekerja_kantor';
      case ActivityLevel.ibuRumahTangga:
        return 'ibu_rumah_tangga';
      case ActivityLevel.mahasiswaGuruPerawat:
        return 'mahasiswa_guru_perawat';
      case ActivityLevel.buruhTaniAtlet:
        return 'buruh_tani_atlet';
    }
  }

  static ActivityLevel fromValue(String value) {
    switch (value) {
      case 'baring_total':
        return ActivityLevel.baringTotal;
      case 'lansia_pekerja_kantor':
        return ActivityLevel.lansiaPekerjaKantor;
      case 'ibu_rumah_tangga':
        return ActivityLevel.ibuRumahTangga;
      case 'mahasiswa_guru_perawat':
        return ActivityLevel.mahasiswaGuruPerawat;
      case 'buruh_tani_atlet':
        return ActivityLevel.buruhTaniAtlet;
      // Legacy DM/Jantung value mapping → nearest equivalent
      case 'ringan':
        return ActivityLevel.lansiaPekerjaKantor;
      case 'sedang':
        return ActivityLevel.ibuRumahTangga;
      case 'berat':
        return ActivityLevel.mahasiswaGuruPerawat;
      case 'sangat_berat':
        return ActivityLevel.buruhTaniAtlet;
      default:
        return ActivityLevel.lansiaPekerjaKantor;
    }
  }
}
