import 'package:cloud_firestore/cloud_firestore.dart';

enum HeartInputType { beratBadan, gejala, obat, pemeriksaan }

extension HeartInputTypeExtension on HeartInputType {
  String get value {
    switch (this) {
      case HeartInputType.beratBadan:
        return 'berat_badan';
      case HeartInputType.gejala:
        return 'gejala';
      case HeartInputType.obat:
        return 'obat';
      case HeartInputType.pemeriksaan:
        return 'pemeriksaan';
    }
  }

  String get label {
    switch (this) {
      case HeartInputType.beratBadan:
        return 'Berat Badan';
      case HeartInputType.gejala:
        return 'Gejala';
      case HeartInputType.obat:
        return 'Obat';
      case HeartInputType.pemeriksaan:
        return 'Pemeriksaan';
    }
  }
}

HeartInputType heartInputTypeFromValue(String value) {
  switch (value) {
    case 'berat_badan':
      return HeartInputType.beratBadan;
    case 'gejala':
      return HeartInputType.gejala;
    case 'obat':
      return HeartInputType.obat;
    case 'pemeriksaan':
      return HeartInputType.pemeriksaan;
    default:
      return HeartInputType.beratBadan;
  }
}

class HeartHealthRecord {
  final String id;
  final HeartInputType type;
  final DateTime date;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const HeartHealthRecord({
    required this.id,
    required this.type,
    required this.date,
    required this.payload,
    required this.createdAt,
  });

  factory HeartHealthRecord.create({
    required HeartInputType type,
    required DateTime date,
    required Map<String, dynamic> payload,
  }) {
    final now = DateTime.now();
    return HeartHealthRecord(
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

  factory HeartHealthRecord.fromMap(Map<String, dynamic> map) {
    return HeartHealthRecord(
      id: (map['id'] ?? '').toString(),
      type: heartInputTypeFromValue((map['type'] ?? 'berat_badan').toString()),
      date: (map['date'] as Timestamp).toDate(),
      payload: Map<String, dynamic>.from(map['payload'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  double get weight => _toDouble(payload['weight']);
  double get idealWeight => _toDouble(payload['idealWeight']);
}
