import 'package:cloud_firestore/cloud_firestore.dart';
import 'family_link_service.dart';
import '../models/kidney_health_record.dart';

class KidneyHealthService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _recordsRef(String uid) {
    return _db.collection('users').doc(uid).collection('kidney_health_records');
  }

  static Future<void> addRecord(String uid, KidneyHealthRecord record) async {
    await _recordsRef(uid).doc(record.id).set(record.toMap());
    await FamilyLinkService.mirrorUserSubcollectionWrite(
      sourceUid: uid,
      subcollection: 'kidney_health_records',
      docId: record.id,
      data: record.toMap(),
    );
  }

  static Future<void> updateRecord(
    String uid,
    KidneyHealthRecord record,
  ) async {
    await _recordsRef(
      uid,
    ).doc(record.id).set(record.toMap(), SetOptions(merge: true));
    await FamilyLinkService.mirrorUserSubcollectionWrite(
      sourceUid: uid,
      subcollection: 'kidney_health_records',
      docId: record.id,
      data: record.toMap(),
    );
  }

  static Future<void> deleteRecord(String uid, String recordId) async {
    await _recordsRef(uid).doc(recordId).delete();
    await FamilyLinkService.mirrorUserSubcollectionDelete(
      sourceUid: uid,
      subcollection: 'kidney_health_records',
      docId: recordId,
    );
  }

  static Future<List<KidneyHealthRecord>> getRecords(
    String uid, {
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 200,
  }) async {
    Query<Map<String, dynamic>> query = _recordsRef(
      uid,
    ).orderBy('date', descending: true).limit(limit);

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
    return snap.docs.map((d) => KidneyHealthRecord.fromMap(d.data())).toList();
  }
}
