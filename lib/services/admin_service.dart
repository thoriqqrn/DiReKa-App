import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../core/app_constants.dart';
import '../models/disease_type.dart';
import '../models/user_model.dart';

class _UserIdentity {
  final String uid;
  final String name;
  final String email;

  const _UserIdentity({
    required this.uid,
    required this.name,
    required this.email,
  });
}

class AdminFoodLogSummary {
  final String uid;
  final String userName;
  final String userEmail;
  final DateTime date;
  final int entryCount;
  final List<Map<String, dynamic>> entries;

  const AdminFoodLogSummary({
    required this.uid,
    required this.userName,
    required this.userEmail,
    required this.date,
    required this.entryCount,
    required this.entries,
  });
}

class AdminHealthRecordSummary {
  final String uid;
  final String userName;
  final String userEmail;
  final String source;
  final String type;
  final DateTime date;
  final DateTime? createdAt;
  final Map<String, dynamic> payload;

  const AdminHealthRecordSummary({
    required this.uid,
    required this.userName,
    required this.userEmail,
    required this.source,
    required this.type,
    required this.date,
    this.createdAt,
    required this.payload,
  });
}

class EducationPost {
  final String id;
  final String title;
  final String content;
  final String? contentType;
  final String? contentDelta;
  final String? sourceUrl;
  final String previewType;
  final DateTime createdAt;
  final String createdBy;

  const EducationPost({
    required this.id,
    required this.title,
    required this.content,
    this.contentType,
    required this.contentDelta,
    required this.sourceUrl,
    required this.previewType,
    required this.createdAt,
    required this.createdBy,
  });

