import 'package:cloud_firestore/cloud_firestore.dart';
import 'activity_level.dart';
import 'disease_type.dart';
import 'nutrition_needs.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String gender;         // 'laki-laki' | 'perempuan'
  final DiseaseType diseaseType;
  final DateTime dateOfBirth;
  final double weight;     // kg
  final double height;     // cm
  final double urinOutput; // ml/hari — output urin 24 jam (untuk pasien ginjal)
  final ActivityLevel? activityLevel; // hanya untuk DM
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.gender = 'laki-laki',
    required this.diseaseType,
    required this.dateOfBirth,
    required this.weight,
    required this.height,
    this.urinOutput = 300.0,
    this.activityLevel,
    required this.createdAt,
  });

  // ── Kalkulasi Otomatis ────────────────────────────────────────────────────

  /// IMT (Indeks Massa Tubuh) = BB / TB²
  double get bmi {
    final heightM = height / 100;
    return weight / (heightM * heightM);
  }

  /// Kategori IMT berdasarkan standar Asia (berbeda dari WHO):
  /// < 18.5 → Kurang | 18.5–22.9 → Normal | 23–29.9 → Berlebih | ≥30 → Obesitas
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
    return null; // Formula penyakit lain akan ditambahkan
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
      'gender': gender,
      'diseaseType': diseaseType.value,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'weight': weight,
      'height': height,
      'urinOutput': urinOutput,
      'activityLevel': activityLevel?.value,
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
      gender: map['gender'] as String? ?? 'laki-laki',
      diseaseType: DiseaseTypeExtension.fromValue(map['diseaseType'] ?? ''),
      dateOfBirth: (map['dateOfBirth'] as Timestamp).toDate(),
      weight: (map['weight'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
      urinOutput: (map['urinOutput'] as num?)?.toDouble() ?? 300.0,
      activityLevel: map['activityLevel'] != null
          ? ActivityLevelExtension.fromValue(map['activityLevel'] as String)
          : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? gender,
    DiseaseType? diseaseType,
    DateTime? dateOfBirth,
    double? weight,
    double? height,
    double? urinOutput,
    ActivityLevel? activityLevel,
    bool clearActivityLevel = false,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      diseaseType: diseaseType ?? this.diseaseType,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      urinOutput: urinOutput ?? this.urinOutput,
      activityLevel:
          clearActivityLevel ? null : (activityLevel ?? this.activityLevel),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
