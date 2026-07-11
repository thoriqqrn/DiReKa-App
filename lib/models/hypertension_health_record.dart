import 'package:cloud_firestore/cloud_firestore.dart';

enum HypertensionInputType { tekananDarah, pemeriksaan, obat, gejala, aktivitas }

extension HypertensionInputTypeExtension on HypertensionInputType {
  String get value {
    switch (this) {
      case HypertensionInputType.tekananDarah:
        return 'tekanan_darah';
      case HypertensionInputType.pemeriksaan:
        return 'pemeriksaan';
      case HypertensionInputType.obat:
        return 'obat';
      case HypertensionInputType.gejala:
        return 'gejala';
      case HypertensionInputType.aktivitas:
        return 'aktivitas';
    }
  }

  String get label {
    switch (this) {
      case HypertensionInputType.tekananDarah:
        return 'Tekanan Darah';
      case HypertensionInputType.pemeriksaan:
        return 'Pemeriksaan';
      case HypertensionInputType.obat:
        return 'Obat';
      case HypertensionInputType.gejala:
        return 'Gejala';
      case HypertensionInputType.aktivitas:
        return 'Aktivitas';
    }
  }
}

HypertensionInputType hypertensionInputTypeFromValue(String value) {
  switch (value) {
    case 'tekanan_darah':
      return HypertensionInputType.tekananDarah;
    case 'obat':
      return HypertensionInputType.obat;
    case 'gejala':
      return HypertensionInputType.gejala;
    case 'aktivitas':
      return HypertensionInputType.aktivitas;
    default:
      return HypertensionInputType.pemeriksaan;
  }
}

class HypertensionHealthRecord {
  final String id;
  final HypertensionInputType type;
  final DateTime date;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const HypertensionHealthRecord({
    required this.id,
    required this.type,
    required this.date,
    required this.payload,
    required this.createdAt,
  });

  factory HypertensionHealthRecord.create({
    required HypertensionInputType type,
    required DateTime date,
    required Map<String, dynamic> payload,
  }) {
    final now = DateTime.now();
    return HypertensionHealthRecord(
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

  factory HypertensionHealthRecord.fromMap(Map<String, dynamic> map) {
    return HypertensionHealthRecord(
      id: (map['id'] ?? '').toString(),
      type: hypertensionInputTypeFromValue((map['type'] ?? 'pemeriksaan').toString()),
      date: (map['date'] as Timestamp).toDate(),
      payload: Map<String, dynamic>.from(map['payload'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Helper: sistol dari payload tekanan darah (pemeriksaan dengan examId 'td')
  double? get sistol {
    final result = payload['result']?.toString() ?? '';
    final parts = result.split('/');
    if (parts.length < 2) return null;
    return double.tryParse(parts[0].trim());
  }

  /// Helper: diastol dari payload tekanan darah
  double? get diastol {
    final result = payload['result']?.toString() ?? '';
    final parts = result.split('/');
    if (parts.length < 2) return null;
    return double.tryParse(parts[1].trim());
  }
}
