import 'package:cloud_firestore/cloud_firestore.dart';

enum KidneyInputType { pemeriksaan, hemodialisa, gejala, obat }

extension KidneyInputTypeExtension on KidneyInputType {
  String get value {
    switch (this) {
      case KidneyInputType.pemeriksaan:
        return 'pemeriksaan';
      case KidneyInputType.hemodialisa:
        return 'hemodialisa';
      case KidneyInputType.gejala:
        return 'gejala';
      case KidneyInputType.obat:
        return 'obat';
    }
  }

  String get label {
    switch (this) {
      case KidneyInputType.pemeriksaan:
        return 'Pemeriksaan';
      case KidneyInputType.hemodialisa:
        return 'Hemodialisa';
      case KidneyInputType.gejala:
        return 'Gejala';
      case KidneyInputType.obat:
        return 'Obat';
    }
  }

}

KidneyInputType kidneyInputTypeFromValue(String value) {
  switch (value) {
    case 'pemeriksaan':
      return KidneyInputType.pemeriksaan;
    case 'hemodialisa':
      return KidneyInputType.hemodialisa;
    case 'gejala':
      return KidneyInputType.gejala;
    case 'obat':
      return KidneyInputType.obat;
    default:
      return KidneyInputType.pemeriksaan;
  }
}

class KidneyHealthRecord {
  final String id;
  final KidneyInputType type;
  final DateTime date;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const KidneyHealthRecord({
    required this.id,
    required this.type,
    required this.date,
    required this.payload,
    required this.createdAt,
  });

  factory KidneyHealthRecord.create({
    required KidneyInputType type,
    required DateTime date,
    required Map<String, dynamic> payload,
  }) {
    final now = DateTime.now();
    return KidneyHealthRecord(
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

  factory KidneyHealthRecord.fromMap(Map<String, dynamic> map) {
    return KidneyHealthRecord(
      id: (map['id'] ?? '').toString(),
      type: kidneyInputTypeFromValue(
        (map['type'] ?? 'pemeriksaan').toString(),
      ),
      date: (map['date'] as Timestamp).toDate(),
      payload: Map<String, dynamic>.from(map['payload'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  double get postHd1 => (payload['postHd1'] as num?)?.toDouble() ?? 0;
  double get preHd2 => (payload['preHd2'] as num?)?.toDouble() ?? 0;
  double get gain => preHd2 - postHd1;
  double get gainPercent {
    if (postHd1 <= 0) return 0;
    return (gain / postHd1) * 100;
  }
}
