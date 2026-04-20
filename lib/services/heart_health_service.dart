import 'package:cloud_firestore/cloud_firestore.dart';
import 'family_link_service.dart';
import '../models/heart_health_record.dart';

class HeartHealthService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _recordsRef(String uid) {
    return _db.collection('users').doc(uid).collection('heart_health_records');
  }

  static Future<void> addRecord(String uid, HeartHealthRecord record) async {
    await _recordsRef(uid).doc(record.id).set(record.toMap());
    await FamilyLinkService.mirrorUserSubcollectionWrite(
      sourceUid: uid,
      subcollection: 'heart_health_records',
      docId: record.id,
      data: record.toMap(),
    );
  }

  static Future<void> updateRecord(String uid, HeartHealthRecord record) async {
    await _recordsRef(uid)
        .doc(record.id)
        .set(record.toMap(), SetOptions(merge: true));
    await FamilyLinkService.mirrorUserSubcollectionWrite(
      sourceUid: uid,
      subcollection: 'heart_health_records',
      docId: record.id,
      data: record.toMap(),
    );
  }

  static Future<void> deleteRecord(String uid, String recordId) async {
    await _recordsRef(uid).doc(recordId).delete();
    await FamilyLinkService.mirrorUserSubcollectionDelete(
      sourceUid: uid,
      subcollection: 'heart_health_records',
      docId: recordId,
    );
  }

  static Future<List<HeartHealthRecord>> getRecords(
    String uid, {
    DateTime? fromDate,
    int limit = 200,
  }) async {
    Query<Map<String, dynamic>> query =
        _recordsRef(uid).orderBy('date', descending: true).limit(limit);

    if (fromDate != null) {
      query =
          query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate));
    }

    final snap = await query.get();
    return snap.docs.map((d) => HeartHealthRecord.fromMap(d.data())).toList();
  }
}
