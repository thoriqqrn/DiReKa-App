import 'package:cloud_firestore/cloud_firestore.dart';
import 'family_link_service.dart';
import '../models/hypertension_health_record.dart';

class HypertensionHealthService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _recordsRef(String uid) {
    return _db.collection('users').doc(uid).collection('hypertension_health_records');
  }

  static Future<void> addRecord(String uid, HypertensionHealthRecord record) async {
    await _recordsRef(uid).doc(record.id).set(record.toMap());
    await FamilyLinkService.mirrorUserSubcollectionWrite(
      sourceUid: uid,
      subcollection: 'hypertension_health_records',
      docId: record.id,
      data: record.toMap(),
    );
  }

  static Future<void> updateRecord(String uid, HypertensionHealthRecord record) async {
    await _recordsRef(uid).doc(record.id).set(record.toMap(), SetOptions(merge: true));
    await FamilyLinkService.mirrorUserSubcollectionWrite(
      sourceUid: uid,
      subcollection: 'hypertension_health_records',
      docId: record.id,
      data: record.toMap(),
    );
  }

  static Future<void> deleteRecord(String uid, String recordId) async {
    await _recordsRef(uid).doc(recordId).delete();
    await FamilyLinkService.mirrorUserSubcollectionDelete(
      sourceUid: uid,
      subcollection: 'hypertension_health_records',
      docId: recordId,
    );
  }

  static Future<List<HypertensionHealthRecord>> getRecords(
    String uid, {
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 200,
  }) async {
    Query<Map<String, dynamic>> query =
        _recordsRef(uid).orderBy('date', descending: true).limit(limit);

    if (fromDate != null) {
      query = query.where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate),
      );
    }
    if (toDate != null) {
      query = query.where('date', isLessThan: Timestamp.fromDate(toDate));
    }

    final snap = await query.get();
    return snap.docs.map((d) => HypertensionHealthRecord.fromMap(d.data())).toList();
  }

  /// Ambil data tekanan darah bulanan untuk grafik tren.
  /// Mengembalikan record pemeriksaan dengan examId 'td', diurutkan ascending.
  static Future<List<HypertensionHealthRecord>> getBloodPressureRecords(
    String uid, {
    int monthsBack = 3,
  }) async {
    final from = DateTime.now().subtract(Duration(days: monthsBack * 30));
    final all = await getRecords(uid, fromDate: from);
    final bpRecords = all
        .where((r) => r.type == HypertensionInputType.pemeriksaan)
        .where((r) => (r.payload['examId'] ?? '').toString() == 'td')
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return bpRecords;
  }
}
