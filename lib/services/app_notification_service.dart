import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_constants.dart';
import '../models/app_notification.dart';
import '../models/diabetes_health_record.dart';
import '../models/disease_type.dart';
import '../models/food_log_entry.dart';
import '../models/heart_health_record.dart';
import '../models/kidney_health_record.dart';
import '../models/user_model.dart';
import 'diabetes_health_service.dart';
import 'family_link_service.dart';
import 'food_log_service.dart';
import 'heart_health_service.dart';
import 'kidney_health_service.dart';

class AppNotificationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _notificationsRef(String uid) {
    return _db
        .collection(AppConstants.colUsers)
        .doc(uid)
        .collection('notifications');
  }

  static Stream<List<AppNotification>> watchNotifications(String uid) {
    return _notificationsRef(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppNotification.fromMap(doc.data()))
              .toList(),
        );
  }

  static Stream<int> watchUnreadCount(String uid) {
    return watchNotifications(uid).map(
      (items) => items.where((item) => !item.isRead).length,
    );
  }

  static Future<void> markAsRead(String uid, String notificationId) async {
    await _notificationsRef(uid).doc(notificationId).set({
      'isRead': true,
    }, SetOptions(merge: true));
  }

  static Future<void> markAllAsRead(String uid) async {
    final snapshot = await _notificationsRef(uid).where('isRead', isEqualTo: false).get();
    if (snapshot.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.set(doc.reference, {'isRead': true}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  static Future<void> refreshForUser(UserModel user) async {
    final userNotifications = await _buildNotifications(user);
    await _syncManagedNotifications(
      uid: user.uid,
      source: 'system',
      notifications: userNotifications,
    );

    final familyAlerts = userNotifications
        .where((item) => item.isFamilyAlert)
        .map(
          (item) => item.copyWith(
            source: 'family_system',
            title: 'Pantauan keluarga: ${user.name}',
            patientUid: user.uid,
            patientName: user.name,
          ),
        )
        .toList();

    final familyUids = await FamilyLinkService.getLinkedFamilyUids(user.uid);
    for (final familyUid in familyUids) {
      await _syncManagedNotifications(
        uid: familyUid,
        source: 'family_system',
        notifications: familyAlerts,
      );
    }
  }

  static Future<void> _syncManagedNotifications({
    required String uid,
    required String source,
    required List<AppNotification> notifications,
  }) async {
    final existingSnapshot = await _notificationsRef(uid)
        .where('source', isEqualTo: source)
        .get();
    final existingById = {
      for (final doc in existingSnapshot.docs) doc.id: AppNotification.fromMap(doc.data()),
    };

    final nextIds = notifications.map((item) => item.id).toSet();
    final batch = _db.batch();

    for (final item in notifications) {
      final existing = existingById[item.id];
      batch.set(
        _notificationsRef(uid).doc(item.id),
        item.copyWith(
          source: source,
          isRead: existing?.isRead ?? false,
        ).toMap(),
      );
    }

    for (final doc in existingSnapshot.docs) {
      if (!nextIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }

    await batch.commit();
  }

  static Future<List<AppNotification>> _buildNotifications(UserModel user) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entriesToday = await FoodLogService.getEntries(user.uid, today);
    final foodTotals = _sumFoodEntries(entriesToday);
    final needs = user.nutritionNeeds;
    final notifications = <AppNotification>[];
    final dateKey = _dateKey(today);

    int intakeMismatchCount = 0;
    int badExamCount = 0;

    if (user.diseaseType == DiseaseType.chronicKidneyDisease) {
      final kidneyRecords = await KidneyHealthService.getRecords(
        user.uid,
        fromDate: today.subtract(const Duration(days: 7)),
        limit: 50,
      );
      final todayRecords = kidneyRecords.where((e) => _isSameDay(e.date, today)).toList();

      if (needs != null && needs.cairan > 0) {
        final ratio = foodTotals['cairan']! / needs.cairan;
        if (ratio >= 0.5) {
          intakeMismatchCount++;
          notifications.add(
            AppNotification(
              id: 'kidney-fluid-$dateKey',
              title: 'Asupan cairan mulai tinggi',
              message:
                  'Asupan cairan hari ini sudah ${(ratio * 100).toStringAsFixed(0)}% dari batas harian.',
              typeKey: 'kidney_fluid_warning',
              source: 'system',
              createdAt: now,
              diseaseType: user.diseaseType.value,
            ),
          );
        }
      }

      intakeMismatchCount += _addNutrientThresholdAlerts(
        notifications: notifications,
        now: now,
        dateKey: dateKey,
        disease: user.diseaseType,
        totals: foodTotals,
        thresholds: {
          'protein': needs?.protein ?? 0,
          'natrium': needs?.natrium ?? 0,
          'kalium': needs?.kalium ?? 0,
          'fosfor': needs?.fosfor ?? 0,
        },
      );

      badExamCount = kidneyRecords
          .where((record) => record.type == KidneyInputType.pemeriksaan)
          .where((record) => !_isNormalCategory(record.payload['category']))
          .length;

      if (_hasNoInputToday(entriesToday, todayRecords)) {
        notifications.add(
          AppNotification(
            id: 'kidney-no-input-$dateKey',
            title: 'Belum ada input hari ini',
            message: 'Catat makanan atau data kesehatan ginjal hari ini agar pemantauan tetap akurat.',
            typeKey: 'kidney_daily_reminder',
            source: 'system',
            createdAt: now,
            diseaseType: user.diseaseType.value,
          ),
        );
      }

      if (badExamCount >= 2 && intakeMismatchCount >= 2) {
        notifications.add(
          AppNotification(
            id: 'kidney-family-alert-$dateKey',
            title: 'Kondisi ginjal perlu perhatian keluarga',
            message:
                'Terdapat beberapa hasil pemeriksaan yang kurang baik dan asupan hari ini belum sesuai target.',
            typeKey: 'kidney_family_alert',
            source: 'system',
            createdAt: now,
            diseaseType: user.diseaseType.value,
            isFamilyAlert: true,
          ),
        );
      }
    }

    if (user.diseaseType == DiseaseType.type2DiabetesMellitus) {
      final dmRecords = await DiabetesHealthService.getRecords(
        user.uid,
        fromDate: today.subtract(const Duration(days: 7)),
        limit: 50,
      );
      final todayRecords = dmRecords.where((e) => _isSameDay(e.date, today)).toList();
      final todayInsulin = todayRecords
          .where((record) => record.type == DiabetesInputType.insulin)
          .toList();
      final todayCheckups = todayRecords
          .where((record) => record.type == DiabetesInputType.pemeriksaan)
          .toList();

      for (final record in todayInsulin) {
        final meal = (record.payload['meal'] ?? 'Waktu makan').toString();
        final gl = _toDouble(record.payload['gl']);
        final carbs = _toDouble(record.payload['karbohidratMakan']);
        if (gl > 20 || carbs > 45) {
          intakeMismatchCount++;
          notifications.add(
            AppNotification(
              id: 'dm-gl-$dateKey-${record.id}',
              title: 'GL makan tinggi',
              message:
                  '$meal terdeteksi memiliki glycemic load/asupan karbohidrat tinggi. Pertimbangkan evaluasi porsi dan pilihan makanan.',
              typeKey: 'dm_gl_warning',
              source: 'system',
              createdAt: now,
              diseaseType: user.diseaseType.value,
            ),
          );
        }
      }

      badExamCount = todayCheckups
          .where((record) => !_isNormalCategory(record.payload['category']))
          .length;

      if (_hasNoInputToday(entriesToday, todayRecords)) {
        notifications.add(
          AppNotification(
            id: 'dm-no-input-$dateKey',
            title: 'Belum ada input hari ini',
            message: 'Masukkan makanan atau data kesehatan diabetes hari ini agar analisis tetap terjaga.',
            typeKey: 'dm_daily_reminder',
            source: 'system',
            createdAt: now,
            diseaseType: user.diseaseType.value,
          ),
        );
      }

      if (todayInsulin.isEmpty) {
        notifications.add(
          AppNotification(
            id: 'dm-insulin-reminder-$dateKey',
            title: 'Pengingat input insulin',
            message: 'Belum ada input analisis insulin hari ini.',
            typeKey: 'dm_insulin_reminder',
            source: 'system',
            createdAt: now,
            diseaseType: user.diseaseType.value,
          ),
        );
      }

      if (badExamCount >= 2 && intakeMismatchCount >= 1) {
        notifications.add(
          AppNotification(
            id: 'dm-family-alert-$dateKey',
            title: 'Kondisi diabetes perlu perhatian keluarga',
            message:
                'Beberapa hasil pemeriksaan dan pola asupan hari ini menunjukkan kondisi yang perlu dipantau lebih ketat.',
            typeKey: 'dm_family_alert',
            source: 'system',
            createdAt: now,
            diseaseType: user.diseaseType.value,
            isFamilyAlert: true,
          ),
        );
      }
    }

    if (user.diseaseType == DiseaseType.heartFailure) {
      final heartRecords = await HeartHealthService.getRecords(
        user.uid,
        fromDate: today.subtract(const Duration(days: 14)),
        limit: 80,
      );
      final todayRecords = heartRecords.where((e) => _isSameDay(e.date, today)).toList();
      final todaySymptoms = todayRecords.where((e) => e.type == HeartInputType.gejala).toList();
      final todayMeds = todayRecords.where((e) => e.type == HeartInputType.obat).toList();

      if ((needs?.natrium ?? 0) > 0) {
        final natriumRatio = foodTotals['natrium']! / (needs?.natrium ?? 1);
        if (natriumRatio >= 0.75) {
          intakeMismatchCount++;
          notifications.add(
            AppNotification(
              id: 'heart-sodium-$dateKey',
              title: 'Asupan natrium tinggi',
              message:
                  'Asupan natrium hari ini sudah ${(natriumRatio * 100).toStringAsFixed(0)}% dari batas harian.',
              typeKey: 'heart_sodium_warning',
              source: 'system',
              createdAt: now,
              diseaseType: user.diseaseType.value,
            ),
          );
        }
      }

      final pressureTrend = _hasRisingBloodPressureTrend(heartRecords);
      if (pressureTrend) {
        badExamCount++;
        notifications.add(
          AppNotification(
            id: 'heart-pressure-trend-$dateKey',
            title: 'Tren tekanan darah meningkat',
            message: 'Tekanan darah terbaru menunjukkan tren naik dibanding catatan sebelumnya.',
            typeKey: 'heart_pressure_trend',
            source: 'system',
            createdAt: now,
            diseaseType: user.diseaseType.value,
          ),
        );
      }

      if (_hasNoInputToday(entriesToday, todayRecords)) {
        notifications.add(
          AppNotification(
            id: 'heart-no-input-$dateKey',
            title: 'Belum ada input hari ini',
            message: 'Catat makanan atau data kesehatan jantung hari ini agar pemantauan tetap lengkap.',
            typeKey: 'heart_daily_reminder',
            source: 'system',
            createdAt: now,
            diseaseType: user.diseaseType.value,
          ),
        );
      }

      if (todaySymptoms.isEmpty || todayMeds.isEmpty) {
        final missing = <String>[
          if (todaySymptoms.isEmpty) 'gejala',
          if (todayMeds.isEmpty) 'obat',
        ].join(' dan ');
        notifications.add(
          AppNotification(
            id: 'heart-input-reminder-$dateKey',
            title: 'Pengingat input harian jantung',
            message: 'Belum ada input $missing untuk hari ini.',
            typeKey: 'heart_input_reminder',
            source: 'system',
            createdAt: now,
            diseaseType: user.diseaseType.value,
          ),
        );
      }

      badExamCount += heartRecords
          .where((record) => record.type == HeartInputType.pemeriksaan)
          .where((record) => !_isNormalCategory(record.payload['category']))
          .length;

      if (badExamCount >= 2 && intakeMismatchCount >= 1) {
        notifications.add(
          AppNotification(
            id: 'heart-family-alert-$dateKey',
            title: 'Kondisi jantung perlu perhatian keluarga',
            message:
                'Terdapat tren pemeriksaan yang memburuk dan pola asupan hari ini belum sesuai target.',
            typeKey: 'heart_family_alert',
            source: 'system',
            createdAt: now,
            diseaseType: user.diseaseType.value,
            isFamilyAlert: true,
          ),
        );
      }
    }

    return notifications;
  }

  static int _addNutrientThresholdAlerts({
    required List<AppNotification> notifications,
    required DateTime now,
    required String dateKey,
    required DiseaseType disease,
    required Map<String, double> totals,
    required Map<String, double> thresholds,
  }) {
    var count = 0;
    final labels = {
      'protein': 'protein',
      'natrium': 'natrium',
      'kalium': 'kalium',
      'fosfor': 'fosfor',
    };

    for (final entry in thresholds.entries) {
      if (entry.value <= 0) continue;
      final actual = totals[entry.key] ?? 0;
      final ratio = actual / entry.value;
      if (ratio >= 0.75) {
        count++;
        notifications.add(
          AppNotification(
            id: '${disease.value}-${entry.key}-$dateKey',
            title: 'Asupan ${labels[entry.key]} mendekati/melewati batas',
            message:
                'Asupan ${labels[entry.key]} hari ini sudah ${(ratio * 100).toStringAsFixed(0)}% dari target harian.',
            typeKey: '${disease.value}_${entry.key}_warning',
            source: 'system',
            createdAt: now,
            diseaseType: disease.value,
          ),
        );
      }
    }

    return count;
  }

  static bool _hasNoInputToday(
    List<FoodLogEntry> entriesToday,
    List<dynamic> healthRecordsToday,
  ) {
    return entriesToday.isEmpty && healthRecordsToday.isEmpty;
  }

  static bool _hasRisingBloodPressureTrend(List<HeartHealthRecord> records) {
    final bpRecords = records
        .where((record) => record.type == HeartInputType.pemeriksaan)
        .where((record) => (record.payload['examId'] ?? '').toString() == 'td')
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (bpRecords.length < 2) return false;

    final latest = _parseBloodPressure(bpRecords.last.payload['result']);
    final previous = _parseBloodPressure(bpRecords[bpRecords.length - 2].payload['result']);
    if (latest == null || previous == null) return false;

    return latest.$1 >= previous.$1 + 5 || latest.$2 >= previous.$2 + 5;
  }

  static (double, double)? _parseBloodPressure(dynamic value) {
    final text = (value ?? '').toString().replaceAll(',', '.');
    final regex = RegExp(r'(\d+(?:\.\d+)?)');
    final matches = regex.allMatches(text).toList();
    if (matches.length < 2) return null;

    final sistol = double.tryParse(matches[0].group(0) ?? '');
    final diastol = double.tryParse(matches[1].group(0) ?? '');
    if (sistol == null || diastol == null) return null;
    return (sistol, diastol);
  }

  static bool _isNormalCategory(dynamic value) {
    final text = (value ?? '').toString().trim().toLowerCase();
    if (text.isEmpty) return false;
    return text == 'normal' || text == 'balance' || text == 'normal / aman';
  }

  static Map<String, double> _sumFoodEntries(List<FoodLogEntry> entries) {
    return {
      'energi': entries.fold(0.0, (total, item) => total + item.energi),
      'protein': entries.fold(0.0, (total, item) => total + item.protein),
      'lemak': entries.fold(0.0, (total, item) => total + item.lemak),
      'karbohidrat': entries.fold(0.0, (total, item) => total + item.karbohidrat),
      'natrium': entries.fold(0.0, (total, item) => total + item.natrium),
      'kalium': entries.fold(0.0, (total, item) => total + item.kalium),
      'fosfor': entries.fold(0.0, (total, item) => total + item.fosfor),
      'cairan': entries.fold(0.0, (total, item) => total + item.air),
      'serat': entries.fold(0.0, (total, item) => total + item.serat),
    };
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }
}
