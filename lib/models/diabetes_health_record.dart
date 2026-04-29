import 'package:cloud_firestore/cloud_firestore.dart';

enum DiabetesInputType { pemeriksaan, insulin, aktivitas, obat }

extension DiabetesInputTypeExtension on DiabetesInputType {
  String get value {
    switch (this) {
      case DiabetesInputType.pemeriksaan:
        return 'pemeriksaan';
      case DiabetesInputType.insulin:
        return 'insulin';
      case DiabetesInputType.aktivitas:
        return 'aktivitas';
      case DiabetesInputType.obat:
        return 'obat';
    }
  }

  String get label {
    switch (this) {
      case DiabetesInputType.pemeriksaan:
        return 'Pemeriksaan';
      case DiabetesInputType.insulin:
        return 'Analisis Insulin';
      case DiabetesInputType.aktivitas:
        return 'Aktivitas';
      case DiabetesInputType.obat:
        return 'Obat';
    }
  }
}

DiabetesInputType diabetesInputTypeFromValue(String value) {
  switch (value) {
    case 'pemeriksaan':
      return DiabetesInputType.pemeriksaan;
    case 'insulin':
      return DiabetesInputType.insulin;
    case 'aktivitas':
      return DiabetesInputType.aktivitas;
    case 'obat':
      return DiabetesInputType.obat;
    default:
      return DiabetesInputType.pemeriksaan;
  }
}

class DiabetesHealthRecord {
  final String id;
  final DiabetesInputType type;
  final DateTime date;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const DiabetesHealthRecord({
    required this.id,
    required this.type,
    required this.date,
    required this.payload,
    required this.createdAt,
  });

  factory DiabetesHealthRecord.create({
    required DiabetesInputType type,
    required DateTime date,
    required Map<String, dynamic> payload,
  }) {
    final now = DateTime.now();
    return DiabetesHealthRecord(
      id: now.microsecondsSinceEpoch.toString(),
      type: type,
      date: DateTime(date.year, date.month, date.day),
      payload: payload,
      createdAt: now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.value,
      'date': Timestamp.fromDate(date),
      'payload': payload,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory DiabetesHealthRecord.fromMap(Map<String, dynamic> map) {
    return DiabetesHealthRecord(
      id: (map['id'] ?? '').toString(),
      type: diabetesInputTypeFromValue((map['type'] ?? 'pemeriksaan').toString()),
      date: (map['date'] as Timestamp).toDate(),
      payload: Map<String, dynamic>.from(map['payload'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
