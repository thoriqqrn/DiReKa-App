import 'package:cloud_firestore/cloud_firestore.dart';
import 'activity_level.dart';
import 'disease_type.dart';
import 'hemodialysis_data.dart';
import 'nutrition_needs.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String addressVillage;
  final String addressDistrict;
  final String addressCity;
  final String addressProvince;
  final String education;
  final String occupation;
  final String gender; // 'laki-laki' | 'perempuan'
  final DiseaseType diseaseType;
  final DateTime dateOfBirth;
  final double weight; // kg
  final double height; // cm
  final double urinOutput; // ml/hari — output urin 24 jam (untuk pasien ginjal)
  final ActivityLevel? activityLevel; // untuk DM dan Jantung Koroner
  final double diabetesDurationYears; // hanya untuk DM
  final double heartDiseaseDurationYears; // hanya untuk Jantung Koroner
  final bool usesInsulinTherapy; // hanya untuk DM
  final double insulinDurationYears; // hanya untuk DM
  final HemodialysisData? hemodialysisData; // hanya untuk penyakit ginjal
  final bool hasEdema; // riwayat pembengkakan — untuk pasien Jantung Koroner
  // ── Field khusus Hipertensi ───────────────────────────────────────────────
  final double hypertensionDurationYears; // lama menderita hipertensi
  final bool hypertensionFamilyHistory; // riwayat hipertensi keluarga
  final bool hypertensionRoutineMeds; // rutin konsumsi obat harian
  final bool isPregnant; // hanya untuk perempuan
  final int pregnancyTrimester; // 1/2/3, 0 = tidak hamil
  final DateTime createdAt;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastLoginDate;
  final List<DateTime> loginDates;
  final String? primaryUserUid; // UID akun utama jika ini adalah akun keluarga

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.addressVillage = '',
    this.addressDistrict = '',
    this.addressCity = '',
    this.addressProvince = '',
    this.education = '',
    this.occupation = '',
    this.gender = 'laki-laki',
    required this.diseaseType,
    required this.dateOfBirth,
    required this.weight,
    required this.height,
    this.urinOutput = 300.0,
    this.activityLevel,
    this.diabetesDurationYears = 0.0,
    this.heartDiseaseDurationYears = 0.0,
    this.usesInsulinTherapy = false,
    this.insulinDurationYears = 0.0,
    this.hemodialysisData,
    this.hasEdema = false,
    this.hypertensionDurationYears = 0.0,
    this.hypertensionFamilyHistory = false,
    this.hypertensionRoutineMeds = false,
    this.isPregnant = false,
    this.pregnancyTrimester = 0,
    required this.createdAt,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastLoginDate,
    this.loginDates = const [],
    this.primaryUserUid,
  });

  // ── Kalkulasi Otomatis ────────────────────────────────────────────────────

  /// IMT (Indeks Massa Tubuh) = BB / TB²
  double get bmi {
    final heightM = height / 100;
    return weight / (heightM * heightM);
  }

  /// Kategori IMT (Asia-Pacific):
  /// < 18.5    → Berat badan kurang (underweight)
  /// 18.5–22.9 → Berat badan normal
  /// 23.0–29.9 → Berat badan berlebih (overweight/risiko obesitas)
  /// ≥ 30.0    → Obesitas
  String get bmiCategory {
    final b = bmi;
    if (b < 18.5) return 'Berat Badan Kurang';
    if (b < 23.0) return 'Normal';
    if (b < 30.0) return 'Berat Badan Berlebih';
    return 'Obesitas';
  }

  /// BBI (Berat Badan Ideal) — Rumus Broca modifikasi:
  /// BBI = (TB - 100) - ((TB - 100) × 10%)
  double get bbi {
    final base = height - 100;
    // Untuk laki-laki < 160cm dan perempuan < 150cm, tidak dikurangi 10%
    if ((gender == 'laki-laki' && height < 160) ||
        (gender == 'perempuan' && height < 150)) {
      return base;
    }
    return base - (base * 0.1);
  }

  /// Kebutuhan nutrisi harian berdasarkan jenis penyakit.
  NutritionNeeds? get nutritionNeeds {
    if (diseaseType == DiseaseType.chronicKidneyDisease) {
      return NutritionNeeds.kidneyDisease(bbi: bbi, urinOutput: urinOutput);
    }
    if (diseaseType == DiseaseType.type2DiabetesMellitus) {
      return NutritionNeeds.diabetes(
        bbi: bbi,
        gender: gender,
        age: age['years']!,
        koreksiFraksiAktivitas:
            (activityLevel ?? ActivityLevel.lansiaPekerjaKantor).koreksiFraction,
        bmiCategory: bmiCategory,
      );
    }
    if (diseaseType == DiseaseType.heartFailure) {
      return NutritionNeeds.heartFailure(
        weight: weight,
        height: height,
        gender: gender,
        age: age['years']!,
        activityFactor:
            (activityLevel ?? ActivityLevel.lansiaPekerjaKantor).activityFactor,
        hasEdema: hasEdema,
      );
    }
    if (diseaseType == DiseaseType.hypertension) {
      return NutritionNeeds.hypertension(
        bbi: bbi,
        height: height,
        gender: gender,
        age: age['years']!,
        activityFactor:
            (activityLevel ?? ActivityLevel.lansiaPekerjaKantor).hypertensionFactor,
        isSevere: false, // default; diperbarui berdasarkan data TD terbaru
      );
    }
    return null;
  }

  Map<String, int> get age {
    final now = DateTime.now();
    int years = now.year - dateOfBirth.year;
    int months = now.month - dateOfBirth.month;
    if (months < 0) {
      years--;
      months += 12;
    }
    return {'years': years, 'months': months};
  }

  String get ageString {
    final a = age;
    return '${a['years']} tahun ${a['months']} bulan';
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'addressVillage': addressVillage,
      'addressDistrict': addressDistrict,
      'addressCity': addressCity,
      'addressProvince': addressProvince,
      'education': education,
      'occupation': occupation,
      'gender': gender,
      'diseaseType': diseaseType.value,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'weight': weight,
      'height': height,
      'urinOutput': urinOutput,
      'activityLevel': activityLevel?.value,
      'diabetesDurationYears': diabetesDurationYears,
      'heartDiseaseDurationYears': heartDiseaseDurationYears,
      'usesInsulinTherapy': usesInsulinTherapy,
      'insulinDurationYears': insulinDurationYears,
      'hemodialysisData': hemodialysisData?.toMap(),
      'hasEdema': hasEdema,
      'hypertensionDurationYears': hypertensionDurationYears,
      'hypertensionFamilyHistory': hypertensionFamilyHistory,
      'hypertensionRoutineMeds': hypertensionRoutineMeds,
      'isPregnant': isPregnant,
      'pregnancyTrimester': pregnancyTrimester,
      'bmi': double.parse(bmi.toStringAsFixed(2)),
      'bbi': double.parse(bbi.toStringAsFixed(2)),
      'createdAt': Timestamp.fromDate(createdAt),
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastLoginDate': lastLoginDate != null ? Timestamp.fromDate(lastLoginDate!) : null,
      'loginDates': loginDates.map((d) => Timestamp.fromDate(d)).toList(),
      'primaryUserUid': primaryUserUid,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    double toDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      addressVillage: (map['addressVillage'] ?? '').toString(),
      addressDistrict: (map['addressDistrict'] ?? '').toString(),
      addressCity: (map['addressCity'] ?? '').toString(),
      addressProvince: (map['addressProvince'] ?? '').toString(),
      education: (map['education'] ?? '').toString(),
      occupation: (map['occupation'] ?? '').toString(),
      gender: map['gender'] as String? ?? 'laki-laki',
      diseaseType: DiseaseTypeExtension.fromValue(map['diseaseType'] ?? ''),
      dateOfBirth: (map['dateOfBirth'] as Timestamp).toDate(),
      weight: toDouble(map['weight']),
      height: toDouble(map['height']),
      urinOutput: map['urinOutput'] != null ? toDouble(map['urinOutput']) : 300.0,
      activityLevel: map['activityLevel'] != null
          ? ActivityLevelExtension.fromValue(map['activityLevel'] as String)
          : null,
      diabetesDurationYears: toDouble(map['diabetesDurationYears']),
      heartDiseaseDurationYears: toDouble(map['heartDiseaseDurationYears']),
      usesInsulinTherapy: (map['usesInsulinTherapy'] as bool?) ?? false,
      insulinDurationYears: toDouble(map['insulinDurationYears']),
      hemodialysisData: map['hemodialysisData'] != null
          ? HemodialysisData.fromMap(
              map['hemodialysisData'] as Map<String, dynamic>,
            )
          : null,
      hasEdema: (map['hasEdema'] as bool?) ?? false,
      hypertensionDurationYears: toDouble(map['hypertensionDurationYears']),
      hypertensionFamilyHistory: (map['hypertensionFamilyHistory'] as bool?) ?? false,
      hypertensionRoutineMeds: (map['hypertensionRoutineMeds'] as bool?) ?? false,
      isPregnant: (map['isPregnant'] as bool?) ?? false,
      pregnancyTrimester: (map['pregnancyTrimester'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (map['longestStreak'] as num?)?.toInt() ?? 0,
      lastLoginDate: map['lastLoginDate'] != null
          ? (map['lastLoginDate'] as Timestamp).toDate()
          : null,
      loginDates:
          (map['loginDates'] as List<dynamic>?)
              ?.map((t) => (t as Timestamp).toDate())
              .toList() ??
          [],
      primaryUserUid: map['primaryUserUid'] as String?,
    );
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? addressVillage,
    String? addressDistrict,
    String? addressCity,
    String? addressProvince,
    String? education,
    String? occupation,
    String? gender,
    DiseaseType? diseaseType,
    DateTime? dateOfBirth,
    double? weight,
    double? height,
    double? urinOutput,
    ActivityLevel? activityLevel,
    bool clearActivityLevel = false,
    double? diabetesDurationYears,
    double? heartDiseaseDurationYears,
    bool? usesInsulinTherapy,
    double? insulinDurationYears,
    HemodialysisData? hemodialysisData,
    bool clearHemodialysisData = false,
    bool? hasEdema,
    double? hypertensionDurationYears,
    bool? hypertensionFamilyHistory,
    bool? hypertensionRoutineMeds,
    bool? isPregnant,
    int? pregnancyTrimester,
    DateTime? createdAt,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastLoginDate,
    List<DateTime>? loginDates,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      addressVillage: addressVillage ?? this.addressVillage,
      addressDistrict: addressDistrict ?? this.addressDistrict,
      addressCity: addressCity ?? this.addressCity,
      addressProvince: addressProvince ?? this.addressProvince,
      education: education ?? this.education,
      occupation: occupation ?? this.occupation,
      gender: gender ?? this.gender,
      diseaseType: diseaseType ?? this.diseaseType,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      urinOutput: urinOutput ?? this.urinOutput,
      activityLevel: clearActivityLevel
          ? null
          : (activityLevel ?? this.activityLevel),
      diabetesDurationYears:
          diabetesDurationYears ?? this.diabetesDurationYears,
      heartDiseaseDurationYears:
          heartDiseaseDurationYears ?? this.heartDiseaseDurationYears,
      usesInsulinTherapy: usesInsulinTherapy ?? this.usesInsulinTherapy,
      insulinDurationYears: insulinDurationYears ?? this.insulinDurationYears,
      hemodialysisData: clearHemodialysisData
          ? null
          : (hemodialysisData ?? this.hemodialysisData),
      hasEdema: hasEdema ?? this.hasEdema,
      hypertensionDurationYears: hypertensionDurationYears ?? this.hypertensionDurationYears,
      hypertensionFamilyHistory: hypertensionFamilyHistory ?? this.hypertensionFamilyHistory,
      hypertensionRoutineMeds: hypertensionRoutineMeds ?? this.hypertensionRoutineMeds,
      isPregnant: isPregnant ?? this.isPregnant,
      pregnancyTrimester: pregnancyTrimester ?? this.pregnancyTrimester,
      createdAt: createdAt ?? this.createdAt,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      loginDates: loginDates ?? this.loginDates,
      primaryUserUid: primaryUserUid ?? primaryUserUid,
    );
  }
}
