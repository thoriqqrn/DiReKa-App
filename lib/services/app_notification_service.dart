import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/app_constants.dart';
import '../models/app_notification.dart';
import '../models/diabetes_health_record.dart';
import '../models/disease_type.dart';
import '../models/food_log_entry.dart';
import '../models/heart_health_record.dart';
import '../models/kidney_health_record.dart';
import '../models/meal_type.dart';
import '../models/user_model.dart';
import 'diabetes_health_service.dart';
import 'family_link_service.dart';
import 'food_log_service.dart';
import 'heart_health_service.dart';
import 'kidney_health_service.dart';
import '../models/hypertension_health_record.dart';
import 'hypertension_health_service.dart';

class AppNotificationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  // Stream controller to notify listeners about permission status changes
  static final StreamController<bool> _permissionStreamController = StreamController<bool>.broadcast();
  static Stream<bool> get onPermissionChanged => _permissionStreamController.stream;

  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      final androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      final iosInit = DarwinInitializationSettings();
      final initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

      final success = await _localNotifications.initialize(
        settings: initSettings,
      );
      _isInitialized = success ?? false;
      
      // Update initial status
      final status = await checkPermissionStatus();
      _permissionStreamController.add(status);
    } catch (e) {
      debugPrint('Notification Init Error: $e');
      _isInitialized = false;
    }
  }

  static Future<bool> checkPermissionStatus() async {
    if (kIsWeb) return false;
    
    final platform = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (platform != null) {
      final allowed = await platform.areNotificationsEnabled();
      return allowed ?? false;
    }
    return _isInitialized;
  }

  static Future<bool> requestPermissions() async {
    if (!_isInitialized) await init();
    
    try {
      bool? granted = false;
      final platform = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (platform != null) {
        granted = await platform.requestNotificationsPermission();
      }
      
      final iosPlatform = _localNotifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosPlatform != null) {
        granted = await iosPlatform.requestPermissions(alert: true, badge: true, sound: true);
      }
      
      final finalStatus = granted ?? false;
      _permissionStreamController.add(finalStatus);
      return finalStatus;
    } catch (e) {
      debugPrint('Request Permission Error: $e');
      return false;
    }
  }

  static Future<void> sendTestNotification() async {
    if (!_isInitialized) await init();
    
    await _showLocalNotification(
      AppNotification(
        id: 'test-notification',
        title: 'Tes Notifikasi DiReKa',
        message: 'Selamat! Notifikasi di HP kamu sudah aktif dan berjalan dengan baik.',
        typeKey: 'test',
        source: 'system',
        createdAt: DateTime.now(),
        diseaseType: 'all',
      ),
    );
  }

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

  static Future<void> deleteNotification(String uid, String notificationId) async {
    await _notificationsRef(uid).doc(notificationId).delete();
  }

  static Future<void> clearAllNotifications(String uid) async {
    final snapshot = await _notificationsRef(uid).get();
    if (snapshot.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
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
      final isRead = existing?.isRead ?? false;

      batch.set(
        _notificationsRef(uid).doc(item.id),
        item.copyWith(
          source: source,
          isRead: isRead,
        ).toMap(),
      );

      // Jika baru dan belum dibaca, tampilkan local notification
      if (existing == null && !isRead) {
        _showLocalNotification(item);
      }
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
        fromDate: today.subtract(Duration(days: 7)),
        limit: 50,
      );
      final todayRecords = kidneyRecords.where((e) => _isSameDay(e.date, today)).toList();

      if (needs != null && needs.cairan > 0) {
        final ratio = foodTotals['cairan']! / needs.cairan;
        if (ratio >= 0.5) { // Zona kuning > 50%
          intakeMismatchCount++;
          notifications.add(
            AppNotification(
              id: 'kidney-fluid-$dateKey',
              title: 'Asupan cairan mulai tinggi',
              message:
                  'Asupan cairan hari ini sudah ${(ratio * 100).toStringAsFixed(0)}% (Zona Kuning). Harap batasi minum.',
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
            message: 'Jangan lupa catat makanan atau data kesehatan ginjal hari ini.',
            typeKey: 'kidney_daily_reminder',
            source: 'system',
            createdAt: now,
            diseaseType: user.diseaseType.value,
          ),
        );
      }

      if ((badExamCount >= 2 && intakeMismatchCount >= 2) || (badExamCount >= 3)) {
        notifications.add(
          AppNotification(
            id: 'kidney-family-alert-$dateKey',
            title: 'Kondisi ginjal perlu perhatian keluarga',
            message:
                'Terdapat hasil pemeriksaan yang kurang baik dan asupan belum sesuai target.',
            typeKey: 'kidney_family_alert',
            source: 'system',
            createdAt: now,
            diseaseType: user.diseaseType.value,
            isFamilyAlert: true,
          ),
        );
      }

      // H-1 Hemodialisis Reminder
      if (user.hemodialysisData != null) {
        final tomorrow = now.add(Duration(days: 1));
        final dayNameTomorrow = _getDayNameIndonesian(tomorrow.weekday);
        if (user.hemodialysisData!.scheduleDays.contains(dayNameTomorrow)) {
          notifications.add(
            AppNotification(
              id: 'kidney-hd-reminder-$dateKey',
              title: 'Jadwal Dialisis Besok',
              message: 'Besok kamu ada jadwal dialisis di ${user.hemodialysisData!.location}.',
              typeKey: 'kidney_hd_reminder',
              source: 'system',
              createdAt: now,
              diseaseType: user.diseaseType.value,
            ),
          );
        }
      }
    }

    if (user.diseaseType == DiseaseType.type2DiabetesMellitus) {
      final dmRecords = await DiabetesHealthService.getRecords(
        user.uid,
        fromDate: today.subtract(Duration(days: 7)),
        limit: 50,
      );
      final todayRecords = dmRecords.where((e) => _isSameDay(e.date, today)).toList();
      final todayCheckups = todayRecords
          .where((record) => record.type == DiabetesInputType.pemeriksaan)
          .toList();

      // NEW: Add individual checkup alerts for DM
      for (final checkup in todayCheckups) {
        if (!_isNormalCategory(checkup.payload['category'])) {
          notifications.add(
            AppNotification(
              id: 'dm-checkup-${checkup.id}',
              title: 'Hasil pemeriksaan memerlukan perhatian',
              message: 'Hasil ${checkup.payload['exam'] ?? 'pemeriksaan'} Anda (${checkup.payload['result']}) berada di kategori ${checkup.payload['category']}.',
              typeKey: 'dm_checkup_warning',
              source: 'system',
              createdAt: now,
              diseaseType: user.diseaseType.value,
            ),
          );
        }
      }

      // NEW: Add general nutrient threshold alerts for DM (especially for Carbs)
      intakeMismatchCount += _addNutrientThresholdAlerts(
        notifications: notifications,
        now: now,
        dateKey: dateKey,
        disease: user.diseaseType,
        totals: foodTotals,
        thresholds: {
          'karbohidrat': needs?.karbohidrat ?? 0,
          'energi': needs?.energi ?? 0,
        },
      );

      // Warning Glycemic Load per makan
      final entriesByMeal = <MealType, List<FoodLogEntry>>{};
      for (var e in entriesToday) {
        entriesByMeal.putIfAbsent(e.mealType, () => []).add(e);
      }

      entriesByMeal.forEach((mealType, entries) {
        final mealGL = entries.fold(0.0, (total, e) => total + e.glycemicLoad);
        if (mealGL >= 20) { // GL Tinggi > 20
          intakeMismatchCount++;
          notifications.add(
            AppNotification(
              id: 'dm-gl-$dateKey-${mealType.value}',
              title: 'Glycemic Load ${mealType.label} Tinggi',
              message: 'Menu ${mealType.label} kamu memiliki beban glikemik tinggi (${mealGL.toStringAsFixed(1)}).',
              typeKey: 'dm_gl_warning',
              source: 'system',
              createdAt: now,
              diseaseType: user.diseaseType.value,
            ),
          );
        }
      });

      badExamCount = todayCheckups
          .where((record) => !_isNormalCategory(record.payload['category']))
          .length;

      if (_hasNoInputToday(entriesToday, todayRecords)) {
        notifications.add(
          AppNotification(
            id: 'dm-no-input-$dateKey',
            title: 'Belum ada input hari ini',
            message: 'Masukkan data makanan atau kesehatan diabetes kamu hari ini.',
            typeKey: 'dm_daily_reminder',
            source: 'system',
            createdAt: now,
            diseaseType: user.diseaseType.value,
          ),
        );
      }

      if (user.usesInsulinTherapy) {
        final hasInsulinInput = todayRecords.any((r) => r.type == DiabetesInputType.insulin);
        if (!hasInsulinInput) {
          notifications.add(
            AppNotification(
              id: 'dm-insulin-reminder-$dateKey',
              title: 'Pengingat Input Insulin',
              message: 'Kamu belum memasukkan data analisis insulin hari ini.',
              typeKey: 'dm_insulin_reminder',
              source: 'system',
              createdAt: now,
              diseaseType: user.diseaseType.value,
            ),
          );
        }
      }

      if (badExamCount >= 2 && intakeMismatchCount >= 1) {
        notifications.add(
          AppNotification(
            id: 'dm-family-alert-$dateKey',
            title: 'Kondisi diabetes perlu perhatian keluarga',
            message:
                'Hasil pemeriksaan dan pola makan hari ini memerlukan pantauan lebih ketat.',
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
        fromDate: today.subtract(Duration(days: 14)),
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
                  'Asupan natrium sudah mencapai ${(natriumRatio * 100).toStringAsFixed(0)}% dari batas harian.',
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
            message: 'Tekanan darah menunjukkan tren naik. Harap waspada dan istirahat.',
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
            message: 'Catat makanan atau data kesehatan jantung hari ini.',
            typeKey: 'heart_daily_reminder',
            source: 'system',
            createdAt: now,
            diseaseType: user.diseaseType.value,
          ),
        );
      }

      if (todaySymptoms.isEmpty || todayMeds.isEmpty) {
        notifications.add(
          AppNotification(
            id: 'heart-input-reminder-$dateKey',
            title: 'Pengingat input harian',
            message: 'Jangan lupa masukkan data gejala dan konsumsi obat hari ini.',
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
                'Tren kesehatan menurun dan asupan natrium tidak sesuai target.',
            typeKey: 'heart_family_alert',
            source: 'system',
            createdAt: now,
            diseaseType: user.diseaseType.value,
            isFamilyAlert: true,
          ),
        );
      }
    }

    if (user.diseaseType == DiseaseType.hypertension) {
      final htRecords = await HypertensionHealthService.getRecords(
        user.uid,
        fromDate: today,
        limit: 50,
      );
      final todayRecords = htRecords.where((e) => _isSameDay(e.date, today)).toList();

      intakeMismatchCount += _addNutrientThresholdAlerts(
        notifications: notifications,
        now: now,
        dateKey: dateKey,
        disease: user.diseaseType,
        totals: foodTotals,
        thresholds: {
          'natrium': needs?.natrium ?? 0,
          'kalium': needs?.kalium ?? 0,
          'kalsium': needs?.kalsium ?? 0,
          'magnesium': needs?.magnesium ?? 0,
        },
      );

      final abnormalExams = todayRecords
          .where((record) => record.type == HypertensionInputType.pemeriksaan)
          .where((record) => !_isNormalCategory(record.payload['category']))
          .toList();

      if (abnormalExams.isNotEmpty) {
        badExamCount += abnormalExams.length;
        notifications.add(
          AppNotification(
            id: 'ht-exam-warning-$dateKey',
            title: 'Hasil pemeriksaan tidak normal',
            message: 'Ada hasil pemeriksaan hari ini yang berada di luar batas normal. Jaga pola makan dan istirahat.',
            typeKey: 'ht_exam_warning',
            source: 'system',
            createdAt: now,
            diseaseType: user.diseaseType.value,
          ),
        );
      }

      if (user.hypertensionRoutineMeds == true) {
        final medsToday = todayRecords.where((e) => e.type == HypertensionInputType.obat).toList();
        if (medsToday.isEmpty) {
          notifications.add(
            AppNotification(
              id: 'ht-med-reminder-$dateKey',
              title: 'Pengingat obat rutin',
              message: 'Anda belum mencatat konsumsi obat hipertensi hari ini.',
              typeKey: 'ht_med_reminder',
              source: 'system',
              createdAt: now,
              diseaseType: user.diseaseType.value,
            ),
          );
        }
      }

      final activitiesToday = todayRecords.where((e) => e.type == HypertensionInputType.aktivitas).toList();
      final totalActivityDuration = activitiesToday.fold<int>(
        0,
        (acc, item) => acc + (int.tryParse(item.payload['duration']?.toString() ?? '0') ?? 0),
      );

      if (totalActivityDuration < 30) {
        notifications.add(
          AppNotification(
            id: 'ht-activity-reminder-$dateKey',
            title: 'Kurang aktivitas fisik',
            message: 'Ayo bergerak! Sisihkan minimal 30 menit hari ini untuk aktivitas fisik ringan.',
            typeKey: 'ht_activity_reminder',
            source: 'system',
            createdAt: now,
            diseaseType: user.diseaseType.value,
          ),
        );
      }

      if (_hasNoInputToday(entriesToday, todayRecords)) {
        notifications.add(
          AppNotification(
            id: 'ht-no-input-$dateKey',
            title: 'Belum ada input hari ini',
            message: 'Catat makanan atau data kesehatan hipertensi hari ini.',
            typeKey: 'ht_daily_reminder',
            source: 'system',
            createdAt: now,
            diseaseType: user.diseaseType.value,
          ),
        );
      }

      if (badExamCount >= 2 && intakeMismatchCount >= 1) {
        notifications.add(
          AppNotification(
            id: 'ht-family-alert-$dateKey',
            title: 'Kondisi hipertensi perlu perhatian',
            message: 'Pemeriksaan abnormal dan asupan nutrisi belum sesuai target. Butuh perhatian keluarga.',
            typeKey: 'ht_family_alert',
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
        'kalsium': 'kalsium',
        'magnesium': 'magnesium',
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
    return text == 'normal' || 
           text == 'balance' || 
           text == 'normal / aman' || 
           text == 'aman' || 
           text == 'sinkron';
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

  static String _getDayNameIndonesian(int weekday) {
    switch (weekday) {
      case 1: return 'Senin';
      case 2: return 'Selasa';
      case 3: return 'Rabu';
      case 4: return 'Kamis';
      case 5: return 'Jumat';
      case 6: return 'Sabtu';
      case 7: return 'Minggu';
      default: return '';
    }
  }

  static Future<void> _showLocalNotification(AppNotification item) async {
    final id = item.id.hashCode;
    final androidDetails = AndroidNotificationDetails(
      'direka_alerts',
      'Alerts & Reminders',
      channelDescription: 'Pemberitahuan kesehatan DiReKa',
      importance: Importance.max,
      priority: Priority.high,
    );
    final iosDetails = DarwinNotificationDetails();
    final platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: id,
      title: item.title,
      body: item.message,
      notificationDetails: platformDetails,
    );
  }

}
