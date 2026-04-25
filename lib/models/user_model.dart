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
  final ActivityLevel? activityLevel; // hanya untuk DM
  final double diabetesDurationYears; // hanya untuk DM
  final bool usesInsulinTherapy; // hanya untuk DM
  final HemodialysisData? hemodialysisData; // hanya untuk penyakit ginjal
  final bool hasEdema; // riwayat pembengkakan — untuk pasien gagal jantung
  final DateTime createdAt;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastLoginDate;
  final List<DateTime> loginDates;

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
    this.usesInsulinTherapy = false,
    this.hemodialysisData,
    this.hasEdema = false,
    required this.createdAt,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastLoginDate,
    this.loginDates = const [],
  });

  // ── Kalkulasi Otomatis ────────────────────────────────────────────────────

  /// IMT (Indeks Massa Tubuh) = BB / TB²
  double get bmi {
    final heightM = height / 100;
    return weight / (heightM * heightM);
  }

  /// Kategori IMT untuk DM (3 kategori):
  /// < 18.5 → Kurus (+20% energi)
  /// 18.5–25 → Normal (0%)
  /// ≥ 25 → Gemuk (-20% energi)
  String get bmiCategory {
    final b = bmi;
    if (b < 18.5) return 'Kurus';
    if (b < 25.0) return 'Normal';
    return 'Gemuk';
  }

  /// BBI (Berat Badan Ideal) — Rumus Broca modifikasi:
  /// BBI = (TB - 100) - ((TB - 100) × 10%)
  double get bbi {
    final base = height - 100;
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
            (activityLevel ?? ActivityLevel.ringan).koreksiFraction,
        bmiCategory: bmiCategory,
      );
    }
    if (diseaseType == DiseaseType.heartFailure) {
      return NutritionNeeds.heartFailure(
        weight: weight,
        height: height,
        gender: gender,
        age: age['years']!,
        koreksiFraksiAktivitas:
            (activityLevel ?? ActivityLevel.ringan).koreksiFraction,
        hasEdema: hasEdema,
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
      'usesInsulinTherapy': usesInsulinTherapy,
      'hemodialysisData': hemodialysisData?.toMap(),
      'hasEdema': hasEdema,
      'bmi': double.parse(bmi.toStringAsFixed(2)),
      'bbi': double.parse(bbi.toStringAsFixed(2)),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
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
      weight: (map['weight'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
      urinOutput: (map['urinOutput'] as num?)?.toDouble() ?? 300.0,
      activityLevel: map['activityLevel'] != null
          ? ActivityLevelExtension.fromValue(map['activityLevel'] as String)
          : null,
      diabetesDurationYears:
          (map['diabetesDurationYears'] as num?)?.toDouble() ?? 0.0,
      usesInsulinTherapy: (map['usesInsulinTherapy'] as bool?) ?? false,
      hemodialysisData: map['hemodialysisData'] != null
          ? HemodialysisData.fromMap(
              map['hemodialysisData'] as Map<String, dynamic>,
            )
          : null,
      hasEdema: (map['hasEdema'] as bool?) ?? false,
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
    bool? usesInsulinTherapy,
    HemodialysisData? hemodialysisData,
    bool clearHemodialysisData = false,
    bool? hasEdema,
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
      usesInsulinTherapy: usesInsulinTherapy ?? this.usesInsulinTherapy,
      hemodialysisData: clearHemodialysisData
          ? null
          : (hemodialysisData ?? this.hemodialysisData),
      hasEdema: hasEdema ?? this.hasEdema,
      createdAt: createdAt ?? this.createdAt,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      loginDates: loginDates ?? this.loginDates,
    );
  }
}