  String get safeContentType {
    final raw = (contentType ?? '').trim().toLowerCase();
    return raw == 'booklet' ? 'booklet' : 'artikel';
  }
}

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-southeast2');

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(AppConstants.colUsers);
  CollectionReference<Map<String, dynamic>> get _foodLogs =>
      _db.collection('food_logs');
  CollectionReference<Map<String, dynamic>> get _educationPosts =>
      _db.collection('education_posts');

  /// Total jumlah user terdaftar
  Future<int> getTotalUsers() async {
    final snapshot = await _getWithFallback(_users);
    return snapshot.docs.length;
  }

  /// Jumlah user per jenis penyakit
  Future<Map<DiseaseType, int>> getUsersByDisease() async {
    final result = <DiseaseType, int>{
      for (final disease in DiseaseType.values) disease: 0,
    };
    final snapshot = await _getWithFallback(_users);
    for (final doc in snapshot.docs) {
      final diseaseRaw = (doc.data()['diseaseType'] ?? '').toString();
      for (final disease in DiseaseType.values) {
        if (disease.value == diseaseRaw) {
          result[disease] = (result[disease] ?? 0) + 1;
          break;
        }
      }
    }
    return result;
  }

  /// Ambil semua user (untuk tabel)
  Future<List<UserModel>> getAllUsers() async {
    final snapshot = await _getWithFallback(
      _users.orderBy('createdAt', descending: true),
    );
    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data()))
        .toList();
  }

  Future<List<AdminFoodLogSummary>> getRecentFoodLogs({int limit = 50}) async {
    final snapshot = await _getWithFallback(
      _foodLogs.orderBy('date', descending: true).limit(limit),
    );
    final usersMap = await _fetchUsersByUid();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final entriesRaw = (data['entries'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final dateStr = (data['date'] ?? '').toString();
      final uid = (data['uid'] ?? '').toString();
      final user = usersMap[uid];
      return AdminFoodLogSummary(
        uid: uid,
        userName: user?.name ?? uid,
        userEmail: user?.email ?? '-',
        date: _parseDateKey(dateStr),
        entryCount: entriesRaw.length,
        entries: entriesRaw,
      );
    }).toList();
  }

  Future<List<AdminHealthRecordSummary>> getRecentHealthRecords({
    int perUserLimit = 5,
    int maxUsers = 40,
  }) async {
    final users = await _getWithFallback(_users.limit(maxUsers));
    final futures = users.docs.map((doc) async {
      final userData = doc.data();
      final uid = doc.id;
      final userName = (userData['name'] ?? uid).toString();
      final userEmail = (userData['email'] ?? '-').toString();

      final diabetesSnap = await _getWithFallback(_db
          .collection(AppConstants.colUsers)
          .doc(uid)
          .collection('diabetes_health_records')
          .orderBy('date', descending: true)
          .limit(perUserLimit)
      );
      final kidneySnap = await _getWithFallback(_db
          .collection(AppConstants.colUsers)
          .doc(uid)
          .collection('kidney_health_records')
          .orderBy('date', descending: true)
          .limit(perUserLimit)
      );
      final heartSnap = await _getWithFallback(_db
          .collection(AppConstants.colUsers)
          .doc(uid)
          .collection('heart_health_records')
          .orderBy('date', descending: true)
          .limit(perUserLimit)
      );

      return <AdminHealthRecordSummary>[
        ...diabetesSnap.docs
            .map((d) => _mapHealthDoc(d.data(), uid, userName, userEmail, 'Diabetes')),
        ...kidneySnap.docs
            .map((d) => _mapHealthDoc(d.data(), uid, userName, userEmail, 'Ginjal')),
        ...heartSnap.docs
            .map((d) => _mapHealthDoc(d.data(), uid, userName, userEmail, 'Jantung')),
      ];
    });

    final nested = await Future.wait(futures);
    final all = nested.expand((items) => items).toList();

    all.sort((a, b) => b.date.compareTo(a.date));
    return all;
  }

  Future<void> uploadEducationPost({
    required String title,
    required String content,
    String contentType = 'artikel',
    String? contentDelta,
    String? sourceUrl,
    String previewType = 'auto',
  }) async {
    await _educationPosts.add({
      'title': title.trim(),
      'content': content.trim(),
      'contentType': contentType,
      'contentDelta':
          (contentDelta == null || contentDelta.trim().isEmpty)
              ? null
              : contentDelta,
      'sourceUrl': (sourceUrl == null || sourceUrl.trim().isEmpty)
          ? null
          : sourceUrl.trim(),
      'previewType': previewType,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _auth.currentUser?.email ?? 'admin',
    });
  }

  Future<void> updateEducationPost({
    required String postId,
    required String title,
    required String content,
    String contentType = 'artikel',
    String? contentDelta,
    String? sourceUrl,
    String previewType = 'auto',
  }) async {
    await _educationPosts.doc(postId).set({
      'title': title.trim(),
      'content': content.trim(),
      'contentType': contentType,
      'contentDelta':
          (contentDelta == null || contentDelta.trim().isEmpty)
              ? null
              : contentDelta,
      'sourceUrl': (sourceUrl == null || sourceUrl.trim().isEmpty)
          ? null
          : sourceUrl.trim(),
      'previewType': previewType,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.email ?? 'admin',
    }, SetOptions(merge: true));
  }

  Future<void> deleteEducationPost(String postId) async {
    await _educationPosts.doc(postId).delete();
  }

  Future<List<EducationPost>> getEducationPosts({int limit = 50}) async {
    final snapshot = await _getWithFallback(
      _educationPosts.orderBy('createdAt', descending: true).limit(limit),
    );

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return EducationPost(
        id: doc.id,
        title: (data['title'] ?? '').toString(),
        content: (data['content'] ?? '').toString(),
        contentType: (data['contentType'] ?? 'artikel').toString(),
        contentDelta: (data['contentDelta'] as String?)?.trim().isEmpty == true
            ? null
            : data['contentDelta'] as String?,
        sourceUrl: (data['sourceUrl'] as String?)?.trim().isEmpty == true
            ? null
            : data['sourceUrl'] as String?,
        previewType: (data['previewType'] ?? 'auto').toString(),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        createdBy: (data['createdBy'] ?? 'admin').toString(),
      );
    }).toList();
  }

  /// Kirim pengumuman/notifikasi ke semua user
  Future<void> sendBroadcastNotification({
    required String title,
    required String message,
  }) async {
    await _db.collection('admin_broadcasts').add({
      'title': title.trim(),
      'message': message.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'sentBy': _auth.currentUser?.email ?? 'admin',
    });
  }

  /// Hapus akun user dari database
  Future<void> deleteUserAccount(String uid) async {
    await _users.doc(uid).delete();
  }

  /// Reset password user via Cloud Function (hanya untuk admin).
  /// Cloud Function juga membuat audit log reset password.
  Future<void> resetUserPassword({
    required String targetUid,
    required String newPassword,
    String? reason,
  }) async {
    final callable = _functions.httpsCallable('adminResetUserPassword');
    await callable.call({
      'targetUid': targetUid,
      'newPassword': newPassword,
      'reason': (reason ?? 'Reset manual dari Admin App').trim(),
    });
  }

  /// Stream realtime jumlah user
  Stream<int> userCountStream() {
    return _users.snapshots().map((snap) => snap.docs.length);
  }

  AdminHealthRecordSummary _mapHealthDoc(
    Map<String, dynamic> data,
    String uid,
    String userName,
    String userEmail,
    String source,
  ) {
    return AdminHealthRecordSummary(
      uid: uid,
      userName: userName,
      userEmail: userEmail,
      source: source,
      type: (data['type'] ?? '-').toString(),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      payload: Map<String, dynamic>.from(data['payload'] ?? {}),
    );
  }

  DateTime _parseDateKey(String date) {
    final parts = date.split('-');
    if (parts.length != 3) return DateTime.now();

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);

    if (year == null || month == null || day == null) return DateTime.now();
    return DateTime(year, month, day);
  }

  Future<Map<String, _UserIdentity>> _fetchUsersByUid() async {
    final snapshot = await _getWithFallback(_users);
    return {
      for (final doc in snapshot.docs)
        (doc.data()['uid'] ?? doc.id).toString(): _UserIdentity(
          uid: (doc.data()['uid'] ?? doc.id).toString(),
          name: (doc.data()['name'] ?? doc.id).toString(),
          email: (doc.data()['email'] ?? '-').toString(),
        ),
    };
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _getWithFallback(
    Query<Map<String, dynamic>> query, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      return await query
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(timeout);
    } on TimeoutException {
      return query.get(const GetOptions(source: Source.cache));
    } on FirebaseException catch (e) {
      final shouldFallbackToCache = e.code == 'unavailable' ||
          e.code == 'deadline-exceeded' ||
          e.code == 'failed-precondition';
      if (shouldFallbackToCache) {
        debugPrint('AdminService fallback cache: ${e.code} ${e.message}');
        return query.get(const GetOptions(source: Source.cache));
      }
      rethrow;
    }
  }
}
