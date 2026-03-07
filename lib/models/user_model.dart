import 'package:cloud_firestore/cloud_firestore.dart';
import 'disease_type.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final DiseaseType diseaseType;
  final DateTime dateOfBirth;
  final double weight; // kg
  final double height; // cm
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.diseaseType,
    required this.dateOfBirth,
    required this.weight,
    required this.height,
    required this.createdAt,
  });

  // Kalkulasi otomatis
  double get bmi {
    final heightM = height / 100;
    return weight / (heightM * heightM);
  }

  String get bmiCategory {
    final b = bmi;
    if (b < 18.5) return 'Kurus';
    if (b < 25.0) return 'Normal';
    if (b < 30.0) return 'Gemuk';
    return 'Obesitas';
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
      'diseaseType': diseaseType.value,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'weight': weight,
      'height': height,
      'bmi': double.parse(bmi.toStringAsFixed(2)),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      diseaseType: DiseaseTypeExtension.fromValue(map['diseaseType'] ?? ''),
      dateOfBirth: (map['dateOfBirth'] as Timestamp).toDate(),
      weight: (map['weight'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    DiseaseType? diseaseType,
    DateTime? dateOfBirth,
    double? weight,
    double? height,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      diseaseType: diseaseType ?? this.diseaseType,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
