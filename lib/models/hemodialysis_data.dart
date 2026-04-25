import 'package:cloud_firestore/cloud_firestore.dart';

/// Data hemodialisis untuk pasien penyakit ginjal kronis.
/// Menyimpan informasi kapan dimulai, jadwal, dan lokasi.
class HemodialysisData {
  final DateTime startDate; // Tanggal mulai dialisa (hanya bulan & tahun yang disimpan di UI)
  final List<String> scheduleDays; // ['Senin', 'Kamis', 'Sabtu'] (tanpa batas maksimal)
  final String location; // Nama rumah sakit/klinik

  HemodialysisData({
    required this.startDate,
    required this.scheduleDays,
    required this.location,
  });

  /// Durasi dialisa dalam bulan dihitung sampai hari ini (approximate)
  int get durationMonths {
    return ((DateTime.now().difference(startDate).inDays) / 30).ceil();
  }

  /// Status dialisa (selalu ongoing karena tidak ada endDate)
  bool get isOngoing => true;

  /// Format durasi untuk display
  String get durationString {
    final days = DateTime.now().difference(startDate).inDays;
    if (days < 0) return '0 hari';
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
      'scheduleDays': scheduleDays,
      'location': location,
    };
  }

  /// Create dari Map (dari Firestore)
  factory HemodialysisData.fromMap(Map<String, dynamic> map) {
    return HemodialysisData(
      startDate: (map['startDate'] as Timestamp).toDate(),
      scheduleDays: List<String>.from(map['scheduleDays'] as List),
      location: map['location'] as String,
    );
  }

  HemodialysisData copyWith({
    DateTime? startDate,
    List<String>? scheduleDays,
    String? location,
  }) {
    return HemodialysisData(
      startDate: startDate ?? this.startDate,
      scheduleDays: scheduleDays ?? this.scheduleDays,
      location: location ?? this.location,
    );
  }

  @override
  String toString() =>
      'HemodialysisData(startDate: $startDate, scheduleDays: $scheduleDays, location: $location)';
}
