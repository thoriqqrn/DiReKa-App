import 'package:cloud_firestore/cloud_firestore.dart';

/// Data hemodialisis untuk pasien penyakit ginjal kronis.
/// Menyimpan informasi kapan dimulai, kapan berakhir, jadwal, dan lokasi.
class HemodialysisData {
  final DateTime startDate;        // Tanggal mulai dialisa
  final DateTime endDate;          // Tanggal selesai dialisa (wajib)
  final List<String> scheduleDays; // ['Senin', 'Kamis', 'Sabtu'] (1-3 hari)
  final String location;           // Nama rumah sakit/klinik

  HemodialysisData({
    required this.startDate,
    required this.endDate,
    required this.scheduleDays,
    required this.location,
  });

  /// Durasi dialisa dalam bulan (approximate)
  int get durationMonths {
    return ((endDate.difference(startDate).inDays) / 30).ceil();
  }

  /// Status dialisa (ongoing atau completed)
  bool get isOngoing {
    return DateTime.now().isBefore(endDate);
  }

  /// Format durasi untuk display
  String get durationString {
    final days = endDate.difference(startDate).inDays;
    final months = (days / 30).floor();
    final remainingDays = days % 30;

    if (months == 0) {
      return '$days hari';
    } else if (remainingDays == 0) {
      return '$months bulan';
    } else {
      return '$months bulan $remainingDays hari';
    }
  }

  /// Format jadwal untuk display
  String get scheduleString => scheduleDays.join(', ');

  /// Convert ke Map untuk Firestore
  Map<String, dynamic> toMap() {
    return {
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'scheduleDays': scheduleDays,
      'location': location,
    };
  }

  /// Create dari Map (dari Firestore)
  factory HemodialysisData.fromMap(Map<String, dynamic> map) {
    return HemodialysisData(
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      scheduleDays: List<String>.from(map['scheduleDays'] as List),
      location: map['location'] as String,
    );
  }

  HemodialysisData copyWith({
    DateTime? startDate,
    DateTime? endDate,
    List<String>? scheduleDays,
    String? location,
  }) {
    return HemodialysisData(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      scheduleDays: scheduleDays ?? this.scheduleDays,
      location: location ?? this.location,
    );
  }

  @override
  String toString() =>
      'HemodialysisData(startDate: $startDate, endDate: $endDate, scheduleDays: $scheduleDays, location: $location)';
}
