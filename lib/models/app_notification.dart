import 'package:cloud_firestore/cloud_firestore.dart';

enum AppNotificationSeverity { info, warning, critical }

extension AppNotificationSeverityExtension on AppNotificationSeverity {
  String get value {
    switch (this) {
      case AppNotificationSeverity.info:
        return 'info';
      case AppNotificationSeverity.warning:
        return 'warning';
      case AppNotificationSeverity.critical:
        return 'critical';
    }
  }

  static AppNotificationSeverity fromValue(String value) {
    switch (value) {
      case 'warning':
        return AppNotificationSeverity.warning;
      case 'critical':
        return AppNotificationSeverity.critical;
      default:
        return AppNotificationSeverity.info;
    }
  }
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String typeKey;
  final String source;
  final bool isRead;
  final bool isFamilyAlert;
  final String? patientUid;
  final String? patientName;
  final String? diseaseType;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.typeKey,
    required this.source,
    required this.createdAt,
    this.isRead = false,
    this.isFamilyAlert = false,
    this.patientUid,
    this.patientName,
    this.diseaseType,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    String? typeKey,
    String? source,
    bool? isRead,
    bool? isFamilyAlert,
    String? patientUid,
    String? patientName,
    String? diseaseType,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      typeKey: typeKey ?? this.typeKey,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      isFamilyAlert: isFamilyAlert ?? this.isFamilyAlert,
      patientUid: patientUid ?? this.patientUid,
      patientName: patientName ?? this.patientName,
      diseaseType: diseaseType ?? this.diseaseType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'typeKey': typeKey,
      'source': source,
      'isRead': isRead,
      'isFamilyAlert': isFamilyAlert,
      'patientUid': patientUid,
      'patientName': patientName,
      'diseaseType': diseaseType,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      typeKey: (map['typeKey'] ?? '').toString(),
      source: (map['source'] ?? 'system').toString(),
      isRead: (map['isRead'] as bool?) ?? false,
      isFamilyAlert: (map['isFamilyAlert'] as bool?) ?? false,
      patientUid: (map['patientUid'] ?? '').toString().isEmpty
          ? null
          : (map['patientUid'] ?? '').toString(),
      patientName: (map['patientName'] ?? '').toString().isEmpty
          ? null
          : (map['patientName'] ?? '').toString(),
      diseaseType: (map['diseaseType'] ?? '').toString().isEmpty
          ? null
          : (map['diseaseType'] ?? '').toString(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
