/// Level aktivitas fisik pasien — digunakan untuk koreksi kalori DM (PERKENI).
enum ActivityLevel { ringan, sedang, berat, sangatBerat }

extension ActivityLevelExtension on ActivityLevel {
  String get label {
    switch (this) {
      case ActivityLevel.ringan:
        return 'Aktivitas Ringan';
      case ActivityLevel.sedang:
        return 'Aktivitas Sedang';
      case ActivityLevel.berat:
        return 'Aktivitas Berat';
      case ActivityLevel.sangatBerat:
        return 'Aktivitas Sangat Berat';
    }
  }

  String get description {
    switch (this) {
      case ActivityLevel.ringan:
        return 'Pegawai kantor, guru, ibu rumah tangga, mahasiswa';
      case ActivityLevel.sedang:
        return 'Pegawai industri, buruh pabrik';
      case ActivityLevel.berat:
        return 'Petani, buruh kasar, atlet, militer';
      case ActivityLevel.sangatBerat:
        return 'Tukang becak, kuli';
    }
  }

  /// Persentase koreksi terhadap kalori basal (mis. 0.20 = +20%) untuk DM.
  double get koreksiFraction {
    switch (this) {
      case ActivityLevel.ringan:
        return 0.20;
      case ActivityLevel.sedang:
        return 0.30;
      case ActivityLevel.berat:
        return 0.40;
      case ActivityLevel.sangatBerat:
        return 0.50;
    }
  }

  /// Faktor Aktivitas untuk Jantung Koroner (Harris Benedict).
  double get activityFactor {
    switch (this) {
      case ActivityLevel.ringan:
        return 1.2;
      case ActivityLevel.sedang:
        return 1.3;
      case ActivityLevel.berat:
        return 1.4;
      case ActivityLevel.sangatBerat:
        return 1.5;
    }
  }

  String get value {
    switch (this) {
      case ActivityLevel.ringan:
        return 'ringan';
      case ActivityLevel.sedang:
        return 'sedang';
      case ActivityLevel.berat:
        return 'berat';
      case ActivityLevel.sangatBerat:
        return 'sangat_berat';
    }
  }

  static ActivityLevel fromValue(String value) {
    switch (value) {
      case 'sedang':
        return ActivityLevel.sedang;
      case 'berat':
        return ActivityLevel.berat;
      case 'sangat_berat':
        return ActivityLevel.sangatBerat;
      default:
        return ActivityLevel.ringan;
    }
  }
}
